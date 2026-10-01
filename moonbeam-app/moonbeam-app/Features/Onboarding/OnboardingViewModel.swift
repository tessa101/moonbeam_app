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
///
/// DEBUG builds can also force it (DECISIONS.md 2026-10-01 "DEBUG onboarding
/// trigger"): `-forceOnboarding`, `-onboardingPage`, or the main screen's
/// Show onboarding button. A forced run writes no stored state.
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

    /// Goes up by one each time Use my location can't show the prompt
    /// (Location Services off, or already denied): the view opens the app's
    /// Settings page when it changes, as "Enable location" does.
    private(set) var settingsRequestCount = 0

    // MARK: - Dependencies

    private let locationService: any LocationService
    @ObservationIgnored private let onboardingStore: any OnboardingStore
    @ObservationIgnored private let onFinish: (Outcome) -> Void

    // MARK: - Bookkeeping

    /// The prompt deactivates the scene; its return to active isn't a
    /// return from Settings.
    @ObservationIgnored private var isRequestingPermission = false

    /// Use my location sent the user to Settings from the upsell; coming
    /// back authorized goes to the main screen.
    @ObservationIgnored private var isAwaitingSettingsFromUpsell = false

    #if DEBUG
    /// Shown by the DEBUG trigger, not by `shouldShow`: finishing leaves the
    /// completed flag alone.
    @ObservationIgnored private var isForced = false

    /// "That's okay" was forced on screen with location already allowed.
    /// Its Settings-return rule would close it the moment the scene became
    /// active, so it's held until the user leaves it.
    @ObservationIgnored private var isDeclinedForcedWhileAuthorized = false
    #endif

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
    ///
    /// "That's okay" follows a real Don't Allow only (DECISIONS.md
    /// 2026-10-01 "Location Services off"). With Location Services off, or
    /// permission already denied ("Never"), no prompt can show, so nobody
    /// declined anything: Settings opens instead and the upsell stays.
    func useMyLocation() async {
        guard step == .locationUpsell, !isRequestingPermission else { return }
        let before = locationService.authorizationState
        if before == .servicesOff || before == .denied {
            requestSettings()
            return
        }

        isRequestingPermission = true
        let state = await locationService.requestAuthorization()
        isRequestingPermission = false

        switch state {
        case .authorized:
            finish(.locationAllowed)
        case .notDetermined:
            // The prompt went away unanswered; stay so it can be tapped again.
            break
        case .servicesOff:
            requestSettings()
        case .denied, .restricted:
            // Don't Allow at the prompt. Restricted (parental controls,
            // MDM) can't be fixed in Settings, so it keeps "That's okay".
            step = .locationDeclined
            #if DEBUG
            isDeclinedForcedWhileAuthorized = false
            #endif
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
    ///
    /// The same holds on the upsell after Use my location opened Settings;
    /// still off, it stays so Use my location can be tapped again.
    func sceneDidBecomeActive() {
        guard isPresented, !isRequestingPermission else { return }
        let isBackFromUpsellSettings = step == .locationUpsell && isAwaitingSettingsFromUpsell
        guard step == .locationDeclined || isBackFromUpsellSettings else { return }
        guard locationService.authorizationState.isAuthorized else { return }
        #if DEBUG
        if isDeclinedForcedWhileAuthorized { return }
        #endif
        finish(.locationAllowed)
    }

    /// Asks the view to open the app's Settings page; the upsell stays up.
    private func requestSettings() {
        isAwaitingSettingsFromUpsell = true
        settingsRequestCount += 1
    }

    // MARK: - Finishing

    private func finish(_ outcome: Outcome) {
        guard isPresented else { return }
        #if DEBUG
        let marksCompleted = !isForced
        isForced = false
        isDeclinedForcedWhileAuthorized = false
        #else
        let marksCompleted = true
        #endif
        if marksCompleted {
            onboardingStore.isOnboardingCompleted = true
        }
        isAwaitingSettingsFromUpsell = false
        // The main screen is told first, so it starts in the right state.
        onFinish(outcome)
        isPresented = false
    }

    // MARK: - DEBUG trigger (DECISIONS.md 2026-10-01)

    #if DEBUG
    /// Shows onboarding whatever the saved place, permission and completed
    /// flag say. Temporary: remove before the 1.0 App Store build.
    static let forceLaunchArgument = "-forceOnboarding"

    /// Followed by `landing`, `upsell` or `declined`: the page onboarding
    /// starts on. Anything else, or nothing, is the landing.
    static let pageLaunchArgument = "-onboardingPage"

    /// `-onboardingPage`'s values.
    static let debugPageNames: [String: Step] = [
        "landing": .landing,
        "upsell": .locationUpsell,
        "declined": .locationDeclined,
    ]

    /// The page named after `-onboardingPage`, if any.
    static func debugPage(in arguments: [String]) -> Step? {
        guard let index = arguments.firstIndex(of: pageLaunchArgument),
              arguments.indices.contains(index + 1) else { return nil }
        return debugPageNames[arguments[index + 1]]
    }

    /// Call once at launch with the process's arguments. `-forceOnboarding`
    /// shows it; `-onboardingPage` picks the page whenever it shows.
    func applyDebugLaunchArguments(_ arguments: [String]) {
        let page = Self.debugPage(in: arguments)
        if arguments.contains(Self.forceLaunchArgument) {
            debugShow(startingAt: page ?? .landing)
        } else if isPresented, let page {
            step = page
        }
    }

    /// The forced flow, from launch or the main screen's Show onboarding
    /// button. Changes nothing stored: no flag, place or permission.
    func debugShow(startingAt page: Step = .landing) {
        isForced = true
        isRequestingPermission = false
        isAwaitingSettingsFromUpsell = false
        step = page
        isDeclinedForcedWhileAuthorized = page == .locationDeclined
            && locationService.authorizationState.isAuthorized
        isPresented = true
    }
    #endif
}
