//
//  OnboardingLocationScreen.swift
//  moonbeam-app
//

import SwiftUI

/// Onboarding 2, Location upsell (DESIGN-1.1.md §5): why the app wants
/// location, a note to keep Precise Location on, then Use my location (the
/// only way to the system prompt) or Search for a city instead.
struct OnboardingLocationScreen: View {

    let onUseMyLocation: () -> Void
    let onSearchInstead: () -> Void

    // MARK: - Constants (read from the HTML)

    private static let topSpacing: CGFloat = 96
    private static let moonSize: CGFloat = 64
    private static let spacing: CGFloat = 22
    private static let infoIconSpacing: CGFloat = 12
    private static let infoPaddingVertical: CGFloat = 14
    private static let infoPaddingHorizontal: CGFloat = 16
    private static let infoCornerRadius: CGFloat = 18
    /// The design's location icon is the madlib's pin.
    private static let infoSymbol = MadlibFormatter.placeSymbol

    // MARK: - Body

    var body: some View {
        OnboardingPage(topSpacing: Self.topSpacing) {
            VStack(alignment: .leading, spacing: Self.spacing) {
                OnboardingMoon(size: Self.moonSize)

                Text(OnboardingCopy.upsellTitle)
                    .font(Theme.Fonts.onboardingTitle)
                    .accessibilityAddTraits(.isHeader)

                Text(OnboardingCopy.upsellBody)
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.textBody)

                preciseNote
            }
        } actions: {
            Button(OnboardingCopy.useMyLocation, action: onUseMyLocation)
                .buttonStyle(.primary)
            Button(OnboardingCopy.searchInstead, action: onSearchInstead)
                .buttonStyle(.textLink)
        }
    }

    /// The info box: 1 pt `stroke`, radius 18, the pin in amber.
    private var preciseNote: some View {
        HStack(alignment: .firstTextBaseline, spacing: Self.infoIconSpacing) {
            Image(Self.infoSymbol)
                .foregroundStyle(Theme.Colors.accent)
                .accessibilityHidden(true)
            Text(OnboardingCopy.preciseNote)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .font(Theme.Fonts.infoNote)
        .padding(.vertical, Self.infoPaddingVertical)
        .padding(.horizontal, Self.infoPaddingHorizontal)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay {
            RoundedRectangle(cornerRadius: Self.infoCornerRadius)
                .strokeBorder(Theme.Colors.stroke, lineWidth: Theme.Metrics.hairline)
        }
    }
}

#Preview {
    OnboardingLocationScreen(onUseMyLocation: {}, onSearchInstead: {})
        .background { ScreenBackground() }
}
