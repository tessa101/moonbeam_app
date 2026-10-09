//
//  MadlibSentence.swift
//  moonbeam-app
//

import SwiftUI

/// The main screen's header (DESIGN-1.1.md §3.1, §3.1a, COMPASS-1.1.md §2):
/// "Where can I find / the moon 📅 today / in 📍 Los Angeles, CA?", where the two amber tokens
/// open the calendar and the search sheet.
///
/// Always three lines, so the card below never jumps as the date or city
/// changes length. Each line is one `Text`. At the default size all three
/// share one scale (`MadlibScale`: the smallest any line needs, down to
/// 70%) and a line wraps only below that; at other sizes nothing shrinks
/// and long lines wrap (§3.1a). Each token is a
/// link whose URL an `OpenURLAction` turns back into a view-model call.
/// VoiceOver would read those as links inside the text, so the text is
/// replaced, for accessibility only, by the sentence as a header followed
/// by a real button per token: "Date, today, button", "Place, Los
/// Angeles, C A, button", in that order. The words come from `MadlibFormatter` via
/// `LocationViewModel`.
struct MadlibSentence: View {

    let viewModel: LocationViewModel

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Each line's one-line width at full size, by line index, and the width
    /// the lines get: the inputs to the shared scale.
    @State private var naturalWidths: [Int: CGFloat] = [:]
    @State private var availableWidth: CGFloat = 0
    /// False from the start of detection until the city line has been let
    /// back in (a beat after the city is known).
    @State private var placeRevealed = true

    // MARK: - Constants

    /// Token links use this scheme and the token kind as the host, so the
    /// `OpenURLAction` can tell them apart and never hands them to the system.
    private static let linkScheme = "moonbeam-token"
    private static let dateHost = "date"
    private static let placeHost = "place"

    private static let underlineOpacity = 0.55

    /// Points kept free on the widest line when choosing the shared scale.
    private static let fitTolerance: CGFloat = 2

    /// LOADER.md §12.9: the city token cross-fades in place on a place
    /// change, like a date change (§12.1). Opacity only, so Reduce Motion
    /// keeps it.
    static let placeTokenFade = Animation.easeOut(duration: 0.15)

    /// 5.10a.3 (Tessa, 2026-10-09): while My location is detecting, the
    /// place line is hidden, not a stand-in like "your location"; it fades
    /// in once the city is known. Opacity only, so Reduce Motion keeps it.
    static let placeRevealFade = Animation.easeOut(duration: 0.3)
    private static let placeLineIndex = 2

    private static let dateHint = "Opens the calendar"
    private static let placeHint = "Opens search"

    // MARK: - Body

    var body: some View {
        // Where the sentence doesn't shrink, long lines wrap, so a token
        // may break between its words rather than inside one.
        let sentence = viewModel.madlibSentence(
            allowsBreaksInsideTokens: !MadlibScale.shrinks(at: dynamicTypeSize)
        )

        let scale = MadlibScale.shared(
            naturalWidths: Array(naturalWidths.values),
            // A little slack: glyph widths don't scale exactly with point
            // size, and a line scaled to fit to the point can still wrap.
            availableWidth: availableWidth - Self.fitTolerance,
            minimum: Theme.Fonts.sentenceMinimumScale,
            dynamicTypeSize: dynamicTypeSize
        )

        VStack(alignment: .leading, spacing: 0) {
            ForEach(sentence.lines.indices, id: \.self) { index in
                let text = Self.text(for: sentence.lines[index])
                SentenceLine(text: text, scale: scale)
                    .opacity(hidesLine(index, pending: sentence.placeIsPending) ? 0 : 1)
                    .allowsHitTesting(!hidesLine(index, pending: sentence.placeIsPending))
                    .background(alignment: .leading) {
                        // Measures the line at full size on one line. It
                        // doesn't depend on `scale`, so there's no loop.
                        text
                            .font(Theme.Fonts.sentence)
                            .fixedSize()
                            .hidden()
                            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                                naturalWidths[index] = width
                            }
                    }
            }
        }
        // 5.10a.7: the city line is gone the moment detection starts, not
        // faded out behind the closing search sheet.
        .transaction(value: sentence.placeIsPending) { [isPending = sentence.placeIsPending] transaction in
            if isPending { transaction.disablesAnimations = true }
        }
        .lineHeight(.multiple(factor: Theme.Fonts.sentenceLineHeightMultiple))
        .contentTransition(.opacity)
        .animation(
            Self.placeTokenFade,
            value: sentence.tokens.first { $0.kind == .place }?.text
        )
        // 5.10a.4: the line goes the moment detection starts (the 0.15 s
        // token fade above) and shows once, after the new city's text is
        // already in, so the old name never cross-fades into the new one.
        .onChange(of: sentence.placeIsPending) { _, isPending in
            if isPending {
                placeRevealed = false
            } else {
                withAnimation(Self.placeRevealFade) { placeRevealed = true }
            }
        }
        .onAppear { placeRevealed = !sentence.placeIsPending }
        .foregroundStyle(Theme.Colors.textPrimary)
        .tint(Theme.Colors.accent)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
            availableWidth = width
        }
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

    // MARK: - Place line

    /// The place line stays out while detecting, and until its reveal runs.
    private func hidesLine(_ index: Int, pending: Bool) -> Bool {
        index == Self.placeLineIndex && (pending || !placeRevealed)
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

/// One of the sentence's three lines (§3.1a), set at the scale all three
/// share. It wraps only if it doesn't fit at that scale.
private struct SentenceLine: View {

    let text: Text
    let scale: CGFloat

    /// The sentence's size after Dynamic Type. Scaled here rather than by
    /// `Font.custom(_:size:relativeTo:)`, which rounds a size like 26.6 back
    /// up to 27, so a line meant to just fit would wrap.
    @ScaledMetric(relativeTo: .title)
    private var fullSize = Theme.Fonts.sentenceSize

    /// A full-size line's fixed slot, so fractional font metrics at different
    /// shared scales can't move the card below (§3.1a, §9.19).
    private var fullLineHeight: CGFloat {
        fullSize * Theme.Fonts.sentenceLineHeightMultiple
    }

    var body: some View {
        text
            .font(Theme.Fonts.sentence(fixedSize: fullSize * scale))
            .fixedSize(horizontal: false, vertical: true)
            .frame(height: fullLineHeight)
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

#Preview("Irvine") {
    MadlibSentence(viewModel: previewViewModel(place: Place.irvine, dayOffset: 0))
        // The main screen's margin, so lines get the app's width.
        .padding(.horizontal, Theme.Metrics.screenMargin)
        .background(Theme.Colors.bg)
}

#Preview("Rancho Santa Margarita") {
    MadlibSentence(viewModel: previewViewModel(place: Place.ranchoSantaMargarita, dayOffset: 0))
        // The main screen's margin, so lines get the app's width.
        .padding(.horizontal, Theme.Metrics.screenMargin)
        .background(Theme.Colors.bg)
}

/// January 4 next year, so the date token carries the year.
#Preview("Other year") {
    MadlibSentence(viewModel: previewViewModel(place: Place.ranchoSantaMargarita, day: nextYearDay()))
        // The main screen's margin, so lines get the app's width.
        .padding(.horizontal, Theme.Metrics.screenMargin)
        .background(Theme.Colors.bg)
}

#Preview("No place") {
    MadlibSentence(viewModel: previewViewModel(place: nil, dayOffset: 0))
        .padding()
        .background(Theme.Colors.bg)
}

/// January 4 next year.
private func nextYearDay() -> DateComponents {
    let year = Calendar.current.component(.year, from: Date()) + 1
    return DateComponents(year: year, month: 1, day: 4)
}

/// A view model showing `place` on `day`, as if picked in the calendar.
private func previewViewModel(place: Place, day: DateComponents) -> LocationViewModel {
    let viewModel = previewViewModel(place: place, dayOffset: 0)
    viewModel.select(day: day)
    return viewModel
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
