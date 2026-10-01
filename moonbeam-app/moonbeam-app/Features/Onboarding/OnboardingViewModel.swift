//
//  OnboardingViewModel.swift
//  moonbeam-app
//

import Foundation
import Observation

/// First-launch onboarding (DESIGN-1.1.md §5): Landing → Location upsell →
/// the iOS prompt → "That's okay" (only after Don't Allow).
///
/// Decides whether onboarding shows at all, which screen is up, and how it
/// ends. The system prompt only ever comes from the upsell's Use my location
/// tap, never from launch (ARCHITECTURE.md §10).
///
/// Every exit marks onboarding completed, then hands its `Outcome` to
/// `onFinish`, which the app routes to `LocationViewModel` so the main
/// screen starts in the right state.
@Observable
final class OnboardingViewModel {

    // MARK: - Types

    enum Step: Equatable {
        /// "Moon Signal" and Get started.
        case landing
        /// "Find the moon from where you are": Use my location / Search
        /// for a city instead.
        case locationUpsell
        /// "That's okay", after Don't Allow at the prompt.
        case locationDeclined
    }

    /// How onboarding ended, which decides how the main screen starts.
    enum Outcome: Equatable {
        /// Allowed at the prompt (Allow Once included), or authorized in
        /// Settings while "That's okay" was up: the normal launch flow
        /// finds the city.
        case locationAllowed
        /// Got it, after Don't Allow: the empty "a city" state.
        case locationDeclined
        /// Search for a city instead: the search sheet opens, no prompt.
        case searchInstead
    }

    // MARK: - Observed state

    /// Onboarding is up. Set once at launch; cleared by any exit.
    private(set) var isPresented: Bool

    private(set) var step: Step = .landing

    // MARK: - Dependencies

    private let locationService: any LocationService
    @ObservationIgnored private let onboardingStore: any OnboardingStore
    @ObservationIgnored private let onFinish: (Outcome) -> Void

    // MARK: - Bookkeeping

    /// The prompt deactivates the scene; its return to active isn't a
    /// return from Settings.
    @ObservationIgnored private var isRequestingPermission = false

    // MARK: - Init

    init(
        locationService: any LocationService,
        placeStore: any PlaceStore,
        onboardingStore: any OnboardingStore,
        onFinish: @escaping (Outcome) -> Void = { _ in }
    ) {
        self.locationService = locationService
        self.onboardingStore = onboardingStore
        self.onFinish = onFinish
        isPresented = Self.shouldShow(
            hasSavedPlace: placeStore.lastViewed != nil,
            authorizationState: locationService.authorizationState,
            isCompleted: onboardingStore.isOnboardingCompleted
        )
    }

    // MARK: - When it shows (§5, §11 Q5)

    /// New installs only: no saved place, permission never asked, and
    /// onboarding not already left once. Existing installs skip it.
    static func shouldShow(
        hasSavedPlace: Bool,
        authorizationState: LocationAuthState,
        isCompleted: Bool
    ) -> Bool {
        !hasSavedPlace && authorizationState == .notDetermined && !isCompleted
    }

    // MARK: - Actions

    /// Landing's Get started.
    func getStarted() {
        guard step == .landing else { return }
        step = .locationUpsell
    }

    /// The upsell's Use my location: the one call that shows the prompt.
    func useMyLocation() async {
        guard step == .locationUpsell, !isRequestingPermission else { return }
        isRequestingPermission = true
        let state = await locationService.requestAuthorization()
        isRequestingPermission = false

        switch state {
        case .authorized:
            finish(.locationAllowed)
        case .notDetermined:
            // The prompt went away unanswered; stay so it can be tapped again.
            break
        case .denied, .restricted, .servicesOff:
            step = .locationDeclined
        }
    }

    /// The upsell's Search for a city instead. No prompt.
    func searchInstead() {
        guard step == .locationUpsell else { return }
        finish(.searchInstead)
    }

    /// "That's okay"'s Got it.
    func gotIt() {
        guard step == .locationDeclined else { return }
        finish(.locationDeclined)
    }

    /// Call when the scene becomes active. "Enable location" leaves for
    /// Settings with "That's okay" still up; coming back authorized goes to
    /// the main screen as Allow does. Anything else stays put.
    func sceneDidBecomeActive() {
        guard isPresented, step == .locationDeclined, !isRequestingPermission else { return }
        guard locationService.authorizationState.isAuthorized else { return }
        finish(.locationAllowed)
    }

    // MARK: - Finishing

    private func finish(_ outcome: Outcome) {
        guard isPresented else { return }
        onboardingStore.isOnboardingCompleted = true
        // The main screen is told first, so it starts in the right state.
        onFinish(outcome)
        isPresented = false
    }
}
