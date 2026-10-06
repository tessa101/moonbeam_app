//
//  LaunchScreenTests.swift
//  moonbeam-appTests
//

import SwiftUI
import Testing
import UIKit
@testable import moonbeam_app

/// The system launch screen is the app's `bg`, not black (LOADER.md §10,
/// Build 5.9.2), so the hand-off to the first frame doesn't flash.
@Suite("Launch screen")
struct LaunchScreenTests {

    private static let colorName = "LaunchBackground"
    /// Per-channel tolerance for the 8-bit round trip.
    private static let channelTolerance: CGFloat = 0.5 / 255

    @Test("Info.plist names the launch background colour")
    func plistNamesColor() {
        let launchScreen = Bundle.main.object(forInfoDictionaryKey: "UILaunchScreen") as? [String: Any]
        #expect(launchScreen?["UIColorName"] as? String == Self.colorName)
    }

    @Test("The launch background colour is bg")
    func colorIsBg() throws {
        let asset = try #require(UIColor(named: Self.colorName, in: .main, compatibleWith: nil))
        let expected = UIColor(Theme.Colors.bg)
        var a = (r: CGFloat(0), g: CGFloat(0), b: CGFloat(0), alpha: CGFloat(0))
        var e = a
        asset.getRed(&a.r, green: &a.g, blue: &a.b, alpha: &a.alpha)
        expected.getRed(&e.r, green: &e.g, blue: &e.b, alpha: &e.alpha)
        #expect(abs(a.r - e.r) <= Self.channelTolerance)
        #expect(abs(a.g - e.g) <= Self.channelTolerance)
        #expect(abs(a.b - e.b) <= Self.channelTolerance)
        #expect(a.alpha == 1)
    }
}
