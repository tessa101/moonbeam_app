//
//  MadlibFormatterTests.swift
//  moonbeam-appTests
//

import Accessibility
import Foundation
import Testing
@testable import moonbeam_app

/// The madlib sentence (DESIGN-1.1.md §3.1, §3.1a): the three lines; the
/// date token's text on today, another day and another year; the place
/// token, including "a city"; the non-breaking spaces; and what VoiceOver
/// says. Pinned to `en_US`.
@Suite("Madlib formatter")
nonisolated struct MadlibFormatterTests {

    // MARK: - Fixtures

    private static let losAngelesZone = TimeZone(identifier: "America/Los_Angeles") ?? .gmt
    private static let nbsp = MadlibFormatter.nonBreakingSpace

    private static let losAngeles = Place(
        name: "Los Angeles",
        locality: "Los Angeles",
        region: "CA",
        country: "United States",
        latitude: 34.05,
        longitude: -118.24,
        timeZone: losAngelesZone
    )

    private let formatter = MadlibFormatter(locale: Locale(identifier: "en_US"))

    // MARK: - Date token

    @Test("Today: the date token reads \"today\"")
    func today() throws {
        let sentence = try sentence(day: (2026, 9, 30), dayOffset: 0)
        let date = try #require(sentence.tokens.first)

        #expect(date.kind == .date)
        #expect(date.symbol == "token.calendar")
        #expect(date.text == "today")
        #expect(String(date.accessibilityLabel.characters) == "Date, today")
    }

    @Test("Another day: \"on Sat, Oct 3\", spoken in full")
    func otherDay() throws {
        let sentence = try sentence(day: (2026, 10, 3), dayOffset: 3)
        let date = try #require(sentence.tokens.first)

        #expect(date.text == "on\(Self.nbsp)Sat,\(Self.nbsp)Oct\(Self.nbsp)3")
        #expect(String(date.accessibilityLabel.characters) == "Date, Saturday, October 3")
    }

    @Test("Another year: the year is added, shown and spoken")
    func otherYear() throws {
        let sentence = try sentence(day: (2027, 1, 4), dayOffset: 96, allowsBreaks: true)
        let date = try #require(sentence.tokens.first)

        #expect(date.text == "on Mon, Jan 4, 2027")
        #expect(String(date.accessibilityLabel.characters) == "Date, Monday, January 4, 2027")
    }

    // MARK: - Place token

    @Test("The place token is \"City, ST\", with the region spelled out when spoken")
    func placeToken() throws {
        let sentence = try sentence(day: (2026, 9, 30), dayOffset: 0)
        let place = try #require(sentence.tokens.last)

        #expect(place.kind == .place)
        #expect(place.symbol == "token.pin")
        #expect(place.text == "Los\(Self.nbsp)Angeles,\(Self.nbsp)CA")
        #expect(String(place.accessibilityLabel.characters) == "Place, Los Angeles, CA")
        #expect(Self.spelledOut(place.accessibilityLabel) == ["CA"])
    }

    @Test("A region that's a word isn't spelled out; no region, nothing to spell", arguments: [
        ("London", "England", "Place, London, England"),
        ("Singapore", nil, "Place, Singapore"),
    ])
    func regionWords(name: String, region: String?, expected: String) {
        let place = Place(name: name, region: region, latitude: 0, longitude: 0, timeZone: .gmt)
        let sentence = formatter.sentence(
            place: place, day: Date(), dayOffset: 0, today: Date(), allowsBreaksInsideTokens: true
        )
        let label = sentence.tokens.last?.accessibilityLabel ?? AttributedString()

        #expect(String(label.characters) == expected)
        #expect(Self.spelledOut(label).isEmpty)
    }

    // MARK: - Sentence

    @Test("Three lines: \"Where can I find\" / \"the moon\" + date / \"in\" + place + \"?\"")
    func lines() throws {
        let sentence = try sentence(day: (2026, 9, 30), dayOffset: 0, allowsBreaks: true)
        let tokens = sentence.tokens

        #expect(sentence.lines.count == 3)
        #expect(sentence.lines[0] == [.words("Where can I find")])
        #expect(sentence.lines[1] == [.words("the moon "), .token(tokens[0])])
        #expect(sentence.lines[2] == [.words("in "), .token(tokens[1]), .words("?")])
        #expect(tokens.map(\.kind) == [.date, .place])
        #expect(sentence.accessibilityLabel == "Where can I find the moon today in Los Angeles, CA?")
    }

    /// No space, so line breaking can't put the "?" on a line of its own,
    /// and no invisible joiner either (it hung the layout; see the formatter).
    @Test("The \"?\" follows the city with nothing between")
    func questionMarkGlued() throws {
        let sentence = try sentence(day: (2026, 9, 30), dayOffset: 0, allowsBreaks: true)

        #expect(sentence.lines[2].last == .words("?"))
        #expect(sentence.tokens.last?.text.hasSuffix(" ") == false)
        #expect(!sentence.accessibilityLabel.unicodeScalars.contains("\u{2060}"))
    }

    @Test("Spoken sentence uses ordinary spaces even when tokens don't break")
    func spokenSentenceSpaces() throws {
        let sentence = try sentence(day: (2026, 10, 3), dayOffset: 3, allowsBreaks: false)

        #expect(sentence.accessibilityLabel == "Where can I find the moon on Sat, Oct 3 in Los Angeles, CA?")
    }

    @Test("Off the default size a token's words may break; at the default they can't")
    func breaksInsideTokens() throws {
        let fixed = try sentence(day: (2026, 9, 30), dayOffset: 0, allowsBreaks: false)
        let free = try sentence(day: (2026, 9, 30), dayOffset: 0, allowsBreaks: true)

        #expect(fixed.tokens.last?.text.contains(" ") == false)
        #expect(free.tokens.last?.text == "Los Angeles, CA")
    }

    // MARK: - No place (§11 Q2)

    @Test("No place: \"a city\" token, the date as plain words")
    func noPlace() {
        let sentence = formatter.sentence(
            place: nil, day: Date(), dayOffset: 0, today: Date(), allowsBreaksInsideTokens: false
        )

        #expect(sentence.lines.count == 3)
        #expect(sentence.lines[1] == [.words("the moon today")])
        #expect(sentence.tokens.map(\.kind) == [.place])
        #expect(sentence.tokens.first?.text == "a\(Self.nbsp)city")
        #expect(sentence.tokens.first.map { String($0.accessibilityLabel.characters) } == "Place, choose a city")
        #expect(sentence.accessibilityLabel == "Where can I find the moon today in a city?")
    }

    @Test("5.10a.3 a pending place is flagged hidden and VoiceOver skips it")
    func pendingPlace() {
        // As the view model calls it: a pending place keeps the replaced
        // place's zone, so the date stays a token (LOADER.md §12.9).
        let sentence = formatter.sentence(
            place: nil, placePending: true, dateTimeZone: .gmt,
            day: Date(), dayOffset: 0, today: Date(), allowsBreaksInsideTokens: false
        )

        #expect(sentence.placeIsPending)
        #expect(sentence.lines.count == 3)
        #expect(sentence.tokens.map(\.kind) == [.date])
        #expect(sentence.accessibilityLabel == "Where can I find the moon today")
    }

    @Test("No place with a stand-in: its name in the place token, the date still plain")
    func standIn() {
        let sentence = formatter.sentence(
            place: nil,
            standIn: Self.losAngeles,
            day: Date(),
            dayOffset: 0,
            today: Date(),
            allowsBreaksInsideTokens: true
        )

        #expect(sentence.tokens.map(\.kind) == [.place])
        #expect(sentence.tokens.first?.text == "Los Angeles, CA")
    }

    // MARK: - Helpers

    private func sentence(
        day: (Int, Int, Int),
        dayOffset: Int,
        allowsBreaks: Bool = false
    ) throws -> MadlibFormatter.Sentence {
        let today = try Self.date(2026, 9, 30, hour: 12)
        let selected = try Self.date(day.0, day.1, day.2, hour: 0)
        return formatter.sentence(
            place: Self.losAngeles,
            day: selected,
            dayOffset: dayOffset,
            today: today,
            allowsBreaksInsideTokens: allowsBreaks
        )
    }

    /// The runs VoiceOver spells out letter by letter.
    private static func spelledOut(_ label: AttributedString) -> [String] {
        label.runs
            .filter { $0.accessibilitySpeechSpellsOutCharacters == true }
            .map { String(label[$0.range].characters) }
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = losAngelesZone
        let components = DateComponents(year: year, month: month, day: day, hour: hour)
        return try #require(calendar.date(from: components))
    }
}
