# Status & Handoff

> A living note on where things stand. Update it at the end of each work session
> so the next session (you, or Claude) can pick up cold.

_Last updated: 2026-10-01 (Step 5.3 madlib sentence built, with §3.1a; 5.2 follow-ups; Step 5.2 moon card built; 5.1 theme; Design 1.1 settled: DESIGN-1.1.md, Step 5; 4.14, Step 2.2 and 4.15 built; device checks pending)_

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
- **Location, step 2 — view model + screen (2026-09-25).** `LocationViewModel` (§3 launch logic,
  §4 permission branches, and the 10 s timeout, which *cancels* the fix when it fires),
  `LocationScreen` (plain, unstyled) and `LocationOffDialog` (denied / services-off / restricted),
  plus `AppInfo.name` as the single app-name constant. The app now opens on the location screen,
  and picking a place loads the existing spike moon table (`ContentView`) for it. Review fixes from
  the service-layer commit: a current location is never named after `mapItem.name` (a street
  address). The mapping uses `cityName`, then `cityWithContext`'s first component, then fails. The
  unreachable "Mar Vista, Los Angeles" display-name test was dropped. **87 tests / 171 cases,
  8 suites, all passing** in Xcode's runner. Builds with no warnings. Decisions are in
  DECISIONS.md 2026-09-25 ("Location view model, screen and dialog").
- **Location, Step 2.1 — search sheet with recent cities (2026-09-26).** Spec:
  [SEARCH-RECENTS.md](SEARCH-RECENTS.md), which amends LOCATION.md. Built in the §8 build order:
  - `PlaceStore` recents (cap 8, dedupe via `Place.isSameCity(as:)`, move to front, remove), with a
    new `recentPlaces` key seeded once from `lastViewed`
  - `SearchSheetViewModel`: recents at 0 characters, filtered recents at 1, type-ahead from 2
  - `SearchSheet`, and the main-screen field turned into a button that opens it
  - Decisions A–C: the location row closes the sheet first; the row is hidden when viewing the
    detected location; the "Back to {City}" chip is removed
  - **129 tests / 217 cases across 10 suites, all passing** in Xcode's runner, with no build
    warnings. Sheet auto-focus was checked in the iPhone 17 simulator (keyboard comes up on open)
    and on device by Tessa (field focused on open). Decisions are in DECISIONS.md 2026-09-26.
  - **Device QA pending** (see Next, item 5).
- **Step 3 — date selection (2026-09-26).** Spec: [DATE.md](DATE.md), plan and as-built notes in §10.
  Commits 2e64a8d → 52e3281, plus the docs.
  - `DaySelection` (`.today` / picked day, calendar-day math in the place's zone, noon anchor, ±366)
  - `DayLabelFormatter` ("Today · Sat, Sep 26, 2026" and the spoken form)
  - `FakeMoonService`
  - Day selection in `LocationViewModel`, rolling over on foreground only
  - The time zone label sampled at local noon on the selected day
  - `DateControl` and `CalendarSheet`
  - The spike table is built for the selected day (`today:` → `day:`). After the review it no longer
    repeats the city or date, which the search field and date control already show
  - Decisions 1–4 are in DECISIONS.md 2026-09-26, including the calendar wheel draft and Done
  - Review follow-ups (07478c7 → b4e5b8e, plus the docs):
    - shorter date label ("Sun, Sep 27"; year only in another year)
    - 44 pt tap target for the Today chip
    - date field fills the row; location button above the date control
    - Today chip removed from the date row; back to today is the calendar sheet's Today button,
      disabled on today
    - no duplicate city/date in the table
  - **179 tests / 273 cases across 14 suites, all passing** in Xcode's runner on the iPhone 17
    simulator. No build warnings.
  - Checked in the iPhone 17 simulator:
    - ‹ / › update the label and table
    - the sheet fits at medium for a five-row month
    - the wheel keeps the sheet open, and Done appears
    - a day tap picks the day and closes the sheet
    - Oct 3 in Westminster shows "No moonrise today"
  - **Device QA pending** (see Next, item 6).
- **Step 4 — compass, in progress (2026-09-28).** Spec: [COMPASS.md](COMPASS.md).
  - 4.1 `MoonPosition` + `MoonService.moonPosition(for:at:)` (moon-up = latest rise after latest set)
  - Display name and `AppInfo.name` → "Moon Signal"
  - 4.2 `HeadingService` + `CoreLocationHeadingService` + fake; `HeadingReading` (low accuracy > 15°)
  - Portrait lock and iPhone-only
  - 4.3a `CompassViewModel`: §2 visibility, targets, lock/hold/release, 30 s Moon refresh, sensor lifecycle
  - 4.3b `LocationViewModel` owns and feeds the compass (detected place, permission, selected day's `MoonDay`)
  - Moon table uses the shared bearing formatter (359.6° reads "0° N" in both)
  - 4.4 `CompassView` + `CompassDial` (plain) under the moon table; placeholder hint and low-accuracy
    text; VoiceOver labels from the view model. `LocationScreen` reports on-screen via
    `onScrollVisibilityChange`/`onDisappear` and forwards `.background`.
  - Checked in previews (locked, low accuracy, no compass, location off; AX 3 in dark mode). The app
    launches in the iPhone 17 simulator with no errors. The live compass needs a device.
  - Follow-ups from the first device test (2026-09-29), one commit each:
    - 4.5 haptic tap on lock acquire
    - 4.6 proximity states (Here / Nearby ≤ 60 mi / Far); Turn On Location from the compass hint
      keeps the searched city, including after Settings
    - 4.7 target rows removed; the dial reads its targets to VoiceOver
  - **322 tests / 462 cases across 21 suites, all passing** in Xcode's runner on the iPhone 17 simulator.
  - **Device QA pending** (see Next, item 7).

## Next
1. [x] Push to GitHub (docs + Xcode project are on `main`)
2. [x] Astronomy Engine spike: vendor `astronomy.c/.h`, bridging header, print the moon table for a hardcoded city
3. [x] Add a test target and pull USNO reference values
   - `moonbeam-appTests` (Swift Testing, app-hosted, shared scheme): **22 tests / 91 cases, all
     passing.** MoonPhase angle→name incl. wraparound, CompassFormatter sector edges, and
     AstronomyEngineMoonService against the §5 Mar Vista row.
   - Since the location work (2026-09-25) the target holds **87 tests / 171 cases across 8 suites**,
     all passing in Xcode's runner.
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
4. [ ] Build the SwiftUI table → **now part of Step 5 (Design 1.1), item 5.2**
   - Design settled 2026-09-30: [DESIGN-1.1.md](DESIGN-1.1.md) §3.2 (moon card, incl. "No moonrise today").
   - **Step 5 build order** (DESIGN-1.1.md §7, one commit each): 5.1 theme · 5.2 moon card · 5.3 madlib
     sentence · 5.4 compass restyle · 5.5 AX reflow · 5.6 pinned compass bar · 5.7 onboarding · then
     device QA at default / AX1 / AX5.
   - [x] **5.1 theme (2026-09-30):** `Theme/Theme.swift` (color tokens, type scale, bundled font names),
     `Theme/ScreenBackground.swift` (`bg` + top amber glow), fonts in `Resources/Fonts` + `UIAppFonts`,
     forced dark (`UIUserInterfaceStyle`), `AccentColor` = `accent`, iOS 26 status bar backing is solid
     `bg`. App root defaults to the body font and `textPrimary`. `ThemeTests`: fonts register, §2
     contrast table holds.
   - [x] **5.2 moon card (2026-09-30):** `Features/MoonTable/` (`MoonCard`, `MoonTableViewModel`,
     `PhaseGlyph` + `PhaseGlyphGeometry`), `Formatting/MoonTableFormatter`. Header "Today · Wed, Sep 30"
     with ‹ › (moved out of `DateControl`, which now only opens the calendar until 5.3), phase glyph
     with a real terminator, rise/set columns with the place's zone beside each time (replaces the
     "Sydney · AEST" line). Spike `ContentView` / `SpikeMoonTableViewModel` deleted. 371 tests / 568
     cases pass. Screenshots: `.agent-reports/design-1.1/`. **Open for Tessa:** the zone wraps under the
     time at default size (DECISIONS.md "5.2 moon card"). **For 5.4:** `tick` → `#807075`
     (DESIGN-1.1.md §2, §7). Next: 5.3 madlib sentence.
   - [x] **5.2 follow-ups (2026-09-30):** rise/set times round to the nearest minute (were truncated: LA
     9:09 / 2:26 → 9:10 / 2:27, matching USNO); rise/set VoiceOver labels end with the degrees
     ("east-northeast, 58 degrees"). Zone wrapping under the time accepted (Tessa).
   - [x] **5.3 madlib sentence (2026-10-01), with §3.1a:** "Where can I find the moon / 📅 tonight in /
     📍 Los Angeles, CA?" on three fixed lines (a long city shrinks to 0.8 before wrapping; the card doesn't
     move). Tokens open the calendar and search sheets; VoiceOver reads the sentence, then "Date, tonight,
     button", "Place, Los Angeles, C A, button". No place: "a city" token + Use my location (secondary
     button). Custom `token.calendar` / `token.pin` symbols from the HTML. `DateControl` and the search-field
     button are gone. `MadlibFormatter`, `MadlibSentence`, `SecondaryButtonStyle`. 388 tests / 594 cases.
     Screenshots: `.agent-reports/design-1.1/5.3-*`. **Time zone check (Tessa's report):** the zone still
     shows beside/under the times for Sydney (GMT+10), London (GMT+1) and Sydney River (ADT) in the
     simulator; places in the phone's own zone show none, by design (§11 Q3). **Found, not fixed:** the
     recent "Sydney, Australia" resolved to Sydney River, Nova Scotia (search resolve, Step 2.2). Next: 5.4
     compass restyle.
   - [x] **5.4 compass restyle (2026-10-01):** heading readout (Young Serif 24 in a 40 pt slot), 220 pt
     dial (gradient face, 15° tick dots, upright N/E/S/W with N amber, ↑/↓ by the rise/set dots, 18 pt
     live Moon dot with no arrow), lock = amber pill + dot ring/glow + dial halo, notes as amber-tint
     pills (`CompassNote`) with Use Precise Location / Turn On Location as secondary buttons. `tick` →
     `#807075`. Behavior unchanged (haptic, sensors, Far hides the dial); Reduce Motion swaps with no
     animation. 398 tests / 604 cases. Screenshots: `.agent-reports/5.4-compass/`. **Check on device:**
     the lock pill + haptic, marks moving smoothly, notes in low accuracy. Next: 5.5 AX reflow (incl. the
     260 pt dial).

5. [ ] Location: detect + search (Step 2)
   - Spec: **[LOCATION.md](LOCATION.md)** (decided 2026-09-25). Place model, CoreLocation one-shot fix,
     MapKit city search, last-viewed persistence, custom "location off" dialog, place time zones.
   - Plain functional screen for now; visual design comes later (design-led).
   - [x] §6 service layer + §7 service tests + Info.plist keys (see Done, above)
   - [x] `LocationViewModel`: §3 launch logic, §4 permission branches, 10 s timeout (cancels the fix)
   - [x] `LocationScreen` + `LocationOffDialog` (3 variants), and `AppInfo.name` from §9
   - [x] Wire the screen to the moon table. The app passes the chosen place into
     `SpikeMoonTableViewModel`. Its Mar Vista fixture is now only a default for previews
   - [ ] **§8 on a device or simulator, by hand.** Not verified by the agent. Tests cover the logic;
     these need a person:
     - fresh install shows no permission prompt until "Use my location" is tapped
     - real MapKit search + pick, without ever granting location
     - relaunch with location on shows the current city (the "Back to {City}" chip is gone, Decision C)
     - each dialog variant appears; "Open Settings" lands on Moonbeam's settings page
     - granting in Settings and returning fetches automatically
     - Dynamic Type at the largest sizes, and VoiceOver on the screen and dialog
   - [x] Step 2.1 search sheet + recents (SEARCH-RECENTS.md), built and unit-tested
   - [ ] **Step 2.1 device QA, by hand** (SEARCH-RECENTS.md §6):
     - [x] tapping the main-screen field opens the sheet with the field focused (confirmed on device 2026-09-26)
     - recents appear with no typing; 1 character filters them; 2+ shows type-ahead; clearing returns to recents
     - picking dismisses the sheet, loads the moon and moves that city to the top of recents
     - max 8, no duplicates, swipe to delete, recents survive a relaunch
     - the detected location never appears in recents
     - the location row closes the sheet and then runs the flow; with permission denied, the dialog
       shows and "Search instead" reopens the sheet
     - the location row is hidden when viewing the detected location
     - VoiceOver and Dynamic Type in the sheet
   - [ ] Time zone label says "GMT+10" for Sydney in `en_US`, not "AEST" (the system abbreviation;
     see DECISIONS.md). Decide in the design pass whether that's acceptable

6. [x] **Step 3 device QA, by hand** (DATE.md §7). Pushed 2026-09-28 (`6f13dd0`). **Passed on "T2 iPhone" 2026-09-28:**
   - ‹ / › move a day; tapping the date opens the calendar; tapping a day picks it and closes; the month/year wheel shows Done
   - Mar Vista on Oct 3 shows the no-moonrise state (pick Oct 3, or open the app that day)
   - Relaunch opens on today
   - **Deferred** (Tessa, 2026-09-28):
     - VoiceOver and Dynamic Type checks for the date row and sheet → DESIGN-REVIEW.md, Accessibility
     - Six-row month at the medium detent → DESIGN-REVIEW.md, Date control ("Calendar sheet header")
     - Background → foreground across the place's midnight (covered by unit tests; rare in practice)
     - Test target has no development team, so tests run on the iPhone 17 simulator only. Set a team
       under Signing & Capabilities to run tests on "T2 iPhone"

7. [ ] **Step 4 device QA, by hand** (COMPASS.md). The compass view is built (4.4); the simulator has no compass.
   1. [x] **Answered 2026-09-30:** with Precise off, iOS sends a true heading but reports ±81–86°, so the compass stays in low accuracy and never locks. Kept as is (DECISIONS.md 2026-09-30). Original check: true heading is valid under **approximate location**. `Info.plist` sets
      `NSLocationDefaultAccuracyReduced`; if iOS withholds `trueHeading` then, every reading is low
      accuracy and the compass never locks. With Precise Location off for Moon Signal, the heading
      should read and lock normally.
   2. The app stays in portrait when the phone is rotated.
   3. **Right after moonrise, the Moonrise and Moon targets overlap** (the moon is still where it
      rose). Note which label wins, and whether that's confusing. Expected per `CompassLock`: the
      nearer one wins, an exact tie goes to Moonrise, and once locked it holds until you turn more
      than 8° away. So it may stay "Moonrise" while the moon drifts from the rise point.
   4. **First device test 2026-09-29 (Tessa):** compass works at a basic level. Follow-ups to build,
      one commit each (COMPASS.md decision log, DECISIONS.md 2026-09-29):
      - [x] **4.5** Haptic tap on lock acquire. Built; **check on device:** one firm tap per lock,
        none on release or while holding, and none with Settings › Sounds & Haptics › System
        Haptics off
      - [x] **4.6** Proximity states: within 60 mi → shown (Nearby note), beyond → hidden (Far message);
        Turn On Location from the compass hint keeps the searched city, including after Settings.
        Built; **check on device:**
        - searched nearby city → "Directions for {City}" and a working lock
        - far city → the Far message only
        - with location off, the compass hint → prompt or Settings → back still shows the searched city
        - the main "Use my location" still switches to you
      - [x] **4.7** Remove the target rows under the dial (duplicate the moon table). Built; the dial
        now reads its targets to VoiceOver. **Check on device:** with VoiceOver on, swipe to the
        dial and hear "Targets: moonrise, …; moon, …"
   5. **Device test 2026-09-29 (Tessa), next fixes** — blocks the next TestFlight build:
      - [x] **4.8 + 4.9** Sensors stuck: "Compass accuracy is low" until Settings › Moon Signal ›
        Location was toggled off/on; and the compass gone after an overnight background. Likely one
        root cause (sensors not restarted on auth/accuracy change or foreground). Reproduce in a test,
        then fix. DEBUG-only readout (heading, accuracy, accuracyAuthorization, visibility, targets,
        lock, sensors running, haptic count) to diagnose on device.
        **Built** (DECISIONS.md 2026-09-29 "4.8 + 4.9"). **Check on device:**
        - hold the phone still on the compass for a few minutes: accuracy stays good
        - leave it backgrounded overnight: the compass is back in the morning
        - if either fails, send the DEBUG readout lines (accuracyAuthorization, detected, sensors)
      - [x] **Haptic** still missing after a lock (System Haptics on). **Works on the 337a7f1 build
        (Tessa, 2026-09-29).** That commit didn't touch the haptic path, so the earlier miss is
        unexplained; watch for it recurring
      - [x] **Low accuracy flip-flopping:** DEBUG readout showed real iOS accuracy crossing 15°
        (±11.8° → ±27.3° charging → ±13.4°), not a stuck state. Now hysteresis: enter above 25°,
        leave below 20° (DECISIONS.md 2026-09-29)
      - [x] **4.10** Inline low-accuracy reason (COMPASS.md §1 Accuracy). Built. **Check on device:**
        - turn Precise Location off for Moon Signal: in low accuracy, "Precise Location is off" +
          Open Settings, which lands on the app's page
        - with it on, near a charger or metal: the metal/magnets/charger tip
        - both lines clear once accuracy is back below ±20°

   6. **Device test 2026-09-30 (Tessa)** of 4.8–4.10:
      - [x] 4.10 Precise off → "Precise Location is off" + Open Settings. Appears after a pause or a
        relaunch, not always right after switching Precise off
      - [x] 4.10 interference tip comes and goes while charging (`full`, `interference`)
      - [x] Location off → compass hidden, Turn On Location hint
      - [x] 4.6 Nearby (LA, Los Feliz, Huntington Beach from Irvine) shows the compass and locks;
        Far (La Jolla) hides it
      - [ ] Still to check: phone held still for a few minutes; overnight background; Open Settings
        lands on the app's page; one haptic per lock
      - [x] **4.11** built (COMPASS.md §2, DECISIONS.md 2026-09-30). One commit:
        - Nearby note: "You're in {Detected city} but {City} is nearby"
        - Far message: "You're a bit too far from {City} to view the compass accurately"
        - Main-screen "Use my location" only on the empty first-launch state; the sheet row covers the rest
        - **Check on device:** LA from Irvine shows the new note and no button under the search field;
          La Jolla shows the new Far message; the sheet's row still switches to you; fresh install
          still shows the button and no prompt until it's tapped
      - [x] **4.12** built (COMPASS.md §1 Accuracy + §3 Privacy wording, DECISIONS.md 2026-09-30). One commit:
        - Remove `NSLocationDefaultAccuracyReduced`; new `NSLocationWhenInUseUsageDescription` text
        - `NSLocationTemporaryUsageDescriptionDictionary` key `Compass`; Use Precise Location →
          temporary full-accuracy request; "Always use Precise Location" → Settings; new reduced line
        - Aha line on reduced → full while visible
        - **Check on device:** delete and reinstall → the prompt shows Precise On and the new text;
          switch Precise off → the new line; Use Precise Location → iOS alert with our text → aha
          line → lock; relaunch later → asked again (temporary); "Always…" lands on the app's page
      - [x] **4.13** built: "City, ST" in the search field and compass copy (LOCATION.md "Place name on
        screen", DECISIONS.md 2026-09-30). One commit. **Check on device:** Irvine → "Irvine, CA";
        search Sydney, London, Paris, Tokyo, Singapore and note what each shows
      - **Device test 2026-09-30 1:49 PM (Tessa):** 4.12 new line + Use Precise Location → iOS alert with
        our text works. Two CTAs felt wrong; search misses Singapore/Tokyo, London, ON above London, UK
      - [x] **4.14** built. One button: remove "Always use Precise Location" (COMPASS.md §1). One commit
      - [x] **Step 2.2** built (fixes 1, 3, 2; one commit each). Search quality (SEARCH-RECENTS.md §0): filter, resolve-the-tapped-row, and ranking
        (smart, then closest) all decided. Before/after query table in latest.md. One commit per fix
      - [x] **4.15** built. Status bar: main-screen content must not slide under the clock. Use the iOS 26 top
        scroll edge effect (system fade/blur); solid bar background as fallback. One commit.
        *As built:* `.scrollEdgeEffectStyle(.soft, for: .top)` on the main `ScrollView`, plus the
        system bar material behind the status bar **before iOS 27 only** (`StatusBarBackdrop`). Your
        iOS 26.6.2 screenshot 03 shows no edge effect at all for this bare `ScrollView`, and only an
        iOS 27 simulator is installed here, so the iOS 26 path is the documented fallback, checked on
        the simulator by forcing it. Both paths checked in light and dark: the clock stays readable.
        **Check on device:** scroll the main screen to the compass; the clock stays readable over the
        moon table and date control, in light and dark mode

Design-pass items (visuals, copy, a11y) are tracked in **[DESIGN-REVIEW.md](DESIGN-REVIEW.md)**.

## Open questions
- ~~Minimum iOS version (suggested 26+)~~ **Settled 2026-09-23:** deployment target is 26.0, and
  Swift 6 with complete strict concurrency is on. Both built and ran clean. Project *and* target
  deployment targets are both 26.0, so new targets inherit the right floor
- ~~Show illumination for the current time or for local midnight?~~ **Settled 2026-09-23:** tonight's
  local midnight, i.e. the end of the selected day. See DECISIONS.md and PRODUCT FR5
- Primary persona (confirm with design partner)
- Display name "Moon Signal" for now, was "Moonbeam" (project name stays `moonbeam-app`). `AppInfo.name` and home-screen name updated (8ed1750)
