//
//  LoaderMessage.swift
//  moonbeam-app
//

import SwiftUI

/// The block under the stopped loader moon (LOADER.md §10.3): headline and
/// body at the top, the primary button and "Search for a city instead" at
/// the bottom. Copy and actions come from `LocationIssue`.
///
/// The built button and link styles win over the handoff's sizes (18 pt
/// button, 17 pt link): they match the rest of the app.
struct LoaderMessage: View {

    let issue: LocationIssue

    /// §10.5: 1, or about 0.8 where the message doesn't fit.
    var textScale: CGFloat = 1

    /// Fills the space down to the bottom inset, buttons at the bottom; off
    /// when measuring its natural height or inside a scroll view.
    var fillsHeight = true

    let onPrimary: () -> Void
    let onSearch: () -> Void

    // MARK: - Constants

    /// The handoff: 12 pt headline → body, 22 pt button → link.
    private static let headlineToBody: CGFloat = 12
    private static let buttonToLink: CGFloat = 22
    /// The flexible gap's least, between the body and the button.
    static let minimumBodyToButton: CGFloat = 24

    @ScaledMetric(relativeTo: .title) private var headlineLeading = Theme.Fonts.messageHeadlineSize
        * (Theme.Fonts.messageHeadlineLineHeightMultiple - 1)
    @ScaledMetric(relativeTo: .body) private var bodyLeading = Theme.Fonts.messageBodySize
        * (Theme.Fonts.messageBodyLineHeightMultiple - 1)

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: Self.headlineToBody * textScale) {
                Text(issue.headline)
                    .font(Theme.Fonts.messageHeadline(scale: textScale))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineSpacing(headlineLeading * textScale)
                    .accessibilityAddTraits(.isHeader)
                Text(issue.body)
                    .font(Theme.Fonts.messageBody(scale: textScale))
                    .foregroundStyle(Theme.Colors.textBody)
                    .lineSpacing(bodyLeading * textScale)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            if fillsHeight {
                Spacer(minLength: Self.minimumBodyToButton)
            } else {
                Color.clear.frame(height: Self.minimumBodyToButton)
            }

            // The button keeps its 56 pt (§10.5), so it isn't scaled.
            VStack(spacing: Self.buttonToLink) {
                Button(issue.primaryTitle, action: onPrimary)
                    .buttonStyle(.primary)
                // With no link (restricted), its room is kept, so the button
                // sits where it does on the other messages (Tessa,
                // 2026-10-06).
                Button(LocationIssue.searchLinkTitle, action: onSearch)
                    .buttonStyle(.textLink)
                    .opacity(issue.showsSearchLink ? 1 : 0)
                    .disabled(!issue.showsSearchLink)
                    .accessibilityHidden(!issue.showsSearchLink)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: fillsHeight ? .infinity : nil)
    }
}

#Preview {
    LoaderMessage(issue: .appDenied, onPrimary: {}, onSearch: {})
        .padding(.horizontal, Theme.Metrics.onboardingMargin)
        .padding(.vertical, 40)
        .background { ScreenBackground() }
}
