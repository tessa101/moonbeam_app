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

    /// COMPASS.md §2.
    enum Visibility: Equatable {
        /// No place yet, or a city other than where you are.
        case hidden

        /// Location isn't authorized: the enable-location hint instead.
        case locationOff

        case shown
    }

    // MARK: - Constants

    /// How often the live "Moon" target is recomputed (COMPASS.md §1). The
    /// moon's azimuth moves about a quarter of a degree a minute.
    static let defaultMoonRefreshInterval = Duration.seconds(30)

    // MARK: - Placeholder copy (final copy is in the design pass)

    /// In place of the compass when location is off (COMPASS.md §2).
    static let locationOffHint = "Turn on location to use the compass."

    /// Leads into the existing Location Off flow.
    static let turnOnLocationTitle = "Turn On Location"

    /// Shown, and read by VoiceOver, while the heading can't be trusted.
    static let lowAccuracyText = "Compass accuracy is low"

    // MARK: - Observed state

    private(set) var visibility: Visibility = .hidden

    /// Moonrise and moonset for the selected day (when that day has them),
    /// then the moon if it's today and it's up.
    private(set) var targets: [CompassTarget] = []

    /// The latest reading, or `nil` while the sensors are off.
    private(set) var reading: HeadingReading?

    private(set) var lockedKind: CompassTarget.Kind?

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

    /// No reading yet counts as low accuracy: there's nothing to trust.
    var isLowAccuracy: Bool { reading?.isLowAccuracy ?? true }

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

    /// A target row: "Moonset · 288° WNW".
    func targetText(for target: CompassTarget) -> String {
        "\(Self.name(of: target.kind)) · \(formatter.bearing(for: target.azimuth))"
    }

    /// "Moonset, 288 degrees west-northwest".
    func targetAccessibilityLabel(for target: CompassTarget) -> String {
        "\(Self.name(of: target.kind)), \(formatter.spokenBearing(for: target.azimuth))"
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
        visibility = Self.visibility(for: context)
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

    // MARK: - Visibility (COMPASS.md §2)

    /// Only where you're standing: a searched city can't prove you're in it.
    static func visibility(for context: CompassContext) -> Visibility {
        guard let place = context.place else { return .hidden }
        guard context.authState.isAuthorized else { return .locationOff }
        if place.isCurrentLocation { return .shown }
        if let detected = context.detectedPlace, place.isSameCity(as: detected) { return .shown }
        return .hidden
    }

    // MARK: - Targets

    private func rebuildTargets() {
        var rebuilt: [CompassTarget] = []
        if visibility == .shown, let moonDay = context.moonDay {
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
        guard visibility == .shown, context.isToday, let place = context.place else { return nil }
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
        let next = CompassLock.next(locked: lockedKind, reading: reading, targets: targets)
        guard next != lockedKind else { return }
        if next != nil { lockAcquisitionCount += 1 }
        lockedKind = next
    }

    private func apply(_ newReading: HeadingReading) {
        reading = newReading
        updateLock()
    }

    // MARK: - Sensors (COMPASS.md §1 Sensor lifecycle)

    private var shouldSense: Bool {
        visibility == .shown && isOnScreen && isInForeground
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
        moonRefreshTask?.cancel()
        moonRefreshTask = nil

        reading = nil
        lockedKind = nil
    }
}
