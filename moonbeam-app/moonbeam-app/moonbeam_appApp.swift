//
//  moonbeam_appApp.swift
//  moonbeam-app
//
//  Created by TC on 9/23/26.
//

import os
import SwiftUI

@main
struct moonbeam_appApp: App {
    @State private var locationViewModel: LocationViewModel
    @State private var onboardingViewModel: OnboardingViewModel
    /// Trails the view model by the shared outgoing-page fade, so onboarding
    /// and main are never removed before their 0.2 s exit completes.
    @State private var displaysOnboarding: Bool
    @State private var isLeavingRootScreen = false

    #if DEBUG
    /// `-screenState <kind>`: open on one faked compass state, for
    /// screenshots (`DebugScreenState`).
    private let debugScreenState = DebugScreenState.kind(fromLaunchArguments: ProcessInfo.processInfo.arguments)
    #endif

    /// The one place the real services are chosen; everything below receives
    /// them through initializers. Onboarding and the main screen share the
    /// location service and place store.
    init() {
        let signposter = LaunchSignposts.signposter
        let appInit = signposter.beginInterval("App.init")
        defer { signposter.endInterval("App.init", appInit) }

        // Astronomy Engine spike scaffolding; remove with MoonTableSpike.
        let spike = signposter.beginInterval("MoonTableSpike.run")
        MoonTableSpike.run()
        signposter.endInterval("MoonTableSpike.run", spike)

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
            headingService: CoreLocationHeadingService(),
            onboardingStore: onboardingStore,
            connectivity: NWPathMonitorConnectivityService(),
            reducesMotion: { UIAccessibility.isReduceMotionEnabled }
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
        _displaysOnboarding = State(initialValue: onboarding.isPresented)
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
        Group {
            // DESIGN-1.1.md §5: new installs see onboarding first.
            if displaysOnboarding {
                OnboardingView(viewModel: onboardingViewModel)
            } else {
                // The chosen place drives the moon card.
                // Show onboarding and Forget saved place: DEBUG and TestFlight
                // only, temporary (DECISIONS.md 2026-10-01, 2026-10-06).
                LocationScreen(
                    viewModel: locationViewModel,
                    onShowOnboarding: BuildChannel.showsOnboardingButton
                        ? { onboardingViewModel.forceShow() }
                        : nil,
                    onForgetSavedPlace: BuildChannel.showsOnboardingButton
                        ? { Task { await locationViewModel.forgetSavedPlace() } }
                        : nil,
                    // Back from `noCity` to the upsell (ONBOARDING-MOD-MAIN.md);
                    // the screen offers it only until a city is set.
                    onReturnToOnboarding: { onboardingViewModel.returnToUpsell() }
                )
            }
        }
        .opacity(isLeavingRootScreen ? 0 : 1)
        // Outside the fade, so a handover never shows the window's black
        // (STEP-5.14 §6.2 item 3).
        .background { ScreenBackground() }
        .task(id: onboardingViewModel.isPresented) {
            await handOverRootScreen(toOnboarding: onboardingViewModel.isPresented)
        }
    }

    /// The same page exit used between onboarding steps, then the incoming
    /// screen owns its established block-by-block load-in. A new target
    /// cancels the sleep and takes over without stacking animations.
    private func handOverRootScreen(toOnboarding: Bool) async {
        guard toOnboarding != displaysOnboarding else { return }
        withAnimation(OnboardingScreenChange.exitAnimation) {
            isLeavingRootScreen = true
        }
        try? await Task.sleep(for: .seconds(OnboardingScreenChange.exitDuration))
        guard !Task.isCancelled else { return }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            displaysOnboarding = toOnboarding
            isLeavingRootScreen = false
        }

        if toOnboarding {
            try? await Task.sleep(for: .seconds(
                OnboardingScreenChange.announceDelay(for: onboardingViewModel.step)
            ))
            guard !Task.isCancelled else { return }
            AccessibilityNotification.ScreenChanged().post()
        }
    }
}
