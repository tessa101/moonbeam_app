//
//  CompassGhost.swift
//  moonbeam-app
//

import SwiftUI

/// The location-off prompt's art (LOCATION-OFF-FLOW.md §2, design 1.9
/// "S1: Prompt"): the live `CompassDial` itself, fed the day's real rise and
/// set (and the moon, if it's up), ghosted to 42% and blurred, its ring
/// turning slowly under a fixed needle with a PREVIEW pill over it. A copy
/// of the real compass rather than a new drawing, so it shows what location
/// unlocks.
///
/// At its 196 pt design face the dial's frame is 260 pt wide, the handoff's
/// 260-unit space, so it's laid out there and scaled to 210 pt.
///
/// Reduce Motion, the app in the background and the art scrolled out of view
/// all show the still 0° frame rather than a paused timeline, by
/// `LocationIllustration.shouldAnimate`. Decorative: hidden from VoiceOver.
struct CompassGhost: View {

    let targets: [CompassTarget]
    let arc: CompassArc?
    let moonGlyph: PhaseGlyphGeometry?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    /// On screen: in the hierarchy, and (inside a scroll view) in view.
    @State private var isInHierarchy = false
    @State private var isScrolledIntoView = true

    // MARK: - Constants (design 1.9)

    static let artSize: CGFloat = 210
    /// The handoff's drawing space, and the dial's frame width at its
    /// design face.
    private static let designSpace: CGFloat = 260
    private static let layerOpacity = 0.42
    private static let layerBlur: CGFloat = 1.2

    /// PREVIEW: padding 7 × 11, 1 pt border, fully rounded.
    private static let pillPaddingVertical: CGFloat = 7
    private static let pillPaddingHorizontal: CGFloat = 11
    static let pillText = "PREVIEW"

    /// A sliver counts as visible, like the compass's own sensors.
    private static let visibilityThreshold = 0.1

    // MARK: - Body

    var body: some View {
        ZStack {
            Group {
                if LocationIllustration.shouldAnimate(
                    reduceMotion: reduceMotion,
                    scenePhase: scenePhase,
                    isVisible: isInHierarchy && isScrolledIntoView
                ) {
                    CompassGhostTimeline(dial: dial(ringDegrees:))
                } else {
                    dial(ringDegrees: CompassGhostMotion.stillDegrees)
                }
            }
            .compositingGroup()
            .opacity(Self.layerOpacity)
            .blur(radius: Self.layerBlur)

            pill
        }
        .frame(width: Self.artSize, height: Self.artSize)
        .accessibilityHidden(true)
        .onScrollVisibilityChange(threshold: Self.visibilityThreshold) { isScrolledIntoView = $0 }
        .onAppear { isInHierarchy = true }
        .onDisappear { isInHierarchy = false }
    }

    /// The live dial with the ring turned `ringDegrees` clockwise. Its
    /// needle stays at 12 o'clock: the handoff's static north tick.
    private func dial(ringDegrees: Double) -> some View {
        CompassDial(
            faceDiameter: CompassDial.designDiameter,
            heading: CompassGhostMotion.heading(forRingDegrees: ringDegrees),
            targets: targets,
            lockedKind: nil,
            moonGlyph: moonGlyph,
            arc: arc,
            showsTargetLabels: false
        )
        .frame(width: Self.designSpace, height: Self.designSpace)
        .scaleEffect(Self.artSize / Self.designSpace)
        .frame(width: Self.artSize, height: Self.artSize)
    }

    /// Doesn't turn, isn't ghosted.
    private var pill: some View {
        Text(verbatim: Self.pillText)
            .font(Theme.Fonts.previewPill)
            .tracking(Theme.Fonts.previewPillTracking)
            .foregroundStyle(Theme.Colors.accent)
            .padding(.vertical, Self.pillPaddingVertical)
            .padding(.horizontal, Self.pillPaddingHorizontal)
            .background(Theme.Colors.bg, in: Capsule())
            .overlay {
                Capsule().strokeBorder(Theme.Colors.previewPillBorder, lineWidth: Theme.Metrics.hairline)
            }
            .fixedSize()
    }
}

// MARK: - Timeline

/// Runs the loop from its start each time it appears, so it always begins at
/// north up (a resume after the background included).
private struct CompassGhostTimeline<Dial: View>: View {

    let dial: (Double) -> Dial

    @State private var start = Date()

    var body: some View {
        TimelineView(.animation) { context in
            dial(CompassGhostMotion.degrees(at: context.date.timeIntervalSince(start)))
        }
    }
}

// MARK: - Previews

#Preview("Ghost, moon down") {
    CompassGhost(
        targets: [
            CompassTarget(kind: .moonrise, azimuth: 72),
            CompassTarget(kind: .moonset, azimuth: 288),
        ],
        arc: CompassArc(startAzimuth: 72, endAzimuth: 288, moonAzimuth: nil),
        moonGlyph: nil
    )
    .padding(40)
    .background { ScreenBackground() }
}

#Preview("Ghost, no moonset") {
    CompassGhost(targets: [CompassTarget(kind: .moonrise, azimuth: 72)], arc: nil, moonGlyph: nil)
        .padding(40)
        .background { ScreenBackground() }
}
