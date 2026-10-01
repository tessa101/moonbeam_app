//
//  OnboardingPage.swift
//  moonbeam-app
//

import SwiftUI

/// The layout every onboarding screen shares (DESIGN-1.1.md §5): 28 pt
/// margins, content from the top, buttons pinned to the bottom.
///
/// The page is a scroll view at least the screen's height, with a spacer
/// between content and buttons. When everything fits, the buttons sit at
/// the bottom and nothing scrolls; at AX sizes the page scrolls and the
/// buttons follow the content, so they're always reachable.
struct OnboardingPage<Content: View, Actions: View>: View {

    /// From the top safe area to the content, read from the HTML.
    let topSpacing: CGFloat

    /// `.center` for the landing, `.leading` for the others.
    var alignment: HorizontalAlignment = .leading

    @ViewBuilder var content: Content
    @ViewBuilder var actions: Actions

    // MARK: - Constants

    // Computed: generic types can't hold static stored properties.

    /// The least gap between content and buttons once the page scrolls.
    private static var minimumGap: CGFloat { 32 }
    private static var actionSpacing: CGFloat { 10 }
    /// The HTML's buttons end 42 pt from the screen bottom: the home
    /// indicator's safe area plus this.
    private static var bottomPadding: CGFloat { 8 }

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    // Ideal height for both: under the min-height frame the
                    // stack would otherwise squeeze a title to one
                    // truncated line instead of letting the spacer give.
                    content
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .top))
                        .padding(.top, topSpacing)

                    Spacer(minLength: Self.minimumGap)

                    VStack(spacing: Self.actionSpacing) {
                        actions
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Theme.Metrics.onboardingMargin)
                .padding(.bottom, Self.bottomPadding)
                .frame(minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}
