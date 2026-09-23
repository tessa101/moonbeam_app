# Architecture

> *How* Moonbeam is built. Start small and write down the patterns so they stay consistent.
> Sections marked **TBD** get filled in after the first spike.

_Last updated: 2026-09-23_

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

```
Moonbeam/
├── App/                 # @main entry, dependency wiring
├── Features/
│   └── MoonTable/       # MoonTableView, MoonTableViewModel
├── Services/
│   ├── Moon/            # MoonService protocol + AstronomyEngineMoonService
│   └── Geocoding/       # GeocodingService protocol + MapKit impl
├── Models/              # Plain value types
├── Formatting/          # Compass, time, and percent formatters
└── Vendor/Astronomy/    # astronomy.c, astronomy.h, VERSION
MoonbeamTests/           # Swift Testing: formatters, services vs USNO values
```

## 3. Data models

```swift
struct Place: Equatable {
    let name: String            // "Los Angeles, CA"
    let latitude: Double
    let longitude: Double
    let timeZone: TimeZone
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
protocol MoonService {
    func moonDay(for place: Place, on date: Date) -> MoonDay   // sync, pure, fast
}

protocol GeocodingService {
    func place(for query: String) async throws -> Place
}
```

- `MoonService` is synchronous and deterministic, so it's easy to test.
- `GeocodingService` is async and can fail. It's the only network-touching code.
- Both get mock implementations for SwiftUI previews and tests.

## 5. State management

- The view model is `@Observable` and exposes `enum State { idle, loading, loaded(MoonDay), failed(String) }`.
- The view switches on `state`, with no scattered booleans.
- **TBD:** date selection state (V1.1).

## 6. Persistence

V1 has none. **TBD (V1.1):** the last-used city goes in `@AppStorage`, and saved places in SwiftData if that feature happens.

## 7. Apple frameworks

| Framework | Use |
|---|---|
| SwiftUI | UI |
| Observation | `@Observable` view models |
| MapKit | City → coordinates + time zone (**TBD:** confirm current geocoding API in spike, `MKGeocodingRequest` vs `CLGeocoder`) |
| CoreLocation | V1.1 current location |
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
- Location permission (V1.1): When In Use only, with a clear purpose string.
- Privacy manifest (`PrivacyInfo.xcprivacy`) added before any TestFlight build.

## 11. Testing

- **Formatters:** exhaustive (compass boundaries at 11.25°, 348.75°, and so on).
- **MoonService:** reference cities from `ASTRONOMY.md` §5, within tolerance.
- **ViewModel:** state transitions with mock services.
- UI tests: none in V1.
