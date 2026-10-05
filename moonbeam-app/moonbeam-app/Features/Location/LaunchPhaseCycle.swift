//
//  LaunchPhaseCycle.swift
//  moonbeam-app
//

import SwiftUI

/// The launch loader (LOADER.md §3, design concept 1a): the onboarding moon,
/// centred on a clean screen, running through its phases over a breathing
/// glow, with "Finding your location…" under it. Shown only while a slow
/// launch fetch runs; `LocationViewModel.launchStage` decides when.
///
/// The screen's backdrop (with its faint top glow) comes from
/// `LocationScreen`, so it doesn't change when the loader comes and goes.
struct LaunchPhaseCycle: View {

    static let message = "Finding your location…"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The month starts at new when the loader appears, as in the mock.
    @State private var startDate = Date.now

    // MARK: - Constants

    /// §3: fixed at every text size; only the text scales.
    private static let moonSize: CGFloat = 140
    /// The mock's gap between the moon and the text.
    private static let moonToText: CGFloat = 28
    /// The mock's disc glow, CSS `0 0 40px`.
    private static let glyphGlowCSSBlur: CGFloat = 40
    /// The breathing glow, CSS `inset: -0.6 × size`: 2.2 moons across.
    private static let glowDiameterPerMoon: CGFloat = 2.2
    /// `accent` 32% at the centre, clear at the edge (CSS `closest-side`).
    private static let glowOpacity = 0.32

    // MARK: - Body

    var body: some View {
        VStack(spacing: Self.moonToText) {
            TimelineView(.animation) { context in
                moon(elapsed: context.date.timeIntervalSince(startDate))
            }
            .frame(width: Self.moonSize, height: Self.moonSize)
            .accessibilityHidden(true)

            Text(Self.message)
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Theme.Metrics.screenMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Moon

    /// Reduce Motion: the glyph holds at full and the glow only fades, with
    /// no swell (§3).
    private func moon(elapsed: TimeInterval) -> some View {
        let level = PhaseCycle.glowLevel(at: elapsed)
        return PhaseGlyph(
            geometry: reduceMotion ? PhaseCycle.stillGeometry : PhaseCycle.geometry(at: elapsed),
            discColor: Theme.Colors.bg,
            glowCSSBlur: Self.glyphGlowCSSBlur
        )
        .background {
            // Behind the glyph and outside layout, so it never moves the text.
            glow
                .opacity(Self.interpolate(PhaseCycle.glowOpacityRange, level))
                .scaleEffect(reduceMotion ? 1 : Self.interpolate(PhaseCycle.glowScaleRange, level))
        }
    }

    private var glow: some View {
        let diameter = Self.moonSize * Self.glowDiameterPerMoon
        return Circle()
            .fill(
                RadialGradient(
                    colors: [Theme.Colors.accent.opacity(Self.glowOpacity), Theme.Colors.accent.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: diameter / 2
                )
            )
            .frame(width: diameter, height: diameter)
    }

    private static func interpolate(_ range: ClosedRange<Double>, _ fraction: Double) -> Double {
        range.lowerBound + (range.upperBound - range.lowerBound) * fraction
    }
}

#Preview {
    LaunchPhaseCycle()
        .background { ScreenBackground() }
}
