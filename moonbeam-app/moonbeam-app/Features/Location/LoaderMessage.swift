//
//  LoaderMessage.swift
//  moonbeam-app
//

import SwiftUI

/// The block under the stopped loader moon (LOADER.md §10.3): headline and
/// body at the top, the primary button and "Enter a city instead" at the
/// bottom. Copy and actions come from `LocationIssue`.
///
/// Built from the same `MessageText` and `MessageActions` as the failure
/// screen (STEP-5.10a Chunk 2), with the loader handoff's spacing.
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

    /// The flexible gap's least, between the body and the button.
    static let minimumBodyToButton: CGFloat = 24

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            MessageText(copy: issue.copy, textScale: textScale)

            if fillsHeight {
                Spacer(minLength: Self.minimumBodyToButton)
            } else {
                Color.clear.frame(height: Self.minimumBodyToButton)
            }

            // The button keeps its 56 pt (§10.5), so it isn't scaled.
            // At the failure screen's heights (Chunk 2b).
            MessageActions(
                copy: issue.copy,
                buttonToLink: LocationFailureLayout.buttonToLink,
                onPrimary: onPrimary,
                onLink: onSearch
            )
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
