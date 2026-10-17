# Step 5.13: search is a detour, "That's okay for now", suggested cities, tap feedback

_Decided by Tessa, 2026-10-14 and 2026-10-15 (flow diagram "Onboarding tweaks 10/15"), from a TestFlight 0.1 (10)
recording. Three small agent runs: 5.13.1 → 5.13.2 → 5.13.3. Replaces the open follow-up in
STEP-5.10a-LOCATION-CONSOLIDATION.md §6 ("decline acknowledgment → city search"). The cat on the landing screen and
the onboarding load-ins are STEP-5.14-ONBOARDING-CAT-AND-LOAD-IN.md._

> **Status (2026-10-15):** the cancel-search flow is an MVP blocker and is still being decided (separate chat).
> **5.13.1 and 5.13.2 are on hold.** 5.13.3 (tap feedback, §4) doesn't depend on it and can be built now. The rule in
> §1 and the copy in §2 are Tessa's decisions so far; they may change with the flow.

> **Update (2026-10-16):** the cancel-search flow is decided in [ONBOARDING-MOD-MAIN.md](ONBOARDING-MOD-MAIN.md): the main screen gets a `noCity` state, Search is a sheet, and closing it always returns there. Where this doc disagrees about where Search close or "Search instead" lands, ONBOARDING-MOD-MAIN.md wins. Re-read §1 and §2 against it before building 5.13.1 and 5.13.2.

## 0. The problem

After a real **Don't Allow** on the onboarding upsell, "That's okay" showed. **Got it** exited onboarding with no saved
place and a denied permission, so the main screen showed the **telescope**: the same message twice in a row.

## 1. The rule: search is a detour (Tessa, 2026-10-15)

Whenever the user opens **Search for a city (instead)** and closes the sheet with **Cancel** (or a drag), they go
**back to the screen they opened it from**. Picking a city goes to the main screen with that city.

| Opened from | Cancel returns to | Pick goes to |
|---|---|---|
| Onboarding upsell (2) | the upsell | main screen, that city |
| "That's okay for now" (3) | "That's okay for now" | main screen, that city |
| Telescope and the other failure screens (5) | the same failure screen | main screen, that city |
| First ask, loader message, main screen | the same screen | main screen, that city |

Telescope, the other failure screens and the main screen already behave this way (consolidation Chunk 3 tests cover
cancel and pick for every cause). **The upsell is the exception today**: its Search exits onboarding and Cancel
lands on First ask, which looks almost like the upsell. 5.13.1 fixes that with the same mechanism as "That's okay".

## 2. "That's okay for now" and the sheet over onboarding (5.13.1)

Copy (Tessa; replaces the old "That's okay" text, `OnboardingCopy`):

- Title: **That's okay for now**
- Body: **You can still search for a city, but to use the advanced features, like the compass, you will need to enable
  location.** (with the full stop the old body lacked)
- Primary: **Got it** → opens the city search (accessibility hint "Opens city search").
- Secondary: **Enable location** → Settings, unchanged; coming back authorized goes to the main screen.

Behaviour:

- Both onboarding screens present the search sheet **over** themselves; onboarding stays up behind it, so Cancel
  needs no routing. Build the sheet from `SearchSheet`/`SearchSheetViewModel` (a factory closure from the app root is
  fine); onboarding must not gain its own place or recents writes.
- **Pick** (a recent, a suggested city, or a resolved suggestion): onboarding finishes with a new outcome carrying the
  place (e.g. `.pickedCity(Place)`), marking completed unless forced.
  `LocationViewModel.onboardingDidFinish` routes it to the existing `select(_:)`, so `LocationViewModel` stays the
  only writer of the place, `lastViewed` and recents. The main screen loads in as for any picked city (LOADER.md §12).
- **Cancel / drag-dismiss:** step unchanged, no flag, place or permission change, VoiceOver focus back on the button
  that opened the sheet.
- The upsell's "Search for a city instead" uses the same sheet (the old `finish(.searchInstead)` exit goes away for
  that button).
- **Use my location row in the sheet** (§3): from onboarding it behaves like the upsell's primary.
- **Forced run (Show onboarding):** a pick still selects the place but sets no completed flag.
- Tests: pick from each onboarding screen ends onboarding with the place selected and recents updated; Cancel on each
  leaves the step, flag unset and no place; the copy strings; Enable location unchanged; `-onboardingPage declined`
  still works.

## 3. The search sheet: location row and suggested cities (5.13.2)

> **Status (2026-10-16):** 5.13.2 is built and no longer on hold. Notes from the build:
> - The location row keeps the existing rule: shown unless the place is already the detected location, or location is restricted (Settings can't help there, so the row would be dead).
> - Denied or Location Services off: the row opens Settings and the sheet stays. Back authorized, the sheet closes and the row's flow runs (on noCity, Enable location).
> - Rows show "Los Angeles, CA" over "United States", matching the table's Row column.
> - With no recents, the field isn't auto-focused (§6 "Keyboard vs the suggested cities"). With recents, it focuses as before.

Sheet content, 0-character state, top to bottom:

1. **Use my location**, first, with the **place pin** (the same pin glyph as the main page's place token, not the
   arrow) as its icon. Shown when the sheet is in its "no recents / first time" state or without location.
   - Permission not determined: closes the sheet and runs the normal Use my location flow (in onboarding, the
     upsell's `useMyLocation()`; Don't Allow then goes to "That's okay for now").
   - Denied or Location Services off (no prompt can show): **opens the app's Settings and the sheet stays**, the
     same rule as the onboarding upsell (DECISIONS.md 2026-10-01 "Location Services off"). Coming back authorized
     finishes as Allow.
2. **Recent** (when there are recents).
3. With no recents: a section headed **Search for your city or choose one of these** with five rows. With recents the
   five are hidden. Typing switches to the usual suggestions. Applies to every search sheet, because a new user who
   opens search from anywhere has no recents.

| Row | name / region / country | latitude | longitude | time zone |
|---|---|---|---|---|
| Los Angeles, CA | Los Angeles / CA / United States | 34.0522 | -118.2437 | America/Los_Angeles |
| New York, NY | New York / NY / United States | 40.7128 | -74.0060 | America/New_York |
| Paris | Paris / – / France | 48.8566 | 2.3522 | Europe/Paris |
| London | London / – / United Kingdom | 51.5074 | -0.1278 | Europe/London |
| Tokyo | Tokyo / – / Japan | 35.6762 | 139.6503 | Asia/Tokyo |

- Fixed `Place` values, no network, so a pick can't fail; row title the short name, detail the region or country;
  no coordinates on screen. A picked city becomes a recent. "New York, NY" (not NYC) to match "Los Angeles, CA".
- Header has the header trait; rows read "Los Angeles, California, United States" style labels.
- Tests: empty recents shows the five; recents hide them; typing hides them; a pick calls `onPick` with the fixed
  place and its own time zone; the row is first and uses the pin; denied/off opens Settings and keeps the sheet.

## 4. Tap feedback on every control, app-wide (5.13.3)

**Global, not specific to onboarding or search.** It is a design-system rule: the 100 ms minimum hold lives in the
shared `PressFeedback`, so every control on a shared style gets it (main screen, compass, onboarding, failure
screens, sheets, debug tools). 5.13.3 doesn't depend on the search flow and can be built now.

**What Tessa wants (2026-10-15):** the pressed state shows on an ordinary **tap**, not only when the user presses
hard or holds. Today `PressFeedback` shows scale 0.96 and opacity 0.8 only while the finger is down, with a 0.15 s
spring, so a quick tap shows it for a frame or two. The ‹ › buttons already solve this (5.10c: held ≥ 90 ms).

- **Minimum visible time:** every control keeps its pressed look for at least **100 ms** after the finger goes down,
  even if it lifts sooner, then springs back. The action still fires on release, never delayed. Keep the animation
  scoped to the two pressed effects (the earlier chevron-jump bug).
- **Strength:** start at the existing 0.96 / 0.8 with the hold, then tune on the phone (0.95 / 0.75 is the first
  step). Reduce Motion: opacity only, still held ≥ 100 ms.
- **Close the gaps** (one shared style, applied everywhere): the search sheet's Cancel, Clear, Use my location and rows;
  the sentence tokens (44 pt targets); the debug panel and TestFlight tools.
  System controls stay system: the iOS prompt and **every nav-bar / toolbar button**, which includes the calendar
  sheet's Today, Cancel and Done (the system glass gives them their own pressed look and sizes them itself).
  *Correction, 2026-10-15:* an earlier version of this spec listed the calendar sheet's three buttons as gaps; on the
  phone the shared style truncated Today to "Tod…" and double-dimmed it. They go back to the system style and the
  drift test allowlists toolbar buttons.
- **Enforce it:** a test that fails when a `Button` in the app target has no shared style, so the rule can't drift.
- Not in this step: haptics.

## 5. Build order and checks

5.13.1 detour rule + "That's okay for now" (§1, §2) → 5.13.2 sheet content (§3) → 5.13.3 tap feedback (§4). One commit
each; the first includes the uncommitted doc changes. Debug build to the T2 iPhone after each. Phone checks: Don't
Allow → Got it → search → Cancel (back on "That's okay for now") → pick; upsell Search → Cancel (back on the upsell);
telescope Search → Cancel; the five cities with no recents; Use my location first with the pin, denied opens
Settings; tap every button type quickly and see the state.

## 6. Open / later

- "That's okay for now" keeps the dimmed moon for now; a sleeping cat there is part of the cat decision (5.14).
- "Got it" opening search relies on the body saying so; if testers expect it to just dismiss, rename to
  "Got it, search" (Tessa's call after friend testing).
- **After a pick with location still off (open, 2026-10-15):** the compass then shows S1 ("Turn On Location", "Maybe
  later") because `locationPromptDismissed` is set only by Maybe later. After Don't Allow → "That's okay for now" →
  search → pick, that is a third mention of location. Proposed: an explanation screen the user has already seen
  ("That's okay for now", the telescope and the other cause screens) counts as the one ask, so the compass starts on
  the quiet guide row (S2), tappable to reopen S1. S1 stays for people who haven't been asked.
- **Keyboard vs the suggested cities (open):** the sheet opens with the keyboard up (SEARCH-RECENTS.md §2), which can
  cover the five cities. Proposed: with no recents, don't auto-focus the field; tap it to type. With recents, as today.
