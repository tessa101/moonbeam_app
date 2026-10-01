//
//  CompassArc.swift
//  moonbeam-app
//

import Foundation

/// The moon arc round the dial (DESIGN-1.1.md §3.3a): a moon pass reduced to
/// what the dial draws. All three azimuths are on the same unwrapped scale
/// (`MoonPass.path`), so the dial draws from `startAzimuth` to `endAzimuth`
/// the way the moon actually goes, never the short way round.
///
/// `nonisolated`: an inert value, like `CompassTarget`.
nonisolated struct CompassArc: Equatable, Sendable {

    /// Moonrise, where the arc starts.
    let startAzimuth: Double

    /// Moonset. Below `startAzimuth`: the pass runs anticlockwise.
    let endAzimuth: Double

    /// The moon, between the two, while this pass is under way: the seam
    /// between the travelled hairline and the dotted rest. `nil`: the moon is
    /// down and this is the next pass, drawn dimmed with no glyph.
    let moonAzimuth: Double?
}
