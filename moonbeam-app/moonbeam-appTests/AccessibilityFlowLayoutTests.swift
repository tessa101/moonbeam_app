import SwiftUI
import Testing
import UIKit
@testable import moonbeam_app

/// Exercise real scroll containers, not just unconstrained text renderings.
@Suite("Accessibility flow layouts", .serialized, .timeLimit(.minutes(1)))
@MainActor
struct AccessibilityFlowLayoutTests {
    nonisolated enum Screen: String, CaseIterable, Sendable {
        case landing, upsell, declined, noFix, denied, servicesOff, restricted, calendar, search
        case loaderSearching, loaderPermission
    }

    nonisolated private static func fixtures(_ screens: [Screen]) -> [(Screen, CGSize)] {
        screens.flatMap { screen in
            [CGSize(width: 375, height: 667), CGSize(width: 402, height: 874)].map { (screen, $0) }
        }
    }

    @Test("Onboarding content and actions remain reachable", arguments: fixtures([.landing, .upsell, .declined]),
          [DynamicTypeSize.accessibility1, .accessibility5])
    func onboarding(fixture: (Screen, CGSize), size: DynamicTypeSize) async throws {
        try await layout(fixture: fixture, size: size)
    }

    @Test("Failure messages and pinned actions fit", arguments: fixtures([.noFix, .denied, .servicesOff, .restricted]),
          [DynamicTypeSize.accessibility1, .accessibility5])
    func failures(fixture: (Screen, CGSize), size: DynamicTypeSize) async throws {
        try await layout(fixture: fixture, size: size)
    }

    @Test("Native calendar and search retain reachable content", arguments: fixtures([.calendar, .search]),
          [DynamicTypeSize.accessibility1, .accessibility5])
    func sheets(fixture: (Screen, CGSize), size: DynamicTypeSize) async throws {
        try await layout(fixture: fixture, size: size)
    }

    @Test("Searching and first-permission loader fit at maximum text", arguments: fixtures([.loaderSearching, .loaderPermission]))
    func loaders(fixture: (Screen, CGSize)) async throws {
        try await layout(fixture: fixture, size: .accessibility5)
    }

    private func layout(fixture: (Screen, CGSize), size: DynamicTypeSize) async throws {
        let (screen, phone) = fixture
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: phone)
        let host = UIHostingController(rootView: content(screen)
            .font(Theme.Fonts.body)
            .foregroundStyle(Theme.Colors.textPrimary)
            .background { ScreenBackground() }
            .environment(\.dynamicTypeSize, size))
        // Native controls (DatePicker/TextField) read UIKit traits rather
        // than only SwiftUI's Dynamic Type environment.
        host.traitOverrides.preferredContentSizeCategory = size == .accessibility1
            ? .accessibilityMedium : .accessibilityExtraExtraExtraLarge
        window.rootViewController = host
        window.makeKeyAndVisible()
        #expect(host.traitCollection.preferredContentSizeCategory == (size == .accessibility1
            ? .accessibilityMedium : .accessibilityExtraExtraExtraLarge))
        defer { window.isHidden = true }
        // Includes the final onboarding/failure block's stagger and fade.
        try await Task.sleep(for: .milliseconds(1_200))
        let name = "\(screen.rawValue)-\(Int(phone.width))-\(size)"
        try save(window, name: name + "-top")
        let scrolls = scrollViews(in: host.view).filter { !$0.isHidden && $0.bounds.height > 0 }
        if size == .accessibility5 && [.landing, .upsell, .declined].contains(screen) {
            #expect(scrolls.contains {
                $0.contentSize.height > $0.bounds.height - $0.adjustedContentInset.top - $0.adjustedContentInset.bottom + 1
            }, "\(name): enlarged onboarding must create a real scroll range")
        }
        for scroll in scrolls {
            #expect(scroll.contentSize.width <= scroll.bounds.width + 1,
                    "\(name): content escapes horizontally")
            let bottom = max(-scroll.adjustedContentInset.top,
                             scroll.contentSize.height + scroll.adjustedContentInset.bottom - scroll.bounds.height)
            if bottom > -scroll.adjustedContentInset.top + 1 {
                #expect(scroll.isScrollEnabled && scroll.panGestureRecognizer.isEnabled,
                        "\(name): overflowing content must support touch scrolling")
            }
            scroll.setContentOffset(CGPoint(x: 0, y: bottom), animated: false)
            #expect(abs(scroll.contentOffset.y - bottom) < 2, "\(name): bottom unreachable")
        }
        if [.landing, .upsell, .declined, .calendar, .search].contains(screen) {
            #expect(!scrolls.isEmpty, "\(name): missing scroll container")
        }
        try await Task.sleep(for: .milliseconds(80))
        try save(window, name: name + "-bottom")
    }

    private func content(_ screen: Screen) -> AnyView {
        switch screen {
        case .landing: return AnyView(OnboardingLandingScreen(onGetStarted: {}))
        case .upsell: return AnyView(OnboardingLocationScreen(onUseMyLocation: {}, onSearchInstead: {}))
        case .declined: return AnyView(OnboardingDeclinedScreen(onGotIt: {}, onEnableLocation: {}))
        case .noFix: return AnyView(LocationFailureView(failure: .noFix, onSearch: {}))
        case .denied: return AnyView(LocationFailureView(failure: .permissionDenied, onSearch: {}))
        case .servicesOff: return AnyView(LocationFailureView(failure: .servicesOff, onSearch: {}))
        case .restricted: return AnyView(LocationFailureView(failure: .restricted, onSearch: {}))
        case .calendar:
            return AnyView(CalendarSheet(viewModel: LocationViewModel(
                locationService: FakeLocationService(), placeSearch: FakePlaceSearchService(),
                placeStore: InMemoryPlaceStore(lastViewed: .irvine), moonService: FakeMoonService(),
                headingService: FakeHeadingService()
            ), maximumHeight: 600))
        case .loaderSearching, .loaderPermission:
            let loader = LocationLoader()
            if screen == .loaderPermission { loader.presentMessage(.firstAsk) }
            else { loader.appear() }
            return AnyView(LaunchPhaseCycle(loader: loader, onPrimary: {}, onSearch: {}))
        case .search:
            return AnyView(SearchSheet(viewModel: SearchSheetViewModel(
                placeSearch: FakePlaceSearchService(),
                placeStore: InMemoryPlaceStore(recents: [.irvine, .marVista]),
                showsUseMyLocation: true, onPick: { _ in }, onUseMyLocation: {}
            )))
        }
    }

    private func scrollViews(in view: UIView) -> [UIScrollView] {
        (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap { scrollViews(in: $0) }
    }

    private func save(_ window: UIWindow, name: String) throws {
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("moonbeam-5.5d")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try #require(image.pngData()).write(to: directory.appendingPathComponent(name + ".png"))
    }
}
