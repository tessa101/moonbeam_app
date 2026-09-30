//
//  PlaceSuggestionRanking.swift
//  moonbeam-app
//

import Foundation

/// Turns MapKit's type-ahead batches, asked for separately by address level,
/// into the one list the search sheet shows (SEARCH-RECENTS.md §0, Step 2.2).
///
/// Separate levels because a completion doesn't say what kind of place it
/// is, and the rule depends on it: a region- or country-level result
/// (Singapore, Tokyo, London, England) only appears when the typed text is
/// its name, so "cal" doesn't offer California.
///
/// Pure and `nonisolated`, so the rule is tested without MapKit.
nonisolated enum PlaceSuggestionRanking {

    // MARK: - Merge

    /// "Smart, then closest" (Step 2.2 fix 2), by level:
    /// 1. name-matched regions: a name match is the prominent place typed
    ///    (Tokyo, Japan; London, England)
    /// 2. towns and cities, in MapKit's order (Venice, Italy; Paris, TX)
    /// 3. neighbourhoods and landmarks, still listed but below the cities
    ///    (Venice Beach; Paris in Acton, CA)
    ///
    /// Within a level MapKit's own relevance order stands: completions carry
    /// no coordinates, so there's no distance to break ties with, and
    /// MapKit already favours nearby places among equals. Duplicates across
    /// levels (Paris, France comes back as both) keep their first position.
    static func merged(
        query: String,
        localities: [PlaceSuggestion],
        subLocalities: [PlaceSuggestion],
        regions: [PlaceSuggestion]
    ) -> [PlaceSuggestion] {
        let cities = localities + subLocalities
        let leading = regions.filter { region in
            isNameMatch(region, query: query) && !hasSameNamedCity(as: region, in: cities)
        }
        return deduplicated(leading + localities + subLocalities)
    }

    // MARK: - Name match

    /// The region's name is what was typed, ignoring case and accents.
    ///
    /// A trailing all-caps designation is ignored too, so "Hong Kong"
    /// matches MapKit's "Hong Kong SAR, China". Whole names only: a prefix
    /// ("cal", "Tok") never brings in a region.
    static func isNameMatch(_ suggestion: PlaceSuggestion, query: String) -> Bool {
        let typed = normalized(query)
        guard !typed.isEmpty else { return false }
        let name = self.name(of: suggestion)
        if normalized(name) == typed { return true }
        guard let withoutDesignation = droppingDesignation(from: name) else { return false }
        return normalized(withoutDesignation) == typed
    }

    /// A city with the region's name in the region's country: New York City
    /// beats New York State. The region is left out rather than listed
    /// second, since moon times for a whole state aren't useful.
    ///
    /// The identical row doesn't count: MapKit returns "Hong Kong SAR,
    /// China" at both levels, and that's the same place, not a rival city.
    static func hasSameNamedCity(as region: PlaceSuggestion, in cities: [PlaceSuggestion]) -> Bool {
        let regionName = normalized(name(of: region))
        let regionCountry = country(of: region).map(normalized)
        return cities.contains { city in
            city.id != region.id
                && normalized(name(of: city)) == regionName
                && country(of: city).map(normalized) == regionCountry
        }
    }

    // MARK: - Parts of a suggestion

    /// "New York" from "New York, NY": the title up to its first comma.
    static func name(of suggestion: PlaceSuggestion) -> String {
        firstComponent(of: suggestion.title)
    }

    /// The last comma-separated part of the subtitle, or of the title when
    /// there's no subtitle ("Hong Kong SAR, China" → "China"). `nil` if
    /// there's nothing after a comma to go on.
    static func country(of suggestion: PlaceSuggestion) -> String? {
        let source = suggestion.subtitle.isEmpty ? suggestion.title : suggestion.subtitle
        let parts = components(of: source)
        if suggestion.subtitle.isEmpty, parts.count < 2 { return nil }
        return parts.last
    }

    // MARK: - Helpers

    /// A designation is one trailing word, all capitals, at least this long.
    private static let minimumDesignationLength = 2

    private static func deduplicated(_ suggestions: [PlaceSuggestion]) -> [PlaceSuggestion] {
        var seen = Set<PlaceSuggestion.ID>()
        return suggestions.filter { seen.insert($0.id).inserted }
    }

    private static func components(of text: String) -> [String] {
        text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func firstComponent(of text: String) -> String {
        components(of: text).first ?? text.trimmingCharacters(in: .whitespaces)
    }

    /// "Hong Kong" from "Hong Kong SAR", or `nil` if the last word isn't a
    /// designation.
    private static func droppingDesignation(from name: String) -> String? {
        var words = name.split(separator: " ")
        guard words.count > 1, let last = words.last,
              last.count >= minimumDesignationLength,
              last.allSatisfy({ $0.isUppercase && $0.isLetter })
        else { return nil }
        words.removeLast()
        return words.joined(separator: " ")
    }

    private static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
