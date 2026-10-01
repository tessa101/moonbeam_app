//
//  PhaseGlyph.swift
//  moonbeam-app
//

import SwiftUI

/// The rendered moon beside the phase name (DESIGN-1.1.md §3.2): the lit
/// part in `moonLit` over a disc the card's own colour, with a soft amber
/// glow. Decorative; the phase row's label says the same in words.
struct PhaseGlyph: View {

    let geometry: PhaseGlyphGeometry

    /// §3.2: glow `accent` 30%, blur 18 in the design's CSS. SwiftUI's
    /// shadow radius is about half a CSS blur.
    private static let glowOpacity = 0.3
    private static let glowCSSBlur: CGFloat = 18

    var body: some View {
        Circle()
            .fill(Theme.Colors.surface)
            .shadow(color: Theme.Colors.accent.opacity(Self.glowOpacity), radius: Self.glowCSSBlur / 2)
            .overlay {
                LitShape(geometry: geometry)
                    .fill(Theme.Colors.moonLit)
            }
            .aspectRatio(1, contentMode: .fit)
            .accessibilityHidden(true)
    }
}

// MARK: - Lit shape

/// `PhaseGlyphGeometry`'s outline scaled into the glyph's frame.
/// `nonisolated`: `Shape` requires it, and the path is pure geometry.
nonisolated private struct LitShape: Shape {

    let geometry: PhaseGlyphGeometry

    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let points = geometry.litOutline().map {
            CGPoint(x: center.x + $0.x * radius, y: center.y + $0.y * radius)
        }
        var path = Path()
        path.addLines(points)
        path.closeSubpath()
        return path
    }
}

#Preview("Phases") {
    HStack(spacing: 16) {
        ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { lit in
            VStack(spacing: 16) {
                PhaseGlyph(geometry: PhaseGlyphGeometry(illumination: lit, phaseAngle: 90))
                PhaseGlyph(geometry: PhaseGlyphGeometry(illumination: lit, phaseAngle: 270))
            }
            .frame(width: 44)
        }
    }
    .padding()
    .background(Theme.Colors.surface)
}
