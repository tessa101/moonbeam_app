//
//  MoonPhase.swift
//  moonbeam-app
//

import Foundation

/// The named lunar phase, derived from the phase angle.
///
/// `nonisolated`: an inert value, not main-actor state.
nonisolated enum MoonPhase: String, CaseIterable {
    case new, waxingCrescent, firstQuarter, waxingGibbous
    case full, waningGibbous, lastQuarter, waningCrescent
}

// MARK: - Derivation from phase angle

extension MoonPhase {
    /// Half-width of the window around each of the four principal phases.
    ///
    /// A common convention rather than a standard; see ASTRONOMY.md §3, which
    /// flags it as TBD pending design review.
    nonisolated static let principalPhaseHalfWidth = 6.0

    /// Maps a phase angle to a named phase using the table in ASTRONOMY.md §3.
    ///
    /// - Parameter phaseAngle: Degrees in `0..<360`, where 0 is new, 90 first
    ///   quarter, 180 full and 270 last quarter. Values outside the range are
    ///   wrapped, so callers don't have to normalise first.
    ///
    /// `nonisolated` because it's pure arithmetic on the argument, so it
    /// doesn't belong on the main actor under
    /// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
    nonisolated init(phaseAngle: Double) {
        let halfWidth = Self.principalPhaseHalfWidth
        let angle = phaseAngle.wrappedIntoDegreeCircle

        // Each principal phase owns a window of ±halfWidth; the crescent and
        // gibbous phases fill the gaps between those windows.
        switch angle {
        case ..<halfWidth:
            self = .new
        case ..<(90 - halfWidth):
            self = .waxingCrescent
        case ..<(90 + halfWidth):
            self = .firstQuarter
        case ..<(180 - halfWidth):
            self = .waxingGibbous
        case ..<(180 + halfWidth):
            self = .full
        case ..<(270 - halfWidth):
            self = .waningGibbous
        case ..<(270 + halfWidth):
            self = .lastQuarter
        case ..<(360 - halfWidth):
            self = .waningCrescent
        default:
            self = .new
        }
    }
}

// MARK: - Angle helpers

extension Double {
    /// This value reduced into `0..<360`, so negative and over-large angles
    /// behave the same as their in-range equivalents.
    ///
    /// `nonisolated` for the same reason as its callers: pure arithmetic.
    nonisolated var wrappedIntoDegreeCircle: Double {
        let fullCircle = 360.0
        let remainder = truncatingRemainder(dividingBy: fullCircle)
        return remainder < 0 ? remainder + fullCircle : remainder
    }
}
