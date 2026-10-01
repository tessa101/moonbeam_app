//
//  ScreenBackground.swift
//  moonbeam-app
//

import SwiftUI

/// The main screen's backdrop (DESIGN-1.1.md §2): solid `bg` with a faint
/// amber glow centred at the top, as if the moon's light spills in.
///
/// It fills the whole screen, safe areas included, so it sits behind the
/// status bar and home indicator too.
struct ScreenBackground: View {

    /// The glow is an ellipse wider than the phone, so its edges fall off
    /// screen and only the soft centre shows.
    private static let glowSize = CGSize(width: 520, height: 420)
    /// Pushes the glow's centre up towards the top edge of the screen.
    private static let glowTopOffset: CGFloat = -120
    private static let glowOpacity = 0.08

    var body: some View {
        Theme.Colors.bg
            .overlay(alignment: .top) {
                // `EllipticalGradient` reaches the frame's edges at 0.5, the
                // CSS `closest-side` the design uses.
                EllipticalGradient(
                    colors: [
                        Theme.Colors.accent.opacity(Self.glowOpacity),
                        Theme.Colors.accent.opacity(0)
                    ]
                )
                .frame(width: Self.glowSize.width, height: Self.glowSize.height)
                .offset(y: Self.glowTopOffset)
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

#Preview {
    ScreenBackground()
}
