//
//  CompassGuideRow.swift
//  moonbeam-app
//

import SwiftUI

/// Where the location-off prompt was, after Maybe later (LOCATION-OFF-FLOW.md
/// §3, design 1.9 S2): one tappable row that brings the prompt back. For
/// now, the waiting state only, with no avatar or countdown; 5.12b.2 adds
/// those.
///
/// The whole row is one button: its label is the title and subtitle.
struct CompassGuideRow: View {

    let title: String
    let subtitle: String
    let hint: String
    let action: () -> Void

    // MARK: - Constants (design 1.9, S2)

    private static let paddingTop: CGFloat = 12
    private static let paddingTrailing: CGFloat = 16
    private static let paddingBottom: CGFloat = 12
    private static let paddingLeading: CGFloat = 12
    private static let cornerRadius: CGFloat = 20
    private static let itemSpacing: CGFloat = 14
    private static let textSpacing: CGFloat = 2
    private static let chevron = "›"

    // MARK: - Body

    var body: some View {
        Button(action: action) {
            HStack(spacing: Self.itemSpacing) {
                VStack(alignment: .leading, spacing: Self.textSpacing) {
                    Text(title)
                        .font(Theme.Fonts.guideRowTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(subtitle)
                        .font(Theme.Fonts.guideRowSubtitle)
                        .foregroundStyle(Theme.Colors.teaserBody)
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(verbatim: Self.chevron)
                    .font(Theme.Fonts.guideRowChevron)
                    .foregroundStyle(Theme.Colors.guideRowChevron)
                    .accessibilityHidden(true)
            }
            .padding(EdgeInsets(
                top: Self.paddingTop,
                leading: Self.paddingLeading,
                bottom: Self.paddingBottom,
                trailing: Self.paddingTrailing
            ))
            .frame(minHeight: Theme.Metrics.minimumHitTarget)
            .overlay {
                RoundedRectangle(cornerRadius: Self.cornerRadius)
                    .strokeBorder(Theme.Colors.guideRowBorder, lineWidth: Theme.Metrics.hairline)
            }
            .contentShape(RoundedRectangle(cornerRadius: Self.cornerRadius))
        }
        .buttonStyle(.plain)
        // The button is the one element; this replaces its read-out text.
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityHint(hint)
    }
}

// MARK: - Previews

#Preview("Waiting") {
    CompassGuideRow(
        title: CompassViewModel.guideRowTitle,
        subtitle: CompassViewModel.guideRowSubtitle,
        hint: CompassViewModel.guideRowHint,
        action: {}
    )
    .padding()
    .background { ScreenBackground() }
}
