//
//  LocationIllustration.swift
//  moonbeam-app
//

import SwiftUI

/// The animated calico art on a location failure screen (STEP-5.10a):
/// the cause's slices move from `IllustrationSpec` on their shared 400 × 520
/// canvas. The screen only knows this view. Decorative: hidden from VoiceOver.
struct LocationIllustration: View {

    /// Which drawing. Each has the moon inside it, so it takes the dimmed
    /// moon's place.
    nonisolated enum Kind: CaseIterable, Sendable {
        case searching
        case locationNotFound
        case permissionOff
        case servicesOff
        case restricted

        var spec: IllustrationSpec {
            IllustrationSpec.spec(for: self)
        }
    }

    /// The art's canvas (its SVG viewBox), shared by every state, so one
    /// frame lines them all up.
    nonisolated static let designSize = IllustrationSpec.viewBox

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false
    @State private var motionStartedAt: TimeInterval?

    let kind: Kind
    var animationDelay: TimeInterval = 0

    var body: some View {
        ZStack {
            if Self.shouldAnimate(
                reduceMotion: reduceMotion,
                scenePhase: scenePhase,
                isVisible: isVisible && motionStartedAt != nil
            ) {
                TimelineView(.animation) { context in
                    LocationIllustrationFrame(
                        spec: kind.spec,
                        time: timelineTime(for: context.date)
                    )
                }
            } else {
                LocationIllustrationFrame(spec: kind.spec, time: nil)
            }
        }
        .aspectRatio(Self.designSize, contentMode: .fit)
        .accessibilityHidden(true)
        .onAppear {
            isVisible = true
        }
        .onDisappear {
            isVisible = false
            motionStartedAt = nil
        }
        .task {
            if animationDelay > 0 {
                try? await Task.sleep(for: .seconds(animationDelay))
                guard !Task.isCancelled else { return }
            }
            motionStartedAt = Date.timeIntervalSinceReferenceDate
        }
    }

    /// A timeline exists only while motion is allowed and the art can be seen.
    /// Returning false selects static artwork, rather than a paused timeline.
    nonisolated static func shouldAnimate(
        reduceMotion: Bool,
        scenePhase: ScenePhase,
        isVisible: Bool
    ) -> Bool {
        !reduceMotion && scenePhase == .active && isVisible
    }

    /// Landing art starts at its rest pose when its load-in reaches home.
    /// Existing failure illustrations keep their established absolute phase.
    private func timelineTime(for date: Date) -> TimeInterval {
        let now = date.timeIntervalSinceReferenceDate
        guard animationDelay > 0, let motionStartedAt else { return now }
        return max(now - motionStartedAt, 0)
    }
}

/// One timeline sample. Keeping the frame separate means only the drawing
/// invalidates on each animation tick.
private struct LocationIllustrationFrame: View {
    let spec: IllustrationSpec
    let time: TimeInterval?

    var body: some View {
        GeometryReader { geometry in
            let scale = geometry.size.width / IllustrationSpec.viewBox.width

            ZStack {
                ForEach(spec.layers, id: \.asset) { layer in
                    LocationIllustrationLayer(
                        layer: layer,
                        spec: spec,
                        time: time,
                        canvasSize: geometry.size,
                        canvasScale: scale
                    )
                }

                if let star = spec.star {
                    IllustrationStarView(star: star, time: time, canvasScale: scale)
                }

                if spec.spark != nil, let state = spec.sparkState(at: time) {
                    IllustrationSparkView(state: state, canvasScale: scale)
                }
            }
        }
    }
}

/// One full-canvas asset slice with all of its nested part transforms applied.
private struct LocationIllustrationLayer: View {
    let layer: IllustrationSpec.Layer
    let spec: IllustrationSpec
    let time: TimeInterval?
    let canvasSize: CGSize
    let canvasScale: CGFloat

    var body: some View {
        let poses = layer.parts.map { part in
            (part, spec.pose(of: part, at: time))
        }
        let transform = spec.transform(of: layer, at: time, canvasScale: canvasScale)
        let opacity = poses.reduce(1.0) { result, item in
            result * item.1.opacity * waypointOpacity(for: item.0)
        }
        let brightness = poses.reduce(1.0) { result, item in
            result * item.1.brightness
        }

        if let bands = spec.tailBands(of: layer, at: time, canvasScale: canvasScale) {
            // A bending tail: the one slice, clipped into bands that each
            // turn on their own joint, base to tip. Each band first clears
            // its own rect, then draws, so the overlap that closes a turned
            // joint replaces the band below instead of doubling its alpha
            // (1k's tail base is translucent where it fades into the body).
            // Clear and mask are one aliased fill so they cover the same
            // pixels; two antialiased edges on one line would leave a
            // see-through seam, and a clip rounds its edge row differently.
            ZStack {
                ForEach(bands.indices, id: \.self) { index in
                    let band = bands[index]
                    Path(band.clip)
                        .fill(.black, style: Self.bandEdge)
                        .transformEffect(band.transform)
                        .blendMode(.destinationOut)
                    slice
                        .frame(width: canvasSize.width, height: canvasSize.height)
                        .mask { Path(band.clip).fill(.black, style: Self.bandEdge) }
                        .transformEffect(band.transform)
                }
            }
            .compositingGroup()
            .brightness(brightness - 1)
            .opacity(opacity)
        } else {
            slice
                .frame(width: canvasSize.width, height: canvasSize.height)
                .brightness(brightness - 1)
                .opacity(opacity)
                .transformEffect(transform)
        }
    }

    private static let bandEdge = FillStyle(antialiased: false)

    /// A full-canvas vector slice, or a raster drawn at its own viewBox
    /// rect on the canvas, so its pixels are only scaled once.
    @ViewBuilder private var slice: some View {
        if let placement = layer.placement {
            Image(layer.asset)
                .resizable()
                .interpolation(.high)
                .frame(
                    width: placement.width * canvasScale,
                    height: placement.height * canvasScale
                )
                .position(
                    x: placement.midX * canvasScale,
                    y: placement.midY * canvasScale
                )
        } else {
            Image(layer.asset)
                .resizable()
        }
    }

    private func waypointOpacity(for part: IllustrationSpec.Part) -> Double {
        guard let index = part.waypointIndex,
              let spark = spec.spark,
              let state = spec.sparkState(at: time) else {
            return 1
        }
        return spark.waypointOpacity(index, spark: state)
    }
}

private struct IllustrationStarView: View {
    let star: IllustrationSpec.Star
    let time: TimeInterval?
    let canvasScale: CGFloat

    var body: some View {
        let pose = star.motion.pose(at: time ?? 0)
        let path = SVGPathData.path(
            IllustrationSpec.Star.pathData,
            offset: star.centre
        ).applying(CGAffineTransform(scaleX: canvasScale, y: canvasScale))

        path
            .fill(Color(illustrationHex: IllustrationSpec.Star.colorHex))
            .opacity(time == nil ? 0 : pose.opacity)
            .transformEffect(
                pose.scaledTransform(pivot: star.centre, canvasScale: canvasScale)
            )
    }
}

private struct IllustrationSparkView: View {
    let state: IllustrationSpark.State
    let canvasScale: CGFloat

    var body: some View {
        let diameter = IllustrationSpark.glowRadius * 2 * canvasScale
        let point = CGPoint(x: state.point.x * canvasScale, y: state.point.y * canvasScale)

        Circle()
            .fill(Color(illustrationHex: IllustrationSpark.glowColorHex).opacity(IllustrationSpark.glowOpacity))
            .frame(width: diameter, height: diameter)
            .overlay {
                Circle()
                    .fill(Color(illustrationHex: IllustrationSpark.coreColorHex))
                    .frame(
                        width: IllustrationSpark.coreRadius * 2 * canvasScale,
                        height: IllustrationSpark.coreRadius * 2 * canvasScale
                    )
            }
            .position(point)
            .opacity(state.opacity)
    }
}

private extension Color {
    init(illustrationHex hex: UInt32) {
        let channelMax = 255.0
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / channelMax,
            green: Double((hex >> 8) & 0xFF) / channelMax,
            blue: Double(hex & 0xFF) / channelMax
        )
    }
}

#Preview {
    HStack {
        ForEach(LocationIllustration.Kind.allCases, id: \.self) { kind in
            LocationIllustration(kind: kind)
        }
    }
    .background { ScreenBackground() }
}
