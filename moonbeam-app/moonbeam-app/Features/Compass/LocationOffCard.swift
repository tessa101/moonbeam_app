//
//  LocationOffCard.swift
//  moonbeam-app
//

import SwiftUI

/// The location-off prompt and the guide row as one outlined card
/// (LOCATION-OFF-FLOW.md §5.3, design 1.9 TRANSITION.md option 1d, "One
/// container"). Expanded it holds S1: the ghosted ring, the body, Turn On
/// Location and Maybe later (no title, §8). Collapsed it *is* the row (S2 to
/// S6): one border, not two.
///
/// The card is its content's own height, so Dynamic Type works; full width
/// inside the screen margins, 1 pt border, no fill (the row's warm fill in
/// S3 to S6), corners 24 expanded and 20 collapsed, content clipped.
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

    // MARK: - Constants (TRANSITION.md, less the title: §5.3)

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
        let radius = isCollapsed ? Self.collapsedCornerRadius : Self.expandedCornerRadius
        let shape = RoundedRectangle(cornerRadius: radius)
        Group {
            if isCollapsed {
                CompassGuideRow(row: row, isActive: isRowActive, action: onRowTap)
                    // Inside the card's border.
                    .padding(Theme.Metrics.hairline)
            } else {
                prompt
            }
        }
        .frame(maxWidth: .infinity)
        .background {
            if isCollapsed, isRowActive {
                shape.fill(Theme.Colors.guideRowActiveFill)
            }
        }
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(
                isCollapsed && isRowActive ? Theme.Colors.guideRowActiveBorder : Theme.Colors.guideRowBorder,
                lineWidth: Theme.Metrics.hairline
            )
        }
    }

    /// S1: the ghost, the body (read first by VoiceOver: the art is hidden),
    /// Turn On Location, Maybe later.
    private var prompt: some View {
        VStack(spacing: 0) {
            CompassGhost(geometry: ghost)
                .padding(.top, Self.ghostTop)
            Text(CompassViewModel.locationPromptBody)
                .font(Theme.Fonts.teaserBody)
                .foregroundStyle(Theme.Colors.teaserBody)
                .themeLineHeight(Theme.Fonts.teaserBodyLineHeightMultiple)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: Self.bodyMaxWidth)
                .padding(.top, Self.ghostToBody)
            Button(CompassViewModel.turnOnLocationTitle, action: onTurnOnLocation)
                .buttonStyle(.secondary)
                .padding(.top, Self.bodyToButton)
            Button(CompassViewModel.maybeLaterTitle, action: onMaybeLater)
                .buttonStyle(.textLink(color: Theme.Colors.teaserBody))
                .accessibilityHint(CompassViewModel.maybeLaterHint)
                .padding(.top, Self.buttonToMaybeLater)
                .padding(.bottom, Self.maybeLaterToBottom)
        }
        .padding(.horizontal, Self.promptSideInset)
    }
}

// MARK: - Previews

#Preview("Expanded") {
    LocationOffCard(
        isCollapsed: false,
        ghost: CompassGhostGeometry(rise: 57, set: 304, moonAzimuth: nil, crossesSouth: true),
        row: LocationOffGuideFormatter().row(for: .waiting),
        isRowActive: false,
        onTurnOnLocation: {},
        onMaybeLater: {},
        onRowTap: {}
    )
    .padding(Theme.Metrics.screenMargin)
    .background { ScreenBackground() }
}

#Preview("Collapsed, S3 to S6") {
    LocationOffCard(
        isCollapsed: true,
        ghost: .empty,
        row: LocationOffGuideFormatter().row(for: .moonriseIn(minutes: 40)),
        isRowActive: true,
        onTurnOnLocation: {},
        onMaybeLater: {},
        onRowTap: {}
    )
    .padding(Theme.Metrics.screenMargin)
    .background { ScreenBackground() }
}
