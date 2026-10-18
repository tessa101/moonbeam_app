//
//  TestDependencyDefaults.swift
//  moonbeam-appTests
//

import Foundation
@testable import moonbeam_app

/// Test-target-only defaults. Shipping and preview construction must name
/// every service that can affect persisted state or connectivity.
extension LocationViewModel {

    convenience init(
        locationService: any LocationService,
        placeSearch: any PlaceSearchService,
        placeStore: any PlaceStore,
        moonService: any MoonService,
        headingService: any HeadingService,
        reducesMotion: @escaping () -> Bool = { false },
        fetchTimeout: Duration = LocationViewModel.defaultFetchTimeout,
        fetchTimeoutSleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        deviceTimeZone: TimeZone = .current,
        now: @escaping () -> Date = Date.init,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        placeChangeSleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        loaderNow: @escaping () -> Date = Date.init
    ) {
        self.init(
            locationService: locationService,
            placeSearch: placeSearch,
            placeStore: placeStore,
            moonService: moonService,
            headingService: headingService,
            onboardingStore: InMemoryOnboardingStore(),
            connectivity: FakeConnectivityService(),
            reducesMotion: reducesMotion,
            fetchTimeout: fetchTimeout,
            fetchTimeoutSleep: fetchTimeoutSleep,
            deviceTimeZone: deviceTimeZone,
            now: now,
            sleep: sleep,
            placeChangeSleep: placeChangeSleep,
            loaderNow: loaderNow
        )
    }

    convenience init(
        locationService: any LocationService,
        placeSearch: any PlaceSearchService,
        placeStore: any PlaceStore,
        moonService: any MoonService,
        headingService: any HeadingService,
        onboardingStore: any OnboardingStore,
        reducesMotion: @escaping () -> Bool = { false },
        fetchTimeout: Duration = LocationViewModel.defaultFetchTimeout,
        fetchTimeoutSleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        deviceTimeZone: TimeZone = .current,
        now: @escaping () -> Date = Date.init,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        placeChangeSleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        loaderNow: @escaping () -> Date = Date.init
    ) {
        self.init(
            locationService: locationService,
            placeSearch: placeSearch,
            placeStore: placeStore,
            moonService: moonService,
            headingService: headingService,
            onboardingStore: onboardingStore,
            connectivity: FakeConnectivityService(),
            reducesMotion: reducesMotion,
            fetchTimeout: fetchTimeout,
            fetchTimeoutSleep: fetchTimeoutSleep,
            deviceTimeZone: deviceTimeZone,
            now: now,
            sleep: sleep,
            placeChangeSleep: placeChangeSleep,
            loaderNow: loaderNow
        )
    }

    convenience init(
        locationService: any LocationService,
        placeSearch: any PlaceSearchService,
        placeStore: any PlaceStore,
        moonService: any MoonService,
        headingService: any HeadingService,
        connectivity: any ConnectivityService,
        reducesMotion: @escaping () -> Bool = { false },
        fetchTimeout: Duration = LocationViewModel.defaultFetchTimeout,
        fetchTimeoutSleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        deviceTimeZone: TimeZone = .current,
        now: @escaping () -> Date = Date.init,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        placeChangeSleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        loaderNow: @escaping () -> Date = Date.init
    ) {
        self.init(
            locationService: locationService,
            placeSearch: placeSearch,
            placeStore: placeStore,
            moonService: moonService,
            headingService: headingService,
            onboardingStore: InMemoryOnboardingStore(),
            connectivity: connectivity,
            reducesMotion: reducesMotion,
            fetchTimeout: fetchTimeout,
            fetchTimeoutSleep: fetchTimeoutSleep,
            deviceTimeZone: deviceTimeZone,
            now: now,
            sleep: sleep,
            placeChangeSleep: placeChangeSleep,
            loaderNow: loaderNow
        )
    }
}

extension CompassViewModel {

    convenience init(
        headingService: any HeadingService,
        moonService: any MoonService,
        now: @escaping () -> Date = Date.init,
        moonRefreshInterval: Duration = CompassViewModel.defaultMoonRefreshInterval,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        entranceSleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
        reducesMotion: @escaping () -> Bool = { false }
    ) {
        self.init(
            headingService: headingService,
            moonService: moonService,
            onboardingStore: InMemoryOnboardingStore(),
            now: now,
            moonRefreshInterval: moonRefreshInterval,
            sleep: sleep,
            entranceSleep: entranceSleep,
            reducesMotion: reducesMotion
        )
    }
}
