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

    @Test("Every still is in the app's asset catalog", arguments: LocationIllustration.Kind.allCases)
    func stillsExist(kind: LocationIllustration.Kind) {
        #expect(UIImage(named: kind.stillImageName) != nil)
    }

    // MARK: - Copy

    @Test(
        "Line breaks match the doc's table at the default size",
        arguments: [
            (
                LocationFailure.permissionDenied,
                "Moon Signal can’t\nsee your location",
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
                "Check your signal and try\nagain, or search for a city."
            ),
            (
                .restricted,
                "Moon Signal can’t\nsee your location",
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

    @Test("The headline uses the app's name constant")
    func appName() {
        #expect(LocationFailure.permissionDenied.copy.headline.hasPrefix(AppInfo.name))
        #expect(LocationFailure.permissionDenied.pathChipLines?.first?.contains(AppInfo.name) == true)
    }

    @Test("Path chip only where Settings can fix it, on the doc's two lines")
    func pathChips() {
        #expect(LocationFailure.permissionDenied.pathChipLines == ["Settings › Moon Signal ›", "Location › While Using the App"])
        #expect(LocationFailure.servicesOff.pathChipLines == ["Settings › Privacy & Security ›", "Location Services"])
        #expect(LocationFailure.noFix.pathChipLines == nil)
        #expect(LocationFailure.restricted.pathChipLines == nil)
    }

    @Test("VoiceOver reads the chip's path as a list")
    func pathChipLabel() {
        #expect(
            LocationFailure.permissionDenied.copy.pathChipAccessibilityLabel
                == "Settings, Moon Signal, Location, While Using the App"
        )
        #expect(LocationFailure.noFix.copy.pathChipAccessibilityLabel == nil)
    }

    // MARK: - Actions

    @Test(
        "Primary and secondary per cause; Open Settings only for denied and services off",
        arguments: [
            (LocationFailure.permissionDenied, LocationIssue.Action.openSettings, "Open Settings", true),
            (.servicesOff, .openSettings, "Open Settings", true),
            (.noFix, .tryAgain, "Try again", true),
            (.restricted, .search, "Search for a city", false),
        ]
    )
    func actions(failure: LocationFailure, action: LocationIssue.Action, title: String, showsLink: Bool) {
        #expect(failure.primaryAction == action)
        #expect(failure.copy.primaryTitle == title)
        #expect(failure.copy.showsLink == showsLink)
        // Restricted keeps the link's room under the same title.
        #expect(failure.copy.linkTitle == "Enter a city instead")
    }

    @Test("The launch loader's messages keep their copy through the shared block")
    func loaderCopyUnchanged() {
        let copy = LocationIssue.appDenied.copy
        #expect(copy.headline == LocationIssue.appDenied.headline)
        #expect(copy.body == LocationIssue.appDenied.body)
        #expect(copy.linkTitle == LocationIssue.searchLinkTitle)
        #expect(copy.pathChipLines == nil)
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
        #expect(smallText.artSize.width == 160)
        #expect(smallText.textScale == 0.8)
        #expect(!smallText.scrollsMessage)

        let scrolls = resolve(400, 320)
        #expect(scrolls.textScale == 0.8)
        #expect(scrolls.scrollsMessage)
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
