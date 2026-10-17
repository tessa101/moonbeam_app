//
//  RootScreen.swift
//  moonbeam-app
//

import SwiftUI

/// Onboarding, or the main screen, and the handover between them.
///
/// A view of its own rather than the `App`'s body: the handover's fades are
/// `withAnimation` changes to its state, and state held on the `App` reached
/// the screen with no animation, so every root fade cut in one frame
/// (STEP-5.14 §6.1).
struct RootScreen: View {

    let locationViewModel: LocationViewModel
    let onboardingViewModel: OnboardingViewModel

    /// Trails the view model by the shared outgoing-page fade, so onboarding
    /// and main are never removed before their 0.2 s exit completes.
    @State private var displaysOnboarding: Bool
    @State private var isLeavingRootScreen = false
    /// Got it's moon entry (STEP-5.14 §6.3): only the declined page's text
    /// and buttons leave; its moon stays for the loader to take over.
    @State private var isLeavingAroundMoon = false
    /// "That's okay"'s moon, in global coordinates, for the loader's moon to
    /// fly up from.
    @State private var declinedMoonFrame: CGRect?

    init(locationViewModel: LocationViewModel, onboardingViewModel: OnboardingViewModel) {
        self.locationViewModel = locationViewModel
        self.onboardingViewModel = onboardingViewModel
        _displaysOnboarding = State(initialValue: onboardingViewModel.isPresented)
    }

    var body: some View {
        Group {
            // DESIGN-1.1.md §5: new installs see onboarding first.
            if displaysOnboarding {
                OnboardingView(viewModel: onboardingViewModel) { declinedMoonFrame = $0 }
                    .environment(\.onboardingLeavesAroundMoon, isLeavingAroundMoon)
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
                    onReturnToOnboarding: { onboardingViewModel.returnToUpsell() },
                    moonEntryStartFrame: declinedMoonFrame
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
        // Got it: the moon stays where it is and the main screen's loader
        // takes it over (STEP-5.14 §6.3). Its text exit is the same fade.
        let keepsMoon = !toOnboarding && locationViewModel.entersThroughMoon && declinedMoonFrame != nil
        withAnimation(OnboardingScreenChange.exitAnimation) {
            if keepsMoon {
                isLeavingAroundMoon = true
            } else {
                isLeavingRootScreen = true
            }
        }
        try? await Task.sleep(for: .seconds(keepsMoon ? MoonEntry.textExitDuration : OnboardingScreenChange.exitDuration))
        guard !Task.isCancelled else { return }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            displaysOnboarding = toOnboarding
            isLeavingRootScreen = false
            isLeavingAroundMoon = false
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
