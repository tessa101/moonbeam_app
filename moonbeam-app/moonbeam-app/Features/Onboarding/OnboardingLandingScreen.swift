//
//  OnboardingLandingScreen.swift
//  moonbeam-app
//

import SwiftUI

/// Onboarding 1, Landing (STEP-5.14): the searching cat, app name, tagline
/// and Get started.
struct OnboardingLandingScreen: View {

    let onGetStarted: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: - Constants (read from the HTML)

    private static let titleToTagline: CGFloat = 12
    private static let taglineMaxWidth: CGFloat = 280

    /// Load-in order, top to bottom (STEP-5.14 §2).
    private enum LoadInBlock: Int {
        case moon, title, tagline, getStarted
    }

    // MARK: - Body

    var body: some View {
        OnboardingPage(topSpacing: OnboardingLandingLayout.topSpacing, alignment: .center) {
            VStack(spacing: OnboardingLandingLayout.artToTextSpacing) {
                if let artSize = OnboardingLandingLayout.artSize(for: dynamicTypeSize) {
                    LocationIllustration(
                        kind: .searching,
                        animationDelay: ContentLoadIn.duration
                    )
                    .frame(width: artSize.width, height: artSize.height)
                    .contentLoadIn(index: LoadInBlock.moon.rawValue)
                }

                VStack(spacing: Self.titleToTagline) {
                    Text(AppInfo.name)
                        .font(Theme.Fonts.onboardingHero)
                        .accessibilityAddTraits(.isHeader)
                        .contentLoadIn(index: LoadInBlock.title.rawValue)

                    Text(OnboardingCopy.tagline)
                        .font(Theme.Fonts.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(maxWidth: Self.taglineMaxWidth)
                        .contentLoadIn(index: LoadInBlock.tagline.rawValue)
                }
                .multilineTextAlignment(.center)
            }
        } actions: {
            Button(OnboardingCopy.getStarted, action: onGetStarted)
                .buttonStyle(.primary)
                .contentLoadIn(index: LoadInBlock.getStarted.rawValue)
        }
    }
}

#Preview {
    OnboardingLandingScreen(onGetStarted: {})
        .background { ScreenBackground() }
}
