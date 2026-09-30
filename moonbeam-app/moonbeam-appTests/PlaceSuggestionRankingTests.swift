//
//  PlaceSuggestionRankingTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// `PlaceSuggestionRanking` (SEARCH-RECENTS.md §0, Step 2.2): regions and
/// countries only on a name match, and how the levels merge. The rows are
/// what MapKit returned for these queries on 2026-09-30 (simulator, Irvine).
@Suite("Place suggestion ranking")
nonisolated struct PlaceSuggestionRankingTests {

    // MARK: - Fixtures

    private static func row(_ title: String, _ subtitle: String = "") -> PlaceSuggestion {
        PlaceSuggestion(title: title, subtitle: subtitle)
    }

    // MARK: - Name match

    @Test(
        "A region matches when the typed text is its name, ignoring case and accents",
        arguments: [
            ("Tokyo", "Japan", "tokyo"),
            ("Singapore", "", "Singapore"),
            ("Mexico City", "Mexico", "mexico city"),
            ("London", "England", " London "),
            ("Reykjavík", "Iceland", "reykjavik"),
            ("Hong Kong SAR, China", "", "hong kong"),
        ]
    )
    func nameMatches(title: String, subtitle: String, query: String) {
        #expect(PlaceSuggestionRanking.isNameMatch(Self.row(title, subtitle), query: query))
    }

    /// Whole names only, so typing doesn't flood the list with states. A
    /// typo doesn't match either: MapKit's fuzzy match of "Tokio" to Tokyo
    /// only comes back at the region level, which the rule keeps out.
    @Test(
        "A prefix or a typo isn't a name match",
        arguments: [
            ("California", "United States", "Cal"),
            ("Tokyo", "Japan", "Tok"),
            ("Tokyo", "Japan", "Tokio"),
            ("Singapore", "", "Singapur"),
            ("Tokyo", "Japan", ""),
        ]
    )
    func notNameMatches(title: String, subtitle: String, query: String) {
        #expect(!PlaceSuggestionRanking.isNameMatch(Self.row(title, subtitle), query: query))
    }

    @Test("The country is the subtitle's last part, or the title's with no subtitle")
    func country() {
        #expect(PlaceSuggestionRanking.country(of: Self.row("London, KY", "United States")) == "United States")
        #expect(PlaceSuggestionRanking.country(of: Self.row("Venice", "Los Angeles, CA, United States")) == "United States")
        #expect(PlaceSuggestionRanking.country(of: Self.row("Hong Kong SAR, China")) == "China")
        #expect(PlaceSuggestionRanking.country(of: Self.row("Singapore")) == nil)
    }

    // MARK: - Merge

    @Test("London: London, England leads London, ON")
    func londonLeads() {
        let merged = PlaceSuggestionRanking.merged(
            query: "London",
            cities: [Self.row("London", "ON, Canada"), Self.row("London, KY", "United States")],
            regions: [Self.row("London", "England")]
        )

        #expect(merged.map(\.id) == [
            Self.row("London", "England").id,
            Self.row("London", "ON, Canada").id,
            Self.row("London, KY", "United States").id,
        ])
    }

    @Test("Tokyo and Singapore, which aren't cities to MapKit, appear first")
    func cityStatesAppear() {
        let tokyo = PlaceSuggestionRanking.merged(
            query: "Tokyo",
            cities: [Self.row("Little Tokyo", "Los Angeles, CA, United States")],
            regions: [Self.row("Tokyo", "Japan")]
        )
        let singapore = PlaceSuggestionRanking.merged(
            query: "Singapore",
            cities: [Self.row("Singapore Polytechnic", "Singapore")],
            regions: [Self.row("Singapore")]
        )

        #expect(tokyo.first == Self.row("Tokyo", "Japan"))
        #expect(singapore.first == Self.row("Singapore"))
    }

    @Test("Cal: California and the other regions stay out")
    func prefixKeepsRegionsOut() {
        let cities = [Self.row("Calgary, AB", "Canada"), Self.row("Calexico, CA", "United States")]

        let merged = PlaceSuggestionRanking.merged(
            query: "Cal",
            cities: cities,
            regions: [Self.row("California", "United States"), Self.row("Calabria", "Italy")]
        )

        #expect(merged == cities)
    }

    @Test("New York: the city beats the same-named state, which is left out")
    func cityBeatsSameNamedState() {
        let city = Self.row("New York, NY", "United States")

        let merged = PlaceSuggestionRanking.merged(
            query: "New York",
            cities: [city, Self.row("New York Mills, MN", "United States")],
            regions: [Self.row("New York", "United States")]
        )

        #expect(merged.first == city)
        #expect(!merged.contains(Self.row("New York", "United States")))
    }

    /// The same row at both levels is the same place, so it leads once.
    @Test("Hong Kong: the row MapKit returns at both levels leads, once")
    func sameRowAtBothLevels() {
        let hongKong = Self.row("Hong Kong SAR, China")

        let merged = PlaceSuggestionRanking.merged(
            query: "Hong Kong",
            cities: [Self.row("Hong Kong", "La Paz, B.C.S., Mexico"), hongKong],
            regions: [hongKong]
        )

        #expect(merged == [hongKong, Self.row("Hong Kong", "La Paz, B.C.S., Mexico")])
    }

    @Test("A place at both levels is listed once")
    func deduplicates() {
        let paris = Self.row("Paris", "France")

        let merged = PlaceSuggestionRanking.merged(
            query: "Paris",
            cities: [paris, Self.row("Paris, TX", "United States")],
            regions: [paris]
        )

        #expect(merged == [paris, Self.row("Paris, TX", "United States")])
    }
}
