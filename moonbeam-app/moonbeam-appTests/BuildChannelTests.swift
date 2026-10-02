//
//  BuildChannelTests.swift
//  moonbeam-appTests
//

import Foundation
import Testing
@testable import moonbeam_app

/// `BuildChannel` (DECISIONS.md 2026-10-01 "Show onboarding button also in
/// TestFlight builds"): the receipt name decides TestFlight, and the Show
/// onboarding button shows in DEBUG or TestFlight, never the App Store.
@Suite("Build channel")
struct BuildChannelTests {

    private static let receiptFolder = URL(filePath: "/private/var/containers/Bundle/Application/X/Moon Signal.app/_MASReceipt")
    private static let testFlightReceipt = receiptFolder.appending(path: "sandboxReceipt")
    private static let appStoreReceipt = receiptFolder.appending(path: "receipt")

    @Test("A sandbox receipt is TestFlight")
    func sandboxReceiptIsTestFlight() {
        #expect(BuildChannel.isTestFlight(receiptURL: Self.testFlightReceipt))
    }

    @Test("An App Store receipt, or none, isn't TestFlight", arguments: [appStoreReceipt, nil])
    func otherReceiptsAreNot(receiptURL: URL?) {
        #expect(!BuildChannel.isTestFlight(receiptURL: receiptURL))
    }

    @Test("Release: the button shows with a sandbox receipt only", arguments: [
        (testFlightReceipt, true),
        (appStoreReceipt, false),
        (nil, false),
    ] as [(URL?, Bool)])
    func buttonInRelease(receiptURL: URL?, shows: Bool) {
        #expect(BuildChannel.showsOnboardingButton(isDebug: false, receiptURL: receiptURL) == shows)
    }

    @Test("DEBUG: the button always shows", arguments: [testFlightReceipt, appStoreReceipt, nil])
    func buttonInDebug(receiptURL: URL?) {
        #expect(BuildChannel.showsOnboardingButton(isDebug: true, receiptURL: receiptURL))
    }
}
