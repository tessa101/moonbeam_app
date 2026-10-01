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

    // MARK: - Card

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.cardSpacing) {
            header
            phaseRow
            hairline
            riseSetRow
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
    private static let pressedOpacity = 0.6
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
            .opacity(isEnabled ? (configuration.isPressed ? Self.pressedOpacity : 1) : Self.disabledOpacity)
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
