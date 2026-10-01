//
//  PrimaryButtonStyle.swift
//  moonbeam-app
//

import SwiftUI

/// DESIGN-1.1.md §2 "Primary button": a full-width 56 pt `accent` capsule
/// with `onAccent` Nunito 700 text and a soft amber glow. Onboarding's Get
/// started, Use my location and Got it (§5).
struct PrimaryButtonStyle: ButtonStyle {

    @Environment(\.isEnabled) private var isEnabled

    private static let glowOpacity = 0.25
    /// CSS `0 0 30px`: SwiftUI's radius is about half a CSS blur.
    private static let glowRadius: CGFloat = 15
    private static let disabledOpacity = 0.35
    /// Keeps the title off the rounded ends when it wraps at AX sizes.
    private static let horizontalPadding: CGFloat = 24
    private static let verticalPadding: CGFloat = 12

    func makeBody(configuration: Configuration) -> some View {
        let capsule = Capsule()

        configuration.label
            .font(Theme.Fonts.button)
            .foregroundStyle(Theme.Colors.onAccent)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Self.horizontalPadding)
            .padding(.vertical, Self.verticalPadding)
            // Grows past 56 pt when the title wraps, so it never truncates.
            .frame(maxWidth: .infinity, minHeight: Theme.Metrics.primaryButtonHeight)
            .background {
                capsule
                    .fill(Theme.Colors.accent)
                    .shadow(color: Theme.Colors.accent.opacity(Self.glowOpacity), radius: Self.glowRadius)
            }
            .opacity(isEnabled ? 1 : Self.disabledOpacity)
            // Shrink, dim and spring back (DECISIONS.md "Tap animation").
            .pressFeedback(isPressed: configuration.isPressed)
            .contentShape(capsule)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {

    /// `.buttonStyle(.primary)`.
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}
