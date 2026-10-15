//
//  RowButtonStyle.swift
//  moonbeam-app
//

import SwiftUI

/// A whole list row as one button: the search sheet's Use my location,
/// recents and suggestions (STEP-5.13 §4). Leading-aligned across the full
/// row, at least 44 pt tall, tappable anywhere in it, with the shared
/// pressed look in place of the list's gray highlight.
struct RowButtonStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, minHeight: Theme.Metrics.minimumHitTarget, alignment: .leading)
            .contentShape(Rectangle())
            // Shrink, dim and spring back (DECISIONS.md "Tap animation").
            .pressFeedback(isPressed: configuration.isPressed)
    }
}

extension ButtonStyle where Self == RowButtonStyle {

    /// `.buttonStyle(.row)`.
    static var row: RowButtonStyle { RowButtonStyle() }
}
