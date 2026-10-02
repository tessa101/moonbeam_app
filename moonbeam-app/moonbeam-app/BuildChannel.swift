//
//  BuildChannel.swift
//  moonbeam-app
//

import Foundation

/// Where this build came from, as far as the temporary Show onboarding button
/// cares (DECISIONS.md 2026-10-01 "Show onboarding button also in TestFlight
/// builds"): testers get it, App Store users don't.
///
/// A runtime check rather than a build setting, because TestFlight and the App
/// Store ship the same Release binary. TestFlight installs carry a sandbox
/// receipt (`sandboxReceipt`); App Store installs have `receipt`.
/// Temporary: remove with the button before the 1.0 App Store build.
nonisolated enum BuildChannel {

    /// The receipt file name TestFlight installs have.
    static let testFlightReceiptName = "sandboxReceipt"

    /// A TestFlight install: its receipt is the sandbox one.
    static var isTestFlight: Bool {
        isTestFlight(receiptURL: receiptURL)
    }

    /// The Show onboarding button: DEBUG builds and TestFlight, never the App
    /// Store.
    static var showsOnboardingButton: Bool {
        #if DEBUG
        let isDebug = true
        #else
        let isDebug = false
        #endif
        return showsOnboardingButton(isDebug: isDebug, receiptURL: receiptURL)
    }

    /// Deprecated since iOS 18 in favour of StoreKit's `AppTransaction`, but
    /// still set, synchronous, and what the decision chose for this temporary
    /// check. Read in this one place, so it's one warning.
    private static var receiptURL: URL? {
        Bundle.main.appStoreReceiptURL
    }

    // MARK: - Testable forms

    static func isTestFlight(receiptURL: URL?) -> Bool {
        receiptURL?.lastPathComponent == testFlightReceiptName
    }

    static func showsOnboardingButton(isDebug: Bool, receiptURL: URL?) -> Bool {
        isDebug || isTestFlight(receiptURL: receiptURL)
    }
}
