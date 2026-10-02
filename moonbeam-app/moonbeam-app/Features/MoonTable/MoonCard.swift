//
//  MoonCard.swift
//  moonbeam-app
//

import SwiftUI

/// The moon card (DESIGN-1.1.md §3.2): the selected day with ‹ ›, the phase,
/// then moonrise and moonset side by side.
///
/// Layout and announcements only. Day stepping is `LocationViewModel`'s
/// (DATE.md), the card's text is `MoonTableViewModel`'s.
struct MoonCard: View {

    let viewModel: LocationViewModel
    let table: MoonTableViewModel

    // MARK: - Layout constants (§3.2, read from the HTML)

    /// Between the date label and the ‹ › hit areas.
    private static let headerSpacing: CGFloat = 8
    /// The header's 44 pt hit areas reach into the card's padding, so the
    /// 32 pt circles sit where the design draws them.
    private static let headerTopOutset: CGFloat = 6
    private static let headerTrailingOutset: CGFloat = 8

    private static let glyphSize: CGFloat = 44
    private static let phaseSpacing: CGFloat = 14
    private static let phaseTextSpacing: CGFloat = 4

    /// Gap on each side of the rise/set divider.
    private static let columnGap: CGFloat = 18
    private static let columnMinHeight: CGFloat = 76
    private static let columnSpacing: CGFloat = 6
    /// Between a time and its zone abbreviation, side by side or stacked.
    private static let timeZoneSpacing: CGFloat = 4
    /// "No moonrise today" sits a little lower than a time would.
    private static let missingTopPadding: CGFloat = 4

    // MARK: - Up now constants (COMPASS-1.1.md §3, read from the HTML)

    private static let cellPaddingVertical: CGFloat = 8
    private static let cellPaddingHorizontal: CGFloat = 10
    private static let cellCornerRadius: CGFloat = 14
    /// The cell reaches this far into the card's padding, so its text sits
    /// just inside the header's, as in the HTML (12 pt card padding there,
    /// 18 here).
    private static let cellOutset: CGFloat = 6

    /// Between the headline and the bar.
    private static let upNowSpacing: CGFloat = 7
    /// Between the dot, the title, the bar and its times.
    private static let upNowItemSpacing: CGFloat = 8
    /// The headline's two halves, stacked at large sizes.
    private static let upNowStackedSpacing: CGFloat = 4
    private static let upNowDotSize: CGFloat = 8

    private static let barHeight: CGFloat = 2
    private static let barFillOpacity = 0.6
    /// The bar never squeezes below this between its two times.
    private static let barMinWidth: CGFloat = 40
    /// The thumb: a mini phase glyph in a `surface` ring, softly glowing.
    private static let thumbSize: CGFloat = 14
    private static let thumbOutline: CGFloat = 1.5
    private static let thumbGlowOpacity = 0.6
    /// CSS `0 0 8px`: SwiftUI's radius is about half a CSS blur.
    private static let thumbGlowRadius: CGFloat = 4

    // MARK: - Card

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.cardSpacing) {
            header
            phaseRow
            hairline
            riseSetRow
            // COMPASS-1.1.md §3: today with the compass shown; hidden on
            // other dates.
            if let upNow = viewModel.compass.upNow {
                upNowRow(upNow)
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

    private var header: some View {
        HStack(spacing: Self.headerSpacing) {
            dateLabel
            stepButton("Previous day", systemImage: "chevron.left", enabled: viewModel.canGoBack) {
                viewModel.previousDay()
            }
            stepButton("Next day", systemImage: "chevron.right", enabled: viewModel.canGoForward) {
                viewModel.nextDay()
            }
        }
        .padding(.top, -Self.headerTopOutset)
        .padding(.trailing, -Self.headerTrailingOutset)
    }

    /// For VoiceOver it's adjustable: swipe up or down moves a day, and the
    /// new value is read automatically (DATE.md §5).
    private var dateLabel: some View {
        Text(viewModel.cardDateLabel)
            .font(Theme.Fonts.label)
            .foregroundStyle(Theme.Colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
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

    // MARK: - Phase row

    private var phaseRow: some View {
        HStack(spacing: Self.phaseSpacing) {
            PhaseGlyph(geometry: table.glyph)
                .frame(width: Self.glyphSize, height: Self.glyphSize)
            VStack(alignment: .leading, spacing: Self.phaseTextSpacing) {
                Text(table.phaseName)
                    .font(Theme.Fonts.phaseName)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(table.illuminationText)
                    .font(Theme.Fonts.detail)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(table.phaseAccessibilityLabel)
    }

    // MARK: - Rise/set row

    /// Two equal columns with a hairline between. The hairline is an overlay
    /// at the centre, which is where the gap between equal columns is, so it
    /// spans the row's full height whichever column is taller.
    private var riseSetRow: some View {
        HStack(alignment: .top, spacing: 2 * Self.columnGap + Theme.Metrics.hairline) {
            column(table.rise)
            column(table.set)
        }
        .frame(minHeight: Self.columnMinHeight, alignment: .top)
        .overlay {
            Rectangle()
                .fill(Theme.Colors.stroke)
                .frame(width: Theme.Metrics.hairline)
                .accessibilityHidden(true)
        }
    }

    private func column(_ column: MoonTableViewModel.Column) -> some View {
        VStack(alignment: .leading, spacing: Self.columnSpacing) {
            Text(column.title)
                .font(Theme.Fonts.label)
                .foregroundStyle(Theme.Colors.textSecondary)

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
        .frame(maxWidth: .infinity, alignment: .leading)
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

    // MARK: - Up now row (COMPASS-1.1.md §3)

    /// One element for VoiceOver, with the formatter's sentence. The bar's
    /// line is kept while the moon is down, hidden, so the card keeps its
    /// height as the moon rises or sets.
    private func upNowRow(_ upNow: UpNow) -> some View {
        VStack(alignment: .leading, spacing: Self.upNowSpacing) {
            upNowHeadline(upNow)
            if case let .up(_, pass?) = upNow.state {
                upNowBar(pass)
            } else {
                upNowBar(Self.placeholderPass)
                    .hidden()
            }
        }
        .padding(.vertical, Self.cellPaddingVertical)
        .padding(.horizontal, Self.cellPaddingHorizontal)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surfaceInset, in: RoundedRectangle(cornerRadius: Self.cellCornerRadius))
        .padding(.horizontal, -Self.cellOutset)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(upNow.accessibilityLabel)
    }

    /// Holds the bar's line open while the moon is down; never shown.
    private static let placeholderPass = UpNow.Pass(progress: 0, riseTime: "12:00 PM", setTime: "12:00 PM")

    /// "● Up now ……… 266° W" on one line, or stacked when the two don't fit
    /// (AX sizes).
    private func upNowHeadline(_ upNow: UpNow) -> some View {
        let title = HStack(spacing: Self.upNowItemSpacing) {
            Circle()
                .fill(upNow.isUp ? Theme.Colors.moonLit : Theme.Colors.faint)
                .frame(width: Self.upNowDotSize, height: Self.upNowDotSize)
            Text(upNow.title)
                .font(Theme.Fonts.label)
                .foregroundStyle(Theme.Colors.textBody)
        }
        let detail = Self.detail(of: upNow).map { text in
            Text(text)
                .font(Theme.Fonts.label)
                .foregroundStyle(upNow.isUp ? Theme.Colors.accent : Theme.Colors.textSecondary)
        }
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: Self.upNowItemSpacing) {
                title
                Spacer(minLength: Self.upNowItemSpacing)
                detail
            }
            VStack(alignment: .leading, spacing: Self.upNowStackedSpacing) {
                title
                detail
            }
        }
    }

    /// The right side: the bearing, or when it rises.
    private static func detail(of upNow: UpNow) -> String? {
        switch upNow.state {
        case let .up(bearing, _): bearing
        case let .down(nextRise): nextRise
        }
    }

    /// "10:06 PM ━━━━━●───── 1:28 PM", or at large sizes, where the times
    /// leave the bar no room, the bar over the two times.
    private func upNowBar(_ pass: UpNow.Pass) -> some View {
        let rise = Text(pass.riseTime).fixedSize()
        let set = Text(pass.setTime).fixedSize()
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: Self.upNowItemSpacing) {
                rise
                progressBar(pass.progress)
                    .frame(minWidth: Self.barMinWidth)
                set
            }
            VStack(spacing: Self.upNowStackedSpacing) {
                progressBar(pass.progress)
                HStack(spacing: Self.upNowItemSpacing) {
                    rise
                    Spacer(minLength: 0)
                    set
                }
            }
        }
        .font(Theme.Fonts.caption)
        .foregroundStyle(Theme.Colors.textSecondary)
    }

    /// The track, the travelled part in amber, and the moon as the thumb.
    /// The thumb's centre runs inset by its radius, so at either end it
    /// stays clear of the times.
    private func progressBar(_ progress: Double) -> some View {
        let thumbDiameter = Self.thumbSize + 2 * Self.thumbOutline
        return GeometryReader { proxy in
            let radius = thumbDiameter / 2
            let midY = proxy.size.height / 2
            let thumbX = radius + max(proxy.size.width - thumbDiameter, 0) * progress
            ZStack {
                Capsule()
                    .fill(Theme.Colors.stroke)
                    .frame(width: proxy.size.width, height: Self.barHeight)
                    .position(x: proxy.size.width / 2, y: midY)
                Capsule()
                    .fill(Theme.Colors.accent.opacity(Self.barFillOpacity))
                    .frame(width: thumbX, height: Self.barHeight)
                    .position(x: thumbX / 2, y: midY)
                PhaseGlyph(geometry: table.glyph, glowCSSBlur: 0)
                    .frame(width: Self.thumbSize, height: Self.thumbSize)
                    .padding(Self.thumbOutline)
                    .background(Theme.Colors.surface, in: Circle())
                    .shadow(color: Theme.Colors.accent.opacity(Self.thumbGlowOpacity), radius: Self.thumbGlowRadius)
                    .position(x: thumbX, y: midY)
            }
        }
        .frame(height: thumbDiameter)
        .accessibilityHidden(true)
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

/// The design's sky (COMPASS-1.1.md source, state 1 and 4) from fakes: Irvine
/// at 7:53 AM on Fri, Oct 2, detected, so the compass and its Up now row
/// show. Moon up at 266° on the pass from 10:06 PM to 1:28 PM; or down,
/// rising in 34 minutes.
private struct UpNowPreview: View {

    let viewModel: LocationViewModel

    init(isMoonUp: Bool) {
        viewModel = Self.makeViewModel(isMoonUp: isMoonUp)
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

    private static func makeViewModel(isMoonUp: Bool) -> LocationViewModel {
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
            headingService: FakeHeadingService(),
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
