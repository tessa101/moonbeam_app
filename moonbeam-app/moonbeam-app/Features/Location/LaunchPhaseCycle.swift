//
//  LaunchPhaseCycle.swift
//  moonbeam-app
//

import SwiftUI

/// The launch loader (LOADER.md §3, §10.2; design concept 1a): the onboarding
/// moon, centred on a clean screen, running through its phases over a
/// breathing glow, with "Finding your location…" under it. Shown only while
/// the launch waits; `LocationViewModel.launchStage` decides when, and
/// `LocationLoader` how the moon, glow and label move.
///
/// The screen's backdrop (with its faint top glow) comes from
/// `LocationScreen`, so it doesn't change when the loader comes and goes.
struct LaunchPhaseCycle: View {

    static let message = "Finding your location…"

    let loader: LocationLoader

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The entrance (§10.2): the moon fades in and rises, then the label.
    @State private var moonIsIn = false
    @State private var moonHasRisen = false
    @State private var labelIsIn = false
    @State private var labelHasRisen = false

    // MARK: - Constants

    /// §3: the built size, over the handoff's 132 pt.
    private static let moonSize: CGFloat = 140
    /// The mock's gap between the moon and the text.
    private static let moonToText: CGFloat = 28
    /// The mock's disc glow, CSS `0 0 40px`.
    private static let glyphGlowCSSBlur: CGFloat = 40
    /// The breathing glow, CSS `inset: -0.6 × size`: 2.2 moons across.
    private static let glowDiameterPerMoon: CGFloat = 2.2
    /// `accent` 32% at the centre, clear at the edge (CSS `closest-side`).
    private static let glowOpacity = 0.32

    /// The handoff's "Entrance": both rise 8 pt on `cubic-bezier(.16, 1,
    /// .3, 1)`; the moon fades in over 0.9 s and rises over 1.2 s, the label
    /// over 0.7 s and 0.9 s.
    private static let entranceRise: CGFloat = 8
    private static let riseCurve = (x1: 0.16, y1: 1.0, x2: 0.3, y2: 1.0)
    private static let moonFadeDuration: TimeInterval = 0.9
    private static let moonRiseDuration: TimeInterval = 1.2
    private static let labelFadeDuration: TimeInterval = 0.7
    private static let labelRiseDuration: TimeInterval = 0.9
    /// Reduce Motion (§10.6): every step cross-fades over 0.3 s.
    private static let reduceMotionFade: TimeInterval = 0.3

    // MARK: - Body

    var body: some View {
        VStack(spacing: Self.moonToText) {
            TimelineView(.animation(paused: reduceMotion)) { context in
                moon(at: context.date)
            }
            .frame(width: Self.moonSize, height: Self.moonSize)
            .opacity(moonIsIn ? 1 : 0)
            .offset(y: moonHasRisen || reduceMotion ? 0 : Self.entranceRise)
            .accessibilityHidden(true)

            Text(Self.message)
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(labelIsIn ? 1 : 0)
                .offset(y: labelHasRisen || reduceMotion ? 0 : Self.entranceRise)
        }
        .padding(.horizontal, Theme.Metrics.screenMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: enter)
    }

    // MARK: - Moon

    /// Reduce Motion: the glyph holds at the hold phase and the glow only
    /// fades, with no swell (§10.6).
    private func moon(at date: Date) -> some View {
        let elapsed = loader.moon.elapsed(at: date)
        let look = loader.glow.look(at: date, elapsed: elapsed)
        return PhaseGlyph(
            geometry: reduceMotion ? PhaseCycle.stillGeometry : PhaseCycle.geometry(at: elapsed),
            discColor: Theme.Colors.bg,
            glowCSSBlur: Self.glyphGlowCSSBlur
        )
        .background {
            // Behind the glyph and outside layout, so it never moves the text.
            glow
                .opacity(look.opacity)
                .scaleEffect(reduceMotion ? 1 : look.scale)
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

    // MARK: - Entrance

    private func enter() {
        if reduceMotion {
            withAnimation(.easeOut(duration: Self.reduceMotionFade)) { moonIsIn = true }
            withAnimation(.easeOut(duration: Self.reduceMotionFade).delay(LocationLoader.labelEntranceDelay)) {
                labelIsIn = true
            }
            return
        }
        withAnimation(.easeOut(duration: Self.moonFadeDuration)) { moonIsIn = true }
        withAnimation(Self.rise(duration: Self.moonRiseDuration)) { moonHasRisen = true }
        let delay = LocationLoader.labelEntranceDelay
        withAnimation(.easeOut(duration: Self.labelFadeDuration).delay(delay)) { labelIsIn = true }
        withAnimation(Self.rise(duration: Self.labelRiseDuration).delay(delay)) { labelHasRisen = true }
    }

    private static func rise(duration: TimeInterval) -> Animation {
        .timingCurve(riseCurve.x1, riseCurve.y1, riseCurve.x2, riseCurve.y2, duration: duration)
    }
}

#Preview {
    let loader = LocationLoader()
    LaunchPhaseCycle(loader: loader)
        .background { ScreenBackground() }
        .onAppear { loader.appear() }
}
