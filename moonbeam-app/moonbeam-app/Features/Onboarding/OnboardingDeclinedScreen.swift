//
//  OnboardingDeclinedScreen.swift
//  moonbeam-app
//

import SwiftUI

/// Onboarding 4, after Don't Allow (DESIGN-1.1.md §5): "That's okay", with
/// Got it (the main screen's empty state) or Enable location (Settings).
struct OnboardingDeclinedScreen: View {

    let onGotIt: () -> Void
    let onEnableLocation: () -> Void

    // MARK: - Constants (read from the HTML)

    private static let topSpacing: CGFloat = 110
    private static let moonSize: CGFloat = 64
    /// The moon is dimmed: location is off.
    private static let moonOpacity = 0.6
    private static let spacing: CGFloat = 22

    // MARK: - Body

    var body: some View {
        OnboardingPage(topSpacing: Self.topSpacing) {
            VStack(alignment: .leading, spacing: Self.spacing) {
                OnboardingMoon(size: Self.moonSize)
                    .opacity(Self.moonOpacity)

                Text(OnboardingCopy.declinedTitle)
                    .font(Theme.Fonts.onboardingTitle)
                    .accessibilityAddTraits(.isHeader)

                Text(OnboardingCopy.declinedBody)
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.textBody)
            }
        } actions: {
            Button(OnboardingCopy.gotIt, action: onGotIt)
                .buttonStyle(.primary)
            Button(OnboardingCopy.enableLocation, action: onEnableLocation)
                .buttonStyle(.secondary)
        }
    }
}

#Preview {
    OnboardingDeclinedScreen(onGotIt: {}, onEnableLocation: {})
        .background { ScreenBackground() }
}
