//
//  moonbeam_appApp.swift
//  moonbeam-app
//
//  Created by TC on 9/23/26.
//

import SwiftUI

@main
struct moonbeam_appApp: App {
    // Astronomy Engine spike scaffolding; remove with MoonTableSpike.
    init() {
        MoonTableSpike.run()
    }

    var body: some Scene {
        WindowGroup {
            // Spike UI wiring; replaced in task #4.
            ContentView(
                viewModel: SpikeMoonTableViewModel(moonService: AstronomyEngineMoonService())
            )
        }
    }
}
