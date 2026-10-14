//
//  LocationOffCard.swift
//  moonbeam-app
//

import SwiftUI

/// The location-off prompt and the guide row as one outlined card that
/// resizes between them (LOCATION-OFF-FLOW.md §5.3, §5.4; design 1.9
/// TRANSITION.md option 1d, "One container"). Expanded it holds S1: the
/// ghosted ring, the body, Turn On Location and Maybe later (no title, §8).
/// Collapsed it *is* the row (S2 to S6): one border, not two.
///
/// The card is its content's own height, so Dynamic Type works: full width
/// inside the screen margins, 1 pt border, no fill (the row's warm fill in
/// S3 to S6), corners 24 expanded and 20 collapsed, content clipped.
///
/// **The swap.** When the view model's state flips, the card runs
/// `LocationOffCardMotion`'s timeline from that moment (`LocationOffCardPhase`):
/// one `TimelineView` evaluates every track from the same elapsed time, so
/// nothing drifts. The height animates between the two layers' measured
/// heights, so the content below moves with it on the same curve; the ring
/// scales into the avatar's measured centre while it keeps turning. Taps
/// are off for the whole swap, and VoiceOver reads only the arriving layer.
/// Reduce Motion: a 200 ms crossfade plus the height change.
///
/// Which state to show is the view model's (`showsLocationGuideRow`); the
/// card only draws it.
struct LocationOffCard: View {

    /// The row (S2 to S6) rather than the prompt.
    let isCollapsed: Bool
    let ghost: CompassGhostGeometry
    let row: LocationOffGuideFormatter.Row
    /// S3 to S6: the row's warm look.
    let isRowActive: Bool
    let onTurnOnLocation: () -> Void
    let onMaybeLater: () -> Void
    let onRowTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var phase: LocationOffCardPhase
    @State private var timelineIsRunning = false

    /// The two layers' own heights, measured; the card animates between them.
    @State private var expandedHeight: CGFloat = 0
    @State private var collapsedHeight: CGFloat = 0

    /// Where the ring's centre sits expanded, and where the avatar's sits, in
    /// the card's space: the ring's travel is the difference (§5.3: from the
    /// real geometry, not the mock's numbers).
    @State private var ghostCentre: CGPoint?
    @State private var avatarCentre: CGPoint?

    init(
        isCollapsed: Bool,
        ghost: CompassGhostGeometry,
        row: LocationOffGuideFormatter.Row,
        isRowActive: Bool,
        onTurnOnLocation: @escaping () -> Void,
        onMaybeLater: @escaping () -> Void,
        onRowTap: @escaping () -> Void
    ) {
        self.isCollapsed = isCollapsed
        self.ghost = ghost
        self.row = row
        self.isRowActive = isRowActive
        self.onTurnOnLocation = onTurnOnLocation
        self.onMaybeLater = onMaybeLater
        self.onRowTap = onRowTap
        _phase = State(initialValue: .rest(collapsed: isCollapsed))
    }

    // MARK: - Constants (TRANSITION.md, less the title: §5.3)

    /// The card's own space, where the ring and avatar centres are measured.
    nonisolated static let coordinateSpace = "LocationOffCard"

    static let expandedCornerRadius: CGFloat = 24
    static let collapsedCornerRadius: CGFloat = 20

    /// The ring 20 from the card's top; the body 12 under it, where the
    /// title was; the CTA 14 under the body, Maybe later 4 under that, 12
    /// to the card's bottom. The CTA is 20 in from each side (310 of 350).
    private static let ghostTop: CGFloat = 20
    private static let ghostToBody: CGFloat = 12
    private static let bodyToButton: CGFloat = 14
    private static let buttonToMaybeLater: CGFloat = 4
    private static let maybeLaterToBottom: CGFloat = 12
    private static let promptSideInset: CGFloat = 20
    private static let bodyMaxWidth: CGFloat = 300

    // MARK: - Body

    var body: some View {
        TimelineView(.animation(paused: !timelineIsRunning)) { context in
            card(phase.frame(at: context.date, reduceMotion: reduceMotion))
        }
        .onChange(of: isCollapsed) { _, collapsed in
            withoutLayoutAdjustment {
                phase = .swap(toCollapsed: collapsed, at: .now)
                timelineIsRunning = true
            }
        }
        // Settle once the timeline has run; the frames themselves come from
        // the elapsed time, not from this.
        .task(id: phase) {
            guard phase.isAnimating else { return }
            try? await Task.sleep(for: .seconds(LocationOffCardMotion.totalDuration(reduceMotion: reduceMotion)))
            guard !Task.isCancelled else { return }
            withoutLayoutAdjustment {
                timelineIsRunning = false
            }
        }
    }

    /// Phase bookkeeping must not add a second implicit geometry animation or
    /// ask the enclosing scroll view to preserve the card's departing edge.
    private func withoutLayoutAdjustment(_ changes: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        transaction.scrollContentOffsetAdjustmentBehavior = .disabled
        withTransaction(transaction, changes)
    }

    private func card(_ frame: LocationOffCardMotion.Frame) -> some View {
        let shape = RoundedRectangle(
            cornerRadius: frame.cornerRadius(expanded: Self.expandedCornerRadius, collapsed: Self.collapsedCornerRadius)
        )
        return ZStack(alignment: .top) {
            rowLayer(frame)
            // Over the row, so the ring stays in front as it lands.
            promptLayer(frame)
        }
        .frame(maxWidth: .infinity)
        .frame(height: animatedHeight(frame), alignment: .top)
        .background {
            if isRowActive {
                shape.fill(Theme.Colors.guideRowActiveFill).opacity(frame.card)
            }
        }
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(Theme.Colors.guideRowBorder, lineWidth: Theme.Metrics.hairline)
            if isRowActive {
                shape.strokeBorder(Theme.Colors.guideRowActiveBorder, lineWidth: Theme.Metrics.hairline)
                    .opacity(frame.card)
            }
        }
        .coordinateSpace(.named(Self.coordinateSpace))
    }

    /// During a swap, between the measured heights; at rest, the shown
    /// layer's own (so Dynamic Type changes reflow it).
    private func animatedHeight(_ frame: LocationOffCardMotion.Frame) -> CGFloat? {
        guard collapsedHeight > 0 else { return nil }
        if phase == .collapsed { return collapsedHeight }
        if phase == .expanded {
            return expandedHeight > 0 ? expandedHeight : nil
        }
        guard phase.isAnimating else { return nil }
        // Not measured yet (the prompt arrives with the expand): its first
        // layout lands before the height leaves the row's (the card track
        // starts 120 ms in).
        let expanded = expandedHeight > 0 ? expandedHeight : collapsedHeight
        return frame.height(expanded: expanded, collapsed: collapsedHeight)
    }

    // MARK: - Row (S2 to S6)

    private func rowLayer(_ frame: LocationOffCardMotion.Frame) -> some View {
        CompassGuideRow(
            row: row,
            isActive: isRowActive,
            action: onRowTap,
            avatarOpacity: frame.avatarOpacity,
            avatarScale: frame.avatarScale,
            textOpacity: frame.rowTextOpacity,
            textOffsetX: frame.rowTextOffsetX,
            chevronOpacity: frame.chevronOpacity,
            onAvatarCentreChange: { avatarCentre = $0 }
        )
        // Inside the card's border.
        .padding(Theme.Metrics.hairline)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { collapsedHeight = $0 }
        .allowsHitTesting(!timelineIsRunning && isCollapsed)
        .accessibilityHidden(!phase.rowIsAccessible)
    }

    // MARK: - Prompt (S1)

    /// The ghost, the body (read first by VoiceOver: the art is hidden),
    /// Turn On Location, Maybe later.
    private func promptLayer(_ frame: LocationOffCardMotion.Frame) -> some View {
        VStack(spacing: 0) {
            ghostSlot(frame)
                .padding(.top, Self.ghostTop)
            Text(CompassViewModel.locationPromptBody)
                .font(Theme.Fonts.teaserBody)
                .foregroundStyle(Theme.Colors.teaserBody)
                .themeLineHeight(Theme.Fonts.teaserBodyLineHeightMultiple)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: Self.bodyMaxWidth)
                .padding(.top, Self.ghostToBody)
                .offset(y: frame.promptOffsetY(frame.body))
                .opacity(frame.promptOpacity(frame.body))
            Button(CompassViewModel.turnOnLocationTitle, action: onTurnOnLocation)
                .buttonStyle(.secondary)
                .padding(.top, Self.bodyToButton)
                .offset(y: frame.promptOffsetY(frame.turnOnLocation))
                .opacity(frame.promptOpacity(frame.turnOnLocation))
            Button(CompassViewModel.maybeLaterTitle, action: onMaybeLater)
                .buttonStyle(.textLink(color: Theme.Colors.teaserBody))
                .accessibilityHint(CompassViewModel.maybeLaterHint)
                .padding(.top, Self.buttonToMaybeLater)
                .padding(.bottom, Self.maybeLaterToBottom)
                .offset(y: frame.promptOffsetY(frame.maybeLater))
                .opacity(frame.promptOpacity(frame.maybeLater))
        }
        .padding(.horizontal, Self.promptSideInset)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { expandedHeight = $0 }
        .allowsHitTesting(!timelineIsRunning && !isCollapsed)
        .accessibilityHidden(!phase.promptIsAccessible)
    }

    /// The ring's place, measured untransformed, with the ring drawn over it
    /// scaling and travelling toward the avatar.
    private func ghostSlot(_ frame: LocationOffCardMotion.Frame) -> some View {
        Color.clear
            .frame(width: CompassGhost.artSize, height: CompassGhost.artSize)
            .onGeometryChange(for: CGPoint.self) { proxy in
                let frame = proxy.frame(in: .named(Self.coordinateSpace))
                return CGPoint(x: frame.midX, y: frame.midY)
            } action: { centre in
                ghostCentre = centre
            }
            .overlay {
                CompassGhost(
                    geometry: ghost,
                    previewOpacity: frame.previewOpacity,
                    isActive: timelineIsRunning || !isCollapsed
                )
                    .scaleEffect(frame.compassScale)
                    .offset(compassTravel(frame))
                    .opacity(frame.compassOpacity)
            }
    }

    /// Avatar centre minus ring centre, as far along as the move is.
    private func compassTravel(_ frame: LocationOffCardMotion.Frame) -> CGSize {
        guard let ghostCentre, let avatarCentre else { return .zero }
        return CGSize(
            width: (avatarCentre.x - ghostCentre.x) * frame.compassTravel,
            height: (avatarCentre.y - ghostCentre.y) * frame.compassTravel
        )
    }
}

// MARK: - Previews

/// Tap Maybe later, then the row, to watch the swap.
private struct LocationOffCardPreview: View {

    @State private var isCollapsed = false

    var body: some View {
        VStack(spacing: 0) {
            LocationOffCard(
                isCollapsed: isCollapsed,
                ghost: CompassGhostGeometry(rise: 57, set: 304, moonAzimuth: nil, crossesSouth: true),
                row: LocationOffGuideFormatter().row(for: .moonriseIn(minutes: 40)),
                isRowActive: true,
                onTurnOnLocation: {},
                onMaybeLater: { isCollapsed = true },
                onRowTap: { isCollapsed = false }
            )
            // Stands in for the DEBUG readout: it should glide, not jump.
            Text(verbatim: "Below the card")
                .padding(.top)
            Spacer()
        }
        .padding(Theme.Metrics.screenMargin)
        .background { ScreenBackground() }
    }
}

#Preview("Swap") {
    LocationOffCardPreview()
}
