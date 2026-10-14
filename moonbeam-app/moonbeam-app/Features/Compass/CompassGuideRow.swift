//
//  CompassGuideRow.swift
//  moonbeam-app
//

import SwiftUI

/// Where the location-off prompt was, after Maybe later (LOCATION-OFF-FLOW.md
/// §3, design 1.9 S2 to S6): the calico, two lines from
/// `LocationOffGuideFormatter`, and a chevron. Waiting (S2) is quiet: a
/// hairline border and the sleeping cat. A moonrise near, rising or up (S3 to
/// S6) warms up: fill, warm border, amber subtitle and chevron, the cat awake.
///
/// The whole row is one button that brings the prompt back; its label is the
/// title and subtitle.
struct CompassGuideRow: View {

    let row: LocationOffGuideFormatter.Row
    /// S3 to S6.
    let isActive: Bool
    let action: () -> Void

    // MARK: - Constants (design 1.9, S2 to S6)

    private static let paddingTop: CGFloat = 12
    private static let paddingTrailing: CGFloat = 16
    private static let paddingBottom: CGFloat = 12
    private static let paddingLeading: CGFloat = 12
    private static let cornerRadius: CGFloat = 20
    private static let itemSpacing: CGFloat = 14
    private static let textSpacing: CGFloat = 2
    /// The prepared crops (design 1.9 avatars), drawn at their own size.
    private static let avatarSize: CGFloat = 52
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

                Text(verbatim: Self.chevron)
                    .font(Theme.Fonts.guideRowChevron)
                    .foregroundStyle(isActive ? Theme.Colors.accent : Theme.Colors.guideRowChevron)
                    .accessibilityHidden(true)
            }
            .padding(EdgeInsets(
                top: Self.paddingTop,
                leading: Self.paddingLeading,
                bottom: Self.paddingBottom,
                trailing: Self.paddingTrailing
            ))
            .frame(minHeight: Theme.Metrics.minimumHitTarget)
            .background {
                if isActive {
                    RoundedRectangle(cornerRadius: Self.cornerRadius).fill(Theme.Colors.guideRowActiveFill)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: Self.cornerRadius)
                    .strokeBorder(
                        isActive ? Theme.Colors.guideRowActiveBorder : Theme.Colors.guideRowBorder,
                        lineWidth: Theme.Metrics.hairline
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: Self.cornerRadius))
        }
        .buttonStyle(.plain)
        // The button is the one element; this replaces its read-out text.
        .accessibilityLabel(row.accessibilityLabel)
        .accessibilityHint(LocationOffGuideFormatter.rowHint)
    }
}

// MARK: - Previews

#Preview("S2 to S6") {
    let formatter = LocationOffGuideFormatter()
    VStack(spacing: 12) {
        ForEach([
            LocationOffGuide.waiting, .moonriseIn(minutes: 135), .moonriseIn(minutes: 40), .rising, .up,
        ], id: \.self) { guide in
            CompassGuideRow(row: formatter.row(for: guide), isActive: guide.isActive, action: {})
        }
    }
    .padding()
    .background { ScreenBackground() }
}
