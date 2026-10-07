//
//  OnboardingMoon.swift
//  moonbeam-app
//

import SwiftUI

/// The moon at the top of each onboarding screen (DESIGN-1.1.md §5): the
/// card's `PhaseGlyph` with the loader's earthshine dark side (LOADER.md
/// §11.6), so it hands over to the loader with no change, its glow scaled to
/// its size, plus the landing's big soft halo. Decorative.
struct OnboardingMoon: View {

    let size: CGFloat

    /// The landing's extra halo.
    var hasHalo = false

    // MARK: - Constants

    /// A fixed waxing gibbous, about 83% lit as the HTML's two-circle moon,
    /// lit on the right with the dark sliver on the left: the loader's hold
    /// phase (LOADER.md §10.2), mirrored from the HTML's waning one (Tessa,
    /// 2026-10-06).
    static let geometry = PhaseGlyphGeometry(illumination: 0.83, phaseAngle: 120)

    /// The HTML's glyph glow grows with the glyph (CSS blur 27 at 64 pt, 63
    /// at 150 pt).
    private static let glowBlurPerPoint: CGFloat = 0.42

    /// Landing halo, CSS `0 0 120px 30px` `accent` 18%. SwiftUI's blur
    /// radius is about half a CSS blur.
    private static let haloOpacity = 0.18
    private static let haloSpread: CGFloat = 30
    private static let haloCSSBlur: CGFloat = 120

    // MARK: - Body

    var body: some View {
        PhaseGlyph(
            geometry: Self.geometry,
            discColor: Theme.Colors.moonEarthshine,
            glowCSSBlur: size * Self.glowBlurPerPoint
        )
        .frame(width: size, height: size)
        .background {
            if hasHalo {
                Circle()
                    .fill(Theme.Colors.accent.opacity(Self.haloOpacity))
                    .padding(-Self.haloSpread)
                    .blur(radius: Self.haloCSSBlur / 2)
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 80) {
        OnboardingMoon(size: 150, hasHalo: true)
        OnboardingMoon(size: 64)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.Colors.bg)
}
