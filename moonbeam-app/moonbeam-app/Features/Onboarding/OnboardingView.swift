//
//  OnboardingView.swift
//  moonbeam-app
//

import SwiftUI
import UIKit

/// Shows the current onboarding screen (DESIGN-1.1.md §5) and passes taps
/// and scene changes to `OnboardingViewModel`, which decides everything.
/// Screen 3 is the system prompt itself, so it has no view here.
struct OnboardingView: View {

    let viewModel: OnboardingViewModel

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    var body: some View {
        Group {
            switch viewModel.step {
            case .landing:
                OnboardingLandingScreen(onGetStarted: viewModel.getStarted)
            case .locationUpsell:
                OnboardingLocationScreen(
                    onUseMyLocation: { Task { await viewModel.useMyLocation() } },
                    onSearchInstead: viewModel.searchInstead
                )
            case .locationDeclined:
                OnboardingDeclinedScreen(
                    onGotIt: viewModel.gotIt,
                    onEnableLocation: openSettings
                )
            }
        }
        .background { ScreenBackground() }
        // A new screen replaces the old one in place, so VoiceOver is told
        // to start again from its top (the title).
        .onChange(of: viewModel.step) {
            AccessibilityNotification.ScreenChanged().post()
        }
        // Use my location with Location Services off or already denied: no
        // prompt can show, so the app's Settings page instead (DECISIONS.md
        // 2026-10-01 "Location Services off").
        .onChange(of: viewModel.settingsRequestCount) {
            openSettings()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            viewModel.sceneDidBecomeActive()
        }
    }

    // MARK: - Actions

    /// "Enable location", and Use my location when no prompt can show: the
    /// app's own Settings page. The screen stays up; the view model checks
    /// again on the way back.
    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

#Preview("Landing") {
    OnboardingView(
        viewModel: OnboardingViewModel(
            locationService: FakeLocationService(),
            placeStore: InMemoryPlaceStore(),
            onboardingStore: InMemoryOnboardingStore()
        )
    )
}
