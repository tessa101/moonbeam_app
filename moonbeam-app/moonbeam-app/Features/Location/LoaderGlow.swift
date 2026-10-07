//
//  LoaderGlow.swift
//  moonbeam-app
//

import SwiftUI

/// The loader moon's glow over time (LOADER.md §10.2, §10.4; handoff
/// "Glow"): it breathes with the month while searching, pulses once the moon
/// has stopped for a message, and flares once for "Aha".
///
/// Breathing stays tied to the phase, brightest at full, as built in 5.9
/// (the built version wins over the handoff's free-running loop). A change
/// of mode blends from wherever the glow was over `blendDuration`, so it
/// never jumps.
///
/// `nonisolated`: a plain value, testable without a view.
nonisolated struct LoaderGlow: Equatable {

    // MARK: - Types

    enum Mode: Equatable {
        /// Searching: with the month (`PhaseCycle.glowLevel`).
        case breathe
        /// Stopped: the handoff's 1.8 s `pulse` loop.
        case pulse
        /// "Aha": the handoff's 1.4 s `flare`, once, then holds its end.
        case flare
    }

    /// What the view draws.
    struct Look: Equatable {
        var opacity: Double
        var scale: Double
    }

    // MARK: - Constants

    /// The handoff's `pulse`: 1.8 s ease-in-out, opacity .35 → 1, scale
    /// .9 → 1.18, and back.
    static let pulsePeriod: TimeInterval = 1.8
    static let pulseOpacityRange: ClosedRange<Double> = 0.35...1
    static let pulseScaleRange: ClosedRange<Double> = 0.9...1.18

    /// The handoff's `flare`: 1.4 s ease-out, once. Opacity .5 → 1 → .8,
    /// scale 1 → 1.7 → 1.15, peaking halfway.
    static let flareDuration: TimeInterval = 1.4
    static let flareStart = Look(opacity: 0.5, scale: 1)
    static let flarePeak = Look(opacity: 1, scale: 1.7)
    static let flareEnd = Look(opacity: 0.8, scale: 1.15)
    private static let flarePeakFraction = 0.5

    /// How long a change of mode takes to blend in.
    static let blendDuration: TimeInterval = 0.3

    // MARK: - State

    let mode: Mode
    /// When the mode began.
    let since: Date
    /// The look when it began, blended away over `blendDuration`.
    let from: Look?

    /// Searching, from the start.
    static let breathing = LoaderGlow(mode: .breathe, since: .distantPast, from: nil)

    /// The same glow switched to `mode` at `date`, blending from how it
    /// looked then. `elapsed` is the moon's month time at `date`.
    func switching(to mode: Mode, at date: Date, elapsed: TimeInterval) -> LoaderGlow {
        guard mode != self.mode else { return self }
        // The flare starts from its own first frame.
        let from = mode == .flare ? nil : look(at: date, elapsed: elapsed)
        return LoaderGlow(mode: mode, since: date, from: from)
    }

    // MARK: - Reading it

    /// The look at `date`, with the moon at month time `elapsed`.
    func look(at date: Date, elapsed: TimeInterval) -> Look {
        look(at: date, litFraction: PhaseCycle.glowLevel(at: elapsed))
    }

    /// The look at `date`, with the moon `litFraction` lit: for the "Aha"
    /// ride, which isn't on the month's clock (§11.2.2).
    func look(at date: Date, litFraction: Double) -> Look {
        let seconds = max(0, date.timeIntervalSince(since))
        let target = Self.look(of: mode, seconds: seconds, litFraction: litFraction)
        guard let from, seconds < Self.blendDuration else { return target }
        return Self.mix(from, target, seconds / Self.blendDuration)
    }

    private static func look(of mode: Mode, seconds: TimeInterval, litFraction level: Double) -> Look {
        switch mode {
        case .breathe:
            return Look(
                opacity: interpolate(PhaseCycle.glowOpacityRange, level),
                scale: interpolate(PhaseCycle.glowScaleRange, level)
            )
        case .pulse:
            let level = pulseLevel(at: seconds)
            return Look(
                opacity: interpolate(pulseOpacityRange, level),
                scale: interpolate(pulseScaleRange, level)
            )
        case .flare:
            return flare(at: seconds)
        }
    }

    /// 0 → 1 → 0 over one pulse, eased each way.
    static func pulseLevel(at seconds: TimeInterval) -> Double {
        let phase = (seconds / pulsePeriod).truncatingRemainder(dividingBy: 1) * 2
        let rising = phase < 1
        let eased = UnitCurve.easeInOut.value(at: rising ? phase : phase - 1)
        return rising ? eased : 1 - eased
    }

    static func flare(at seconds: TimeInterval) -> Look {
        let fraction = min(1, seconds / flareDuration)
        let eased = UnitCurve.easeOut.value(at: fraction)
        if eased < flarePeakFraction {
            return mix(flareStart, flarePeak, eased / flarePeakFraction)
        }
        return mix(flarePeak, flareEnd, (eased - flarePeakFraction) / (1 - flarePeakFraction))
    }

    // MARK: - Helpers

    private static func mix(_ a: Look, _ b: Look, _ t: Double) -> Look {
        Look(opacity: a.opacity + (b.opacity - a.opacity) * t, scale: a.scale + (b.scale - a.scale) * t)
    }

    private static func interpolate(_ range: ClosedRange<Double>, _ fraction: Double) -> Double {
        range.lowerBound + (range.upperBound - range.lowerBound) * fraction
    }
}
