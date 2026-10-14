//
//  DebugPanel.swift
//  moonbeam-app
//

import SwiftUI

/// Everything temporary for testing, in one block at the very bottom of the
/// main screen: Show onboarding, Forget saved place, then the compass's
/// diagnostic readout (DECISIONS.md 2026-10-14). Early testers get it too
/// (DEBUG and TestFlight, via `BuildChannel`), and can hide or show all of it
/// with the last button; the choice is remembered.
///
/// The screen only builds this when at least one debug action is passed in,
/// so App Store builds never show any of it. Temporary, with the buttons.
struct DebugPanel: View {

    /// The readout's lines (`CompassViewModel.debugReadout`).
    let readoutLines: [String]

    /// `nil` hides that button, as `LocationScreen`'s own parameters do.
    var onShowOnboarding: (() -> Void)?
    var onForgetSavedPlace: (() -> Void)?

    /// Remembered across launches, so a tester who hid it keeps it hidden.
    @AppStorage(DebugPanel.hiddenDefaultsKey) private var isHidden = false

    static let hiddenDefaultsKey = "debugToolsHidden"

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !isHidden {
                // Side by side while they fit, stacked at large sizes.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Theme.Metrics.screenMargin) { actions }
                    VStack(alignment: .leading, spacing: 0) { actions }
                }

                readout
            }

            Button(isHidden ? "Show debug tools" : "Hide debug tools") {
                isHidden.toggle()
            }
            .buttonStyle(.textLink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Pieces

    @ViewBuilder
    private var actions: some View {
        if let onShowOnboarding {
            Button("Show onboarding", action: onShowOnboarding)
                .buttonStyle(.textLink)
        }
        if let onForgetSavedPlace {
            Button("Forget saved place", action: onForgetSavedPlace)
                .buttonStyle(.textLink)
        }
    }

    /// Why the compass is in the state it's in (4.8/4.9). Shown in every
    /// compass state, hidden included: "the compass is gone" is one of the
    /// things it has to diagnose.
    private var readout: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(readoutLines, id: \.self) { line in
                Text(line)
            }
        }
        .font(.caption.monospaced())
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical)
    }
}
