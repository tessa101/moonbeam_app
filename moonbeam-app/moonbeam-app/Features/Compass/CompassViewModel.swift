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
/// on screen (the view reports scroll-in/out), and the app is in the
/// foreground. While they run, a task holds the heading stream and iterates
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
        /// location. Compass, plus "Directions for {City}".
        case nearby

        /// Further than that. No compass, just the Far message.
        case far

        /// Here and Nearby get the live compass (and its sensors).
        var showsCompass: Bool { self == .here || self == .nearby }
    }

    // MARK: - Constants

    /// How often the live "Moon" target is recomputed (COMPASS.md §1). The
    /// moon's azimuth moves about a quarter of a degree a minute.
    static let defaultMoonRefreshInterval = Duration.seconds(30)

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

    /// Shown, and read by VoiceOver, while the heading can't be trusted.
    static let lowAccuracyText = "Compass accuracy is low"

    /// In place of the compass beyond the nearby radius. Never a distance:
    /// with the city name, that would reveal roughly where someone is.
    static let farMessage = "Compass is only available near this location"

    // MARK: - Observed state

    private(set) var visibility: Visibility = .hidden

    /// "Directions for Huntington Beach" in the Nearby state, else `nil`.
    /// Says what it shows, not that it's approximate: at ≤ 60 mi the error
    /// is under 1°. Never a distance. Stored (not derived from `context`,
    /// which isn't observed) so moving between two Nearby cities updates it.
    private(set) var nearbyNote: String?

    /// Moonrise and moonset for the selected day (when that day has them),
    /// then the moon if it's today and it's up.
    private(set) var targets: [CompassTarget] = []

    /// The latest reading, or `nil` while the sensors are off.
    private(set) var reading: HeadingReading?

    /// Low accuracy, with hysteresis (`CompassAccuracy`): in above 25°, out
    /// below 20°. Stored because the rule depends on the previous state.
    /// Starts, and returns to, low whenever there's no reading.
    private(set) var isLowAccuracy = true

    private(set) var lockedKind: CompassTarget.Kind?

    /// The heading and location sensors are running.
    private(set) var isSensing = false

    /// From the context: Precise Location is off for the app.
    private(set) var isPreciseLocationOff = false

    /// From the context: something has been detected this session. Only the
    /// DEBUG readout uses it, to tell "Nothing detected" apart (4.8).
    private(set) var hasDetectedPlace = false

    /// Goes up by one each time a lock is acquired, including a switch
    /// straight from one target to another. The view plays the haptic when
    /// it changes (COMPASS.md §1, 4.5), so release and holding stay silent.
    private(set) var lockAcquisitionCount = 0

    // MARK: - Dependencies

    private let headingService: any HeadingService
    private let moonService: any MoonService
    private let now: () -> Date
    private let moonRefreshInterval: Duration
    private let sleep: @Sendable (Duration) async throws -> Void
    private let formatter = CompassFormatter()

    // MARK: - Bookkeeping

    @ObservationIgnored private var context = CompassContext.empty
    @ObservationIgnored private var isOnScreen = false
    @ObservationIgnored private var isInForeground = true

    /// Iterates, and so holds, the heading stream. Non-nil exactly while the
    /// sensors run.
    @ObservationIgnored private var headingTask: Task<Void, Never>?

    /// Ticks the "Moon" target refresh while the sensors run.
    @ObservationIgnored private var moonRefreshTask: Task<Void, Never>?

    // MARK: - Init

    /// - Parameters:
    ///   - now: the clock the "Moon" target is computed for.
    ///   - sleep: the wait between "Moon" refreshes; injectable so tests
    ///     can tick it by hand.
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

    var lockedTarget: CompassTarget? {
        guard let lockedKind else { return nil }
        return targets.first { $0.kind == lockedKind }
    }

    /// "72° ENE", or `nil` with no true heading.
    var headingText: String? {
        heading.map(formatter.bearing(for:))
    }

    /// "Moonrise · 72° ENE": the target's own bearing, not the heading's.
    var lockText: String? {
        lockedTarget.map(targetText(for:))
    }

    var headingAccessibilityLabel: String {
        guard !isLowAccuracy, let heading else { return Self.lowAccuracyText }
        return "Heading \(formatter.spokenBearing(for: heading))"
    }

    /// "Moonset · 288° WNW": the lock label's format.
    func targetText(for target: CompassTarget) -> String {
        "\(Self.name(of: target.kind)) · \(formatter.bearing(for: target.azimuth))"
    }

    /// The dial's VoiceOver label: "Targets: moonrise, 72 degrees
    /// east-northeast; moon, 140 degrees southeast". There are no target rows
    /// (4.7), so this is how VoiceOver hears each bearing, including the live
    /// moon's, which the moon table doesn't have. `nil` with no targets.
    var targetsAccessibilityLabel: String? {
        guard !targets.isEmpty else { return nil }
        let parts = targets.map { target in
            "\(Self.name(of: target.kind).lowercased()), \(formatter.spokenBearing(for: target.azimuth))"
        }
        return "Targets: " + parts.joined(separator: "; ")
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
        self.context = context
        isPreciseLocationOff = context.isPreciseLocationOff
        hasDetectedPlace = context.detectedPlace != nil
        visibility = Self.visibility(for: context)
        nearbyNote = visibility == .nearby ? context.place.map { "Directions for \($0.shortName)" } : nil
        rebuildTargets()
        updateSensors()
    }

    /// The compass scrolled into or out of view, or was inserted or removed.
    func setOnScreen(_ onScreen: Bool) {
        isOnScreen = onScreen
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
        var rebuilt: [CompassTarget] = []
        if visibility.showsCompass, let moonDay = context.moonDay {
            if let rise = moonDay.rise {
                rebuilt.append(CompassTarget(kind: .moonrise, azimuth: rise.azimuth))
            }
            if let set = moonDay.set {
                rebuilt.append(CompassTarget(kind: .moonset, azimuth: set.azimuth))
            }
        }
        if let moon = liveMoonTarget() {
            rebuilt.append(moon)
        }
        setTargets(rebuilt)
    }

    /// A tick: only the moon moves, so only its target is recomputed. This
    /// is also where it appears or disappears as the moon rises or sets on
    /// screen.
    private func refreshMoonTarget() {
        var refreshed = targets.filter { $0.kind != .moon }
        if let moon = liveMoonTarget() {
            refreshed.append(moon)
        }
        setTargets(refreshed)
    }

    /// Only on today, and only while it's up (COMPASS.md §1, §3).
    private func liveMoonTarget() -> CompassTarget? {
        guard visibility.showsCompass, context.isToday, let place = context.place else { return nil }
        let position = moonService.moonPosition(for: place, at: now())
        guard position.isUp else { return nil }
        return CompassTarget(kind: .moon, azimuth: position.azimuth)
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
        if next != nil { lockAcquisitionCount += 1 }
        lockedKind = next
    }

    private func apply(_ newReading: HeadingReading) {
        reading = newReading
        let low = CompassAccuracy.isLow(after: newReading, wasLow: isLowAccuracy)
        if low != isLowAccuracy { isLowAccuracy = low }
        updateLock()
    }

    // MARK: - Sensors (COMPASS.md §1 Sensor lifecycle)

    private var shouldSense: Bool {
        visibility.showsCompass && isOnScreen && isInForeground
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

        reading = nil
        isLowAccuracy = true
        lockedKind = nil
    }
}
