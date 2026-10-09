//
//  DayStepAnimationTests.swift
//  moonbeam-appTests
//

import SwiftUI
import Testing
import UIKit
@testable import moonbeam_app

/// COMPASS-1.1.md §9.19: sample both day-arrow frames throughout the
/// post-tap animation, rather than checking only the settled card.
@Suite("Day-step animation layout")
@MainActor
struct DayStepAnimationTests {

    private struct Target: CustomStringConvertible {
        let month: Int
        let day: Int

        var description: String { "2026-\(month)-\(day)" }
    }

    /// The four device-video failures plus ordinary dates spread through the
    /// same range. Each target is entered with both the previous and next
    /// arrow.
    private static let targets = [
        Target(month: 10, day: 14),
        Target(month: 10, day: 19),
        Target(month: 10, day: 23),
        Target(month: 10, day: 26),
        Target(month: 10, day: 28),
        Target(month: 11, day: 5),
        Target(month: 11, day: 11),
    ]

    private static let sampleInterval = Duration.milliseconds(16)
    private static let sampleCount = 32
    private static let frameTolerance: CGFloat = 0.01

    @Test("Both arrows stay fixed for every 16 ms sample after a day step")
    func arrowsStayFixedDuringTransition() async throws {
        let viewModel = Self.makeViewModel()
        let probe = DayStepLayoutProbe()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.rootViewController = UIHostingController(
            rootView: DayStepHarness(viewModel: viewModel, probe: probe)
        )
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        try await Self.settle()
        let restingFrames = try Self.requireBothFrames(probe)

        for target in Self.targets {
            try await Self.sampleArrival(
                on: target,
                using: .next,
                viewModel: viewModel,
                probe: probe,
                restingFrames: restingFrames
            )
            try await Self.sampleArrival(
                on: target,
                using: .previous,
                viewModel: viewModel,
                probe: probe,
                restingFrames: restingFrames
            )
        }
    }

    private static func sampleArrival(
        on target: Target,
        using direction: DayStepDirection,
        viewModel: LocationViewModel,
        probe: DayStepLayoutProbe,
        restingFrames: [DayStepDirection: CGRect]
    ) async throws {
        let neighbor = direction == .next ? target.day - 1 : target.day + 1
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            viewModel.select(day: DateComponents(year: 2026, month: target.month, day: neighbor))
        }
        try await settle()

        withAnimation(PressFeedback.animation) {
            switch direction {
            case .previous: viewModel.previousDay()
            case .next: viewModel.nextDay()
            }
        }

        for sample in 0..<sampleCount {
            let frames = try requireBothFrames(probe)
            for arrow in [DayStepDirection.previous, .next] {
                let frame = try #require(frames[arrow])
                let resting = try #require(restingFrames[arrow])
                #expect(
                    Self.matches(frame, resting),
                    "\(arrow) moved at sample \(sample) entering \(target) with \(direction): \(frame), resting: \(resting)"
                )
            }
            try await Task.sleep(for: sampleInterval)
        }
    }

    private static func matches(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.minX - rhs.minX) < frameTolerance
            && abs(lhs.minY - rhs.minY) < frameTolerance
            && abs(lhs.width - rhs.width) < frameTolerance
            && abs(lhs.height - rhs.height) < frameTolerance
    }

    private static func requireBothFrames(_ probe: DayStepLayoutProbe) throws -> [DayStepDirection: CGRect] {
        #expect(probe.frames[.previous] != nil)
        #expect(probe.frames[.next] != nil)
        return probe.frames
    }

    private static func settle() async throws {
        try await Task.sleep(for: .milliseconds(100))
    }

    private static func makeViewModel() -> LocationViewModel {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Place.irvine.timeZone
        let now = calendar.date(
            from: DateComponents(year: 2026, month: 10, day: 8, hour: 12)
        ) ?? Date(timeIntervalSince1970: 0)
        let here = Place(
            name: "Irvine",
            region: "CA",
            latitude: Place.irvine.latitude,
            longitude: Place.irvine.longitude,
            timeZone: Place.irvine.timeZone,
            isCurrentLocation: true
        )
        let viewModel = LocationViewModel(
            locationService: FakeLocationService(
                authorizationState: .authorized,
                placeResult: .success(here)
            ),
            placeSearch: FakePlaceSearchService(),
            placeStore: InMemoryPlaceStore(),
            moonService: AstronomyEngineMoonService(),
            headingService: FakeHeadingService(),
            deviceTimeZone: Place.irvine.timeZone,
            now: { now }
        )
        viewModel.select(here)
        return viewModel
    }
}

@MainActor
private struct DayStepHarness: View {
    let viewModel: LocationViewModel
    let probe: DayStepLayoutProbe

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MadlibSentence(viewModel: viewModel)
            if let table = viewModel.moonTable {
                MoonCard(
                    viewModel: viewModel,
                    table: table,
                    dayStepLayoutProbe: probe
                )
                .padding(.top, Theme.Metrics.sentenceToCard)
            }
        }
        .padding(.horizontal, Theme.Metrics.screenMargin)
        .padding(.top, Theme.Metrics.contentTopSpacing)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.Colors.bg)
        .environment(\.dynamicTypeSize, .large)
    }
}
