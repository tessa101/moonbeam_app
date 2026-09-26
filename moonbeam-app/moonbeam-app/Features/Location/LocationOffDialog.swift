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
                Text("Location is off for \(AppInfo.name)")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                Text(message)

                if variant.offersSettings {
                    Button("Open Settings", action: openSettings)
                    Button("Search instead", action: onSearch)
                } else {
                    Button("Search for a city", action: onSearch)
                }
            }
            .padding()
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Copy

    private var message: LocalizedStringKey {
        switch variant {
        case .denied:
            "To find the moon where you are, turn on location in **Settings › \(AppInfo.name) › Location** and choose **While Using the App**. You can also just search for a city."
        case .servicesOff:
            // Open Settings can only reach the app's own page, so the copy
            // carries the path to the device-wide switch.
            "Location Services are off on this device. Turn them on in **Settings › Privacy & Security › Location Services**, or search for a city."
        case .restricted:
            "Location access is restricted on this device. Search for a city instead."
        }
    }

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
