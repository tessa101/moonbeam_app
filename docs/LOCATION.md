# Step 2 Spec: Location (Detect + Search)

**Status:** Ready for the Xcode agent · **Decided:** 2026-09-25 · **Owner:** Tessa
**Depends on:** Astronomy Engine spike (`MoonService`, `AstronomyEngineMoonService`), which is done
**Feeds:** Task #4, the SwiftUI moon table (design-led)
**Amended by:** [SEARCH-RECENTS.md](SEARCH-RECENTS.md) (Step 2.1, 2026-09-26): search moves into a bottom sheet with recent cities, and the "Back to {City}" chip is removed. Where the two disagree, SEARCH-RECENTS.md wins; superseded text below is struck through.

---

## 1. Goal

Get the user to a **place** (name + coordinates + time zone) as fast as possible, either by detecting where they are or by letting them search for any city. The place drives the moon table.

Principle: **never force current location.** Looking up a city you're not in is a first-class use case, not a fallback.

## 2. Scope

**In scope**
- `Place` model, location services, city search, persistence of last-viewed place
- A functional location screen, wired end to end. Keep the visuals plain; the visual design pass comes later.
- Custom "location is off" dialog
- Tests for all services and permission states

**Out of scope (later)**
- ~~Recently searched cities list~~ No longer out of scope: built in Step 2.1 (SEARCH-RECENTS.md §3)
- Visual design and polish, animation
- Background or continuous location updates

## 3. UX behavior

### Copy
| Element | Text |
|---|---|
| Screen prompt | **Where are you watching the moon tonight?** |
| Search placeholder | Search for a city |
| Location button | Use my location |
| ~~Last-viewed chip~~ | ~~Back to {City}~~ Removed (SEARCH-RECENTS.md §1, Decision C) |
| Time zone label (when place ≠ device time zone) | {City} · {TZ abbreviation}, e.g. "Sydney · AEST" |

### Search field
> The main-screen field is now a button that opens the search sheet (SEARCH-RECENTS.md §1–2).
> Suggestions, resolving and the list states below still apply, inside the sheet.

- Type-ahead suggestions for city, state/region, country (`MKLocalSearchCompleter`, filtered to addresses/cities).
- Picking a suggestion resolves it to a `Place` and loads the moon data.
- ~~When the field holds a city (detected or chosen):~~
  - ~~**Tapping into the field selects all of its text**, so typing replaces it immediately.~~
  - ~~**A clear (x) button** is always visible in the field while it holds text.~~
  - Superseded by SEARCH-RECENTS.md §1: the sheet always opens with an empty field, which has its own clear (x).
- Suggestions list states: typing (results), no results ("No matching cities"), network error ("Can't search right now. Check your connection.").

### "Use my location" button
- Shown **below the search field** whenever the current place is *not* the detected current location.
- Tap behavior depends on permission state (see §4).

### Launch logic

**First launch (no saved place, permission not yet asked)**
1. Empty search field + prompt.
2. "Use my location" below the field.
3. No permission prompt at launch. It only appears when the user taps "Use my location".

**Subsequent launches: current location wins** ~~, with last-viewed one tap away~~ (recents in the search sheet now cover returning to a saved city)
| Permission | Behavior |
|---|---|
| Authorized | Fetch current location → field shows current city → moon data loads. ~~If the last-viewed place differs from the current city, show a **"Back to {City}"** chip.~~ (Chip removed: SEARCH-RECENTS.md §1, Decision C.) |
| Authorized, fetch fails or times out (10 s) | Fall back to last-viewed place (if any). Show "Use my location" so they can retry. |
| Not determined / denied / restricted / services off | Show last-viewed place if one exists, otherwise the empty first-launch state. "Use my location" is visible. |

While the fetch is in progress, show the last-viewed place's name as a placeholder, or a small loading state if there's no saved place. Don't show a blank screen.

Picking any place (search or detect ~~, or chip~~) makes it the new **last-viewed place**. A launch fix doesn't: the saved place stays the fallback for a later launch where location is off or fails. Picks from search also become **recents** (SEARCH-RECENTS.md §3).

## 4. Permission states

| State | "Use my location" tap does |
|---|---|
| `notDetermined` | Triggers the system permission prompt, then fetches if granted |
| `authorizedWhenInUse` | Fetches location (one-shot) |
| `denied` | Shows the **custom Location Off dialog** (below) |
| `restricted` | Shows the custom dialog in its restricted variant (no Settings button) |
| Location Services off system-wide | Shows the custom dialog in its services-off variant |
| Approximate location only | Treated as authorized. Approximate is enough for moon times. |

### Custom "Location Off" dialog
A custom in-app sheet or dialog, **not** a system alert.

**Denied variant**
- Title: Location is off for Moonbeam
- Body: To find the moon where you are, turn on location in **Settings › Moonbeam › Location** and choose **While Using the App**. You can also just search for a city.
- Primary: **Open Settings** (deep-links to the app's settings page via `UIApplication.openSettingsURLString`)
- Secondary: **Search instead** (dismisses the dialog ~~and focuses the search field~~, then opens the search sheet once the dialog has gone: SEARCH-RECENTS.md §2, Decision A)

**Services-off variant** (Location Services disabled for the whole device)
- Body: Location Services are off on this device. Turn them on in **Settings › Privacy & Security › Location Services**, or search for a city.
- Same buttons. Note: Open Settings can only reach the app's page, so the copy carries the path.

**Restricted variant** (parental controls or device management)
- Body: Location access is restricted on this device. Search for a city instead.
- Single button: **Search for a city**

When the app returns to the foreground after Settings, re-check permission. If it's now authorized, fetch automatically.

*"Moonbeam" is still a working name. Keep the app name in one string constant so it's easy to swap.*

## 5. Time zones

- Every `Place` carries **its own `TimeZone`**. All moon times show in the place's time zone, not the device's.
- Show the time zone label (§3) whenever `place.timeZone` ≠ `TimeZone.current`.
- Pass `place.timeZone` into `MoonService`. The existing API already takes a time zone.

## 6. Architecture

Follow the existing pattern: protocol + concrete implementation + fake for tests. Swift 6 strict concurrency, iOS 26 minimum.

```
Models/
  Place.swift                   // name, locality, region, country, coordinate, timeZone; Codable, Sendable, Hashable
  PlaceSuggestion.swift         // one type-ahead row: title + subtitle, no coordinates yet
Services/Location/              // grouped like the existing Services/Moon/
  LocationAuthState.swift       // the five states in §4, mapped from CLAuthorizationStatus
  LocationService.swift         // protocol (+ LocationError)
  CoreLocationService.swift
  FakeLocationService.swift
  PlaceSearchService.swift      // protocol (+ PlaceSearchError)
  MapKitPlaceSearchService.swift
  FakePlaceSearchService.swift
  PlaceStore.swift              // protocol
  UserDefaultsPlaceStore.swift
  InMemoryPlaceStore.swift
  Place+MapKit.swift            // MKMapItem → Place; shared by the two MapKit services
Features/Location/
  LocationViewModel.swift       // @Observable, @MainActor; owns launch logic, permission state + the 10 s timeout
  LocationScreen.swift          // functional SwiftUI screen (visuals come later)
  LocationOffDialog.swift       // custom dialog, 3 variants
```

The three services are **main-actor isolated** (the project default): they drive
`CLLocationManager` and MapKit. The models and the MapKit mapping are `nonisolated`, so a resolved
`Place` reaches `MoonService` without a hop.

### `Place`
- `displayName` → "Sydney, NSW, Australia" (omit missing parts, and skip `locality` when it just
  repeats `name`, which is the usual case for a city search)
- `shortName` → "Sydney"
- `isCurrentLocation: Bool` (not persisted as truth; used for UI). Excluded from `Codable` *and*
  from `==`/`hash`, so a saved place and the same place freshly detected compare equal.
  ~~The "Back to {City}" chip in §3 depends on that comparison.~~ The chip is gone
  (SEARCH-RECENTS.md, Decision C). `==` stays exact on everything else because
  `PlaceStore.removeRecent` uses it to delete only the swiped row; recents dedupe uses the looser
  `isSameCity(as:)`
- `coordinate` is stored as `latitude`/`longitude` (so `Codable` needs no custom coding) and exposed
  as a computed `CLLocationCoordinate2D` in `Place+MapKit.swift`, which keeps the model
  Foundation-only
- `isInDifferentTimeZone(from:on:)` is the §5 label decision, comparing **offsets** rather than
  identifiers, with the device zone passed in — see DECISIONS.md 2026-09-25

### `LocationService`
- `var authorizationState: LocationAuthState { get }` (enum: notDetermined, authorized, denied, restricted, servicesOff)
- `func requestAuthorization() async -> LocationAuthState`
- `func currentPlace() async throws -> Place` (one-shot fix → reverse geocode → `Place`)
- Implementation notes:
  - Info.plist: `NSLocationWhenInUseUsageDescription` = "Moonbeam uses your location to show when and where the moon rises and sets near you."
  - Info.plist: `NSLocationDefaultAccuracyReduced` = `YES` (defaults the Precise toggle off; city-level is enough)
  - One-shot request; no continuous updates, no background mode
  - Reverse geocoding: `MKReverseGeocodingRequest(location:)` → `await request.mapItems`. Confirmed
    against the iOS 26 SDK, where `MKMapItem.placemark` and `CLGeocoder` are both deprecated
  - The fix itself comes from `CLLocationUpdate.liveUpdates()`, stopped after the first location
  - Time zone comes from `MKMapItem.timeZone`, and a map item **without** one fails the mapping
    rather than falling back to the device's — a silent fallback would show the wrong times
  - The name is `cityName`, else the first component of `cityWithContext`, else the mapping fails
    (`couldNotIdentifyPlace`). **Never** `mapItem.name`, which for a reverse geocode is a street
    address. Search results may fall back to `mapItem.name`. See `Place.placeName(...)`
  - No timeout here: the 10-second fallback in §3 is a launch policy, so it belongs to the view model

### `PlaceSearchService`
- Wraps `MKLocalSearchCompleter`, with `resultTypes = .address` and
  `MKAddressFilter(including: [.locality, .subLocality])` — cities and neighbourhoods, no cafés, no
  street numbers, no whole states
- `func suggestions(for query: String) -> AsyncThrowingStream<[PlaceSuggestion], any Error>`
  (debounce ~250 ms). **Throwing**, not a plain `AsyncStream`: §3's "Can't search right now" state
  needs a failure channel, which a non-throwing stream doesn't have. An empty query yields one
  empty batch and finishes, so clearing the field clears the list
- `func resolve(_ suggestion: PlaceSuggestion) async throws -> Place` — an `MKLocalSearch` over the
  suggestion's two lines rejoined as a `naturalLanguageQuery`, rather than replaying the
  `MKLocalSearchCompletion` (which isn't `Sendable`). See DECISIONS.md 2026-09-25

### `PlaceStore`
- `var lastViewed: Place? { get set }`
- ~~Store as a Codable array under the hood (max 1 for V1) so recents is a small change later~~
  Recents turned out to need their own list, since `lastViewed` can be a detected place and recents
  can't. See SEARCH-RECENTS.md §8 for `recents`, `addRecent`/`removeRecent` and the migration

## 7. Tests (Swift Testing)

Use fakes for `LocationService`, `PlaceSearchService`, `PlaceStore`.

> **Done so far (2026-09-25):** the service and model tests — `PlaceTests`, `PlaceTimeZoneTests`,
> `PlaceStoreTests`, `PlaceSearchServiceTests`, `LocationServiceTests`. The view model tests below
> are in `LocationViewModelTests`, plus the suggestion-list states and a check that the timeout
> cancels the fix.
>
> `CoreLocationService` itself is not directly tested: it needs a device fix and a live geocoder.
> What *is* tested is the decision inside it — `LocationAuthState(status:servicesEnabled:)`, which
> is where the §4 table actually lives.

**LocationViewModel launch logic**
- First launch, no saved place → empty state, "Use my location" visible, no permission request made
- Authorized + fetch succeeds → current place shown ~~; last-viewed chip shown only when it differs~~ (chip removed; the test now checks a launch fix doesn't replace the saved place)
- Authorized + fetch fails or times out → falls back to last-viewed
- Denied with saved place → saved place shown, button visible
- Each permission state → correct button behavior / dialog variant (§4)
- Choosing a place updates `lastViewed`
- Foreground after Settings with newly authorized → auto-fetch

**Time zone**
- Sydney place, device set to America/Los_Angeles → moon times formatted in AEST; TZ label shown
- Mar Vista place, device in LA → no TZ label
- Reuse the ASTRONOMY.md §5 validation values (Sydney 2026-09-23: rise 14:24, set 03:41 AEST)

**PlaceStore**
- Round-trips a `Place` including its time zone
- Survives a relaunch (new store instance)

**Search**
- Empty query → no suggestions
- Resolve maps coordinates + time zone correctly (fake completer results)

## 8. Acceptance criteria

- [ ] Fresh install: no permission prompt until "Use my location" is tapped
- [ ] Can search and pick any city without ever granting location
- [ ] With location on, relaunch shows current city ~~; a different last-viewed city is one tap away~~ (superseded: recents, SEARCH-RECENTS.md §6)
- [ ] ~~Tapping into a filled search field selects its text; (x) clears it~~ Superseded by SEARCH-RECENTS.md §1
- [ ] Denied, services-off, and restricted each show the right custom dialog; "Open Settings" lands on the app's settings page
- [ ] Returning from Settings with permission granted fetches automatically
- [ ] Times show in the place's time zone, labeled when different from the device
- [ ] All tests pass under Swift 6 strict concurrency

## 9. Open items
- Display name "Moonbeam" (kept in one constant)
- Visual design of this screen and the dialog (design-led, after this step)
