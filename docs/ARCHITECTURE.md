# Architecture

> *How* Moonbeam is built. Start small and write down the patterns so they stay consistent.
> Sections marked **TBD** get filled in after the first spike.

_Last updated: 2026-09-25_

---

## 1. Overview

```
┌──────────────┐    ┌───────────────────┐    ┌────────────────────────┐
│ MoonTableView│───▶│ MoonTableViewModel│───▶│ GeocodingService       │ → MapKit
│  (SwiftUI)   │◀───│   (@Observable)   │───▶│ MoonService (protocol) │
└──────────────┘    └───────────────────┘    │  └ AstronomyEngine impl│ → C lib
                                             └────────────────────────┘
```

**Pattern:** MVVM-lite. Views are dumb, view models own state, and services are
protocols injected into view models. No singletons.

## 2. Project structure

Xcode project: `moonbeam-app/moonbeam-app.xcodeproj`. Source lives in `moonbeam-app/moonbeam-app/`.

```
moonbeam-app/moonbeam-app/
├── App/                 # @main entry, dependency wiring
├── Features/
│   ├── Location/        # LocationViewModel, LocationScreen, LocationOffDialog
│   └── MoonTable/       # MoonTableView, MoonTableViewModel
├── Services/
│   ├── Moon/            # MoonService protocol + AstronomyEngineMoonService
│   └── Location/        # LocationService, PlaceSearchService, PlaceStore + real and fake impls
├── Models/              # Plain value types
├── Formatting/          # Compass, time, and percent formatters
└── Vendor/Astronomy/    # astronomy.c, astronomy.h, VERSION
moonbeam-appTests/       # Swift Testing, app-hosted: formatters, models, service vs ASTRONOMY.md §5
```

## 3. Data models

```swift
struct Place: Codable, Hashable, Sendable {
    let name: String            // "Sydney"
    let locality: String?       // "Sydney" — the city; repeats name, or nil if MapKit has none
    let region: String?         // "NSW"
    let country: String?        // "Australia"
    let latitude: Double
    let longitude: Double
    let timeZone: TimeZone      // the place's own; every displayed time uses it
    var isCurrentLocation: Bool // UI only: outside Codable and ==
}

struct PlaceSuggestion: Identifiable, Hashable, Sendable {
    let title: String           // "Sydney"
    let subtitle: String        // "NSW, Australia"
}

struct MoonEvent: Equatable {
    let date: Date
    let azimuth: Double         // degrees from true north
}

enum MoonPhase: String, CaseIterable {
    case new, waxingCrescent, firstQuarter, waxingGibbous
    case full, waningGibbous, lastQuarter, waningCrescent
}

struct MoonDay: Equatable {
    let place: Place
    let rise: MoonEvent?        // nil = no moonrise that day
    let set: MoonEvent?
    let phase: MoonPhase
    let phaseAngle: Double      // 0–360
    let illumination: Double    // 0.0–1.0
}
```

Models are plain values with no formatting logic. `Formatting/` turns them into strings.

## 4. Services

```swift
protocol MoonService {                                         // nonisolated
    func moonDay(for place: Place, on date: Date) -> MoonDay   // sync, pure, fast
}

protocol LocationService {                                     // @MainActor
    var authorizationState: LocationAuthState { get }
    func requestAuthorization() async -> LocationAuthState
    func currentPlace() async throws -> Place
}

protocol PlaceSearchService {                                  // @MainActor
    func suggestions(for query: String) -> AsyncThrowingStream<[PlaceSuggestion], any Error>
    func resolve(_ suggestion: PlaceSuggestion) async throws -> Place
}

protocol PlaceStore {                                          // @MainActor
    var lastViewed: Place? { get set }
}
```

- `MoonService` is synchronous, deterministic and `nonisolated`, so it's easy to test.
- The location services are async, can fail, and are the only network-touching code. They're
  main-actor isolated because `CLLocationManager` and MapKit expect a single, UI-bound home;
  the models they return stay `nonisolated` so results cross back out freely.
- All four get fake implementations for SwiftUI previews and tests.

`GeocodingService` from the first draft of this doc was superseded by `LocationService` +
`PlaceSearchService`: the spec calls for two distinct jobs (detect where you are, search for
anywhere) with different failure modes. See LOCATION.md.

## 5. State management

- The view model is `@Observable` and exposes `enum State { idle, loading, loaded(MoonDay), failed(String) }`.
- The view switches on `state`, with no scattered booleans.
- **TBD:** date selection state (V1.1).

## 6. Persistence

One thing: the last-viewed place, via `PlaceStore` → `UserDefaults` (LOCATION.md §6). Stored as a
JSON *array* capped at one entry, so the deferred recent-searches feature becomes a cap change
rather than a migration. **TBD:** saved places in SwiftData, if that feature happens.

## 7. Apple frameworks

| Framework | Use |
|---|---|
| SwiftUI | UI |
| Observation | `@Observable` view models |
| MapKit | City search (`MKLocalSearchCompleter`, `MKLocalSearch`) and reverse geocoding (`MKReverseGeocodingRequest`). **Settled 2026-09-25:** `CLGeocoder` and `MKMapItem.placemark` are deprecated in iOS 26 |
| CoreLocation | One-shot current location via `CLLocationUpdate.liveUpdates()`; authorization via `CLLocationManager` |
| Swift Testing | Unit tests |

## 8. Dependencies

| Dependency | Why | How |
|---|---|---|
| Astronomy Engine | Moon math | Vendored C source, pinned version |

Rule: no new dependency without an entry in `DECISIONS.md`.

## 9. API strategy

No runtime APIs besides Apple geocoding. USNO is used **only** to generate test
reference values. See `ASTRONOMY.md`.

## 10. Security & privacy

- No analytics, no third-party SDKs, and no data leaves the device except geocoding queries.
- Location permission: When In Use only, with a clear purpose string
  (`NSLocationWhenInUseUsageDescription`), requested on tap and never at launch.
  `NSLocationDefaultAccuracyReduced` is `YES` — city-level is all the moon maths needs.
- Privacy manifest (`PrivacyInfo.xcprivacy`) added before any TestFlight build.

## 11. Testing

- **Formatters:** exhaustive (compass boundaries at 11.25°, 348.75°, and so on).
- **MoonService:** reference cities from `ASTRONOMY.md` §5, within tolerance.
- **ViewModel:** state transitions with mock services.
- UI tests: none in V1.
