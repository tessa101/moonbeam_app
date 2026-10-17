//
//  StatusBarScrim.swift
//  moonbeam-app
//

import SwiftUI

/// A fade from the screen's background to clear across the top of a
/// scrolling screen, so content scrolling up under the status bar doesn't
/// collide with the time and icons (STEP-5.15).
///
/// Apply it to a `ScrollView` (or a view wrapping one): it reads that
/// scroll view's offset, and covers the top safe area plus a little more.
/// It's invisible at the top of the scroll and ramps in over the first
/// `rampDistance` points, so it never pops. It never takes touches.
///
/// No motion of its own: it only changes opacity, so Reduce Motion needs no
/// special case. A jump bigger than the whole ramp (a programmatic scroll,
/// content reset) cross-fades with the screen's load-in timing rather than
/// cutting.
struct StatusBarScrim: ViewModifier {

    // MARK: - Constants (STEP-5.15 spec)

    /// How far below the top safe area the fade reaches.
    nonisolated static let extraHeight: CGFloat = 24
    /// The scroll distance over which the scrim goes from clear to full.
    /// `nonisolated` so the ramp's pure functions (and tests) can read it.
    nonisolated static let rampDistance: CGFloat = 40

    /// The scrim's opacity for a scroll offset measured from the resting
    /// top: 0 at rest (or overscrolled), 1 from `rampDistance` on.
    nonisolated static func opacity(forOffset offset: CGFloat) -> Double {
        Double(min(max(offset / rampDistance, 0), 1))
    }

    /// Whether moving between two offsets is a jump rather than a scroll,
    /// so the opacity should cross-fade instead of tracking.
    nonisolated static func isJump(from old: CGFloat, to new: CGFloat) -> Bool {
        abs(new - old) > rampDistance
    }

    // MARK: - State

    @State private var opacity: Double = 0
    @State private var topInset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                // From the resting top, whatever insets the scroll view has.
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { old, new in
                let target = Self.opacity(forOffset: new)
                if Self.isJump(from: old, to: new) {
                    withAnimation(.easeOut(duration: ContentLoadIn.duration)) { opacity = target }
                } else {
                    opacity = target
                }
            }
            .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.top } action: { inset in
                topInset = inset
            }
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [Theme.Colors.bg, Theme.Colors.bg.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: topInset + Self.extraHeight)
                // A full-height container, so ignoring the safe area pins
                // the gradient to the screen's top edge.
                .frame(maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea(edges: .top)
                .opacity(opacity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
    }
}

extension View {
    /// Fades the top of this scrolling view under the status bar (STEP-5.15).
    func statusBarScrim() -> some View {
        modifier(StatusBarScrim())
    }
}
