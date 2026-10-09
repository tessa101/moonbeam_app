//
//  MoonCard.swift
//  moonbeam-app
//

import SwiftUI

enum DayStepDirection: Hashable {
    case previous
    case next
}

@Observable
@MainActor
final class DayStepLayoutProbe {
    struct PressedLookEvent {
        let isPressed: Bool
        let instant: ContinuousClock.Instant
    }

    @ObservationIgnored
    private(set) var frames: [DayStepDirection: CGRect] = [:]
    @ObservationIgnored
    private(set) var pressedLookEvents: [DayStepDirection: [PressedLookEvent]] = [:]
    var pressedDirection: DayStepDirection?

    func record(_ frame: CGRect, for direction: DayStepDirection) {
        frames[direction] = frame
    }

    func recordPressedLook(_ isPressed: Bool, for direction: DayStepDirection) {
        guard pressedLookEvents[direction]?.last?.isPressed != isPressed else { return }
        pressedLookEvents[direction, default: []].append(
            PressedLookEvent(isPressed: isPressed, instant: ContinuousClock.now)
        )
    }

    func resetPressedLookEvents(for direction: DayStepDirection) {
        pressedLookEvents[direction] = []
    }
}

/// The moon card (DESIGN-1.1.md §3.2, COMPASS-1.1.md §9.2, §9.14): a header
/// row (phase glyph, the selected day over the phase, ‹ ›), then moonrise and
/// moonset, with Up now between them while the moon is up today. A compass
/// lock outlines the matching cell.
///
/// Layout and announcements only. Day stepping is `LocationViewModel`'s
/// (DATE.md), the card's text is `MoonTableViewModel`'s, Up now and the lock
/// are the compass's.
struct MoonCard: View {

    let viewModel: LocationViewModel
    let table: MoonTableViewModel
    /// Frame recorder used by the §9.19 animation regression. `nil` in the
    /// app, so production rendering has no observation state.
    var dayStepLayoutProbe: DayStepLayoutProbe? = nil
    @State private var dayStepHapticCount = 0

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.hidesCardPhaseGlyph) private var hidesPhaseGlyph
    @Environment(\.risesCardContent) private var risesContent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Only used when `risesContent`: false until the landing starts.
    @State private var isContentIn = false

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
    /// At the default size the phase line shrinks in these steps, down to
    /// 70%, then drops " lit" (COMPASS-1.1.md §9.12): always one line, so
    /// the card's height is the same for every phase on every phone.
    private static let phaseLineScales: [CGFloat] = [1, 0.95, 0.9, 0.85, 0.8, 0.75, 0.7]
    /// The three columns' text, at the default size, shrinks in these steps
    /// before it wraps (COMPASS-1.1.md §9.14).
    fileprivate static let cellTextScales: [CGFloat] = [1, 0.9, 0.8]

    // MARK: - Rise/set constants

    /// Between the Moonrise and Moonset cells (the HTML's grid gap).
    private static let columnGap: CGFloat = 6
    /// "↑ Moonrise" to the time: tight, but clear of Young Serif's
    /// ascenders (COMPASS-1.1.md §9.10; 4 before).
    private static let labelToTimeSpacing: CGFloat = 2
    /// The time to its direction.
    private static let timeToDirectionSpacing: CGFloat = 4
    /// Between a time and its zone abbreviation, side by side or stacked.
    private static let timeZoneSpacing: CGFloat = 4

    // MARK: - Cell constants (COMPASS-1.1.md §3, read from the HTML)

    /// The data cells (`CellStyle`) reach this far into the card's padding,
    /// so their text sits just inside the header's.
    private static let cellOutset: CGFloat = 6

    // MARK: - Up now column constants (COMPASS-1.1.md §9.14)

    /// "Up now" a step under the times (about 20 pt to their 24, the mock).
    private static let upNowTitleSize: CGFloat = 20
    private static let upNowTitleScale = upNowTitleSize / Theme.Fonts.displaySize
    /// One narrow digit gives the time slot's height without its width.
    private static let timeSlotSample = "1"
    /// The phase glyph on the connector, in the label's slot.
    @ScaledMetric(relativeTo: .footnote) private var upNowGlyphSize: CGFloat = 16
    /// The shortest the connector gets on each side before it hides.
    private static let connectorMinLength: CGFloat = 12
    /// Between the connector's ends and the cells beside it.
    private static let connectorInset: CGFloat = 4
    /// The pill fallback reads Moonrise → Up now → Moonset, though the pill
    /// is under both.
    private static let firstSortPriority: Double = 2
    private static let secondSortPriority: Double = 1

    // MARK: - Up now pill constants (COMPASS-1.1.md §9.2)

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
            riseSetArea
        }
        // Content only, before the frame is drawn: the card's surface and
        // outline stay put while the content rises into them.
        .opacity(risesContent && !isContentIn ? 0 : 1)
        .offset(y: risesContent && !isContentIn && !reduceMotion ? ContentLoadIn.rise : 0)
        .onAppear {
            guard risesContent else { return }
            if reduceMotion {
                isContentIn = true
            } else {
                withAnimation(ContentLoadIn.cardLandingAnimation) { isContentIn = true }
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

    /// LOADER.md §10.4: "Aha"'s moon lands here, so the slot reports its
    /// frame, and the glyph waits hidden until it has.
    private var glyph: some View {
        PhaseGlyph(geometry: table.glyph)
            .frame(width: Self.glyphSize, height: Self.glyphSize)
            .opacity(hidesPhaseGlyph ? 0 : 1)
            .anchorPreference(key: CardPhaseSlotKey.self, value: .bounds) { $0 }
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
            stepButton(.previous, title: "Previous day", systemImage: "chevron.left", enabled: viewModel.canGoBack) {
                viewModel.previousDay()
            }
            stepButton(.next, title: "Next day", systemImage: "chevron.right", enabled: viewModel.canGoForward) {
                viewModel.nextDay()
            }
        }
        .sensoryFeedback(
            .impact(flexibility: .soft, intensity: Self.dayStepHapticIntensity),
            trigger: dayStepHapticCount
        )
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

    /// "Last Quarter · 53% lit" on one line. At the default size always one
    /// line, on every phone (COMPASS-1.1.md §9.12): it shrinks to 70%, then
    /// drops " lit". At other sizes it doesn't shrink; the name goes over
    /// "21% lit" instead, so the "·" is never left at a line's end.
    /// VoiceOver keeps "at midnight".
    private var phaseLine: some View {
        let name = Text(table.phaseName)
            .foregroundStyle(Theme.Colors.textPrimary)
        let lit = Text(table.illuminationText)
            .foregroundStyle(Theme.Colors.textSecondary)
        let separator = Text(Self.phaseSeparator)
            .foregroundStyle(Theme.Colors.textSecondary)
        let oneLine = Text("\(name)\(separator)\(lit)")
        return Group {
            // Only the default size shrinks, like the sentence (§3.1a).
            if MadlibScale.shrinks(at: dynamicTypeSize) {
                ViewThatFits(in: .horizontal) {
                    ForEach(Self.phaseLineScales, id: \.self) { scale in
                        oneLine
                            .font(Theme.Fonts.phaseName(scale: scale))
                            .lineLimit(1)
                    }
                    // "Waning Crescent · 42%": the last resort, and what
                    // ViewThatFits falls back to, so never a second line.
                    Text("\(name)\(separator)\(Text(table.illuminationPercentText).foregroundStyle(Theme.Colors.textSecondary))")
                        .font(Theme.Fonts.phaseName(scale: Self.phaseLineScales.last ?? 1))
                        .lineLimit(1)
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    oneLine
                        .lineLimit(1)
                    VStack(alignment: .leading, spacing: Self.headerTextSpacing) {
                        name
                        lit
                    }
                }
                .font(Theme.Fonts.phaseName)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(table.phaseAccessibilityLabel)
    }

    private func stepButton(
        _ direction: DayStepDirection,
        title: String,
        systemImage: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Self.performDayStep(enabled: enabled, hapticCount: &dayStepHapticCount, action: action)
            announceDate()
        } label: {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
        }
        .buttonStyle(
            DayStepButtonStyle(
                direction: direction,
                layoutProbe: dayStepLayoutProbe
            )
        )
        .disabled(!enabled)
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { frame in
            dayStepLayoutProbe?.record(frame, for: direction)
        }
    }

    static let dayStepHapticIntensity = 0.5

    static func performDayStep(
        enabled: Bool,
        hapticCount: inout Int,
        action: () -> Void
    ) {
        guard enabled else { return }
        action()
        hapticCount += 1
    }

    /// DATE.md §5: changing the day with ‹ or › announces the new date. The
    /// adjustable label doesn't need this, since VoiceOver reads its value.
    private func announceDate() {
        AccessibilityNotification.Announcement(viewModel.dateAccessibilityValue).post()
    }

    // MARK: - Rise/set row (COMPASS-1.1.md §9.14)

    /// The live row over its hidden twin for the other state (moon up or
    /// down), so the card is the same height either way and nothing below
    /// it moves when the moon rises or sets.
    private var riseSetArea: some View {
        let layout = RiseSetLayout(upNow: viewModel.compass.upNow)
        return ZStack(alignment: .top) {
            if let twin = layout.twin {
                riseSetRow(twin)
                    .hidden()
                    .accessibilityHidden(true)
            }
            riseSetRow(layout)
        }
        .padding(.horizontal, -Self.cellOutset)
    }

    /// Moon up: three columns, the widest that fits of `threeColumnRungs`
    /// (the connector gives first, then the text shrinks); past that, at the
    /// default size the text wraps at 80%, at other sizes the pill row
    /// fallback. Otherwise rise and set hug their ends, joined by the dim
    /// line, or as built (two halves) when they don't fit.
    @ViewBuilder
    private func riseSetRow(_ layout: RiseSetLayout) -> some View {
        if let bearing = layout.bearing {
            ViewThatFits(in: .horizontal) {
                ForEach(threeColumnRungs, id: \.self) { rung in
                    threeColumns(bearing: bearing, rung: rung)
                }
                if MadlibScale.shrinks(at: dynamicTypeSize) {
                    threeColumns(bearing: bearing, rung: .wrapping)
                } else {
                    fallbackRow(layout, bearing: bearing)
                }
            }
        } else {
            ViewThatFits(in: .horizontal) {
                joinedColumns
                halfColumns()
            }
        }
    }

    /// One-line steps for the three columns. Only the default size shrinks,
    /// like the sentence (§3.1a).
    private var threeColumnRungs: [Rung] {
        let scales = MadlibScale.shrinks(at: dynamicTypeSize) ? Self.cellTextScales : [1]
        return [Rung(showsConnector: true, scale: 1, oneLine: true)]
            + scales.map { Rung(showsConnector: false, scale: $0, oneLine: true) }
    }

    /// ↑ Moonrise · Up now · ↓ Moonset (7a, 7b). The outer cells hug their
    /// content; the connector, or the gap, takes what's left, so Up now sits
    /// centred between them.
    private func threeColumns(bearing: String, rung: Rung) -> some View {
        HStack(alignment: .top, spacing: 0) {
            column(table.rise, isHighlighted: viewModel.highlightedCardCell == .moonrise, rung: rung)
                .layoutPriority(1)
            joint(.travelled, shows: rung.showsConnector)
            upNowColumn(bearing: bearing, rung: rung)
                .layoutPriority(1)
            joint(.remaining, shows: rung.showsConnector)
            column(table.set, isHighlighted: viewModel.highlightedCardCell == .moonset, rung: rung)
                .layoutPriority(1)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Moon down or another date (7c): rise leading, set trailing, one dim
    /// dotted line between them. Set is where it is with the moon up.
    private var joinedColumns: some View {
        HStack(alignment: .top, spacing: 0) {
            column(table.rise, isHighlighted: viewModel.highlightedCardCell == .moonrise)
                .layoutPriority(1)
            joint(.dim, shows: true)
            column(table.set, isHighlighted: viewModel.highlightedCardCell == .moonset)
                .layoutPriority(1)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Two equal cells, as tall as the taller one, so a highlighted cell's
    /// outline matches its neighbour's height (COMPASS-1.1.md §3): the
    /// 5.4.6c row, for when the cells don't fit hugging their ends.
    private func halfColumns(sortsForVoiceOver: Bool = false) -> some View {
        HStack(alignment: .top, spacing: Self.columnGap) {
            column(table.rise, isHighlighted: viewModel.highlightedCardCell == .moonrise, fills: true)
                .accessibilitySortPriority(sortsForVoiceOver ? Self.firstSortPriority : 0)
            column(table.set, isHighlighted: viewModel.highlightedCardCell == .moonset, fills: true)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// When three columns don't fit (AX sizes, §9.14): rise and set as built
    /// with the 5.4.6a pill under them, still read Moonrise → Up now →
    /// Moonset.
    private func fallbackRow(_ layout: RiseSetLayout, bearing: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.cardSpacing) {
            halfColumns(sortsForVoiceOver: true)
            if layout.fallback.showsPillRow {
                upNowPill(bearing: bearing)
                    .accessibilitySortPriority(Self.secondSortPriority)
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// The connector in a gap (`shows`), or just the gap.
    @ViewBuilder
    private func joint(_ style: ConnectorStyle, shows: Bool) -> some View {
        if shows {
            connector(style)
        } else {
            Spacer(minLength: Self.columnGap)
        }
    }

    /// On the labels' centre line: a hidden label-sized line sets the height,
    /// so it stays there at any text size. Decorative.
    private func connector(_ style: ConnectorStyle) -> some View {
        Text(verbatim: " ")
            .font(Theme.Fonts.label)
            .hidden()
            .frame(minWidth: Self.connectorMinLength + 2 * Self.connectorInset, maxWidth: .infinity)
            .overlay {
                HorizontalLine()
                    .stroke(style.color, style: style.stroke)
                    .padding(.horizontal, Self.connectorInset)
            }
            .padding(.top, CellStyle.paddingVertical)
            .accessibilityHidden(true)
    }

    /// Top-aligned in both states, so the labels share a baseline, and as
    /// tall as its neighbours, so a lock outline matches them. Missing
    /// (§9.10, §9.16): "After midnight" smaller, in the time's slot, the
    /// next one ("Sun 12:20 AM") where the direction goes.
    ///
    /// - Parameters:
    ///   - rung: the three columns' text step; `nil` as built.
    ///   - fills: takes half the row (as built) rather than hugging.
    private func column(
        _ column: MoonTableViewModel.Column,
        isHighlighted: Bool,
        rung: Rung? = nil,
        fills: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: Self.labelToTimeSpacing) {
            Text(column.title)
                .font(Theme.Fonts.label)
                .foregroundStyle(isHighlighted ? Theme.Colors.accent : Theme.Colors.textSecondary)
                .lineLimit(rung?.oneLine == true ? 1 : nil)
                

            VStack(alignment: .leading, spacing: Self.timeToDirectionSpacing) {
                switch column.detail {
                case let .time(time, timeZone, direction):
                    if let rung {
                        scaledTimeView(time, timeZone: timeZone, rung: rung)
                    } else {
                        timeView(time, timeZone: timeZone)
                    }
                    Text(direction)
                        .font(Theme.Fonts.detail)
                        .foregroundStyle(Theme.Colors.accent)
                        .lineLimit(rung?.oneLine == true ? 1 : nil)
                        // Its own height: filled to the row's, the cell gave
                        // it one line at AX5 ("57° E…").
                        .fixedSize(horizontal: false, vertical: true)
                        
                case let .missing(text, next):
                    missingText(text, slotScale: rung?.scale ?? 1, oneLine: rung?.oneLine == true)
                    if let next {
                        Text(next)
                            .font(Theme.Fonts.detail)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .lineLimit(rung?.oneLine == true ? 1 : nil)
                            .fixedSize(horizontal: false, vertical: true)
                            
                    }
                }
            }
        }
        // Filled to the row's height, top first: 5.4.6b centred the shorter
        // cell, which set its label ~5 pt low.
        .frame(maxWidth: fills ? .infinity : nil, maxHeight: .infinity, alignment: .topLeading)
        .modifier(CellStyle(isHighlighted: isHighlighted, restingFill: .clear))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(column.accessibilityLabel)
    }

    /// The middle column (7a): the phase glyph in the label's slot, on the
    /// connector; "Up now" a step under the times; the live bearing. Locked
    /// on the Moon, outlined like Moonrise and Moonset (7b).
    private func upNowColumn(bearing: String, rung: Rung) -> some View {
        let isHighlighted = viewModel.highlightedCardCell == .upNow
        let title = Text(UpNowFormatter.upTitle)
            .font(Theme.Fonts.display(scale: Self.upNowTitleScale * rung.scale))
        return VStack(alignment: .center, spacing: Self.labelToTimeSpacing) {
            Text(verbatim: " ")
                .font(Theme.Fonts.label)
                .hidden()
                .overlay {
                    PhaseGlyph(geometry: table.glyph)
                        .frame(width: upNowGlyphSize, height: upNowGlyphSize)
                }
            VStack(alignment: .center, spacing: Self.timeToDirectionSpacing) {
                // As tall as a time and on its baseline, so the bearing
                // lines up with the directions beside it; a narrow sample
                // keeps the width the title's.
                ZStack(alignment: Alignment(horizontal: .center, vertical: .firstTextBaseline)) {
                    Text(verbatim: Self.timeSlotSample)
                        .font(Theme.Fonts.display(scale: rung.scale))
                        .hidden()
                    title
                        .lineLimit(rung.oneLine ? 1 : nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(bearing)
                    .font(Theme.Fonts.detail)
                    .foregroundStyle(Theme.Colors.accent)
                    .lineLimit(1)
            }
        }
        .foregroundStyle(Theme.Colors.accent)
        .frame(maxHeight: .infinity, alignment: .top)
        .modifier(CellStyle(isHighlighted: isHighlighted, restingFill: .clear))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(viewModel.compass.upNow?.accessibilityLabel ?? "")
    }

    /// "After midnight" / "Not today" (§9.16): its own smaller size, out of
    /// the columns' shared scale, so it no longer pulls the times down to
    /// 80%. It sits in a time's slot and on its baseline, so the next time
    /// ("Sun 12:20 AM") lines up with the directions beside it and the card
    /// keeps its height. Wraps where it doesn't fit (AX sizes), never an
    /// ellipsis.
    ///
    /// - Parameters:
    ///   - slotScale: the times' scale beside it, which sets the slot.
    ///   - oneLine: a three-column step that must fit on one line.
    private func missingText(_ text: String, slotScale: CGFloat, oneLine: Bool) -> some View {
        ZStack(alignment: Alignment(horizontal: .leading, vertical: .firstTextBaseline)) {
            Text(verbatim: Self.timeSlotSample)
                .font(Theme.Fonts.display(scale: slotScale))
                .hidden()
            Text(text)
                .font(Theme.Fonts.missingEvent)
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(oneLine ? 1 : nil)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// A time-font line at the rung's scale: one line, or wrapping.
    @ViewBuilder
    private func scaledText(_ text: Text, rung: Rung) -> some View {
        if rung.oneLine {
            text
                .font(Theme.Fonts.display(scale: rung.scale))
                .lineLimit(1)
        } else {
            text
                .font(Theme.Fonts.display(scale: rung.scale))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// A time in the three columns: at the rung's scale, the zone beside it
    /// on one line, or under it when wrapping.
    @ViewBuilder
    private func scaledTimeView(_ time: TimeText, timeZone: String?, rung: Rung) -> some View {
        let timeText = scaledText(Self.text(for: time, scale: rung.scale), rung: rung)
            .foregroundStyle(Theme.Colors.textPrimary)
        if let timeZone {
            let zoneText = Text(timeZone)
                .font(Theme.Fonts.note)
                .foregroundStyle(Theme.Colors.textSecondary)
                .lineLimit(1)
            if rung.oneLine {
                HStack(alignment: .firstTextBaseline, spacing: Self.timeZoneSpacing) {
                    timeText
                    zoneText
                }
            } else {
                VStack(alignment: .leading, spacing: Self.timeZoneSpacing) {
                    timeText
                    zoneText
                }
            }
        } else {
            timeText
        }
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

    // MARK: - Up now pill (COMPASS-1.1.md §9.2; the §9.14 AX fallback)

    /// "● Up now · 266° W", outlined when the compass is locked on the
    /// Moon. Only while the moon is up, and only where the three columns
    /// don't fit; one element for VoiceOver, with the formatter's sentence
    /// (§3).
    private func upNowPill(bearing: String) -> some View {
        let isHighlighted = viewModel.highlightedCardCell == .upNow
        let shape = RoundedRectangle(cornerRadius: Self.pillHeight / 2)
        return HStack(spacing: Self.upNowItemSpacing) {
            Circle()
                .fill(Theme.Colors.moonLit)
                .frame(width: Self.upNowDotSize, height: Self.upNowDotSize)
            Text(UpNow.pillText(bearing: bearing))
                .font(Theme.Fonts.label)
                .foregroundStyle(Theme.Colors.accent)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Self.pillPaddingHorizontal)
        .padding(.vertical, Self.pillPaddingVertical)
        .frame(maxWidth: .infinity, minHeight: Self.pillHeight, alignment: .leading)
        .background(Theme.Colors.surfaceInset, in: shape)
        .overlay {
            shape.strokeBorder(isHighlighted ? Theme.Colors.accent : .clear, lineWidth: Theme.Metrics.hairline)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(viewModel.compass.upNow?.accessibilityLabel ?? "")
    }
}

// MARK: - Three-column steps

private extension MoonCard {

    /// One step of the three columns' fit (§9.14): whether the connector
    /// shows, the time-font scale, and whether text stays on one line.
    struct Rung: Hashable {
        let showsConnector: Bool
        let scale: CGFloat
        let oneLine: Bool

        /// The last resort at the default size: 80%, wrapping, never an
        /// ellipsis.
        static let wrapping = Rung(
            showsConnector: false,
            scale: MoonCard.cellTextScales.last ?? 1,
            oneLine: false
        )
    }

    /// The connector's three looks, matched to the dial's arc.
    enum ConnectorStyle {
        /// Moonrise → glyph: the arc's travelled hairline.
        case travelled
        /// Glyph → Moonset: the arc's remaining dots.
        case remaining
        /// Moon down: the dim dots.
        case dim

        private static let solidWidth: CGFloat = 1.5
        private static let solidOpacity = 0.3
        /// Smaller than the dial's 3 pt dots, at the card's scale.
        private static let dotSize: CGFloat = 2
        private static let dotSpacing: CGFloat = 5
        /// A dash just long enough to draw its round caps: a dot.
        private static let dotDash: CGFloat = 0.01
        private static let remainingOpacity = 0.95
        private static let dimOpacity = 0.4

        var color: Color {
            switch self {
            case .travelled: Theme.Colors.accent.opacity(Self.solidOpacity)
            case .remaining: Theme.Colors.accent.opacity(Self.remainingOpacity)
            case .dim: Theme.Colors.accent.opacity(Self.dimOpacity)
            }
        }

        var stroke: StrokeStyle {
            switch self {
            case .travelled:
                StrokeStyle(lineWidth: Self.solidWidth, lineCap: .round)
            case .remaining, .dim:
                StrokeStyle(lineWidth: Self.dotSize, lineCap: .round, dash: [Self.dotDash, Self.dotSpacing])
            }
        }
    }
}

/// A line across the middle of its frame.
nonisolated private struct HorizontalLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
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
    /// - Parameter scale: the three columns' shrink step (§9.14); 1 as built.
    static func text(for time: TimeText, scale: CGFloat = 1) -> Text {
        time.runs.reduce(Text(verbatim: "")) { text, run in
            let words = run.text.replacingOccurrences(of: narrowNoBreakSpace, with: " ")
            let piece = Text(verbatim: words)
                .font(Theme.Fonts.display(scale: run.isDayPeriod ? scale * Theme.Fonts.dayPeriodScale : scale))
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

    /// Also where the connector's line starts, beside a cell's label.
    static let paddingVertical: CGFloat = 8
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
struct DayStepButtonStyle: ButtonStyle {

    @Environment(\.isEnabled) private var isEnabled
    let direction: DayStepDirection?
    let layoutProbe: DayStepLayoutProbe?

    static let highlightOpacity = 0.06
    static let highlightHeight: CGFloat = 1
    static let shadowOpacity = 0.25
    /// CSS `0 2px 6px`: SwiftUI's radius is about half a CSS blur.
    static let shadowRadius: CGFloat = 3
    static let shadowOffsetY: CGFloat = 2
    static let disabledOpacity = 0.35
    static let pressedScale: CGFloat = 0.88
    static let pressedFillOpacity = 0.10
    static let minimumPressedDuration = Duration.milliseconds(90)
    static let releaseAnimation = Animation.spring(duration: 0.15)

    init(
        direction: DayStepDirection? = nil,
        layoutProbe: DayStepLayoutProbe? = nil
    ) {
        self.direction = direction
        self.layoutProbe = layoutProbe
    }

    func makeBody(configuration: Configuration) -> some View {
        DayStepPressedBody(
            configuration: configuration,
            isEnabled: isEnabled,
            direction: direction,
            layoutProbe: layoutProbe
        )
    }
}

private struct DayStepPressedBody: View {

    let configuration: ButtonStyleConfiguration
    let isEnabled: Bool
    let direction: DayStepDirection?
    let layoutProbe: DayStepLayoutProbe?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsPressedLook = false
    @State private var pressIsDown = false
    @State private var minimumHoldElapsed = false
    @State private var pressCycle = 0

    private var isPressedByTest: Bool {
        guard let direction, let layoutProbe else { return false }
        return layoutProbe.pressedDirection == direction
    }

    private var isPressed: Bool {
        isEnabled && (configuration.isPressed || isPressedByTest)
    }

    var body: some View {
        let circle = Circle()
        let inner = circle.inset(by: Theme.Metrics.hairline)

        configuration.label
            .font(Theme.Fonts.label)
            .foregroundStyle(Theme.Colors.textPrimary)
            .frame(width: Theme.Metrics.stepButtonSize, height: Theme.Metrics.stepButtonSize)
            .background {
                circle
                    .fill(Theme.Colors.surfaceRaised)
                    .overlay {
                        circle.fill(
                            Color.white.opacity(
                                showsPressedLook ? DayStepButtonStyle.pressedFillOpacity : 0
                            )
                        )
                        .animation(
                            DayStepButtonStyle.releaseAnimation,
                            value: showsPressedLook
                        )
                    }
                    .shadow(
                        color: .black.opacity(DayStepButtonStyle.shadowOpacity),
                        radius: DayStepButtonStyle.shadowRadius,
                        y: DayStepButtonStyle.shadowOffsetY
                    )
            }
            .overlay {
                // CSS `inset 0 1px 0`: a 1 pt crescent along the inner top edge.
                inner
                    .subtracting(inner.offset(y: DayStepButtonStyle.highlightHeight))
                    .fill(.white.opacity(DayStepButtonStyle.highlightOpacity))
            }
            .overlay {
                circle.strokeBorder(Theme.Colors.strokeRaised, lineWidth: Theme.Metrics.hairline)
            }
            .opacity(isEnabled ? 1 : DayStepButtonStyle.disabledOpacity)
            .animation(DayStepButtonStyle.releaseAnimation) { content in
                content.scaleEffect(
                    showsPressedLook && !reduceMotion ? DayStepButtonStyle.pressedScale : 1
                )
            }
            .frame(width: Theme.Metrics.minimumHitTarget, height: Theme.Metrics.minimumHitTarget)
            .contentShape(Rectangle())
            .onChange(of: isPressed, initial: true) { _, pressed in
                updatePressedLook(pressed)
            }
            .onChange(of: showsPressedLook, initial: true) { _, pressed in
                guard let direction else { return }
                layoutProbe?.recordPressedLook(pressed, for: direction)
            }
    }

    private func updatePressedLook(_ pressed: Bool) {
        pressIsDown = pressed
        guard pressed else {
            if minimumHoldElapsed {
                showsPressedLook = false
            }
            return
        }

        pressCycle += 1
        let cycle = pressCycle
        minimumHoldElapsed = false
        showsPressedLook = true
        Task { @MainActor in
            try? await Task.sleep(for: DayStepButtonStyle.minimumPressedDuration)
            guard cycle == pressCycle else { return }
            minimumHoldElapsed = true
            if !pressIsDown {
                showsPressedLook = false
            }
        }
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
