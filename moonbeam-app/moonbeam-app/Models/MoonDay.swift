//
//  MoonDay.swift
//  moonbeam-app
//

import Foundation

/// Everything the moon table shows for one place on one day.
///
/// `rise` and `set` are independent: either can be `nil` (the moon rises about
/// 50 minutes later each day, so roughly monthly one of them falls outside the
/// day), and a set can precede a rise. See ASTRONOMY.md §4.
struct MoonDay: Equatable {
    let place: Place
    let rise: MoonEvent?
    let set: MoonEvent?
    let phase: MoonPhase

    /// Degrees in `0..<360`.
    let phaseAngle: Double

    /// Fraction of the disc lit, `0.0...1.0`.
    let illumination: Double
}
