//
//  CompassDial.swift
//  moonbeam-app
//

import SwiftUI

/// A plain rotating dial (COMPASS.md §1): north, east, south and west,
/// degree ticks, a dot for each target, and a fixed indicator at the top.
///
/// Deliberately unstyled; the look is the design pass. For VoiceOver it's one
/// element that reads its targets ("Targets: moonrise, 72 degrees
/// east-northeast; …"). With the target rows gone (4.7) it's the only place
/// VoiceOver hears the live moon's bearing. With no targets it's hidden.
/// Not animated: a turn from 359° to 0° would otherwise spin the long way.
struct CompassDial: View {

    /// Degrees from true north the phone points, or `nil` with no heading.
    let heading: Double?

    let targets: [CompassTarget]
    let lockedKind: CompassTarget.Kind?

    /// `CompassViewModel.targetsAccessibilityLabel`; `nil` hides the dial
    /// from VoiceOver.
    var accessibilityTargets: String? = nil

    // MARK: - Constants

    private static let maxSize: CGFloat = 240
    private static let tickStepDegrees = 30
    private static let fullTurnDegrees = 360
    private static let tickLength: CGFloat = 8
    private static let ringWidth: CGFloat = 2
    private static let lockedRingWidth: CGFloat = 4
    private static let targetDotSize: CGFloat = 12
    private static let lockedDotSize: CGFloat = 18

    /// How far in from the rim the letters and dots sit, as a fraction of
    /// the radius.
    private static let letterInset: CGFloat = 0.72
    private static let dotInset: CGFloat = 0.9

    /// With no heading, the dial is drawn faded and north-up.
    private static let noHeadingOpacity = 0.4

    private static let cardinals: [(label: String, degrees: Double)] = [
        ("N", 0), ("E", 90), ("S", 180), ("W", 270),
    ]

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            let radius = min(proxy.size.width, proxy.size.height) / 2

            ZStack {
                ring
                ticks(radius: radius)
                cardinalLabels(radius: radius)
                targetDots(radius: radius)
            }
            // Turning the phone right turns the dial left, as in Compass.
            .rotationEffect(.degrees(-(heading ?? 0)))
            .opacity(heading == nil ? Self.noHeadingOpacity : 1)
            .overlay(alignment: .top) { indicator }
            .frame(width: radius * 2, height: radius * 2)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: Self.maxSize)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityTargets ?? "")
        .accessibilityHidden(accessibilityTargets == nil)
    }

    // MARK: - Parts

    private var ring: some View {
        Circle()
            .strokeBorder(
                lockedKind == nil ? Color.secondary : Color.accentColor,
                lineWidth: lockedKind == nil ? Self.ringWidth : Self.lockedRingWidth
            )
    }

    private func ticks(radius: CGFloat) -> some View {
        ForEach(Array(stride(from: 0, to: Self.fullTurnDegrees, by: Self.tickStepDegrees)), id: \.self) { degrees in
            Rectangle()
                .fill(.secondary)
                .frame(width: Self.ringWidth, height: Self.tickLength)
                .offset(y: -radius + Self.tickLength / 2)
                .rotationEffect(.degrees(Double(degrees)))
        }
    }

    private func cardinalLabels(radius: CGFloat) -> some View {
        ForEach(Self.cardinals, id: \.label) { cardinal in
            Text(cardinal.label)
                .font(.headline)
                .offset(y: -radius * Self.letterInset)
                .rotationEffect(.degrees(cardinal.degrees))
        }
    }

    private func targetDots(radius: CGFloat) -> some View {
        ForEach(targets, id: \.kind) { target in
            let isLocked = target.kind == lockedKind
            Circle()
                .fill(isLocked ? Color.accentColor : Color.primary)
                .frame(
                    width: isLocked ? Self.lockedDotSize : Self.targetDotSize,
                    height: isLocked ? Self.lockedDotSize : Self.targetDotSize
                )
                .offset(y: -radius * Self.dotInset)
                .rotationEffect(.degrees(target.azimuth))
        }
    }

    /// Fixed at the top, just above the rim: where the phone points. Sized
    /// by a text style so it scales with Dynamic Type.
    private var indicator: some View {
        Image(systemName: "arrowtriangle.down.fill")
            .font(.title3)
            .foregroundStyle(Color.accentColor)
            .alignmentGuide(.top) { $0[.bottom] }
    }
}

#Preview("Heading 74°, locked on moonrise") {
    CompassDial(
        heading: 74,
        targets: [
            CompassTarget(kind: .moonrise, azimuth: 72),
            CompassTarget(kind: .moonset, azimuth: 288),
            CompassTarget(kind: .moon, azimuth: 140),
        ],
        lockedKind: .moonrise
    )
    .padding()
}

#Preview("No heading") {
    CompassDial(heading: nil, targets: [CompassTarget(kind: .moonset, azimuth: 252)], lockedKind: nil)
        .padding()
}
