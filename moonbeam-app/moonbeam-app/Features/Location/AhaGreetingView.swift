//
//  AhaGreetingView.swift
//  moonbeam-app
//

import SwiftUI

/// "Aha" under the full loader moon after a recovery (LOADER.md §10.4, the
/// handoff's "Found"): the line, and under it the city row, a pin and
/// "City, ST" in `accent`. VoiceOver reads both as one: "Aha, there you
/// are! Irvine, CA".
struct AhaGreetingView: View {

    let greeting: AhaGreeting

    // MARK: - Constants

    /// The handoff: city row 10 pt under the line, pin 6 pt before the city.
    private static let lineToCity: CGFloat = 10
    private static let pinToCity: CGFloat = 6

    /// The handoff's 14 × 17 pin, growing with the city's text.
    @ScaledMetric(relativeTo: .callout) private var pinWidth: CGFloat = 14
    @ScaledMetric(relativeTo: .callout) private var pinHeight: CGFloat = 17

    // MARK: - Body

    var body: some View {
        VStack(spacing: Self.lineToCity) {
            Text(greeting.line)
                .font(Theme.Fonts.ahaLine)
                .foregroundStyle(Theme.Colors.textPrimary)
                .themeLineHeight(Theme.Fonts.ahaLineHeightMultiple)
            HStack(spacing: Self.pinToCity) {
                CityPin()
                    .frame(width: pinWidth, height: pinHeight)
                Text(greeting.city)
                    .font(Theme.Fonts.ahaCity)
                    .foregroundStyle(Theme.Colors.accent)
            }
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(greeting.accessibilityLabel)
    }
}

// MARK: - Pin

/// The handoff's pin: an outlined drop (1.8 pt `accent` stroke on its
/// 16 × 19 artboard) with a filled dot in its head.
private struct CityPin: View {

    /// The SVG's viewBox and its pieces, in its units.
    private static let artboard = CGSize(width: 16, height: 19)
    private static let strokeWidth: CGFloat = 1.8
    private static let dotRadius: CGFloat = 2.2

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / Self.artboard.width, proxy.size.height / Self.artboard.height)
            ZStack {
                DropShape()
                    .stroke(Theme.Colors.accent, lineWidth: Self.strokeWidth * scale)
                Circle()
                    .fill(Theme.Colors.accent)
                    .frame(width: Self.dotRadius * 2 * scale, height: Self.dotRadius * 2 * scale)
                    .position(
                        x: proxy.size.width / 2,
                        y: proxy.size.height * DropShape.headCentreY / Self.artboard.height
                    )
            }
        }
        .accessibilityHidden(true)
    }
}

/// The SVG path `M8 18s6.2-5.6 6.2-10.4A6.2 6.2 0 0 0 1.8 7.6C1.8 12.4 8
/// 18 8 18z`, scaled into the frame.
/// `nonisolated`: `Shape` requires it, and the path is pure geometry.
nonisolated private struct DropShape: Shape {

    static let headCentreY: CGFloat = 7.6
    private static let artboard = CGSize(width: 16, height: 19)
    private static let headRadius: CGFloat = 6.2
    private static let tip = CGPoint(x: 8, y: 18)
    /// The sides' control points sit level with the SVG's handles, so they
    /// leave the head at its widest and taper to the tip.
    private static let sideControlY: CGFloat = 12.4

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width / Self.artboard.width, rect.height / Self.artboard.height)
        let origin = CGPoint(
            x: rect.midX - Self.artboard.width * scale / 2,
            y: rect.midY - Self.artboard.height * scale / 2
        )
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: origin.x + x * scale, y: origin.y + y * scale)
        }
        let centre = Self.artboard.width / 2
        let left = centre - Self.headRadius
        let right = centre + Self.headRadius

        var path = Path()
        path.move(to: point(Self.tip.x, Self.tip.y))
        path.addQuadCurve(to: point(right, Self.headCentreY), control: point(right, Self.sideControlY))
        path.addArc(
            center: point(centre, Self.headCentreY),
            radius: Self.headRadius * scale,
            startAngle: .zero,
            endAngle: .degrees(180),
            clockwise: true
        )
        path.addQuadCurve(to: point(Self.tip.x, Self.tip.y), control: point(left, Self.sideControlY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    AhaGreetingView(greeting: AhaGreeting(line: AhaGreeting.lines[0], city: "Rancho Santa Margarita, CA"))
        .padding()
        .background { ScreenBackground() }
}
