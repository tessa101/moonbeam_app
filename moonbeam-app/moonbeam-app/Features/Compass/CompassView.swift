//
//  CompassView.swift
//  moonbeam-app
//

import SwiftUI

/// The compass under the moon table (COMPASS.md §1, §2), or the
/// enable-location hint in its place.
///
/// Functional and deliberately unstyled: layout and look are the design
/// pass. Every string and accessibility label comes from `CompassViewModel`.
/// Where it sits and when it counts as on screen is `LocationScreen`'s job.
struct CompassView: View {

    let viewModel: CompassViewModel

    /// The hint's button: the existing Location Off flow (the system prompt
    /// if not yet asked, otherwise the Location Off dialog).
    let onTurnOnLocation: () -> Void

    var body: some View {
        switch viewModel.visibility {
        case .shown:
            compass
        case .locationOff:
            locationOffHint
        case .hidden:
            EmptyView()
        }
    }

    // MARK: - Compass

    private var compass: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Compass")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            CompassDial(
                heading: viewModel.heading,
                targets: viewModel.targets,
                lockedKind: viewModel.lockedKind
            )
            .padding(.vertical)

            heading

            if let lockText = viewModel.lockText {
                Label(lockText, systemImage: "scope")
                    .font(.title3.bold())
                    .foregroundStyle(Color.accentColor)
                    .accessibilityLabel(viewModel.lockAccessibilityLabel ?? lockText)
            }

            ForEach(viewModel.targets, id: \.kind) { target in
                Text(viewModel.targetText(for: target))
                    .accessibilityLabel(viewModel.targetAccessibilityLabel(for: target))
            }
        }
    }

    /// One element for VoiceOver: the heading, or "Compass accuracy is low"
    /// when it can't be trusted (an untrustworthy number isn't read out).
    private var heading: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let headingText = viewModel.headingText {
                Text(headingText)
                    .font(.largeTitle)
                    .monospacedDigit()
                    .foregroundStyle(viewModel.isLowAccuracy ? .secondary : .primary)
            }
            if viewModel.isLowAccuracy {
                Text(CompassViewModel.lowAccuracyText)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(viewModel.headingAccessibilityLabel)
        .accessibilityAddTraits(.updatesFrequently)
    }

    // MARK: - Location off (§2)

    private var locationOffHint: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(CompassViewModel.locationOffHint)
            Button(CompassViewModel.turnOnLocationTitle, action: onTurnOnLocation)
        }
    }
}

// MARK: - Previews

/// A compass fed from fakes: the simulator has no compass.
private struct CompassPreview: View {

    let context: CompassContext
    let reading: HeadingReading?

    @State private var heading = FakeHeadingService()
    @State private var viewModel: CompassViewModel?

    var body: some View {
        ScrollView {
            if let viewModel {
                CompassView(viewModel: viewModel, onTurnOnLocation: {})
                    .padding()
            }
        }
        .task {
            let viewModel = CompassViewModel(
                headingService: heading,
                moonService: FakeMoonService(position: MoonPosition(azimuth: 140, isUp: true))
            )
            viewModel.update(context)
            viewModel.setOnScreen(true)
            self.viewModel = viewModel
            // Let the view model's stream task start before sending.
            await Task.yield()
            if let reading { heading.send(reading) }
        }
    }

    static let place = Place(
        name: "Los Angeles",
        region: "CA",
        country: "United States",
        latitude: 34.00,
        longitude: -118.43,
        timeZone: TimeZone(identifier: "America/Los_Angeles") ?? .gmt,
        isCurrentLocation: true
    )

    static func context(auth: LocationAuthState = .authorized) -> CompassContext {
        let day = Date()
        return CompassContext(
            place: place,
            detectedPlace: place,
            authState: auth,
            moonDay: MoonDay(
                place: place,
                rise: MoonEvent(date: day, azimuth: 72),
                set: MoonEvent(date: day, azimuth: 288),
                phase: .full,
                phaseAngle: FakeMoonService.fullMoonPhaseAngle,
                illumination: FakeMoonService.fullyLit
            ),
            isToday: true
        )
    }
}

#Preview("Locked on moonrise") {
    CompassPreview(context: CompassPreview.context(), reading: HeadingReading(trueHeading: 74, accuracy: 3))
}

#Preview("Low accuracy") {
    CompassPreview(context: CompassPreview.context(), reading: HeadingReading(trueHeading: 200, accuracy: 25))
}

#Preview("No compass (simulator)") {
    CompassPreview(context: CompassPreview.context(), reading: .unavailable)
}

#Preview("Location off") {
    CompassPreview(context: CompassPreview.context(auth: .denied), reading: nil)
}
