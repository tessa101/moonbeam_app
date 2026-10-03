//
//  CompassDial.swift
//  moonbeam-app
//

import SwiftUI

/// The compass dial (DESIGN-1.1.md §3.3, §3.3a, COMPASS-1.1.md §4, §9.3,
/// COMPASS.md §1): a lit face with tick lines every 2° (longer every 10° and
/// 30°), degree numbers every 30°, N/E/S/W in Young Serif and a fixed
/// crosshair; just outside the rim, the moon arc, the moon's pass from rise
/// to set, with `moonLit` dots at moonrise and moonset and the live Moon as
/// a phase glyph riding on it (pulsing until the first lock), their labels
/// beyond; and a short fixed needle at 12 o'clock from just above the arc to
/// the inner end of the heavy ticks. Locked, the target's mark grows and
/// glows and the dial gets a soft amber halo; locked on the Moon, the glyph
/// sits at 12 o'clock over the needle's top.
///
/// Sized by `faceDiameter` (5.4.6b: as big as the screen's width allows,
/// `faceDiameter(forWidth:)`); ticks, numbers' and letters' distances,
/// letters and crosshair scale with it from the 196 pt dial they were drawn
/// for. The marks and the degree numbers' size don't.
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

    /// The face's diameter; see `faceDiameter(forWidth:)`.
    let faceDiameter: CGFloat

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

    // MARK: - Size (COMPASS-1.1.md §9.3)

    /// The dial the tick, number, letter and crosshair geometry below was
    /// drawn for (§3.3a); a bigger face scales it by `scale`.
    static let designDiameter: CGFloat = 196
    /// §9.3's target; the screen's width caps it first on today's phones.
    static let maxFaceDiameter: CGFloat = 300
    static let minFaceDiameter = designDiameter
    /// "↑ Rise", the widest label, at 12 pt bold, rounded up.
    private static let widestLabelWidth: CGFloat = 38

    /// The biggest face whose labels at 3 and 9 o'clock still end inside
    /// the screen: they may reach into the screen's side margin, not past
    /// it. 260 pt on a 402 pt phone, 233 pt on a 375 pt one.
    ///
    /// - Parameter width: the compass block's width (screen less margins).
    static func faceDiameter(forWidth width: CGFloat) -> CGFloat {
        let sideReach = arcGap + targetDotSize / 2 + CompassTargetLabels.labelGap + widestLabelWidth
            - Theme.Metrics.screenMargin
        return min(max(width - 2 * sideReach, minFaceDiameter), maxFaceDiameter)
    }

    private var radius: CGFloat { faceDiameter / 2 }
    private var scale: CGFloat { faceDiameter / Self.designDiameter }
    private var arcRadius: CGFloat { radius + Self.arcGap }

    /// The view's frame: as wide as the arc and the Moon's disc on it (the
    /// side labels may overhang, into the screen margin), and as tall as
    /// that plus a label's room above and below the arc, so a label near 12
    /// or 6 o'clock never runs into the readout or what's below.
    private var frameSize: CGSize {
        let sideReach = arcRadius + Self.moonMarkerSize / 2 + Self.moonDiscMargin
        let verticalReach = arcRadius + Self.labelRoom
        return CGSize(width: sideReach * 2, height: verticalReach * 2)
    }

    private var centre: CGPoint {
        CGPoint(x: frameSize.width / 2, y: frameSize.height / 2)
    }

    // MARK: - Constants (§3.3, §3.3a, measured from the HTML)

    private static let fullTurnDegrees = 360
    private static let cardinalStepDegrees = 90

    /// Ticks (COMPASS-1.1.md §4, the HTML's 104 pt dial scaled to 98 pt):
    /// every 2° minor, every 10° mid, every 30° heavy, from just inside the
    /// rim inwards. Minor ticks are under 3:1 and decorative; mid and heavy
    /// carry the reading. Lengths scale with the dial, widths don't.
    private static let minorTickStepDegrees = 2
    private static let midTickStepDegrees = 10
    private static let heavyTickStepDegrees = 30
    private static let tickOuterInset: CGFloat = 1
    private static let minorTick = (length: CGFloat(7), width: CGFloat(1))
    private static let midTick = (length: CGFloat(11), width: CGFloat(1.4))
    private static let heavyTick = (length: CGFloat(15), width: CGFloat(2.2))

    /// Degree numbers every 30° except on the cardinals, this far from the
    /// centre; cardinals at `letterCentreDistance` (both on the 196 pt dial).
    private static let numberCentreDistance: CGFloat = 72
    private static let letterCentreDistance: CGFloat = 58
    /// Target labels ("↑ Rise", "↓ Set", "Now", COMPASS-1.1.md §5, §9.3):
    /// `CompassTargetLabels.labelGap` from their mark, with a `bg` halo so
    /// they read over the dots.
    private static let labelHaloRadius: CGFloat = 1.5
    /// A 12 pt label's line, rounded up.
    private static let labelLineHeight: CGFloat = 16
    /// Room beyond the arc's track, above and below, for a label over the
    /// Moon (the biggest unlocked mark).
    private static let labelRoom = moonMarkerSize / 2 + CompassTargetLabels.labelGap + labelLineHeight

    /// The Moon's pulse (§5): a 2 pt `accent` ring growing from 10 to 24 pt
    /// radius as it fades from 80%, every 1.8 s. Reduce Motion: a still ring
    /// halfway out.
    private static let pulseStartRadius: CGFloat = 10
    private static let pulseEndRadius: CGFloat = 24
    private static let pulseStaticRadius: CGFloat = 17
    private static let pulseLineWidth: CGFloat = 2
    private static let pulseStartOpacity = 0.8
    private static let pulseDuration = 1.8

    /// The fixed crosshair: ±28 pt on the 196 pt dial, 1 pt, with a 2 pt
    /// centre dot.
    private static let crosshairReach: CGFloat = 28
    private static let crosshairDotSize: CGFloat = 2

    /// The arc's track: this far outside the rim, at any dial size.
    private static let arcGap: CGFloat = 16
    /// Still to come: 3 pt round dots about 6.6 pt apart, `accent` 95%.
    private static let arcDotSize: CGFloat = 3
    private static let arcDotSpacing: CGFloat = 6.6
    /// A dash just long enough to draw its round caps: a dot.
    private static let arcDotDash: CGFloat = 0.01
    private static let arcRemainingOpacity = 0.95
    /// Already travelled, at 30%: a solid hairline while locked, dots
    /// otherwise (COMPASS-1.1.md §9.3, as the mock).
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

    /// The needle (COMPASS-1.1.md §9.10): a 3 pt round-capped line from this
    /// far above the arc's track to the inner end of the heavy ticks. It
    /// only has to point at the degree.
    private static let needleWidth: CGFloat = 3
    private static let needleOverArc: CGFloat = 6

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

    private var marksOpacity: Double {
        heading == nil ? Self.noHeadingOpacity : 1
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            halo
            face
            crosshair
            dialMarks
                .opacity(marksOpacity)
            // Under the targets, so a mark at 12 o'clock (the Moon, locked)
            // sits over the needle's top.
            needle
            targetMarks
                .opacity(marksOpacity)
        }
        .frame(width: frameSize.width, height: frameSize.height)
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
                    endRadius: faceDiameter * Self.faceGradientReach
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
            .frame(width: faceDiameter, height: faceDiameter)
    }

    /// Only while locked (§3.3): the whole dial sits in a soft amber glow.
    /// Unchanged by the arc (§3.3a leaves its tone against the amber arc
    /// open).
    @ViewBuilder
    private var halo: some View {
        if lockedKind != nil {
            let reach = radius + Self.haloOverhang
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

    /// Fixed at 12 o'clock: where the phone points. From just above the
    /// arc's track, across it, to the inner end of the heavy ticks; amber
    /// while locked.
    private var needle: some View {
        let top = arcRadius + Self.needleOverArc
        let bottom = radius - Self.tickOuterInset - Self.heavyTick.length * scale
        return Path { path in
            path.move(to: CGPoint(x: centre.x, y: centre.y - top))
            path.addLine(to: CGPoint(x: centre.x, y: centre.y - bottom))
        }
        .stroke(
            lockedKind == nil ? Theme.Colors.textPrimary : Theme.Colors.accent,
            style: StrokeStyle(lineWidth: Self.needleWidth, lineCap: .round)
        )
        .frame(width: frameSize.width, height: frameSize.height)
        .accessibilityHidden(true)
    }

    /// Fixed, under the turning marks; decorative.
    private var crosshair: some View {
        let reach = Self.crosshairReach * scale
        return ZStack {
            Path { path in
                path.move(to: CGPoint(x: centre.x - reach, y: centre.y))
                path.addLine(to: CGPoint(x: centre.x + reach, y: centre.y))
                path.move(to: CGPoint(x: centre.x, y: centre.y - reach))
                path.addLine(to: CGPoint(x: centre.x, y: centre.y + reach))
            }
            .stroke(Theme.Colors.faint, lineWidth: Theme.Metrics.hairline)
            Circle()
                .fill(Theme.Colors.tick)
                .frame(width: Self.crosshairDotSize, height: Self.crosshairDotSize)
                .position(centre)
        }
        .frame(width: frameSize.width, height: frameSize.height)
        .accessibilityHidden(true)
    }

    // MARK: - Marks

    /// What's printed on the dial and the arc: everything that turns but
    /// the targets.
    private var dialMarks: some View {
        ZStack {
            ticks
            numbers
            letters
            arcTrack
        }
        .frame(width: frameSize.width, height: frameSize.height)
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
    /// inwards by `length` (on the 196 pt dial).
    private func tickPath(where include: (Int) -> Bool, length: CGFloat) -> Path {
        let outer = radius - Self.tickOuterInset
        var path = Path()
        for degrees in stride(from: 0, to: Self.fullTurnDegrees, by: Self.minorTickStepDegrees) where include(degrees) {
            path.move(to: point(at: Double(degrees), distance: outer))
            path.addLine(to: point(at: Double(degrees), distance: outer - length * scale))
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
                .position(point(at: Double(degrees), distance: Self.numberCentreDistance * scale))
        }
        .accessibilityHidden(true)
    }

    /// Young Serif; N in amber, the rest in `textPrimary`, always upright.
    private var letters: some View {
        ForEach(Self.cardinals, id: \.label) { cardinal in
            Text(cardinal.label)
                .font(Theme.Fonts.dialLetter(size: letterSize, dialScale: scale))
                .foregroundStyle(cardinal.degrees == 0 ? Theme.Colors.accent : Theme.Colors.textPrimary)
                .position(point(at: cardinal.degrees, distance: Self.letterCentreDistance * scale))
        }
    }

    /// The pass (§3.3a, option B; §9.3). Moon up: from moonrise to the Moon
    /// faint (a solid hairline while locked, dots otherwise), dots from the
    /// Moon to moonset. Moon down: the next pass, all dots, dimmed.
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
                let travelled = arcPath(from: arc.startAzimuth, to: seam)
                let travelledColor = Theme.Colors.accent.opacity(Self.arcTravelledOpacity)
                if lockedKind != nil {
                    travelled.stroke(
                        travelledColor,
                        style: StrokeStyle(lineWidth: Self.arcTravelledWidth, lineCap: .round)
                    )
                } else {
                    travelled.stroke(travelledColor, style: dotted)
                }
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
        return ZStack {
            ForEach(targets, id: \.kind) { target in
                let isLocked = target.kind == lockedKind
                let size = Self.markSize(kind: target.kind, isLocked: isLocked)
                let position = point(at: displayAzimuth(of: target), distance: arcRadius)
                if target.kind == .moon, showsMoonPulse {
                    MoonPulse(reduceMotion: reduceMotion)
                        .position(position)
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
                    .position(position)
            }
            ArcLabelLayout(trackRadius: arcRadius) {
                ForEach(targets.filter { labels[$0.kind] != nil }, id: \.kind) { target in
                    Text(labels[target.kind] ?? "")
                        .font(Theme.Fonts.dialTargetLabel)
                        .foregroundStyle(Theme.Colors.textBody)
                        .fixedSize()
                        .shadow(color: Theme.Colors.bg, radius: Self.labelHaloRadius)
                        .shadow(color: Theme.Colors.bg, radius: Self.labelHaloRadius)
                        .layoutValue(key: ArcLabelLayout.LabelAngle.self, value: screenAngle(of: target.azimuth))
                        .layoutValue(
                            key: ArcLabelLayout.MarkRadius.self,
                            value: Self.markSize(kind: target.kind, isLocked: false) / 2
                        )
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(width: frameSize.width, height: frameSize.height)
    }

    /// Where a target is drawn: its azimuth, except the Moon while locked,
    /// which sits at 12 o'clock over the needle (§9.3), within the lock's
    /// few degrees of where it really is.
    private func displayAzimuth(of target: CompassTarget) -> Double {
        if target.kind == .moon, lockedKind == .moon, let heading {
            return heading
        }
        return target.azimuth
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

    /// On screen, clockwise from 12 o'clock: the azimuth less the heading.
    private func screenAngle(of azimuth: Double) -> Double {
        azimuth - (heading ?? 0)
    }

    /// Where something at `azimuth` sits on screen, `distance` from the
    /// dial's centre.
    private func point(at azimuth: Double, distance: CGFloat) -> CGPoint {
        let angle = Angle.degrees(screenAngle(of: azimuth)).radians
        return CGPoint(
            x: centre.x + distance * CGFloat(sin(angle)),
            y: centre.y - distance * CGFloat(cos(angle))
        )
    }

    /// Along the arc's track from one unwrapped azimuth to another, the way
    /// they say (anticlockwise if `end` is smaller), never the short way.
    private func arcPath(from start: Double, to end: Double) -> Path {
        let sweep = end - start
        let steps = max(Int((abs(sweep) / Self.arcStepDegrees).rounded(.up)), 1)
        var path = Path()
        path.addLines((0...steps).map { step in
            point(at: start + sweep * Double(step) / Double(steps), distance: arcRadius)
        })
        return path
    }
}

// MARK: - Label layout (COMPASS-1.1.md §9.3)

/// Places the target labels round the arc, each out along the radius
/// through its mark by `CompassTargetLabels.centreDistance`, which needs
/// the label's measured size: the same gap to the mark at any angle.
private struct ArcLabelLayout: Layout {

    /// A label's on-screen angle, clockwise from 12 o'clock.
    struct LabelAngle: LayoutValueKey {
        static let defaultValue = 0.0
    }

    /// Its mark's radius.
    struct MarkRadius: LayoutValueKey {
        static let defaultValue: CGFloat = 0
    }

    let trackRadius: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let angle = subview[LabelAngle.self]
            let distance = CompassTargetLabels.centreDistance(
                trackRadius: trackRadius,
                markRadius: subview[MarkRadius.self],
                labelSize: size,
                angle: angle
            )
            let radians = angle * .pi / 180
            let point = CGPoint(
                x: bounds.midX + distance * CGFloat(sin(radians)),
                y: bounds.midY - distance * CGFloat(cos(radians))
            )
            subview.place(at: point, anchor: .center, proposal: ProposedViewSize(size))
        }
    }
}

// MARK: - Previews

/// A 402 pt phone's compass block: the screen less its 20 pt margins.
private let previewWidth: CGFloat = 362

#Preview("Heading 72°, moon up") {
    CompassDial(
        faceDiameter: CompassDial.faceDiameter(forWidth: previewWidth),
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
    .padding(.vertical, 40)
    .background(Theme.Colors.bg)
}

#Preview("Moon down, next pass") {
    CompassDial(
        faceDiameter: CompassDial.faceDiameter(forWidth: previewWidth),
        heading: 152,
        targets: [
            CompassTarget(kind: .moonrise, azimuth: 56),
            CompassTarget(kind: .moonset, azimuth: 304),
        ],
        lockedKind: nil,
        arc: CompassArc(startAzimuth: 56, endAzimuth: 304, moonAzimuth: nil)
    )
    .padding(.vertical, 40)
    .background(Theme.Colors.bg)
}

/// Sydney: the moon passes through the north, so the arc runs
/// anticlockwise from moonrise (60°) to moonset (300°, unwrapped to −60°).
#Preview("Southern hemisphere") {
    CompassDial(
        faceDiameter: CompassDial.faceDiameter(forWidth: previewWidth),
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
    .padding(.vertical, 40)
    .background(Theme.Colors.bg)
}

#Preview("Locked on moonrise") {
    CompassDial(
        faceDiameter: CompassDial.faceDiameter(forWidth: previewWidth),
        heading: 58,
        targets: [
            CompassTarget(kind: .moonrise, azimuth: 58),
            CompassTarget(kind: .moonset, azimuth: 301),
        ],
        lockedKind: .moonrise,
        arc: CompassArc(startAzimuth: 58, endAzimuth: 301, moonAzimuth: nil)
    )
    .padding(.vertical, 40)
    .background(Theme.Colors.bg)
}

#Preview("No heading") {
    CompassDial(faceDiameter: CompassDial.faceDiameter(forWidth: previewWidth), heading: nil, targets: [CompassTarget(kind: .moonset, azimuth: 252)], lockedKind: nil)
        .padding(.vertical, 40)
        .background(Theme.Colors.bg)
}
