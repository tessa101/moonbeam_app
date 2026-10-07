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

    /// §11.1.3: the prototype's widths, centred inside the 28 pt sides.
    /// Not at accessibility sizes, where the copy needs every point.
    static let headlineMaxWidth: CGFloat = 300
    static let bodyMaxWidth: CGFloat = 290

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: Self.headlineToBody * textScale) {
                BrokenText(text: issue.headline, lines: issue.headlineLines)
                    .font(Theme.Fonts.messageHeadline(scale: textScale))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .themeLineHeight(Theme.Fonts.messageHeadlineLineHeightMultiple)
                    .frame(maxWidth: maxWidth(Self.headlineMaxWidth))
                    .accessibilityAddTraits(.isHeader)
                BrokenText(text: issue.body, lines: issue.bodyLines)
                    .font(Theme.Fonts.messageBody(scale: textScale))
                    .foregroundStyle(Theme.Colors.textBody)
                    .themeLineHeight(Theme.Fonts.messageBodyLineHeightMultiple)
                    .frame(maxWidth: maxWidth(Self.bodyMaxWidth))
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
                    // §10.5 keeps this control at the designed 56 pt even
                    // when the surrounding message uses an AX text size.
                    // The full title remains available to VoiceOver.
                    .dynamicTypeSize(.large)
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

    private func maxWidth(_ width: CGFloat) -> CGFloat {
        dynamicTypeSize.isAccessibilitySize ? .infinity : width
    }
}

// MARK: - Set line breaks

/// The copy on its set lines (§11.1.3) when every line fits the width,
/// otherwise wrapped naturally (accessibility sizes, small screens, a line
/// too long for the width). Never truncated. VoiceOver reads the copy
/// without the breaks.
private struct BrokenText: View {

    let text: String
    let lines: [String]?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            if let lines {
                Text(lines.joined(separator: "\n"))
                    .fixedSize()
            }
            Text(text)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

#Preview {
    LoaderMessage(issue: .appDenied, onPrimary: {}, onSearch: {})
        .padding(.horizontal, Theme.Metrics.onboardingMargin)
        .padding(.vertical, 40)
        .background { ScreenBackground() }
}
