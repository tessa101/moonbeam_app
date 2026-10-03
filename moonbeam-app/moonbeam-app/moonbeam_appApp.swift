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

    #if DEBUG
    /// `-screenState <kind>`: open on one faked compass state, for
    /// screenshots (`DebugScreenState`).
    private let debugScreenState = DebugScreenState.kind(fromLaunchArguments: ProcessInfo.processInfo.arguments)
    #endif

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
        let onboarding = OnboardingViewModel(
            locationService: locationService,
            placeStore: placeStore,
            onboardingStore: onboardingStore,
            // How onboarding ended decides how the main screen starts.
            onFinish: { [weak location] outcome in location?.onboardingDidFinish(outcome) }
        )
        #if DEBUG
        // -forceOnboarding / -onboardingPage (DECISIONS.md 2026-10-01).
        onboarding.applyDebugLaunchArguments(ProcessInfo.processInfo.arguments)
        #endif
        _onboardingViewModel = State(initialValue: onboarding)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG
                if let debugScreenState {
                    DebugScreenState(debugScreenState)
                } else {
                    mainContent
                }
                #else
                mainContent
                #endif
            }
            // Design 1.1 defaults for any text a step hasn't styled yet,
            // sheets included (DESIGN-1.1.md §6). Dark is forced in
            // Info.plist; tint comes from the AccentColor asset.
            .font(Theme.Fonts.body)
            .foregroundStyle(Theme.Colors.textPrimary)
        }
    }

    /// Onboarding, or the main screen.
    @ViewBuilder
    private var mainContent: some View {
        // DESIGN-1.1.md §5: new installs see onboarding first.
        if onboardingViewModel.isPresented {
            OnboardingView(viewModel: onboardingViewModel)
        } else {
            // The chosen place drives the moon card.
            // Show onboarding: DEBUG and TestFlight only, temporary
            // (DECISIONS.md 2026-10-01).
            LocationScreen(
                viewModel: locationViewModel,
                onShowOnboarding: BuildChannel.showsOnboardingButton
                    ? { onboardingViewModel.forceShow() }
                    : nil
            )
        }
    }
}
