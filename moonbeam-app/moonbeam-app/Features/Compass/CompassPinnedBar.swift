//
//  CompassPinnedBar.swift
//  moonbeam-app
//

import SwiftUI

/// The glass bar pinned near the bottom while the dial's centre is below the
/// fold (COMPASS-1.1.md §9.6, DESIGN-1.1.md §4.1): the live heading on the
/// left, **Compass ↓** on the right, which scrolls to the dial. On lock it
/// turns amber and reads the lock text ("Moonrise · 58° ENE"), so the lock
/// can't be missed. `LocationScreen` decides where it sits (above the bottom
/// note, if there is one) and when it shows (`showsPinnedBar`).
struct CompassPinnedBar: View {

    let viewModel: CompassViewModel

    /// Scrolls the dial into view.
    let onShowCompass: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Constants (DESIGN-1.1.md §4.1)

    private static let minHeight: CGFloat = 64
    /// From the screen's sides.
    static let sideMargin: CGFloat = 16
    /// Above the home indicator, or the bottom note's top.
    static let bottomMargin: CGFloat = 8
    private static let paddingLeading: CGFloat = 22
    /// The button sits closer to the bar's end.
    private static let paddingTrailing: CGFloat = 10
    private static let paddingVertical: CGFloat = 10
    private static let spacing: CGFloat = 12
    private static let shadowOpacity = 0.35
    private static let shadowRadius: CGFloat = 12
    private static let shadowOffsetY: CGFloat = 4
    /// Low accuracy dims the heading, as on the readout (§9.4).
    private static let lowAccuracyOpacity = 0.5
    /// It's fixed over the content, so its text stops growing here, like
    /// the bottom bar's.
    private static let maxTextSize = DynamicTypeSize.accessibility1
    private static let lockAnimation = Animation.easeOut(duration: 0.2)
    /// With the compact button, a long lock text ("Moonrise · 58° ENE") at
    /// AX sizes on a small phone shrinks this far rather than being cut off.
    private static let readoutMinimumScale: CGFloat = 0.5

    static let showCompassTitle = "Compass ↓"
    /// The button when the readout and "Compass ↓" don't fit side by side
    /// (AX sizes, a lock text).
    static let showCompassCompactTitle = "↓"
    /// Spoken instead of the arrow.
    static let showCompassAccessibilityLabel = "Go to compass"

    // MARK: - Body

    private var isLocked: Bool { viewModel.lockReadout != nil }

    var body: some View {
        // The readout at full size beside "Compass ↓"; failing that, beside
        // just "↓", shrinking if it must. Never an ellipsis.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Self.spacing) {
                readout
                    .fixedSize()
                    .frame(maxWidth: .infinity, alignment: .leading)
                showCompassButton(Self.showCompassTitle)
            }
            HStack(spacing: Self.spacing) {
                readout
                    .minimumScaleFactor(Self.readoutMinimumScale)
                    .frame(maxWidth: .infinity, alignment: .leading)
                showCompassButton(Self.showCompassCompactTitle)
            }
        }
        .padding(.leading, Self.paddingLeading)
        .padding(.trailing, Self.paddingTrailing)
        .padding(.vertical, Self.paddingVertical)
        .frame(maxWidth: .infinity, minHeight: Self.minHeight)
        .background { background }
        .overlay {
            Capsule().strokeBorder(isLocked ? .clear : Theme.Colors.glassBorder, lineWidth: Theme.Metrics.hairline)
        }
        .shadow(color: .black.opacity(Self.shadowOpacity), radius: Self.shadowRadius, y: Self.shadowOffsetY)
        .animation(reduceMotion ? nil : Self.lockAnimation, value: isLocked)
        .padding(.horizontal, Self.sideMargin)
        .padding(.bottom, Self.bottomMargin)
        .dynamicTypeSize(...Self.maxTextSize)
        .accessibilityElement(children: .contain)
    }

    private func showCompassButton(_ title: String) -> some View {
        Button(title, action: onShowCompass)
            .buttonStyle(ShowCompassButtonStyle(isLocked: isLocked))
            .accessibilityLabel(Self.showCompassAccessibilityLabel)
    }

    /// Glass (ultra-thin material under the `glassTint`); amber on lock.
    @ViewBuilder
    private var background: some View {
        if isLocked {
            Capsule().fill(Theme.Colors.accent)
        } else {
            Capsule()
                .fill(Theme.Colors.glassTint)
                .background(.ultraThinMaterial, in: Capsule())
        }
    }

    /// The readout's text and VoiceOver label, from the same view-model
    /// state as the readout above the dial.
    @ViewBuilder
    private var readout: some View {
        if let lockReadout = viewModel.lockReadout {
            CompassView.text(for: lockReadout)
                .foregroundStyle(Theme.Colors.onAccent)
                .lineLimit(1)
                .accessibilityLabel(viewModel.lockAccessibilityLabel ?? lockReadout.string)
        } else {
            CompassView.text(for: viewModel.headingReadout)
                .monospacedDigit()
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)
                .opacity(viewModel.isLowAccuracy && viewModel.reading != nil ? Self.lowAccuracyOpacity : 1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(viewModel.headingAccessibilityLabel)
                .accessibilityAddTraits(.updatesFrequently)
        }
    }
}

// MARK: - Compass ↓

/// An `accent` capsule with a 44 pt target; dark on the amber (locked) bar.
private struct ShowCompassButtonStyle: ButtonStyle {

    let isLocked: Bool

    private static let paddingHorizontal: CGFloat = 16
    private static let paddingVertical: CGFloat = 10

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.button)
            .foregroundStyle(isLocked ? Theme.Colors.accent : Theme.Colors.onAccent)
            .fixedSize()
            .padding(.horizontal, Self.paddingHorizontal)
            .padding(.vertical, Self.paddingVertical)
            .frame(minHeight: Theme.Metrics.minimumHitTarget)
            .background(isLocked ? Theme.Colors.onAccent : Theme.Colors.accent, in: Capsule())
            // Shrink, dim and spring back (DECISIONS.md "Tap animation").
            .pressFeedback(isPressed: configuration.isPressed)
            .contentShape(Capsule())
    }
}
