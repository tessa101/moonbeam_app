//
//  TextLinkButtonStyle.swift
//  moonbeam-app
//

import SwiftUI

/// DESIGN-1.1.md §2 "Text link": amber Nunito 600 with no fill, full width
/// and at least 44 pt tall so it's an easy target. Onboarding's "Search for
/// a city instead" (§5).
struct TextLinkButtonStyle: ButtonStyle {

    private static let pressedOpacity = 0.6
    private static let verticalPadding: CGFloat = 8

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.link)
            .foregroundStyle(Theme.Colors.accent)
            .multilineTextAlignment(.center)
            .padding(.vertical, Self.verticalPadding)
            .frame(maxWidth: .infinity, minHeight: Theme.Metrics.minimumHitTarget)
            .opacity(configuration.isPressed ? Self.pressedOpacity : 1)
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == TextLinkButtonStyle {

    /// `.buttonStyle(.textLink)`.
    static var textLink: TextLinkButtonStyle { TextLinkButtonStyle() }
}
