//
//  moonbeam_appApp.swift
//  moonbeam-app
//
//  Created by TC on 9/23/26.
//

import SwiftUI

@main
struct moonbeam_appApp: App {
    @State private var locationViewModel: LocationViewModel
    @State private var onboardingViewModel: OnboardingViewModel

    /// The one place the real services are chosen; everything below receives
    /// them through initializers. Onboarding and the main screen share the
    /// location service and place store.
    init() {
        // Astronomy Engine spike scaffolding; remove with MoonTableSpike.
        MoonTableSpike.run()

        let locationService = CoreLocationService()
        let placeStore = UserDefaultsPlaceStore()
        let onboardingStore = UserDefaultsOnboardingStore()
        #if DEBUG
        onboardingStore.resetIfRequested(by: ProcessInfo.processInfo.arguments)
        #endif

        let location = LocationViewModel(
            locationService: locationService,
            placeSearch: MapKitPlaceSearchService(),
            placeStore: placeStore,
            moonService: AstronomyEngineMoonService(),
            headingService: CoreLocationHeadingService()
        )
        _locationViewModel = State(initialValue: location)
        _onboardingViewModel = State(
            initialValue: OnboardingViewModel(
                locationService: locationService,
                placeStore: placeStore,
                onboardingStore: onboardingStore,
                // How onboarding ended decides how the main screen starts.
                onFinish: { [weak location] outcome in location?.onboardingDidFinish(outcome) }
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            Group {
                // DESIGN-1.1.md §5: new installs see onboarding first.
                if onboardingViewModel.isPresented {
                    OnboardingView(viewModel: onboardingViewModel)
                } else {
                    // The chosen place drives the moon card.
                    LocationScreen(viewModel: locationViewModel)
                }
            }
            // Design 1.1 defaults for any text a step hasn't styled yet,
            // sheets included (DESIGN-1.1.md §6). Dark is forced in
            // Info.plist; tint comes from the AccentColor asset.
            .font(Theme.Fonts.body)
            .foregroundStyle(Theme.Colors.textPrimary)
        }
    }
}
