//
//  CompassViewModel.swift
//  moonbeam-app
//

import Foundation
import Observation

/// The live compass under the moon table (COMPASS.md).
///
/// Decides whether the compass shows (§2), which targets it offers (§1), what
/// it's locked onto, and when the sensors run. It never reads location state
/// itself: `LocationViewModel` pushes a `CompassContext` whenever the place,
/// day or permission changes.
///
/// **Sensors run only while all three hold:** the compass is shown (§2), it's
/// on screen (the view reports scroll-in/out) or the pinned bar shows its
/// heading (COMPASS-1.1.md §9.6), and the app is in the foreground. While they run, a task holds the heading stream and iterates
/// it; dropping it would end the session (`HeadingService`).
///
/// Main-actor isolated (the project default), like the heading service it
/// drives. Services, the clock and the sleep come in through the initializer
/// so tests run the same logic against fakes.
@Observable
final class CompassViewModel {

    // MARK: - Types

    /// The COMPASS.md §2 states.
    enum Visibility: Equatable {
        /// No place yet, or location is on but nothing has been detected.
        case hidden

        /// Location isn't authorized: the enable-location hint instead.
        case locationOff

        /// The selected place is the detected city. Compass, no note.
        case here

        /// A different city within `nearbyRadiusMeters` of the detected
        /// location. Compass, plus the Nearby note naming both cities.
        case nearby

        /// Further than that. No compass, just the Far message.
        case far

        /// Here and Nearby get the live compass (and its sensors).
        var showsCompass: Bool { self == .here || self == .nearby }
    }

    /// Why accuracy is low, so the user can fix it (COMPASS.md §1, 4.10).
    enum LowAccuracyReason: Equatable {
        /// Precise Location is off for the app: fixable in one tap with the
        /// temporary alert (4.12). For good, only in Settings (4.14).
        case preciseLocationOff

        /// Cause unknown: most often metal, magnets or a charger nearby,
        /// or a magnetometer that needs a figure 8.
        case interference
    }

    // MARK: - Constants

    /// How often the live "Moon" target is recomputed (COMPASS.md §1). The
    /// moon's azimuth moves about a quarter of a degree a minute.
    static let defaultMoonRefreshInterval = Duration.seconds(30)

    /// A day's pass is looked up a minute after its moonrise, when the moon
    /// is safely up by the same rule the service uses.
    static let passLookupDelayAfterRise: TimeInterval = 60

    /// How long the aha line stays before the normal readout (4.12).
    static let preciseConfirmationDuration = Duration.seconds(3)

    private static let metersPerMile = 1_609.344
    private static let nearbyRadiusMiles = 60.0

    /// 60 mi (~97 km). Rise/set bearings depend mostly on latitude, so within
    /// this they differ by well under 1°, inside the ±5° lock (COMPASS.md
    /// §2). Inclusive.
    static let nearbyRadiusMeters = nearbyRadiusMiles * metersPerMile

    // MARK: - Placeholder copy (final copy is in the design pass)

    /// In place of the compass when location is off (COMPASS.md §2).
    static let locationOffHint = "Turn on location to use the compass."

    /// Leads into the existing Location Off flow.
    static let turnOnLocationTitle = "Turn On Location"

    /// How VoiceOver names the live Moon on the dial.
    static let moonNowName = "Moon now"

    /// Shown, and read by VoiceOver, while the heading can't be trusted.
    static let lowAccuracyText = "Compass accuracy is low"

    /// The bottom bar, Precise Location off (COMPASS-1.1.md §9.4; replaces
    /// 4.12's "We think you're near [city]…").
    static let preciseLocationOffText = "Using your approximate location. Precise gives a better reading."

    /// Its only button (4.14, §9.4): iOS's temporary full-accuracy alert,
    /// one tap and no trip to Settings. Lasts this session of use.
    static let usePreciseLocationTitle = "Use Precise"

    /// Replaces the reason line for a moment when Precise Location turns on
    /// with the compass on screen (4.12).
    static let preciseConfirmationText = "There you are! The compass is happy now."

    /// The bottom bar in low accuracy, whatever the cause (COMPASS-1.1.md
    /// §9.4: one line for every reason; replaces 4.10's tip). "Charger"
    /// since the device test, where charging took accuracy to ±27°.
    static let lowAccuracyNote = "Compass accuracy is low. Move away from metal or a charger, or wave your phone in a figure 8."

    /// Over the compass in the Nearby state (4.11): names where you are and
    /// the selected city. Says what it shows, not that it's approximate: at
    /// ≤ 60 mi the error is under 1°.
    static func nearbyText(detected: String, selected: String) -> String {
        "You're in \(detected) but \(selected) is nearby"
    }

    /// In place of the compass beyond the nearby radius (4.11).
    static func farText(selected: String) -> String {
        "You're a bit too far from \(selected) to view the compass accurately"
    }

    // MARK: - Observed state

    private(set) var visibility: Visibility = .hidden

    /// `nearbyText` in the Nearby state, else `nil`. Never a distance: with
    /// the city names, that would reveal roughly where someone is. Stored
    /// (not derived from `context`, which isn't observed) so moving between
    /// two Nearby cities updates it.
    private(set) var nearbyNote: String?

    /// `farText` in the Far state, else `nil`. Stored for the same reason.
    private(set) var farMessage: String?

    /// Moonrise and moonset for the selected day (when that day has them),
    /// then the moon if it's today and it's up.
    private(set) var targets: [CompassTarget] = []

    /// The moon arc (DESIGN-1.1.md §3.3a): today with the moon up, the pass
    /// it's on; otherwise the pass from the selected day's moonrise. `nil`
    /// with no compass, no moonrise, or no pass found.
    private(set) var arc: CompassArc?

    /// The moon card's Up now row (COMPASS-1.1.md §3): today with the
    /// compass shown, from the same position, pass and tick as the Moon
    /// target, so the card and the dial agree. `nil` on other dates and
    /// wherever there's no compass.
    private(set) var upNow: UpNow?

    /// The latest reading, or `nil` while the sensors are off.
    private(set) var reading: HeadingReading?

    /// Low accuracy, with hysteresis (`CompassAccuracy`): in above 25°, out
    /// below 20°. Stored because the rule depends on the previous state.
    /// Starts, and returns to, low whenever there's no reading.
    private(set) var isLowAccuracy = true

    private(set) var lockedKind: CompassTarget.Kind?

    /// The live Moon marker's phase (§11 Q4, revised): the same lit
    /// fraction and side as the moon card's glyph, from the selected day's
    /// table. Stored, since `context` isn't observed.
    private(set) var moonGlyph: PhaseGlyphGeometry?

    /// The heading and location sensors are running.
    private(set) var isSensing = false

    /// From the context: Precise Location is off for the app.
    private(set) var isPreciseLocationOff = false

    /// The aha line while it shows (4.12), else `nil`. Only on Precise
    /// Location turning on with the compass on screen, never on an ordinary
    /// recovery from low accuracy, which would make it constant.
    private(set) var preciseConfirmation: String?

    /// The bar's note when the sensors last stopped, kept until the next
    /// reading. The bar is an inset, so at large text sizes it can cover the
    /// compass enough to count as off screen; without this, stopping the
    /// sensors cleared the reading, the note went, the compass came back on
    /// screen and the bar flickered in and out.
    private(set) var heldBottomNote: CompassBottomNote?

    /// From the context: something has been detected this session. Only the
    /// DEBUG readout uses it, to tell "Nothing detected" apart (4.8).
    private(set) var hasDetectedPlace = false

    /// Goes up by one each time a lock is acquired, including a switch
    /// straight from one target to another. The view plays the haptic when
    /// it changes (COMPASS.md §1, 4.5), so release and holding stay silent.
    private(set) var lockAcquisitionCount = 0

    /// Some target has been locked since launch. The Moon's pulse
    /// (COMPASS-1.1.md §5) stops then and doesn't return until the app
    /// relaunches; this view model lives as long as the app does.
    private(set) var hasLockedThisLaunch = false

    /// The dial's centre is below the fold (the screen's bottom, or a
    /// bottom bar's top), as the screen last reported it.
    private(set) var isDialCentreBelowFold = false

    // MARK: - Dependencies

    private let headingService: any HeadingService
    private let moonService: any MoonService
    private let now: () -> Date
    private let moonRefreshInterval: Duration
    private let sleep: @Sendable (Duration) async throws -> Void
    private let formatter = CompassFormatter()
    private let upNowFormatter = UpNowFormatter()

    // MARK: - Bookkeeping

    @ObservationIgnored private var context = CompassContext.empty
    @ObservationIgnored private var isOnScreen = false
    @ObservationIgnored private var isInForeground = true

    /// Iterates, and so holds, the heading stream. Non-nil exactly while the
    /// sensors run.
    @ObservationIgnored private var headingTask: Task<Void, Never>?

    /// Ticks the "Moon" target refresh while the sensors run.
    @ObservationIgnored private var moonRefreshTask: Task<Void, Never>?

    /// Clears `preciseConfirmation` after its few seconds.
    @ObservationIgnored private var preciseConfirmationTask: Task<Void, Never>?

    /// The pass behind `arc`. Kept so the 30 s tick only moves the moon
    /// along it, and only looks the pass up again when the moon rises or sets.
    @ObservationIgnored private var pass: MoonPass?

    /// The next moonrise while the moon is down, for Up now. Kept so the
    /// tick only looks it up again once it has passed.
    @ObservationIgnored private var nextRise: MoonEvent?

    // MARK: - Init

    /// - Parameters:
    ///   - now: the clock the "Moon" target is computed for.
    ///   - sleep: the wait between "Moon" refreshes, and before the aha line
    ///     clears; injectable so tests can tick it by hand.
    init(
        headingService: any HeadingService,
        moonService: any MoonService,
        now: @escaping () -> Date = Date.init,
        moonRefreshInterval: Duration = CompassViewModel.defaultMoonRefreshInterval,
        sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.headingService = headingService
        self.moonService = moonService
        self.now = now
        self.moonRefreshInterval = moonRefreshInterval
        self.sleep = sleep
    }

    // MARK: - Derived state

    var heading: Double? { reading?.trueHeading }

    /// The ring pulsing from the live Moon (COMPASS-1.1.md §5): while the
    /// moon is up (so today) and nothing has been locked yet this launch.
    var showsMoonPulse: Bool {
        !hasLockedThisLaunch && targets.contains { $0.kind == .moon }
    }

    var lockedTarget: CompassTarget? {
        guard let lockedKind else { return nil }
        return targets.first { $0.kind == lockedKind }
    }

    /// The pinned compass bar (COMPASS-1.1.md §9.6, DESIGN-1.1.md §4.1):
    /// with the compass shown (Here or Nearby) and its dial's centre below
    /// the fold. It hides once the centre is on screen, and with the dial
    /// scrolled off the top.
    var showsPinnedBar: Bool {
        visibility.showsCompass && isDialCentreBelowFold
    }

    /// The pinned bar's rule: the centre's y is past the fold's, both in
    /// the same space (the screen's, from the top).
    static func isBelowFold(dialCentreY: CGFloat, foldY: CGFloat) -> Bool {
        dialCentreY > foldY
    }

    /// "72° ENE", or `nil` with no true heading.
    var headingText: String? {
        heading.map(formatter.bearing(for:))
    }

    /// "Moonrise · 72° ENE": the target's own bearing, not the heading's.
    var lockText: String? {
        lockedTarget.map(targetText(for:))
    }

    /// `headingText` split for the readout (COMPASS-1.1.md §9.10): "72°"
    /// then "ENE".
    var headingReadout: CompassReadout? {
        heading.map { heading in
            let parts = formatter.bearingParts(for: heading)
            return CompassReadout(lead: parts.degrees, direction: parts.direction)
        }
    }

    /// `lockText` split for the pill: "Moonrise · 72°" then "ENE".
    var lockReadout: CompassReadout? {
        lockedTarget.map { target in
            let parts = formatter.bearingParts(for: target.azimuth)
            return CompassReadout(lead: "\(Self.name(of: target.kind)) · \(parts.degrees)", direction: parts.direction)
        }
    }

    /// The heading, then the bottom bar's note (COMPASS-1.1.md §9.4: the
    /// bar reads right after the readout, so its text is spoken here and
    /// the bar keeps only its button for VoiceOver). An untrustworthy
    /// number isn't read out. The aha line is announced as it appears
    /// instead.
    var headingAccessibilityLabel: String {
        let note = bottomNote.flatMap { $0.kind == .aha ? nil : $0.text }
        guard !isLowAccuracy, let heading else {
            // The low-accuracy note already starts "Compass accuracy is low."
            if bottomNote?.kind == .lowAccuracy, let note { return note }
            return [Self.lowAccuracyText, note].compactMap(\.self).joined(separator: ". ")
        }
        return ["Heading \(formatter.spokenBearing(for: heading))", note].compactMap(\.self).joined(separator: ". ")
    }

    /// Why accuracy is low (4.10), or `nil`: not low, no reading yet, or no
    /// compass at all (`.unavailable`), where neither the tip nor Settings
    /// would help.
    var lowAccuracyReason: LowAccuracyReason? {
        guard isLowAccuracy, let reading, reading != .unavailable else { return nil }
        return isPreciseLocationOff ? .preciseLocationOff : .interference
    }

    /// The bar fixed above the home indicator (COMPASS-1.1.md §9.4), only
    /// with the compass shown (Here or Nearby; location off and Far keep
    /// their note in place of the compass). One at a time, by priority:
    /// Precise off > low accuracy > Nearby > aha. Low accuracy needs a
    /// reading, so nothing flashes up before the first one; with no compass
    /// at all (`.unavailable`) it still shows, since the spec has one line
    /// for every reason.
    var bottomNote: CompassBottomNote? {
        guard visibility.showsCompass else { return nil }
        // Sensors paused or starting: the last note, unless Precise has
        // been turned on meanwhile.
        if reading == nil, let held = heldBottomNote,
           held.kind != .preciseOff || isPreciseLocationOff {
            return held
        }
        return liveBottomNote
    }

    /// `bottomNote` from the current reading and context.
    private var liveBottomNote: CompassBottomNote? {
        if lowAccuracyReason == .preciseLocationOff, preciseConfirmation == nil {
            return CompassBottomNote(kind: .preciseOff, text: Self.preciseLocationOffText)
        }
        if isLowAccuracy, reading != nil {
            return CompassBottomNote(kind: .lowAccuracy, text: Self.lowAccuracyNote)
        }
        if let nearbyNote {
            return CompassBottomNote(kind: .nearby, text: nearbyNote)
        }
        if let preciseConfirmation {
            return CompassBottomNote(kind: .aha, text: preciseConfirmation)
        }
        return nil
    }

    /// "Moonset · 288° WNW": the lock label's format.
    func targetText(for target: CompassTarget) -> String {
        "\(Self.name(of: target.kind)) · \(formatter.bearing(for: target.azimuth))"
    }

    /// The dial's VoiceOver label: "Targets: moonrise, 72 degrees
    /// east-northeast; Moon now, west, 275 degrees". There are no target rows
    /// (4.7), so this is how VoiceOver hears each bearing, including the live
    /// moon's, which the moon table doesn't have. `nil` with no targets.
    var targetsAccessibilityLabel: String? {
        guard !targets.isEmpty else { return nil }
        let parts = targets.map { target in
            switch target.kind {
            case .moonrise, .moonset:
                "\(Self.name(of: target.kind).lowercased()), \(formatter.spokenBearing(for: target.azimuth))"
            case .moon:
                moonNowText(for: target.azimuth)
            }
        }
        return "Targets: " + parts.joined(separator: "; ")
    }

    /// "Moon now, west, 275 degrees": "now" says it's where the moon is,
    /// not where it rises (the marker looked like a second moonrise on
    /// device), and the direction leads, as on the moon card.
    private func moonNowText(for azimuth: Double) -> String {
        "\(Self.moonNowName), \(formatter.spokenName(for: azimuth)), \(formatter.spokenDegrees(for: azimuth))"
    }

    /// "Pointing at moonrise, 72 degrees east-northeast".
    var lockAccessibilityLabel: String? {
        guard let lockedTarget else { return nil }
        let name = Self.name(of: lockedTarget.kind).lowercased()
        return "Pointing at \(name), \(formatter.spokenBearing(for: lockedTarget.azimuth))"
    }

    /// Display name, also the first word of the lock copy.
    static func name(of kind: CompassTarget.Kind) -> String {
        switch kind {
        case .moonrise: "Moonrise"
        case .moonset: "Moonset"
        case .moon: "Moon"
        }
    }

    // MARK: - Inputs

    /// The place, day or permission changed. Rebuilds the targets, so a day
    /// that becomes today gets its "Moon" target straight away.
    func update(_ context: CompassContext) {
        let wasPreciseLocationOff = isPreciseLocationOff
        self.context = context
        let glyph = context.moonDay.map {
            PhaseGlyphGeometry(illumination: $0.illumination, phaseAngle: $0.phaseAngle)
        }
        if glyph != moonGlyph { moonGlyph = glyph }
        isPreciseLocationOff = context.isPreciseLocationOff
        hasDetectedPlace = context.detectedPlace != nil
        visibility = Self.visibility(for: context)
        // Foreground isn't required: coming back from Settings, the context
        // arrives before the scene counts as active again.
        if wasPreciseLocationOff, !isPreciseLocationOff, visibility.showsCompass, isOnScreen {
            showPreciseConfirmation()
        }
        nearbyNote = nil
        farMessage = nil
        if let place = context.place {
            switch visibility {
            case .nearby:
                if let detected = context.detectedPlace {
                    nearbyNote = Self.nearbyText(detected: detected.nameWithRegion, selected: place.nameWithRegion)
                }
            case .far:
                farMessage = Self.farText(selected: place.nameWithRegion)
            case .hidden, .locationOff, .here:
                break
            }
        }
        rebuildTargets()
        updateSensors()
    }

    /// The compass scrolled into or out of view, or was inserted or removed.
    func setOnScreen(_ onScreen: Bool) {
        isOnScreen = onScreen
        updateSensors()
    }

    /// Where the dial's centre is against the fold (COMPASS-1.1.md §9.6).
    /// The pinned bar shows the live heading, so the sensors run while it's
    /// up, even with all of the compass below the fold (AX sizes).
    func setDialCentreBelowFold(_ below: Bool) {
        guard below != isDialCentreBelowFold else { return }
        isDialCentreBelowFold = below
        updateSensors()
    }

    /// Back in the foreground: the moon may have risen or set meanwhile, so
    /// recompute now rather than at the next tick (COMPASS.md §1).
    func sceneDidBecomeActive() {
        isInForeground = true
        rebuildTargets()
        updateSensors()
    }

    func sceneDidEnterBackground() {
        isInForeground = false
        updateSensors()
    }

    // MARK: - Aha line (4.12)

    /// Shows the aha line, then clears it. No haptic of its own: the first
    /// lock's tap is the payoff.
    private func showPreciseConfirmation() {
        preciseConfirmation = Self.preciseConfirmationText
        preciseConfirmationTask?.cancel()
        let sleep = sleep
        preciseConfirmationTask = Task { [weak self] in
            do {
                try await sleep(Self.preciseConfirmationDuration)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.preciseConfirmation = nil
        }
    }

    // MARK: - DEBUG readout (device diagnosis, 4.8/4.9)

    #if DEBUG
    /// Plain lines for the DEBUG-only readout under the compass, so a device
    /// test shows why it's in the state it's in. Never in release builds.
    var debugReadout: [String] {
        let heading = reading?.trueHeading.map { String(format: "%.1f° true", $0) } ?? "none"
        let accuracy = reading?.accuracy.map { String(format: "±%.1f°", $0) } ?? "unknown"
        let targetList = targets.isEmpty
            ? "none"
            : targets.map { "\(Self.name(of: $0.kind).lowercased()) \(Int($0.azimuth.rounded()))" }
                .joined(separator: ", ")
        return [
            "heading: \(heading)",
            "accuracy: \(accuracy)\(isLowAccuracy ? " (low)" : "")",
            "accuracyAuthorization: \(isPreciseLocationOff ? "reduced" : "full")",
            "reason: \(lowAccuracyReason.map { "\($0)" } ?? "none")",
            "visibility: \(visibility)",
            "detected: \(hasDetectedPlace ? "yes" : "no")",
            "targets: \(targetList)",
            "lock: \(lockedKind.map { Self.name(of: $0).lowercased() } ?? "none")",
            "sensors: \(isSensing ? "running" : "stopped")",
        ]
    }
    #endif

    // MARK: - Visibility (COMPASS.md §2)

    /// Near where you're standing: a searched city can't prove you're in
    /// it, so it's measured against the detected location.
    static func visibility(for context: CompassContext) -> Visibility {
        guard let place = context.place else { return .hidden }
        guard context.authState.isAuthorized else { return .locationOff }
        if place.isCurrentLocation { return .here }
        guard let detected = context.detectedPlace else { return .hidden }
        if place.isSameCity(as: detected) { return .here }
        return place.distanceMeters(to: detected) <= nearbyRadiusMeters ? .nearby : .far
    }

    // MARK: - Targets

    private func rebuildTargets() {
        let moment = now()
        var rebuilt: [CompassTarget] = []
        if visibility.showsCompass, let moonDay = context.moonDay {
            if let rise = moonDay.rise {
                rebuilt.append(CompassTarget(kind: .moonrise, azimuth: rise.azimuth))
            }
            if let set = moonDay.set {
                rebuilt.append(CompassTarget(kind: .moonset, azimuth: set.azimuth))
            }
        }
        let moon = liveMoonTarget(at: moment)
        if let moon {
            rebuilt.append(moon)
        }
        pass = passToDraw(isMoonUp: moon != nil, at: moment)
        nextRise = nil
        updateArc(moon: moon, at: moment)
        updateUpNow(moon: moon, at: moment)
        setTargets(rebuilt)
    }

    /// A tick: only the moon moves, so only its target is recomputed. This
    /// is also where it appears or disappears as the moon rises or sets on
    /// screen, and the arc switches between the live pass and the next one.
    private func refreshMoonTarget() {
        let moment = now()
        let wasMoonUp = targets.contains { $0.kind == .moon }
        var refreshed = targets.filter { $0.kind != .moon }
        let moon = liveMoonTarget(at: moment)
        if let moon {
            refreshed.append(moon)
        }
        if (moon != nil) != wasMoonUp {
            pass = passToDraw(isMoonUp: moon != nil, at: moment)
        }
        updateArc(moon: moon, at: moment)
        updateUpNow(moon: moon, at: moment)
        setTargets(refreshed)
    }

    /// Only on today, and only while it's up (COMPASS.md §1, §3).
    private func liveMoonTarget(at moment: Date) -> CompassTarget? {
        guard visibility.showsCompass, context.isToday, let place = context.place else { return nil }
        let position = moonService.moonPosition(for: place, at: moment)
        guard position.isUp else { return nil }
        return CompassTarget(kind: .moon, azimuth: position.azimuth)
    }

    // MARK: - Arc (DESIGN-1.1.md §3.3a)

    /// Moon up (so today): the pass under way, whose rise may be yesterday
    /// and set tomorrow. Otherwise the pass that starts at the selected
    /// day's moonrise; none without one.
    private func passToDraw(isMoonUp: Bool, at moment: Date) -> MoonPass? {
        guard visibility.showsCompass, let place = context.place else { return nil }
        if isMoonUp {
            return moonService.moonPass(for: place, containing: moment)
        }
        guard let rise = context.moonDay?.rise else { return nil }
        return moonService.moonPass(
            for: place,
            containing: rise.date.addingTimeInterval(Self.passLookupDelayAfterRise)
        )
    }

    private func updateArc(moon: CompassTarget?, at moment: Date) {
        var newArc: CompassArc?
        if let pass, let start = pass.path.first, let end = pass.path.last {
            newArc = CompassArc(
                startAzimuth: start,
                endAzimuth: end,
                moonAzimuth: moon.map { pass.pathAzimuth(for: $0.azimuth, at: moment) }
            )
        }
        if newArc != arc { arc = newArc }
    }

    // MARK: - Up now (COMPASS-1.1.md §3)

    /// Where the live Moon target can exist: today, with the compass shown.
    /// Moon up: its bearing and the pass behind the arc. Down: the next
    /// rise, looked up again only once it's a minute past (the moon may
    /// read down for a moment at its rise, like the pass lookup).
    private func updateUpNow(moon: CompassTarget?, at moment: Date) {
        var newUpNow: UpNow?
        if visibility.showsCompass, context.isToday, let place = context.place {
            if let moon {
                nextRise = nil
                newUpNow = upNowFormatter.up(azimuth: moon.azimuth, pass: pass, at: moment, in: place.timeZone)
            } else {
                if nextRise.map({ moment > $0.date.addingTimeInterval(Self.passLookupDelayAfterRise) }) ?? true {
                    nextRise = moonService.nextMoonrise(for: place, after: moment)
                }
                newUpNow = upNowFormatter.down(nextRise: nextRise?.date, at: moment, in: place.timeZone)
            }
        } else {
            nextRise = nil
        }
        if newUpNow != upNow { upNow = newUpNow }
    }

    private func setTargets(_ newTargets: [CompassTarget]) {
        if newTargets != targets { targets = newTargets }
        updateLock()
    }

    // MARK: - Lock

    private func updateLock() {
        let next = CompassLock.next(
            locked: lockedKind,
            heading: reading?.trueHeading,
            isLowAccuracy: isLowAccuracy,
            targets: targets
        )
        guard next != lockedKind else { return }
        if next != nil {
            lockAcquisitionCount += 1
            if !hasLockedThisLaunch { hasLockedThisLaunch = true }
        }
        lockedKind = next
    }

    private func apply(_ newReading: HeadingReading) {
        reading = newReading
        if heldBottomNote != nil { heldBottomNote = nil }
        let low = CompassAccuracy.isLow(after: newReading, wasLow: isLowAccuracy)
        if low != isLowAccuracy { isLowAccuracy = low }
        updateLock()
    }

    // MARK: - Sensors (COMPASS.md §1 Sensor lifecycle)

    private var shouldSense: Bool {
        visibility.showsCompass && (isOnScreen || showsPinnedBar) && isInForeground
    }

    private func updateSensors() {
        if shouldSense {
            startSensorsIfNeeded()
        } else {
            stopSensors()
        }
    }

    private func startSensorsIfNeeded() {
        guard headingTask == nil else { return }

        let stream = headingService.start()
        isSensing = true
        headingTask = Task { [weak self] in
            for await reading in stream {
                self?.apply(reading)
            }
        }

        let interval = moonRefreshInterval
        let sleep = sleep
        moonRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await sleep(interval)
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                self?.refreshMoonTarget()
            }
        }
    }

    /// Clears the reading and lock too: a stale heading mustn't be shown or
    /// hold a lock after the sensors are off.
    private func stopSensors() {
        guard headingTask != nil else { return }

        headingService.stop()
        headingTask?.cancel()
        headingTask = nil
        isSensing = false
        moonRefreshTask?.cancel()
        moonRefreshTask = nil

        // The aha line is a moment, not a state, so it isn't kept.
        heldBottomNote = liveBottomNote.flatMap { $0.kind == .aha ? nil : $0 }
        reading = nil
        isLowAccuracy = true
        lockedKind = nil
    }
}
