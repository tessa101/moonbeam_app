//
//  CompassGuideRow.swift
//  moonbeam-app
//

import SwiftUI

/// The guide row's content after Maybe later (LOCATION-OFF-FLOW.md §3, design
/// 1.9 S2 to S6): the calico, two lines from `LocationOffGuideFormatter`, and
/// a chevron. Waiting (S2) is quiet: the sleeping cat and a gray chevron. A
/// moonrise near, rising or up (S3 to S6) warms up: the cat awake, the
/// subtitle and chevron amber.
///
/// Content only: the outlined card around it (border, fill, corners) is
/// `LocationOffCard`'s, since the row and the prompt are one card (§5.3).
/// The whole row is one button that brings the prompt back; its label is the
/// title and subtitle.
struct CompassGuideRow: View {

    let row: LocationOffGuideFormatter.Row
    /// S3 to S6.
    let isActive: Bool
    let action: () -> Void

    /// The card's swap (§5.3) draws each piece at its own point in the
    /// timeline; at rest, all fully in.
    var avatarOpacity = 1.0
    var avatarScale: CGFloat = 1
    var textOpacity = 1.0
    var textOffsetX: CGFloat = 0
    var chevronOpacity = 1.0

    /// The avatar's centre in `LocationOffCard.coordinateSpace`, whenever it
    /// moves: where the ring lands as it collapses.
    var onAvatarCentreChange: (CGPoint) -> Void = { _ in }

    // MARK: - Constants (design 1.9, S2 to S6)

    /// Inside the card's 1 pt border, so the avatar sits at (13, 13) and the
    /// row is 78 pt tall (TRANSITION.md).
    private static let paddingTop: CGFloat = 12
    private static let paddingTrailing: CGFloat = 16
    private static let paddingBottom: CGFloat = 12
    private static let paddingLeading: CGFloat = 12
    private static let itemSpacing: CGFloat = 14
    private static let textSpacing: CGFloat = 2
    /// The prepared crops (design 1.9 avatars), drawn at their own size.
    static let avatarSize: CGFloat = 52
    private static let sleepingAvatar = "avatar_sleeping"
    private static let searchingAvatar = "avatar_searching"
    private static let chevron = "›"

    // MARK: - Body

    var body: some View {
        Button(action: action) {
            HStack(spacing: Self.itemSpacing) {
                // Decorative, so it never reads out its asset name.
                Image(decorative: isActive ? Self.searchingAvatar : Self.sleepingAvatar)
                    .resizable()
                    .frame(width: Self.avatarSize, height: Self.avatarSize)
                    .clipShape(Circle())
                    .onGeometryChange(for: CGPoint.self) { proxy in
                        let frame = proxy.frame(in: .named(LocationOffCard.coordinateSpace))
                        return CGPoint(x: frame.midX, y: frame.midY)
                    } action: { centre in
                        onAvatarCentreChange(centre)
                    }
                    .scaleEffect(avatarScale)
                    .opacity(avatarOpacity)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Self.textSpacing) {
                    Text(row.title)
                        .font(Theme.Fonts.guideRowTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(row.subtitle)
                        .font(isActive ? Theme.Fonts.guideRowSubtitleActive : Theme.Fonts.guideRowSubtitle)
                        .foregroundStyle(isActive ? Theme.Colors.accent : Theme.Colors.teaserBody)
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(x: textOffsetX)
                .opacity(textOpacity)

                Text(verbatim: Self.chevron)
                    .font(Theme.Fonts.guideRowChevron)
                    .foregroundStyle(isActive ? Theme.Colors.accent : Theme.Colors.guideRowChevron)
                    .opacity(chevronOpacity)
                    .accessibilityHidden(true)
            }
            .padding(EdgeInsets(
                top: Self.paddingTop,
                leading: Self.paddingLeading,
                bottom: Self.paddingBottom,
                trailing: Self.paddingTrailing
            ))
            .frame(maxWidth: .infinity, minHeight: Theme.Metrics.minimumHitTarget)
            .contentShape(Rectangle())
        }
        // The shared held press (STEP-5.13 §4). The press scale also moves the
        // avatar centre reported above for up to 100 ms after a tap.
        .buttonStyle(.row)
        // The button is the one element; this replaces its read-out text.
        .accessibilityLabel(row.accessibilityLabel)
        .accessibilityHint(LocationOffGuideFormatter.rowHint)
    }
}
