//
//  TextLinkButtonStyle.swift
//  moonbeam-app
//

import SwiftUI

/// DESIGN-1.1.md §2 "Text link": amber Nunito 600 with no fill, full width
/// and at least 44 pt tall so it's an easy target. Onboarding's "Search for
/// a city instead" (§5). The location-off prompt's Maybe later is the same
/// link in `teaserBody` (LOCATION-OFF-FLOW.md §2).
struct TextLinkButtonStyle: ButtonStyle {

    var color = Theme.Colors.accent

    private static let verticalPadding: CGFloat = 8

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.link)
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
            .padding(.vertical, Self.verticalPadding)
            .frame(maxWidth: .infinity, minHeight: Theme.Metrics.minimumHitTarget)
            // Shrink, dim and spring back (DECISIONS.md "Tap animation").
            .pressFeedback(isPressed: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == TextLinkButtonStyle {

    /// `.buttonStyle(.textLink)`.
    static var textLink: TextLinkButtonStyle { TextLinkButtonStyle() }

    /// `.buttonStyle(.textLink(color:))`: the same link in another color.
    static func textLink(color: Color) -> TextLinkButtonStyle { TextLinkButtonStyle(color: color) }
}
