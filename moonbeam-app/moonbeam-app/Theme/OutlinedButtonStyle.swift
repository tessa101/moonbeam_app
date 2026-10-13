//
//  OutlinedButtonStyle.swift
//  moonbeam-app
//

import SwiftUI

/// LOCATION-SHEET.md §3 secondary: a full-width 48 pt capsule outlined in
/// `accent` at 40%, with `accent` text and no fill, so it reads as the quieter
/// of two actions on a sheet. The Location Off dialog's "Search for a city
/// instead".
struct OutlinedButtonStyle: ButtonStyle {

    @Environment(\.isEnabled) private var isEnabled

    static let height: CGFloat = 48
    private static let borderOpacity = 0.4
    private static let disabledOpacity = 0.35
    /// Keeps the title off the rounded ends when it wraps at AX sizes.
    private static let horizontalPadding: CGFloat = 24
    private static let verticalPadding: CGFloat = 12

    func makeBody(configuration: Configuration) -> some View {
        let capsule = Capsule()

        configuration.label
            .font(Theme.Fonts.secondaryButton)
            .foregroundStyle(Theme.Colors.accent)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Self.horizontalPadding)
            .padding(.vertical, Self.verticalPadding)
            // Grows past 48 pt when the title wraps, so it never truncates.
            .frame(maxWidth: .infinity, minHeight: Self.height)
            .overlay {
                capsule.strokeBorder(
                    Theme.Colors.accent.opacity(Self.borderOpacity),
                    lineWidth: Theme.Metrics.hairline
                )
            }
            .opacity(isEnabled ? 1 : Self.disabledOpacity)
            // Shrink, dim and spring back (DECISIONS.md "Tap animation").
            .pressFeedback(isPressed: configuration.isPressed)
            .contentShape(capsule)
    }
}

extension ButtonStyle where Self == OutlinedButtonStyle {

    /// `.buttonStyle(.outlined)`.
    static var outlined: OutlinedButtonStyle { OutlinedButtonStyle() }
}
