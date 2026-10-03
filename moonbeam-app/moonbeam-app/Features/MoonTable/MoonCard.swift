//
//  MoonCard.swift
//  moonbeam-app
//

import SwiftUI

/// The moon card (DESIGN-1.1.md §3.2, COMPASS-1.1.md §9.2): a header row
/// (phase glyph, the selected day over the phase, ‹ ›), then moonrise and
/// moonset side by side, and on today the Up now pill (or when it rises). A
/// compass lock outlines the matching cell.
///
/// Layout and announcements only. Day stepping is `LocationViewModel`'s
/// (DATE.md), the card's text is `MoonTableViewModel`'s, Up now and the lock
/// are the compass's.
struct MoonCard: View {

    let viewModel: LocationViewModel
    let table: MoonTableViewModel

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: - Header constants (COMPASS-1.1.md §9.2)

    /// Between the glyph, the two text lines and the ‹ › hit areas.
    private static let headerSpacing: CGFloat = 12
    /// Between the date line and the phase line.
    private static let headerTextSpacing: CGFloat = 2
    /// The ‹ › 44 pt hit areas reach into the card's padding, so the 32 pt
    /// circles sit where the design draws them.
    private static let headerTrailingOutset: CGFloat = 6
    private static let stepButtonSpacing: CGFloat = 0

    private static let glyphSize: CGFloat = 44
    /// Between the phase name and its illumination ("Last Quarter · 53% lit").
    private static let phaseSeparator = " · "

    // MARK: - Rise/set constants

    /// Between the Moonrise and Moonset cells (the HTML's grid gap).
    private static let columnGap: CGFloat = 6
    private static let columnSpacing: CGFloat = 4
    /// Between a time and its zone abbreviation, side by side or stacked.
    private static let timeZoneSpacing: CGFloat = 4
    /// "No moonrise today" sits a little lower than a time would.
    private static let missingTopPadding: CGFloat = 4

    // MARK: - Cell constants (COMPASS-1.1.md §3, read from the HTML)

    /// The data cells (`CellStyle`) reach this far into the card's padding,
    /// so their text sits just inside the header's.
    private static let cellOutset: CGFloat = 6

    // MARK: - Up now constants (COMPASS-1.1.md §9.2)

    /// The pill's height on one line; its radius is half of it.
    private static let pillHeight: CGFloat = 36
    private static let pillPaddingHorizontal: CGFloat = 14
    private static let pillPaddingVertical: CGFloat = 6
    /// Between the dot and the text.
    private static let upNowItemSpacing: CGFloat = 8
    private static let upNowDotSize: CGFloat = 8

    // MARK: - Card

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.cardSpacing) {
            header
            hairline
            riseSetRow
            // COMPASS-1.1.md §3: today with the compass shown; hidden on
            // other dates.
            if let upNow = viewModel.compass.upNow, let line = upNow.line {
                upNowRow(upNow, line: line)
            }
        }
        .padding(.vertical, Theme.Metrics.cardPaddingVertical)
        .padding(.horizontal, Theme.Metrics.cardPaddingHorizontal)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface, in: cardShape)
        .overlay {
            cardShape.strokeBorder(Theme.Colors.stroke, lineWidth: Theme.Metrics.hairline)
        }
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.Metrics.cardCornerRadius)
    }

    private var hairline: some View {
        Rectangle()
            .fill(Theme.Colors.stroke)
            .frame(height: Theme.Metrics.hairline)
            .accessibilityHidden(true)
    }

    // MARK: - Header row

    /// Glyph, the two text lines, ‹ ›. At accessibility sizes the text
    /// gets its own full-width rows under the glyph and ‹ ›, since squeezed
    /// between them it wraps a word per line.
    @ViewBuilder
    private var header: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Self.headerSpacing) {
                HStack(spacing: Self.headerSpacing) {
                    glyph
                    Spacer(minLength: 0)
                    stepButtons
                }
                .padding(.trailing, -Self.headerTrailingOutset)
                headerText
            }
        } else {
            HStack(spacing: Self.headerSpacing) {
                glyph
                headerText
                    .frame(maxWidth: .infinity, alignment: .leading)
                stepButtons
            }
            .padding(.trailing, -Self.headerTrailingOutset)
        }
    }

    private var glyph: some View {
        PhaseGlyph(geometry: table.glyph)
            .frame(width: Self.glyphSize, height: Self.glyphSize)
            .accessibilityHidden(true)
    }

    /// "Today · Fri, Oct 2" over "Last Quarter · 53% lit".
    private var headerText: some View {
        VStack(alignment: .leading, spacing: Self.headerTextSpacing) {
            dateLabel
            phaseLine
        }
    }

    private var stepButtons: some View {
        HStack(spacing: Self.stepButtonSpacing) {
            stepButton("Previous day", systemImage: "chevron.left", enabled: viewModel.canGoBack) {
                viewModel.previousDay()
            }
            stepButton("Next day", systemImage: "chevron.right", enabled: viewModel.canGoForward) {
                viewModel.nextDay()
            }
        }
    }

    /// For VoiceOver it's adjustable: swipe up or down moves a day, and the
    /// new value is read automatically (DATE.md §5).
    private var dateLabel: some View {
        Text(viewModel.cardDateLabel)
            .font(Theme.Fonts.label)
            .foregroundStyle(Theme.Colors.textSecondary)
            .accessibilityLabel("Date")
            .accessibilityValue(viewModel.dateAccessibilityValue)
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: viewModel.nextDay()
                case .decrement: viewModel.previousDay()
                @unknown default: break
                }
            }
    }

    /// "Last Quarter · 53% lit" on one line; when that doesn't fit ("Waning
    /// Crescent · 21% lit" on a 402 pt phone), the name over "21% lit", so
    /// the "·" is never left at a line's end. VoiceOver keeps "at midnight".
    private var phaseLine: some View {
        let name = Text(table.phaseName)
            .foregroundStyle(Theme.Colors.textPrimary)
        let lit = Text(table.illuminationText)
            .foregroundStyle(Theme.Colors.textSecondary)
        let separator = Text(Self.phaseSeparator)
            .foregroundStyle(Theme.Colors.textSecondary)
        return ViewThatFits(in: .horizontal) {
            Text("\(name)\(separator)\(lit)")
                .lineLimit(1)
            VStack(alignment: .leading, spacing: Self.headerTextSpacing) {
                name
                lit
            }
        }
        .font(Theme.Fonts.phaseName)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(table.phaseAccessibilityLabel)
    }

    private func stepButton(
        _ title: String,
        systemImage: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
            announceDate()
        } label: {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
        }
        .buttonStyle(DayStepButtonStyle())
        .disabled(!enabled)
    }

    /// DATE.md §5: changing the day with ‹ or › announces the new date. The
    /// adjustable label doesn't need this, since VoiceOver reads its value.
    private func announceDate() {
        AccessibilityNotification.Announcement(viewModel.dateAccessibilityValue).post()
    }

    // MARK: - Rise/set row

    /// Two equal cells, as tall as the taller one, so a highlighted cell's
    /// outline matches its neighbour's height (COMPASS-1.1.md §3). Since
    /// 5.4.6 they hug their content (no minimum height).
    private var riseSetRow: some View {
        HStack(alignment: .top, spacing: Self.columnGap) {
            column(table.rise, isHighlighted: viewModel.highlightedCardCell == .moonrise)
            column(table.set, isHighlighted: viewModel.highlightedCardCell == .moonset)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, -Self.cellOutset)
    }

    private func column(_ column: MoonTableViewModel.Column, isHighlighted: Bool) -> some View {
        VStack(alignment: .leading, spacing: Self.columnSpacing) {
            Text(column.title)
                .font(Theme.Fonts.label)
                .foregroundStyle(isHighlighted ? Theme.Colors.accent : Theme.Colors.textSecondary)

            switch column.detail {
            case let .time(time, timeZone, direction):
                timeView(time, timeZone: timeZone)
                Text(direction)
                    .font(Theme.Fonts.detail)
                    .foregroundStyle(Theme.Colors.accent)
            case let .missing(text):
                Text(text)
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .padding(.top, Self.missingTopPadding)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .modifier(CellStyle(isHighlighted: isHighlighted, restingFill: .clear))
        .frame(maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(column.accessibilityLabel)
    }

    /// "11:13 PM AEST", baseline-aligned; the zone wraps under the time when
    /// the two don't fit side by side (§3.2).
    @ViewBuilder
    private func timeView(_ time: TimeText, timeZone: String?) -> some View {
        // The display font as the base too, so the line is measured for
        // Young Serif 24, not the body font, and it wraps instead of being
        // cut short at AX sizes.
        let timeText = Self.text(for: time)
            .font(Theme.Fonts.display)
            .foregroundStyle(Theme.Colors.textPrimary)
            .fixedSize(horizontal: false, vertical: true)

        if let timeZone {
            let zoneText = Text(timeZone)
                .font(Theme.Fonts.note)
                .foregroundStyle(Theme.Colors.textSecondary)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: Self.timeZoneSpacing) {
                    timeText
                    zoneText
                }
                VStack(alignment: .leading, spacing: Self.timeZoneSpacing) {
                    timeText
                    zoneText
                }
            }
        } else {
            timeText
        }
    }

    // MARK: - Up now (COMPASS-1.1.md §9.2)

    /// Moon up: the pill "● Up now · 266° W", outlined when the compass is
    /// locked on the Moon. Down: the plain line "● Rises 11:10 PM", same
    /// height, so the card doesn't jump as the moon rises or sets. One
    /// element for VoiceOver, with the formatter's sentence (§3).
    private func upNowRow(_ upNow: UpNow, line: String) -> some View {
        let isUp = upNow.isUp
        let isHighlighted = viewModel.highlightedCardCell == .upNow
        let shape = RoundedRectangle(cornerRadius: Self.pillHeight / 2)
        return HStack(spacing: Self.upNowItemSpacing) {
            Circle()
                .fill(isUp ? Theme.Colors.moonLit : Theme.Colors.faint)
                .frame(width: Self.upNowDotSize, height: Self.upNowDotSize)
            Text(line)
                .font(Theme.Fonts.label)
                .foregroundStyle(isUp ? Theme.Colors.accent : Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Self.pillPaddingHorizontal)
        .padding(.vertical, Self.pillPaddingVertical)
        .frame(maxWidth: .infinity, minHeight: Self.pillHeight, alignment: .leading)
        .background(isUp ? Theme.Colors.surfaceInset : .clear, in: shape)
        .overlay {
            shape.strokeBorder(isHighlighted ? Theme.Colors.accent : .clear, lineWidth: Theme.Metrics.hairline)
        }
        .padding(.horizontal, -Self.cellOutset)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(upNow.accessibilityLabel)
    }
}

// MARK: - Time

private extension MoonCard {

    /// The formatter's space before the day period ("9:10\u{202F}PM").
    static let narrowNoBreakSpace = "\u{202F}"

    /// One `Text`, so the digits and the smaller day period share a
    /// baseline. The formatter's no-break space becomes an ordinary one, so
    /// a time too wide for its column (AX sizes) puts the day period on the
    /// next line instead of breaking inside it ("8:53 A / M").
    static func text(for time: TimeText) -> Text {
        time.runs.reduce(Text(verbatim: "")) { text, run in
            let words = run.text.replacingOccurrences(of: narrowNoBreakSpace, with: " ")
            let piece = Text(verbatim: words)
                .font(run.isDayPeriod ? Theme.Fonts.dayPeriod : Theme.Fonts.display)
            return Text("\(text)\(piece)")
        }
    }
}

// MARK: - Cell style (COMPASS-1.1.md §3)

/// A data cell's box: padded and rounded, with the lock highlight (1 pt
/// `accent` border, `accent` 10% fill) when it's the locked target's cell.
/// Unlocked, the border is drawn clear, so locking shifts nothing.
private struct CellStyle: ViewModifier {

    let isHighlighted: Bool
    /// The fill while not highlighted: none for Moonrise and Moonset.
    let restingFill: Color

    private static let paddingVertical: CGFloat = 8
    private static let paddingHorizontal: CGFloat = 10
    private static let cornerRadius: CGFloat = 14
    private static let highlightFillOpacity = 0.1

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Self.cornerRadius)
        content
            .padding(.vertical, Self.paddingVertical)
            .padding(.horizontal, Self.paddingHorizontal)
            .background(
                isHighlighted ? Theme.Colors.accent.opacity(Self.highlightFillOpacity) : restingFill,
                in: shape
            )
            .overlay {
                shape.strokeBorder(isHighlighted ? Theme.Colors.accent : .clear, lineWidth: Theme.Metrics.hairline)
            }
    }
}

// MARK: - ‹ › button style

/// §2: a 32 pt raised circle with a faint top highlight and a soft shadow,
/// centred in a 44 pt hit area.
private struct DayStepButtonStyle: ButtonStyle {

    @Environment(\.isEnabled) private var isEnabled

    private static let highlightOpacity = 0.06
    private static let highlightHeight: CGFloat = 1
    private static let shadowOpacity = 0.25
    /// CSS `0 2px 6px`: SwiftUI's radius is about half a CSS blur.
    private static let shadowRadius: CGFloat = 3
    private static let shadowOffsetY: CGFloat = 2
    private static let disabledOpacity = 0.35

    func makeBody(configuration: Configuration) -> some View {
        let circle = Circle()
        let inner = circle.inset(by: Theme.Metrics.hairline)

        configuration.label
            .font(Theme.Fonts.label)
            .foregroundStyle(Theme.Colors.textPrimary)
            .frame(width: Theme.Metrics.stepButtonSize, height: Theme.Metrics.stepButtonSize)
            .background {
                circle
                    .fill(Theme.Colors.surfaceRaised)
                    .shadow(
                        color: .black.opacity(Self.shadowOpacity),
                        radius: Self.shadowRadius,
                        y: Self.shadowOffsetY
                    )
            }
            .overlay {
                // CSS `inset 0 1px 0`: a 1 pt crescent along the inner top edge.
                inner
                    .subtracting(inner.offset(y: Self.highlightHeight))
                    .fill(.white.opacity(Self.highlightOpacity))
            }
            .overlay {
                circle.strokeBorder(Theme.Colors.strokeRaised, lineWidth: Theme.Metrics.hairline)
            }
            .opacity(isEnabled ? 1 : Self.disabledOpacity)
            // The circle, not its 44 pt target, shrinks and dims
            // (DECISIONS.md "Tap animation").
            .pressFeedback(isPressed: configuration.isPressed)
            .frame(width: Theme.Metrics.minimumHitTarget, height: Theme.Metrics.minimumHitTarget)
            .contentShape(Rectangle())
    }
}

// MARK: - Previews

#Preview("Today, Los Angeles") {
    previewCard(place: .marVista, dayOffset: 0)
}

#Preview("Sat, Oct 3: no moonrise") {
    previewCard(place: .marVista, dayOffset: 3)
}

#Preview("Up now: moon up") {
    UpNowPreview(isMoonUp: true)
}

#Preview("Up now: moon down") {
    UpNowPreview(isMoonUp: false)
}

#Preview("Locked on the moon") {
    UpNowPreview(isMoonUp: true, heading: 266)
}

#Preview("Locked on moonset") {
    UpNowPreview(isMoonUp: true, heading: 303)
}

#Preview("Locked on moonrise") {
    UpNowPreview(isMoonUp: false, heading: 58)
}

/// The design's sky (COMPASS-1.1.md source, state 1 and 4) from fakes: Irvine
/// at 7:53 AM on Fri, Oct 2, detected, so the compass and its Up now row
/// show. Moon up at 266° on the pass from 10:06 PM to 1:28 PM; or down,
/// rising in 34 minutes. With a `heading`, the compass is on screen and
/// reads it, so it locks onto the target there.
private struct UpNowPreview: View {

    let viewModel: LocationViewModel

    /// Well inside the compass's low-accuracy threshold.
    private static let goodAccuracy = 3.0

    init(isMoonUp: Bool, heading: Double? = nil) {
        let headingService = FakeHeadingService()
        viewModel = Self.makeViewModel(isMoonUp: isMoonUp, headingService: headingService)
        if let heading {
            viewModel.compass.setOnScreen(true)
            headingService.send(HeadingReading(trueHeading: heading, accuracy: Self.goodAccuracy))
        }
    }

    /// In a scroll view, as on the main screen, so AX sizes don't squeeze it.
    var body: some View {
        ScrollView {
            if let table = viewModel.moonTable {
                MoonCard(viewModel: viewModel, table: table)
                    .padding(20)
            }
        }
        .background(Theme.Colors.bg)
        .font(Theme.Fonts.body)
    }

    private static func makeViewModel(isMoonUp: Bool, headingService: FakeHeadingService) -> LocationViewModel {
        let zone = Place.irvine.timeZone
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        func time(_ day: Int, _ hour: Int, _ minute: Int) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute)) ?? .now
        }
        let now = time(2, 7, 53)
        let here = Place(
            name: "Irvine",
            region: "CA",
            latitude: Place.irvine.latitude,
            longitude: Place.irvine.longitude,
            timeZone: zone,
            isCurrentLocation: true
        )
        let moon = FakeMoonService(
            rise: MoonEvent(date: time(2, 23, 10), azimuth: 57),
            set: MoonEvent(date: time(2, 13, 28), azimuth: 304),
            phaseAngle: 270,
            illumination: 0.53,
            position: MoonPosition(azimuth: 266, isUp: isMoonUp),
            pass: MoonPass(
                rise: MoonEvent(date: time(1, 22, 6), azimuth: 56),
                set: MoonEvent(date: time(2, 13, 28), azimuth: 304),
                path: [56, 304]
            )
        )
        moon.nextRise = MoonEvent(date: now.addingTimeInterval(34 * 60), azimuth: 57)
        let viewModel = LocationViewModel(
            locationService: FakeLocationService(authorizationState: .authorized, placeResult: .success(here)),
            placeSearch: FakePlaceSearchService(),
            placeStore: InMemoryPlaceStore(),
            moonService: moon,
            headingService: headingService,
            deviceTimeZone: zone,
            now: { now }
        )
        // A current-location place is "Here": the compass shows.
        viewModel.select(here)
        return viewModel
    }
}

/// A card for `place`, moved `dayOffset` days from today, on the real engine.
private func previewCard(place: Place, dayOffset: Int) -> some View {
    let viewModel = LocationViewModel(
        locationService: FakeLocationService(),
        placeSearch: FakePlaceSearchService(),
        placeStore: InMemoryPlaceStore(),
        moonService: AstronomyEngineMoonService(),
        headingService: FakeHeadingService()
    )
    viewModel.select(place)
    for _ in 0..<dayOffset {
        viewModel.nextDay()
    }
    return Group {
        if let table = viewModel.moonTable {
            MoonCard(viewModel: viewModel, table: table)
        }
    }
    .padding(20)
    .frame(maxHeight: .infinity, alignment: .top)
    .background(Theme.Colors.bg)
    .font(Theme.Fonts.body)
}
