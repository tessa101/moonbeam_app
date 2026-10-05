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
        case moonUp, lockedOnMoon, lockedOnRise, lockedOnSet, moonDown, otherDate
        case preciseOff, lowAccuracy, aha, nearby, locationOff, far, noMoonrise
        /// "Waning Crescent · 29% lit": the widest phase line, moon up.
        case longPhaseName
        /// The launch loader (LOADER.md §3): the fix hangs, so the phase
        /// cycle runs until the 10 s timeout, then the empty state.
        case loading
        /// A launch whose fix lands at 150 ms (no loader) or 2.5 s (the
        /// phase cycle), then the moon-up screen loading in (LOADER.md §2.1).
        case launchFast, launchSlow
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

    init(_ state: Kind) {
        self.state = state
        _fixture = State(initialValue: Fixture(state))
    }

    var body: some View {
        LocationScreen(viewModel: fixture.viewModel)
            .task {
                await fixture.apply(state)
            }
    }

    // MARK: - Fixture

    /// The view model and the fakes behind it.
    @MainActor
    private final class Fixture {

        let viewModel: LocationViewModel
        let heading = FakeHeadingService()
        let location: FakeLocationService

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
            let now = state == .noMoonrise ? Self.time(3, 7, 53) : Self.time(2, 7, 53)
            let authState: LocationAuthState = state == .locationOff ? .denied : .authorized
            location = FakeLocationService(authorizationState: authState, placeResult: .success(here))
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

            let moonService: any MoonService = if state == .noMoonrise {
                AstronomyEngineMoonService()
            } else {
                Self.fakeMoon(isUp: state != .moonDown, longPhaseName: state == .longPhaseName, now: now)
            }
            viewModel = LocationViewModel(
                locationService: location,
                placeSearch: FakePlaceSearchService(),
                placeStore: InMemoryPlaceStore(lastViewed: state == .locationOff ? Place.irvine : nil),
                moonService: moonService,
                headingService: heading,
                deviceTimeZone: Self.zone,
                now: { now }
            )
        }

        /// Last quarter, 53% (the design's); or a waning crescent, 29%.
        private static let lastQuarter = (phaseAngle: 270.0, illumination: 0.53)
        private static let waningCrescent = (phaseAngle: 300.0, illumination: 0.29)

        private static func fakeMoon(isUp: Bool, longPhaseName: Bool, now: Date) -> FakeMoonService {
            let phase = longPhaseName ? waningCrescent : lastQuarter
            let moon = FakeMoonService(
                rise: MoonEvent(date: time(2, 23, 10), azimuth: riseAzimuth),
                set: MoonEvent(date: time(2, 13, 28), azimuth: setAzimuth),
                phaseAngle: phase.phaseAngle,
                illumination: phase.illumination,
                position: MoonPosition(azimuth: moonAzimuth, isUp: isUp),
                pass: MoonPass(
                    rise: MoonEvent(date: time(1, 22, 6), azimuth: 56),
                    set: MoonEvent(date: time(2, 13, 28), azimuth: setAzimuth),
                    path: [56, 180, setAzimuth]
                )
            )
            moon.nextRise = MoonEvent(date: now.addingTimeInterval(minutesToRise * secondsPerMinute), azimuth: riseAzimuth)
            return moon
        }

        /// Polls for the screen's own start to show a place.
        private static let pollInterval = Duration.milliseconds(10)
        private static let pollLimit = 200
        /// The launch kinds wait up to the 10 s launch timeout.
        private static let launchPollLimit = 1_000

        /// Once the screen's own start has shown a place (detection has
        /// run), the place and day can change, and the compass can be fed a
        /// heading.
        func apply(_ state: Kind) async {
            // The loader is the screen's own launch; nothing to fake on top.
            guard state != .loading else { return }
            let limit = state == .launchFast || state == .launchSlow ? Self.launchPollLimit : Self.pollLimit
            for _ in 0..<limit where viewModel.moonTable == nil {
                try? await Task.sleep(for: Self.pollInterval)
            }
            switch state {
            case .otherDate: viewModel.nextDay()
            case .nearby: viewModel.select(Place.marVista)
            case .far: viewModel.select(Self.sanDiego)
            case .aha: await viewModel.usePreciseLocationForCompass()
            default: break
            }
            guard state != .locationOff, state != .far else { return }
            viewModel.compass.setOnScreen(true)
            // Let the compass's stream task start before sending.
            await Task.yield()
            heading.send(Self.reading(for: state))
        }

        private static func reading(for state: Kind) -> HeadingReading {
            switch state {
            case .lockedOnMoon: HeadingReading(trueHeading: moonAzimuth + lockOffset, accuracy: goodAccuracy)
            case .lockedOnRise: HeadingReading(trueHeading: riseAzimuth + lockOffset, accuracy: goodAccuracy)
            case .lockedOnSet: HeadingReading(trueHeading: setAzimuth + lockOffset, accuracy: goodAccuracy)
            case .moonDown: HeadingReading(trueHeading: moonDownHeading, accuracy: goodAccuracy)
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
#Preview("6 Other date") { DebugScreenState(.otherDate) }
#Preview("7 Precise off") { DebugScreenState(.preciseOff) }
#Preview("8 Low accuracy") { DebugScreenState(.lowAccuracy) }
#Preview("9 Aha") { DebugScreenState(.aha) }
#Preview("10 Nearby") { DebugScreenState(.nearby) }
#Preview("11 Location off") { DebugScreenState(.locationOff) }
#Preview("12 Far") { DebugScreenState(.far) }
#Preview("13 No moonrise, Sat Oct 3") { DebugScreenState(.noMoonrise) }
#Preview("14 Long phase name") { DebugScreenState(.longPhaseName) }
#Preview("15 Launch loader") { DebugScreenState(.loading) }
#Preview("16 Fast launch") { DebugScreenState(.launchFast) }
#Preview("17 Slow launch") { DebugScreenState(.launchSlow) }
#endif
