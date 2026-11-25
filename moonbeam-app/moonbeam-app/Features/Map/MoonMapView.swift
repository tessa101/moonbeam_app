//
//  MoonMapView.swift
//  moonbeam-app
//

import MapKit
import SwiftUI

/// The map sheet (MAP.md §3): a satellite map with a fixed "stand here" pin
/// at its centre and the moonrise and moonset lines drawn from it, each
/// tagged near the pin. It opens following you, turning with the phone; a
/// line turns amber with a haptic when the phone points along it, as the
/// compass locks. Pan the map to try another spot.
///
/// The camera is view state: MapKit owns it, and the pin is simply the
/// camera's centre, reported to the model as it moves. Everything else
/// (lines, labels, style, online) comes from `MoonMapViewModel`.
struct MoonMapView: View {

    @Bindable var viewModel: MoonMapViewModel

    @State private var position: MapCameraPosition

    /// The camera as last reported, and whether it's moving. A reference
    /// MapKit writes to every frame, deliberately unobserved: as `@State`
    /// it redrew the whole sheet each frame, which with 3D and the phone's
    /// heading froze the map (Tessa, 2026-11-25).
    @State private var tracker = CameraTracker()

    private var lastCamera: MapCamera? { tracker.camera }

    @Environment(\.dismiss) private var dismiss

    // MARK: - Constants

    private static let lockedLineWidth: CGFloat = 5
    private static let selectedLineWidth: CGFloat = 4
    private static let otherLineWidth: CGFloat = 2
    private static let otherLineOpacity = 0.45
    private static let tagPaddingHorizontal: CGFloat = 8
    private static let tagPaddingVertical: CGFloat = 4
    private static let cellPadding: CGFloat = 10
    private static let cellCornerRadius: CGFloat = 14
    private static let cellSelectedBorderOpacity = 0.5
    private static let cellLockedFillOpacity = 0.15
    /// How long the camera must be still before the map turns again.
    private static let settleDelay = Duration.milliseconds(300)
    /// Closer than this, the camera already faces the heading: setting it
    /// again would only report another move, and so on.
    private static let alreadyFacingDegrees = 0.5
    private static let mapButtonSpacing: CGFloat = 12
    private static let mapButtonTopPadding: CGFloat = 12
    private static let pinSize: CGFloat = 18
    private static let pinStrokeWidth: CGFloat = 3
    private static let pinDotSize: CGFloat = 6
    private static let legendPadding: CGFloat = 14
    private static let legendSpacing: CGFloat = 8
    private static let legendCornerRadius: CGFloat = 18
    private static let legendTitleToDetail: CGFloat = 2

    // MARK: - Init

    init(viewModel: MoonMapViewModel) {
        self.viewModel = viewModel
        let camera = Self.placeCamera(for: viewModel)
        _position = State(
            initialValue: viewModel.startsFollowingUser
                ? .userLocation(followsHeading: true, fallback: .camera(camera))
                : .camera(camera)
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            map
                .overlay {
                    // Looking along a line, the camera's centre is out on
                    // the line; the stand point is a map annotation instead.
                    if viewModel.lookingAlong == nil { pin }
                }
                .overlay(alignment: .bottom) { legend }
                .overlay(alignment: .topLeading) { mapButtons }
                .toolbar { toolbar }
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.visible, for: .navigationBar)
        }
        .task { await viewModel.observeConnectivity() }
        .task { await viewModel.observeHeading() }
        .onChange(of: viewModel.cameraHeadingRequest) { _, heading in
            turnCamera(to: heading)
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: viewModel.lockAcquisitionCount)
        .onChange(of: viewModel.returnToPlaceCount) {
            position = .camera(Self.placeCamera(for: viewModel))
        }
        .onChange(of: viewModel.style) { old, new in
            // Switching to 3D goes straight to looking along the selected
            // line: the binoculars alone weren't obvious (Tessa,
            // 2026-11-25). The button then switches to the 3D overview.
            if new == .threeD, let request = viewModel.lookAlong() {
                move(to: request)
            } else {
                tiltForStyle(from: old, to: new)
            }
        }
        .onChange(of: viewModel.selected) {
            // Turn to the newly selected line while looking along one.
            guard viewModel.lookingAlong != nil, let request = viewModel.lookAlong() else { return }
            move(to: request)
        }
    }

    /// Turns the map with the phone at a chosen spot (MAP.md §3.10): the
    /// same centre, zoom and tilt, the phone's heading. MapKit does this
    /// itself while following you.
    ///
    /// Never mid-gesture or mid-animation: setting the camera then fights
    /// your finger. A turn that arrives meanwhile is applied when the camera
    /// settles.
    private func turnCamera(to heading: Double?) {
        guard let heading, let lastCamera, !tracker.isMoving,
              !position.followsUserLocation, viewModel.lookingAlong == nil,
              CompassLock.angularDistance(lastCamera.heading, heading) >= Self.alreadyFacingDegrees else { return }
        position = .camera(
            MapCamera(
                centerCoordinate: lastCamera.centerCoordinate,
                distance: lastCamera.distance,
                heading: heading,
                pitch: lastCamera.pitch
            )
        )
    }

    /// The camera moved (a gesture, an animation, or a turn): hold off
    /// turning until it has been still for `settleDelay`, then apply any
    /// turn that waited. This also caps turns at a few a second.
    private func cameraMoved() {
        tracker.isMoving = true
        tracker.settle?.cancel()
        tracker.settle = Task { @MainActor in
            do { try await Task.sleep(for: Self.settleDelay) } catch { return }
            tracker.isMoving = false
            turnCamera(to: viewModel.cameraHeadingRequest)
        }
    }

    /// A tap on the map: stand there, keeping the zoom, tilt and heading.
    private func standHere(_ coordinate: BearingLine.Coordinate) {
        if let request = viewModel.standHere(coordinate) {
            move(to: request)
            return
        }
        withAnimation {
            position = .camera(
                MapCamera(
                    centerCoordinate: coordinate.location,
                    distance: lastCamera?.distance ?? MoonMapViewModel.initialCameraDistance,
                    heading: lastCamera?.heading ?? 0,
                    pitch: lastCamera?.pitch ?? 0
                )
            )
        }
    }

    /// Animates MapKit's camera to the model's request.
    private func move(to request: MoonMapViewModel.CameraRequest) {
        withAnimation {
            position = .camera(
                MapCamera(
                    centerCoordinate: request.center.location,
                    distance: request.distance,
                    heading: request.heading,
                    pitch: request.pitch
                )
            )
        }
    }

    /// "Look along the line" on and off (MAP.md §5).
    private func toggleLookAlong() {
        if viewModel.lookingAlong != nil {
            move(to: viewModel.stopLookingAlong())
        } else if let request = viewModel.lookAlong() {
            move(to: request)
        }
    }

    /// Switching to 3D tilts the camera where it is, so the terrain reads
    /// as 3D straight away; leaving 3D lays it flat again. While following
    /// you the camera is MapKit's, so it's left alone (the pitch control
    /// still works).
    private func tiltForStyle(from old: MoonMapViewModel.Style, to new: MoonMapViewModel.Style) {
        guard !position.followsUserLocation, viewModel.lookingAlong == nil, let lastCamera,
              (old == .threeD) != (new == .threeD) else { return }
        let pitch = new == .threeD ? MoonMapViewModel.threeDPitch : 0
        withAnimation {
            position = .camera(
                MapCamera(
                    centerCoordinate: lastCamera.centerCoordinate,
                    distance: lastCamera.distance,
                    heading: lastCamera.heading,
                    pitch: pitch
                )
            )
        }
    }

    /// North up over the place, a few kilometres across.
    private static func placeCamera(for viewModel: MoonMapViewModel) -> MapCamera {
        MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: viewModel.place.latitude, longitude: viewModel.place.longitude),
            distance: MoonMapViewModel.initialCameraDistance,
            heading: 0,
            pitch: 0
        )
    }

    // MARK: - Map

    /// The map, plus tap to stand somewhere else (MAP.md §3.10).
    private var map: some View {
        MapReader { proxy in
            mapView
                .onTapGesture { point in
                    guard let coordinate = proxy.convert(point, from: .local) else { return }
                    standHere(BearingLine.Coordinate(coordinate))
                }
        }
    }

    private var mapView: some View {
        Map(position: $position) {
            UserAnnotation()
            if viewModel.lookingAlong != nil {
                Annotation("Stand here", coordinate: viewModel.pin.location, anchor: .center) {
                    pin
                }
                .annotationTitles(.hidden)
            }
            ForEach(viewModel.lines) { line in
                MapPolyline(
                    coordinates: [line.bearingLine.start.location, line.bearingLine.end.location],
                    contourStyle: .geodesic
                )
                .stroke(lineColor(line), lineWidth: lineWidth(line))
            }
            ForEach(viewModel.lines) { line in
                Annotation(line.mapLabel, coordinate: line.mapLabelCoordinate.location, anchor: .center) {
                    lineTag(line)
                }
                // The tag already shows the text; hide MapKit's own title.
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(mapStyle)
        .mapControls {
            MapCompass()
            MapPitchToggle()
            MapScaleView()
        }
        .onMapCameraChange(frequency: .continuous) { context in
            tracker.camera = context.camera
            cameraMoved()
            viewModel.cameraChanged(
                center: BearingLine.Coordinate(context.camera.centerCoordinate),
                heading: context.camera.heading,
                distance: context.camera.distance,
                pitch: context.camera.pitch,
                followsHeading: position.followsUserHeading
            )
        }
        .accessibilityLabel(viewModel.mapAccessibilityLabel)
    }

    /// Amber when the phone points along it (the compass's lock colour),
    /// light when selected, faint otherwise.
    private func lineColor(_ line: MoonMapViewModel.Line) -> Color {
        if line.isLocked { return Theme.Colors.accent }
        return line.isSelected ? Theme.Colors.textPrimary : Theme.Colors.textPrimary.opacity(Self.otherLineOpacity)
    }

    private func lineWidth(_ line: MoonMapViewModel.Line) -> CGFloat {
        if line.isLocked { return Self.lockedLineWidth }
        return line.isSelected ? Self.selectedLineWidth : Self.otherLineWidth
    }

    /// "Moonrise 58°" on the line near the pin. Tapping it selects the line.
    private func lineTag(_ line: MoonMapViewModel.Line) -> some View {
        Text(line.mapLabel)
            .font(Theme.Fonts.label)
            .foregroundStyle(line.isLocked ? Theme.Colors.onAccent : Theme.Colors.textPrimary)
            .padding(.horizontal, Self.tagPaddingHorizontal)
            .padding(.vertical, Self.tagPaddingVertical)
            .background(line.isLocked ? Theme.Colors.accent : Theme.Colors.glassTint, in: Capsule())
            .opacity(line.isSelected || line.isLocked ? 1 : Self.otherLineOpacity * 2)
            .onTapGesture { viewModel.select(line.event) }
            .accessibilityHidden(true)
    }

    private var mapStyle: MapStyle {
        switch viewModel.style {
        case .satellite: .hybrid(elevation: .flat)
        case .explore: .standard(elevation: .flat)
        case .threeD: .hybrid(elevation: .realistic)
        }
    }

    /// The fixed "stand here" pin, centred over the map like a pickup pin.
    /// It ignores touches so the map pans under it.
    private var pin: some View {
        ZStack {
            Circle()
                .stroke(Theme.Colors.accent, lineWidth: Self.pinStrokeWidth)
                .frame(width: Self.pinSize, height: Self.pinSize)
            Circle()
                .fill(Theme.Colors.accent)
                .frame(width: Self.pinDotSize, height: Self.pinDotSize)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Legend

    /// Moonrise and Moonset side by side, like the card: time, bearing and,
    /// while the map turns with the phone, which way to turn. Tapping one
    /// selects its line (MAP.md §3.9). Plus the offline note.
    private var legend: some View {
        VStack(alignment: .leading, spacing: Self.legendSpacing) {
            if !viewModel.isOnline {
                VStack(alignment: .leading, spacing: Self.legendTitleToDetail) {
                    Text(MoonMapViewModel.offlineTitle)
                        .font(Theme.Fonts.label)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(MoonMapViewModel.offlineMessage)
                        .font(Theme.Fonts.detail)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .accessibilityElement(children: .combine)
            }
            if let note = viewModel.lookAlongNote ?? viewModel.threeDHint {
                Text(note)
                    .font(Theme.Fonts.detail)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: Self.legendSpacing) { legendCells }
                VStack(alignment: .leading, spacing: Self.legendSpacing) { legendCells }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Self.legendPadding)
        .background(Theme.Colors.glassTint, in: RoundedRectangle(cornerRadius: Self.legendCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Self.legendCornerRadius)
                .strokeBorder(Theme.Colors.glassBorder, lineWidth: Theme.Metrics.hairline)
        }
        .padding(.horizontal, Theme.Metrics.screenMargin)
        .padding(.bottom, Theme.Metrics.screenMargin)
    }

    private var legendCells: some View {
        ForEach(viewModel.lines) { line in
            legendCell(line)
        }
    }

    private func legendCell(_ line: MoonMapViewModel.Line) -> some View {
        let shape = RoundedRectangle(cornerRadius: Self.cellCornerRadius)
        return Button {
            viewModel.select(line.event)
        } label: {
            VStack(alignment: .leading, spacing: Self.legendTitleToDetail) {
                Text(line.title)
                    .font(Theme.Fonts.label)
                    .foregroundStyle(line.isLocked ? Theme.Colors.accent : Theme.Colors.textSecondary)
                Text(line.detail)
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.textPrimary)
                if let hint = line.turnHint {
                    Text(hint)
                        .font(Theme.Fonts.detail)
                        .foregroundStyle(Theme.Colors.accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Self.cellPadding)
            .background(line.isLocked ? Theme.Colors.accent.opacity(Self.cellLockedFillOpacity) : Color.clear, in: shape)
            .overlay {
                shape.strokeBorder(cellBorder(line), lineWidth: Theme.Metrics.hairline)
            }
            .contentShape(shape)
        }
        .buttonStyle(.row)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(line.accessibilityLabel)
        .accessibilityAddTraits(cellTraits(line))
    }

    private func cellTraits(_ line: MoonMapViewModel.Line) -> AccessibilityTraits {
        var traits: AccessibilityTraits = .isButton
        if line.isSelected { traits.formUnion(.isSelected) }
        return traits
    }

    private func cellBorder(_ line: MoonMapViewModel.Line) -> Color {
        if line.isLocked { return Theme.Colors.accent }
        return line.isSelected ? Theme.Colors.textPrimary.opacity(Self.cellSelectedBorderOpacity) : Color.clear
    }

    // MARK: - Map buttons

    /// Follow me, turn with the phone, and (in 3D) look along the line: a
    /// column of round buttons at the map's leading edge, clear of MapKit's
    /// own controls at the trailing edge.
    private var mapButtons: some View {
        VStack(spacing: Self.mapButtonSpacing) {
            if viewModel.canFollowUser {
                mapButton(
                    systemImage: position.followsUserLocation ? "location.north.line.fill" : "location.north.line",
                    label: "Follow my location",
                    isOn: position.followsUserLocation
                ) {
                    viewModel.stopLookingAlong()
                    viewModel.turnsWithPhone = true
                    position = .userLocation(followsHeading: true, fallback: position)
                }
                mapButton(
                    systemImage: viewModel.turnsWithPhone ? "safari.fill" : "safari",
                    label: "Turn the map with the phone",
                    isOn: viewModel.turnsWithPhone
                ) {
                    viewModel.turnsWithPhone.toggle()
                }
            }
            if viewModel.canLookAlong {
                mapButton(
                    systemImage: viewModel.lookingAlong == nil ? "binoculars" : "binoculars.fill",
                    label: viewModel.lookingAlong == nil ? "Look along the line" : "Back to the map",
                    isOn: viewModel.lookingAlong != nil,
                    action: toggleLookAlong
                )
            }
        }
        .padding(.leading, Theme.Metrics.screenMargin)
        .padding(.top, Self.mapButtonTopPadding)
    }

    private func mapButton(
        systemImage: String,
        label: String,
        isOn: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3)
                .frame(width: Theme.Metrics.minimumHitTarget, height: Theme.Metrics.minimumHitTarget)
                .background(Theme.Colors.glassTint, in: Circle())
                .overlay {
                    Circle().strokeBorder(isOn ? Theme.Colors.accent : Theme.Colors.glassBorder, lineWidth: Theme.Metrics.hairline)
                }
        }
        .buttonStyle(.inline(isOn ? Theme.Colors.accent : Theme.Colors.textPrimary))
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? AccessibilityTraits.isSelected : AccessibilityTraits())
    }

    // MARK: - Toolbar

    /// Only the style switch and Done: with the map buttons up here as
    /// well, the bar overlapped itself (Tessa, 2026-11-25).
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Picker("Map style", selection: $viewModel.style) {
                ForEach(MoonMapViewModel.Style.allCases, id: \.self) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Done") { dismiss() }
        }
    }
}

// MARK: - Camera tracker

/// The camera MapKit last reported and whether it's still moving, kept out
/// of SwiftUI's observation so per-frame updates don't redraw the sheet.
private final class CameraTracker {
    var camera: MapCamera?
    var isMoving = false
    var settle: Task<Void, Never>?
}

// MARK: - Coordinates

/// MapKit's coordinate type, kept out of `BearingLine` so its maths stays
/// free of MapKit.
private extension BearingLine.Coordinate {

    init(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    var location: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Irvine, moonrise tapped") {
    MoonMapView(
        viewModel: MoonMapViewModel(
            place: .irvine,
            day: .now,
            rise: MoonEvent(date: .now, azimuth: 58),
            set: MoonEvent(date: .now, azimuth: 301),
            selected: .rise,
            canFollowUser: true,
            connectivity: FakeConnectivityService(),
            headingService: FakeHeadingService()
        )
    )
}

#Preview("Offline") {
    MoonMapView(
        viewModel: MoonMapViewModel(
            place: .irvine,
            day: .now,
            rise: MoonEvent(date: .now, azimuth: 58),
            set: nil,
            selected: .rise,
            canFollowUser: false,
            connectivity: FakeConnectivityService(isOnline: false),
            headingService: FakeHeadingService()
        )
    )
}
#endif
