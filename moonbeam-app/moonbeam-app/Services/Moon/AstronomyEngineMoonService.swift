//
//  AstronomyEngineMoonService.swift
//  moonbeam-app
//

import Foundation

/// `MoonService` backed by the vendored Astronomy Engine C library.
///
/// This is the only type in the app permitted to call the C API; everything
/// else depends on the `MoonService` protocol. Conventions (rise/set
/// definition, search window, refraction) are documented in ASTRONOMY.md §3
/// and must stay in step with the USNO reference values.
///
/// `nonisolated` because this is pure computation over its inputs with no
/// shared state, so it has no business on the main actor. The project builds
/// with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, which would otherwise
/// isolate it and force every caller — tests included — onto the main actor.
nonisolated struct AstronomyEngineMoonService: MoonService {

    // MARK: - Constants

    /// Observer elevation. ASTRONOMY.md §3 fixes this at sea level for V1.
    private static let observerHeightMeters = 0.0

    /// Rise/set search window, in days, starting at local midnight.
    private static let searchWindowDays = 1.0

    /// `Astronomy_SearchRiseSetEx` measures from ground level, matching the
    /// 0 m observer height above.
    private static let metersAboveGround = 0.0

    private static let nanosecondsPerSecond = 1_000_000_000.0

    /// How far back `moonPosition(for:at:)` looks for the latest rise and
    /// set. The moon rises and sets about daily at V1 latitudes; a lunar
    /// month leaves room for high latitudes, where it can stay up or down
    /// for days. Backward searches stop at the first event, so the width
    /// costs nothing in the usual case.
    private static let moonUpLookbackDays = 30.0

    // MARK: - MoonService

    func moonDay(for place: Place, on date: Date) -> MoonDay {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = place.timeZone

        // The window runs local midnight → next local midnight in the place's
        // own zone, so DST transitions are handled by Calendar rather than by
        // a fixed offset.
        let localMidnight = calendar.startOfDay(for: date)
        let searchStart = Self.astroTime(from: localMidnight)

        let observer = Astronomy_MakeObserver(
            place.latitude,
            place.longitude,
            Self.observerHeightMeters
        )

        let rise = Self.event(
            direction: DIRECTION_RISE,
            observer: observer,
            searchStart: searchStart
        )
        let set = Self.event(
            direction: DIRECTION_SET,
            observer: observer,
            searchStart: searchStart
        )

        // Phase and illumination are sampled at *tonight's* local midnight —
        // the end of the selected day — because the app answers "how bright is
        // the moon tonight?" (PRODUCT FR5, ASTRONOMY.md §3). Adding a calendar
        // day rather than 24 hours keeps this correct across DST transitions,
        // when a local day is 23 or 25 hours long.
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: localMidnight)
        let illuminationMoment = endOfDay ?? localMidnight

        let phaseResult = Astronomy_MoonPhase(Self.astroTime(from: illuminationMoment))
        let phaseAngle = phaseResult.status == ASTRO_SUCCESS
            ? phaseResult.angle.wrappedIntoDegreeCircle
            : 0

        return MoonDay(
            place: place,
            rise: rise,
            set: set,
            phase: MoonPhase(phaseAngle: phaseAngle),
            phaseAngle: phaseAngle,
            illumination: illumination(at: illuminationMoment)
        )
    }

    /// "Up" is "the latest rise is later than the latest set", both found by
    /// the same rise/set search the moon table uses (COMPASS.md §3). An
    /// altitude > 0° check was rejected: it measures the disc's centre, while
    /// rise/set use the upper edge, so it would disagree with the table for a
    /// minute or two at every rise and set.
    func moonPosition(for place: Place, at date: Date) -> MoonPosition {
        let observer = Astronomy_MakeObserver(
            place.latitude,
            place.longitude,
            Self.observerHeightMeters
        )
        var now = Self.astroTime(from: date)
        let horizontal = Self.horizontal(at: &now, observer: observer)

        let lastRise = Self.latestEvent(direction: DIRECTION_RISE, observer: observer, before: now)
        let lastSet = Self.latestEvent(direction: DIRECTION_SET, observer: observer, before: now)

        let isUp: Bool
        switch (lastRise, lastSet) {
        case let (rise?, set?):
            isUp = rise.ut > set.ut
        case (.some, nil):
            isUp = true
        case (nil, .some):
            isUp = false
        case (nil, nil):
            // No event in the whole lookback: circumpolar or never rising,
            // so there's no rise/set boundary to disagree with.
            isUp = (horizontal?.altitude ?? 0) > 0
        }

        return MoonPosition(
            azimuth: horizontal?.azimuth.wrappedIntoDegreeCircle ?? 0,
            isUp: isUp
        )
    }

    /// The same latest-rise / latest-set rule as `moonPosition(for:at:)`, so
    /// a pass exists exactly when the compass's "Moon" target does. The set
    /// is searched forward from `date` over the same span as the lookback.
    func moonPass(for place: Place, containing date: Date) -> MoonPass? {
        let observer = Astronomy_MakeObserver(
            place.latitude,
            place.longitude,
            Self.observerHeightMeters
        )
        let moment = Self.astroTime(from: date)

        guard let riseTime = Self.latestEvent(direction: DIRECTION_RISE, observer: observer, before: moment) else {
            return nil
        }
        if let lastSet = Self.latestEvent(direction: DIRECTION_SET, observer: observer, before: moment),
           lastSet.ut > riseTime.ut {
            return nil
        }
        let setSearch = Astronomy_SearchRiseSetEx(
            BODY_MOON,
            observer,
            DIRECTION_SET,
            moment,
            Self.moonUpLookbackDays,
            Self.metersAboveGround
        )
        guard setSearch.status == ASTRO_SUCCESS else { return nil }

        let riseDate = Self.date(from: riseTime)
        let setDate = Self.date(from: setSearch.time)
        var sampleDates = Array(stride(from: riseDate, to: setDate, by: MoonPass.sampleInterval))
        sampleDates.append(setDate)

        var azimuths: [Double] = []
        azimuths.reserveCapacity(sampleDates.count)
        for sampleDate in sampleDates {
            var time = Self.astroTime(from: sampleDate)
            guard let horizon = Self.horizontal(at: &time, observer: observer) else { return nil }
            azimuths.append(horizon.azimuth.wrappedIntoDegreeCircle)
        }
        guard let riseAzimuth = azimuths.first, let setAzimuth = azimuths.last else { return nil }

        return MoonPass(
            rise: MoonEvent(date: riseDate, azimuth: riseAzimuth),
            set: MoonEvent(date: setDate, azimuth: setAzimuth),
            path: MoonPass.unwrapped(azimuths)
        )
    }

    /// The same search as the table's moonrise, run forward from `date`
    /// instead of local midnight, over the lookback's span, so it lands on
    /// the very event the Moonrise column shows when that's still ahead.
    func nextMoonrise(for place: Place, after date: Date) -> MoonEvent? {
        let observer = Astronomy_MakeObserver(
            place.latitude,
            place.longitude,
            Self.observerHeightMeters
        )
        return Self.event(
            direction: DIRECTION_RISE,
            observer: observer,
            searchStart: Self.astroTime(from: date),
            limitDays: Self.moonUpLookbackDays
        )
    }

    // MARK: - Illumination at an arbitrary moment

    /// The lit fraction of the disc, `0.0...1.0`, at a specific instant.
    ///
    /// `moonDay(for:on:)` calls this with tonight's local midnight, the moment
    /// PRODUCT FR5 settles on. It's also `internal` so tests can sample other
    /// moments — USNO publishes its `fracillum` for local noon, not midnight
    /// (ASTRONOMY.md §3) — without anything outside this type touching the
    /// C API.
    func illumination(at date: Date) -> Double {
        let result = Astronomy_Illumination(BODY_MOON, Self.astroTime(from: date))
        return result.status == ASTRO_SUCCESS ? result.phase_fraction : 0
    }

    // MARK: - Astronomy Engine bridging

    /// Finds a rise or set within the window and the azimuth at that moment.
    ///
    /// Returns `nil` when the event doesn't occur in the window, which is
    /// normal rather than an error (ASTRONOMY.md §4).
    ///
    /// - Parameter limitDays: the window; the table's one day by default.
    private static func event(
        direction: astro_direction_t,
        observer: astro_observer_t,
        searchStart: astro_time_t,
        limitDays: Double = searchWindowDays
    ) -> MoonEvent? {
        // Astronomy_SearchRiseSet is a C macro in v2.1.19, so it isn't
        // visible to Swift; call the underlying function directly.
        let search = Astronomy_SearchRiseSetEx(
            BODY_MOON,
            observer,
            direction,
            searchStart,
            limitDays,
            metersAboveGround
        )
        guard search.status == ASTRO_SUCCESS else { return nil }

        var eventTime = search.time
        guard let horizon = horizontal(at: &eventTime, observer: observer) else { return nil }

        return MoonEvent(
            date: date(from: search.time),
            azimuth: horizon.azimuth.wrappedIntoDegreeCircle
        )
    }

    /// The most recent rise or set before `time`, or `nil` if none falls in
    /// the lookback. A negative `limitDays` makes the search run backward.
    private static func latestEvent(
        direction: astro_direction_t,
        observer: astro_observer_t,
        before time: astro_time_t
    ) -> astro_time_t? {
        let search = Astronomy_SearchRiseSetEx(
            BODY_MOON,
            observer,
            direction,
            time,
            -moonUpLookbackDays,
            metersAboveGround
        )
        return search.status == ASTRO_SUCCESS ? search.time : nil
    }

    /// The moon's horizontal coordinates at `time`: equatorial coordinates
    /// of date, then horizontal with standard refraction, to match the USNO
    /// rise/set definition.
    private static func horizontal(
        at time: inout astro_time_t,
        observer: astro_observer_t
    ) -> astro_horizon_t? {
        let equatorial = Astronomy_Equator(
            BODY_MOON,
            &time,
            observer,
            EQUATOR_OF_DATE,
            ABERRATION
        )
        guard equatorial.status == ASTRO_SUCCESS else { return nil }

        return Astronomy_Horizon(
            &time,
            observer,
            equatorial.ra,
            equatorial.dec,
            REFRACTION_NORMAL
        )
    }

    /// Converts a `Date` to Astronomy Engine's time type via UTC components.
    private static func astroTime(from date: Date) -> astro_time_t {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = .gmt

        let parts = utcCalendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second, .nanosecond],
            from: date
        )
        let seconds = Double(parts.second ?? 0)
            + Double(parts.nanosecond ?? 0) / nanosecondsPerSecond

        return Astronomy_MakeTime(
            Int32(parts.year ?? 0),
            Int32(parts.month ?? 1),
            Int32(parts.day ?? 1),
            Int32(parts.hour ?? 0),
            Int32(parts.minute ?? 0),
            seconds
        )
    }

    /// Converts Astronomy Engine's time type back to a `Date`.
    private static func date(from time: astro_time_t) -> Date {
        let utc = Astronomy_UtcFromTime(time)

        var components = DateComponents()
        components.year = Int(utc.year)
        components.month = Int(utc.month)
        components.day = Int(utc.day)
        components.hour = Int(utc.hour)
        components.minute = Int(utc.minute)
        components.second = Int(utc.second)
        components.nanosecond = Int(
            (utc.second - utc.second.rounded(.down)) * nanosecondsPerSecond
        )

        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = .gmt

        // A UTC calendar date built from UTC components always resolves.
        return utcCalendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }
}
