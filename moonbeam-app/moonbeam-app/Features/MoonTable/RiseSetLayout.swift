//
//  RiseSetLayout.swift
//  moonbeam-app
//

import Foundation

/// The moon card's rise / set row (COMPASS-1.1.md §9.14): which cells it
/// shows, in reading order, and how they're joined.
///
/// Moon up (today, with the compass): three columns, ↑ Moonrise · Up now ·
/// ↓ Moonset, the glyph on a line that's solid from rise to now and dotted
/// from now to set, like the dial's arc. Moon down, or another date: rise
/// and set joined by one dim dotted line. Where the three columns don't fit
/// (AX sizes), `fallback`: rise and set, with the 5.4.6a pill row under them.
///
/// Kept out of the view so the choice is testable; the view only lays it out.
///
/// `nonisolated`: an inert value.
nonisolated struct RiseSetLayout: Equatable {

    enum Connector: Equatable {
        /// Moon up: solid from Moonrise to the glyph, dotted on to Moonset.
        case travelled
        /// Moon down or another date: one dotted line at 40%.
        case dim
    }

    /// When the three columns don't fit: rise and set as built, no
    /// connector, and Up now as the pill row under them.
    struct Fallback: Equatable {
        let cells: [MoonCardCell]
        let showsPillRow: Bool
    }

    /// The row's cells, left to right, which is also VoiceOver's order.
    let cells: [MoonCardCell]
    let connector: Connector
    /// "266° W" under "Up now"; `nil` with no middle column.
    let bearing: String?
    /// Today with the compass, the row keeps room for the other state
    /// (`twin`), so the card's height doesn't change when the moon rises
    /// or sets.
    let reservesTwinHeight: Bool

    /// Stands in for the live bearing while the moon is down, when the
    /// row only measures the Up now column. The widest bearing text.
    static let placeholderBearing = "359° NNW"

    /// - Parameter upNow: the compass's Up now, `nil` on other dates or
    ///   without the compass.
    init(upNow: UpNow?) {
        switch upNow?.state {
        case let .up(bearing, _):
            self.init(bearing: bearing, reservesTwinHeight: true)
        case .down:
            self.init(bearing: nil, reservesTwinHeight: true)
        case nil:
            self.init(bearing: nil, reservesTwinHeight: false)
        }
    }

    private init(bearing: String?, reservesTwinHeight: Bool) {
        self.bearing = bearing
        self.reservesTwinHeight = reservesTwinHeight
        if bearing != nil {
            cells = [.moonrise, .upNow, .moonset]
            connector = .travelled
        } else {
            cells = [.moonrise, .moonset]
            connector = .dim
        }
    }

    /// The other state's row, measured but not shown, so both states take
    /// the taller one's height; `nil` when the row doesn't reserve it.
    var twin: RiseSetLayout? {
        guard reservesTwinHeight else { return nil }
        return bearing == nil
            ? RiseSetLayout(bearing: Self.placeholderBearing, reservesTwinHeight: false)
            : RiseSetLayout(bearing: nil, reservesTwinHeight: false)
    }

    var fallback: Fallback {
        Fallback(cells: [.moonrise, .moonset], showsPillRow: bearing != nil)
    }
}
