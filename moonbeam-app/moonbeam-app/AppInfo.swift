//
//  AppInfo.swift
//  moonbeam-app
//

import Foundation

/// App-wide identity strings.
///
/// "Hello Luna" replaced the working name "Moon Signal" for TestFlight 11
/// (DECISIONS.md 2026-10-17), so user-facing copy reads it from here rather
/// than spelling it out. The places
/// that can't are the target's `INFOPLIST_KEY_CFBundleDisplayName` (home-screen
/// name) and `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription` build
/// settings, which have to change by hand if the name does.
nonisolated enum AppInfo {
    static let name = "Hello Luna"
}
