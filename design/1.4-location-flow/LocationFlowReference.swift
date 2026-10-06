// Reference sketch only — adapt to the app's existing LocationService / navigation.
import SwiftUI
import CoreLocation

enum LocationIssue { case firstAsk, appDenied, servicesOff, timeout }
enum FlowStep: Equatable { case entering, searching, message, systemPrompt, found, city }

enum FlowTiming {
    static let phaseCycle: Double = 4.8          // s, full lunar cycle
    static let stopSpeedup: Double = 2.6         // run-out speed when stopping
    static let holdOffset: Double = 0.75         // onboarding phase (shadow x / diameter)
    static let labelDelay: Double = 0.32
    static let phaseStartDelay: Double = 0.84
    static let minSearchBeforeMessage: Double = 1.2
    static let resumeLabelDelay: Double = 0.2    // "gone instantly" return
    static let minSearchBeforeAha: Double = 1.8
    static let ahaHold: Double = 2.0
    static let fixTimeout: Double = 10
}

extension Color {
    static let msBg = Color(red: 0x1B/255, green: 0x15/255, blue: 0x19/255)
    static let msMoon = Color(red: 0xF2/255, green: 0xE6/255, blue: 0xCF/255)
    static let msAccent = Color(red: 0xF2/255, green: 0xC2/255, blue: 0x7B/255)
}

/// cubic-bezier(0.45, 0, 0.55, 1)
func phaseEase(_ x: Double) -> Double {
    var t = x
    for _ in 0..<8 {
        let X = ((0.7 * t - 1.05) * t + 1.35) * t - x
        let dX = (2.1 * t - 2.1) * t + 1.35
        if abs(dX) < 1e-6 { break }
        t = min(1, max(0, t - X / dX))
    }
    return (3 - 2 * t) * t * t
}

/// p in [0,1) → shadow x offset as fraction of diameter (matches the onboarding loader).
func shadowOffset(_ p: Double) -> Double {
    p < 0.5 ? phaseEase(p * 2) : -1 + phaseEase((p - 0.5) * 2)
}

struct MoonDisc: View {
    var diameter: CGFloat
    var offset: Double                // from shadowOffset(_:)
    var body: some View {
        ZStack {
            Circle().fill(Color.msMoon)
            Circle().fill(Color.msBg).offset(x: diameter * offset)
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .shadow(color: Color.msAccent.opacity(0.35), radius: 20)
    }
}

/// Drives the phase. `running == false` runs forward to the hold phase, then freezes and calls `onFrozen`.
@Observable final class MoonPhaseClock {
    var p: Double = 0
    var running = false
    var target: Double? = nil         // nil → hold phase
    var onFrozen: (() -> Void)?
    private var last: Date?

    func tick(_ now: Date) {
        let dt = min(0.05, now.timeIntervalSince(last ?? now)); last = now
        if running { p = (p + dt / FlowTiming.phaseCycle).truncatingRemainder(dividingBy: 1); return }
        let goal = target ?? holdP
        let d = (goal - p + 1).truncatingRemainder(dividingBy: 1)
        if d > 0.002 && d < 0.998 {
            p = (p + min(d, dt * FlowTiming.stopSpeedup / FlowTiming.phaseCycle)).truncatingRemainder(dividingBy: 1)
        } else { onFrozen?(); onFrozen = nil }
    }
    /// p where shadowOffset == holdOffset (first half).
    let holdP: Double = {
        var lo = 0.0, hi = 1.0
        for _ in 0..<30 { let m = (lo + hi) / 2; if phaseEase(m) < FlowTiming.holdOffset { lo = m } else { hi = m } }
        return lo / 2
    }()
}

// Usage:
// TimelineView(.animation) { ctx in
//     let _ = clock.tick(ctx.date)
//     MoonDisc(diameter: 132, offset: shadowOffset(clock.p))
// }
// Resolve the issue from CLLocationManager:
//   !CLLocationManager.locationServicesEnabled()      → .servicesOff
//   manager.authorizationStatus == .notDetermined     → .firstAsk
//   .denied / .restricted                             → .appDenied
//   authorized, no fix within FlowTiming.fixTimeout   → .timeout
// Re-check on locationManagerDidChangeAuthorization and when scenePhase becomes .active.
