//
//  MoonTableSpike.swift
//  moonbeam-app
//
//  Temporary scaffolding for the Astronomy Engine spike (STATUS.md "Next" #2):
//  prints the moon table for a hardcoded city so the vendored C library can be
//  checked against the reference row in ASTRONOMY.md §5. Delete once the real
//  test target (STATUS.md "Next" #3) covers this.
//

import Foundation

/// Prints one day's moon table to the console for a fixed place and date.
enum MoonTableSpike {

    // MARK: - Fixture

    /// The reference row from ASTRONOMY.md §5.
    private static let marVista = Place(
        name: "Los Angeles (Mar Vista), CA",
        latitude: 34.00,
        longitude: -118.43,
        timeZone: TimeZone(identifier: "America/Los_Angeles") ?? .gmt
    )

    /// 2026-09-23, the date the JS sanity check in STATUS.md used.
    private static let referenceDateComponents = DateComponents(
        year: 2026, month: 9, day: 23, hour: 12
    )

    private static let percentMultiplier = 100.0

    // MARK: - Running

    static func run(service: MoonService = AstronomyEngineMoonService()) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = marVista.timeZone

        guard let date = calendar.date(from: referenceDateComponents) else {
            print("[spike] Could not build the reference date.")
            return
        }

        let moonDay = service.moonDay(for: marVista, on: date)
        print(report(for: moonDay, on: date))
    }

    // MARK: - Reporting

    private static func report(for moonDay: MoonDay, on date: Date) -> String {
        let place = moonDay.place
        let compass = CompassFormatter()

        // All user-facing times use the place's zone, never the device's.
        var dayStyle = Date.FormatStyle.dateTime.year().month().day()
        dayStyle.timeZone = place.timeZone
        let dayLabel = date.formatted(dayStyle)

        let illuminationPercent = (moonDay.illumination * percentMultiplier)
            .formatted(.number.precision(.fractionLength(0)))

        return """

        ── Moon table · \(place.name) · \(dayLabel) ──
          Moonrise: \(describe(moonDay.rise, compass: compass, timeZone: place.timeZone))
          Moonset:  \(describe(moonDay.set, compass: compass, timeZone: place.timeZone))
          Phase:    \(moonDay.phase.rawValue) (angle \(moonDay.phaseAngle.formatted(.number.precision(.fractionLength(1))))°)
          Lit:      \(illuminationPercent)%
          Expected: rise 5:18 PM 105° ESE · set 3:37 AM 252° WSW · 94% (ASTRONOMY.md §5)

        """
    }

    private static func describe(
        _ event: MoonEvent?,
        compass: CompassFormatter,
        timeZone: TimeZone
    ) -> String {
        guard let event else { return "none today" }

        var timeStyle = Date.FormatStyle.dateTime.hour().minute()
        timeStyle.timeZone = timeZone
        let time = event.date.formatted(timeStyle)
        let degrees = event.azimuth.formatted(.number.precision(.fractionLength(0)))
        return "\(time) · \(degrees)° \(compass.abbreviation(for: event.azimuth))"
    }
}
