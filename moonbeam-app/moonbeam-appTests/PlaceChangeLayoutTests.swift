//
//  PlaceChangeLayoutTests.swift
//  moonbeam-appTests
//

import SwiftUI
import Testing
import UIKit
@testable import moonbeam_app

/// LOADER.md §12.9: sample the screen every 16 ms through a slow "Use my
/// location" (the 700 ms fix from Tessa's device video), on the real
/// sentence, card slot and load-in modifiers.
@Suite("Place change layout", .timeLimit(.minutes(1)))
@MainActor
struct PlaceChangeLayoutTests {

    // MARK: - Fixtures

    private static let zone = Place.irvine.timeZone

    /// Irvine as detected; the screen starts on the saved (non-current) Irvine,
    /// so the replacement card has the same rows and height as the old one.
    private static let detectedIrvine = Place(
        name: "Irvine",
        region: "CA",
        latitude: Place.irvine.latitude,
        longitude: Place.irvine.longitude,
        timeZone: zone,
        isCurrentLocation: true
    )

    private static let savedIrvine = Place(
        name: "Irvine",
        region: "CA",
        latitude: Place.irvine.latitude,
        longitude: Place.irvine.longitude,
        timeZone: zone
    )

    /// The device video's slow fix. Since 5.10a.7 the skeleton shows at once
    /// and holds at least 350 ms, so this fix lands after the minimum.
    private static let fixDelay = Duration.milliseconds(700)
    private static let sampleInterval = Duration.milliseconds(16)
    /// ~1.3 s: past the fix, the minimum and the card's load-in.
    private static let sampleCount = 80
    private static let frameTolerance: CGFloat = 0.01
    /// "At once", measured with sampling overhead: well under the 400 ms
    /// wait 5.10a.7 removed.
    private static let immediateSkeletonBound = Duration.milliseconds(200)
    /// A sentence line of text has thousands of light pixels; a faded-out
    /// one has none.
    private static let minimumInkPixels = 200

    // MARK: - Test

    @Test("No blank sentence, no date reset, nothing below moving, skeleton ≥ 350 ms", .timeLimit(.minutes(1)))
    func slowUseMyLocationKeepsSentenceAndSlot() async throws {
        let location = FakeLocationService(authorizationState: .authorized, placeResult: .success(Self.detectedIrvine))
        let viewModel = Self.makeViewModel(location: location)
        await viewModel.start()
        viewModel.select(Self.savedIrvine)
        viewModel.select(day: DateComponents(year: 2026, month: 10, day: 16))
        let selectedDate = Self.dateTokenText(viewModel)
        #expect(selectedDate != "today")

        let probe = PlaceChangeProbe()
        // In the host app's scene: a window without one is never drawn, so
        // `drawHierarchy` would capture nothing.
        let scene = try #require(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        window.rootViewController = UIHostingController(
            rootView: PlaceChangeHarness(viewModel: viewModel, probe: probe)
        )
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        try await Task.sleep(for: .milliseconds(800))

        let restingBelow = try #require(probe.belowFrame)
        let restingSentence = try #require(probe.sentenceFrame)
        #expect(
            Self.inkPixels(in: restingSentence, of: window) >= Self.minimumInkPixels,
            "resting sentence \(restingSentence) drew no ink: \(Self.captureDescription(restingSentence, of: window))"
        )
        // Control: an empty strip of background below the card reads as
        // blank, so the check above can tell a missing sentence.
        let emptyStrip = CGRect(x: restingSentence.minX, y: restingBelow.maxY + 8,
                                width: restingSentence.width, height: restingSentence.height)
        #expect(Self.inkPixels(in: emptyStrip, of: window) < Self.minimumInkPixels)

        location.fixDelay = Self.fixDelay
        let start = ContinuousClock.now
        let locate = Task { await viewModel.useMyLocation() }

        var skeletonShown: ContinuousClock.Instant?
        var skeletonGone: ContinuousClock.Instant?
        var firstSkeletonSample: Int?
        for sample in 0..<Self.sampleCount {
            let sentence = try #require(probe.sentenceFrame, "sentence absent at sample \(sample)")
            #expect(
                Self.inkPixels(in: sentence, of: window) >= Self.minimumInkPixels,
                "sentence blank at sample \(sample)"
            )
            #expect(Self.dateTokenText(viewModel) == selectedDate, "date reset at sample \(sample)")
            let below = try #require(probe.belowFrame)
            #expect(Self.matches(below, restingBelow), "content below moved at sample \(sample): \(below) vs \(restingBelow)")

            let showsSkeleton = viewModel.cardPlaceholder == .finding
            if showsSkeleton, skeletonShown == nil {
                skeletonShown = .now
                firstSkeletonSample = sample
            }
            if !showsSkeleton, skeletonShown != nil, skeletonGone == nil { skeletonGone = .now }
            try await Task.sleep(for: Self.sampleInterval)
        }
        // A time limit cancels the test; pass that on to the fix.
        await withTaskCancellationHandler {
            await locate.value
        } onCancel: {
            locate.cancel()
        }

        #expect(viewModel.place == Self.detectedIrvine)
        let shown = try #require(skeletonShown, "the skeleton never showed for a 700 ms fix")
        let gone = try #require(skeletonGone)
        // 5.10a.7: no 400 ms wait. The skeleton is in by the first sample
        // after the replacement begins (sample 0 may land before the task
        // has run, so allow sample 1).
        #expect((firstSkeletonSample ?? .max) <= 1, "skeleton first seen at sample \(firstSkeletonSample ?? -1)")
        // Wall clock includes each sample's screen capture (~30 ms), so the
        // bound is loose; it still fails if a 400 ms wait comes back.
        #expect(start.duration(to: shown) < Self.immediateSkeletonBound)
        // Sampled, so allow one interval of slack on the minimum.
        #expect(shown.duration(to: gone) >= LocationViewModel.placeSkeletonMinimum - Self.sampleInterval)
    }

    // MARK: - Helpers

    private static func makeViewModel(location: FakeLocationService) -> LocationViewModel {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: 12)) ?? Date(timeIntervalSince1970: 0)
        return LocationViewModel(
            locationService: location,
            placeSearch: FakePlaceSearchService(),
            placeStore: InMemoryPlaceStore(),
            moonService: AstronomyEngineMoonService(),
            headingService: FakeHeadingService(),
            deviceTimeZone: zone,
            now: { now }
        )
    }

    private static func dateTokenText(_ viewModel: LocationViewModel) -> String? {
        viewModel.madlibSentence(allowsBreaksInsideTokens: true).tokens.first { $0.kind == .date }?.text
    }

    private static func matches(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.minY - rhs.minY) < frameTolerance && abs(lhs.height - rhs.height) < frameTolerance
    }

    /// The capture's format and its brightest pixel, for a failure message.
    private static func captureDescription(_ rect: CGRect, of window: UIWindow) -> String {
        let image = capture(rect, of: window)
        guard let cgImage = image.cgImage,
              let data = cgImage.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { return "no image" }
        var brightest: UInt8 = 0
        for index in 0..<CFDataGetLength(data) where bytes[index] > brightest && index % 4 != 3 {
            brightest = bytes[index]
        }
        return "\(cgImage.width)×\(cgImage.height), \(cgImage.bitsPerPixel) bpp, brightest byte \(brightest)"
    }

    /// `rect` as currently drawn. `.standard` is 8 bits per channel: the
    /// default extended range is 16, and byte reads of it found no ink.
    private static func capture(_ rect: CGRect, of window: UIWindow) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(bounds: rect, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
    }

    /// Light (text) pixels in `rect` as currently drawn, animations
    /// included (`afterScreenUpdates: false` captures the screen as shown).
    private static func inkPixels(in rect: CGRect, of window: UIWindow) -> Int {
        guard let cgImage = capture(rect, of: window).cgImage,
              let data = cgImage.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { return 0 }
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        var count = 0
        for y in 0..<cgImage.height {
            for x in 0..<cgImage.width {
                let offset = y * cgImage.bytesPerRow + x * bytesPerPixel
                // The sentence is light text on the dark background.
                if bytes[offset] > 128, bytes[offset + 1] > 128, bytes[offset + 2] > 128 {
                    count += 1
                }
            }
        }
        return count
    }
}

/// The sentence's and the marker's frames in the window.
@MainActor
private final class PlaceChangeProbe {
    var sentenceFrame: CGRect?
    var belowFrame: CGRect?
}

/// The main screen's top: the sentence, the card slot and a marker for the
/// content below, with the same load-in modifiers as `LocationScreen`.
@MainActor
private struct PlaceChangeHarness: View {
    let viewModel: LocationViewModel
    let probe: PlaceChangeProbe

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MadlibSentence(viewModel: viewModel)
                .contentLoadIn(.sentence)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { probe.sentenceFrame = $0 }
            PlaceCardRegion(viewModel: viewModel)
                .padding(.top, Theme.Metrics.sentenceToCard)
                .contentLoadIn(.card, generation: viewModel.cardLoadInGeneration)
            Color.clear
                .frame(height: 1)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { probe.belowFrame = $0 }
        }
        .padding(.horizontal, Theme.Metrics.screenMargin)
        .padding(.top, Theme.Metrics.contentTopSpacing)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.Colors.bg)
        .environment(\.dynamicTypeSize, .large)
    }
}
