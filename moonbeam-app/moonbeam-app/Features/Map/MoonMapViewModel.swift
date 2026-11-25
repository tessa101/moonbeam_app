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

    /// The map's look (MAP.md §3.2, §4; Tessa 2026-11-24).
    nonisolated enum Style: CaseIterable, Hashable, Sendable {
        /// Satellite imagery with labels: the default, easiest for reading
        /// a coast or a ridge.
        case satellite
        /// Apple's standard map.
        case explore
        /// Satellite imagery over real terrain, with 3D buildings where
        /// Apple has them, tilted (MAP.md §4, step 6.2).
        case threeD

        /// The style switch's label.
        var title: String {
            switch self {
            case .satellite: "Satellite"
            case .explore: "Explore"
            case .threeD: "3D"
            }
        }
    }

    /// One bearing line, its labels and how it's drawn.
    nonisolated struct Line: Equatable, Identifiable, Sendable {
        let event: MoonTableFormatter.Event
        let bearingLine: BearingLine
        /// "↑ Moonrise".
        let title: String
        /// "4:42 PM · 58° ENE", or "Sun 12:20 AM · 58° ENE" for an event
        /// on another day than the selected one.
        let detail: String
        /// "Moonrise 58°": the tag on the line itself, near the pin.
        let mapLabel: String
        /// Where the tag sits: along the line, a fraction of the view away.
        let mapLabelCoordinate: BearingLine.Coordinate
        /// "Turn 23° right", "Facing it", or `nil` unless the map turns
        /// with the phone (MAP.md §3.8).
        let turnHint: String?
        /// "Moonrise at 4:42 PM, east-northeast, 58 degrees." plus the turn
        /// hint when there is one.
        let accessibilityLabel: String
        /// The line chosen in the map's Moonrise / Moonset switch (first
        /// the tapped cell's), drawn stronger.
        let isSelected: Bool
        /// The phone points along it (MAP.md §3.8): drawn amber, as the
        /// compass's lock is.
        let isLocked: Bool

        var id: MoonTableFormatter.Event { event }
    }

    /// Where the view should put MapKit's camera: a request, not a reading.
    nonisolated struct CameraRequest: Equatable, Sendable {
        /// What the camera looks at, not where it stands.
        let center: BearingLine.Coordinate
        /// Degrees from true north.
        let heading: Double
        /// Metres from the camera to `center`.
        let distance: Double
        /// Degrees from straight down.
        let pitch: Double
    }

    // MARK: - Constants

    /// The camera's starting distance from the ground, in metres: a few
    /// kilometres across, enough to see the neighbourhood the line leaves.
    static let initialCameraDistance: Double = 6_000

    /// The tilt, in degrees from straight down, that switching to 3D gives
    /// the camera, so the terrain reads as 3D at once (MAP.md §4).
    static let threeDPitch = 60.0

    /// "Look along the line" (MAP.md §5, step 6.3): the camera's distance
    /// and tilt. The eye sits `distance × cos(pitch)` up. MapKit clamps the
    /// tilt, less so close in, so a short distance gets lowest: 600 m read
    /// as "pretty high up" on the phone (Tessa, 2026-11-25). Tune there.
    static let lookAlongDistance = 250.0
    static let lookAlongPitch = 80.0

    /// How far along a line its tag sits, as a fraction of the camera's
    /// distance: near enough to stay on screen at any zoom.
    static let mapLabelDistanceFraction = 0.25

    /// Follow me starts on by default (Tessa, 2026-11-24), but not when
    /// you're this far from the place: you're browsing another city, and
    /// its bearings wouldn't apply where you stand.
    static let followMaximumDistance: Double = 50_000

    /// The far-from-place check only trusts cameras closer than this to the
    /// ground. Opening, MapKit can report a zoomed-out default view before
    /// it has found you, whose centre is far from anywhere: judged on that,
    /// the check sent the map back to the place and Follow me never came on
    /// (Tessa, 2026-11-25).
    static let followCheckMaximumCameraDistance: Double = 20_000

    /// Turning the map at a chosen spot moves the camera only when the
    /// phone's heading has changed this much, so a still hand doesn't make
    /// the map shiver (MAP.md §3.10). 2° was too busy in 3D.
    static let turnThresholdDegrees = 3.0

    // MARK: - State

    let place: Place

    /// The line in focus: first the tapped cell's, then the map's own
    /// Moonrise / Moonset switch (MAP.md §3.9).
    private(set) var selected: MoonTableFormatter.Event

    /// Leaving 3D ends "look along the line", which only works in 3D.
    var style: Style = .satellite {
        didSet {
            if style != .threeD, lookingAlong != nil {
                lookingAlong = nil
                eyeHeight = nil
                applyHeading()
            }
        }
    }

    /// The line the camera looks along from the pin (MAP.md §5), or `nil`.
    /// Meanwhile the pin stays put: the camera's centre is out along the
    /// line, not where you stand.
    private(set) var lookingAlong: MoonTableFormatter.Event?

    /// While looking along: how high the camera's eye is, in metres, from
    /// the tilt MapKit actually gave. `nil` otherwise.
    private(set) var eyeHeight: Double?

    /// "Seen from about 140 ft up · drag to move": says how far from eye
    /// level the view is, and that the stand point moves (MAP.md §5).
    var lookAlongNote: String? {
        guard lookingAlong != nil, let eyeHeight else { return nil }
        let height = Measurement(value: eyeHeight.rounded(), unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road).locale(formatter.locale))
        return "Seen from about \(height) up · drag to move"
    }

    /// In 3D but not looking along: point at the binoculars, which weren't
    /// obvious (Tessa, 2026-11-25).
    var threeDHint: String? {
        guard style == .threeD, lookingAlong == nil, canLookAlong else { return nil }
        return "Tap the binoculars to look along the \(formatter.eventName(selected).lowercased()) line"
    }

    /// "Look along the line" is offered in 3D, for a line that exists.
    var canLookAlong: Bool {
        style == .threeD && azimuth(for: selected) != nil
    }

    /// Where you'd stand: the map's centre. Starts at the place.
    private(set) var pin: BearingLine.Coordinate

    /// Whether the map can load its tiles (MAP.md §3.7). Assumed online
    /// until the first reading.
    private(set) var isOnline = true

    /// Location is allowed, so Follow me can be offered (MAP.md §3.5).
    let canFollowUser: Bool

    /// Open straight onto your own position, turning with the phone,
    /// whenever location is allowed (Tessa, 2026-11-24). If you turn out to
    /// be far from the place, `returnToPlaceCount` sends the map back to it.
    var startsFollowingUser: Bool { canFollowUser }

    /// Bumped when an automatic Follow me finds you more than
    /// `followMaximumDistance` from the place: the view moves the camera
    /// back to the place.
    private(set) var returnToPlaceCount = 0

    /// The map turns with the phone, at your location or wherever the pin
    /// is (Tessa, 2026-11-25: drag or tap to a spot and keep turning and
    /// locking there). On by default when location is allowed.
    var turnsWithPhone: Bool {
        didSet { applyHeading() }
    }

    /// The phone's true heading while the map turns with it, else `nil`.
    /// Drives the lock and the turn hints.
    private(set) var heading: Double?

    /// Where the view should turn the camera when the map turns at a chosen
    /// spot (MapKit turns it itself while following you). Moves only in
    /// `turnThresholdDegrees` steps.
    private(set) var cameraHeadingRequest: Double?

    /// The line the phone points along, under the compass's lock rules.
    private(set) var locked: MoonTableFormatter.Event?

    /// Bumped on each new lock, for the haptic (like the compass's).
    private(set) var lockAcquisitionCount = 0

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
    @ObservationIgnored private let headingService: any HeadingService

    /// The phone's last reading, kept so toggling turning applies at once.
    @ObservationIgnored private var reading: HeadingReading?

    /// The compass's low-accuracy state for the map's own readings: no lock
    /// while the heading could be 25° out (COMPASS.md §1).
    @ObservationIgnored private var isLowAccuracy = true

    /// MapKit is following you, turning the camera itself.
    @ObservationIgnored private var isFollowingUser = false
    @ObservationIgnored private let formatter: MoonTableFormatter
    @ObservationIgnored private let compass = CompassFormatter()

    /// Following started by default rather than by a tap, so being far from
    /// the place should undo it. Cleared once you stop following.
    @ObservationIgnored private var isAutoFollowing: Bool

    /// The camera's last distance from the ground, for placing line tags.
    private var cameraDistance: Double = MoonMapViewModel.initialCameraDistance

    // MARK: - Init

    /// - Parameters:
    ///   - day: the start of the selected day in the place's zone; an event
    ///     on another day is labelled with its weekday.
    ///   - rise: the moonrise the card shows (the day's, the next one on a
    ///     day without, or the current pass's while the moon is up).
    ///   - set: likewise for moonset.
    ///   - selected: the cell that was tapped.
    ///   - canFollowUser: location is authorized.
    ///   - headingService: the phone's heading, for turning the map and the
    ///     lock. The caller pauses the compass meanwhile: one session at a
    ///     time.
    init(
        place: Place,
        day: Date,
        rise: MoonEvent?,
        set: MoonEvent?,
        selected: MoonTableFormatter.Event,
        canFollowUser: Bool,
        connectivity: any ConnectivityService,
        headingService: any HeadingService,
        formatter: MoonTableFormatter = MoonTableFormatter()
    ) {
        self.place = place
        self.day = day
        riseEvent = rise
        setEvent = set
        self.selected = selected
        self.canFollowUser = canFollowUser
        isAutoFollowing = canFollowUser
        self.connectivity = connectivity
        self.headingService = headingService
        self.formatter = formatter
        turnsWithPhone = canFollowUser
        pin = BearingLine.Coordinate(latitude: place.latitude, longitude: place.longitude)
    }

    // MARK: - Actions

    /// The map's camera moved: a pan, a zoom, a turn, or following you.
    /// The pin is its centre; while looking along a line, the ground under
    /// the camera's eye, so dragging the view moves where you stand.
    ///
    /// - Parameters:
    ///   - heading: the camera's heading, degrees from true north.
    ///   - distance: metres from the camera to `center`.
    ///   - pitch: degrees from straight down.
    ///   - followsHeading: the map turns with the phone, so `heading` is
    ///     where the phone points.
    func cameraChanged(
        center: BearingLine.Coordinate,
        heading: Double,
        distance: Double,
        pitch: Double = 0,
        followsHeading: Bool
    ) {
        cameraDistance = distance
        if lookingAlong != nil {
            let tilt = pitch * .pi / Self.halfTurn
            pin = BearingLine.destination(from: center, bearing: heading + Self.halfTurn, distance: distance * sin(tilt))
            eyeHeight = distance * cos(tilt)
            return
        }
        pin = center
        if followsHeading != isFollowingUser {
            // Following stopped (a drag or a tap elsewhere): the map keeps
            // turning, now at the new spot; or MapKit took over turning.
            isFollowingUser = followsHeading
            applyHeading()
        }

        if followsHeading, isAutoFollowing, distance <= Self.followCheckMaximumCameraDistance,
           BearingLine.distance(from: center, to: placeCoordinate) > Self.followMaximumDistance {
            isAutoFollowing = false
            returnToPlaceCount += 1
            return
        }
        if !followsHeading { isAutoFollowing = false }
    }

    /// A reading from the phone's heading session (`observeHeading()`).
    func headingChanged(_ newReading: HeadingReading) {
        reading = newReading
        isLowAccuracy = CompassAccuracy.isLow(after: newReading, wasLow: isLowAccuracy)
        applyHeading()
    }

    /// Runs the phone's heading session while the sheet is open, when
    /// location is allowed; it ends when the caller's task is cancelled.
    func observeHeading() async {
        guard canFollowUser else { return }
        for await newReading in headingService.start() {
            headingChanged(newReading)
        }
    }

    /// The map's own Moonrise / Moonset switch. While looking along a line,
    /// the view calls `lookAlong()` again to turn to the new one.
    func select(_ event: MoonTableFormatter.Event) {
        selected = event
    }

    /// Starts (or re-aims) "look along the line" for the selected line:
    /// the camera stands back over the pin, faces the line's bearing and
    /// tilts toward the horizon. `nil` outside 3D or without that line.
    func lookAlong() -> CameraRequest? {
        guard style == .threeD, let bearing = azimuth(for: selected) else { return nil }
        lookingAlong = selected
        isAutoFollowing = false
        applyHeading()
        // The camera looks at a point ahead and stands `distance` back from
        // it, so that point is `distance × sin(pitch)` along the line.
        let ahead = Self.lookAlongDistance * sin(Self.lookAlongPitch * .pi / Self.halfTurn)
        return CameraRequest(
            center: BearingLine.destination(from: pin, bearing: bearing, distance: ahead),
            heading: bearing,
            distance: Self.lookAlongDistance,
            pitch: Self.lookAlongPitch
        )
    }

    /// A tap on the map: stand there (MAP.md §3.10). While looking along a
    /// line, returns the camera that looks along it from the new spot;
    /// otherwise `nil`, and the view centres the camera on the spot.
    func standHere(_ coordinate: BearingLine.Coordinate) -> CameraRequest? {
        pin = coordinate
        return lookingAlong == nil ? nil : lookAlong()
    }

    /// Back to the map over the pin, still tilted as 3D is. Follow me
    /// calls it too, ignoring the camera request since MapKit takes over.
    @discardableResult
    func stopLookingAlong() -> CameraRequest {
        lookingAlong = nil
        eyeHeight = nil
        applyHeading()
        return CameraRequest(
            center: pin,
            heading: 0,
            distance: Self.initialCameraDistance,
            pitch: style == .threeD ? Self.threeDPitch : 0
        )
    }

    /// Follows the network path until the caller's task is cancelled (the
    /// sheet has closed).
    func observeConnectivity() async {
        for await online in connectivity.pathUpdates() {
            isOnline = online
        }
    }

    private func azimuth(for event: MoonTableFormatter.Event) -> Double? {
        switch event {
        case .rise: riseEvent?.azimuth
        case .set: setEvent?.azimuth
        }
    }

    // MARK: - Lock

    private var placeCoordinate: BearingLine.Coordinate {
        BearingLine.Coordinate(latitude: place.latitude, longitude: place.longitude)
    }

    /// Turning applies unless it's off or the view is looking along a line
    /// (its camera faces the line, not the phone).
    private var isTurning: Bool {
        turnsWithPhone && lookingAlong == nil
    }

    /// Recomputes the heading, the lock and the camera's turn from the last
    /// reading and the current mode.
    private func applyHeading() {
        let newHeading = isTurning ? reading?.trueHeading : nil
        // `heading` feeds the hints, shown in whole degrees: publish it only
        // when that changes, so a sensor's many readings a second don't
        // redraw the map each time (Tessa's 3D freeze, 2026-11-25).
        let shown = newHeading.map { $0.rounded() }
        if shown != heading.map({ $0.rounded() }) { heading = newHeading }
        updateLock(heading: newHeading)

        guard let newHeading, !isFollowingUser else {
            cameraHeadingRequest = nil
            return
        }
        if let current = cameraHeadingRequest,
           CompassLock.angularDistance(current, newHeading) < Self.turnThresholdDegrees {
            return
        }
        cameraHeadingRequest = newHeading
    }

    /// The compass's lock rules (COMPASS.md §1): acquire within ±5°, hold
    /// to ±8°, none in low accuracy.
    private func updateLock(heading: Double?) {
        var targets: [CompassTarget] = []
        if let riseEvent { targets.append(CompassTarget(kind: .moonrise, azimuth: riseEvent.azimuth)) }
        if let setEvent { targets.append(CompassTarget(kind: .moonset, azimuth: setEvent.azimuth)) }
        let next = CompassLock.next(
            locked: locked.map(Self.targetKind),
            heading: heading,
            isLowAccuracy: isLowAccuracy,
            targets: targets
        )
        let nextEvent = next.flatMap(Self.event)
        if let nextEvent, nextEvent != locked {
            lockAcquisitionCount += 1
        }
        locked = nextEvent
    }

    private static func targetKind(_ event: MoonTableFormatter.Event) -> CompassTarget.Kind {
        switch event {
        case .rise: .moonrise
        case .set: .moonset
        }
    }

    private static func event(_ kind: CompassTarget.Kind) -> MoonTableFormatter.Event? {
        switch kind {
        case .moonrise: .rise
        case .moonset: .set
        case .moon: nil
        }
    }

    // MARK: - Turn hint

    private static let fullTurn = 360.0
    private static let halfTurn = 180.0

    /// How far to turn, and which way, to face `bearing` from `heading`:
    /// "Turn 23° right"; "Facing it" once locked.
    private func turnHint(to bearing: Double, isLocked: Bool) -> (shown: String, spoken: String)? {
        guard let heading else { return nil }
        if isLocked { return ("Facing it", "You're facing it") }
        var turn = (bearing - heading).truncatingRemainder(dividingBy: Self.fullTurn)
        if turn >= Self.halfTurn { turn -= Self.fullTurn }
        if turn < -Self.halfTurn { turn += Self.fullTurn }
        let degrees = Int(abs(turn).rounded())
        let side = turn >= 0 ? "right" : "left"
        return ("Turn \(degrees)° \(side)", "Turn \(degrees) degrees \(side)")
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
        let isLocked = locked == event
        let hint = turnHint(to: moonEvent.azimuth, isLocked: isLocked)
        let labelDistance = min(cameraDistance * Self.mapLabelDistanceFraction, BearingLine.defaultLength)
        var spoken = "\(formatter.eventName(event)) \(spokenTime), \(direction)."
        if let hint { spoken += " \(hint.spoken)." }
        return Line(
            event: event,
            bearingLine: BearingLine(start: pin, bearing: moonEvent.azimuth),
            title: formatter.eventTitle(event),
            detail: "\(shownTime) · \(formatter.direction(for: moonEvent.azimuth))",
            mapLabel: "\(formatter.eventName(event)) \(compass.bearingParts(for: moonEvent.azimuth).degrees)",
            mapLabelCoordinate: BearingLine.destination(from: pin, bearing: moonEvent.azimuth, distance: labelDistance),
            turnHint: hint?.shown,
            accessibilityLabel: spoken,
            isSelected: event == selected,
            isLocked: isLocked
        )
    }

    private static func calendar(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}
