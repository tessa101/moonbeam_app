import SwiftUI
import Testing
import UIKit
@testable import moonbeam_app

@Suite("Compass accessibility layout", .serialized, .timeLimit(.minutes(1)))
@MainActor
struct CompassAccessibilityLayoutTests {
    @Test("Wrapped lock text reserves space above the dial and releases it again",
          arguments: [CGFloat(375), 402],
          [DynamicTypeSize.accessibility1, .accessibility3, .accessibility5])
    func wrappedReadout(width: CGFloat, size: DynamicTypeSize) async throws {
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        let place = Place(name: "Irvine", region: "CA", latitude: Place.irvine.latitude,
                          longitude: Place.irvine.longitude, timeZone: Place.irvine.timeZone, isCurrentLocation: true)
        let heading = FakeHeadingService()
        let model = CompassViewModel(headingService: heading, moonService: FakeMoonService(), now: { date },
                                    entranceSleep: { _ in })
        model.update(CompassContext(
            place: place, detectedPlace: place, authState: .authorized,
            moonDay: MoonDay(place: place,
                            rise: MoonEvent(date: date, azimuth: 72),
                            set: MoonEvent(date: date, azimuth: 288),
                            phase: .full, phaseAngle: FakeMoonService.fullMoonPhaseAngle,
                            illumination: FakeMoonService.fullyLit), isToday: true
        ))
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let probe = CompassLayoutProbe()
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: width, height: 1_200)
        window.rootViewController = UIHostingController(rootView:
            VStack(spacing: 0) {
                CompassView(viewModel: model, heightBudget: 100, onTurnOnLocation: {},
                            onDialCentreChange: { probe.centre = $0 },
                            onReadoutTopChange: { probe.top = $0 })
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.Metrics.screenMargin)
            .padding(.top, 40)
            .background(Theme.Colors.bg)
            .environment(\.dynamicTypeSize, size)
        )
        window.makeKeyAndVisible()
        model.setOnScreen(true)
        defer { window.isHidden = true; model.setOnScreen(false) }
        await Task.yield()
        heading.send(HeadingReading(trueHeading: 190, accuracy: 3))
        try await waitUntil { model.heading == 190 && probe.centre != nil }
        try await Task.sleep(for: .milliseconds(600))
        let before = try #require(probe.centre)
        let top = try #require(probe.top)
        try save(window, name: "heading-\(Int(width))-\(size)")

        heading.send(HeadingReading(trueHeading: 72, accuracy: 3))
        try await waitUntil { model.lockedKind == .moonrise }
        try await Task.sleep(for: .milliseconds(600))
        let locked = try #require(probe.centre)
        #expect(locked > before + 10, "Wrapped pill needs more height than the single-line heading")
        #expect(abs((probe.top ?? 0) - top) < 1)
        try save(window, name: "locked-\(Int(width))-\(size)")

        heading.send(HeadingReading(trueHeading: 190, accuracy: 3))
        try await waitUntil { model.lockedKind == nil }
        try await Task.sleep(for: .milliseconds(600))
        #expect(abs((probe.centre ?? 0) - before) < 1)
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while !condition() && ContinuousClock.now < deadline { await Task.yield() }
        #expect(condition())
    }

    private func save(_ window: UIWindow, name: String) throws {
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("moonbeam-5.5c")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try #require(image.pngData()).write(to: directory.appendingPathComponent(name + ".png"))
    }
}

@MainActor
private final class CompassLayoutProbe {
    var centre: CGFloat?
    var top: CGFloat?
}
