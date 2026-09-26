# Step 2 Spec: Location (Detect + Search)

**Status:** Ready for the Xcode agent · **Decided:** 2026-09-25 · **Owner:** Tessa
**Depends on:** Astronomy Engine spike (`MoonService`, `AstronomyEngineMoonService`), which is done
**Feeds:** Task #4, the SwiftUI moon table (design-led)

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
- Recently searched cities list (V1 stores only one last-viewed place, but the storage should be shaped so it can become a list)
- Visual design and polish, animation
- Background or continuous location updates

## 3. UX behavior

### Copy
| Element | Text |
|---|---|
| Screen prompt | **Where are you watching the moon tonight?** |
| Search placeholder | Search for a city |
| Location button | Use my location |
| Last-viewed chip | Back to {City} |
| Time zone label (when place ≠ device time zone) | {City} · {TZ abbreviation}, e.g. "Sydney · AEST" |

### Search field
- Type-ahead suggestions for city, state/region, country (`MKLocalSearchCompleter`, filtered to addresses/cities).
- Picking a suggestion resolves it to a `Place` and loads the moon data.
- When the field holds a city (detected or chosen):
  - **Tapping into the field selects all of its text**, so typing replaces it immediately.
  - **A clear (x) button** is always visible in the field while it holds text.
- Suggestions list states: typing (results), no results ("No matching cities"), network error ("Can't search right now. Check your connection.").

### "Use my location" button
- Shown **below the search field** whenever the current place is *not* the detected current location.
- Tap behavior depends on permission state (see §4).

### Launch logic

**First launch (no saved place, permission not yet asked)**
1. Empty search field + prompt.
2. "Use my location" below the field.
3. No permission prompt at launch. It only appears when the user taps "Use my location".

**Subsequent launches: current location wins, with last-viewed one tap away**
| Permission | Behavior |
|---|---|
| Authorized | Fetch current location → field shows current city → moon data loads. If the last-viewed place differs from the current city, show a **"Back to {City}"** chip. |
| Authorized, fetch fails or times out (10 s) | Fall back to last-viewed place (if any). Show "Use my location" so they can retry. |
| Not determined / denied / restricted / services off | Show last-viewed place if one exists, otherwise the empty first-launch state. "Use my location" is visible. |

While the fetch is in progress, show the last-viewed place's name as a placeholder, or a small loading state if there's no saved place. Don't show a blank screen.

Picking any place (search, detect, or chip) makes it the new **last-viewed place**.

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
- Secondary: **Search instead** (dismisses the dialog and focuses the search field)

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
Services/
  LocationService.swift         // protocol + CoreLocationService
  PlaceSearchService.swift      // protocol + MapKitPlaceSearchService
  PlaceStore.swift              // protocol + UserDefaultsPlaceStore
Features/Location/
  LocationViewModel.swift       // @Observable, @MainActor; owns launch logic + permission state
  LocationScreen.swift          // functional SwiftUI screen (visuals come later)
  LocationOffDialog.swift       // custom dialog, 3 variants
```

### `Place`
- `displayName` → "Sydney, NSW, Australia" (omit missing parts)
- `shortName` → "Sydney"
- `isCurrentLocation: Bool` (not persisted as truth; used for UI)

### `LocationService`
- `var authorizationState: LocationAuthState { get }` (enum: notDetermined, authorized, denied, restricted, servicesOff)
- `func requestAuthorization() async -> LocationAuthState`
- `func currentPlace() async throws -> Place` (one-shot fix → reverse geocode → `Place`)
- Implementation notes:
  - Info.plist: `NSLocationWhenInUseUsageDescription` = "Moonbeam uses your location to show when and where the moon rises and sets near you."
  - Info.plist: `NSLocationDefaultAccuracyReduced` = `YES` (defaults the Precise toggle off; city-level is enough)
  - One-shot request; no continuous updates, no background mode
  - Reverse geocoding: on iOS 26 use **MapKit's geocoding requests** (`MKReverseGeocodingRequest`) rather than the deprecated `CLGeocoder`. Check the exact API against the current SDK.
  - Time zone comes from the resulting map item or placemark

### `PlaceSearchService`
- Wraps `MKLocalSearchCompleter` (result types limited to addresses/cities)
- `func suggestions(for query: String) -> AsyncStream<[PlaceSuggestion]>` (debounce ~250 ms)
- `func resolve(_ suggestion: PlaceSuggestion) async throws -> Place` (via `MKLocalSearch`)

### `PlaceStore`
- `var lastViewed: Place? { get set }`
- Store as a Codable array under the hood (max 1 for V1) so recents is a small change later

## 7. Tests (Swift Testing)

Use fakes for `LocationService`, `PlaceSearchService`, `PlaceStore`.

**LocationViewModel launch logic**
- First launch, no saved place → empty state, "Use my location" visible, no permission request made
- Authorized + fetch succeeds → current place shown; last-viewed chip shown only when it differs
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
- [ ] With location on, relaunch shows current city; a different last-viewed city is one tap away
- [ ] Tapping into a filled search field selects its text; (x) clears it
- [ ] Denied, services-off, and restricted each show the right custom dialog; "Open Settings" lands on the app's settings page
- [ ] Returning from Settings with permission granted fetches automatically
- [ ] Times show in the place's time zone, labeled when different from the device
- [ ] All tests pass under Swift 6 strict concurrency

## 9. Open items
- Display name "Moonbeam" (kept in one constant)
- Visual design of this screen and the dialog (design-led, after this step)
