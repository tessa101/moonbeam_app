# Status & Handoff

> A living note on where things stand. Update it at the end of each work session
> so the next session (you, or Claude) can pick up cold.

_Last updated: 2026-09-23_

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

## Next
1. [x] Push to GitHub (docs + Xcode project are on `main`)
2. [x] Astronomy Engine spike: vendor `astronomy.c/.h`, bridging header, print the moon table for a hardcoded city
3. [x] Add a test target and pull USNO reference values
   - `moonbeam-appTests` (Swift Testing, app-hosted, shared scheme): **22 tests / 91 cases, all
     passing.** MoonPhase angle→name incl. wraparound, CompassFormatter sector edges, and
     AstronomyEngineMoonService against the §5 Mar Vista row.
   - **Validated against USNO:** rise and set times within ±2 min (engine 17:18:30 / 03:37:09 vs
     USNO 17:19 / 03:37), illumination at local noon within ±1% (90.9% vs USNO's 91%), and phase
     name. Azimuths have no USNO equivalent — USNO publishes none, which is why we calculate on
     device — so those stay engine-derived regression guards, labelled as such in the tests.
   - Note the moment mismatch in §3: USNO samples `fracillum` at local noon, the app displays
     tonight's local midnight (94%). Both are asserted, separately and for different reasons.
4. [ ] Build the SwiftUI table

## Open questions
- ~~Minimum iOS version (suggested 26+)~~ **Settled 2026-09-23:** deployment target is 26.0, and
  Swift 6 with complete strict concurrency is on. Both built and ran clean. Project *and* target
  deployment targets are both 26.0, so new targets inherit the right floor
- ~~Show illumination for the current time or for local midnight?~~ **Settled 2026-09-23:** tonight's
  local midnight, i.e. the end of the selected day. See DECISIONS.md and PRODUCT FR5
- Primary persona (confirm with design partner)
- Display name "Moonbeam" (project name is `moonbeam-app`)
