//
//  moonbeam_appApp.swift
//  moonbeam-app
//
//  Created by TC on 9/23/26.
//

import SwiftUI

@main
struct moonbeam_appApp: App {
    /// The one place the real services are chosen; everything below receives
    /// them through initializers.
    @State private var locationViewModel = LocationViewModel(
        locationService: CoreLocationService(),
        placeSearch: MapKitPlaceSearchService(),
        placeStore: UserDefaultsPlaceStore(),
        moonService: AstronomyEngineMoonService(),
        headingService: CoreLocationHeadingService()
    )

    // Astronomy Engine spike scaffolding; remove with MoonTableSpike.
    init() {
        MoonTableSpike.run()
    }

    var body: some Scene {
        WindowGroup {
            // The chosen place drives the spike moon table (ContentView)
            // until the designed table replaces it in task #4.
            LocationScreen(viewModel: locationViewModel)
                // Design 1.1 defaults for any text a step hasn't styled yet,
                // sheets included (DESIGN-1.1.md §6). Dark is forced in
                // Info.plist; tint comes from the AccentColor asset.
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textPrimary)
        }
    }
}
