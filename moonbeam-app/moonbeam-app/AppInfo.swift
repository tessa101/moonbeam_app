//
//  AppInfo.swift
//  moonbeam-app
//

import Foundation

/// App-wide identity strings.
///
/// "Moonbeam" is still a working name (LOCATION.md §9), so user-facing copy
/// reads it from here rather than spelling it out. The one place that can't is
/// `NSLocationWhenInUseUsageDescription` in Info.plist, which has to change by
/// hand if the name does.
nonisolated enum AppInfo {
    static let name = "Moonbeam"
}
