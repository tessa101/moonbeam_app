//
//  LaunchSignposts.swift
//  moonbeam-app
//

import os

/// `os_signpost` intervals and events around the launch path, so a cold
/// launch on a device can be profiled in Instruments' os_signpost / Time
/// Profiler (LOADER.md §9). The 5.9 device stall only showed on hardware,
/// so these stay in: they cost nothing when nobody is recording.
///
/// `nonisolated`: signposts are emitted from any isolation.
nonisolated enum LaunchSignposts {
    static let subsystem = "com.t-alien.moonbeam-app"
    static let category = "Launch"
    static let signposter = OSSignposter(subsystem: subsystem, category: category)
}
