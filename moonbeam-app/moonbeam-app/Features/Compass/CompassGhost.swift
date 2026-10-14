//
//  CompassGhost.swift
//  moonbeam-app
//

import SwiftUI

/// The location-off prompt's art (LOCATION-OFF-FLOW.md §2, design 1.9
/// "S1: Prompt"): a plain ring with the day's real rise-to-set arc, its end
/// dots, the moon marker and "N", ghosted to 42% and blurred, turning slowly
/// under a fixed north tick with a PREVIEW pill over it. Drawn for this, not
/// the live dial, whose ticks and numbers made the ghost muddy (DECISIONS.md
/// 2026-10-13, 5.12b.1 follow-up).
///
/// Drawn in the handoff's 260-unit space (`CompassGhostGeometry`) and scaled
/// to 210 pt, so every size below is in those units.
///
/// Reduce Motion, the app in the background and the art scrolled out of view
/// all show the still 0° frame rather than a paused timeline, by
/// `LocationIllustration.shouldAnimate`. Decorative: hidden from VoiceOver.
struct CompassGhost: View {

    let geometry: CompassGhostGeometry

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    /// On screen: in the hierarchy, and (inside a scroll view) in view.
    @State private var isInHierarchy = false
    @State private var isScrolledIntoView = true

    // MARK: - Constants (design 1.9, in 260-unit space unless noted)

    /// On screen, in points.
    static let artSize: CGFloat = 210
    private static let scale = artSize / CompassGhostGeometry.space
    private static let layerOpacity = 0.42
    /// In points, applied after the scale.
    private static let layerBlur: CGFloat = 1.2

    private static let ringWidth: CGFloat = 2
    private static let arcWidth: CGFloat = 4
    private static let endDotRadius: CGFloat = 6
    private static let moonRadius: CGFloat = 10
    private static let moonHaloRadius: CGFloat = 16
    private static let moonHaloOpacity = 0.3

    /// "N", this far inside the ring's top.
    private static let northInset: CGFloat = 14

    /// The fixed tick: x 130, y 0 to 34, 4 wide, round caps.
    private static let tickWidth: CGFloat = 4
    private static let tickBottom: CGFloat = 34

    /// PREVIEW: padding 7 × 11, 1 pt border, fully rounded (points).
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
                    CompassGhostTimeline(art: art(ringDegrees:))
                } else {
                    art(ringDegrees: CompassGhostMotion.stillDegrees)
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

    /// One frame: the ring group turned `ringDegrees` clockwise, under the
    /// tick, which doesn't turn.
    private func art(ringDegrees: Double) -> some View {
        let space = CompassGhostGeometry.space
        return ZStack {
            ring
                .rotationEffect(.degrees(ringDegrees))
            tick
        }
        .frame(width: space, height: space)
        .scaleEffect(Self.scale)
        .frame(width: Self.artSize, height: Self.artSize)
    }

    /// Ring, arc, end dots, moon and N: everything that turns.
    private var ring: some View {
        let centre = CompassGhostGeometry.centre
        let radius = CompassGhostGeometry.ringRadius
        return ZStack {
            Circle()
                .stroke(Theme.Colors.faint, lineWidth: Self.ringWidth)
                .frame(width: radius * 2, height: radius * 2)
                .position(centre)
            if !geometry.arcPoints.isEmpty {
                Path { $0.addLines(geometry.arcPoints) }
                    .stroke(
                        Theme.Colors.accent,
                        style: StrokeStyle(lineWidth: Self.arcWidth, lineCap: .round, lineJoin: .round)
                    )
            }
            if let rise = geometry.riseDot {
                Self.disc(radius: Self.endDotRadius, color: Theme.Colors.accent, at: rise)
            }
            if let set = geometry.setDot {
                Self.disc(radius: Self.endDotRadius, color: Theme.Colors.accent, at: set)
            }
            if let moon = geometry.moonMarker {
                Self.disc(radius: Self.moonHaloRadius, color: Theme.Colors.accent.opacity(Self.moonHaloOpacity), at: moon)
                Self.disc(radius: Self.moonRadius, color: Theme.Colors.ghostMoon, at: moon)
            }
            Text(verbatim: "N")
                .font(Theme.Fonts.ghostNorth)
                .foregroundStyle(Theme.Colors.teaserBody)
                .position(x: centre.x, y: centre.y - radius + Self.northInset)
        }
        .frame(width: CompassGhostGeometry.space, height: CompassGhostGeometry.space)
    }

    private var tick: some View {
        Path { path in
            path.move(to: CGPoint(x: CompassGhostGeometry.centre.x, y: 0))
            path.addLine(to: CGPoint(x: CompassGhostGeometry.centre.x, y: Self.tickBottom))
        }
        .stroke(Theme.Colors.textPrimary, style: StrokeStyle(lineWidth: Self.tickWidth, lineCap: .round))
    }

    private static func disc(radius: CGFloat, color: Color, at point: CGPoint) -> some View {
        Circle()
            .fill(color)
            .frame(width: radius * 2, height: radius * 2)
            .position(point)
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
private struct CompassGhostTimeline<Art: View>: View {

    let art: (Double) -> Art

    @State private var start = Date()

    var body: some View {
        TimelineView(.animation) { context in
            art(CompassGhostMotion.degrees(at: context.date.timeIntervalSince(start)))
        }
    }
}

// MARK: - Previews

/// The mock's sample: rise 115°, set 243°, the moon at 200°.
#Preview("Ghost, moon up") {
    CompassGhost(geometry: CompassGhostGeometry(rise: 115, set: 243, moonAzimuth: 200))
        .padding(40)
        .background { ScreenBackground() }
}

#Preview("Ghost, moon down") {
    CompassGhost(geometry: CompassGhostGeometry(rise: 57, set: 304, moonAzimuth: nil))
        .padding(40)
        .background { ScreenBackground() }
}

#Preview("Ghost, no moonset") {
    CompassGhost(geometry: CompassGhostGeometry(rise: 72, set: nil, moonAzimuth: nil))
        .padding(40)
        .background { ScreenBackground() }
}
