// Reference sketch only — adapt to the app's existing LocationService / navigation.
// Moon rendering + phase timing live in MoonLoader.swift.
import SwiftUI
import CoreLocation

enum LocationIssue { case firstAsk, appDenied, servicesOff, timeout }
enum FlowStep: Equatable { case entering, searching, message, systemPrompt, found, city }

enum FlowTiming {
    static let moonFadeIn: Double = 0.9          // opacity, ease-out; rise 8 pt over 1.2 s, cubic(0.16,1,0.3,1)
    static let labelDelay: Double = 0.32
    static let phaseStartDelay: Double = 0.84
    static let minSearchBeforeMessage: Double = 1.2
    static let messageFadeIn: Double = 0.45      // after 0.35 s delay, rise 16 pt
    static let resumeLabelDelay: Double = 0.2    // message removed instantly on return
    static let minSearchBeforeAha: Double = 1.8
    static let ahaHold: Double = 2.0
    static let ahaFadeOut: Double = 0.22         // drift up 3 pt
    static let moonToCard: Double = 0.85         // cubic(0.65,0,0.25,1)
    static let fixTimeout: Double = 10
}

func resolveIssue(_ m: CLLocationManager) -> LocationIssue? {
    guard CLLocationManager.locationServicesEnabled() else { return .servicesOff }
    switch m.authorizationStatus {
    case .notDetermined: return .firstAsk
    case .denied, .restricted: return .appDenied
    default: return nil                          // authorized → search; .timeout set by timer
    }
}
// Re-check on locationManagerDidChangeAuthorization and when scenePhase becomes .active.
// Message → set moonClock.stopping = true; show copy in moonClock.onFrozen.
// Fix → moonClock.stopping = false, remove message immediately, label in after resumeLabelDelay.
