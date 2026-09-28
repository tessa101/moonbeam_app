//
//  AppInfo.swift
//  moonbeam-app
//

import Foundation

/// App-wide identity strings.
///
/// "Moon Signal" is still a working name (DECISIONS.md 2026-09-28), so
/// user-facing copy reads it from here rather than spelling it out. The places
/// that can't are the target's `INFOPLIST_KEY_CFBundleDisplayName` (home-screen
/// name) and `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription` build
/// settings, which have to change by hand if the name does.
nonisolated enum AppInfo {
    static let name = "Moon Signal"
}
