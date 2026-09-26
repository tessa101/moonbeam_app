//
//  SpikeMoonTableViewModelTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// The one spike behaviour Step 3 depends on: the table is for the day it was
/// built with, not for whenever it happens to be read. The rest of the spike
/// is replaced in Task #4 and isn't tested here.
@Suite("Spike moon table")
@MainActor
struct SpikeMoonTableViewModelTests {

    private static let losAngeles = TimeZone(identifier: "America/Los_Angeles") ?? .gmt

    /// Deliberately far from the real clock, so "uses `Date()`" can't pass by
    /// accident.
    private static func farDay() throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = losAngeles
        return try #require(calendar.date(from: DateComponents(year: 2020, month: 1, day: 15)))
    }

    /// `LocationViewModel`'s rollover check compares against `day`, so it
    /// has to be the day the table was built for.
    @Test("The day reaches the moon service and is kept")
    func dayReachesTheService() throws {
        let service = FakeMoonService()
        let day = try Self.farDay()

        let table = SpikeMoonTableViewModel(moonService: service, place: SpikeMoonTableViewModel.marVista, day: day)

        #expect(service.requestedDates == [day])
        #expect(table.day == day)
    }
}
