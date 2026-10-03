//
//  CompassBottomBar.swift
//  moonbeam-app
//

import SwiftUI

/// The bar fixed just above the home indicator for the compass's note
/// (COMPASS-1.1.md §9.4, mocks `design/1.2-layout/6a`, `6d`): icon, text, and
/// for Precise Location off the Use Precise button. `LocationScreen` pins it
/// with `safeAreaInset(edge: .bottom)`, so the content scrolls above it and
/// the top of the screen never moves when it appears. Reverses 5.4.3's notes
/// under the readout.
///
/// VoiceOver: the text is spoken with the readout, right before the dial
/// (`CompassViewModel.headingAccessibilityLabel`), so here only the button
/// is an element.
struct CompassBottomBar: View {

    let note: CompassBottomNote

    /// Use Precise: iOS's temporary full-accuracy alert (4.12).
    let onUsePreciseLocation: () -> Void

    @ScaledMetric(relativeTo: .footnote) private var iconSize = Self.iconBaseSize
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: - Constants (§9.4, read from the mocks)

    private static let cornerRadius: CGFloat = 24
    /// From the screen's sides.
    static let sideMargin: CGFloat = 16
    /// Above the home indicator (the safe area's bottom).
    static let bottomMargin: CGFloat = 4
    private static let paddingVertical: CGFloat = 12
    private static let paddingLeading: CGFloat = 16
    /// The button sits closer to the bar's end, as in 6d.
    private static let paddingTrailing: CGFloat = 10
    private static let spacing: CGFloat = 12
    private static let iconBaseSize: CGFloat = 20
    /// The Precise icon's dotted ring and centre dot (6d).
    private static let preciseDotScale: CGFloat = 0.3
    private static let mark = "!"
    /// The bar is fixed over the content, so its text stops growing here:
    /// at AX5 it covered half the iPhone 17's screen and three quarters of
    /// the SE 3's (5.4.6c fit report).
    private static let maxTextSize = DynamicTypeSize.accessibility1

    // MARK: - Body

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Self.cornerRadius)
        // Chosen by size, not ViewThatFits: the wrapping text's ideal width
        // is one long line, so ViewThatFits always put the button under it.
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // At AX sizes the button goes under the text.
                VStack(alignment: .leading, spacing: Self.spacing) {
                    HStack(alignment: .firstTextBaseline, spacing: Self.spacing) {
                        icon
                        text
                    }
                    button
                }
            } else {
                HStack(spacing: Self.spacing) {
                    icon
                    text
                        .frame(maxWidth: .infinity, alignment: .leading)
                    button
                }
            }
        }
        .padding(.vertical, Self.paddingVertical)
        .padding(.leading, Self.paddingLeading)
        .padding(.trailing, note.offersPreciseLocation ? Self.paddingTrailing : Self.paddingLeading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surfaceInset, in: shape)
        .overlay {
            shape.strokeBorder(Theme.Colors.stroke, lineWidth: Theme.Metrics.hairline)
        }
        .padding(.horizontal, Self.sideMargin)
        .padding(.bottom, Self.bottomMargin)
        .dynamicTypeSize(...Self.maxTextSize)
    }

    /// Precise off: a dotted location ring in amber. Otherwise, as built,
    /// the "!" in an amber circle.
    @ViewBuilder
    private var icon: some View {
        Group {
            if note.kind == .preciseOff {
                ZStack {
                    Image(systemName: "circle.dotted")
                        .resizable()
                    Circle()
                        .frame(width: iconSize * Self.preciseDotScale, height: iconSize * Self.preciseDotScale)
                }
                .foregroundStyle(Theme.Colors.accent)
            } else {
                Text(Self.mark)
                    .font(Theme.Fonts.noteMark)
                    .foregroundStyle(Theme.Colors.onAccent)
                    .frame(width: iconSize, height: iconSize)
                    .background(Theme.Colors.accent, in: Circle())
            }
        }
        .frame(width: iconSize, height: iconSize)
        .accessibilityHidden(true)
    }

    private var text: some View {
        Text(note.text)
            .font(Theme.Fonts.note)
            .foregroundStyle(Theme.Colors.textBody)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var button: some View {
        if note.offersPreciseLocation {
            Button(CompassViewModel.usePreciseLocationTitle, action: onUsePreciseLocation)
                .buttonStyle(UsePreciseButtonStyle())
        }
    }
}

// MARK: - Use Precise

/// A compact `accent` capsule (6d), the primary button's colours at the
/// bar's size, with a 44 pt target.
private struct UsePreciseButtonStyle: ButtonStyle {

    private static let paddingHorizontal: CGFloat = 16
    private static let paddingVertical: CGFloat = 10

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.button)
            .foregroundStyle(Theme.Colors.onAccent)
            .fixedSize()
            .padding(.horizontal, Self.paddingHorizontal)
            .padding(.vertical, Self.paddingVertical)
            .frame(minHeight: Theme.Metrics.minimumHitTarget)
            .background(Theme.Colors.accent, in: Capsule())
            // Shrink, dim and spring back (DECISIONS.md "Tap animation").
            .pressFeedback(isPressed: configuration.isPressed)
            .contentShape(Capsule())
    }
}

// MARK: - Previews

#Preview("Precise off") {
    VStack {
        Spacer()
        CompassBottomBar(
            note: CompassBottomNote(kind: .preciseOff, text: CompassViewModel.preciseLocationOffText),
            onUsePreciseLocation: {}
        )
        CompassBottomBar(
            note: CompassBottomNote(kind: .lowAccuracy, text: CompassViewModel.lowAccuracyNote),
            onUsePreciseLocation: {}
        )
    }
    .background(Theme.Colors.bg)
}
