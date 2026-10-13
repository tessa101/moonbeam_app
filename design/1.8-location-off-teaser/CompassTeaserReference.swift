// Reference sketch for option 1b: adapt it to the app's patterns. Geometry is in a 200pt space, scaled to 180pt.
import SwiftUI

struct CompassTeaser: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    // (time s, needle deg, glow opacity, glow radius)
    private let keys: [(Double, Double, Double, Double)] = [
        (0, -30, 0.12, 13), (0.75, 40, 0.12, 13), (1.5, -12, 0.12, 13), (2.25, 78, 0.12, 13),
        (2.75, 56, 0.35, 16), (3.1, 62, 0.55, 19), (4.5, 62, 0.55, 17), (5.0, -30, 0.12, 13)
    ]

    var body: some View {
        VStack(spacing: 10) {
            TimelineView(.animation(paused: reduceMotion)) { ctx in
                let f = reduceMotion ? (62.0, 0.55, 19.0) : frame(ctx.date.timeIntervalSince(start).truncatingRemainder(dividingBy: 5))
                Canvas { c, _ in draw(c, needle: f.0, glowOp: f.1, glowR: f.2) }
                    .frame(width: 200, height: 200)
                    .scaleEffect(0.9)
                    .frame(width: 180, height: 180)
            }
            Text("Point your phone at the moon")
                .font(.custom("YoungSerif-Regular", size: 20))
                .foregroundStyle(Color(hex: 0xF5EADB))
            Text("With location on, this becomes a live compass that turns you toward it.")
                .font(.custom("NunitoSans-Regular", size: 15))
                .foregroundStyle(Color(hex: 0xB9A898))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
    }

    private func ease(_ t: Double) -> Double { // cubic-bezier(.45,0,.55,1) is close to smoothstep
        t * t * (3 - 2 * t)
    }

    private func frame(_ t: Double) -> (Double, Double, Double) {
        for i in 0..<(keys.count - 1) where t <= keys[i + 1].0 {
            let a = keys[i], b = keys[i + 1]
            let p = ease((t - a.0) / (b.0 - a.0))
            return (a.1 + (b.1 - a.1) * p, a.2 + (b.2 - a.2) * p, a.3 + (b.3 - a.3) * p)
        }
        return (keys[0].1, keys[0].2, keys[0].3)
    }

    private func circle(_ x: Double, _ y: Double, _ r: Double) -> Path {
        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }

    private func draw(_ c: GraphicsContext, needle: Double, glowOp: Double, glowR: Double) {
        let cx = 100.0, cy = 104.0
        c.fill(circle(cx, cy, 98), with: .radialGradient(
            Gradient(colors: [Color(hex: 0xF2C27B).opacity(0.28), Color(hex: 0xF2C27B).opacity(0)]),
            center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: 98))
        c.stroke(circle(100, 21, 10), with: .color(Color(hex: 0xE9D3A6)), lineWidth: 5)
        c.fill(circle(cx, cy, 76), with: .color(Color(hex: 0xF7E7BD)))
        c.stroke(circle(cx, cy, 76), with: .color(Color(hex: 0xC99A5B)), lineWidth: 3)
        c.fill(circle(cx, cy, 62), with: .color(Color(hex: 0x241B21)))

        var ticks = Path()
        ticks.move(to: .init(x: 156, y: cy)); ticks.addLine(to: .init(x: 148, y: cy))
        ticks.move(to: .init(x: 100, y: 160)); ticks.addLine(to: .init(x: 100, y: 152))
        ticks.move(to: .init(x: 44, y: cy)); ticks.addLine(to: .init(x: 52, y: cy))
        c.stroke(ticks, with: .color(Color(hex: 0x6E5C66)), style: .init(lineWidth: 3, lineCap: .round))
        var n = Path(); n.move(to: .init(x: 100, y: 48)); n.addLine(to: .init(x: 100, y: 56))
        c.stroke(n, with: .color(Color(hex: 0xF2C27B)), style: .init(lineWidth: 3, lineCap: .round))

        c.fill(circle(181, 61, glowR), with: .color(Color(hex: 0xF2C27B).opacity(glowOp)))
        c.fill(circle(181, 61, 8), with: .color(Color(hex: 0xF7E7BD)))
        c.fill(circle(185, 58, 7), with: .color(Color(hex: 0x1B1519))) // crescent shadow = screen bg

        var g = c
        g.translateBy(x: cx, y: cy); g.rotate(by: .degrees(needle)); g.translateBy(x: -cx, y: -cy)
        var north = Path(); north.addLines([.init(x: 100, y: 58), .init(x: 108, y: 104), .init(x: 92, y: 104)]); north.closeSubpath()
        var south = Path(); south.addLines([.init(x: 100, y: 150), .init(x: 108, y: 104), .init(x: 92, y: 104)]); south.closeSubpath()
        g.fill(north, with: .color(Color(hex: 0xF2C27B)))
        g.fill(south, with: .color(Color(hex: 0x6E5C66)))

        c.fill(circle(cx, cy, 7), with: .color(Color(hex: 0xF7E7BD)))
        c.fill(circle(cx, cy, 2.5), with: .color(Color(hex: 0x241B21)))
    }
}
// Assumes the app's existing Color(hex:) helper.
