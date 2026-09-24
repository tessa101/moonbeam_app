//
//  MoonService.swift
//  moonbeam-app
//

import Foundation

/// Supplies the moon table for a place and day.
///
/// Synchronous and deterministic: the maths is local and fast, which keeps
/// call sites and tests simple.
///
/// `nonisolated` so conformances aren't forced onto the main actor by
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. Without this the requirement
/// would be main-actor isolated and every caller, tests included, would have
/// to hop to the main actor to ask for a moon table.
nonisolated protocol MoonService {
    func moonDay(for place: Place, on date: Date) -> MoonDay
}
