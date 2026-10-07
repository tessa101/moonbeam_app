//
//  OnboardingStoreTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// `UserDefaultsOnboardingStore`: the completed flag survives a relaunch,
/// and the DEBUG reset clears it.
@Suite("Onboarding store")
@MainActor
final class OnboardingStoreTests {

    /// A suite per test, so tests never touch the app's own defaults.
    private let suiteName = "OnboardingStoreTests.\(UUID().uuidString)"
    private let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    @Test("Starts not completed")
    func startsNotCompleted() {
        #expect(!UserDefaultsOnboardingStore(defaults: defaults).isOnboardingCompleted)
    }

    @Test("Completed survives a relaunch")
    func completedSurvivesRelaunch() {
        UserDefaultsOnboardingStore(defaults: defaults).isOnboardingCompleted = true

        #expect(UserDefaultsOnboardingStore(defaults: defaults).isOnboardingCompleted)
    }

    @Test("The first-find pass starts unseen and survives a relaunch (LOADER.md §11.2.2)")
    func firstFindPassSurvivesRelaunch() {
        #expect(!UserDefaultsOnboardingStore(defaults: defaults).hasSeenFirstFindPass)
        UserDefaultsOnboardingStore(defaults: defaults).hasSeenFirstFindPass = true
        #expect(UserDefaultsOnboardingStore(defaults: defaults).hasSeenFirstFindPass)
    }

    #if DEBUG
    @Test("The DEBUG reset clears the first-find pass too")
    func debugResetClearsFirstFindPass() {
        let store = UserDefaultsOnboardingStore(defaults: defaults)
        store.hasSeenFirstFindPass = true
        store.resetIfRequested(by: ["moonbeam-app", UserDefaultsOnboardingStore.resetLaunchArgument])
        #expect(!store.hasSeenFirstFindPass)
    }

    @Test("The DEBUG launch argument clears the flag; other arguments don't")
    func debugReset() {
        let store = UserDefaultsOnboardingStore(defaults: defaults)
        store.isOnboardingCompleted = true

        store.resetIfRequested(by: ["moonbeam-app", "-SomethingElse"])
        #expect(store.isOnboardingCompleted)

        store.resetIfRequested(by: ["moonbeam-app", UserDefaultsOnboardingStore.resetLaunchArgument])
        #expect(!store.isOnboardingCompleted)
    }
    #endif
}
