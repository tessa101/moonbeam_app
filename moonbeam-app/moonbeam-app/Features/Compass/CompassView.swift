//
//  CompassView.swift
//  moonbeam-app
//

import SwiftUI

/// The compass block under the moon card (DESIGN-1.1.md §3.3, COMPASS.md
/// §1, §2): the heading readout (an amber pill when locked) and the dial,
/// both dimmed in low accuracy; or, in place of the compass, the Far or
/// location-off note. Its other notes (Precise Location, low accuracy,
/// Nearby, aha) are in `LocationScreen`'s bottom bar (COMPASS-1.1.md §9.4).
///
/// Every string and accessibility label comes from `CompassViewModel`.
/// Where it sits and when it counts as on screen is `LocationScreen`'s job.
struct CompassView: View {

    let viewModel: CompassViewModel

    /// The height the whole compass block (readout slot and dial) may use,
    /// from its top to the bottom padding kept under it; `nil` sizes the dial
    /// by the width alone (previews, before the screen has measured).
    var heightBudget: CGFloat?

    /// The hint's button: the existing Location Off flow (the system prompt
    /// if not yet asked, otherwise the Location Off dialog).
    let onTurnOnLocation: () -> Void

    /// The dial's centre, in global coordinates, whenever it moves: the
    /// pinned bar's rule (COMPASS-1.1.md §9.6) is `LocationScreen`'s.
    var onDialCentreChange: (CGFloat) -> Void = { _ in }

    /// The readout's top edge in global coordinates. The pinned summary must
    /// not appear while this full readout is still visible, or the two copies
    /// compete and the overlay can cover the original at large text sizes.
    var onReadoutTopChange: (CGFloat) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// When the block this compass loads in with starts to show, if it's
    /// loading in (LOADER.md §12.4): the settle waits for it.
    @Environment(\.contentRevealsAt) private var revealsAt

    /// The entrance's settle as drawn: snapped to the view model's start
    /// offset, then animated to 0 (§12.4).
    @State private var settleOffset = 0.0

    /// The default readout slot holds the dial still during lock changes.
    /// At AX sizes this is a minimum: wrapped pills reserve their full height.
    @ScaledMetric(relativeTo: .title2) private var readoutHeight = Self.readoutBaseHeight

    /// The block's width, which sizes the dial (COMPASS-1.1.md §9.3).
    @State private var availableWidth: CGFloat = 0

    // MARK: - Constants (§3.3, from the HTML)

    private static let readoutBaseHeight: CGFloat = 40
    /// Between the location-off note and its button.
    private static let notesSpacing: CGFloat = 10
    /// Buttons under a note are no wider than the widest note.
    private static let noteMaxWidth: CGFloat = 330

    /// The lock pill: padding 10 / 18 (COMPASS-1.1.md §9.12), `accent` glow
    /// 45% (CSS 36 px blur).
    private static let pillPaddingVertical: CGFloat = 10
    private static let pillPaddingHorizontal: CGFloat = 18
    private static let accessibilityPillCornerRadius: CGFloat = 24
    private static let pillGlowOpacity = 0.45
    private static let pillGlowRadius: CGFloat = 18

    private static let lockAnimation = Animation.easeOut(duration: 0.2)

    /// Low accuracy (§9.4): the readout and dial stay put and dim to half,
    /// and fade back in when it recovers.
    private static let lowAccuracyOpacity = 0.5
    private static let accuracyAnimation = Animation.easeInOut(duration: 0.3)

    // MARK: - Entrance (LOADER.md §12.4, §12.4.1)

    /// The compass fades in as the screen's blocks do.
    private static let entranceFade = Animation.easeOut(duration: ContentLoadIn.duration)
    private static func settleAnimation(delay: TimeInterval) -> Animation {
        .spring(duration: CompassEntrance.settleSeconds, bounce: 0).delay(delay)
    }

    /// The readout and the lock pill take turns (§12.4.1): one fades out,
    /// 150 ms, then the other fades in, so they never overlap.
    private static let readoutFadeDuration: TimeInterval = 0.15
    private static let readoutFadeOut = Animation.easeOut(duration: readoutFadeDuration)
    private static let readoutFadeIn = readoutFadeOut.delay(readoutFadeDuration)

    /// §12.4.1: the readout sits closer to the top tick. Tessa's start is
    /// half the gap, but at half a pill would cover the top of a Moon locked
    /// at 12 o'clock, so it stops this short of that mark (DECISIONS.md
    /// 2026-10-12). Tune on the device.
    private static let readoutGapShare: CGFloat = 0.5
    private static let pillOverflowAllowance: CGFloat = 6
    private static let readoutPull = min(
        CompassDial.readoutSlotToRimGap * readoutGapShare,
        CompassDial.readoutSlotToRimGap - CompassDial.lockedMarkReach - pillOverflowAllowance
    )

    /// What restarts the drawn settle: a new entrance, or this one starting
    /// to settle.
    private struct SettleTrigger: Equatable {
        let generation: Int
        let isSettling: Bool
    }

    // MARK: - Location swap (LOCATION-OFF-FLOW.md §5.2)

    /// The block's height while it's held over the compass coming in, so the
    /// slot doesn't jump to the dial's height before the dial shows.
    @State private var locationOffBlockHeight: CGFloat?

    /// Set when a hand-over ends; VoiceOver moves to the dial once it's in.
    @State private var dialFocusRequest: Int?
    @AccessibilityFocusState private var dialFocus: DialFocus?

    /// The dial, or the heading readout if the dial has nothing to read.
    private enum DialFocus: Hashable {
        case dial
        case readout
    }

    /// Each side brings its own animation, so one passing through the screen
    /// (the bottom bar's) can't retime the swap (5.12b.3b part 1).
    private var locationOffBlockTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity
                .combined(with: .offset(y: LocationOffSwap.blockInRise(reduceMotion: reduceMotion)))
                .animation(.easeOut(duration: LocationOffSwap.blockInDuration).delay(LocationOffSwap.blockInDelay)),
            removal: .opacity.animation(.easeOut(duration: LocationOffSwap.blockOutDuration))
        )
    }

    /// The dial is inserted unseen (its entrance fades it in) and fades out.
    private static let compassTransition = AnyTransition.asymmetric(
        insertion: .identity,
        removal: .opacity.animation(.easeOut(duration: LocationOffSwap.dialOutDuration))
    )

    private static let heightAnimationLocationOn = Animation.easeOut(duration: LocationOffSwap.heightDurationLocationOn)
    private static let heightAnimationLocationOff = Animation.easeOut(duration: LocationOffSwap.heightDurationLocationOff)

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // One slot: the block stays over the compass while it comes in.
            ZStack(alignment: .top) {
                switch viewModel.visibility {
                case .here, .nearby:
                    compass
                        .transition(Self.compassTransition)
                case .far:
                    if let farMessage = viewModel.farMessage {
                        CompassNote(text: farMessage)
                    }
                case .locationOff, .hidden:
                    EmptyView()
                }

                if let block = viewModel.locationOffBlock {
                    locationOffNote(block)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                            locationOffBlockHeight = height
                        }
                        .allowsHitTesting(!viewModel.isLocationOffBlockHeld)
                        .transition(locationOffBlockTransition)
                }
            }
            .frame(
                height: viewModel.isLocationOffBlockHeld ? locationOffBlockHeight : nil,
                alignment: .top
            )
            // Off to on, the slot grows with the dial's fade (the inner one
            // wins when both change); on to off, it shrinks with the dial's.
            .animation(Self.heightAnimationLocationOn, value: viewModel.isLocationOffBlockHeld)
            .animation(Self.heightAnimationLocationOff, value: viewModel.locationOffBlock != nil)
        }
        .frame(maxWidth: .infinity)
        .onChange(of: viewModel.locationOnCount) { _, count in
            dialFocusRequest = count
        }
        // §3.3: on location on, VoiceOver moves to the dial once it has
        // faded in, not while it's still out.
        .task(id: dialFocusRequest) {
            guard dialFocusRequest != nil else { return }
            try? await Task.sleep(for: .seconds(LocationOffSwap.dialInDuration))
            guard !Task.isCancelled, viewModel.entrance.showsCompass else { return }
            dialFocus = viewModel.targetsAccessibilityLabel != nil ? .dial : .readout
        }
    }

    // MARK: - Compass

    /// The width's size (§9.3), pulled in on shorter screens so the dial,
    /// its arc and labels end above the bottom padding. The readout slot
    /// takes its height from the budget first.
    private var faceDiameter: CGFloat {
        CompassDial.faceDiameter(
            forWidth: availableWidth,
            dialHeightBudget: heightBudget.map { $0 - readoutHeight + Self.readoutPull },
            isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
        )
    }

    private var compass: some View {
        // The dial's frame keeps room for a label above the arc, so it sits
        // right under the readout's slot (the fit report has the gaps).
        VStack(spacing: 0) {
            readout
                .fixedSize(horizontal: false, vertical: true)
                .frame(
                    minHeight: readoutHeight,
                    maxHeight: dynamicTypeSize.isAccessibilitySize ? nil : readoutHeight
                )
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.frame(in: .global).minY
                } action: { minY in
                    onReadoutTopChange(minY)
                }
                // Over the dial's frame, now that it reaches up under the
                // slot (§12.4.1).
                .zIndex(1)

            CompassDial(
                faceDiameter: faceDiameter,
                heading: viewModel.heading,
                targets: viewModel.targets,
                lockedKind: viewModel.lockedKind,
                accessibilityTargets: viewModel.targetsAccessibilityLabel,
                moonGlyph: viewModel.moonGlyph,
                arc: viewModel.arc,
                showsMoonPulse: viewModel.showsMoonPulse,
                settleOffset: reduceMotion ? 0 : settleOffset
            )
            .accessibilityFocused($dialFocus, equals: .dial)
            // The dial's frame is symmetric about the face's centre.
            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).midY } action: { centreY in
                onDialCentreChange(centreY)
            }
            // After the centre is read, so it stays the face's (§12.4.1).
            // Wrapped lock text needs its natural height and the full gap
            // above the needle and target labels.
            .padding(.top, dynamicTypeSize.isAccessibilitySize ? 0 : -Self.readoutPull)

            // No target rows (4.7): rise/set bearings are in the moon card
            // above, and VoiceOver reads every target from the dial.
        }
        .opacity(viewModel.isLowAccuracy && viewModel.reading != nil ? Self.lowAccuracyOpacity : 1)
        .animation(reduceMotion ? nil : Self.accuracyAnimation, value: viewModel.isLowAccuracy)
        // §12.4: out until the first heading (or its wait) is over, so the
        // dial never shows north-up first. Reduce Motion fades too.
        .opacity(viewModel.entrance.showsCompass ? 1 : 0)
        .animation(Self.entranceFade, value: viewModel.entrance.showsCompass)
        .accessibilityHidden(!viewModel.entrance.showsCompass)
        .task(id: SettleTrigger(
            generation: viewModel.entrance.generation,
            isSettling: viewModel.entrance.phase == .settling
        )) {
            await runSettle()
        }
        .animation(reduceMotion ? nil : Self.lockAnimation, value: viewModel.lockedKind)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
            availableWidth = width
        }
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

    /// The settle as drawn (§12.4): snap to the view model's start offset,
    /// then ease to 0 once the block is showing. Reduce Motion: none.
    private func runSettle() async {
        guard viewModel.entrance.phase == .settling, !reduceMotion else { return }
        var snap = Transaction()
        snap.disablesAnimations = true
        withTransaction(snap) {
            settleOffset = viewModel.entrance.startOffset
        }
        // Let the snap land before animating away from it.
        await Task.yield()
        let delay = max(revealsAt?.timeIntervalSinceNow ?? 0, 0)
        withAnimation(Self.settleAnimation(delay: delay)) {
            settleOffset = 0
        }
    }

    /// The heading ("72° ENE"), or locked, the amber pill ("Moonrise · 58°
    /// ENE", §3.3). One VoiceOver element either way: the heading, or
    /// "Compass accuracy is low" plus why when it can't be trusted (an
    /// untrustworthy number isn't read out), or "Pointing at moonrise, …".
    ///
    /// §12.4.1: the heading stays in its slot and fades out as a lock
    /// engages, then the pill fades in alone; on release the pill goes and
    /// the heading fades back. The entrance holds the heading out too.
    @ViewBuilder
    private var readout: some View {
        ZStack {
            let showsHeading = viewModel.readoutOpacity > 0
            Self.text(for: viewModel.headingReadout)
                .monospacedDigit()
                .foregroundStyle(Theme.Colors.textPrimary)
                .opacity(viewModel.readoutOpacity)
                .animation(showsHeading ? Self.readoutFadeIn : Self.readoutFadeOut, value: showsHeading)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(viewModel.headingAccessibilityLabel)
                .accessibilityAddTraits(.updatesFrequently)
                .accessibilityHidden(viewModel.lockText != nil)
                .accessibilityFocused($dialFocus, equals: .readout)
            if let lockText = viewModel.lockText, let lockReadout = viewModel.lockReadout {
                Self.text(for: lockReadout)
                    .foregroundStyle(Theme.Colors.onAccent)
                    .padding(.vertical, Self.pillPaddingVertical)
                    .padding(.horizontal, Self.pillPaddingHorizontal)
                    .multilineTextAlignment(.center)
                    .background {
                        if dynamicTypeSize.isAccessibilitySize {
                            // A tall capsule curves behind the first and last
                            // lines. Gentle corners keep wrapped text inside.
                            RoundedRectangle(cornerRadius: Self.accessibilityPillCornerRadius)
                                .fill(Theme.Colors.accent)
                        } else {
                            Capsule().fill(Theme.Colors.accent)
                        }
                    }
                    .shadow(color: Theme.Colors.accent.opacity(Self.pillGlowOpacity), radius: Self.pillGlowRadius)
                    .transition(.asymmetric(
                        insertion: .opacity.animation(Self.readoutFadeIn),
                        removal: .opacity.animation(Self.readoutFadeOut)
                    ))
                    .accessibilityLabel(viewModel.lockAccessibilityLabel ?? lockText)
            }
        }
    }

    /// "Moonrise · 58°" at the card's time size, then "ENE" in capitals at
    /// 0.7x on the same baseline (COMPASS-1.1.md §9.12). Empty with no
    /// heading. The pinned bar uses it too, so the two read alike.
    static func text(for readout: CompassReadout?) -> Text {
        guard let readout else { return Text(verbatim: "") }
        let lead = Text(verbatim: readout.lead + CompassReadout.separator).font(Theme.Fonts.readout)
        let direction = Text(verbatim: readout.direction).font(Theme.Fonts.readoutDirection)
        return Text("\(lead)\(direction)")
    }

    // MARK: - Location off (§2)

    /// Where the user can turn location on, one card holding the prompt
    /// (LOCATION-OFF-FLOW.md §2) or, after Maybe later, the guide row (§3,
    /// §5.3); where they can't (restricted), the plain note, since there's
    /// nothing to show off that they could reach. Drawn from `block`, which
    /// is held while location comes on (§5.2).
    @ViewBuilder
    private func locationOffNote(_ block: LocationOffBlock) -> some View {
        if block.showsPrompt {
            LocationOffCard(
                isCollapsed: block.isCollapsed,
                ghost: block.ghost,
                row: block.row,
                isRowActive: block.isRowActive,
                onTurnOnLocation: onTurnOnLocation,
                onMaybeLater: viewModel.dismissLocationPrompt,
                onRowTap: viewModel.reopenLocationPrompt
            )
        } else {
            VStack(spacing: Self.notesSpacing) {
                CompassNote(text: CompassViewModel.locationOffHint)
                turnOnLocationButton
            }
        }
    }

    /// The existing Location Off flow's button, under the restricted note.
    private var turnOnLocationButton: some View {
        Button(CompassViewModel.turnOnLocationTitle, action: onTurnOnLocation)
            .buttonStyle(.secondary)
            .frame(maxWidth: Self.noteMaxWidth)
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
                CompassView(viewModel: viewModel, onTurnOnLocation: {})
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
                    position: MoonPosition(azimuth: moonAzimuth, altitude: 23, isUp: isMoonUp),
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

#Preview("Location off, restricted") {
    CompassPreview(context: CompassPreview.context(auth: .restricted), reading: nil)
}
