//
//  CompassDial.swift
//  moonbeam-app
//

import SwiftUI

/// The compass dial (DESIGN-1.1.md §3.3, COMPASS.md §1): a lit face with tick
/// dots every 15°, N/E/S/W, a moon-coloured dot on the rim for moonrise (↑)
/// and moonset (↓), a mini phase glyph for the live Moon (§11 Q4, revised)
/// and a fixed indicator at 12 o'clock. Locked, the target's mark grows and
/// glows and the dial gets a soft amber halo.
///
/// The face itself doesn't turn: everything on it is placed at its on-screen
/// angle (azimuth − heading), so letters, arrows and the Moon's phase are
/// always upright and
/// the face's light stays at the top. Turning the phone right still moves
/// the marks left, as in Compass. Not animated: a turn from 359° to 0° would
/// otherwise spin the long way. Only the lock change animates, and not with
/// Reduce Motion.
///
/// For VoiceOver it's one element that reads its targets ("Targets:
/// moonrise, 72 degrees east-northeast; …"); with no targets it's hidden.
struct CompassDial: View {

    /// Degrees from true north the phone points, or `nil` with no heading.
    let heading: Double?

    let targets: [CompassTarget]
    let lockedKind: CompassTarget.Kind?

    /// `CompassViewModel.targetsAccessibilityLabel`; `nil` hides the dial
    /// from VoiceOver.
    var accessibilityTargets: String? = nil

    /// The live Moon's phase (`CompassViewModel.moonGlyph`). `nil` draws the
    /// Moon as a plain dot.
    var moonGlyph: PhaseGlyphGeometry? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The letters scale with Dynamic Type up to `dialLetterMaxSize` (§2).
    @ScaledMetric(relativeTo: .subheadline) private var letterSize = Theme.Fonts.dialLetterSize

    // MARK: - Constants (§3.3, measured from the HTML)

    /// The AX sizes' fixed 260 pt dial is 5.5 (§4).
    private static let diameter: CGFloat = 220

    private static let fullTurnDegrees = 360
    private static let tickStepDegrees = 15
    private static let cardinalStepDegrees = 90
    private static let tickSize: CGFloat = 3
    private static let cardinalTickSize: CGFloat = 5
    /// From the rim to a tick's outer edge.
    private static let tickInset: CGFloat = 10

    /// From the rim to the centre of a letter and of an ↑/↓ arrow.
    private static let letterCentreInset: CGFloat = 34
    private static let arrowCentreInset: CGFloat = 22

    private static let targetDotSize: CGFloat = 14
    /// The live Moon (§11 Q4, revised): a mini phase glyph, bigger than
    /// the rise/set dots, no arrow. Locked, it grows like the others.
    private static let moonMarkerSize: CGFloat = 20
    private static let lockedDotSize: CGFloat = 22
    private static let lockedRingWidth: CGFloat = 4
    private static let lockedRingOpacity = 0.35

    /// CSS blurs are about twice SwiftUI's shadow radius.
    private static let targetGlowRadius: CGFloat = 5
    private static let targetGlowOpacity = 0.35
    private static let lockedGlowRadius: CGFloat = 13
    private static let lockedGlowSpread: CGFloat = 6
    private static let lockedGlowOpacity = 0.7

    /// The locked halo reaches this far past the rim, `accent` 28% → 0.
    private static let haloOverhang: CGFloat = 18
    private static let haloOpacity = 0.28

    /// The indicator: a 6 × 18 capsule whose top is 10 pt above the rim.
    private static let indicatorSize = CGSize(width: 6, height: 18)
    private static let indicatorRise: CGFloat = 10

    /// The face: radial gradient centred at 50% / 40%, out to the farthest
    /// corner of its box (CSS `circle at 50% 40%`), a 1 pt inner highlight
    /// at the top and a soft drop shadow (`0 12px 30px` black 35%).
    private static let faceGradientCentre = UnitPoint(x: 0.5, y: 0.4)
    private static let faceGradientReach: CGFloat = 0.781
    private static let faceHighlightOpacity = 0.06
    private static let faceHighlightHeight: CGFloat = 1
    private static let faceShadowOpacity = 0.35
    private static let faceShadowRadius: CGFloat = 15
    private static let faceShadowOffsetY: CGFloat = 12

    /// With no heading (the simulator), the marks are faded and north-up.
    private static let noHeadingOpacity = 0.4

    private static let lockAnimation = Animation.easeOut(duration: 0.2)

    private static let cardinals: [(label: String, degrees: Double)] = [
        ("N", 0), ("E", 90), ("S", 180), ("W", 270),
    ]

    // MARK: - Body

    var body: some View {
        ZStack {
            face(diameter: Self.diameter)
            marks(diameter: Self.diameter)
                .opacity(heading == nil ? Self.noHeadingOpacity : 1)
        }
        .frame(width: Self.diameter, height: Self.diameter)
        .background { halo(diameter: Self.diameter) }
        .overlay(alignment: .top) { indicator }
        .padding(.top, Self.indicatorRise)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityTargets ?? "")
        .accessibilityHidden(accessibilityTargets == nil)
    }

    // MARK: - Face

    private func face(diameter: CGFloat) -> some View {
        let circle = Circle()
        let inner = circle.inset(by: Theme.Metrics.hairline)
        return circle
            .fill(
                RadialGradient(
                    colors: [Theme.Colors.dialTop, Theme.Colors.dialBottom],
                    center: Self.faceGradientCentre,
                    startRadius: 0,
                    endRadius: diameter * Self.faceGradientReach
                )
            )
            .overlay {
                inner
                    .subtracting(inner.offset(y: Self.faceHighlightHeight))
                    .fill(.white.opacity(Self.faceHighlightOpacity))
            }
            .shadow(
                color: .black.opacity(Self.faceShadowOpacity),
                radius: Self.faceShadowRadius,
                y: Self.faceShadowOffsetY
            )
    }

    /// Only while locked (§3.3): the whole dial sits in a soft amber glow.
    @ViewBuilder
    private func halo(diameter: CGFloat) -> some View {
        if lockedKind != nil {
            let reach = diameter / 2 + Self.haloOverhang
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.Colors.accent.opacity(Self.haloOpacity), Theme.Colors.accent.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: reach
                    )
                )
                .frame(width: reach * 2, height: reach * 2)
                .transition(.opacity)
        }
    }

    /// Fixed at 12 o'clock, straddling the rim: where the phone points.
    private var indicator: some View {
        Capsule()
            .fill(Theme.Colors.textPrimary)
            .frame(width: Self.indicatorSize.width, height: Self.indicatorSize.height)
            .offset(y: -Self.indicatorRise)
    }

    // MARK: - Marks

    private func marks(diameter: CGFloat) -> some View {
        let radius = diameter / 2
        return ZStack {
            ticks(radius: radius)
            letters(radius: radius)
            targetMarks(radius: radius)
        }
        .frame(width: diameter, height: diameter)
    }

    private func ticks(radius: CGFloat) -> some View {
        ForEach(Array(stride(from: 0, to: Self.fullTurnDegrees, by: Self.tickStepDegrees)), id: \.self) { degrees in
            let size = degrees.isMultiple(of: Self.cardinalStepDegrees) ? Self.cardinalTickSize : Self.tickSize
            Circle()
                .fill(Theme.Colors.tick)
                .frame(width: size, height: size)
                .position(point(at: Double(degrees), distanceFromRim: Self.tickInset + size / 2, radius: radius))
        }
        .accessibilityHidden(true)
    }

    /// N in amber, the rest in `textSecondary`, always upright.
    private func letters(radius: CGFloat) -> some View {
        ForEach(Self.cardinals, id: \.label) { cardinal in
            Text(cardinal.label)
                .font(Theme.Fonts.dialLetter(size: letterSize))
                .foregroundStyle(cardinal.degrees == 0 ? Theme.Colors.accent : Theme.Colors.textSecondary)
                .position(point(at: cardinal.degrees, distanceFromRim: Self.letterCentreInset, radius: radius))
        }
    }

    private func targetMarks(radius: CGFloat) -> some View {
        ForEach(targets, id: \.kind) { target in
            let isLocked = target.kind == lockedKind
            targetMark(kind: target.kind, isLocked: isLocked)
                .position(point(at: target.azimuth, distanceFromRim: 0, radius: radius))
            if let arrow = Self.arrow(for: target.kind) {
                Text(arrow)
                    .font(Theme.Fonts.dialArrow)
                    .foregroundStyle(Theme.Colors.accent)
                    .position(point(at: target.azimuth, distanceFromRim: Self.arrowCentreInset, radius: radius))
            }
        }
    }

    /// A target's mark; locked, it grows and gets a ring and a strong glow
    /// (§3.3), the live Moon included.
    private func targetMark(kind: CompassTarget.Kind, isLocked: Bool) -> some View {
        let size = isLocked ? Self.lockedDotSize : (kind == .moon ? Self.moonMarkerSize : Self.targetDotSize)
        return targetFace(kind: kind, isLocked: isLocked)
            .frame(width: size, height: size)
            .background {
                if isLocked {
                    Circle()
                        .fill(Theme.Colors.accent.opacity(Self.lockedGlowOpacity))
                        .frame(width: size + 2 * Self.lockedGlowSpread, height: size + 2 * Self.lockedGlowSpread)
                        .blur(radius: Self.lockedGlowRadius)
                }
            }
            .overlay {
                if isLocked {
                    Circle()
                        .stroke(Theme.Colors.accent.opacity(Self.lockedRingOpacity), lineWidth: Self.lockedRingWidth)
                        .frame(width: size + Self.lockedRingWidth, height: size + Self.lockedRingWidth)
                }
            }
            .animation(reduceMotion ? nil : Self.lockAnimation, value: isLocked)
    }

    /// The live Moon is the card's phase glyph (its own lit fraction,
    /// terminator, `moonLit` and glow), so it can't pass for a second
    /// moonrise. It's placed, not rotated, so it stays upright. Rise and set
    /// are `moonLit` dots with a faint amber glow.
    @ViewBuilder
    private func targetFace(kind: CompassTarget.Kind, isLocked: Bool) -> some View {
        if kind == .moon, let moonGlyph {
            PhaseGlyph(geometry: moonGlyph)
        } else {
            Circle()
                .fill(Theme.Colors.moonLit)
                .shadow(color: Theme.Colors.accent.opacity(isLocked ? 0 : Self.targetGlowOpacity), radius: Self.targetGlowRadius)
        }
    }

    // MARK: - Geometry

    /// Where something at `azimuth` sits on screen, `distanceFromRim` in from
    /// the rim. Its on-screen angle is the azimuth less the heading.
    private func point(at azimuth: Double, distanceFromRim: CGFloat, radius: CGFloat) -> CGPoint {
        let angle = Angle.degrees(azimuth - (heading ?? 0)).radians
        let distance = radius - distanceFromRim
        return CGPoint(
            x: radius + distance * CGFloat(sin(angle)),
            y: radius - distance * CGFloat(cos(angle))
        )
    }

    /// ↑ moonrise, ↓ moonset; the live Moon has none (§11 Q4).
    private static func arrow(for kind: CompassTarget.Kind) -> String? {
        switch kind {
        case .moonrise: "↑"
        case .moonset: "↓"
        case .moon: nil
        }
    }
}

// MARK: - Previews

#Preview("Heading 72°, three targets") {
    CompassDial(
        heading: 72,
        targets: [
            CompassTarget(kind: .moonrise, azimuth: 58),
            CompassTarget(kind: .moonset, azimuth: 301),
            CompassTarget(kind: .moon, azimuth: 140),
        ],
        lockedKind: nil,
        moonGlyph: PhaseGlyphGeometry(illumination: 0.64, phaseAngle: 240)
    )
    .padding(40)
    .background(Theme.Colors.bg)
}

#Preview("Locked on moonrise") {
    CompassDial(
        heading: 58,
        targets: [
            CompassTarget(kind: .moonrise, azimuth: 58),
            CompassTarget(kind: .moonset, azimuth: 301),
        ],
        lockedKind: .moonrise
    )
    .padding(40)
    .background(Theme.Colors.bg)
}

#Preview("No heading") {
    CompassDial(heading: nil, targets: [CompassTarget(kind: .moonset, azimuth: 252)], lockedKind: nil)
        .padding(40)
        .background(Theme.Colors.bg)
}
