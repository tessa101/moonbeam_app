# Decision Log

> One entry per meaningful choice. Newest at the top. Keep it short.
> Format: **date · decision**, then why and what else we considered.

---

### 2026-09-26 · Step 2.1: search sheet with recent cities (SEARCH-RECENTS.md)
- **Decision A: the sheet's "Use my location" row closes the sheet, then runs the main-screen
  flow.** The flow starts from the sheet's `onDismiss`, not from the tap. SwiftUI can't present
  the Location Off dialog while the search sheet is still up from the same view, so waiting keeps
  one code path and avoids stacked sheets. The dialog's "Search instead" does the reverse: it
  reopens the sheet once the dialog has closed.
- **Decision B: the location row is hidden when you're already viewing your detected location.**
  The sheet takes `showsUseMyLocation` from `LocationViewModel`, the same rule as the main-screen
  button. Tapping it there would only re-detect the same place.
- **Decision C: the "Back to {City}" chip is removed.** Recents cover going back to a saved city,
  one tap further away. `lastViewed` stays, because launch still falls back to it when location is
  off, denied or fails. A launch fix still doesn't overwrite it.
- **`PlaceStore` is class-only (`AnyObject`).** The plan's `mutating` recents helpers couldn't be
  called through a `let` reference, even on a class. Both stores are classes and a store is shared
  storage, not a value, so the protocol says so and the helpers aren't `mutating`.
  Considered: keeping `mutating` and using `var` everywhere, which reads as if the store were copied.
- **Resolve failures show `.failed`, whatever the error.** The sheet stays open and nothing is
  picked. The old `LocationViewModel.choose` showed "No matching cities" when a resolve found
  nothing, but that's wrong for a city the user just saw listed. The current "Can't search right
  now" copy isn't right either; logged for the design pass.
- **Type-ahead starts at 2 characters** (`SearchSheetViewModel.searchMinimumCharacters`). Shorter
  queries never reach `MKLocalSearchCompleter`: 0 characters shows recents, and 1 filters them
  (case- and diacritic-insensitive prefix match on any word of name, region or country). The
  threshold is one constant, so it can move to 3 after device testing.
- **8 recents, picked places only.** Picks from search (suggestions or recents) are added, most
  recent first, with the oldest dropped at 9. The detected location never is, because the
  "Use my location" row covers it. Re-picking the same city moves it to the top: same name, region
  and country, or within ~1 km (`Place.isSameCity(as:)`). Recents live under their own
  `recentPlaces` key, seeded once from an existing `lastViewed`. Whether that place was detected
  isn't persisted, so it's seeded regardless.

### 2026-09-25 · Location view model, screen and dialog: the calls LOCATION.md left open
- **The 10 s timeout cancels the fix; it doesn't just stop waiting.** `LocationViewModel` runs
  `currentPlace()` in its own task, with a watchdog that cancels it when the timeout fires.
  Cancelling is what ends `CLLocationUpdate.liveUpdates()`. If the view model only stopped
  awaiting, updates would keep running in the background. Tested with `FakeLocationService`,
  which now records cancelled fixes.
- **A launch detection doesn't overwrite the last-viewed place. Picks do.** §3 says that picking
  any place ("search, detect, or chip") makes it last-viewed. That covers a "Use my location" tap,
  but not the automatic fix at launch. If launch saved it, the "Back to {City}" chip would be gone
  by the next launch. So the chip reduces to one rule: show it when `lastViewed != place`.
- **A current location is never named after `mapItem.name`.** For a reverse geocode, that's the
  nearest street address. Without `cityName`, the mapping uses the first component of
  `cityWithContext`. With neither, it fails, and `CoreLocationService` throws
  `couldNotIdentifyPlace`. Search results keep the `mapItem.name` fallback, because there it names
  the locality the user picked. The rule is `Place.placeName(...)`, tested without MapKit. Because
  the mapping never produces a `locality` that differs from `name`, the "Mar Vista, Los Angeles"
  display-name test was dropped.
- **The time zone label uses the system abbreviation, which isn't always "AEST".** In `en_US`,
  `TimeZone.abbreviation(for:)` gives "GMT+10" for Sydney. Apple only has short names for zones
  the locale commonly uses. That's still unambiguous, so no hand-kept abbreviation table.
- **Refusing at the system prompt ends there.** No Location Off dialog follows straight away. The
  user just answered, so the dialog would nag. The next tap shows it.
- **A failed fix after a tap shows a message: "Couldn't find your location. Try again, or search
  for a city."** §3 only covers failures at launch, which fall back quietly. A tap that did
  nothing visible for up to 10 s would read as broken. Placeholder copy, for the design pass.
- **One dialog title for all three variants.** §4 gives only "Location is off for {AppName}".
- **Foreground re-check is transition-based.** Any change from not authorized to authorized while
  the app was in the background triggers a fetch, whether or not the user got to Settings through
  the dialog. Returns from the system prompt are skipped, so they don't start a second fetch.

### 2026-09-25 · Location services: the API choices behind LOCATION.md §6
Five choices made while building `Place`, `LocationService`, `PlaceSearchService` and `PlaceStore`.
The screen, the view model and the Location Off dialog are still to come.

- **The one-shot fix is `CLLocationUpdate.liveUpdates()`, stopped after the first location.** It's
  the async-native path, so there's no delegate bridging for the fix itself. `requestLocation()`
  would work too, but needs a delegate and a continuation. The `authorizationDenied`,
  `authorizationRestricted` and `locationUnavailable` flags have to be checked as well: the sequence
  doesn't *end* when a fix becomes impossible, it just stops yielding, which would hang the caller.
  Authorization still goes through `CLLocationManager.requestWhenInUseAuthorization()` — the only
  API that controls *when* the prompt appears, which §3 depends on.
- **Reverse geocoding is `MKReverseGeocodingRequest`, as §6 requires.** Confirmed against the iOS 26
  SDK: `MKMapItem.placemark` and `CLGeocoder` are deprecated in 26, and `MKMapItem` gained
  `location`, `address` and `addressRepresentations`.
- **`Place.region` is derived by string, because iOS 26 exposes no administrative-area property.**
  `MKAddressRepresentations` gives `cityName` ("Sydney") and `cityWithContext` ("Sydney, NSW") and
  nothing between them; the component-wise route was `MKPlacemark.administrativeArea`, the very API
  §6 tells us to avoid. So `Place.regionComponent` takes whatever `cityWithContext` has beyond the
  city, and returns `nil` unless the city is confirmed to be the leading component — an unexpected
  format yields no region rather than a wrong one. Covered by tests, rejection cases included.
  Worth revisiting if a later SDK adds the property.
- **`suggestions(for:)` returns an `AsyncThrowingStream`, not the `AsyncStream` §6 specifies.**
  §3 asks for a "Can't search right now. Check your connection." state, and a non-throwing stream
  can't tell a failed search from one that matched nothing. LOCATION.md §6 updated to match.
- **`resolve(_:)` re-searches by address text rather than replaying the `MKLocalSearchCompletion`.**
  §6 says "via `MKLocalSearch`", which this is: the suggestion's two displayed lines are rejoined
  into a `naturalLanguageQuery`, filtered to localities. Replaying the completion object would be
  marginally more precise, but `MKLocalSearchCompletion` isn't `Sendable`, so keeping one would stop
  `PlaceSuggestion` being a value type that fakes and previews can construct.
- **The time zone label compares *offsets*, not identifiers.** §5 says "whenever
  `place.timeZone` ≠ `TimeZone.current`", which reads as identifier equality. Compared that way,
  "US/Pacific" and "America/Los_Angeles" would label a place as elsewhere while showing identical
  times. `Place.isInDifferentTimeZone(from:on:)` takes the device zone as a parameter, which also
  makes it testable — a test process can't change `TimeZone.current`.
- **Isolation split:** these three services are main-actor isolated (the project default), because
  `CLLocationManager` and MapKit both expect a single UI-bound home. `Place`, `PlaceSuggestion`,
  `LocationAuthState` and the MapKit→`Place` mapping stay `nonisolated`, so results cross back into
  the domain layer — and into `MoonService` — without a hop. Note that a `nonisolated` type's
  *extensions* don't inherit that: `Place+MapKit.swift` needs its own `nonisolated`.

### 2026-09-23 · Validate illumination against USNO at local noon, not at the displayed moment
- **Decision:** `AstronomyEngineMoonService` gains an internal `illumination(at:)`. Tests compare
  USNO's `fracillum` against that helper **at local noon**, and assert the displayed
  tonight's-midnight value (94%) separately as an engine-derived regression guard.
- **Why:** USNO samples `fracillum` at local noon. Comparing it to our displayed value would fail by
  ~3 points for a reason that has nothing to do with correctness, and the tempting "fix" — widening
  the tolerance to 5% — would destroy the test's power. Sampling the same moment USNO does isolates
  the maths from the display convention, so each assertion tests one thing.
- **Result:** USNO confirms rise 17:19 and set 03:37 (engine: 17:18:30, 03:37:09, both within
  ±2 min), 91% at local noon (engine 90.9%), and Waxing Gibbous. §5 is no longer TBD.
- **Kept internal, not private:** the helper is `internal` so tests can reach it via
  `@testable import` while the C API stays confined to this one type, per the architecture rule.
- **Not covered by USNO:** rise/set azimuth. USNO doesn't publish it — the reason we calculate on
  device at all (§1) — so azimuth assertions remain engine-derived and are labelled that way.

### 2026-09-23 · The whole domain layer is `nonisolated`, not just the service
- **Decision:** `nonisolated` on `Place`, `MoonEvent`, `MoonDay`, `MoonPhase`, the `MoonService`
  protocol, `AstronomyEngineMoonService` and `CompassFormatter`.
- **Why:** `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` isolates everything unannotated, which makes
  pure value types and pure functions main-actor state. Marking only the service wasn't enough:
  tests still failed to compile because `MoonDay.rise`, `MoonEvent.azimuth` and the `MoonService`
  requirement were all main-actor isolated, so reading a result off the main actor was illegal.
  These types have no mutable or shared state, so isolation buys nothing and costs a hop.
- **Consequence:** Test suites are marked `nonisolated` too, so they genuinely exercise the code off
  the main actor. Views and view models stay main-actor isolated by default, which is what we want.

### 2026-09-23 · Unit tests live in an app-hosted target, driven by a shared scheme
- **Decision:** `moonbeam-appTests` is a Swift Testing bundle **hosted in the app** (`TEST_HOST` +
  `BUNDLE_LOADER` + a target dependency), and the `moonbeam-app` scheme is **shared** in
  `xcshareddata/xcschemes/`.
- **Why hosted:** `@testable import moonbeam_app` needs the app's Swift module. An unhosted bundle
  with no dependency on the app fails with "Unable to resolve module dependency: 'moonbeam_app'".
  Creating the target with the host app attached wires `TEST_HOST` and the dependency correctly;
  creating it standalone does not, and the dependency can't be added without editing
  `project.pbxproj`, which the Xcode tooling forbids.
- **Why shared:** Xcode's autocreated schemes carry no test action, so `xcodebuild test` fails with
  "Scheme moonbeam-app is not currently configured for the test action". Sharing the scheme puts the
  test action in version control. Committing it is deliberate — don't let Xcode replace it.
- **Also:** The test target inherits none of the app's language settings, so Swift 6, complete strict
  concurrency, iOS 26.0 and iOS-only platforms had to be set on it explicitly. The template defaults
  were Swift 5.0, iOS 27.0 and a multiplatform `SDKROOT = auto`.

### 2026-09-23 · Swift 6 language mode with complete strict concurrency
- **Decision:** `SWIFT_VERSION = 6.0` and `SWIFT_STRICT_CONCURRENCY = complete`, matching what
  CLAUDE.md already required. The Xcode template had shipped 5.0.
- **Outcome:** Builds clean with no errors and no concurrency warnings, so no source changes and no
  suppressions were needed. The existing code was already compatible: the models are value types of
  Sendable members, so they pick up implicit `Sendable`; the service is a stateless `struct` whose
  C calls are all local; and the spike's statics are immutable.
- **Note:** The template also sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and
  `SWIFT_APPROACHABLE_CONCURRENCY = YES`, both left as-is. Those make unannotated code MainActor
  isolated, which is why calling the spike from `App.init` is fine. When the test target lands,
  expect to mark the astronomy helpers `nonisolated` so tests can call them off the main actor.

### 2026-09-23 · Minimum iOS 26.0
- **Decision:** `IPHONEOS_DEPLOYMENT_TARGET = 26.0`, the value PRODUCT.md §8 recommended. The
  template had 27.0.
- **Why:** 26 is a wide enough net for a new app while still avoiding legacy baggage; nothing in the
  codebase needs a 27-only API. Verified by building and running at 26.0 — the moon table still
  prints identical values, including 94% illumination.
- **Where it's set:** Both the project and the target read **26.0**, in Debug and Release, so new
  targets inherit the right floor. Getting there took two passes: the target was set first, then the
  project level went 27.0 → 26.6 → 26.0 in Xcode. Claude can only set the *target* level — the
  Xcode tooling exposes no project-level build setting and forbids hand-editing `project.pbxproj`,
  so project-wide changes have to be made in the UI.

### 2026-09-23 · Pin Astronomy Engine v2.1.19; call `Astronomy_SearchRiseSetEx`, not the macro
- **Why:** `Astronomy_SearchRiseSet` is a C *macro* in v2.1.19, so Swift can't see it. The
  underlying function `Astronomy_SearchRiseSetEx` takes an extra `metersAboveGround`, which we
  pass as 0.0 to match the 0 m observer height. ASTRONOMY.md §2 lists the macro name; treat that
  table as naming the capability, not the exact symbol.
- **Considered:** A static-inline shim in the bridging header (more moving parts for no gain).

### 2026-09-23 · Illumination and phase are sampled at tonight's local midnight
- **Decision:** Sample at the **end** of the selected day in the place's time zone, computed with
  `calendar.date(byAdding: .day, value: 1, to: localMidnight)` — not by adding 24 hours, which is
  wrong on the 23- and 25-hour days around a DST transition. The rise/set search window is
  unchanged: it still starts at the *start* of the local day and runs one day.
- **Why:** The app answers "how bright is the moon tonight?", so a fixed nightly anchor is right.
  Sampling the current time would make the number drift during the day and make the value
  irreproducible in tests; the start of the day is stale by evening, which is when people look.
- **Why it matters:** Illumination moves ~6 points across one day (Mar Vista, 2026-09-23: 87.8% at
  the start, 90.9% at noon, 93.6% at the end), far beyond the ±1% tolerance. Rise/set times and
  azimuths are unaffected. The §5 reference illumination is now **94%**, and this unblocks task #3.
- **Considered:** Local current time (drifts, untestable), local noon (matched the old 91% reference
  but has no product meaning), start of the selected day (stale by evening).

### 2026-09-23 · Astronomy Engine on the device; USNO for tests only
- **Why:** USNO has no rise/set azimuth, needs a network connection, and has had outages. Astronomy Engine is MIT-licensed, works offline, and covers every V1 field.
- **Considered:** USNO as the live API, SwiftAA, a hand-rolled Meeus algorithm.

### 2026-09-23 · Docs live in the repo under `docs/`, with CLAUDE.md at the root
- **Why:** Versioned with the code, and Claude Code picks up `CLAUDE.md` automatically.
- **Considered:** Keeping docs only in Obsidian or Notion (they'd drift from the code).

### 2026-09-23 · No separate API.md
- **Why:** There's no runtime API. Data-source research lives in `ASTRONOMY.md`.

### 2026-09-23 · SwiftUI + MVVM-lite + protocol services
- **Why:** Simple, testable, and easy for Claude to follow consistently.
