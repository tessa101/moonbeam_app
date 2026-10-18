import SwiftUI
import Testing
import UIKit
@testable import moonbeam_app

@Suite("Location screen scrolling", .serialized, .timeLimit(.minutes(1)))
@MainActor
struct LocationScreenScrollingTests {
    @Test("Large-text content has a scroll range and its bottom is reachable",
          arguments: [CGSize(width: 375, height: 667), CGSize(width: 402, height: 874)],
          [DynamicTypeSize.accessibility1, .accessibility3, .accessibility5])
    func bottomIsReachable(phone: CGSize, size: DynamicTypeSize) async throws {
        let here = Place(name: "Irvine", region: "CA", latitude: Place.irvine.latitude,
                         longitude: Place.irvine.longitude, timeZone: Place.irvine.timeZone, isCurrentLocation: true)
        let now = Date(timeIntervalSince1970: 1_791_000_000)
        let model = LocationViewModel(
            locationService: FakeLocationService(authorizationState: .authorized, placeResult: .success(here)),
            placeSearch: FakePlaceSearchService(), placeStore: InMemoryPlaceStore(),
            moonService: AstronomyEngineMoonService(), headingService: FakeHeadingService(),
            deviceTimeZone: here.timeZone, now: { now }
        )
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: phone)
        let host = UIHostingController(rootView:
            LocationScreen(viewModel: model)
                .environment(\.dynamicTypeSize, size)
        )
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; model.compass.setOnScreen(false) }
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while (model.launchStage != .ready || Self.scrollView(in: host.view) == nil) && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(16))
        }
        try await Task.sleep(for: .milliseconds(600))
        let scroll = try #require(Self.scrollView(in: host.view))
        let maximumOffset = scroll.contentSize.height + scroll.adjustedContentInset.bottom - scroll.bounds.height
        #expect(scroll.isScrollEnabled && scroll.panGestureRecognizer.isEnabled)
        let diagnostic = "\(phone), \(size): content \(scroll.contentSize.height), viewport \(scroll.bounds.height), scroll range \(maximumOffset)"
        #expect(maximumOffset > 200, "\(diagnostic)")
        guard maximumOffset > 200 else { return }
        scroll.setContentOffset(CGPoint(x: 0, y: maximumOffset), animated: false)
        // Bringing the compass on screen starts its sensors and may animate
        // a bottom accuracy note. Reach the final bottom after that inset
        // settles, rather than comparing with its intermediate animation.
        try await Task.sleep(for: .milliseconds(600))
        let settledMaximum = scroll.contentSize.height + scroll.adjustedContentInset.bottom - scroll.bounds.height
        scroll.setContentOffset(CGPoint(x: 0, y: settledMaximum), animated: false)
        try await Task.sleep(for: .milliseconds(100))
        #expect(!model.compass.showsPinnedBar, "The pinned summary must leave when the real compass is visible")
        #expect(abs(scroll.contentOffset.y - settledMaximum) < 2)
        #expect(abs(scroll.bounds.maxY - scroll.contentSize.height - scroll.adjustedContentInset.bottom) < 2)
    }

    private static func scrollView(in view: UIView) -> UIScrollView? {
        if let scroll = view as? UIScrollView { return scroll }
        return view.subviews.lazy.compactMap { scrollView(in: $0) }.first
    }

    @Test("The short location guide still fills the viewport without moving its top",
          arguments: [CGSize(width: 375, height: 667), CGSize(width: 402, height: 874)])
    func promptCollapseKeepsTop(phone: CGSize) async throws {
        let model = LocationViewModel(
            locationService: FakeLocationService(authorizationState: .denied),
            placeSearch: FakePlaceSearchService(), placeStore: InMemoryPlaceStore(lastViewed: .irvine),
            moonService: AstronomyEngineMoonService(), headingService: FakeHeadingService(),
            deviceTimeZone: Place.irvine.timeZone
        )
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: phone)
        let host = UIHostingController(rootView: LocationScreen(viewModel: model).environment(\.dynamicTypeSize, .large))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while Self.scrollView(in: host.view) == nil && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(16))
        }
        try await Task.sleep(for: .milliseconds(600))
        let scroll = try #require(Self.scrollView(in: host.view))
        let topOffset = -scroll.adjustedContentInset.top
        scroll.setContentOffset(CGPoint(x: 0, y: topOffset), animated: false)
        model.compass.dismissLocationPrompt()
        try await Task.sleep(for: .milliseconds(900))
        #expect(model.compass.isLocationPromptDismissed)
        #expect(abs(scroll.contentOffset.y - topOffset) < 2)
        let visibleHeight = scroll.bounds.height - scroll.adjustedContentInset.top - scroll.adjustedContentInset.bottom
        #expect(scroll.contentSize.height >= visibleHeight)
        model.compass.reopenLocationPrompt()
        try await Task.sleep(for: .milliseconds(900))
        #expect(abs(scroll.contentOffset.y - topOffset) < 2)
    }
}
