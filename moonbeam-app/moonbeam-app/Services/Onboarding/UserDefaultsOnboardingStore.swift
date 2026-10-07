//
//  UserDefaultsOnboardingStore.swift
//  moonbeam-app
//

import Foundation

/// `OnboardingStore` backed by `UserDefaults`: one Bool, read once at launch.
final class UserDefaultsOnboardingStore: OnboardingStore {

    // MARK: - Constants

    private static let completedKey = "onboardingCompleted"
    private static let firstFindPassKey = "hasSeenFirstFindPass"

    // MARK: - State

    private let defaults: UserDefaults

    /// Injectable so tests get their own suite, and "survives a relaunch" can
    /// be tested with a second store over the same suite.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - OnboardingStore

    /// Absent reads as `false`: a new install hasn't seen onboarding.
    var isOnboardingCompleted: Bool {
        get { defaults.bool(forKey: Self.completedKey) }
        set { defaults.set(newValue, forKey: Self.completedKey) }
    }

    /// Absent reads as `false`: a new install's first ride gets the lap.
    var hasSeenFirstFindPass: Bool {
        get { defaults.bool(forKey: Self.firstFindPassKey) }
        set { defaults.set(newValue, forKey: Self.firstFindPassKey) }
    }

    // MARK: - DEBUG reset (DESIGN-1.1.md §5)

    #if DEBUG
    /// Launch argument that clears the flag, so onboarding can be re-run
    /// without reinstalling. It still only shows with no saved place and
    /// location permission not determined.
    static let resetLaunchArgument = "-resetOnboarding"

    /// Clears the flags if `arguments` carries `resetLaunchArgument`.
    func resetIfRequested(by arguments: [String]) {
        guard arguments.contains(Self.resetLaunchArgument) else { return }
        isOnboardingCompleted = false
        hasSeenFirstFindPass = false
    }
    #endif
}
