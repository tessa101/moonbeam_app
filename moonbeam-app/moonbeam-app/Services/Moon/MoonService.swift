//
//  MoonService.swift
//  moonbeam-app
//

import Foundation

/// Supplies the moon table for a place and day.
///
/// Synchronous and deterministic: the maths is local and fast, which keeps
/// call sites and tests simple.
protocol MoonService {
    func moonDay(for place: Place, on date: Date) -> MoonDay
}
