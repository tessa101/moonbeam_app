//
//  MoonMapViewModel.swift
//  moonbeam-app
//

import Foundation
import Observation

/// The map sheet's state (MAP.md §3): where the "stand here" pin is, the
/// moonrise and moonset lines drawn from it, the map style, and whether the
/// map can load.
///
/// Built by `LocationViewModel` when a rise or set cell is tapped, from the
/// events the card shows, so the map always agrees with the card. Nothing
/// here is astronomical: within a city the bearing doesn't change as the pin
/// moves (MAP.md §2), so moving the pin only redraws the lines.
///
/// The camera itself (zoom, rotation, following the user) is the view's: it
/// belongs to MapKit, and the pin is simply wherever the camera's centre is.
@Observable
final class MoonMapViewModel {

    // MARK: - Types

    /// The map's look (MAP.md §3.2, Tessa 2026-11-24). 3D joins in 6.2.
    nonisolated enum Style: CaseIterable, Hashable, Sendable {
        /// Satellite imagery with labels: the default, easiest for reading
        /// a coast or a ridge.
        case satellite
        /// Apple's standard map.
        case explore

        /// The style switch's label.
        var title: String {
            switch self {
            case .satellite: "Satellite"
            case .explore: "Explore"
            }
        }
    }

    /// One bearing line and its legend text.
    nonisolated struct Line: Equatable, Identifiable, Sendable {
        let event: MoonTableFormatter.Event
        let bearingLine: BearingLine
        /// "↑ Moonrise".
        let title: String
        /// "4:42 PM · 58° ENE", or "Sun 12:20 AM · 58° ENE" for an event
        /// on another day than the selected one.
        let detail: String
        /// "Moonrise at 4:42 PM, east-northeast, 58 degrees."
        let accessibilityLabel: String
        /// The line for the cell that was tapped, drawn stronger.
        let isEmphasised: Bool

        var id: MoonTableFormatter.Event { event }
    }

    // MARK: - Constants

    /// The camera's starting distance from the ground, in metres: a few
    /// kilometres across, enough to see the neighbourhood the line leaves.
    static let initialCameraDistance: Double = 6_000

    // MARK: - State

    let place: Place

    /// Which line was tapped.
    let emphasised: MoonTableFormatter.Event

    var style: Style = .satellite

    /// Where you'd stand: the map's centre. Starts at the place.
    private(set) var pin: BearingLine.Coordinate

    /// Whether the map can load its tiles (MAP.md §3.7). Assumed online
    /// until the first reading.
    private(set) var isOnline = true

    /// Location is allowed, so Follow me can be offered (MAP.md §3.5).
    let canFollowUser: Bool

    /// Open straight onto your own position, turning with the phone, when
    /// the place already is where you are.
    var startsFollowingUser: Bool {
        canFollowUser && place.isCurrentLocation
    }

    var lines: [Line] {
        [riseLine, setLine].compactMap { $0 }
    }

    /// VoiceOver's summary of the map: the lines' directions in words
    /// (MAP.md §3, Accessibility), since the drawing itself says nothing.
    var mapAccessibilityLabel: String {
        let parts = lines.map(\.accessibilityLabel)
        guard !parts.isEmpty else { return "Map. No moonrise or moonset to show." }
        return "Map. Lines from the pin: " + parts.joined(separator: " ")
    }

    /// The no-connection note (MAP.md §3.7; copy to be settled).
    static let offlineTitle = "No connection"
    static let offlineMessage = "The map needs the internet to load. The directions below still hold."

    // MARK: - Dependencies

    @ObservationIgnored private let riseEvent: MoonEvent?
    @ObservationIgnored private let setEvent: MoonEvent?
    @ObservationIgnored private let day: Date
    @ObservationIgnored private let connectivity: any ConnectivityService
    @ObservationIgnored private let formatter: MoonTableFormatter
    @ObservationIgnored private let compass = CompassFormatter()

    // MARK: - Init

    /// - Parameters:
    ///   - day: the start of the selected day in the place's zone; an event
    ///     on another day is labelled with its weekday.
    ///   - rise: the moonrise the card shows (the day's, the next one on a
    ///     day without, or the current pass's while the moon is up).
    ///   - set: likewise for moonset.
    ///   - emphasised: the cell that was tapped.
    ///   - canFollowUser: location is authorized.
    init(
        place: Place,
        day: Date,
        rise: MoonEvent?,
        set: MoonEvent?,
        emphasised: MoonTableFormatter.Event,
        canFollowUser: Bool,
        connectivity: any ConnectivityService,
        formatter: MoonTableFormatter = MoonTableFormatter()
    ) {
        self.place = place
        self.day = day
        riseEvent = rise
        setEvent = set
        self.emphasised = emphasised
        self.canFollowUser = canFollowUser
        self.connectivity = connectivity
        self.formatter = formatter
        pin = BearingLine.Coordinate(latitude: place.latitude, longitude: place.longitude)
    }

    // MARK: - Actions

    /// The map's centre moved (a pan, a zoom, or following the user).
    func pinMoved(to coordinate: BearingLine.Coordinate) {
        pin = coordinate
    }

    /// Follows the network path until the caller's task is cancelled (the
    /// sheet has closed).
    func observeConnectivity() async {
        for await online in connectivity.pathUpdates() {
            isOnline = online
        }
    }

    // MARK: - Lines

    private var riseLine: Line? {
        riseEvent.map { line(for: .rise, $0) }
    }

    private var setLine: Line? {
        setEvent.map { line(for: .set, $0) }
    }

    private func line(for event: MoonTableFormatter.Event, _ moonEvent: MoonEvent) -> Line {
        let timeZone = place.timeZone
        let isOnSelectedDay = Self.calendar(in: timeZone).isDate(moonEvent.date, inSameDayAs: day)
        let shownTime: String
        let spokenTime: String
        if isOnSelectedDay {
            shownTime = formatter.time(moonEvent.date, in: timeZone)
            spokenTime = "at \(shownTime)"
        } else {
            let next = formatter.nextEventText(moonEvent.date, in: timeZone)
            shownTime = next.shown
            spokenTime = next.spoken
        }
        let direction = "\(compass.spokenName(for: moonEvent.azimuth)), \(compass.spokenDegrees(for: moonEvent.azimuth))"
        return Line(
            event: event,
            bearingLine: BearingLine(start: pin, bearing: moonEvent.azimuth),
            title: formatter.eventTitle(event),
            detail: "\(shownTime) · \(formatter.direction(for: moonEvent.azimuth))",
            accessibilityLabel: "\(formatter.eventName(event)) \(spokenTime), \(direction).",
            isEmphasised: event == emphasised
        )
    }

    private static func calendar(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}
