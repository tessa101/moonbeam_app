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

    /// Load-in order, top to bottom (STEP-5.14 §2 / 5.14.2).
    private enum LoadInBlock: Int {
        case moon, title, body, gotIt, enableLocation
    }

    // MARK: - Body

    var body: some View {
        OnboardingPage(topSpacing: Self.topSpacing) {
            VStack(alignment: .leading, spacing: Self.spacing) {
                OnboardingMoon(size: Self.moonSize)
                    .opacity(Self.moonOpacity)
                    .contentLoadIn(index: LoadInBlock.moon.rawValue)

                Text(OnboardingCopy.declinedTitle)
                    .font(Theme.Fonts.onboardingTitle)
                    .accessibilityAddTraits(.isHeader)
                    .contentLoadIn(index: LoadInBlock.title.rawValue)

                Text(OnboardingCopy.declinedBody)
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.textBody)
                    .contentLoadIn(index: LoadInBlock.body.rawValue)
            }
        } actions: {
            Button(OnboardingCopy.gotIt, action: onGotIt)
                .buttonStyle(.primary)
                .contentLoadIn(index: LoadInBlock.gotIt.rawValue)
            Button(OnboardingCopy.enableLocation, action: onEnableLocation)
                .buttonStyle(.secondary)
                .contentLoadIn(index: LoadInBlock.enableLocation.rawValue)
        }
    }
}

#Preview {
    OnboardingDeclinedScreen(onGotIt: {}, onEnableLocation: {})
        .background { ScreenBackground() }
}
