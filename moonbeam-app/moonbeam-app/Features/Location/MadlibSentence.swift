//
//  MadlibSentence.swift
//  moonbeam-app
//

import SwiftUI

/// The main screen's header (DESIGN-1.1.md §3.1, §3.1a): "Where can I find
/// the moon / 📅 tonight in / 📍 Los Angeles, CA?", where the two amber tokens
/// open the calendar and the search sheet.
///
/// Always three lines, so the card below never jumps as the date or city
/// changes length. Each line is one `Text` that first stays on one line,
/// then shrinks (down to 80%), and only then wraps (§3.1a). Each token is a
/// link whose URL an `OpenURLAction` turns back into a view-model call.
/// VoiceOver would read those as links inside the text, so the text is
/// replaced, for accessibility only, by the sentence as a header followed
/// by a real button per token: "Date, tonight, button", "Place, Los
/// Angeles, C A, button", in that order. The words come from `MadlibFormatter` via
/// `LocationViewModel`.
struct MadlibSentence: View {

    let viewModel: LocationViewModel

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: - Constants

    /// Token links use this scheme and the token kind as the host, so the
    /// `OpenURLAction` can tell them apart and never hands them to the system.
    private static let linkScheme = "moonbeam-token"
    private static let dateHost = "date"
    private static let placeHost = "place"

    private static let underlineOpacity = 0.55

    private static let dateHint = "Opens the calendar"
    private static let placeHint = "Opens search"

    // MARK: - Body

    var body: some View {
        let sentence = viewModel.madlibSentence(
            allowsBreaksInsideTokens: dynamicTypeSize.isAccessibilitySize
        )

        VStack(alignment: .leading, spacing: 0) {
            ForEach(sentence.lines.indices, id: \.self) { index in
                SentenceLine(text: Self.text(for: sentence.lines[index]))
            }
        }
        .font(Theme.Fonts.sentence)
        .lineHeight(.multiple(factor: Theme.Fonts.sentenceLineHeightMultiple))
        .foregroundStyle(Theme.Colors.textPrimary)
        .tint(Theme.Colors.accent)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, Theme.Metrics.sentenceInset)
        .environment(\.openURL, OpenURLAction { url in
            guard let kind = Self.tokenKind(for: url) else { return .discarded }
            viewModel.open(kind)
            return .handled
        })
        .accessibilityElement()
        .accessibilityChildren {
            VStack {
                Text(sentence.accessibilityLabel)
                    .accessibilityAddTraits(.isHeader)
                ForEach(sentence.tokens, id: \.kind) { token in
                    Button {
                        viewModel.open(token.kind)
                    } label: {
                        Text(token.accessibilityLabel)
                    }
                    .accessibilityHint(Self.hint(for: token.kind))
                }
            }
        }
    }

    // MARK: - Text

    private static func text(for line: [MadlibFormatter.Part]) -> Text {
        line.reduce(Text(verbatim: "")) { text, part in
            let piece = switch part {
            case let .words(words): Text(verbatim: words)
            case let .token(token): tokenText(token)
            }
            return Text("\(text)\(piece)")
        }
    }

    /// The icon, a non-breaking space so it never wraps away from the first
    /// word (§3.1), then the underlined words as a link.
    private static func tokenText(_ token: MadlibFormatter.Token) -> Text {
        // The symbol is drawn to the HTML's scale beside the sentence's own
        // size, so it takes the line's font and shrinks with it.
        let icon = Text(Image(token.symbol))
            .foregroundStyle(Theme.Colors.accent)

        // The space is its own run, so the underline starts at the word.
        let space = Text(verbatim: MadlibFormatter.nonBreakingSpace)

        var words = AttributedString(token.text)
        words.foregroundColor = Theme.Colors.accent
        words.underlineStyle = Text.LineStyle(
            pattern: .solid,
            color: Theme.Colors.accent.opacity(underlineOpacity)
        )
        words.link = url(for: token.kind)

        return Text("\(icon)\(space)\(Text(words))")
    }

    // MARK: - Links

    private static func url(for kind: MadlibFormatter.Token.Kind) -> URL? {
        var components = URLComponents()
        components.scheme = linkScheme
        components.host = switch kind {
        case .date: dateHost
        case .place: placeHost
        }
        return components.url
    }

    private static func tokenKind(for url: URL) -> MadlibFormatter.Token.Kind? {
        guard url.scheme == linkScheme else { return nil }
        switch url.host() {
        case dateHost: return .date
        case placeHost: return .place
        default: return nil
        }
    }

    private static func hint(for kind: MadlibFormatter.Token.Kind) -> String {
        switch kind {
        case .date: dateHint
        case .place: placeHint
        }
    }
}

// MARK: - Line

/// One of the sentence's three lines (§3.1a): on one line at full size if it
/// fits; else on one line shrunk as far as 80%; else wrapped at full size.
///
/// The shrinking option is measured by the line set at 80%, so
/// `ViewThatFits` only picks it when that fits, but it shows the full-size
/// line scaled just enough for the space it gets.
private struct SentenceLine: View {

    let text: Text

    /// A full-size line's height, scaled like the sentence's font, so a
    /// shrunk line keeps its slot and the card below doesn't move (§3.1a).
    @ScaledMetric(relativeTo: .title)
    private var fullLineHeight = Theme.Fonts.sentenceSize * Theme.Fonts.sentenceLineHeightMultiple

    var body: some View {
        lineThatFits
            .frame(minHeight: fullLineHeight)
    }

    private var lineThatFits: some View {
        ViewThatFits(in: .horizontal) {
            text
                .fixedSize()

            text
                .font(Theme.Fonts.sentenceMinimum)
                .fixedSize()
                .hidden()
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .leading) {
                    text
                        .lineLimit(1)
                        .minimumScaleFactor(Theme.Fonts.sentenceMinimumScale)
                }

            text
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Previews

#Preview("Today") {
    MadlibSentence(viewModel: previewViewModel(place: Place.marVista, dayOffset: 0))
        .padding()
        .background(Theme.Colors.bg)
}

#Preview("Picked day") {
    MadlibSentence(viewModel: previewViewModel(place: Place.marVista, dayOffset: 3))
        .padding()
        .background(Theme.Colors.bg)
}

#Preview("No place") {
    MadlibSentence(viewModel: previewViewModel(place: nil, dayOffset: 0))
        .padding()
        .background(Theme.Colors.bg)
}

/// A view model showing `place`, moved `dayOffset` days from today.
private func previewViewModel(place: Place?, dayOffset: Int) -> LocationViewModel {
    let viewModel = LocationViewModel(
        locationService: FakeLocationService(),
        placeSearch: FakePlaceSearchService(),
        placeStore: InMemoryPlaceStore(),
        moonService: FakeMoonService(),
        headingService: FakeHeadingService()
    )
    if let place {
        viewModel.select(place)
    }
    for _ in 0..<dayOffset {
        viewModel.nextDay()
    }
    return viewModel
}
