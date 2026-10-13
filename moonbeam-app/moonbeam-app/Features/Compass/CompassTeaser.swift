//
//  CompassTeaser.swift
//  moonbeam-app
//

import SwiftUI

/// In place of the warning chip when location is off (design handoff,
/// Location Off Teaser, option 1b): a small cartoon compass whose needle
/// hunts for the moon, finds it and glows, with a title and a line saying
/// what turning location on gets you. It shows the feature instead of
/// nagging about the permission.
///
/// The art is six full-canvas layers (`compassTeaser_*` in the illustrations
/// catalog) on one 200-unit canvas shown at 180 pt, so stacking them lines
/// them up. Decorative: the title and body are one VoiceOver element.
///
/// Reduce Motion, the app in the background and the art scrolled out of view
/// all show the settled frame rather than a paused timeline, as
/// `LocationIllustration` does.
struct CompassTeaser: View {

    let title: String
    let message: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    /// On screen: in the hierarchy, and (inside a scroll view) in view.
    @State private var isInHierarchy = false
    @State private var isScrolledIntoView = true

    // MARK: - Constants

    /// The art's size on screen; the canvas it's authored on is 200 units.
    static let artSize: CGFloat = 180
    static let stackSpacing: CGFloat = 10
    static let topPadding: CGFloat = 4
    static let messageMaxWidth: CGFloat = 300

    /// A sliver counts as visible, like the compass's own sensors.
    private static let visibilityThreshold = 0.1

    // MARK: - Body

    var body: some View {
        VStack(spacing: Self.stackSpacing) {
            art
            Text(title)
                .font(Theme.Fonts.teaserTitle)
                .foregroundStyle(Theme.Colors.textPrimary)
                .themeLineHeight(Theme.Fonts.teaserTitleLineHeightMultiple)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(message)
                .font(Theme.Fonts.teaserBody)
                .foregroundStyle(Theme.Colors.teaserBody)
                .themeLineHeight(Theme.Fonts.teaserBodyLineHeightMultiple)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: Self.messageMaxWidth)
        }
        .padding(.top, Self.topPadding)
        .accessibilityElement(children: .combine)
        .onAppear { isInHierarchy = true }
        .onDisappear { isInHierarchy = false }
    }

    @ViewBuilder
    private var art: some View {
        Group {
            if Self.shouldAnimate(
                reduceMotion: reduceMotion,
                scenePhase: scenePhase,
                isVisible: isInHierarchy && isScrolledIntoView
            ) {
                CompassTeaserTimeline()
            } else {
                CompassTeaserArt(frame: CompassTeaserMotion.settled)
            }
        }
        .onScrollVisibilityChange(threshold: Self.visibilityThreshold) { isScrolledIntoView = $0 }
    }

    /// A timeline exists only while motion is allowed and the art can be
    /// seen. Returning false selects the settled art, not a paused timeline.
    nonisolated static func shouldAnimate(
        reduceMotion: Bool,
        scenePhase: ScenePhase,
        isVisible: Bool
    ) -> Bool {
        !reduceMotion && scenePhase == .active && isVisible
    }
}

// MARK: - Timeline

/// Runs the loop from its start each time it appears, so the hunt always
/// begins at the top of the table (a resume after the background included).
private struct CompassTeaserTimeline: View {

    @State private var start = Date()

    var body: some View {
        TimelineView(.animation) { context in
            CompassTeaserArt(
                frame: CompassTeaserMotion.frame(at: context.date.timeIntervalSince(start))
            )
        }
    }
}

// MARK: - Art

/// One frame of the art: the six layers, back to front.
private struct CompassTeaserArt: View {

    let frame: CompassTeaserMotion.Frame

    // MARK: - Constants

    /// The canvas the layers are authored on.
    private static let canvas = 200.0
    /// The hub, which the needle turns about: (100, 104), not the centre.
    private static let needleAnchor = UnitPoint(x: 100 / canvas, y: 104 / canvas)
    /// The moon, which the glow grows about: (181, 61).
    private static let moonAnchor = UnitPoint(x: 181 / canvas, y: 61 / canvas)

    // MARK: - Body

    var body: some View {
        ZStack {
            layer("glow")
            layer("body")
            layer("moonGlow")
                .scaleEffect(frame.glowRadius / CompassTeaserMotion.glowAssetRadius, anchor: Self.moonAnchor)
                .opacity(frame.glowOpacity)
            layer("moon")
            layer("needle")
                .rotationEffect(.degrees(frame.needleDegrees), anchor: Self.needleAnchor)
            layer("hub")
        }
        .frame(width: CompassTeaser.artSize, height: CompassTeaser.artSize)
        .accessibilityHidden(true)
    }

    private func layer(_ name: String) -> some View {
        Image("compassTeaser_\(name)").resizable()
    }
}

// MARK: - Previews

#Preview("Teaser") {
    ScrollView {
        CompassTeaser(
            title: CompassViewModel.locationOffTeaserTitle,
            message: CompassViewModel.locationOffTeaserBody
        )
        .padding()
    }
    .background { ScreenBackground() }
}
