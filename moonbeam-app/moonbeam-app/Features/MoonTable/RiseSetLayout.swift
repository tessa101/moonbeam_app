//
//  RiseSetLayout.swift
//  moonbeam-app
//

import Foundation

/// The moon card's rise / set row (COMPASS-1.1.md §9.14): which cells it
/// shows, in reading order, and how they're joined.
///
/// Today always uses three columns: rise, the current moon state, and set.
/// The connector shows travelled progress while up and stays dim while down.
/// Other dates retain the two-column rise/set row. Where three columns don't
/// fit (AX sizes), `fallback` keeps rise and set with a state pill underneath.
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
    /// connector, and today's state as the pill row under them.
    struct Fallback: Equatable {
        let cells: [MoonCardCell]
        let showsPillRow: Bool
    }

    /// The row's cells, left to right, which is also VoiceOver's order.
    let cells: [MoonCardCell]
    let connector: Connector
    /// The middle-column detail; `nil` only on another date.
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
            self.init(bearing: bearing, connector: .travelled, reservesTwinHeight: false)
        case let .notUpYet(countdown):
            self.init(bearing: countdown, connector: .dim, reservesTwinHeight: false)
        case let .setForToday(nextRise):
            self.init(bearing: nextRise ?? "", connector: .dim, reservesTwinHeight: false)
        case nil:
            self.init(bearing: nil, connector: .dim, reservesTwinHeight: false)
        }
    }

    private init(bearing: String?, connector: Connector, reservesTwinHeight: Bool) {
        self.bearing = bearing
        self.reservesTwinHeight = reservesTwinHeight
        if bearing != nil {
            cells = [.moonrise, .upNow, .moonset]
            self.connector = connector
        } else {
            cells = [.moonrise, .moonset]
            self.connector = connector
        }
    }

    /// The other state's row, measured but not shown, so both states take
    /// the taller one's height; `nil` when the row doesn't reserve it.
    var twin: RiseSetLayout? {
        guard reservesTwinHeight else { return nil }
        return bearing == nil
            ? RiseSetLayout(bearing: Self.placeholderBearing, connector: .travelled, reservesTwinHeight: false)
            : RiseSetLayout(bearing: nil, connector: .dim, reservesTwinHeight: false)
    }

    var fallback: Fallback {
        Fallback(cells: [.moonrise, .moonset], showsPillRow: bearing != nil)
    }
}
