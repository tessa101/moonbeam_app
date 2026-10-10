//
//  MessageActions.swift
//  moonbeam-app
//

import SwiftUI

/// A location message's primary button and the text link under it: the
/// action half of the one message block, shared by the launch loader's
/// messages (`LoaderMessage`) and the failure screen (`LocationFailureView`).
/// Each passes its own gap.
struct MessageActions: View {

    let copy: MessageCopy

    /// The loader's handoff has 22 pt; the failure screen 6 pt.
    var buttonToLink: CGFloat = 22

    let onPrimary: () -> Void
    let onLink: () -> Void

    var body: some View {
        VStack(spacing: buttonToLink) {
            Button(copy.primaryTitle, action: onPrimary)
                // §10.5 keeps this control at the designed 56 pt even when
                // the surrounding message uses an AX text size. The full
                // title remains available to VoiceOver.
                .dynamicTypeSize(.large)
                .buttonStyle(.primary)
            // With no link (restricted), its room is kept, so the button
            // sits where it does on the other messages (Tessa, 2026-10-06).
            Button(copy.linkTitle, action: onLink)
                .buttonStyle(.textLink)
                .opacity(copy.showsLink ? 1 : 0)
                .disabled(!copy.showsLink)
                .accessibilityHidden(!copy.showsLink)
        }
    }
}
