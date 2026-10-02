//
//  CompassDial.swift
//  moonbeam-app
//

import SwiftUI

/// The compass dial (DESIGN-1.1.md §3.3, §3.3a, COMPASS-1.1.md §4, COMPASS.md
/// §1): a lit face with tick lines every 2° (longer every 10° and 30°), degree
/// numbers every 30°, N/E/S/W in Young Serif and a fixed crosshair; outside
/// the rim, the moon arc, the moon's pass from rise to set, with `moonLit`
/// dots at moonrise and moonset, the live Moon as a phase glyph riding on it
/// (pulsing until the first lock), and their labels beyond; and a fixed
/// needle at 12 o'clock from above the arc into the ticks.
/// Locked, the target's mark grows and glows and the dial gets a soft amber
/// halo.
///
/// The face itself doesn't turn: everything is placed at its on-screen
/// angle (azimuth − heading), so letters, labels and the Moon's phase are
/// always upright and the face's light stays at the top. Turning the phone
/// right still moves the marks left, as in Compass. Not animated: a turn
/// from 359° to 0° would otherwise spin the long way, and the Moon steps
/// along its arc with the 30 s refresh. Only the lock change animates, and
/// not with Reduce Motion.
///
/// For VoiceOver it's one element that reads its targets ("Targets:
/// moonrise, 72 degrees east-northeast; …"); with no targets it's hidden.
/// The arc adds nothing to it (§3.3a).
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

    /// `CompassViewModel.arc`; `nil` draws no arc, and the targets still sit
    /// on its track.
    var arc: CompassArc? = nil

    /// `CompassViewModel.showsMoonPulse`: the ring pulsing from the Moon.
    var showsMoonPulse = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The letters scale with Dynamic Type up to `dialLetterMaxSize` (§2).
    @ScaledMetric(relativeTo: .subheadline) private var letterSize = Theme.Fonts.dialLetterSize

    // MARK: - Constants (§3.3, §3.3a, measured from the HTML)

    /// §3.3a: 196 pt, down from 5.4's 220, to make room for the arc. The AX
    /// sizes' 260 pt dial is 5.5 (§4).
    private static let diameter: CGFloat = 196
    private static let dialRadius = diameter / 2

    private static let fullTurnDegrees = 360
    private static let cardinalStepDegrees = 90

    /// Ticks (COMPASS-1.1.md §4, the HTML's 104 pt dial scaled to 98 pt):
    /// every 2° minor, every 10° mid, every 30° heavy, from just inside the
    /// rim inwards. Minor ticks are under 3:1 and decorative; mid and heavy
    /// carry the reading.
    private static let minorTickStepDegrees = 2
    private static let midTickStepDegrees = 10
    private static let heavyTickStepDegrees = 30
    private static let tickOuterInset: CGFloat = 1
    private static let minorTick = (length: CGFloat(7), width: CGFloat(1))
    private static let midTick = (length: CGFloat(11), width: CGFloat(1.4))
    private static let heavyTick = (length: CGFloat(15), width: CGFloat(2.2))

    /// Degree numbers every 30° except on the cardinals, this far from the
    /// centre; cardinals at `letterCentreDistance`.
    private static let numberCentreDistance: CGFloat = 72
    private static let letterCentreDistance: CGFloat = 58
    /// Target labels ("↑ Rise", "↓ Set", "Now", COMPASS-1.1.md §5): centred
    /// this far beyond the arc's track (138 pt from the centre), with a `bg`
    /// halo so they read over the dots.
    private static let labelGap: CGFloat = 24
    private static let labelHaloRadius: CGFloat = 1.5

    /// The Moon's pulse (§5): a 2 pt `accent` ring growing from 10 to 24 pt
    /// radius as it fades from 80%, every 1.8 s. Reduce Motion: a still ring
    /// halfway out.
    private static let pulseStartRadius: CGFloat = 10
    private static let pulseEndRadius: CGFloat = 24
    private static let pulseStaticRadius: CGFloat = 17
    private static let pulseLineWidth: CGFloat = 2
    private static let pulseStartOpacity = 0.8
    private static let pulseDuration = 1.8

    /// The fixed crosshair: ±28 pt, 1 pt, with a 2 pt centre dot.
    private static let crosshairReach: CGFloat = 28
    private static let crosshairDotSize: CGFloat = 2

    /// The arc's track: this far outside the rim (114 pt from the centre).
    private static let arcGap: CGFloat = 16
    private static let arcRadius = dialRadius + arcGap
    /// Still to come: 3 pt round dots about 6.6 pt apart, `accent` 95%.
    private static let arcDotSize: CGFloat = 3
    private static let arcDotSpacing: CGFloat = 6.6
    /// A dash just long enough to draw its round caps: a dot.
    private static let arcDotDash: CGFloat = 0.01
    private static let arcRemainingOpacity = 0.95
    /// Already travelled: a solid `accent` hairline at 30%.
    private static let arcTravelledWidth: CGFloat = 1.5
    private static let arcTravelledOpacity = 0.3
    /// The moon is down: the next pass, all dotted, and its rise and set
    /// dots, at 30%.
    private static let arcNextPassOpacity = 0.3
    /// The arc is drawn as straight steps this many degrees long.
    private static let arcStepDegrees = 1.0

    private static let targetDotSize: CGFloat = 14
    /// The live Moon (§3.3a): the card's phase glyph at 24 pt, on a `bg`
    /// disc 4 pt wider all round so the arc's dots stop short of it.
    private static let moonMarkerSize: CGFloat = 24
    private static let moonDiscMargin: CGFloat = 4
    /// Its own soft glow (the HTML's): `moonLit` 16%, 1.5× the glyph,
    /// blurred.
    private static let moonGlowScale: CGFloat = 1.5
    private static let moonGlowOpacity = 0.16
    private static let moonGlowBlur: CGFloat = 3.2
    /// The glyph's edge: a 1 pt `tick` ring at 50%, as in the HTML.
    private static let moonEdgeOpacity = 0.5
    /// Locked, rise and set grow to 22 pt and the Moon to 28 pt (so it grows
    /// rather than shrinks from its 24 pt).
    private static let lockedDotSize: CGFloat = 22
    private static let lockedMoonMarkerSize: CGFloat = 28
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

    /// The room above the outer radius that 5.4's capsule indicator had,
    /// kept so the dial doesn't move: the needle starts at its top.
    private static let needleLead: CGFloat = 17
    /// The needle (COMPASS-1.1.md §4): a 3 pt round-capped line from the top
    /// of the view, across the arc at 12 o'clock, ending as deep in the ring
    /// as a mid tick.
    private static let needleWidth: CGFloat = 3
    private static let needleDepth = tickOuterInset + midTick.length

    /// The farthest anything reaches on every side but the top: the glyph's
    /// disc on the arc. The view is this radius all round, plus the
    /// needle's lead on top (about 277 pt tall in all).
    private static let outerRadius = arcRadius + moonMarkerSize / 2 + moonDiscMargin
    private static let outerSize = outerRadius * 2

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

    /// 30, 60, 120 … 330: every heavy tick but the cardinals.
    private static let numberedDegrees = stride(from: heavyTickStepDegrees, to: fullTurnDegrees, by: heavyTickStepDegrees)
        .filter { !$0.isMultiple(of: cardinalStepDegrees) }

    /// The moon is up and this is its pass; otherwise everything on the arc
    /// is dimmed.
    private var isMoonUp: Bool {
        targets.contains { $0.kind == .moon }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            halo
            face
            crosshair
            marks
                .opacity(heading == nil ? Self.noHeadingOpacity : 1)
        }
        .frame(width: Self.outerSize, height: Self.outerSize)
        .overlay { needle }
        .padding(.top, Self.needleLead)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityTargets ?? "")
        .accessibilityHidden(accessibilityTargets == nil)
    }

    // MARK: - Face

    private var face: some View {
        let circle = Circle()
        let inner = circle.inset(by: Theme.Metrics.hairline)
        return circle
            .fill(
                RadialGradient(
                    colors: [Theme.Colors.dialTop, Theme.Colors.dialBottom],
                    center: Self.faceGradientCentre,
                    startRadius: 0,
                    endRadius: Self.diameter * Self.faceGradientReach
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
            .frame(width: Self.diameter, height: Self.diameter)
    }

    /// Only while locked (§3.3): the whole dial sits in a soft amber glow.
    /// Unchanged by the arc (§3.3a leaves its tone against the amber arc
    /// open).
    @ViewBuilder
    private var halo: some View {
        if lockedKind != nil {
            let reach = Self.dialRadius + Self.haloOverhang
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

    /// Fixed at 12 o'clock: where the phone points. From the top of the
    /// view (just under the readout), across the arc, into the ticks; amber
    /// while locked. Drawn over the marks, as in the HTML.
    private var needle: some View {
        let capRadius = Self.needleWidth / 2
        return Path { path in
            path.move(to: CGPoint(x: Self.outerRadius, y: capRadius - Self.needleLead))
            path.addLine(to: CGPoint(x: Self.outerRadius, y: Self.outerRadius - Self.dialRadius + Self.needleDepth))
        }
        .stroke(
            lockedKind == nil ? Theme.Colors.textPrimary : Theme.Colors.accent,
            style: StrokeStyle(lineWidth: Self.needleWidth, lineCap: .round)
        )
        .frame(width: Self.outerSize, height: Self.outerSize)
        .accessibilityHidden(true)
    }

    /// Fixed, under the turning marks; decorative.
    private var crosshair: some View {
        let centre = Self.outerRadius
        let reach = Self.crosshairReach
        return ZStack {
            Path { path in
                path.move(to: CGPoint(x: centre - reach, y: centre))
                path.addLine(to: CGPoint(x: centre + reach, y: centre))
                path.move(to: CGPoint(x: centre, y: centre - reach))
                path.addLine(to: CGPoint(x: centre, y: centre + reach))
            }
            .stroke(Theme.Colors.faint, lineWidth: Theme.Metrics.hairline)
            Circle()
                .fill(Theme.Colors.tick)
                .frame(width: Self.crosshairDotSize, height: Self.crosshairDotSize)
                .position(x: centre, y: centre)
        }
        .frame(width: Self.outerSize, height: Self.outerSize)
        .accessibilityHidden(true)
    }

    // MARK: - Marks

    private var marks: some View {
        ZStack {
            ticks
            numbers
            letters
            arcTrack
            targetMarks
        }
        .frame(width: Self.outerSize, height: Self.outerSize)
    }

    /// One path per weight, so 180 ticks are four shapes, not 180 views.
    /// The N tick is heavy, in amber.
    private var ticks: some View {
        ZStack {
            tickPath(where: { !$0.isMultiple(of: Self.midTickStepDegrees) }, length: Self.minorTick.length)
                .stroke(Theme.Colors.faint, lineWidth: Self.minorTick.width)
            tickPath(
                where: { $0.isMultiple(of: Self.midTickStepDegrees) && !$0.isMultiple(of: Self.heavyTickStepDegrees) },
                length: Self.midTick.length
            )
            .stroke(Theme.Colors.dialNumber, lineWidth: Self.midTick.width)
            tickPath(where: { $0.isMultiple(of: Self.heavyTickStepDegrees) && $0 != 0 }, length: Self.heavyTick.length)
                .stroke(Theme.Colors.textBody, lineWidth: Self.heavyTick.width)
            tickPath(where: { $0 == 0 }, length: Self.heavyTick.length)
                .stroke(Theme.Colors.accent, lineWidth: Self.heavyTick.width)
        }
        .accessibilityHidden(true)
    }

    /// Ticks at every 2° that `include` keeps, from just inside the rim
    /// inwards by `length`.
    private func tickPath(where include: (Int) -> Bool, length: CGFloat) -> Path {
        let outer = Self.dialRadius - Self.tickOuterInset
        var path = Path()
        for degrees in stride(from: 0, to: Self.fullTurnDegrees, by: Self.minorTickStepDegrees) where include(degrees) {
            path.move(to: point(at: Double(degrees), distance: outer))
            path.addLine(to: point(at: Double(degrees), distance: outer - length))
        }
        return path
    }

    /// 30, 60, 120 …: fixed size, upright, hidden from VoiceOver (a nice to
    /// have, COMPASS-1.1.md §4).
    private var numbers: some View {
        ForEach(Self.numberedDegrees, id: \.self) { degrees in
            Text(verbatim: String(degrees))
                .font(Theme.Fonts.dialNumber)
                .monospacedDigit()
                .foregroundStyle(Theme.Colors.dialNumber)
                .position(point(at: Double(degrees), distance: Self.numberCentreDistance))
        }
        .accessibilityHidden(true)
    }

    /// Young Serif; N in amber, the rest in `textPrimary`, always upright.
    private var letters: some View {
        ForEach(Self.cardinals, id: \.label) { cardinal in
            Text(cardinal.label)
                .font(Theme.Fonts.dialLetter(size: letterSize))
                .foregroundStyle(cardinal.degrees == 0 ? Theme.Colors.accent : Theme.Colors.textPrimary)
                .position(point(at: cardinal.degrees, distance: Self.letterCentreDistance))
        }
    }

    /// The pass (§3.3a, option B). Moon up: a faint hairline from moonrise
    /// to the Moon, dots from the Moon to moonset. Moon down: the next pass,
    /// all dots, dimmed.
    @ViewBuilder
    private var arcTrack: some View {
        if let arc {
            let dotted = StrokeStyle(
                lineWidth: Self.arcDotSize,
                lineCap: .round,
                dash: [Self.arcDotDash, Self.arcDotSpacing]
            )
            if let moonAzimuth = arc.moonAzimuth {
                // Kept inside the pass, in case the sampled path wobbles past
                // an end.
                let low = min(arc.startAzimuth, arc.endAzimuth)
                let high = max(arc.startAzimuth, arc.endAzimuth)
                let seam = min(max(moonAzimuth, low), high)
                arcPath(from: arc.startAzimuth, to: seam)
                    .stroke(
                        Theme.Colors.accent.opacity(Self.arcTravelledOpacity),
                        style: StrokeStyle(lineWidth: Self.arcTravelledWidth, lineCap: .round)
                    )
                arcPath(from: seam, to: arc.endAzimuth)
                    .stroke(Theme.Colors.accent.opacity(Self.arcRemainingOpacity), style: dotted)
            } else {
                arcPath(from: arc.startAzimuth, to: arc.endAzimuth)
                    .stroke(Theme.Colors.accent.opacity(Self.arcNextPassOpacity), style: dotted)
            }
        }
    }

    /// Each target on the arc's track, with its label outside the arc
    /// (`CompassTargetLabels`: the locked one, and the loser of a collision,
    /// go without). Rise and set dim with the arc while the moon is down; a
    /// locked target never does.
    private var targetMarks: some View {
        let labels = CompassTargetLabels.labels(for: targets, lockedKind: lockedKind)
        return ForEach(targets, id: \.kind) { target in
            let isLocked = target.kind == lockedKind
            let size = Self.markSize(kind: target.kind, isLocked: isLocked)
            if target.kind == .moon, showsMoonPulse {
                MoonPulse(reduceMotion: reduceMotion)
                    .position(point(at: target.azimuth, distance: Self.arcRadius))
            }
            // Grouped so the dot and its glow dim as one, then backed with
            // `bg` so the arc's end dot doesn't show through a dimmed mark.
            targetMark(kind: target.kind, isLocked: isLocked)
                .compositingGroup()
                .opacity(isMoonUp || isLocked ? 1 : Self.arcNextPassOpacity)
                .background {
                    Circle()
                        .fill(Theme.Colors.bg)
                        .frame(width: size, height: size)
                }
                .position(point(at: target.azimuth, distance: Self.arcRadius))
            if let label = labels[target.kind] {
                Text(label)
                    .font(Theme.Fonts.dialTargetLabel)
                    .foregroundStyle(Theme.Colors.textBody)
                    .fixedSize()
                    .shadow(color: Theme.Colors.bg, radius: Self.labelHaloRadius)
                    .shadow(color: Theme.Colors.bg, radius: Self.labelHaloRadius)
                    .position(point(at: target.azimuth, distance: Self.arcRadius + Self.labelGap))
                    .accessibilityHidden(true)
            }
        }
    }

    /// The ring round the Moon until the first lock this launch; hidden from
    /// VoiceOver.
    private struct MoonPulse: View {

        let reduceMotion: Bool
        @State private var isExpanded = false

        var body: some View {
            let radius = reduceMotion
                ? CompassDial.pulseStaticRadius
                : (isExpanded ? CompassDial.pulseEndRadius : CompassDial.pulseStartRadius)
            Circle()
                .stroke(Theme.Colors.accent, lineWidth: CompassDial.pulseLineWidth)
                .frame(width: radius * 2, height: radius * 2)
                .opacity(reduceMotion ? 1 : (isExpanded ? 0 : CompassDial.pulseStartOpacity))
                .accessibilityHidden(true)
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(.easeOut(duration: CompassDial.pulseDuration).repeatForever(autoreverses: false)) {
                        isExpanded = true
                    }
                }
        }
    }

    /// A target's mark; locked, it grows and gets a ring and a strong glow
    /// (§3.3), the live Moon included. The Moon sits on a `bg` disc that
    /// cuts the arc away round it.
    private func targetMark(kind: CompassTarget.Kind, isLocked: Bool) -> some View {
        let size = Self.markSize(kind: kind, isLocked: isLocked)
        let discSize = size + 2 * Self.moonDiscMargin
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
            .background {
                if kind == .moon {
                    Circle()
                        .fill(Theme.Colors.bg)
                        .frame(width: discSize, height: discSize)
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
    /// terminator and `moonLit`), with the HTML's soft cream glow and edge,
    /// so it can't pass for a moonrise. It's placed, not rotated, so it stays
    /// upright. Rise and set are `moonLit` dots with a faint amber glow.
    @ViewBuilder
    private func targetFace(kind: CompassTarget.Kind, isLocked: Bool) -> some View {
        if kind == .moon, let moonGlyph {
            let glowSize = Self.markSize(kind: kind, isLocked: isLocked) * Self.moonGlowScale
            PhaseGlyph(geometry: moonGlyph, glowCSSBlur: 0)
                .overlay {
                    Circle()
                        .stroke(Theme.Colors.tick.opacity(Self.moonEdgeOpacity), lineWidth: Theme.Metrics.hairline)
                }
                .background {
                    Circle()
                        .fill(Theme.Colors.moonLit.opacity(Self.moonGlowOpacity))
                        .frame(width: glowSize, height: glowSize)
                        .blur(radius: Self.moonGlowBlur)
                }
        } else {
            Circle()
                .fill(Theme.Colors.moonLit)
                .shadow(color: Theme.Colors.accent.opacity(isLocked ? 0 : Self.targetGlowOpacity), radius: Self.targetGlowRadius)
        }
    }

    private static func markSize(kind: CompassTarget.Kind, isLocked: Bool) -> CGFloat {
        switch (kind, isLocked) {
        case (.moon, false): moonMarkerSize
        case (.moon, true): lockedMoonMarkerSize
        case (_, false): targetDotSize
        case (_, true): lockedDotSize
        }
    }

    // MARK: - Geometry

    /// Where something at `azimuth` sits on screen, `distance` from the
    /// dial's centre. Its on-screen angle is the azimuth less the heading.
    private func point(at azimuth: Double, distance: CGFloat) -> CGPoint {
        let angle = Angle.degrees(azimuth - (heading ?? 0)).radians
        return CGPoint(
            x: Self.outerRadius + distance * CGFloat(sin(angle)),
            y: Self.outerRadius - distance * CGFloat(cos(angle))
        )
    }

    /// Along the arc's track from one unwrapped azimuth to another, the way
    /// they say (anticlockwise if `end` is smaller), never the short way.
    private func arcPath(from start: Double, to end: Double) -> Path {
        let sweep = end - start
        let steps = max(Int((abs(sweep) / Self.arcStepDegrees).rounded(.up)), 1)
        var path = Path()
        path.addLines((0...steps).map { step in
            point(at: start + sweep * Double(step) / Double(steps), distance: Self.arcRadius)
        })
        return path
    }

}

// MARK: - Previews

#Preview("Heading 72°, moon up") {
    CompassDial(
        heading: 72,
        targets: [
            CompassTarget(kind: .moonrise, azimuth: 58),
            CompassTarget(kind: .moonset, azimuth: 301),
            CompassTarget(kind: .moon, azimuth: 140),
        ],
        lockedKind: nil,
        moonGlyph: PhaseGlyphGeometry(illumination: 0.64, phaseAngle: 240),
        arc: CompassArc(startAzimuth: 58, endAzimuth: 301, moonAzimuth: 140)
    )
    .padding(40)
    .background(Theme.Colors.bg)
}

#Preview("Moon down, next pass") {
    CompassDial(
        heading: 152,
        targets: [
            CompassTarget(kind: .moonrise, azimuth: 56),
            CompassTarget(kind: .moonset, azimuth: 304),
        ],
        lockedKind: nil,
        arc: CompassArc(startAzimuth: 56, endAzimuth: 304, moonAzimuth: nil)
    )
    .padding(40)
    .background(Theme.Colors.bg)
}

/// Sydney: the moon passes through the north, so the arc runs
/// anticlockwise from moonrise (60°) to moonset (300°, unwrapped to −60°).
#Preview("Southern hemisphere") {
    CompassDial(
        heading: 0,
        targets: [
            CompassTarget(kind: .moonrise, azimuth: 60),
            CompassTarget(kind: .moonset, azimuth: 300),
            CompassTarget(kind: .moon, azimuth: 20),
        ],
        lockedKind: nil,
        moonGlyph: PhaseGlyphGeometry(illumination: 0.64, phaseAngle: 240),
        arc: CompassArc(startAzimuth: 60, endAzimuth: -60, moonAzimuth: 20)
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
        lockedKind: .moonrise,
        arc: CompassArc(startAzimuth: 58, endAzimuth: 301, moonAzimuth: nil)
    )
    .padding(40)
    .background(Theme.Colors.bg)
}

#Preview("No heading") {
    CompassDial(heading: nil, targets: [CompassTarget(kind: .moonset, azimuth: 252)], lockedKind: nil)
        .padding(40)
        .background(Theme.Colors.bg)
}
