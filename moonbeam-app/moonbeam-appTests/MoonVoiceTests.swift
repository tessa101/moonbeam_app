import Foundation
import Testing
@testable import moonbeam_app

@Suite("Today guidance")
nonisolated struct MoonVoiceTests {
    let formatter = MoonVoice(locale: Locale(identifier: "en_US"))
    static let zone = Place.irvine.timeZone
    static func date(_ day: Int, _ hour: Int = 12) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour)) ?? .distantPast
    }
    func message(altitude: Double = 31, up: Bool = true, missingRise: Bool = false, missingSet: Bool = false,
                 phase: MoonPhase? = nil, rise: Date? = nil, pass: MoonPass? = nil, nextSet: Date? = nil) -> String {
        let day = MoonDay(place: .irvine,
            rise: missingRise ? nil : MoonEvent(date: Self.date(12, 9), azimuth: 115),
            set: missingSet ? nil : MoonEvent(date: Self.date(12, 19), azimuth: 243),
            phase: .waxingCrescent, phaseAngle: 30, illumination: 0.07)
        return formatter.message(day: day, position: MoonPosition(azimuth: 180, altitude: altitude, isUp: up),
            pass: pass, nextRise: rise.map { MoonEvent(date: $0, azimuth: 90) },
            nextSet: nextSet.map { MoonEvent(date: $0, azimuth: 270) }, exactPhase: phase, at: Self.date(12))
    }
    @Test(arguments: [(-0.5, "Low on the horizon. Find a clear view south."),
        (9.99, "Low on the horizon. Find a clear view south."),
        (10, "Low in the sky. Look south."), (29.99, "Low in the sky. Look south."),
        (30, "Partway up the sky. Look south."), (59.99, "Partway up the sky. Look south."),
        (60, "High in the sky. Look south."), (79.99, "High in the sky. Look south."),
        (80, "Nearly overhead. Look up.")])
    func bands(altitude: Double, expected: String) { #expect(message(altitude: altitude) == expected) }

    @Test func nextRiseAndMidnight() {
        #expect(message(up: false, rise: Self.date(12, 21)).contains("Look east."))
        #expect(message(up: false, rise: Self.date(13, 0)).hasPrefix("Rises after midnight at"))
        #expect(message(up: false, rise: Self.date(12).addingTimeInterval(30)) == "Rising now. Look east.")
        #expect(message(up: false, rise: Self.date(15)) == "No moonrise today.")
    }
    @Test func missingEventsAndPriority() {
        let pass = MoonPass(rise: MoonEvent(date: Self.date(11, 22), azimuth: 90),
            set: MoonEvent(date: Self.date(12, 14), azimuth: 270), path: [90, 270])
        #expect(message(missingRise: true, phase: .new, pass: pass).hasPrefix("Rose last night. Sets today at"))
        #expect(message(missingRise: true) == "No moonrise today.")
        #expect(message(missingSet: true) == "No moonset today.")
        let latePass = MoonPass(rise: pass.rise, set: MoonEvent(date: Self.date(13, 1), azimuth: 270), path: [90,270])
        #expect(message(missingSet: true, pass: latePass).hasPrefix("Stays up past midnight."))
        #expect(message(up: false, missingSet: true, rise: Self.date(12, 15), nextSet: Self.date(13, 1)).contains("until after midnight."))
        #expect(message(up: false, phase: .full, rise: Self.date(13, 0)).hasPrefix("Rises after midnight"))
    }
    @Test func phaseCopy() {
        #expect(message(phase: .new) == "New moon. Close to the sun, hard to spot.")
        #expect(message(phase: .full) == "Full moon. A bright night for moonwatching.")
        #expect(message(up: false, phase: .full, rise: Self.date(12, 18)).hasPrefix("Full moon. Up at"))
    }
    @Test func exactPhaseIsOneLocalDay() {
        let service = AstronomyEngineMoonService()
        #expect(service.exactPrincipalPhase(on: Self.date(10), in: Self.zone) == .new)
        #expect(service.exactPrincipalPhase(on: Self.date(11), in: Self.zone) == nil)
        #expect(service.exactPrincipalPhase(on: Self.date(12), in: Self.zone) == nil)
        #expect(service.exactPrincipalPhase(on: Self.date(25), in: Self.zone) == .full)
        #expect(service.exactPrincipalPhase(on: Self.date(26), in: Self.zone) == nil)
    }
}
