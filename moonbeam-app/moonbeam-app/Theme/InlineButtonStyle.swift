//
//  InlineButtonStyle.swift
//  moonbeam-app
//

import SwiftUI

/// A text or icon action that sits beside other content rather than filling
/// the width: the sheets' Cancel, Clear, Today and Done (STEP-5.13 §4). It
/// keeps the label's own font and draws it in the tint (or a given color), at
/// least 44 pt square, with the shared pressed look. In a toolbar the system's
/// glass stays around it.
struct InlineButtonStyle: ButtonStyle {

    @Environment(\.isEnabled) private var isEnabled

    var foreground = AnyShapeStyle(.tint)

    private static let disabledOpacity = 0.35

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .frame(minWidth: Theme.Metrics.minimumHitTarget, minHeight: Theme.Metrics.minimumHitTarget)
            .opacity(isEnabled ? 1 : Self.disabledOpacity)
            // Shrink, dim and spring back (DECISIONS.md "Tap animation").
            .pressFeedback(isPressed: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == InlineButtonStyle {

    /// `.buttonStyle(.inline)`: in the tint.
    static var inline: InlineButtonStyle { InlineButtonStyle() }

    /// `.buttonStyle(.inline(.secondary))`: in another style, e.g. Clear's gray.
    static func inline(_ foreground: some ShapeStyle) -> InlineButtonStyle {
        InlineButtonStyle(foreground: AnyShapeStyle(foreground))
    }
}
