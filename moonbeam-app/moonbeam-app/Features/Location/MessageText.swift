//
//  MessageText.swift
//  moonbeam-app
//

import SwiftUI

/// A location message's headline, body and (optional) Settings path chip:
/// the text half of the one message block, shared by the launch loader's
/// messages (`LoaderMessage`) and the failure screen (`LocationFailureView`).
/// Each passes its own spacing; the type, colours and line breaks are the
/// same.
struct MessageText: View {

    let copy: MessageCopy

    /// §10.5: 1, or about 0.8 where the message doesn't fit.
    var textScale: CGFloat = 1

    /// The loader's handoff has 12 pt; the failure screen 14 pt.
    var headlineToBody: CGFloat = 12

    /// Where VoiceOver focus goes when the screen appears; `nil` leaves it.
    var headlineFocus: AccessibilityFocusState<Bool>.Binding? = nil
    /// Chunk 6: failure screens reveal these children separately.
    var failureLoadIn = false

    // MARK: - Constants

    /// §11.1.3: the prototype's widths, centred inside the 28 pt sides.
    /// Not at accessibility sizes, where the copy needs every point.
    static let headlineMaxWidth: CGFloat = 300
    static let bodyMaxWidth: CGFloat = 290

    /// STEP-5.10a Layout: the chip sits 16 pt under the body.
    private static let bodyToChip: CGFloat = 16

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            BrokenText(text: copy.headline, lines: copy.headlineLines)
                .font(Theme.Fonts.messageHeadline(scale: textScale))
                .foregroundStyle(Theme.Colors.textPrimary)
                .themeLineHeight(Theme.Fonts.messageHeadlineLineHeightMultiple)
                .frame(maxWidth: maxWidth(Self.headlineMaxWidth))
                .accessibilityAddTraits(.isHeader)
                .modifier(OptionalAccessibilityFocus(binding: headlineFocus))
                .failureLoadIn(.headline, hasPath: copy.pathChipLines != nil, isEnabled: failureLoadIn)
            BrokenText(text: copy.body, lines: copy.bodyLines)
                .font(Theme.Fonts.messageBody(scale: textScale))
                .foregroundStyle(Theme.Colors.textBody)
                .themeLineHeight(Theme.Fonts.messageBodyLineHeightMultiple)
                .frame(maxWidth: maxWidth(Self.bodyMaxWidth))
                .padding(.top, headlineToBody * textScale)
                .failureLoadIn(.body, hasPath: copy.pathChipLines != nil, isEnabled: failureLoadIn)
            if let lines = copy.pathChipLines, let label = copy.pathChipAccessibilityLabel {
                PathChip(lines: lines, accessibilityLabel: label)
                    .padding(.top, Self.bodyToChip * textScale)
                    .failureLoadIn(.path, hasPath: true, isEnabled: failureLoadIn)
            }
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func maxWidth(_ width: CGFloat) -> CGFloat {
        dynamicTypeSize.isAccessibilitySize ? .infinity : width
    }
}

// MARK: - Path chip

/// STEP-5.10a Layout: where to find the switch, e.g. "Settings › Moon
/// Signal › Location › While Using the App", in a quiet raised chip. Only
/// for the causes the user can fix in Settings.
private struct PathChip: View {

    let lines: [String]
    let accessibilityLabel: String

    private static let cornerRadius: CGFloat = 14
    private static let verticalPadding: CGFloat = 8
    private static let horizontalPadding: CGFloat = 14

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
        BrokenText(text: lines.joined(separator: " "), lines: lines)
            .font(Theme.Fonts.note)
            .foregroundStyle(Theme.Colors.textSecondary)
            .padding(.vertical, Self.verticalPadding)
            .padding(.horizontal, Self.horizontalPadding)
            .background { shape.fill(Theme.Colors.surfaceRaised) }
            .overlay { shape.strokeBorder(Theme.Colors.stroke, lineWidth: Theme.Metrics.hairline) }
            .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - Set line breaks

/// The copy on its set lines (§11.1.3) when every line fits the width,
/// otherwise wrapped naturally (accessibility sizes, small screens, a line
/// too long for the width). Never truncated. VoiceOver reads the copy
/// without the breaks.
private struct BrokenText: View {

    let text: String
    let lines: [String]?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            if let lines {
                Text(lines.joined(separator: "\n"))
                    .fixedSize()
            }
            Text(text)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

// MARK: - Focus

/// `accessibilityFocused` only when there's a binding to focus with.
private struct OptionalAccessibilityFocus: ViewModifier {

    let binding: AccessibilityFocusState<Bool>.Binding?

    func body(content: Content) -> some View {
        if let binding {
            content.accessibilityFocused(binding)
        } else {
            content
        }
    }
}
