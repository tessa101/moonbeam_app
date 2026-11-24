//
//  MoonMapView.swift
//  moonbeam-app
//

import MapKit
import SwiftUI

/// The map sheet (MAP.md §3): a satellite map with a fixed "stand here" pin
/// at its centre and the moonrise and moonset lines drawn from it. Pan the
/// map to try another spot; Follow me puts the pin on you and turns the map
/// with the phone.
///
/// The camera is view state: MapKit owns it, and the pin is simply the
/// camera's centre, reported to the model as it moves. Everything else
/// (lines, labels, style, online) comes from `MoonMapViewModel`.
struct MoonMapView: View {

    @Bindable var viewModel: MoonMapViewModel

    @State private var position: MapCameraPosition

    @Environment(\.dismiss) private var dismiss

    // MARK: - Constants

    private static let emphasisedLineWidth: CGFloat = 4
    private static let lineWidth: CGFloat = 2.5
    private static let secondaryLineOpacity = 0.75
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
        let camera = MapCamera(
            centerCoordinate: viewModel.pin.location,
            distance: MoonMapViewModel.initialCameraDistance,
            heading: 0,
            pitch: 0
        )
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
                .stroke(
                    line.isEmphasised ? Theme.Colors.accent : Theme.Colors.textPrimary.opacity(Self.secondaryLineOpacity),
                    lineWidth: line.isEmphasised ? Self.emphasisedLineWidth : Self.lineWidth
                )
            }
        }
        .mapStyle(mapStyle)
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .onMapCameraChange(frequency: .continuous) { context in
            viewModel.pinMoved(to: BearingLine.Coordinate(context.camera.centerCoordinate))
        }
        .accessibilityLabel(viewModel.mapAccessibilityLabel)
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

    /// The lines' times and bearings, readable at any zoom (the lines'
    /// far ends are usually off screen), plus the offline note.
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
            ForEach(viewModel.lines) { line in
                VStack(alignment: .leading, spacing: Self.legendTitleToDetail) {
                    Text(line.title)
                        .font(Theme.Fonts.label)
                        .foregroundStyle(line.isEmphasised ? Theme.Colors.accent : Theme.Colors.textSecondary)
                    Text(line.detail)
                        .font(Theme.Fonts.body)
                        .foregroundStyle(Theme.Colors.textPrimary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(line.accessibilityLabel)
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
            emphasised: .rise,
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
            emphasised: .rise,
            canFollowUser: false,
            connectivity: FakeConnectivityService(isOnline: false)
        )
    )
}
#endif
