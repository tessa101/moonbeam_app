# App Store prep: what's left, in order

_Drafted 2026-10-15 after TestFlight 0.1 (10). Assumes the **recommended cut line (Option A)**: ship 1.0 after the
accessibility pass; polish waits for 1.1. Tessa hasn't confirmed A, so the "decide" items below are open. STATUS.md
is still the source of truth; this is the checklist view._

## Cut line (proposed)

**In for 1.0:** the search / cancel flow and 5.13 (**MVP blocker, Tessa 2026-10-15; the flow's open questions must be decided before 5.13.1 runs**) · 5.14 onboarding cat and load-ins · ready-to-look cat replacing the telescope (5.14) · 5.5 AX reflow with device QA · housekeeping and
warning fixes · cleanup of TestFlight-only tools · store assets and submission settings.
**Out, 1.1 or later:** Voice A (always-on answer line) · light mode · Round 2 leftovers (calendar sheet look, relative
day chips) · app-wide motion pass · Daily Moon Report widget / push · weather · sun/tide sister apps.

## Launch blocker: the search cancel flow (Tessa, 2026-10-15)

The cancel-search flow **must be right for the MVP**. The flow is still being worked out (separate chat). Until it is
decided, **hold 5.13.1 and 5.13.2** and the load-in part of 5.14. The open questions are in
`STEP-5.13-ONBOARDING-DECLINE-SEARCH.md` §6 (the compass after a pick with location off; keyboard vs the suggested
cities) plus whatever the new flow changes.

**The agent can start now, in this order:** housekeeping (item 5) → 5.13.3 tap feedback → 5.5 AX reflow (5.5a to
5.5d) → 5.14.0 slice the searching cat art. None of these depends on the search flow.

## Order of work

1. [ ] **MVP blocker: finish deciding the search / cancel flow (STEP-5.13 §1, §6), then 5.13.1 → .2 → .3** search detour, "That's okay for now", sheet content, tap feedback
   (`STEP-5.13-ONBOARDING-DECLINE-SEARCH.md`). Agent runs.
2. [ ] **TestFlight 0.1 (11)** with 5.13 → friends test (Tessa). Watch list: tap areas on the sentence tokens (about
   23 pt high, overlapping), where people hesitate at "That's okay for now", whether anyone sees the telescope twice.
3. [ ] **5.14** cat on the landing + onboarding load-ins (`STEP-5.14-ONBOARDING-CAT-AND-LOAD-IN.md`). Needs
   `d2-searching` sliced into layers first. Agent runs.
4. [ ] **Telescope → ready-to-look cat** (decided 2026-10-16): the redraw task is dropped; the permission-off art is
   replaced by the 1k Ready-to-look cat (5.14 subsequent run). `STEP-5.10a-TELESCOPE-REDRAW.md` is superseded.
5. [ ] **Housekeeping (agent, small):**
   - Fix the Sendable warning at `LocationScreen.swift:348` (`contentSpace`, likely `nonisolated`).
   - `MoonTableSpike.run()` runs at every launch in Release and prints (`moonbeam_appApp.swift:30`): gate it under
     `#if DEBUG` or delete the spike and its references.
   - Re-run the full suite and a Release build; compare warnings with build 10.
6. [ ] **5.5 AX reflow (agent, four small runs):** three-column card on today, SE 3 connector, pinned bar vs readout
   overlap, large-text layouts. Direction already agreed (`DESIGN-1.1.md` §4, DECISIONS 2026-10-12). Then Tessa's
   device QA at default / AX1 / AX5, VoiceOver order at AX2, the 5.8 arc after midnight.
7. [ ] **Fresh-install checks (Tessa):** onboarding end to end, real Restricted (Screen Time), SE-size phone.
8. [ ] **Remove TestFlight-only tools (agent, last, in the submission build only):** Show onboarding, Forget saved
   place, `BuildChannel`, the debug panel; replace `appStoreReceiptURL`. Keep them in builds friends test.
9. [ ] **Version:** go to 1.0 for submission (0.1 only ever existed in TestFlight). Don't edit a signed archive.
10. [ ] **App Store Connect (Tessa):**
    - Screenshots for the required iPhone sizes, description, keywords, promotional text
    - Privacy policy URL and support URL
    - App Privacy labels: location is used on device, nothing collected (confirm against the privacy manifest)
    - Age rating questionnaire; category
    - Review notes: why location is used, how to test with it denied, that a city can be searched instead
    - Export compliance (already `ITSAppUsesNonExemptEncryption` false)
    - App name availability for "Hello Luna"; display name vs repo name `moonbeam`
11. [ ] **USNO reference rows** (Reykjavík, Sydney, Mar Vista no-rise): fill in from the Mac. Not blocking.

## Decisions still open (Tessa)

- Confirm cut line A (or B/C).
- Telescope: decided 2026-10-16, replaced by the ready-to-look cat.
- ~~Search cancel flow (MVP blocker)~~: decided 2026-10-16 and built; see the status refresh below.
- Final name and primary persona (DESIGN-REVIEW "Brand").

## Status refresh (2026-10-17)

Done since this doc was drafted: 5.5 AX reflow, 5.13.2/5.13.3/5.13.4, ready-to-look cat (telescope replaced), 5.14 cat motion, persisted noCity, Got it moon entry (Run 2, committed 18f7e6c), root handover moved into RootScreen. Full suite via `xcodebuild`: only the 25 known SentenceTokenTests failures plus the PlaceChangeLayoutTests blank-ink flake (passes alone).

Still open, in order:
1. ~~Search/cancel flow decision~~ **Done:** decided 2026-10-16 (ONBOARDING-MOD-MAIN.md) and built (noCity state, search sheet, persisted noCity, Got it moon entry). Still to confirm on the phone: search sheet Cancel and pick from each onboarding screen and from noCity. The "on hold" notes in STATUS.md and STEP-5.13 header are stale.
2. Housekeeping: gate `MoonTableSpike.run()` under `#if DEBUG` (moonbeam_appApp.swift); Sendable warning at LocationScreen.swift:348; Release build, compare warnings with build 10.
3. **Release-build check (TestFlight 0.1 (11), launched from the icon):** first Got it → noCity transition, first cat-tail landing, and the searching cat. Debug/Xcode-attached first runs stall (about 1.8 s frozen moon on the first Got it); launched from the home screen it is smooth. If it still stutters in Release, write the warm-up prompt (pre-render the noCity headline and loader moon during "That's okay").
4. On-device persistence check: delete app, both scheme arguments off, Don't Allow → That's okay → Got it, quit, relaunch from the icon, expect noCity.
5. Reduce Motion on the phone (Got it should cross-fade, not fly). SE 3 at AX3: declined moon starts off-screen when scrolled (about 67 ms still); decide A top-edge start / B scroll to top / C leave.
6. Fresh-install checks, TestFlight-only tool removal, version 1.0, App Store Connect, USNO rows: as listed above.
