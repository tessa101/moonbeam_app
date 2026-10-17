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

    /// "That's okay"'s moon frame, for Got it's moon entry (STEP-5.14 §6.3).
    let onDeclinedMoonFrame: (CGRect) -> Void

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    /// The screen on show. Trails `viewModel.step` by the outgoing page's
    /// fade-out (`OnboardingScreenChange`).
    @State private var displayedStep: OnboardingViewModel.Step
    /// The outgoing page is fading out.
    @State private var isLeaving = false

    init(viewModel: OnboardingViewModel, onDeclinedMoonFrame: @escaping (CGRect) -> Void = { _ in }) {
        self.viewModel = viewModel
        self.onDeclinedMoonFrame = onDeclinedMoonFrame
        _displayedStep = State(initialValue: viewModel.step)
    }

    var body: some View {
        Group {
            switch displayedStep {
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
                    onEnableLocation: openSettings,
                    onMoonFrame: onDeclinedMoonFrame
                )
            }
        }
        .opacity(isLeaving ? 0 : 1)
        .background { ScreenBackground() }
        .task(id: viewModel.step) {
            await changeScreen(to: viewModel.step)
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

    // MARK: - Screen change

    /// Fades the old page out, puts the new one in place (its blocks then
    /// load in on appearance), then tells VoiceOver. A new screen replaces
    /// the old one in place, so VoiceOver starts again from its top (the
    /// title). A step change mid-fade cancels this run; the next one carries
    /// on from the faded page.
    private func changeScreen(to step: OnboardingViewModel.Step) async {
        guard step != displayedStep else { return }
        if OnboardingScreenChange.loadsIn(step) {
            withAnimation(OnboardingScreenChange.exitAnimation) {
                isLeaving = true
            }
            try? await Task.sleep(for: .seconds(OnboardingScreenChange.exitDuration))
            guard !Task.isCancelled else { return }
        }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            displayedStep = step
            isLeaving = false
        }
        let announceDelay = OnboardingScreenChange.announceDelay(for: step)
        if announceDelay > 0 {
            try? await Task.sleep(for: .seconds(announceDelay))
            guard !Task.isCancelled else { return }
        }
        AccessibilityNotification.ScreenChanged().post()
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
