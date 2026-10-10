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

    let kind: Kind

    var body: some View {
        ZStack {
            if Self.shouldAnimate(
                reduceMotion: reduceMotion,
                scenePhase: scenePhase,
                isVisible: isVisible
            ) {
                TimelineView(.animation) { context in
                    LocationIllustrationFrame(
                        spec: kind.spec,
                        time: context.date.timeIntervalSinceReferenceDate
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
        let transform = poses.reduce(CGAffineTransform.identity) { result, item in
            result.concatenating(
                item.1.scaledTransform(
                    pivot: spec.pivots[item.0],
                    canvasScale: canvasScale
                )
            )
        }
        let opacity = poses.reduce(1.0) { result, item in
            result * item.1.opacity * waypointOpacity(for: item.0)
        }
        let brightness = poses.reduce(1.0) { result, item in
            result * item.1.brightness
        }

        Image(layer.asset)
            .resizable()
            .frame(width: canvasSize.width, height: canvasSize.height)
            .brightness(brightness - 1)
            .opacity(opacity)
            .transformEffect(transform)
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

private extension IllustrationMotion.Pose {
    /// Converts the spec's viewBox-space transform to the fitted frame.
    func scaledTransform(pivot: CGPoint?, canvasScale: CGFloat) -> CGAffineTransform {
        var scaledPose = self
        scaledPose.offsetY *= canvasScale
        let scaledPivot = pivot.map {
            CGPoint(x: $0.x * canvasScale, y: $0.y * canvasScale)
        }
        return scaledPose.transform(pivot: scaledPivot)
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
