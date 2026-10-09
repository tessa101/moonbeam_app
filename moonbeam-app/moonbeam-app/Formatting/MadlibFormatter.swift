//
//  MadlibFormatter.swift
//  moonbeam-app
//

import Accessibility
import Foundation

/// Builds the main screen's madlib sentence (DESIGN-1.1.md §3.1, §3.1a):
/// "Where can I find / the moon 📅 today / in 📍 Los Angeles, CA?", as three
/// lines of plain words and two tokens, plus what VoiceOver says for each.
///
/// The date token reads "today" on the place's today (COMPASS-1.1.md §2; it
/// was "tonight") and "on Sat, Oct 3"
/// otherwise, with the year only in another year (DATE.md's rule, through
/// `DayLabelFormatter`). With no place yet the place token reads "a city"
/// and the date is plain words: there's no place's calendar to pick a day
/// in, and the design draws no 📅 there (§11 Q2).
///
/// `nonisolated` because it's a pure mapping over its inputs.
nonisolated struct MadlibFormatter {

    // MARK: - Types

    /// One run of the sentence.
    enum Part: Equatable {
        /// Plain words in `textPrimary`.
        case words(String)
        /// An amber, underlined, tappable token.
        case token(Token)
    }

    /// A tappable token: what it opens, its icon and text, and its spoken
    /// button label.
    struct Token: Equatable {

        enum Kind: Equatable {
            /// Opens the calendar sheet.
            case date
            /// Opens the search sheet.
            case place
        }

        let kind: Kind
        /// The custom symbol drawn before the first word (asset catalog,
        /// from the HTML's SVGs; §3.1a).
        let symbol: String
        /// The token's words. Spaces inside are non-breaking unless breaks
        /// are allowed (every size but the default).
        let text: String
        /// "Date, today" / "Place, Los Angeles, CA". An attributed string
        /// so a region abbreviation is spelled out ("C A").
        let accessibilityLabel: AttributedString
    }

    /// The whole sentence.
    struct Sentence: Equatable {
        /// Always three lines, broken explicitly (§3.1a): the lead, "the
        /// moon" + the date, "in" + the place + "?". A line may still wrap
        /// if it can't fit.
        let lines: [[Part]]
        /// The sentence read as one line, with ordinary spaces and no icons,
        /// for the header element VoiceOver reads before the two buttons.
        let accessibilityLabel: String

        /// The tokens in reading order, for VoiceOver's buttons.
        var tokens: [Token] {
            lines.joined().compactMap { part in
                if case let .token(token) = part { token } else { nil }
            }
        }
    }

    // MARK: - Constants

    static let dateSymbol = "token.calendar"
    static let placeSymbol = "token.pin"

    /// Keeps a token's words, and its icon, on one line.
    static let nonBreakingSpace = "\u{00A0}"

    private static let lead = "Where can I find"
    private static let dateLead = "the moon"
    private static let placeLead = "in"
    private static let end = "?"

    private static let today = "today"
    private static let datePrefix = "on "
    private static let noPlace = "a city"

    private static let dateLabelPrefix = "Date, "
    private static let placeLabelPrefix = "Place, "
    private static let noPlaceLabel = "choose a city"

    /// Region parts up to this long, all capitals, are abbreviations ("CA",
    /// "NSW") and get spelled out; longer ones ("England") are words.
    private static let maximumAbbreviationLength = 3

    // MARK: - Configuration

    let locale: Locale

    private let dayLabels: DayLabelFormatter

    /// - Parameter locale: injectable so tests can pin `en_US`.
    init(locale: Locale = .autoupdatingCurrent) {
        self.locale = locale
        dayLabels = DayLabelFormatter(locale: locale)
    }

    // MARK: - Sentence

    /// The sentence for `place` on `day`.
    ///
    /// - Parameters:
    ///   - place: `nil` before any place is chosen.
    ///   - standIn: with no place, a name for the place token anyway: the
    ///     last-viewed place while the launch fix runs, so the sentence
    ///     isn't "a city" for a moment (LOCATION.md §3). The date stays
    ///     plain words.
    ///   - dateTimeZone: with no place, the zone the date token is read in,
    ///     so a pending place change keeps the selected date (LOADER.md
    ///     §12.9). `nil`: plain "today" words, as before any place.
    ///   - day: the selected day's start in the place's zone (or
    ///     `dateTimeZone`); ignored with neither.
    ///   - dayOffset: days from the place's today (0 = today).
    ///   - today: any moment in the place's today, such as now.
    ///   - allowsBreaksInsideTokens: true wherever the sentence doesn't
    ///     shrink (every size but the default), so a long token wraps
    ///     between its words. Its icon always stays attached.
    func sentence(
        place: Place?,
        standIn: Place? = nil,
        standInText: String? = nil,
        dateTimeZone: TimeZone? = nil,
        day: Date,
        dayOffset: Int,
        today: Date,
        allowsBreaksInsideTokens: Bool
    ) -> Sentence {
        let space = allowsBreaksInsideTokens ? " " : Self.nonBreakingSpace

        let dateLine: [Part]
        let dateWords: String
        if let zone = place?.timeZone ?? dateTimeZone {
            let date = dateToken(timeZone: zone, day: day, dayOffset: dayOffset, today: today)
            dateWords = date.text
            dateLine = [.words(Self.dateLead + " "), .token(date.withSpaces(space))]
        } else {
            dateWords = Self.today
            dateLine = [.words(Self.dateLead + " " + Self.today)]
        }

        let place = placeToken(place ?? standIn, standInText: standInText)
        let placeLine: [Part] = [
            .words(Self.placeLead + " "),
            .token(place.withSpaces(space)),
            // Straight after the city, no space: line breaking never
            // breaks before a "?" (UAX #14 class EX), so it stays with the
            // city. Not a word joiner (U+2060): with one, a line that had to
            // shrink never finished laying out.
            .words(Self.end),
        ]

        return Sentence(
            lines: [[.words(Self.lead)], dateLine, placeLine],
            accessibilityLabel: [Self.lead, Self.dateLead, dateWords, Self.placeLead, place.text + Self.end]
                .joined(separator: " ")
        )
    }

    // MARK: - Tokens

    private func dateToken(timeZone: TimeZone, day: Date, dayOffset: Int, today: Date) -> Token {
        let text: String
        let spoken: String
        if dayOffset == 0 {
            text = Self.today
            spoken = Self.today
        } else {
            text = Self.datePrefix + dayLabels.label(for: day, today: today, timeZone: timeZone)
            spoken = dayLabels.spokenLabel(for: day, today: today, timeZone: timeZone)
        }
        return Token(
            kind: .date,
            symbol: Self.dateSymbol,
            text: text,
            accessibilityLabel: AttributedString(Self.dateLabelPrefix + spoken)
        )
    }

    private func placeToken(_ place: Place?, standInText: String? = nil) -> Token {
        if let standInText {
            return Token(
                kind: .place,
                symbol: Self.placeSymbol,
                text: standInText,
                accessibilityLabel: AttributedString(Self.placeLabelPrefix + standInText)
            )
        }
        guard let place else {
            return Token(
                kind: .place,
                symbol: Self.placeSymbol,
                text: Self.noPlace,
                accessibilityLabel: AttributedString(Self.placeLabelPrefix + Self.noPlaceLabel)
            )
        }
        return Token(
            kind: .place,
            symbol: Self.placeSymbol,
            text: place.nameWithRegion,
            accessibilityLabel: Self.placeLabel(for: place)
        )
    }

    /// "Place, Los Angeles, CA" with "CA" spelled out, so VoiceOver says
    /// "C A" (§3.1) rather than guessing at a word.
    private static func placeLabel(for place: Place) -> AttributedString {
        var label = AttributedString(placeLabelPrefix + place.name)
        let full = place.nameWithRegion
        guard full != place.name else { return label }

        // `nameWithRegion` is "name, region"; split off the ", " so only
        // the region itself is spelled out, not the comma.
        let rest = full.dropFirst(place.name.count)
        let region = rest.drop { !$0.isLetter }
        label.append(AttributedString(String(rest.prefix(rest.count - region.count))))
        var regionRun = AttributedString(String(region))
        if isAbbreviation(region) {
            regionRun.accessibilitySpeechSpellsOutCharacters = true
        }
        label.append(regionRun)
        return label
    }

    private static func isAbbreviation(_ text: Substring) -> Bool {
        !text.isEmpty
            && text.count <= maximumAbbreviationLength
            && text.allSatisfy { $0.isUppercase && $0.isLetter }
    }
}

// MARK: - Spaces

nonisolated private extension MadlibFormatter.Token {

    /// The same token with its inner spaces replaced, so it wraps as a unit
    /// (non-breaking) or freely (ordinary spaces).
    func withSpaces(_ space: String) -> Self {
        Self(
            kind: kind,
            symbol: symbol,
            text: text.replacingOccurrences(of: " ", with: space),
            accessibilityLabel: accessibilityLabel
        )
    }
}
