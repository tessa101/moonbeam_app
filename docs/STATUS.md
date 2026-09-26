# Status & Handoff

> A living note on where things stand. Update it at the end of each work session
> so the next session (you, or Claude) can pick up cold.

_Last updated: 2026-09-25 (location service layer)_

## Where things live
- **Local repo:** `~/app-ideas/moonbeam` (the one true folder)
- **GitHub:** https://github.com/tessa101/moonbeam_app (`main`)
- **Xcode project:** `moonbeam-app/moonbeam-app.xcodeproj` (app target + `moonbeam-appTests`)
- The `moonbeam-app` scheme is shared and version-controlled; `xcodebuild test` depends on it
- Don't tick "Create Git repository" in Xcode. This folder already has one.

## Done
- Planning docs: PRODUCT, ARCHITECTURE, ASTRONOMY, DECISIONS, CLAUDE.md
- Xcode project created inside the repo, plus a `.gitignore`
- Astronomy Engine sanity check (JS, Mar Vista, 2026-09-23): rise 5:18 PM 105° ESE · set 3:37 AM 252° WSW · 91% illuminated
  (that 91% was sampled at local noon; the agreed convention now puts the reference at 94% — see §5)
- Astronomy Engine spike: vendored v2.1.19 + bridging header, app builds and prints the moon table.
  Rise/set **reproduce the JS values exactly** (5:18 PM 105° ESE · 3:37 AM 252° WSW).
- Toolchain settled: Swift 6 language mode, complete strict concurrency, iOS 26.0 minimum. No source
  changes were needed to satisfy strict concurrency.
- **Location, step 2 — service layer (2026-09-25).** LOCATION.md §6 built and §7's service tests
  written: `Place` (now Codable/Hashable with displayName/shortName/time-zone predicate),
  `PlaceSuggestion`, `LocationAuthState`, `LocationService` + `CoreLocationService` + fake,
  `PlaceSearchService` + `MapKitPlaceSearchService` + fake, `PlaceStore` +
  `UserDefaultsPlaceStore` + in-memory fake, and the shared `MKMapItem` → `Place` mapping. Uses the
  iOS 26 APIs: `MKReverseGeocodingRequest` and `CLLocationUpdate.liveUpdates()`, not `CLGeocoder`.
  Info.plist carries `NSLocationWhenInUseUsageDescription` and
  `NSLocationDefaultAccuracyReduced` (both verified in the built app). Builds clean, no warnings.
  Six API/spec deviations are logged in DECISIONS.md 2026-09-25 and folded back into LOCATION.md.
  **No UI yet** — the view model, screen and dialog are the next slice.

## Next
1. [x] Push to GitHub (docs + Xcode project are on `main`)
2. [x] Astronomy Engine spike: vendor `astronomy.c/.h`, bridging header, print the moon table for a hardcoded city
3. [x] Add a test target and pull USNO reference values
   - `moonbeam-appTests` (Swift Testing, app-hosted, shared scheme): **22 tests / 91 cases, all
     passing.** MoonPhase angle→name incl. wraparound, CompassFormatter sector edges, and
     AstronomyEngineMoonService against the §5 Mar Vista row.
   - Since the location work (2026-09-25) the target holds **62 tests / 139 cases across 7 suites**.
     The 40 new ones have **not been run yet** — Tessa is running them.
   - **Validated against USNO:** rise and set times within ±2 min (engine 17:18:30 / 03:37:09 vs
     USNO 17:19 / 03:37), illumination at local noon within ±1% (90.9% vs USNO's 91%), and phase
     name. Azimuths have no USNO equivalent — USNO publishes none, which is why we calculate on
     device — so those stay engine-derived regression guards, labelled as such in the tests.
   - Note the moment mismatch in §3: USNO samples `fracillum` at local noon, the app displays
     tonight's local midnight (94%). Both are asserted, separately and for different reasons.
   - [ ] **Confirm `xcodebuild test` on the Mac.** The 91 passing cases ran in Xcode's own runner; the
     agent's sandbox couldn't launch the simulator from the command line. Run the command in CLAUDE.md
     from Terminal and expect `** TEST SUCCEEDED **`.
   - [ ] **Fill the remaining ASTRONOMY.md §5 rows from USNO** (engine predictions shown, ±2 min expected):
     | Row | Date | Coords, tz | Engine predicts | USNO query |
     |---|---|---|---|---|
     | Reykjavík (high latitude) | 2026-09-23 | 64.15, -21.94 · UTC, no DST | rise 19:07 · set 02:01 | `oneday?date=2026-09-23&coords=64.15,-21.94&tz=0&dst=false` |
     | Sydney (southern hemisphere) | 2026-09-23 | -33.87, 151.21 · AEST, no DST yet | rise 14:24 · set 03:41 | `oneday?date=2026-09-23&coords=-33.87,151.21&tz=10&dst=false` |
     | Mar Vista (no moonrise) | 2026-10-03 | 34.00, -118.43 · PDT | **no rise** · set 14:27 (rise 23:12 on 10/2, 00:21 on 10/4) | `oneday?date=2026-10-03&coords=34.00,-118.43&tz=-8&dst=true` |

     Base URL: `https://aa.usno.navy.mil/api/rstt/`. Open from the Mac (the cloud sandbox is blocked).
4. [ ] Build the SwiftUI table
   - Design first (Tessa): table layout, and the **"no moonrise / no moonset today"** state, which the
     Oct 3 row above will exercise. Bring a sketch or Figma link, then spec it for the agent.

5. [ ] Location: detect + search (Step 2)
   - Spec: **[LOCATION.md](LOCATION.md)** (decided 2026-09-25). Place model, CoreLocation one-shot fix,
     MapKit city search, last-viewed persistence, custom "location off" dialog, place time zones.
   - Plain functional screen for now; visual design comes later (design-led).
   - [x] §6 service layer + §7 service tests + Info.plist keys (see Done, above)
   - [ ] `LocationViewModel`: the §3 launch logic and §4 permission branches, plus the 10-second
     fetch timeout, which the service deliberately leaves to the caller. `FakeLocationService.fixDelay`
     exists to exercise it.
   - [ ] `LocationScreen` + `LocationOffDialog` (3 variants), and the app-name constant from §9
   - [ ] Wire the screen to the moon table, replacing `SpikeMoonTableViewModel`'s hardcoded
     Mar Vista fixture

## Open questions
- ~~Minimum iOS version (suggested 26+)~~ **Settled 2026-09-23:** deployment target is 26.0, and
  Swift 6 with complete strict concurrency is on. Both built and ran clean. Project *and* target
  deployment targets are both 26.0, so new targets inherit the right floor
- ~~Show illumination for the current time or for local midnight?~~ **Settled 2026-09-23:** tonight's
  local midnight, i.e. the end of the selected day. See DECISIONS.md and PRODUCT FR5
- Primary persona (confirm with design partner)
- Display name "Moonbeam" (project name is `moonbeam-app`)
