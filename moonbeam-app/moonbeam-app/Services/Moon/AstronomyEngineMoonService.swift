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
struct AstronomyEngineMoonService: MoonService {

    // MARK: - Constants

    /// Observer elevation. ASTRONOMY.md §3 fixes this at sea level for V1.
    private static let observerHeightMeters = 0.0

    /// Rise/set search window, in days, starting at local midnight.
    private static let searchWindowDays = 1.0

    /// `Astronomy_SearchRiseSetEx` measures from ground level, matching the
    /// 0 m observer height above.
    private static let metersAboveGround = 0.0

    private static let nanosecondsPerSecond = 1_000_000_000.0

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
        let illuminationMoment = Self.astroTime(from: endOfDay ?? localMidnight)

        let phaseResult = Astronomy_MoonPhase(illuminationMoment)
        let phaseAngle = phaseResult.status == ASTRO_SUCCESS
            ? phaseResult.angle.wrappedIntoDegreeCircle
            : 0

        let illuminationResult = Astronomy_Illumination(BODY_MOON, illuminationMoment)
        let illumination = illuminationResult.status == ASTRO_SUCCESS
            ? illuminationResult.phase_fraction
            : 0

        return MoonDay(
            place: place,
            rise: rise,
            set: set,
            phase: MoonPhase(phaseAngle: phaseAngle),
            phaseAngle: phaseAngle,
            illumination: illumination
        )
    }

    // MARK: - Astronomy Engine bridging

    /// Finds a rise or set within the window and the azimuth at that moment.
    ///
    /// Returns `nil` when the event doesn't occur in the window, which is
    /// normal rather than an error (ASTRONOMY.md §4).
    private static func event(
        direction: astro_direction_t,
        observer: astro_observer_t,
        searchStart: astro_time_t
    ) -> MoonEvent? {
        // Astronomy_SearchRiseSet is a C macro in v2.1.19, so it isn't
        // visible to Swift; call the underlying function directly.
        let search = Astronomy_SearchRiseSetEx(
            BODY_MOON,
            observer,
            direction,
            searchStart,
            searchWindowDays,
            metersAboveGround
        )
        guard search.status == ASTRO_SUCCESS else { return nil }

        var eventTime = search.time

        // Equatorial coordinates of date, then horizontal coordinates with
        // standard refraction, to match the USNO rise/set definition.
        let equatorial = Astronomy_Equator(
            BODY_MOON,
            &eventTime,
            observer,
            EQUATOR_OF_DATE,
            ABERRATION
        )
        guard equatorial.status == ASTRO_SUCCESS else { return nil }

        let horizon = Astronomy_Horizon(
            &eventTime,
            observer,
            equatorial.ra,
            equatorial.dec,
            REFRACTION_NORMAL
        )

        return MoonEvent(
            date: date(from: search.time),
            azimuth: horizon.azimuth.wrappedIntoDegreeCircle
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
