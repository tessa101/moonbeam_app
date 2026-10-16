// Moon Signal — searching moon (polished). Reference implementation; adapt to the app's conventions.
// Prototype: "Moon Loader Polish.dc.html" (4b terminator · 4c sliding shadow · 4d light wash).
import SwiftUI

enum MoonStyle { case terminator /*4b*/, slidingShadow /*4c*/, lightWash /*4d*/ }

enum MoonPalette {
    static let lit = Color(red: 0xF2/255, green: 0xE6/255, blue: 0xCF/255)
    static let earthshine = Color(red: 0x2A/255, green: 0x21/255, blue: 0x27/255)
    static let accent = Color(red: 0xF2/255, green: 0xC2/255, blue: 0x7B/255)
}

enum MoonTiming {
    static let cycle: Double = 4.8          // s
    static let sweep: Double = 2.2          // new→full and full→new
    static let fullHold: Double = 0.4       // pause at full
    static let easeAmount: Double = 0.85    // 0 = linear, 1 = full stop at ends
    static let stopSpeedup: Double = 2.6
    static let holdLit: Double = 0.85       // waxing gibbous where the loader freezes
    static let pulsePeriod: Double = 1.8

    /// Ease-in-out per sweep: q − a·sin(2πq)/2π
    static func ease(_ q: Double) -> Double { q - easeAmount * sin(2 * .pi * q) / (2 * .pi) }

    /// Cycle progress p ∈ [0,1) → phase f ∈ [0,1): 0 new, 0.5 full.
    static func phase(_ p: Double) -> Double {
        let s = p * cycle
        if s < sweep { return ease(s / sweep) / 2 }
        if s < sweep + fullHold { return 0.5 }
        return 0.5 + ease((s - sweep - fullHold) / sweep) / 2
    }
}

enum MoonGeometry {
    /// Lit fraction 0…1 for a given style and phase.
    static func lit(_ style: MoonStyle, _ f: Double) -> Double {
        switch style {
        case .terminator: return (1 - cos(2 * .pi * f)) / 2
        case .slidingShadow:
            let d = min(abs(shadowOffset(f)), 2)          // in radii
            let overlap = 2 * acos(d / 2) - (d / 2) * sqrt(4 - d * d)
            return 1 - overlap / .pi
        case .lightWash:
            let t = max(-1, min(1, washEdge(f)))
            let right = (acos(t) - t * sqrt(1 - t * t)) / .pi
            return f < 0.5 ? right : 1 - right
        }
    }
    /// Sliding shadow centre offset, in radii (negative = left). Waxes from the right.
    static func shadowOffset(_ f: Double) -> Double { f < 0.5 ? -2.06 * (2 * f) : 2.06 * (2 - 2 * f) }
    /// Light-wash edge position, in radii from centre (+1 = right limb).
    static func washEdge(_ f: Double) -> Double {
        let g = f < 0.5 ? f * 2 : (f - 0.5) * 2
        return (156 - 180 * g - 66) / 66
    }
    static let washFeather: Double = 22.0 / 66.0          // half-width of the soft edge, in radii

    /// Terminator outline (4b). θ = 2πf. Lit on the right while waxing.
    static func terminatorPath(f: Double, in rect: CGRect, samples: Int = 48) -> Path {
        let r = rect.width / 2, c = CGPoint(x: rect.midX, y: rect.midY)
        let th = 2 * Double.pi * f, waxing = f < 0.5, side: Double = waxing ? 1 : -1
        var p = Path()
        for i in 0...samples {                              // limb, top → bottom
            let t = Double(i) / Double(samples) * .pi
            let pt = CGPoint(x: c.x + side * r * sin(t), y: c.y - r * cos(t))
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        for i in 0...samples {                              // terminator, bottom → top
            let t = Double(i) / Double(samples) * .pi
            p.addLine(to: CGPoint(x: c.x + side * r * cos(th) * sin(t), y: c.y + r * cos(t)))
        }
        p.closeSubpath()
        return p
    }
}

/// Drives progress. `stopping` runs forward to the hold phase, then freezes (and the halo pulses).
@Observable final class MoonClock {
    var p: Double = 0.05
    var stopping = false
    private(set) var frozen = false
    private(set) var pulse: Double = 0
    var onFrozen: (() -> Void)?
    let style: MoonStyle
    private let holdP: Double
    private var last: Date?

    init(style: MoonStyle) {
        self.style = style
        var lo = 0.0, hi = 0.5
        for _ in 0..<30 { let m = (lo + hi) / 2; MoonGeometry.lit(style, m) < MoonTiming.holdLit ? (lo = m) : (hi = m) }
        let fh = lo; lo = 0; hi = MoonTiming.sweep / MoonTiming.cycle
        for _ in 0..<30 { let m = (lo + hi) / 2; MoonTiming.phase(m) < fh ? (lo = m) : (hi = m) }
        holdP = lo
    }

    func tick(_ now: Date) {
        let dt = min(0.05, now.timeIntervalSince(last ?? now)); last = now
        if !stopping { frozen = false; pulse = 0; p = (p + dt / MoonTiming.cycle).truncatingRemainder(dividingBy: 1); return }
        let d = (holdP - p + 1).truncatingRemainder(dividingBy: 1)
        if d > 0.002 && d < 0.998 { p = (p + min(d, dt * MoonTiming.stopSpeedup / MoonTiming.cycle)).truncatingRemainder(dividingBy: 1) }
        else {
            if !frozen { frozen = true; onFrozen?(); onFrozen = nil }
            pulse += dt / MoonTiming.pulsePeriod
        }
    }
    var phase: Double { MoonTiming.phase(p) }
}

struct SearchingMoon: View {
    var clock: MoonClock
    var diameter: CGFloat = 132

    var body: some View {
        TimelineView(.animation) { ctx in
            let _ = clock.tick(ctx.date)
            let f = clock.phase, k = MoonGeometry.lit(clock.style, f)
            let pw = clock.frozen ? 0.7 + 0.3 * sin(2 * .pi * clock.pulse) : 1
            let ps = clock.frozen ? 1 + 0.06 * sin(2 * .pi * clock.pulse) : 1
            ZStack {
                // Halo: 2.2× diameter, tracks lit fraction.
                Circle()
                    .fill(RadialGradient(colors: [MoonPalette.accent.opacity(0.34), MoonPalette.accent.opacity(0)],
                                         center: .center, startRadius: 0, endRadius: diameter * 1.1))
                    .frame(width: diameter * 2.2, height: diameter * 2.2)
                    .scaleEffect((0.94 + 0.1 * k) * ps)
                    .opacity((0.12 + 0.88 * k) * pw)
                Canvas { g, size in draw(&g, size, f) }
                    .frame(width: diameter, height: diameter)
                    .shadow(color: MoonPalette.accent.opacity(0.35 * k), radius: 20)
            }
            .accessibilityHidden(true)
        }
    }

    private func draw(_ g: inout GraphicsContext, _ size: CGSize, _ f: Double) {
        let rect = CGRect(origin: .zero, size: size), disc = Path(ellipseIn: rect), r = size.width / 2
        g.clip(to: disc)
        switch clock.style {
        case .terminator:
            g.fill(disc, with: .color(MoonPalette.earthshine))
            g.drawLayer { l in
                l.addFilter(.blur(radius: 0.8))
                l.fill(MoonGeometry.terminatorPath(f: f, in: rect), with: .color(MoonPalette.lit))
            }
        case .slidingShadow:
            g.fill(disc, with: .color(MoonPalette.lit))
            let dx = MoonGeometry.shadowOffset(f) * r
            g.drawLayer { l in
                l.addFilter(.blur(radius: 1.2))
                l.fill(Path(ellipseIn: rect.insetBy(dx: -1, dy: -1).offsetBy(dx: dx, dy: 0)), with: .color(MoonPalette.earthshine))
            }
        case .lightWash:
            g.fill(disc, with: .color(MoonPalette.earthshine))
            let e = MoonGeometry.washEdge(f), w = MoonGeometry.washFeather
            let x1 = r + (f < 0.5 ? e - w : e + w) * r, x2 = r + (f < 0.5 ? e + w : e - w) * r
            g.fill(disc, with: .linearGradient(Gradient(colors: [MoonPalette.lit.opacity(0), MoonPalette.lit]),
                                               startPoint: CGPoint(x: x1, y: r), endPoint: CGPoint(x: x2, y: r)))
        }
    }
}

// Reduce Motion: render a static moon at the hold phase, no halo pulse:
//   @Environment(\.accessibilityReduceMotion) var reduceMotion
//   if reduceMotion { clock.stopping = true } and skip the pulse terms.
