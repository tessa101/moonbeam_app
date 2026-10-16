import SwiftUI
import Testing
import UIKit
@testable import moonbeam_app

@Suite("Sentence token buttons", .serialized, .timeLimit(.minutes(1)))
@MainActor
struct SentenceTokenTests {
    nonisolated enum Scenario: String, CaseIterable, Sendable { case today, longCity, otherDate, otherYear }
    nonisolated private static let fixtures = Scenario.allCases.flatMap { scenario in
        [CGFloat(375), CGFloat(402)].map { (scenario, $0) }
    }

    @Test("Token targets follow rendered text, including wrapped words and icons", arguments: fixtures,
          [DynamicTypeSize.large, .accessibility1, .accessibility5])
    func layout(fixture: (Scenario, CGFloat), size: DynamicTypeSize) async throws {
        let (scenario, width) = fixture
        let model = LocationViewModel(
            locationService: FakeLocationService(), placeSearch: FakePlaceSearchService(),
            placeStore: InMemoryPlaceStore(), moonService: FakeMoonService(), headingService: FakeHeadingService(),
            now: { Date(timeIntervalSince1970: 1_791_000_000) }
        )
        model.select(scenario == .longCity ? .ranchoSantaMargarita : .irvine)
        if scenario == .otherDate { model.nextDay() }
        if scenario == .otherYear {
            model.calendarDate = Date(timeIntervalSince1970: 1_791_000_000 + 180 * 86_400)
            model.confirmCalendarDraft()
        }
        let probe = SentenceTokenProbe()
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: width, height: 1_600)
        let host = UIHostingController(rootView:
            MadlibSentence(viewModel: model, onTokenFrames: { kind, frames in
                if kind == .date { probe.date = frames } else { probe.place = frames }
            })
            .padding(.horizontal, Theme.Metrics.screenMargin)
            .padding(.top, 30)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Theme.Colors.bg)
            .environment(\.dynamicTypeSize, size)
        )
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while (probe.date.isEmpty || probe.place.isEmpty) && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(16))
        }
        try await Task.sleep(for: .milliseconds(250))
        #expect(!probe.date.isEmpty && !probe.place.isEmpty)
        for rect in probe.date + probe.place {
            #expect(rect.width >= 44 && rect.height >= 44)
            #expect(rect.minX >= 0 && rect.maxX <= width + 1)
        }
        for date in probe.date { for place in probe.place {
            #expect(!date.intersects(place), "Wrong token can receive a tap: \(date), \(place)")
        }}
        if size == .accessibility5 {
            #expect(probe.place.count > 1, "The fixture must exercise a wrapped token")
        }
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("moonbeam-5.13.4")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = "\(scenario.rawValue)-\(Int(width))-\(size)"
        try #require(image.pngData()).write(to: directory.appendingPathComponent(name + ".png"))
        let frames = ["date": probe.date.map { NSCoder.string(for: $0) }, "place": probe.place.map { NSCoder.string(for: $0) }]
        try JSONSerialization.data(withJSONObject: frames, options: .prettyPrinted)
            .write(to: directory.appendingPathComponent(name + ".json"))
        let nodes = Self.accessibilityNodes(host.view)
        let date = try #require(nodes.first { $0.accessibilityLabel?.hasPrefix("Date,") == true })
        let place = try #require(nodes.first { $0.accessibilityLabel?.hasPrefix("Place,") == true })
        #expect(date.accessibilityTraits.contains(.button) && place.accessibilityTraits.contains(.button))
        // Native accessibility frames round to screen pixels. The actual
        // touch geometry above must meet 44 pt without this tolerance.
        let pixel = 1 / window.screen.scale
        #expect(date.accessibilityFrame.height >= 44 - pixel && place.accessibilityFrame.height >= 44 - pixel,
                "Native frames: date \(date.accessibilityFrame), place \(place.accessibilityFrame)")
        #expect(date.accessibilityActivate())
        #expect(model.isCalendarPresented && !model.isSearchPresented)
        model.isCalendarPresented = false
        #expect(place.accessibilityActivate())
        #expect(model.isSearchPresented && !model.isCalendarPresented)

    }

    @Test("A detecting place leaves the accessibility tree, then returns with its new label")
    func pendingPlace() async throws {
        let location = FakeLocationService(authorizationState: .authorized, placeResult: .success(.marVista))
        location.holdsFixes = true
        let model = LocationViewModel(locationService: location, placeSearch: FakePlaceSearchService(),
                                      placeStore: InMemoryPlaceStore(), moonService: FakeMoonService(),
                                      headingService: FakeHeadingService())
        model.select(.irvine)
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let host = UIHostingController(rootView: MadlibSentence(viewModel: model))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { location.releaseFixes(); window.isHidden = true }
        try await Task.sleep(for: .milliseconds(250))
        #expect(Self.accessibilityNodes(host.view).contains { $0.accessibilityLabel?.hasPrefix("Place,") == true })
        let detection = Task { await model.useMyLocation() }
        defer { detection.cancel() }
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while location.heldFixCount == 0 && ContinuousClock.now < deadline { await Task.yield() }
        #expect(location.heldFixCount > 0)
        try await Task.sleep(for: .milliseconds(100))
        #expect(!Self.accessibilityNodes(host.view).contains { $0.accessibilityLabel?.hasPrefix("Place,") == true })
        location.releaseFixes()
        await detection.value
        try await Task.sleep(for: .milliseconds(600))
        #expect(Self.accessibilityNodes(host.view).contains {
            $0.accessibilityLabel?.hasPrefix("Place, Los Angeles") == true
        })
    }

    private static func accessibilityNodes(_ node: NSObject, depth: Int = 0) -> [NSObject] {
        guard depth < 8 else { return [] }
        var nodes = [node]
        if let children = node.accessibilityElements as? [NSObject] {
            for child in children { nodes += accessibilityNodes(child, depth: depth + 1) }
        } else if let view = node as? UIView {
            for child in view.subviews { nodes += accessibilityNodes(child, depth: depth + 1) }
        }
        return nodes
    }

}

@MainActor
private final class SentenceTokenProbe {
    var date: [CGRect] = []
    var place: [CGRect] = []
}
