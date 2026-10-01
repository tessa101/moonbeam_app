//
//  SecondaryButtonStyle.swift
//  moonbeam-app
//

import SwiftUI

/// DESIGN-1.1.md §2 "Secondary button": a full-width 52 pt capsule in
/// `surfaceRaised` with a `strokeRaised` border, the same faint top highlight
/// and soft shadow as the card's ‹ ›, and `textPrimary` text. Used by the
/// no-place Use my location (§3.1); 5.4's notes and onboarding reuse it.
struct SecondaryButtonStyle: ButtonStyle {

    @Environment(\.isEnabled) private var isEnabled

    private static let highlightOpacity = 0.06
    private static let highlightHeight: CGFloat = 1
    private static let shadowOpacity = 0.25
    /// CSS `0 2px 6px`: SwiftUI's radius is about half a CSS blur.
    private static let shadowRadius: CGFloat = 3
    private static let shadowOffsetY: CGFloat = 2
    private static let disabledOpacity = 0.35
    /// Keeps the title off the rounded ends when it wraps at AX sizes.
    private static let horizontalPadding: CGFloat = 24
    private static let verticalPadding: CGFloat = 12

    func makeBody(configuration: Configuration) -> some View {
        let capsule = Capsule()
        let inner = capsule.inset(by: Theme.Metrics.hairline)

        configuration.label
            .font(Theme.Fonts.secondaryButton)
            .foregroundStyle(Theme.Colors.textPrimary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Self.horizontalPadding)
            .padding(.vertical, Self.verticalPadding)
            // Grows past 52 pt when the title wraps, so it never truncates.
            .frame(maxWidth: .infinity, minHeight: Theme.Metrics.secondaryButtonHeight)
            .background {
                capsule
                    .fill(Theme.Colors.surfaceRaised)
                    .shadow(
                        color: .black.opacity(Self.shadowOpacity),
                        radius: Self.shadowRadius,
                        y: Self.shadowOffsetY
                    )
            }
            .overlay {
                // CSS `inset 0 1px 0`: a 1 pt crescent along the inner top edge.
                inner
                    .subtracting(inner.offset(y: Self.highlightHeight))
                    .fill(.white.opacity(Self.highlightOpacity))
            }
            .overlay {
                capsule.strokeBorder(Theme.Colors.strokeRaised, lineWidth: Theme.Metrics.hairline)
            }
            .opacity(isEnabled ? 1 : Self.disabledOpacity)
            // Shrink, dim and spring back (DECISIONS.md "Tap animation").
            .pressFeedback(isPressed: configuration.isPressed)
            .contentShape(capsule)
    }
}

extension ButtonStyle where Self == SecondaryButtonStyle {

    /// `.buttonStyle(.secondary)`.
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}
