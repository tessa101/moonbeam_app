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
        VStack(alignment: .leading) {
            switch viewModel.visibility {
            case .here, .nearby:
                compass
            case .far:
                Text(CompassViewModel.farMessage)
                    .foregroundStyle(.secondary)
            case .locationOff:
                locationOffHint
            case .hidden:
                EmptyView()
            }

            // In every state, including hidden: "the compass is gone" is
            // one of the things it has to diagnose (4.8).
            #if DEBUG
            debugReadout
            #endif
        }
    }

    // MARK: - Compass

    private var compass: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Compass")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            // Nearby only (§2): says which city the bearings are for.
            if let nearbyNote = viewModel.nearbyNote {
                Text(nearbyNote)
                    .foregroundStyle(.secondary)
            }

            CompassDial(
                heading: viewModel.heading,
                targets: viewModel.targets,
                lockedKind: viewModel.lockedKind,
                accessibilityTargets: viewModel.targetsAccessibilityLabel
            )
            .padding(.vertical)

            heading

            if let lockText = viewModel.lockText {
                Label(lockText, systemImage: "scope")
                    .font(.title3.bold())
                    .foregroundStyle(Color.accentColor)
                    .accessibilityLabel(viewModel.lockAccessibilityLabel ?? lockText)
            }

            // No target rows (4.7): rise/set bearings are in the moon table
            // above, and VoiceOver reads every target from the dial.
        }
        // One firm tap per lock acquired (4.5). Release and holding don't
        // change the count, so they're silent. System feedback follows the
        // user's System Haptics setting.
        .sensoryFeedback(.impact(weight: .heavy), trigger: viewModel.lockAcquisitionCount)
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

    // MARK: - DEBUG readout

    #if DEBUG
    /// Device diagnosis only (4.8/4.9); compiled out of release builds.
    private var debugReadout: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(viewModel.debugReadout, id: \.self) { line in
                Text(line)
            }
        }
        .font(.caption.monospaced())
        .foregroundStyle(.secondary)
        .padding(.top)
    }
    #endif

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

    /// About 30 mi from `place`: Nearby.
    static let huntingtonBeach = Place(
        name: "Huntington Beach",
        region: "CA",
        country: "United States",
        latitude: 33.66,
        longitude: -118.00,
        timeZone: TimeZone(identifier: "America/Los_Angeles") ?? .gmt
    )

    /// About 110 mi from `place`: Far.
    static let sanDiego = Place(
        name: "San Diego",
        region: "CA",
        country: "United States",
        latitude: 32.72,
        longitude: -117.16,
        timeZone: TimeZone(identifier: "America/Los_Angeles") ?? .gmt
    )

    static func context(
        selected: Place = place,
        auth: LocationAuthState = .authorized
    ) -> CompassContext {
        let day = Date()
        return CompassContext(
            place: selected,
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

#Preview("Nearby") {
    CompassPreview(
        context: CompassPreview.context(selected: CompassPreview.huntingtonBeach),
        reading: HeadingReading(trueHeading: 74, accuracy: 3)
    )
}

#Preview("Far") {
    CompassPreview(context: CompassPreview.context(selected: CompassPreview.sanDiego), reading: nil)
}

#Preview("Location off") {
    CompassPreview(context: CompassPreview.context(auth: .denied), reading: nil)
}
