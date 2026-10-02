//
//  CompassView.swift
//  moonbeam-app
//

import SwiftUI

/// The compass block under the moon card (DESIGN-1.1.md §3.3, COMPASS.md
/// §1, §2): the heading readout (an amber pill when locked), the accuracy
/// notes under it while they show (COMPASS-1.1.md §4.1), the dial, and the
/// Nearby note under the dial; or, in place of the compass, the Far or
/// location-off note.
///
/// Every string and accessibility label comes from `CompassViewModel`.
/// Where it sits and when it counts as on screen is `LocationScreen`'s job.
struct CompassView: View {

    let viewModel: CompassViewModel

    /// The hint's button: the existing Location Off flow (the system prompt
    /// if not yet asked, otherwise the Location Off dialog).
    let onTurnOnLocation: () -> Void

    /// Use Precise Location: iOS's temporary full-accuracy alert (4.12).
    let onUsePreciseLocation: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The readout's slot, so the dial doesn't move when the pill appears.
    /// The pill is taller than the slot and overflows it, as in the HTML;
    /// the slot grows with the readout's text style.
    @ScaledMetric(relativeTo: .title2) private var readoutHeight = Self.readoutBaseHeight

    // MARK: - Constants (§3.3, from the HTML)

    private static let readoutBaseHeight: CGFloat = 40
    /// Readout to dial (the dial adds its indicator's 17 pt itself), and
    /// dial to notes.
    private static let dialTopSpacing: CGFloat = 12
    private static let dialBottomSpacing: CGFloat = 4
    private static let notesTopSpacing: CGFloat = 14
    private static let notesSpacing: CGFloat = 10
    /// Buttons under a note are no wider than the widest note.
    private static let noteMaxWidth: CGFloat = 330

    /// The lock pill: padding 9 / 18, `accent` glow 45% (CSS 36 px blur).
    private static let pillPaddingVertical: CGFloat = 9
    private static let pillPaddingHorizontal: CGFloat = 18
    private static let pillGlowOpacity = 0.45
    private static let pillGlowRadius: CGFloat = 18

    private static let lockAnimation = Animation.easeOut(duration: 0.2)

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            switch viewModel.visibility {
            case .here, .nearby:
                compass
            case .far:
                if let farMessage = viewModel.farMessage {
                    CompassNote(text: farMessage)
                }
            case .locationOff:
                locationOffNote
            case .hidden:
                EmptyView()
            }

            // In every state, including hidden: "the compass is gone" is
            // one of the things it has to diagnose (4.8).
            #if DEBUG
            debugReadout
            #endif
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Compass

    private var compass: some View {
        VStack(spacing: 0) {
            readout
                .fixedSize(horizontal: false, vertical: true)
                .frame(height: readoutHeight)

            // §4.1: no lock is possible in low accuracy, so the warning
            // takes the space under the readout; the dial (and its needle)
            // moves down while it shows.
            accuracyNotes

            CompassDial(
                heading: viewModel.heading,
                targets: viewModel.targets,
                lockedKind: viewModel.lockedKind,
                accessibilityTargets: viewModel.targetsAccessibilityLabel,
                moonGlyph: viewModel.moonGlyph,
                arc: viewModel.arc,
                showsMoonPulse: viewModel.showsMoonPulse
            )
            .padding(.top, Self.dialTopSpacing)
            .padding(.bottom, Self.dialBottomSpacing)

            notes
                .padding(.top, Self.notesTopSpacing)

            // No target rows (4.7): rise/set bearings are in the moon card
            // above, and VoiceOver reads every target from the dial.
        }
        .animation(reduceMotion ? nil : Self.lockAnimation, value: viewModel.lockedKind)
        // One firm tap per lock acquired (4.5). Release and holding don't
        // change the count, so they're silent. System feedback follows the
        // user's System Haptics setting.
        .sensoryFeedback(.impact(weight: .heavy), trigger: viewModel.lockAcquisitionCount)
        // The aha line is spoken as it appears, wherever VoiceOver is.
        .onChange(of: viewModel.preciseConfirmation) { _, confirmation in
            guard let confirmation else { return }
            AccessibilityNotification.Announcement(confirmation).post()
        }
    }

    /// The heading ("72° ENE"), or locked, the amber pill ("Moonrise · 58°
    /// ENE", §3.3). One VoiceOver element either way: the heading, or
    /// "Compass accuracy is low" plus why when it can't be trusted (an
    /// untrustworthy number isn't read out), or "Pointing at moonrise, …".
    @ViewBuilder
    private var readout: some View {
        if let lockText = viewModel.lockText {
            Text(lockText)
                .font(Theme.Fonts.display)
                .foregroundStyle(Theme.Colors.onAccent)
                .padding(.vertical, Self.pillPaddingVertical)
                .padding(.horizontal, Self.pillPaddingHorizontal)
                .background(Theme.Colors.accent, in: Capsule())
                .shadow(color: Theme.Colors.accent.opacity(Self.pillGlowOpacity), radius: Self.pillGlowRadius)
                .transition(.opacity)
                .accessibilityLabel(viewModel.lockAccessibilityLabel ?? lockText)
        } else {
            Text(viewModel.headingText ?? "")
                .font(Theme.Fonts.display)
                .monospacedDigit()
                .foregroundStyle(viewModel.isLowAccuracy ? Theme.Colors.textSecondary : Theme.Colors.textPrimary)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(viewModel.headingAccessibilityLabel)
                .accessibilityAddTraits(.updatesFrequently)
        }
    }

    /// Under the dial: Nearby, which city the bearings are for.
    @ViewBuilder
    private var notes: some View {
        if let nearbyNote = viewModel.nearbyNote {
            CompassNote(text: nearbyNote)
        }
    }

    /// Under the readout (COMPASS-1.1.md §4.1): the status line (why
    /// accuracy is low, or for a moment the aha line), then Use Precise
    /// Location as a secondary button. Nothing, and no gap, while all's
    /// well. VoiceOver order is unchanged: the readout already says why,
    /// and the button comes after it.
    @ViewBuilder
    private var accuracyNotes: some View {
        if viewModel.statusLineText != nil || viewModel.offersPreciseLocation {
            statusNotes
                .padding(.top, Self.notesSpacing)
        }
    }

    private var statusNotes: some View {
        VStack(spacing: Self.notesSpacing) {
            if let statusLineText = viewModel.statusLineText {
                CompassNote(text: statusLineText)
                    .transition(.opacity)
                    // Already in the readout's spoken label, and the aha
                    // line is announced as it appears.
                    .accessibilityHidden(true)
            }

            // One button only (4.14): the alert is iOS's own (Don't Allow /
            // Allow Once), and permanent Precise lives in Settings.
            if viewModel.offersPreciseLocation {
                Button(CompassViewModel.usePreciseLocationTitle, action: onUsePreciseLocation)
                    .buttonStyle(.secondary)
                    .frame(maxWidth: Self.noteMaxWidth)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut, value: viewModel.preciseConfirmation)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top)
    }
    #endif

    // MARK: - Location off (§2)

    private var locationOffNote: some View {
        VStack(spacing: Self.notesSpacing) {
            CompassNote(text: CompassViewModel.locationOffHint)
            Button(CompassViewModel.turnOnLocationTitle, action: onTurnOnLocation)
                .buttonStyle(.secondary)
                .frame(maxWidth: Self.noteMaxWidth)
        }
    }
}

// MARK: - Previews

/// A compass fed from fakes: the simulator has no compass.
private struct CompassPreview: View {

    let context: CompassContext
    let reading: HeadingReading?
    /// Where the fake moon is: at this azimuth, up unless `isMoonUp` is
    /// false.
    var moonAzimuth = 140.0
    var isMoonUp = true

    @State private var heading = FakeHeadingService()
    @State private var viewModel: CompassViewModel?

    var body: some View {
        ScrollView {
            if let viewModel {
                CompassView(viewModel: viewModel, onTurnOnLocation: {}, onUsePreciseLocation: {})
                    .padding()
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
        }
        .background { ScreenBackground() }
        .task {
            let viewModel = CompassViewModel(
                headingService: heading,
                moonService: FakeMoonService(
                    position: MoonPosition(azimuth: moonAzimuth, isUp: isMoonUp),
                    pass: Self.pass
                )
            )
            viewModel.update(context)
            viewModel.setOnScreen(true)
            self.viewModel = viewModel
            // Let the view model's stream task start before sending.
            await Task.yield()
            if let reading { heading.send(reading) }
        }
    }

    /// A pass from moonrise at 72° to moonset at 288°, through the south,
    /// as `context` has them. Evenly spaced, which is close enough here.
    static let pass: MoonPass = {
        let riseAzimuth = 72.0
        let setAzimuth = 288.0
        let sampleStep = 4.0
        let rise = Date().addingTimeInterval(-6 * 60 * 60)
        let path = Array(stride(from: riseAzimuth, through: setAzimuth, by: sampleStep))
        return MoonPass(
            rise: MoonEvent(date: rise, azimuth: riseAzimuth),
            set: MoonEvent(date: rise.addingTimeInterval(Double(path.count - 1) * MoonPass.sampleInterval), azimuth: setAzimuth),
            path: path
        )
    }()

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
        auth: LocationAuthState = .authorized,
        preciseOff: Bool = false,
        phase: MoonPhase = .full,
        phaseAngle: Double = FakeMoonService.fullMoonPhaseAngle,
        illumination: Double = FakeMoonService.fullyLit
    ) -> CompassContext {
        let day = Date()
        return CompassContext(
            place: selected,
            detectedPlace: place,
            authState: auth,
            isPreciseLocationOff: preciseOff,
            moonDay: MoonDay(
                place: place,
                rise: MoonEvent(date: day, azimuth: 72),
                set: MoonEvent(date: day, azimuth: 288),
                phase: phase,
                phaseAngle: phaseAngle,
                illumination: illumination
            ),
            isToday: true
        )
    }
}

#Preview("Live") {
    CompassPreview(context: CompassPreview.context(), reading: HeadingReading(trueHeading: 100, accuracy: 3))
}

/// The device-test sky (2026-10-01): a waning gibbous Moon up in the west,
/// so the marker's terminator shows.
private let waningGibbous = CompassPreview.context(phase: .waningGibbous, phaseAngle: 240, illumination: 0.64)

#Preview("Moon up") {
    CompassPreview(context: waningGibbous, reading: HeadingReading(trueHeading: 240, accuracy: 3), moonAzimuth: 275)
}

#Preview("Moon down") {
    CompassPreview(
        context: waningGibbous,
        reading: HeadingReading(trueHeading: 240, accuracy: 3),
        moonAzimuth: 275,
        isMoonUp: false
    )
}

#Preview("Locked on the Moon") {
    CompassPreview(context: waningGibbous, reading: HeadingReading(trueHeading: 276, accuracy: 3), moonAzimuth: 275)
}

#Preview("Locked on moonrise") {
    CompassPreview(context: CompassPreview.context(), reading: HeadingReading(trueHeading: 74, accuracy: 3))
}

#Preview("Low accuracy") {
    CompassPreview(context: CompassPreview.context(), reading: HeadingReading(trueHeading: 200, accuracy: 30))
}

#Preview("Low accuracy, Precise Location off") {
    CompassPreview(context: CompassPreview.context(preciseOff: true), reading: HeadingReading(trueHeading: 200, accuracy: 30))
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
