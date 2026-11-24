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
                .overlay { pin }
                .overlay(alignment: .bottom) { legend }
                .toolbar { toolbar }
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.visible, for: .navigationBar)
        }
        .task { await viewModel.observeConnectivity() }
        .sensoryFeedback(.impact(weight: .heavy), trigger: viewModel.lockAcquisitionCount)
        .onChange(of: viewModel.returnToPlaceCount) {
            position = .camera(Self.placeCamera(for: viewModel))
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

    private var map: some View {
        Map(position: $position) {
            UserAnnotation()
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
            }
        }
        .annotationTitles(.hidden)
        .mapStyle(mapStyle)
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .onMapCameraChange(frequency: .continuous) { context in
            viewModel.cameraChanged(
                center: BearingLine.Coordinate(context.camera.centerCoordinate),
                heading: context.camera.heading,
                distance: context.camera.distance,
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
        if line.isSelected { traits.insert(.isSelected) }
        return traits
    }

    private func cellBorder(_ line: MoonMapViewModel.Line) -> Color {
        if line.isLocked { return Theme.Colors.accent }
        return line.isSelected ? Theme.Colors.textPrimary.opacity(Self.cellSelectedBorderOpacity) : Color.clear
    }

    // MARK: - Toolbar

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
        if viewModel.canFollowUser {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    position = .userLocation(followsHeading: true, fallback: position)
                } label: {
                    Image(systemName: position.followsUserLocation ? "location.north.line.fill" : "location.north.line")
                }
                .accessibilityLabel("Follow my location")
            }
        }
    }
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
            connectivity: FakeConnectivityService()
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
            connectivity: FakeConnectivityService(isOnline: false)
        )
    )
}
#endif
