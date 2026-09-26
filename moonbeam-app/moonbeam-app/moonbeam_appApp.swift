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
        moonService: AstronomyEngineMoonService()
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
        }
    }
}
