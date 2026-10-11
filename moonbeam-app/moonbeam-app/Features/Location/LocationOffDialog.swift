//
//  LocationOffDialog.swift
//  moonbeam-app
//

import SwiftUI
import UIKit

/// The custom "Location Off" dialog from LOCATION.md §4, in its denied,
/// services-off and restricted variants.
///
/// Custom rather than a system alert so the copy can carry the Settings path
/// and offer search as an equal alternative. Functional only: the visual
/// design comes later.
///
/// The headline, explanation and Settings path are the cause's, from
/// `LocationFailure` (STEP-5.10a-LOCATION-CONSOLIDATION.md, Chunk 1), so the
/// dialog and the failure screen say the same thing; its actions are its own.
struct LocationOffDialog: View {

    let variant: LocationViewModel.LocationOffVariant

    /// "Search instead" / "Search for a city".
    let onSearch: () -> Void

    /// Called after Settings has been asked to open, so the dialog can close.
    let onOpenedSettings: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(copy.headline)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                Text(copy.body)

                // The failure screen's path chip, as a line of its own.
                if let path = copy.pathChipLines?.joined(separator: " ") {
                    Text(path)
                        .bold()
                        .accessibilityLabel(copy.pathChipAccessibilityLabel ?? path)
                }

                // The cause's button title; "Search instead" stays the
                // dialog's own.
                if variant.offersSettings {
                    Button(copy.primaryTitle, action: openSettings)
                    Button("Search instead", action: onSearch)
                } else {
                    Button(copy.primaryTitle, action: onSearch)
                }
            }
            .padding()
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Copy

    private var copy: MessageCopy { variant.failure.copy }

    // MARK: - Actions

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
        onOpenedSettings()
    }
}

#Preview("Denied") {
    LocationOffDialog(variant: .denied, onSearch: {}, onOpenedSettings: {})
}

#Preview("Services off") {
    LocationOffDialog(variant: .servicesOff, onSearch: {}, onOpenedSettings: {})
}

#Preview("Restricted") {
    LocationOffDialog(variant: .restricted, onSearch: {}, onOpenedSettings: {})
}
