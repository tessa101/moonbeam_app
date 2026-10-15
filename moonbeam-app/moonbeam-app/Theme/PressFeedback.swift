//
//  PressFeedback.swift
//  moonbeam-app
//

import SwiftUI

/// The pressed-state animation every button shares (DECISIONS.md 2026-10-01
/// "Tap animation on buttons", DESIGN-REVIEW.md "Motion and feedback"): a
/// slight shrink and dim while the finger is down, and a quick spring back.
/// With Reduce Motion it only dims.
///
/// The look is held for at least `PressHold.minimum` (100 ms) even if the
/// finger lifts sooner, so an ordinary tap shows it (STEP-5.13 §4). With
/// Reduce Motion the dim is held the same way. The action isn't delayed.
///
/// Applied by the button styles (`.pressFeedback(isPressed:)`), never by a
/// view, so every button picks it up from its style.
struct PressFeedback: ViewModifier {

    let isPressed: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hold = PressHold()

    // MARK: - Constants (proposed; tune on device)

    static let pressedScale: CGFloat = 0.96
    static let pressedOpacity = 0.8
    /// Quick enough not to feel laggy on a tap, slow enough to be seen.
    static let animation = Animation.spring(duration: 0.15)

    // MARK: - Look

    /// No scale under Reduce Motion: shrinking is motion, dimming isn't.
    static func scale(isPressed: Bool, reduceMotion: Bool) -> CGFloat {
        isPressed && !reduceMotion ? pressedScale : 1
    }

    static func opacity(isPressed: Bool) -> Double {
        isPressed ? pressedOpacity : 1
    }

    func body(content: Content) -> some View {
        content
            // Scope the spring to the two pressed-state effects. The older
            // value-based modifier also animated layout changes delivered in
            // the release transaction; a day-step tap could therefore move
            // the tapped chevron from a stale header position.
            .animation(Self.animation) { content in
                content
                    .scaleEffect(Self.scale(isPressed: hold.showsPressedLook, reduceMotion: reduceMotion))
                    .opacity(Self.opacity(isPressed: hold.showsPressedLook))
            }
            .onChange(of: isPressed, initial: true) { _, pressed in
                guard pressed else {
                    hold.fingerUp()
                    return
                }
                let cycle = hold.fingerDown()
                Task { @MainActor in
                    try? await Task.sleep(for: PressHold.minimum)
                    hold.minimumPassed(cycle: cycle)
                }
            }
    }
}

extension View {

    /// The shared pressed-state look and animation, for button styles.
    func pressFeedback(isPressed: Bool) -> some View {
        modifier(PressFeedback(isPressed: isPressed))
    }
}

// MARK: - Previews

/// One button drawn as it looks in a state, with the modifier's own scale
/// and opacity (a preview can't hold a press, or set Reduce Motion).
private struct PressedLook: ViewModifier {
    let isPressed: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(PressFeedback.scale(isPressed: isPressed, reduceMotion: reduceMotion))
            .opacity(PressFeedback.opacity(isPressed: isPressed))
    }
}

/// Each shared style at rest, pressed, and pressed with Reduce Motion.
#Preview("Pressed states") {
    let states: [(title: String, isPressed: Bool, reduceMotion: Bool)] = [
        ("At rest", false, false),
        ("Pressed", true, false),
        ("Pressed, Reduce Motion", true, true),
    ]
    ScrollView {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(states, id: \.title) { state in
                let look = PressedLook(isPressed: state.isPressed, reduceMotion: state.reduceMotion)
                Text(state.title)
                    .font(.caption.monospaced())
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(.top, 8)
                Button("Get started") {}
                    .buttonStyle(.primary)
                    .modifier(look)
                Button("Enable location") {}
                    .buttonStyle(.secondary)
                    .modifier(look)
                Button("Search for a city instead") {}
                    .buttonStyle(.textLink)
                    .modifier(look)
            }
        }
        .padding(28)
    }
    .background(Theme.Colors.bg)
}
