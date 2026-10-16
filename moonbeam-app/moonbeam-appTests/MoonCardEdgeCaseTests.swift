import SwiftUI
import Testing
import UIKit
@testable import moonbeam_app

/// Keep the layout review reproducible with deliberately difficult strings.
@Suite("Moon card edge cases", .serialized, .timeLimit(.minutes(1)))
@MainActor
struct MoonCardEdgeCaseTests {
    nonisolated enum Scenario: String, CaseIterable, Sendable {
        case longTimes, lastNight, missingRise, missingSet, noEvents, countdown, lateReturn, otherDate, foreignZone
    }

    nonisolated private static let fixtures: [(Scenario, CGFloat)] = Scenario.allCases.flatMap { scenario in
        [CGFloat(335), 362].map { (scenario, $0) }
    }

    @Test("Complete edge-case cards render at phone widths and standard/AX sizes",
          arguments: fixtures,
          [DynamicTypeSize.large, .accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5])
    func renderMatrix(fixture: (Scenario, CGFloat), size: DynamicTypeSize) throws {
        let (scenario, width) = fixture
        let service = EdgeCaseMoonService(scenario: scenario)
        let here = Place(name: "Irvine", region: "CA", latitude: Place.irvine.latitude,
                         longitude: Place.irvine.longitude, timeZone: Place.irvine.timeZone, isCurrentLocation: true)
        let model = LocationViewModel(
            locationService: FakeLocationService(authorizationState: .authorized, placeResult: .success(here)),
            placeSearch: FakePlaceSearchService(), placeStore: InMemoryPlaceStore(),
            moonService: service, headingService: FakeHeadingService(),
            deviceTimeZone: scenario == .foreignZone ? TimeZone(secondsFromGMT: 0) ?? here.timeZone : here.timeZone,
            now: { service.now }
        )
        model.select(here)
        if scenario == .otherDate || scenario == .foreignZone { model.nextDay() }
        let table = try #require(model.moonTable)
        switch scenario {
        case .lastNight:
            guard case let .up(_, _, pass) = model.compass.upNow?.state else {
                Issue.record("Expected an active pass"); return
            }
            #expect(pass?.riseContext == "last night")
        case .missingRise:
            guard case let .missing(text, next) = table.rise.detail else {
                Issue.record("Expected a missing rise"); return
            }
            #expect(text == "After midnight" && next != nil)
        case .missingSet:
            guard case let .missing(text, next) = table.set.detail else {
                Issue.record("Expected a missing set"); return
            }
            #expect(text == "After midnight" && next != nil)
        case .noEvents:
            for column in [table.rise, table.set] {
                guard case let .missing(text, next) = column.detail else {
                    Issue.record("Expected no event in range"); return
                }
                #expect(text == "Not today" && next == nil)
            }
        case .foreignZone:
            guard case let .time(_, zone, _) = table.rise.detail else {
                Issue.record("Expected an event with a place-zone label"); return
            }
            #expect(zone != nil)
        case .countdown:
            #expect(model.compass.upNow?.title == "Not up yet")
        case .lateReturn:
            #expect(model.compass.upNow?.detail?.contains("Back late tonight") == true)
        case .otherDate:
            #expect(model.compass.upNow == nil)
        case .longTimes: break
        }
        let image = try Self.render(model, width: width, size: size)
        #expect(image.size.width == width)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("moonbeam-5.5b", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try #require(image.pngData()).write(to:
            directory.appendingPathComponent("\(scenario.rawValue)-\(Int(width))-\(size).png")
        )
    }

    @Test("Locking rise, set or the moon changes the outline without moving content",
          arguments: [(348.0, MoonCardCell.moonrise), (112.0, .moonset), (266.0, .upNow)],
          [DynamicTypeSize.large, .accessibility3, .accessibility5])
    func lockDoesNotResize(target: (Double, MoonCardCell), size: DynamicTypeSize) async throws {
        let service = EdgeCaseMoonService(scenario: .lastNight)
        let heading = FakeHeadingService()
        let here = Place(name: "Irvine", region: "CA", latitude: Place.irvine.latitude,
                         longitude: Place.irvine.longitude, timeZone: Place.irvine.timeZone, isCurrentLocation: true)
        let model = LocationViewModel(
            locationService: FakeLocationService(authorizationState: .authorized, placeResult: .success(here)),
            placeSearch: FakePlaceSearchService(), placeStore: InMemoryPlaceStore(), moonService: service,
            headingService: heading, deviceTimeZone: here.timeZone, now: { service.now }
        )
        model.select(here)
        let before = try Self.render(model, width: 335, size: size)
        model.compass.setOnScreen(true)
        defer { model.compass.setOnScreen(false) }
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while !heading.isRunning && ContinuousClock.now < deadline { await Task.yield() }
        heading.send(HeadingReading(trueHeading: target.0, accuracy: 3))
        while model.highlightedCardCell != target.1 && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(16))
        }
        #expect(model.highlightedCardCell == target.1)
        let after = try Self.render(model, width: 335, size: size)
        #expect(before.size == after.size)
        #expect(before.pngData() != after.pngData())
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("moonbeam-5.5b", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try #require(after.pngData()).write(to: directory.appendingPathComponent("locked-\(target.1)-335-\(size).png"))
    }

    private static func render(_ model: LocationViewModel, width: CGFloat, size: DynamicTypeSize) throws -> UIImage {
        let table = try #require(model.moonTable)
        let renderer = ImageRenderer(content: MoonCard(viewModel: model, table: table)
            .environment(\.dynamicTypeSize, size).environment(\.colorScheme, .dark).frame(width: width))
        renderer.proposedSize = ProposedViewSize(width: width, height: nil)
        return try #require(renderer.uiImage)
    }
}

/// Missing events occur only on the reference day; the following day's
/// event supplies the real "After midnight" fallback, rather than a stub.
nonisolated private struct EdgeCaseMoonService: MoonService {
    let scenario: MoonCardEdgeCaseTests.Scenario
    var now: Date { date(day: 2, hour: 12, minute: 0) }

    private func date(day: Int, hour: Int, minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Place.irvine.timeZone
        return calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))
            ?? Date(timeIntervalSince1970: 0)
    }

    func moonDay(for place: Place, on day: Date) -> MoonDay {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = place.timeZone
        let isReference = calendar.isDate(day, inSameDayAs: now)
        let number = calendar.component(.day, from: day)
        return MoonDay(
            place: place,
            rise: scenario == .noEvents || (scenario == .missingRise && isReference) ? nil
                : MoonEvent(date: date(day: number, hour: isReference ? 23 : 0, minute: isReference ? 59 : 20), azimuth: 348),
            set: scenario == .noEvents || (scenario == .missingSet && isReference) ? nil
                : MoonEvent(date: date(day: number, hour: isReference ? 12 : 0, minute: isReference ? 58 : 20), azimuth: 112),
            phase: .waningGibbous, phaseAngle: 250, illumination: 0.67
        )
    }

    func moonPosition(for place: Place, at date: Date) -> MoonPosition {
        MoonPosition(azimuth: 266, altitude: 23, isUp: scenario == .longTimes || scenario == .lastNight)
    }

    func moonPass(for place: Place, containing moment: Date) -> MoonPass? {
        guard scenario == .lastNight else { return nil }
        return MoonPass(rise: MoonEvent(date: date(day: 1, hour: 23, minute: 59), azimuth: 348),
                        set: MoonEvent(date: date(day: 2, hour: 12, minute: 58), azimuth: 112), path: [348, 472])
    }

    func nextMoonrise(for place: Place, after moment: Date) -> MoonEvent? {
        guard scenario != .noEvents else { return nil }
        return MoonEvent(date: scenario == .countdown ? date(day: 2, hour: 23, minute: 59)
                      : date(day: 3, hour: 0, minute: 20), azimuth: 348)
    }
}
