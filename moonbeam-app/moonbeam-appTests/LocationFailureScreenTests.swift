//
//  LocationFailureScreenTests.swift
//  moonbeam-appTests
//

import CoreGraphics
import Testing
import UIKit
@testable import moonbeam_app

/// STEP-5.10a-LOCATION-FAILURE.md, Chunk 2: each cause's art, copy and
/// actions, and the layout that keeps art, headline and button level across
/// causes.
@Suite("Location failure screen")
struct LocationFailureScreenTests {

    // MARK: - Art

    @Test(
        "Each cause has its art",
        arguments: [
            (LocationFailure.noFix, LocationIllustration.Kind.locationNotFound),
            (.permissionDenied, .permissionOff),
            (.servicesOff, .servicesOff),
            (.restricted, .restricted),
        ]
    )
    func art(failure: LocationFailure, kind: LocationIllustration.Kind) {
        #expect(failure.illustration == kind)
    }

    @Test("Every layer is in the app's asset catalog, on the shared 400 × 520 canvas", arguments: LocationIllustration.Kind.allCases)
    func layersExist(kind: LocationIllustration.Kind) throws {
        for layer in kind.spec.layers {
            let image = try #require(UIImage(named: layer.asset), "missing \(layer.asset)")
            #expect(image.size == IllustrationSpec.viewBox, "\(layer.asset) is \(image.size)")
        }
    }

    // MARK: - Copy

    @Test(
        "Line breaks match the doc's table at the default size",
        arguments: [
            (
                LocationFailure.permissionDenied,
                "Can’t see\nyour location",
                "Allow location access to see\nwhere the moon is from here."
            ),
            (
                .servicesOff,
                "Location\nServices are off",
                "Turn them on to see where\nthe moon is from here."
            ),
            (
                .noFix,
                "Couldn’t find\nyour location",
                "Check your cellular or Wi-Fi\nconnection. We’ll look again\nwhen you come back."
            ),
            (
                .restricted,
                "Can’t see\nyour location",
                "Location access is limited on\nthis iPhone. You can still\nsearch for a city."
            ),
        ]
    )
    func lineBreaks(failure: LocationFailure, headline: String, body: String) {
        let copy = failure.copy
        #expect(copy.headlineLines?.joined(separator: "\n") == headline)
        #expect(copy.bodyLines?.joined(separator: "\n") == body)
    }

    @Test("VoiceOver reads headline and body as one sentence each, without the breaks", arguments: LocationFailure.allCases)
    func readsWithoutBreaks(failure: LocationFailure) {
        let copy = failure.copy
        #expect(!copy.headline.contains("\n"))
        #expect(!copy.body.contains("\n"))
        #expect(copy.headline == copy.headlineLines?.joined(separator: " "))
        #expect(copy.body == copy.bodyLines?.joined(separator: " "))
    }

    @Test("The app name stays in the chip, not the headline (Chunk 2c)")
    func appName() {
        // Chunk 2c: the headline has no app name; the chip keeps it.
        #expect(!LocationFailure.permissionDenied.copy.headline.contains(AppInfo.name))
        #expect(LocationFailure.permissionDenied.copy.headline == "Can’t see your location")
        #expect(LocationFailure.restricted.copy.headline == LocationFailure.permissionDenied.copy.headline)
        #expect(LocationFailure.permissionDenied.pathChipLines?.first?.contains(AppInfo.name) == true)
    }

    @Test("Path chip only where Settings can fix it, on the doc's two lines")
    func pathChips() {
        // Chunk 2b: the app's Location page; any choice but Never works.
        #expect(LocationFailure.permissionDenied.pathChipLines == ["Settings › Moon Signal ›", "Location"])
        #expect(LocationFailure.servicesOff.pathChipLines == ["Settings › Privacy & Security ›", "Location Services"])
        #expect(LocationFailure.noFix.pathChipLines == nil)
        #expect(LocationFailure.restricted.pathChipLines == nil)
    }

    @Test("VoiceOver reads the chip's path as a list")
    func pathChipLabel() {
        #expect(
            LocationFailure.permissionDenied.copy.pathChipAccessibilityLabel
                == "Settings, Moon Signal, Location"
        )
        #expect(LocationFailure.noFix.copy.pathChipAccessibilityLabel == nil)
    }

    // MARK: - Actions

    @Test(
        "Primary and secondary per cause; Open Settings only for denied and services off",
        arguments: [
            (LocationFailure.permissionDenied, LocationIssue.Action?.some(.openSettings), String?.some("Open Settings"), true),
            (.servicesOff, .openSettings, "Open Settings", true),
            // Chunk 2b: no button, only the link.
            (.noFix, nil, nil, true),
            (.restricted, .search, "Search for a city", false),
        ]
    )
    func actions(failure: LocationFailure, action: LocationIssue.Action?, title: String?, showsLink: Bool) {
        #expect(failure.primaryAction == action)
        #expect(failure.copy.primaryTitle == title)
        #expect(failure.copy.showsLink == showsLink)
        // Restricted keeps the link's room under the same title.
        #expect(failure.copy.linkTitle == "Search for a city instead")
    }

    @Test("A launch cause's copy is its failure screen's, Settings chip included")
    func launchCopyIsTheFailureScreens() {
        let copy = LocationIssue.appDenied.copy
        #expect(copy == LocationFailure.permissionDenied.copy)
        #expect(copy.linkTitle == LocationIssue.searchLinkTitle)
        #expect(copy.pathChipLines != nil)
        #expect(!LocationIssue.restricted.copy.showsLink)
    }

    // MARK: - Layout

    /// iPhone 17: 874 pt tall, 62 / 34 pt safe areas. SE 3: 667, 20 / 0.
    private static let iPhone17 = (height: CGFloat(874), top: CGFloat(62), bottom: CGFloat(34))
    private static let iPhoneSE = (height: CGFloat(667), top: CGFloat(20), bottom: CGFloat(0))
    /// 56 pt button, 6 pt gap, 44 pt link.
    private static let actionsHeight: CGFloat = 106

    @Test("Default size: art 240 × 312 with its top at 90 pt, headline at 406 pt")
    func regularPlacement() {
        let layout = LocationFailureLayout.resolve(
            screenHeight: Self.iPhone17.height,
            safeAreaTop: Self.iPhone17.top,
            safeAreaBottom: Self.iPhone17.bottom,
            actionsHeight: Self.actionsHeight,
            tallestMessage: (200, 160)
        )
        #expect(layout == .regular)
        #expect(layout.artSize == CGSize(width: 240, height: 312))
        #expect(Self.iPhone17.top + LocationFailureLayout.artTop(safeAreaTop: Self.iPhone17.top) == 90)
        #expect(layout.headlineTop(safeAreaTop: Self.iPhone17.top) == 406)
    }

    @Test("Below the link: 18 + 30 pt from the screen's edge, never under 8 pt from the safe area")
    func bottomInset() {
        #expect(Self.iPhone17.bottom + LocationFailureLayout.bottomInset(safeAreaBottom: Self.iPhone17.bottom) == 48)
        #expect(LocationFailureLayout.bottomInset(safeAreaBottom: 0) == 48)
        #expect(LocationFailureLayout.bottomInset(safeAreaBottom: 45) == 8)
    }

    @Test("Doesn't fit: the art shrinks first, then the copy, then only the message scrolls")
    func fallbackOrder() {
        func resolve(_ regular: CGFloat, _ compact: CGFloat) -> LocationFailureLayout {
            LocationFailureLayout.resolve(
                screenHeight: Self.iPhoneSE.height,
                safeAreaTop: Self.iPhoneSE.top,
                safeAreaBottom: Self.iPhoneSE.bottom,
                actionsHeight: Self.actionsHeight,
                tallestMessage: (regular, compact)
            )
        }
        // SE 3: actions top 667 − 48 − 106 = 513; room under the 240 pt art
        // 513 − 24 − 406 = 83, under the 160 pt art 513 − 24 − 302 = 187.
        #expect(resolve(80, 64) == .regular)

        let smallArt = resolve(180, 150)
        #expect(smallArt.artSize == CGSize(width: 160, height: 208))
        #expect(smallArt.textScale == 1)
        #expect(!smallArt.scrollsMessage)

        let smallText = resolve(200, 160)
        #expect(smallText.artSize?.width == 160)
        #expect(smallText.textScale == 0.8)
        #expect(!smallText.scrollsMessage)

        // Standard sizes never go below 160 pt or hide the art.
        let scrolls = resolve(400, 320)
        #expect(scrolls.artSize?.width == 160)
        #expect(scrolls.textScale == 0.8)
        #expect(scrolls.scrollsMessage)
    }

    private static func resolveSE(
        _ regular: CGFloat,
        _ compact: CGFloat,
        _ textSize: LocationFailureLayout.TextSize
    ) -> LocationFailureLayout {
        LocationFailureLayout.resolve(
            screenHeight: iPhoneSE.height,
            safeAreaTop: iPhoneSE.top,
            safeAreaBottom: iPhoneSE.bottom,
            actionsHeight: actionsHeight,
            tallestMessage: (regular, compact),
            textSize: textSize
        )
    }

    @Test("AX1–AX3: the art drops to ~96 pt rather than the copy scrolling; never hidden")
    func accessibilityArt() {
        // Under the 96 pt art (124.8 tall) the headline is at 218.8, so the
        // room is 513 − 24 − 218.8 = 270.2.
        let small = Self.resolveSE(320, 260, .accessibility)
        #expect(small.artSize?.width == 96)
        #expect(small.textScale == 0.8)
        #expect(!small.scrollsMessage)

        let scrolls = Self.resolveSE(400, 320, .accessibility)
        #expect(scrolls.artSize?.width == 96)
        #expect(scrolls.scrollsMessage)
    }

    @Test("AX4+: the art is hidden if still needed, the headline at the art's top; then only the message scrolls")
    func largeAccessibilityHidesArt() {
        // A message that fits under the 96 pt art keeps it.
        #expect(Self.resolveSE(320, 260, .largeAccessibility).artSize?.width == 96)

        // No art: the headline at 90 pt, room 513 − 24 − 90 = 399.
        let hidden = Self.resolveSE(400, 320, .largeAccessibility)
        #expect(hidden.artSize == nil)
        #expect(hidden.headlineTop(safeAreaTop: Self.iPhoneSE.top) == 90)
        #expect(!hidden.scrollsMessage)

        let scrolls = Self.resolveSE(600, 480, .largeAccessibility)
        #expect(scrolls.artSize == nil)
        #expect(scrolls.scrollsMessage)
    }

    @Test("Large text only takes the extra steps when it needs them")
    func largeTextFitsFirst() {
        #expect(Self.resolveSE(80, 64, .largeAccessibility) == .regular)
        #expect(LocationFailureLayout.steps(for: .standard).allSatisfy { $0.artSize != nil })
        #expect(!LocationFailureLayout.steps(for: .accessibility).contains { $0.artSize == nil })
    }

    @Test("Before anything is measured it's the regular layout")
    func unmeasured() {
        let layout = LocationFailureLayout.resolve(
            screenHeight: Self.iPhoneSE.height,
            safeAreaTop: Self.iPhoneSE.top,
            safeAreaBottom: Self.iPhoneSE.bottom,
            actionsHeight: 0,
            tallestMessage: (0, 0)
        )
        #expect(layout == .regular)
    }
}
