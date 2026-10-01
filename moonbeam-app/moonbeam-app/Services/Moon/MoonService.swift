//
//  MoonService.swift
//  moonbeam-app
//

import Foundation

/// Supplies the moon table for a place and day, and the moon's live
/// position for the compass.
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

    /// The moon's direction, and whether it's up, at one instant. Unlike
    /// `moonDay(for:on:)`, `date` is the exact moment, not a day.
    func moonPosition(for place: Place, at date: Date) -> MoonPosition

    /// The pass the moon is on at `date`: the latest rise before it to the
    /// next set after it, sampled every `MoonPass.sampleInterval`. `nil`
    /// when the moon is down at `date` (same definition as `moonPosition`),
    /// or the rise or set is out of the search's reach.
    func moonPass(for place: Place, containing date: Date) -> MoonPass?
}
