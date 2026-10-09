# Status & Handoff

> A living note on where things stand. Update it at the end of each work session
> so the next session (you, or Claude) can pick up cold.

_Release preparation, 2026-10-06 (Codex takeover): 5.9.3a is complete at `1b66c3e`; uploaded **TestFlight 1.0 (8)**. Full suite: **648 tests / 970 cases pass**. Signed Release archive succeeds, bundle version verified as 1.0 (8). Assessment and tester notes: `docs/TESTFLIGHT-BUILD-8.md`. Upload succeeded at 9:13 PM PDT; Apple reports the package is processing. Tester notes are ready to paste (App Store Connect browser signed out); loader accessibility review and 5.5 remain deferred._

_Last updated: 2026-10-09 (‹ › tap response specced as 5.10c (COMPASS-1.1.md §9.20: scale 0.88, lighter fill, held ≥ 90 ms, soft haptic per step); 5.10b confirmed on device; Day arrows still float after 5.10, on certain dates only (Oct 19 / Oct 26 / Oct 28 / Nov 11); Roadmap item 2 reopened as 5.10b: reproduce first, then fix + frame-sampling test (COMPASS-1.1.md §9.19, DECISIONS.md 2026-10-09); landing haptic OK on device; next: 5.10b prompt); 2026-10-08 (Cowork planning session after build 8 testing: Roadmap section added (work top to bottom); 5.10a specced (LOADER.md §12: one replayable load-in, place change, card skeleton, compass entrance + polish); 5.11 specced (new MOON-STATE.md); version naming 0.1 (9) from build 9, design rounds D1.x; build 8 testing notes routed in DESIGN-REVIEW.md; next: Roadmap 1 housekeeping, then 5.10); 2026-10-06 (Build 5.9.3b.6: 150 ms load-in stagger everywhere, after Aha 0.30 / 0.45 / 0.60 s; soft haptic as the moon lands; 969 cases pass; next: Tessa's check (feel the haptic), then 5.9.3a); 2026-10-06 (Build 5.9.3b.5: Aha leaves at the flight start; after a recovery the screen loads in by block around the flight, compass last; 968 cases pass; next: Tessa's check, then 5.9.3a); 2026-10-06 (Build 5.9.3b.4: flight overlaps the landing by 0.25 s on a curve that moves at once; 967 cases pass; next: Tessa's check, then 5.9.3a); 2026-10-06 (Build 5.9.3b.3: no pause after the landing, flight starts at the landing, Aha fades during the flight; 961 cases pass; next: Tessa's check, then 5.9.3a); 2026-10-06 (Build 5.9.3b.2: recovery is moon first: the ride starts at the fix at the cycle's speed, Aha 1 s before landing, 0.6 s rest; 959 cases pass; next: Tessa's check, then 5.9.3a); 2026-10-06 (Build 5.9.3b: label leaves at the fix (~3 ms), Aha overlaps at 0.15 s, moon rides forward to the real phase with a first-install lap; onboarding moon has the earthshine dark side (§11.6 item 5); 948 cases pass; next: Tessa's check, then 5.9.3a); 2026-10-06 (Build 5.9.3c moon smoothness: handoff month timing + sine ease, earthshine disc, glow follows k, eased stop; 928 cases pass; next: Tessa's check, then 5.9.3b); 2026-10-06 (Step 5.9.3 loader polish specced: LOADER.md §11, `design/1.5-loader-polish/MoonLoader.swift`; build order 5.9.3c → b → a; the agent's 5.9.3a stop was the missing spec); 2026-10-06 (5.9.2 flow pass: A/B/C built, Forget saved place, 923 cases, on the T2 iPhone); 2026-10-06 (5.9.2 default-size flow pass, part 1: Aha now waits for a full moon (was in over a dark moon); 919 cases pass; two timing calls open for Tessa, `.agent-reports/5.9.2/main-flows/findings.md`); 2026-10-05 (Location Services switch read off the main actor, loader clock starts before the permission read (LOADER.md §9 follow-up); device probe: authorized launches ready at 250–430 ms; 862 cases pass; Tessa's location-flow handoff recorded as LOADER.md §10, not built yet; next: build §10); 2026-10-05 (Build 5.9.1: launch stall fixed at its likely cause (not reproduced on device), 4.8 retry no longer cancels the launch fetch, content loads in, loader starts at a crescent; 562 tests / 857 cases pass; next: Tessa's device check, then 5.5); 2026-10-05 (Build 5.9: launch loader, the phase-cycle moon past 400 ms; 552 tests / 843 cases pass; next: Tessa's device check, then 5.5); 2026-10-03 (TestFlight 1.0 (6) and 1.0 (7) uploaded, same build twice; `CURRENT_PROJECT_VERSION` 7, next upload 8); 2026-10-03 (TestFlight build 5 prepared, 1.0 (5): Compass 1.1 spike + 5.6; Release build checked; 823 cases pass; archive/upload are Tessa's); 2026-10-03 (Build 5.6 [spike]: pinned compass bar, never shows at the default size, shows at xxxLarge / AX; all 823 cases pass; next: device check, then 5.9, then 5.5); 2026-10-03 (Build 5.4.8 [spike]: "After midnight" 13 pt, one line, no-rise card no longer grows; all 812 cases pass in Xcode); 2026-10-03 (Order: 5.4.8 + 5.6 in one run, then 5.9, then 5.5 AX reflow last); 2026-10-03 (Build 5.4.7 [spike]: Up now between Moonrise and Moonset, card 46 pt shorter; all 809 cases pass in Xcode; next: Tessa's device check of 5.4.6 / 5.4.7, then 5.6); 2026-10-03 (Build 5.4.6c [spike]: bottom bar, §9.12 fixes; all 797 cases pass in Xcode; next: Tessa's device check, then 5.6); 2026-10-02 (Build 5.4.6b [spike]: dial 260 pt, gaps, "After midnight"; next 5.4.6c; Build 5.4.6a [spike]: compact card; Compass 1.1 spike built, 5.4.1–5.4.5; sensors start when any part of the compass shows; next: the pinned-bar rule, then 5.5); 2026-10-01 (TestFlight build 4 prepared; onboarding Settings fix; Show onboarding in TestFlight; tap animation and DEBUG onboarding trigger built; next 5.5; Moon Signal app icon in; 5.8 moon arc built; next: DEBUG onboarding trigger, tap animation, then 5.5; TestFlight build 3 uploaded with 5.7; moon arc decided (option B, 5.8); Step 5.7 onboarding built ahead of 5.5/5.6; Step 5.3 madlib sentence built, with §3.1a; 5.2 follow-ups; Step 5.2 moon card built; 5.1 theme; Design 1.1 settled: DESIGN-1.1.md, Step 5; 4.14, Step 2.2 and 4.15 built; device checks pending)_

_Build 5.10a.2 completed 2026-10-09 (continued from Codex's uncommitted work): card skeleton after 400 ms during Use my location, sized by the replaced card; failure copy in the skeleton (also on a refused prompt / Location Off); VoiceOver focus to the card on landing; 6 new tests, all 982 cases pass. Not yet seen on screen. Next: Tessa's device check, then 5.10a.3. Report: `.agent-reports/5.10a/5.10a.2-findings.md`._

_Build 5.10c completed 2026-10-09: ‹ › use 0.88 scale, 10% white fill, ≥ 90 ms hold, 0.15 s spring release, and a soft 0.5 haptic per enabled step; extended frame sampling and all 974 cases pass. Report: `.agent-reports/5.10c/`._

_Build 5.10b completed 2026-10-09: reproduced first; exact madlib line slot fixes the cause; the 0.5 s frame-sampling regression and all 973 cases pass. Report: `.agent-reports/5.10b/`._

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

## Roadmap (Tessa + Cowork, 2026-10-08) — work top to bottom
Rule: finish what changes the card before the AX reflow, or the reflow is done twice.
1. [ ] **Housekeeping:** push `5122505`; commit MOON-STATE.md + the 2026-10-08 doc changes; paste tester notes
   (TESTFLIGHT-BUILD-8.md "What to Test") into App Store Connect.
2. [ ] **5.10 quick fixes** (one commit each):
   - [x] ‹ › day arrows float above the card when stepping days (fixed in 5.10b, **confirmed on device by Tessa 2026-10-09**: exact madlib line slot + both arrows sampled during the 0.5 s transition on all four dates, both directions, plus spread dates; §9.19–9.20). Then the ‹ › tap response
   - [x] **5.10c** (confirmed on device by Tessa 2026-10-09) ‹ › tap response: 0.88 scale, lighter fill held ≥ 90 ms, soft 0.5 haptic per enabled step; extended frame sampling; 974 cases pass (COMPASS-1.1.md §9.20)
   - [x] Landing haptic audited (2026-10-08; Tessa: OK on device 2026-10-08): implementation matches LOADER.md §11.2.7 and stays distinct from
     COMPASS.md §4.5's firm lock tap; recovery flight only, as designed. No clear bug/code change.
3. [ ] **5.10a place change + one load-in** (LOADER.md §12): 5.10a.1 replayable load-in, old place out → 5.10a.2 card
   skeleton → 5.10a.3 compass entrance + readout fade + Now pulse (§12.4, §12.4.1). Date changes cross-fade in place.
   - [x] **5.10a.1:** replayable `ContentLoadIn`; old place removed and token changed before sheet dismissal.
   - [x] **5.10a.2:** card skeleton past 400 ms, failure in its frame, no compass until the card lands (§12.8);
     device check pending.
   - [ ] **5.10a.3:** compass entrance + readout fade + Now pulse (§12.4, §12.4.1).
4. [ ] **5.11 moon state** (MOON-STATE.md): 5.11.1 middle column on today (Up now / Not up yet / Set for today),
   countdown, this pass's rise while up → 5.11.2 `23° up` → 5.11.3 edge-case voice line (draft copy).
5. [ ] **5.5 AX reflow** incl. the always-three-column card on today and the SE 3 connector; loader VoiceOver /
   Reduce Motion review (LOADER.md §10.6).
6. [ ] **5.12 location off:** dimmed compass preview instead of a bare CTA (to spec).
7. [ ] **TestFlight 0.1 (9)**: set `MARKETING_VERSION` 1.0 → **0.1** and `CURRENT_PROJECT_VERSION` 8 → 9
   (DECISIONS.md 2026-10-08, version naming); if App Store Connect rejects the version, go back to 1.0. Then device QA at default / AX1 / AX5; check the 5.8 arc after midnight (draws from the
   evening's rise; rise/set dots on the arc ends).
8. [ ] **Design review + pre-1.0:** motion pass, voice A (always-on answer line), light mode, onboarding copy, Round 2
   screens, VoiceOver order at AX2, final name + persona; remove Show onboarding / Forget saved place / `BuildChannel`;
   replace `appStoreReceiptURL`; USNO rows (item 3 below).
9. Later: Daily Moon Report widget / push; sun / tide sister app.
- OK for now: sentence tokens have no pressed state.

## Next
0. [ ] **Step 5.9.3 loader polish** (LOADER.md §11, DECISIONS.md 2026-10-06), one small prompt each: **5.9.3c** moon smoothness (built 2026-10-06) → **5.9.3b** transitions + phase ride (built 2026-10-06) → **5.9.3b.2** recovery moon first (built 2026-10-06) → **5.9.3b.3** no pause after landing (built 2026-10-06) → **5.9.3b.4** flight overlaps the landing (built 2026-10-06) → **5.9.3b.5** Aha out earlier, screen by block (built 2026-10-06) → **5.9.3b.6** 150 ms stagger + landing haptic (built 2026-10-06) → **5.9.3a** line height / text width (built 2026-10-06, `1b66c3e`). Then Tessa's device check.
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
     | Mar Vista (no moonrise) | 2026-10-03 | 34.00, -118.43 · PDT | **no rise** · set 14:27 (rise 23:12 on 10/2, 00:22 on 10/4) | `oneday?date=2026-10-03&coords=34.00,-118.43&tz=-8&dst=true` |

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
   - [x] **5.3 sentence revision (2026-10-01, Tessa):** "Where will the moon / be 📅 [date] / in 📍 [city]?".
     At the default size only, the three lines shrink together (minimum 0.7×) before any wraps; other sizes
     don't shrink and wrap. 401 tests / 613 cases. Screenshots: `.agent-reports/5.3-sentence-breaks/`.
     **Check on device:** Irvine, Rancho Santa Margarita and a 2027 date at default and AX3.
   - [x] **5.2 follow-up, smaller AM/PM (2026-10-01):** the day period is Young Serif at 60% of the time, same
     colour, on the baseline, found by the `.amPM` date field (works where it comes first or isn't used).
     At AX3 it wraps under the digits. One deprecation warning, on purpose (DECISIONS.md). 404 tests / 619 cases.
     Screenshots: `.agent-reports/5.2-ampm/`.
   - [x] **5.4 follow-up, live Moon marker (2026-10-01):** the Moon is a ~20 pt phase glyph (the card's), not a
     dot; locked like the others; VoiceOver "Moon now, west, 275 degrees". 403 tests / 615 cases. Screenshots:
     `.agent-reports/5.4-moon-marker/`. **Check on device:** with the moon up, the marker reads as the moon,
     not a second moonrise.
   - [x] **5.4 compass restyle (2026-10-01):** heading readout (Young Serif 24 in a 40 pt slot), 220 pt
     dial (gradient face, 15° tick dots, upright N/E/S/W with N amber, ↑/↓ by the rise/set dots, 18 pt
     live Moon dot with no arrow), lock = amber pill + dot ring/glow + dial halo, notes as amber-tint
     pills (`CompassNote`) with Use Precise Location / Turn On Location as secondary buttons. `tick` →
     `#807075`. Behavior unchanged (haptic, sensors, Far hides the dial); Reduce Motion swaps with no
     animation. 398 tests / 604 cases. Screenshots: `.agent-reports/5.4-compass/`. **Check on device:**
     the lock pill + haptic, marks moving smoothly, notes in low accuracy. Next: 5.5 AX reflow (incl. the
     260 pt dial).
   - **Order change (Tessa, 2026-10-01):** 5.7 onboarding is built first; **5.5 AX reflow and 5.6 pinned compass
     bar are deferred until after 5.7.**
   - [x] **5.7 onboarding (2026-10-01):** Landing → Location upsell → iOS prompt → "That’s okay" (after Don't
     Allow only); the prompt only from the Use my location tap. Allow / Allow Once → main screen, normal launch;
     Got it → "a city" empty state; Enable location → app Settings, and back authorized → main screen; Search
     instead → main screen with the search sheet, no prompt. Shows only with no saved place, permission not
     determined and onboarding not completed (any exit sets the flag). DEBUG reset: launch argument
     `-resetOnboarding`. Placeholder copy from the mockup, as-is (DECISIONS.md "5.7 onboarding"). 427 tests / 648
     cases. Screenshots: `.agent-reports/5.7-onboarding/` (default + AX5). **Check on device:** fresh install →
     onboarding; Allow Once; Don't Allow → Enable location → turn on in Settings → back lands on the main screen.
     **Next, in order (2026-10-01):** (1) DEBUG onboarding trigger: `-forceOnboarding` (ignores all
     conditions) + `-onboardingPage landing|upsell|declined`, no stored-state changes, temporary; (2) tap
     animation on buttons (DECISIONS.md 2026-10-01); (3) **5.8 moon arc** (DESIGN-1.1.md §3.3a, option B, 24 pt glyph, dial 196 pt); (4) 5.5 AX reflow, then 5.6 pinned bar.
     **Open:** lock halo vs the amber arc; pinned bar's compact dial (decide in 5.6).
   - [x] **5.8 moon arc (2026-10-01, built ahead of the DEBUG trigger and tap animation at Tessa's request):**
     dial 196 pt; the moon's pass as an arc outside the rim (option B: travelled hairline, dotted rest), rise/set
     dots on it, the live Moon a 24 pt glyph on a `bg` disc, heading capsule beyond the arc. Moon down / other
     days: the pass from that day's moonrise, dimmed, no glyph. Path sampled every 15 min by the new
     `MoonService.moonPass(for:containing:)` (`MoonPass` model), so southern-hemisphere passes run through the
     north. VoiceOver unchanged. 448 tests / 669 cases. Screenshots: `.agent-reports/5.8-moon-arc/`.
     **Check on device:** the arc follows the moon over an evening; the block is ~47 pt taller than 5.4 (not
     25–30), so check the compass's position on the smallest phone (§3.3a: shrink to 180 pt first).
     **Open:** cross-day passes (see DECISIONS.md "5.8 moon arc"); halo vs arc looks fine in the screenshot
     (it barely shows past the face); pinned bar (5.6).
     **Next:** (1) DEBUG onboarding trigger; (2) tap animation; (3) 5.5 AX reflow, then 5.6.
   - [x] **DEBUG onboarding trigger (2026-10-01):** `-forceOnboarding`, `-onboardingPage landing|upsell|declined`,
     and a DEBUG-only Show onboarding button at the bottom of the main screen. No stored state changes (checked
     in the simulator's defaults too). Absent from Release (`strings`). **Temporary: remove before the 1.0 App
     Store build.** Screenshots: `.agent-reports/debug-onboarding/`. 458 tests / 683 cases.
   - [x] **Tap animation (2026-10-01):** shared `PressFeedback` (scale 0.96 + opacity 0.8, 0.15 s spring; Reduce
     Motion: opacity only) in the primary, secondary and text-link styles and the ‹ › day buttons. Sentence
     tokens not done (inline links, open in DECISIONS.md). 461 tests / 687 cases. Screenshots:
     `.agent-reports/tap-animation/`. **Check on device:** tune the scale/opacity/spring by feel.
     **Next:** 5.5 AX reflow, then 5.6 pinned bar.
   - [x] **Onboarding, Location Services off / Never (2026-10-01):** Use my location opens Settings and stays on
     the upsell instead of showing "That's okay"; back allowed → main screen. Real Don't Allow unchanged.
     468 tests / 696 cases. Screenshots: `.agent-reports/onboarding-services-off/`. **Check on device:** that the
     Settings URL lands on Moon Signal's page (the simulator showed Settings' last page).
   - [x] **Show onboarding in TestFlight (2026-10-01):** the button shows in DEBUG and TestFlight
     (`BuildChannel.isTestFlight`, the `sandboxReceipt` check), not App Store; launch arguments stay DEBUG-only.
     **Temporary: remove the button and `BuildChannel` before the 1.0 App Store build** (and Forget saved place
     beside it, 2026-10-06). 473 tests / 706 cases.
     Findings: `.agent-reports/testflight-onboarding-button/`. **Check in TestFlight:** the button is there.
   - [x] **App icon (2026-10-01):** the Moon Signal design replaces the placeholder (`MoonSignal-AppIcon-*`):
     Dark in both the default and dark slots (the app is dark-only, so there's no light design), Tinted for
     tinted. **Check on device:** home screen in default, dark and tinted. In TestFlight build 4.
   - [ ] **Compass 1.1 (decided 2026-10-02, build before 5.5):** [COMPASS-1.1.md](COMPASS-1.1.md) §7, one commit
     each: 5.4.1 Up now row + lock highlight; 5.4.2 dial (needle, ticks, numbers, serif cardinals, crosshair);
     5.4.3 accuracy notes under the readout; 5.4.4 target labels outside the arc + pulse; 5.4.5 sentence
     ("Where can I find / the moon today / in [city]?"). **5.4.1 done** (1fa2bed, bb6e4d2; scheme fix 6044e4c).
     **Next:** sensor threshold fix (§5a), then 5.4.2–5.4.5, then **5.4.6 spacing pass** (§9) after Tessa's device
     check, then the pinned-bar rule (§6), then 5.5.
   - [x] **5.9 Launch loader (decided 2026-10-02, after 5.4.6):** [LOADER.md](LOADER.md). Under 400 ms soft fade;
     over 400 ms the centred phase-cycle moon only (skeleton dropped 2026-10-03). Fixes the "dummy main screen" launch bug
     (DESIGN-REVIEW.md). Order (Tessa, 2026-10-03): 5.4.8 + 5.6 → **5.9** → 5.5 last.
     - [x] **Build 5.9 (2026-10-05):** as LOADER.md §8. Fix inside 400 ms: no loader, the screen fades in (250 ms);
       past that the 140 pt phase-cycle moon, forward, 4.8 s month, glow brightest at full, held ≥ 700 ms, cross-fade.
       Nothing else on screen while loading (no pinned bar, DEBUG readout, Show onboarding, "a city"). Reduce
       Motion: still full moon, glow fades. VoiceOver: announced once, then focus to the sentence. DEBUG
       `-screenState loading`. **Open for Tessa:** no failed-fetch note on a launch timeout (LOCATION.md §3 says
       quiet; LOADER.md §2 mentions a note). Simulator only: Reduce Motion and VoiceOver not checked on screen.
       Report, 20 shots + 4 contact sheets: `.agent-reports/5.9/`. **552 tests / 843 cases, all pass.**
       **Next:** Tessa's device check (a real slow fix), then 5.5 AX reflow last.
     - [x] **Build 5.9.1 (2026-10-05):** Tessa's device check found a multi-second blank launch, no moon (LOADER.md
       §9). Three commits. (1) Not reproduced on the T2 iPhone (~10 cold launches, all ready in 0.25–0.45 s; moon
       on screen at 579 ms with a slowed fix); fixed at the likely cause, `locationServicesEnabled()` on the main
       thread (now read only for not determined / denied), and the 4.8 retry no longer cancels the launch fetch.
       os_signposts kept. (2) Content loads in (sentence → card → compass, 8 pt rise, 300 ms, 70 ms stagger), no
       whole-screen fade; same after the phase cycle (it fades out 200 ms). (3) Loader month starts at a waxing
       crescent, 25% lit. Report, recordings, contact sheets: `.agent-reports/5.9.1/`. **562 tests / 857 cases,
       all pass.** **Open for Tessa:** device check of a real home-screen launch; no Instruments trace (blocked in
       this session); the system launch screen is black, not `bg` (a possible "scrim" flash, not changed).
       **Next:** Tessa's device check, then 5.5 AX reflow last.
     - [ ] **Build 5.9.2 (2026-10-06):** location messages, recovery Aha and loader accessibility (LOADER.md §10).
       Parts 1–5 of 6 are built: `bg` launch screen; waxing-gibbous hold phase and entrance; no-place message
       states; recovery-only Aha and moon flight; message layout that measures the actual Dynamic Type content,
       shrinks/lifts the moon and steps headline/body to 0.8× when needed, then scrolls as the AX fallback.
       Visual matrix: all five messages × iPhone 17 / SE 3 × default / AX1 / AX5 pass. Primary CTA is exactly
       56 pt high throughout; all text/actions remain accessible and every overflow state scrolls successfully.
       Eight lean screenshots and the full findings are in `.agent-reports/5.9.2/5-ax/`.
       **918 / 918 tests pass. Next (Tessa, 2026-10-06):** review and polish the main location flows and animations
       at default text size: fast/slow launch, messages, permission outcomes, return from Settings, retry, city
       search, saved-place fallback and recovery → Aha → main screen. Check entrance/cycle/hold, greeting timing
       and flight into the card; record simulator findings and remaining device checks.
       **Deferred:** §10.6 Reduce Motion and VoiceOver (6/6), and other accessibility work, including the invisible
       outgoing searching label's VoiceOver exposure. Preserve the completed small-screen and large-text layouts.
       **Flow pass, part 1 (2026-10-06):** Aha waited only 1.8 s from the hold phase, by which time the moon had passed
       full, so its text came in over a dark moon. Fixed: the run-out to full now happens under the label, and Aha
       comes in at full (up to 1.85 s later). **919 cases pass.** **Open for Tessa:** (A) known-reason messages take ~3.3 s
       with a fast spin before the stop; (B) a fix just past 400 ms shows a half-entered loader. Findings:
       `.agent-reports/5.9.2/main-flows/findings.md`. **Next:** re-record recovery → Aha, then walk permission / Settings /
       search flows on screen.
       **Flow pass, Tessa's calls (2026-10-06):** (A) a known reason holds the moon, message at ~1.55 s; (B) loader at least
       1.1 s; (C) Aha's run to full starts at the fix (no 1.8 s minimum, label ≥ 0.7 s). Plus **Forget saved place**
       (DEBUG / TestFlight, temporary) beside Show onboarding. **923 cases pass.** Installed on the T2 iPhone for her check.
     - [x] **Build 5.4.1 [spike] (2026-10-02):** Up now row + lock highlight, two commits. The row shows only where the
       compass does (today, Here / Nearby) and refreshes on the compass's tick: **decide** whether it should
       show for any place (DECISIONS.md 2026-10-02 as built). Moonrise/Moonset are now boxed cells, the
       hairline between them is gone. **495 tests / 736 cases across 37 suites**, all pass (iPhone 17 sim).
       Report: `.agent-reports/5.4.1/`. Not yet checked on a 375 pt phone or on device.
     - [x] **Fix (2026-10-02):** compass sensors start when any part of it is visible (threshold 0.1).
     - [x] **Builds 5.4.2–5.4.5 [spike] (2026-10-02):** dial (needle, ticks, numbers, serif cardinals, crosshair);
       accuracy notes under the readout; target labels outside the arc + Moon pulse; sentence "Where can I find /
       the moon today / in …?". **504 tests / 750 cases across 38 suites**, all pass. Not on device yet: tick shimmer, pulse, haptics.
     - [ ] **Fit (2026-10-02, `.agent-reports/5.4-fit/`):** on load at the default size, iPhone 17 with a good
       heading: dial face ends 6 pt above the screen bottom, the arc 10 pt past it; iPhone SE: the dial is ~160 pt
       below the fold. **Decide the pinned-bar rule (§6) next.**
     - [x] **Build 5.4.6a [spike] (2026-10-02):** card header row (glyph · date over "Phase · N% lit" · ‹ ›),
       tighter rise/set, Up now pill / "● Rises …" line (COMPASS-1.1.md §9.2). Builds; previews in
       `.agent-reports/5.4.6/`. **Tests not run** (test runner can't launch in this environment); run them next.
       **Next:** 5.4.6b (dial, spacing, fit report), 5.4.6c (bottom bar).
     - [x] **Build 5.4.6b [spike] (2026-10-02):** dial 260 pt (by width; 233 on SE 3), gaps 28 / 32 / ~35, short needle,
       Moon at 12 on lock, even label gaps, sentence 1.2×, pill/readout 20 pt with small letters, phase line to 0.85×,
       label → time 2 pt, "After midnight" + next time (COMPASS-1.1.md §9.11). Fit: iPhone 17 dial + labels on screen
       (labels 22 pt into the home-indicator area); SE 3 dial centre on screen, face 72 pt below. Report and 78
       screenshots: `.agent-reports/5.4.6/`. **Tests not run** (runner can't launch here). **Next:** Tessa's device
       check, 5.4.6c (bottom bar).
     - [x] **Build 5.4.6c [spike] (2026-10-03):** notes in a bar fixed above the home indicator (Precise off with Use
       Precise, low accuracy, Nearby, aha; one at a time), the dial dims in low accuracy; §9.12: readout / pill 24 pt
       with 0.7× capitals, missing-cell labels aligned, "After midnight" in the time font, needle 28 pt, phase line
       always one line. Text in the bar capped at AX1; the bar holds its note while the sensors pause (COMPASS-1.1.md
       §9.13). On load a bar covers the dial's bottom (iPhone 17) or its centre (SE 3). Report and 84 screenshots:
       `.agent-reports/5.4.6/5.4.6c-bar.md`, `c/`. **521 tests / 797 cases, all pass** (Xcode's runner; three stale
       5.4.6b tests fixed). **Next:** Tessa's device check, then 5.6 (pinned bar).
     - [x] **Build 5.4.7 [spike] (2026-10-03):** Up now moves into the rise / set row as a middle column (glyph on a
       connector, solid rise → now, dotted now → set); moon down / other dates: two columns and a dim dotted line; the
       pill row and "● Rises …" line are gone (AX sizes keep the pill as a fallback). Card **46 pt shorter**, same
       height up and down; iPhone 17 dial face now 106 pt above the fold (COMPASS-1.1.md §9.14, §9.15). Fixed AX5
       "57° E…". Report and 36 screenshots: `.agent-reports/5.4.7/`. **528 tests / 809 cases, all pass** (Xcode's
       runner). **Open:** no-rise day wraps at 80%; no connector on the SE 3; moon down doesn't speak the next rise.
       **Next:** Tessa's device check of 5.4.6 / 5.4.7, then 5.6 (pinned bar).
     - [x] **Next (Tessa, 2026-10-03): 5.4.8 + 5.6 in one run**, one commit each, 5.4.8 first: smaller "After
       midnight" (COMPASS-1.1.md §9.16 item 1), then the pinned bar (§9.6; AX best effort). Then 5.9, then 5.5 last.
       Device check after 5.4.7 done (§9.16); the ‹ › bug is parked.
     - [x] **Build 5.4.8 [spike] (2026-10-03):** "After midnight" / "Not today" in their own 13 pt Young Serif,
       out of the columns' shared scale, in a time's slot (COMPASS-1.1.md §9.16 item 1, §9.17). **Below the spec's
       15–20 pt:** 15 pt can't fit one line beside Up now and Moonset on the SE 3 (13.3 pt max; 16.8 pt on the
       iPhone 17). **Tessa to confirm** 13 everywhere vs per phone. No-rise card now the same height as a normal day
       (181.3 / 181.5 pt). Report and 12 shots: `.agent-reports/5.4.8/`. **530 tests / 812 cases, all pass.**
     - [x] **Build 5.6 [spike] (2026-10-03):** pinned compass bar (COMPASS-1.1.md §9.6, §9.18): glass capsule with
       the live readout and Compass ↓ (scrolls to the compass), amber with the lock text on lock, on top of a bottom
       note; shows while the dial's centre is below the fold, and the sensors run while it does. At the default size
       it **never shows** on the iPhone 17 or SE 3 (5.4.8 card); it shows at xxxLarge and every AX size. AX best
       effort: "↓" button when "Compass ↓" doesn't fit; the AX breakages are listed for 5.5 in the report. Report,
       58 shots + contact sheets: `.agent-reports/5.6/`. **536 tests / 823 cases, all pass.**
       **Next:** Tessa's device check of 5.4.8 / 5.6 (and the 13 pt call), then 5.9 launch loader, then 5.5 AX
       reflow last.

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

8. [ ] **TestFlight build 3 (1.0 (3), prepared 2026-10-01).** Everything since build 2 (`55b64b3`): Design 1.1
   5.1–5.4 and 5.7 (theme, moon card, madlib sentence, compass restyle, onboarding), the 5.2/5.4 follow-ups and
   Step 2.2 fix 4. 5.5 (AX reflow) and 5.6 (pinned compass bar) are **not** in it. Release build checked: CFBundleVersion
   3, the four fonts + OFL texts and `PrivacyInfo.xcprivacy` in the bundle, `-resetOnboarding` compiled out,
   `ITSAppUsesNonExemptEncryption` false. 427 tests / 648 cases pass. **Archive and upload are Tessa's** (not done by the agent).
   **What testers should check:**
   - **Onboarding needs a fresh install.** An update from build 2 has a saved place or a location answer, so it goes
     straight to the main screen (by design). Delete the app, then install build 3:
     - Landing → Get started → upsell; no location prompt until **Use my location** is tapped
     - **Allow** (and, on a second reinstall, **Allow Once**) → main screen with your city
     - **Don't Allow** → "That’s okay" → **Got it** → "Where will the moon be tonight in 📍 a city?" with Use my location
     - **Don't Allow** → **Enable location** → turn location on in Settings → back in the app lands on the main screen
       with your city
     - **Search for a city instead** → search sheet, no prompt; Cancel → "a city"; force-quit and relaunch → no onboarding
   - **Upgrade from build 2** (don't delete): opens on the main screen with the last city; no onboarding
   - **Main screen look (Design 1.1):** dark theme and fonts; the sentence's 📅 / 📍 tokens open the calendar and the
     search; the moon card's ‹ ›, phase glyph, rise/set with "PM" smaller; the zone abbreviation for a far city
   - **Compass:** the new dial; marks move smoothly as you turn; lock pill + one haptic; the live Moon marker reads as
     the moon, not a second moonrise; low-accuracy and Nearby notes
   - **Text size:** onboarding at the largest size scrolls and every button can be reached (the main screen's AX
     layout is 5.5, not in this build)
   - **VoiceOver:** onboarding titles read as headings; the sentence then "Date, …" / "Place, …" buttons
   - Known, not fixed: onboarding text scrolls under the clock at large sizes; "That’s okay" copy is placeholder

9. [ ] **TestFlight build 4 (1.0 (4), prepared 2026-10-01).** Everything since build 3 (`64a99bc`):
   - **5.8 moon arc:** 196 pt dial, the moon's pass as an arc outside the rim (travelled hairline, dots to
     moonset), rise/set dots on it, the live Moon a 24 pt glyph riding it, heading marker beyond the arc.
   - **New app icon:** the Moon Signal design, with default, dark and tinted variants.
   - **Button tap animation:** buttons shrink slightly and dim while pressed (Reduce Motion: dim only). The sentence's
     📅 / 📍 tokens have **no pressed state yet** (open in DECISIONS.md).
   - **Onboarding Settings fix:** with Location Services off, or location set to Never, Use my location opens
     Settings instead of "That's okay"; back with location allowed → the main screen.
   - **Show onboarding button, TestFlight-only and temporary:** at the bottom of the main screen, reopens onboarding
     without deleting the app; writes no stored state. Hidden in App Store builds; remove before 1.0. The DEBUG
     launch arguments (`-forceOnboarding`, `-onboardingPage`) are **not** in this build.
   - Still **not** in it: 5.5 (AX reflow), 5.6 (pinned compass bar).

   Release build checked: CFBundleVersion **4** (MARKETING_VERSION 1.0); the four fonts in the bundle and in
   `UIAppFonts`, both OFL texts; `PrivacyInfo.xcprivacy` (no tracking, no collected data, UserDefaults `CA92.1`);
   forced dark; display name "Moon Signal"; minimum iOS 26.0; `ITSAppUsesNonExemptEncryption` false; the icon's
   default, dark and tinted renditions in `Assets.car`. Launch arguments: 0 `strings` hits for `-forceOnboarding`,
   0 symbols for the launch-argument code (`strings` can't see strings of 15 bytes or fewer, such as
   `-onboardingPage`; DECISIONS.md). 473 tests / 706 cases pass. **Archive and upload are Tessa's** (not done by
   the agent).
   **What testers should check:**
   - **Icon** on the home screen in default, dark and tinted (Home Screen → Edit → Customize)
   - **Moon arc:** it follows the moon over an evening (glyph moves along, hairline grows behind it); a pass that
     crosses midnight (moon up after 12 AM) still draws from the evening's rise; moon down shows the next pass dimmed
   - **Compass height:** the block is ~47 pt taller than build 3; on the **smallest phone**, check how far below the
     moon card it sits
   - **Button press feel:** Get started, Use my location, the ‹ › day buttons, Use Precise Location: does the shrink
     and dim feel right, too much or too little?
   - **Onboarding via Show onboarding** (bottom of the main screen): the whole flow again without deleting the app,
     then back to the main screen with your city unchanged
     - With location set to **Never** (Settings → Moon Signal → Location): Use my location opens Settings, not
       "That's okay"; set it to While Using and come back → main screen. Note where Settings opens (Moon Signal's
       page or somewhere else)
     - Also with Location Services off entirely (Privacy & Security → Location Services)

10. [x] **TestFlight builds 6 and 7 (1.0 (6), 1.0 (7), uploaded 2026-10-03; same content, uploaded twice; prepared as build 5).** Latest is **1.0 (7)**; the next upload is **8**. Everything since build 4 (`2be3270`): the Compass 1.1
   spike (COMPASS-1.1.md, 5.4.1–5.4.8) and 5.6:
   - **Sentence:** three lines, "Where can I find / the moon **today** / in 📍 Irvine, CA?" (another day reads "on Sat,
     Oct 3"); lines a little closer together.
   - **Moon card:** compact header (phase glyph · "Today · Fri, Oct 2" over "Last Quarter · 53% lit" · ‹ ›). With the
     moon up today: **↑ Moonrise · Up now · ↓ Moonset** in one row, the phase glyph on a line between them (solid
     rise → now, dotted now → set) and the live bearing under "Up now". Moon down or another day: rise and set with
     a dim dotted line. The card is the same height either way. A compass lock outlines the matching cell. A day with
     no moonrise shows "After midnight" (smaller) and the next time ("Sun 12:20 AM").
   - **Compass:** bigger dial (260 pt on a 6.3" phone), short needle, ticks, degree numbers, serif N / E / S / W,
     crosshair; readout and lock pill at the card's time size with smaller direction letters; "↑ Rise" / "↓ Set" /
     "Now" labels outside the arc; the Moon pulses until your first lock; locked on the Moon, it sits at 12 o'clock.
   - **Notes in a bottom bar** just above the home indicator: Precise off (with **Use Precise**), low accuracy (one
     line for every cause; the dial dims and won't lock), Nearby, and the "There you are!" line. One at a time.
   - **Sensors start as soon as any part of the compass is on screen** (it used to need half of it).
   - **5.6 pinned compass bar:** when the dial's centre is below the fold, a glass bar near the bottom shows the live
     heading and **Compass ↓** (scrolls to the dial); amber with the lock text when locked. At the default text size it
     doesn't appear on the iPhone 17 or SE 3 (the two measured); it shows with larger text.
   - Still **not** in it: 5.5 (AX reflow), 5.9 (launch loader). The TestFlight-only Show onboarding button is still
     there.

   Release build checked: CFBundleVersion **6** (MARKETING_VERSION 1.0; rebuilt after the 5 → 6 bump); the four fonts in the bundle and in
   `UIAppFonts`, both OFL texts; `PrivacyInfo.xcprivacy` (no tracking, no collected data, UserDefaults `CA92.1`);
   forced dark; display name "Moon Signal"; minimum iOS 26.0; `ITSAppUsesNonExemptEncryption` false; location
   purpose strings (When In Use, temporary `Compass`), no `NSLocationDefaultAccuracyReduced`; the icon's default,
   dark and tinted renditions in `Assets.car`. DEBUG-only code compiled out: 0 symbols for `DebugScreenState` or the
   compass's diagnostic readout, 0 `strings` hits for the launch arguments (`strings` can't see Swift strings of 15
   bytes or fewer, so the symbol check is the real evidence; DECISIONS.md). `CompassPinnedBar` is in.
   536 tests / 823 cases pass. **Archive and upload are Tessa's** (not done by the agent).
   **What testers should check:**
   - **Moon card, moon up today:** three columns; "Up now" and its bearing change as the moon moves (30 s); after the
     moon sets the middle column goes and **nothing below the card moves**
   - **In the morning:** the Moonrise column shows *tonight's* rise left of "Up now" (the moon rose last night). Does
     the solid line from it read as "rose at …"? (COMPASS-1.1.md §9.14 watch item)
   - **A no-moonrise day** (Irvine: Sat Oct 3, via ›): "After midnight" on one line, smaller, next to full-size times;
     the card no taller than the day before. Is 13 pt too small? (DECISIONS.md "5.4.8 as built")
   - **Compass:** dial size and spacing on your phone; turning feels smooth; the Moon's pulse stops after the first
     lock; locking on rise / set / Moon outlines the matching card cell, with one haptic
   - **Bottom bar:** turn Precise Location off (Settings → Moon Signal → Location) → the bar with Use Precise; tap it →
     the iOS alert → "There you are!" for ~3 s; near a charger or metal → the low-accuracy bar, dial dimmed; pick a
     nearby city → the Nearby bar
   - **Pinned bar:** Settings → Display & Brightness → Text Size, largest (or Accessibility → Larger Text): the bar
     shows near the bottom; **Compass ↓** scrolls to the dial and the bar goes; point at a target while it shows → the
     bar turns amber; with a note showing, the bar sits on top of it
   - **Smallest phone:** how far below the card the dial sits; any text that wraps or truncates
   - Known, not fixed: at large / AX text sizes the main screen still uses the old layout and some of it breaks
     (5.5; list in `.agent-reports/5.6/5.6-pinned-bar.md`); the tapped ‹ / › can float above the card for a moment
     when stepping days (parked, DESIGN-REVIEW.md "Date control")

Design-pass items (visuals, copy, a11y) are tracked in **[DESIGN-REVIEW.md](DESIGN-REVIEW.md)**.

## Open questions
- ~~Minimum iOS version (suggested 26+)~~ **Settled 2026-09-23:** deployment target is 26.0, and
  Swift 6 with complete strict concurrency is on. Both built and ran clean. Project *and* target
  deployment targets are both 26.0, so new targets inherit the right floor
- ~~Show illumination for the current time or for local midnight?~~ **Settled 2026-09-23:** tonight's
  local midnight, i.e. the end of the selected day. See DECISIONS.md and PRODUCT FR5
- Primary persona (confirm with design partner)
- Display name "Moon Signal" for now, was "Moonbeam" (project name stays `moonbeam-app`). `AppInfo.name` and home-screen name updated (8ed1750)
