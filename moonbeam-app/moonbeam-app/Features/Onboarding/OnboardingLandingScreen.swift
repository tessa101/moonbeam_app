//
//  OnboardingLandingScreen.swift
//  moonbeam-app
//

import SwiftUI

/// Onboarding 1, Landing (DESIGN-1.1.md §5): a 150 pt moon with a big soft
/// glow, the app name, the tagline and Get started.
struct OnboardingLandingScreen: View {

    let onGetStarted: () -> Void

    // MARK: - Constants (read from the HTML)

    private static let topSpacing: CGFloat = 150
    private static let moonSize: CGFloat = 150
    private static let moonToText: CGFloat = 30
    private static let titleToTagline: CGFloat = 12
    private static let taglineMaxWidth: CGFloat = 280

    // MARK: - Body

    var body: some View {
        OnboardingPage(topSpacing: Self.topSpacing, alignment: .center) {
            VStack(spacing: Self.moonToText) {
                OnboardingMoon(size: Self.moonSize, hasHalo: true)

                VStack(spacing: Self.titleToTagline) {
                    Text(AppInfo.name)
                        .font(Theme.Fonts.onboardingHero)
                        .accessibilityAddTraits(.isHeader)

                    Text(OnboardingCopy.tagline)
                        .font(Theme.Fonts.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(maxWidth: Self.taglineMaxWidth)
                }
                .multilineTextAlignment(.center)
            }
        } actions: {
            Button(OnboardingCopy.getStarted, action: onGetStarted)
                .buttonStyle(.primary)
        }
    }
}

#Preview {
    OnboardingLandingScreen(onGetStarted: {})
        .background { ScreenBackground() }
}
