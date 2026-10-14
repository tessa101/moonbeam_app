//
//  DebugScreenState.swift
//  moonbeam-app
//

#if DEBUG
import SwiftUI

/// The whole main screen in each compass state (COMPASS-1.1.md §9.5), from
/// fakes, for screenshots and the fit report: the simulator has no compass,
/// so locks and good headings can only be shown this way. DEBUG only.
///
/// Launch with `-screenState <kind>` (e.g. `-screenState lockedOnMoon`) and
/// the app opens on this instead of onboarding or the real services, so it
/// can be captured on any simulator and text size; previews below too.
///
/// The design's sky (as `MoonCard`'s previews): Irvine, detected, at 7:53 AM
/// on Fri, Oct 2, 2026, the moon up at 266° W on the pass from 10:06 PM to
/// 1:28 PM; moonrise 11:10 PM at 57°, moonset 1:28 PM at 304°. The
/// no-moonrise day is the real engine's Irvine on Sat, Oct 3.
struct DebugScreenState: View {

    enum Kind: String, CaseIterable {
        case moonUp, lockedOnMoon, lockedOnRise, lockedOnSet, moonDown, moonSetForToday, otherDate
        case preciseOff, lowAccuracy, aha, nearby, locationOff, far, noMoonrise
        /// "Waning Crescent · 29% lit": the widest phase line, moon up.
        case longPhaseName
        /// The launch loader (LOADER.md §3): the fix hangs, so the phase
        /// cycle runs until the 10 s timeout, then No fix (§10.1).
        case loading
        /// A launch whose fix lands at 150 ms (no loader) or 2.5 s (the
        /// phase cycle), then the moon-up screen loading in (LOADER.md §2.1).
        case launchFast, launchSlow
        /// A launch with no saved place, and the permission state (or, for
        /// No fix, a fix that fails) behind it: First ask stops the loader
        /// on its message (LOADER.md §10.3); the four causes open their
        /// failure screen (STEP-5.10a-LOCATION-CONSOLIDATION.md §2). Names
        /// kept from when all five were loader messages.
        case messageFirstAsk, messageDenied, messageServicesOff, messageRestricted, messageNoFix
        /// "Aha" after a recovery (LOADER.md §10.4): the launch's No fix
        /// screen, then a fix lands and a return to the app is played for
        /// you (No fix looks again then, Chunk 2b), so "Aha" and the fly
        /// into the card follow.
        case recoveryAha
        /// The location failure screen (STEP-5.10a): Irvine saved and
        /// shown, then Use my location fails for the cause, through the
        /// real wiring (Chunk 3), so recovery and city search work too.
        case locationFailedDenied = "locationFailed.denied"
        case locationFailedServicesOff = "locationFailed.servicesOff"
        case locationFailedNoFix = "locationFailed.noFix"
        case locationFailedRestricted = "locationFailed.restricted"
        /// No fix whose look on return fails too (`locationFailed.noFix`'s
        /// succeeds).
        case locationFailedNoFixAgain = "locationFailed.noFixAgain"
        /// The compass's Location Off dialog (LOCATION-SHEET.md, 5.12a) over
        /// the saved Irvine, opened straight away: restricted can't be set
        /// on the simulator, and the dialog only opens from a tap.
        case locationOffDialogDenied = "locationOffDialog.denied"
        case locationOffDialogServicesOff = "locationOffDialog.servicesOff"
        case locationOffDialogRestricted = "locationOffDialog.restricted"
        /// Location off over the saved Irvine (LOCATION-OFF-FLOW.md, 5.12b):
        /// after Maybe later, so the compass guide row shows; and restricted,
        /// which keeps the chip and can't be set on the simulator.
        case locationOffDismissed = "locationOff.dismissed"
        case locationOffRestricted = "locationOff.restricted"
        /// Location off with the moon down, so the prompt's ring puts its
        /// moon marker at the arc's midpoint (5.12b.1a).
        case locationOffMoonDown = "locationOff.moonDown"
        /// The guide row after Maybe later (LOCATION-OFF-FLOW.md §3.1), on
        /// the fixed 7:53 AM clock: S2 waiting (next rise 5 h off), S3
        /// (2 hr 15 min), S4 (40 min), S5 (rose 5 min ago), S6 (up since
        /// last night).
        case locationGuideS2 = "locationGuide.s2"
        case locationGuideS3 = "locationGuide.s3"
        case locationGuideS4 = "locationGuide.s4"
        case locationGuideS5 = "locationGuide.s5"
        case locationGuideS6 = "locationGuide.s6"

        var locationFailure: LocationFailure? {
            switch self {
            case .locationFailedDenied: .permissionDenied
            case .locationFailedServicesOff: .servicesOff
            case .locationFailedNoFix, .locationFailedNoFixAgain: .noFix
            case .locationFailedRestricted: .restricted
            default: nil
            }
        }

        var locationOffVariant: LocationViewModel.LocationOffVariant? {
            switch self {
            case .locationOffDialogDenied: .denied
            case .locationOffDialogServicesOff: .servicesOff
            case .locationOffDialogRestricted: .restricted
            default: nil
            }
        }

        /// The home screen with location off, over the saved Irvine.
        var isLocationOff: Bool {
            [.locationOff, .locationOffDismissed, .locationOffRestricted, .locationOffMoonDown].contains(self)
                || isLocationGuide
        }

        /// One of the guide row's states, after Maybe later.
        var isLocationGuide: Bool {
            [.locationGuideS2, .locationGuideS3, .locationGuideS4, .locationGuideS5, .locationGuideS6].contains(self)
        }

        /// Leaving the app stands for a trip to Settings that turns access
        /// on, so Open Settings → back can be recorded (the fakes can't hear
        /// the real Settings app).
        var grantsAccessInSettings: Bool {
            [.locationFailedDenied, .locationFailedServicesOff, .messageDenied, .messageServicesOff].contains(self)
        }
    }

    /// The launch argument, then the kind's name.
    static let launchArgument = "-screenState"

    /// The kind named after `-screenState`, if any.
    static func kind(fromLaunchArguments arguments: [String]) -> Kind? {
        guard let index = arguments.firstIndex(of: launchArgument), arguments.indices.contains(index + 1) else {
            return nil
        }
        return Kind(rawValue: arguments[index + 1])
    }

    let state: Kind

    @State private var fixture: Fixture
    @Environment(\.scenePhase) private var scenePhase

    init(_ state: Kind) {
        self.state = state
        _fixture = State(initialValue: Fixture(state))
    }

    var body: some View {
        LocationScreen(viewModel: fixture.viewModel)
            .task {
                await fixture.apply(state)
            }
            .onChange(of: scenePhase) { _, phase in
                // Before the return's `sceneDidBecomeActive` reads it.
                if phase == .background, state.grantsAccessInSettings {
                    fixture.grantAccess()
                }
            }
    }

    // MARK: - Fixture

    /// The view model and the fakes behind it.
    @MainActor
    private final class Fixture {

        let viewModel: LocationViewModel
        let heading = FakeHeadingService()
        let location: FakeLocationService
        /// Irvine, as detected.
        private let here: Place

        // MARK: Sky

        private static let zone = Place.irvine.timeZone
        private static let moonAzimuth = 266.0
        private static let riseAzimuth = 57.0
        private static let setAzimuth = 304.0
        /// Well inside, and well outside, the compass's accuracy threshold.
        private static let goodAccuracy = 3.0
        private static let poorAccuracy = 30.0
        /// Unlocked: the Moon 26° right of the needle, so "Now" shows.
        private static let unlockedHeading = 240.0
        private static let moonDownHeading = 34.0
        /// Within the lock's tolerance of each target, not on it.
        private static let lockOffset = 1.0
        private static let minutesToRise = 34.0
        private static let secondsPerMinute = 60.0
        /// Longer than the 10 s launch timeout, which ends it.
        private static let hangingFixDelay = Duration.seconds(30)
        /// Either side of the 400 ms phase-cycle delay.
        private static let fastFixDelay = Duration.milliseconds(150)
        private static let slowFixDelay = Duration.milliseconds(2500)

        /// About 110 mi from Irvine: Far.
        private static let sanDiego = Place(
            name: "San Diego",
            region: "CA",
            latitude: 32.72,
            longitude: -117.16,
            timeZone: zone
        )

        private static func time(_ day: Int, _ hour: Int, _ minute: Int) -> Date {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = zone
            return calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute)) ?? .now
        }

        init(_ state: Kind) {
            let here = Place(
                name: Place.irvine.name,
                region: Place.irvine.region,
                latitude: Place.irvine.latitude,
                longitude: Place.irvine.longitude,
                timeZone: Self.zone,
                isCurrentLocation: true
            )
            self.here = here
            let now = if state == .noMoonrise {
                Self.time(3, 7, 53)
            } else if state == .moonSetForToday {
                Self.time(2, 19, 0)
            } else {
                Self.time(2, 7, 53)
            }
            let authState: LocationAuthState = switch state {
            case .locationOff, .locationOffDismissed, .locationOffMoonDown,
                 .locationGuideS2, .locationGuideS3, .locationGuideS4, .locationGuideS5, .locationGuideS6,
                 .messageDenied, .locationFailedDenied, .locationOffDialogDenied: .denied
            case .messageFirstAsk: .notDetermined
            case .messageServicesOff, .locationFailedServicesOff, .locationOffDialogServicesOff: .servicesOff
            case .messageRestricted, .locationFailedRestricted, .locationOffDialogRestricted, .locationOffRestricted:
                .restricted
            default: .authorized
            }
            let placeResult: Result<Place, any Error> = switch state {
            case .messageNoFix, .recoveryAha, .locationFailedNoFix, .locationFailedNoFixAgain:
                .failure(LocationError.locationUnavailable)
            default: .success(here)
            }
            location = FakeLocationService(authorizationState: authState, placeResult: placeResult)
            location.isPreciseLocationOff = state == .preciseOff || state == .aha
            if state == .aha {
                location.preciseOffAfterTemporaryRequest = false
            }
            switch state {
            case .loading: location.fixDelay = Self.hangingFixDelay
            case .launchFast: location.fixDelay = Self.fastFixDelay
            case .launchSlow: location.fixDelay = Self.slowFixDelay
            default: break
            }

            let moonService: any MoonService
            if state == .noMoonrise {
                moonService = AstronomyEngineMoonService()
            } else {
                let moon = Self.fakeMoon(
                    isUp: state != .moonDown && state != .moonSetForToday && state != .locationOffMoonDown,
                    setForToday: state == .moonSetForToday,
                    longPhaseName: state == .longPhaseName,
                    now: now
                )
                Self.applyGuideState(state, to: moon, now: now)
                moonService = moon
            }
            viewModel = LocationViewModel(
                locationService: location,
                placeSearch: FakePlaceSearchService(),
                placeStore: InMemoryPlaceStore(
                    lastViewed: state.isLocationOff || state.locationFailure != nil || state.locationOffVariant != nil
                        ? Place.irvine : nil
                ),
                moonService: moonService,
                headingService: heading,
                onboardingStore: InMemoryOnboardingStore(
                    locationPromptDismissed: state == .locationOffDismissed || state.isLocationGuide
                ),
                deviceTimeZone: Self.zone,
                now: { now }
            )
        }

        /// Last quarter, 53% (the design's); or a waning crescent, 29%.
        private static let lastQuarter = (phaseAngle: 270.0, illumination: 0.53)
        private static let waningCrescent = (phaseAngle: 300.0, illumination: 0.29)

        private static func fakeMoon(isUp: Bool, setForToday: Bool, longPhaseName: Bool, now: Date) -> FakeMoonService {
            let phase = longPhaseName ? waningCrescent : lastQuarter
            let moon = FakeMoonService(
                rise: MoonEvent(date: setForToday ? time(2, 0, 20) : time(2, 23, 10), azimuth: riseAzimuth),
                set: MoonEvent(date: time(2, 13, 28), azimuth: setAzimuth),
                phaseAngle: phase.phaseAngle,
                illumination: phase.illumination,
                position: MoonPosition(azimuth: moonAzimuth, altitude: 23, isUp: isUp),
                pass: MoonPass(
                    rise: MoonEvent(date: time(1, 22, 6), azimuth: 56),
                    set: MoonEvent(date: time(2, 13, 28), azimuth: setAzimuth),
                    path: [56, 180, setAzimuth]
                )
            )
            moon.nextRise = MoonEvent(
                date: setForToday ? time(3, 0, 20) : now.addingTimeInterval(minutesToRise * secondsPerMinute),
                azimuth: riseAzimuth
            )
            return moon
        }

        /// The guide row's states: where the moon is, and when it rose or
        /// rises next, against the fixed clock.
        private static func applyGuideState(_ state: Kind, to moon: FakeMoonService, now: Date) {
            let down = MoonPosition(azimuth: moonAzimuth, isUp: false)
            func rise(inMinutes minutes: Double) -> MoonEvent {
                MoonEvent(date: now.addingTimeInterval(minutes * secondsPerMinute), azimuth: riseAzimuth)
            }
            switch state {
            case .locationGuideS2:
                moon.position = down
                moon.nextRise = rise(inMinutes: guideWaitingMinutes)
            case .locationGuideS3:
                moon.position = down
                moon.nextRise = rise(inMinutes: guideHoursMinutes)
            case .locationGuideS4:
                moon.position = down
                moon.nextRise = rise(inMinutes: guideMinutesMinutes)
            case .locationGuideS5:
                moon.position = MoonPosition(azimuth: riseAzimuth + 1, altitude: 1, isUp: true)
                if let pass = moon.pass {
                    moon.pass = MoonPass(rise: rise(inMinutes: -guideRoseMinutesAgo), set: pass.set, path: pass.path)
                }
            case .locationGuideS6:
                // Up since last night, on the fixture's own pass.
                break
            default:
                break
            }
        }

        /// The guide states' times: 5 h, 2 hr 15 min and 40 min to the next
        /// rise, and a rise 5 min ago.
        private static let guideWaitingMinutes = 300.0
        private static let guideHoursMinutes = 135.0
        private static let guideMinutesMinutes = 40.0
        private static let guideRoseMinutesAgo = 5.0

        /// Polls for the screen's own start to show a place.
        private static let pollInterval = Duration.milliseconds(10)
        private static let pollLimit = 200
        /// The launch kinds wait up to the 10 s launch timeout.
        private static let launchPollLimit = 1_000

        /// How long `recoveryAha` sits on No fix before the return.
        private static let recoveryMessageHold = Duration.seconds(1.5)
        /// How long `recoveryAha`'s fix takes after the return: past the
        /// label's 0.7 s, like a real fix, so the label leaves at the fix
        /// (LOADER.md §11.2.1).
        private static let recoveryFixDelay = Duration.seconds(1)
        /// `locationFailedNoFixAgain`'s look on return: long enough to see the
        /// loader before the failure screen is back (a real miss is 10 s).
        private static let failAgainFixDelay = Duration.seconds(2.5)

        /// `grantsAccessInSettings`: access is on, and a fix will land.
        func grantAccess() {
            location.authorizationState = .authorized
            location.placeResult = .success(here)
            location.fixDelay = Self.recoveryFixDelay
        }

        private static let messageKinds: Set<Kind> = [
            .messageFirstAsk, .messageDenied, .messageServicesOff, .messageRestricted, .messageNoFix,
        ]

        /// Once the screen's own start has shown a place (detection has
        /// run), the place and day can change, and the compass can be fed a
        /// heading.
        func apply(_ state: Kind) async {
            if state == .recoveryAha {
                await recover()
                return
            }
            // The launch destinations are the screen's own launch;
            // nothing to fake on top.
            guard state != .loading, !Self.messageKinds.contains(state) else { return }
            let limit = state == .launchFast || state == .launchSlow ? Self.launchPollLimit : Self.pollLimit
            for _ in 0..<limit where viewModel.moonTable == nil {
                try? await Task.sleep(for: Self.pollInterval)
            }
            if state.locationFailure != nil {
                // The launch must be over first: tapped while `start()` is
                // still finishing, the launch would see no place and stop
                // on the loader's message instead.
                for _ in 0..<limit where viewModel.launchStage != .ready {
                    try? await Task.sleep(for: Self.pollInterval)
                }
                await viewModel.useMyLocation()
                // What a return to the app finds, after a GPS-like wait.
                switch state {
                case .locationFailedNoFix:
                    location.placeResult = .success(here)
                    location.fixDelay = Self.recoveryFixDelay
                case .locationFailedNoFixAgain:
                    location.fixDelay = Self.failAgainFixDelay
                default:
                    break
                }
                return
            }
            if let variant = state.locationOffVariant {
                viewModel.locationOffDialog = variant
                return
            }
            switch state {
            case .otherDate: viewModel.nextDay()
            case .nearby: viewModel.select(Place.marVista)
            case .far: viewModel.select(Self.sanDiego)
            case .aha: await viewModel.usePreciseLocationForCompass()
            default: break
            }
            guard !state.isLocationOff, state != .far else { return }
            viewModel.compass.setOnScreen(true)
            // Let the compass's stream task start before sending.
            await Task.yield()
            heading.send(Self.reading(for: state))
        }

        /// Waits for No fix, lets it show, then a fix lands and the app returns.
        private func recover() async {
            for _ in 0..<Self.launchPollLimit where viewModel.failureScreen != .noFix {
                try? await Task.sleep(for: Self.pollInterval)
            }
            try? await Task.sleep(for: Self.recoveryMessageHold)
            location.placeResult = .success(here)
            location.fixDelay = Self.recoveryFixDelay
            await viewModel.sceneDidBecomeActive()
        }

        private static func reading(for state: Kind) -> HeadingReading {
            switch state {
            case .lockedOnMoon: HeadingReading(trueHeading: moonAzimuth + lockOffset, accuracy: goodAccuracy)
            case .lockedOnRise: HeadingReading(trueHeading: riseAzimuth + lockOffset, accuracy: goodAccuracy)
            case .lockedOnSet: HeadingReading(trueHeading: setAzimuth + lockOffset, accuracy: goodAccuracy)
            case .moonDown, .moonSetForToday: HeadingReading(trueHeading: moonDownHeading, accuracy: goodAccuracy)
            case .preciseOff, .lowAccuracy: HeadingReading(trueHeading: unlockedHeading, accuracy: poorAccuracy)
            default: HeadingReading(trueHeading: unlockedHeading, accuracy: goodAccuracy)
            }
        }
    }
}

// MARK: - Previews (COMPASS-1.1.md §9.5, in that order)

#Preview("1 Moon up") { DebugScreenState(.moonUp) }
#Preview("2 Locked on Moon") { DebugScreenState(.lockedOnMoon) }
#Preview("3 Locked on rise") { DebugScreenState(.lockedOnRise) }
#Preview("4 Locked on set") { DebugScreenState(.lockedOnSet) }
#Preview("5 Moon down") { DebugScreenState(.moonDown) }
#Preview("6 Set for today") { DebugScreenState(.moonSetForToday) }
#Preview("7 Other date") { DebugScreenState(.otherDate) }
#Preview("7 Precise off") { DebugScreenState(.preciseOff) }
#Preview("8 Low accuracy") { DebugScreenState(.lowAccuracy) }
#Preview("9 Aha") { DebugScreenState(.aha) }
#Preview("10 Nearby") { DebugScreenState(.nearby) }
#Preview("11 Location off") { DebugScreenState(.locationOff) }
#Preview("11a Location off, Maybe later") { DebugScreenState(.locationOffDismissed) }
#Preview("11b Location off, restricted") { DebugScreenState(.locationOffRestricted) }
#Preview("11c Location off, moon down") { DebugScreenState(.locationOffMoonDown) }
#Preview("11d Guide S2") { DebugScreenState(.locationGuideS2) }
#Preview("11e Guide S3") { DebugScreenState(.locationGuideS3) }
#Preview("11f Guide S4") { DebugScreenState(.locationGuideS4) }
#Preview("11g Guide S5") { DebugScreenState(.locationGuideS5) }
#Preview("11h Guide S6") { DebugScreenState(.locationGuideS6) }
#Preview("12 Far") { DebugScreenState(.far) }
#Preview("13 No moonrise, Sat Oct 3") { DebugScreenState(.noMoonrise) }
#Preview("14 Long phase name") { DebugScreenState(.longPhaseName) }
#Preview("15 Launch loader") { DebugScreenState(.loading) }
#Preview("16 Fast launch") { DebugScreenState(.launchFast) }
#Preview("17 Slow launch") { DebugScreenState(.launchSlow) }
#Preview("18 Message: First ask") { DebugScreenState(.messageFirstAsk) }
#Preview("19 Launch: App permission off") { DebugScreenState(.messageDenied) }
#Preview("20 Launch: Services off") { DebugScreenState(.messageServicesOff) }
#Preview("21 Launch: Restricted") { DebugScreenState(.messageRestricted) }
#Preview("22 Launch: No fix") { DebugScreenState(.messageNoFix) }
#Preview("23 Aha after a recovery") { DebugScreenState(.recoveryAha) }
#Preview("24 Failed: App permission off") { DebugScreenState(.locationFailedDenied) }
#Preview("25 Failed: Services off") { DebugScreenState(.locationFailedServicesOff) }
#Preview("26 Failed: No fix") { DebugScreenState(.locationFailedNoFix) }
#Preview("27 Failed: Restricted") { DebugScreenState(.locationFailedRestricted) }
#Preview("28 Failed: No fix, looking again fails too") { DebugScreenState(.locationFailedNoFixAgain) }
#endif
