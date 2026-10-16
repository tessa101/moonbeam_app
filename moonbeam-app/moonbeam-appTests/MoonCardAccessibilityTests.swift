import SwiftUI
import Testing
import UIKit
@testable import moonbeam_app

/// Exercise the real button style and header layout at both phone widths.
@Suite("Moon card accessibility", .serialized, .timeLimit(.minutes(1)))
@MainActor
struct MoonCardAccessibilityTests {
    @Test("Day controls share the full row at AX sizes; standard controls stay compact",
          arguments: [CGFloat(335), 362],
          [DynamicTypeSize.large, .accessibility1, .accessibility2, .accessibility3, .accessibility5])
    func dayControlFrames(width: CGFloat, size: DynamicTypeSize) async throws {
        let viewModel = Self.makeViewModel()
        let table = try #require(viewModel.moonTable)
        let probe = DayStepLayoutProbe()
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: width, height: 1800)
        window.rootViewController = UIHostingController(rootView:
            MoonCard(viewModel: viewModel, table: table, dayStepLayoutProbe: probe)
                .environment(\.dynamicTypeSize, size)
                .frame(width: width)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxHeight: .infinity, alignment: .top)
        )
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while probe.frames.count < 2 && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(16))
        }
        let previous = try #require(probe.frames[.previous])
        let next = try #require(probe.frames[.next])
        #expect(abs(previous.width - next.width) < 1)
        #expect(abs(previous.minY - next.minY) < 1)
        #expect(previous.maxX <= next.minX)
        #expect(previous.minX >= 0 && next.maxX <= width + 1)
        if size.isAccessibilitySize {
            #expect(previous.height == 60 && next.height == 60)
            #expect(previous.width > width * 0.4)
            #expect(abs(next.minX - previous.maxX - 12) < 1)
        } else {
            #expect(previous.width == 44 && previous.height == 44)
            #expect(next.width == 44 && next.height == 44)
        }

        // Preserve the full card for the default/AX visual review, including
        // content below the screen. The renderer does not truncate to a
        // phone viewport, so missing content is visible in these artifacts.
        let renderer = ImageRenderer(content:
            MoonCard(viewModel: viewModel, table: table)
                .environment(\.dynamicTypeSize, size)
                .environment(\.colorScheme, .dark)
                .frame(width: width)
        )
        renderer.proposedSize = ProposedViewSize(width: width, height: nil)
        let image = try #require(renderer.uiImage)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("moonbeam-5.5a", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try #require(image.pngData()).write(to:
            directory.appendingPathComponent("card-\(Int(width))-\(size).png")
        )
    }

    private static func makeViewModel() -> LocationViewModel {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Place.irvine.timeZone
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 2, hour: 7, minute: 53))
            ?? Date(timeIntervalSince1970: 0)
        let here = Place(name: "Irvine", region: "CA", latitude: Place.irvine.latitude,
                         longitude: Place.irvine.longitude, timeZone: Place.irvine.timeZone, isCurrentLocation: true)
        let model = LocationViewModel(
            locationService: FakeLocationService(authorizationState: .authorized, placeResult: .success(here)),
            placeSearch: FakePlaceSearchService(),
            placeStore: InMemoryPlaceStore(),
            moonService: AstronomyEngineMoonService(),
            headingService: FakeHeadingService(),
            deviceTimeZone: Place.irvine.timeZone,
            now: { now }
        )
        model.select(here)
        return model
    }
}
