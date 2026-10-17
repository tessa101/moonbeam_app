//
//  MoonEntry.swift
//  moonbeam-app
//

import SwiftUI

/// Got it → `noCity` through the moon (STEP-5.14 §6.3): the Aha flight in
/// reverse. The text on "That's okay" fades out around its moon, the moon
/// flies from its 64 pt frame up to the loader's resting frame, rides the
/// month for a beat, then the loader fades out as the `noCity` blocks load in.
///
/// Nothing is being located, so the hold is a deliberate beat, not a wait.
/// Every duration lives here (§6.2's starting values); if it feels slow,
/// shorten the hold first, then the flight.
enum MoonEntry {

    // MARK: - Durations (§6.2)

    /// The title, body and buttons fade out; the moon stays.
    static let textExitDuration = OnboardingScreenChange.exitDuration
    /// The moon's flight to the loader's frame: the Aha flight's length and
    /// curve, travelling the other way.
    static let flightDuration = LocationLoader.flightDuration
    /// On the loader's frame, riding the month, before the screen.
    static let holdDuration: TimeInterval = 0.6
    /// The loader's fade out as the `noCity` blocks load in.
    static let exitFadeDuration: TimeInterval = 0.25

    /// Reduce Motion: no flight; the moon cross-fades to the loader's frame
    /// with the loader's own fade, and the hold is shortened.
    static let reduceMotionCrossFadeDuration = LaunchPhaseCycle.reduceMotionFade
    static let reduceMotionHoldDuration: TimeInterval = 0.3

    // MARK: - Look

    /// The declined screen's dimming, which the moon starts from.
    static let startOpacity = OnboardingDeclinedScreen.moonOpacity

    // MARK: - Over time

    /// The steps, in order, from the Got it tap.
    enum Stage: Equatable, CaseIterable {
        case textExit
        /// The flight, or with Reduce Motion the cross-fade.
        case flight
        case hold
        /// The loader leaves and `noCity` loads in.
        case exit
    }

    /// Which step is under way `elapsed` seconds after Got it.
    static func stage(atElapsed elapsed: TimeInterval, reducesMotion: Bool) -> Stage {
        if elapsed < textExitDuration { return .textExit }
        if elapsed < landingTime(reducesMotion: reducesMotion) { return .flight }
        if elapsed < duration(reducesMotion: reducesMotion) { return .hold }
        return .exit
    }

    /// From Got it to the moon on the loader's frame.
    static func landingTime(reducesMotion: Bool) -> TimeInterval {
        textExitDuration + (reducesMotion ? reduceMotionCrossFadeDuration : flightDuration)
    }

    /// From Got it to the loader's exit: the moon has landed and held.
    static func duration(reducesMotion: Bool) -> TimeInterval {
        landingTime(reducesMotion: reducesMotion) + (reducesMotion ? reduceMotionHoldDuration : holdDuration)
    }

    /// How far along the flight is, eased with the Aha flight's curve,
    /// `0...1`: 0 through the text exit, 1 from the landing.
    static func flightProgress(since start: Date, at date: Date) -> Double {
        let fraction = (date.timeIntervalSince(start) - textExitDuration) / flightDuration
        return AhaFlight.curve.value(at: min(max(fraction, 0), 1))
    }
}
