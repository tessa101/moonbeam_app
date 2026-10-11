# Step 5.10a follow-up: consolidate location guidance and failure flows

> Agreed with Tessa, October 10, 2026. Implementation plan after the original failure work's Chunk 6.
> **Approved scope. Chunks 1–2 implemented (October 10, 2026); Chunk 3 pending.** This document supersedes earlier instructions to keep the four launch failure causes on the loader moon and to keep the Location Off dialog for acquisition from the launch search row. First ask still uses its existing moon presentation.
> Read `LOCATION-STATE-INVENTORY.md`, `STEP-5.10a-LOCATION-FAILURE.md`, and `LOADER.md` §10–12. Existing illustration/layout/motion specifications remain authoritative.

## 1. Product model

Three moments have different meanings:

| Family | Meaning | Presentation |
|---|---|---|
| Invitation | We have not asked for access yet | Existing onboarding or First ask: benefit explanation, Use my location, city alternative |
| Access guidance | We know why location cannot be used | Permission off, Services off, or restricted: cause-specific illustration, explanation and next action |
| Attempt failed | We attempted to locate but could not obtain a usable city | Calico, Couldn't find your location, city search; looks again on return (Chunk 2b; was Try again) |

Guidance and attempt failure share the existing illustrated layout and entrance system. They do not need a new screen between the explanation and the action. Access off is guidance, not evidence that a search ran. `LocationFailure` can keep its current technical name and cases; this distinction does not require a model rename or new enum.

## 2. Approved destination screens

Use **one cause-specific presentation regardless of entry point**: launch without a saved city, main Use my location, Use my location from the city-search sheet, failed retry, or a changed authorization state on return from Settings.

| Cause | Illustration | Headline | Body | Primary / secondary | Settings chip |
|---|---|---|---|---|---|
| Permission off | Existing telescope | Can’t see your location *(Chunk 2c)* | Allow location access to see where the moon is from here. | Open Settings / Search for a city instead | Settings › Moon Signal › Location *(Chunk 2b)* |
| Services off | Existing map | Location Services are off | Turn them on to see where the moon is from here. | Open Settings / Search for a city instead | Settings › Privacy & Security › Location Services |
| Restricted | Existing locked map | Can’t see your location *(Chunk 2c)* | Location access is limited on this iPhone. You can still search for a city. | Search for a city / none | None |
| No fix | Existing calico | Couldn’t find your location | Check your cellular or Wi-Fi connection. We’ll look again when you come back. *(Chunk 2b)* | none (room kept) / Search for a city instead *(Chunk 2b; was Try again)* | None |

Use `AppInfo.name`, existing fixed line breaks/default sizing and accessibility wrapping. Preserve distinct cause art. Keep timeout, location-service errors and city-naming/reverse-geocoding errors grouped as No fix. Keep Restricted's reserved secondary space without exposing an actionable secondary button.

One source supplies cause copy, art, path and actions. First ask's copy stays independent. Reuse `LocationFailureView`, `MessageText`, `MessageActions`, `FailureLoadIn` and existing illustrations; do not build another full-screen view or import new art. Invitation and onboarding copy/layout changes are outside this pass.

## 3. Entry and recovery contract

| Trigger | Required journey |
|---|---|
| Launch, no saved city, known denied/services-off/restricted | Neutral background → illustrated guidance directly; no deliberate searching cycle or minimum-search wait |
| Launch, no saved city, authorized attempt fails | Existing launch searching moon when applicable → illustrated No fix; preserve searching minimum before failure |
| Main/search Use my location, known access blocked | Remove old screen / dismiss search → matching illustrated guidance directly; no Location Off dialog |
| Use my location when not determined | Permission prompt on user tap; allow → searching; deny → illustrated permission guidance. Unanswered prompt is not No fix |
| ~~Try again from No fix~~ No fix looks again on return (Chunk 2b, row 10) | Remove failed content immediately → existing searching moon → Aha/flight/main on success, same illustrated failure on another miss |
| Settings return, newly authorized | Remove guidance immediately → one automatic location request → existing searching/Aha/flight/main on success, illustrated cause on failure. No intermediate Try again screen |
| Settings return, unchanged blocked state | Keep current guidance; no request |
| Settings return, different blocked cause | Switch to the corresponding shared guidance |
| Settings return, not determined | **Superseded by Chunk 2b item 2:** First ask (stopped moon; Use my location shows iOS's prompt on tap), at launch and after explicit requests; no automatic prompt. *(Was: keep the illustrated guidance.)* |
| No fix foreground, access still authorized | **Superseded by Chunk 2b item 1:** one automatic search per activation (background or inactive → active, Control Center included), none while one runs; same loader → Aha or No fix path. *(Was: wait for Try again.)* |
| First ask primary | Existing user-triggered prompt; allow → existing recovery, deny → shared illustrated permission guidance |
| Enter a city / Restricted's Search for a city | Focused search sheet; cancel returns to origin; pick clears cause and uses existing city load-in, not GPS Aha |

Timing depends on whether a search actually ran, not on the entry point. Reuse `LocationLoader.minimumSearchBeforeMessage`, `ContentLoadIn` and the Chunk 6 entrance constants. A fast attempted failure must still feel like an attempt; known blocked states need no searching theater. Preserve ordinary successful launch's fast-path grace period and existing success load-in.

All explicit acquisition routes, including search opened from First ask or illustrated guidance, converge on this contract. Changing routing must not lose Settings recovery or allow a late location result to override a picked city.

## 4. Boundaries

- **Onboarding remains separate and its behavior is preserved.** Do not change “That’s okay,” Got it, Enable location, invitation text, or its city alternative in this pass. After onboarding exits, the standard no-saved-city destination follows the shared guidance rules. A possible acknowledgment → city search ending is a separate product decision.
- **First ask remains an invitation**, with the stopped moon and existing actions. It is not a fifth failure cause.
- **Saved-city launch fallback remains usable city data**, with existing compass guidance/hidden state. No full-screen cause screen merely because automatic detection failed.
- **Explicit acquisition failure does not restore the previous city.**
- **Compass-only requests remain detection-only.** Keep the compact dialog and preserve the selected city. Reuse cause explanation/Settings instructions where practical; no full-screen acquisition failure or GPS Aha for this path. Do not redesign the dialog in this pass.
- **City-search error/no-results states remain inside search**, with existing copy. They are not No fix.
- Preserve illustration motion, Reduce Motion, background/dismissal lifecycle, card/date/compass behavior and existing accessibility layouts. No timing redesign, new dependency, persistence change, or unrelated cleanup.

## 5. Work division for the agent

Run sequentially, **one chunk per invocation and one commit per chunk**. Each chunk must leave the app usable, update `STATUS.md` and `.agent-reports/latest.md`, append progress to `.agent-reports/progress.log`, then stop and report. Do not push or upload. Report actual test/build results and distinguish automated coverage, sampled screenshots and continuous/device observation.

### Consolidation Chunk 1 — one source for cause presentation

Agent prompt:

> Implement Consolidation Chunk 1 from `docs/STEP-5.10a-LOCATION-CONSOLIDATION.md`. Read the contract and boundaries first. Make the four illustrated causes' copy, art, paths and action definitions the single source of truth. Remove duplicated cause strings in the launch-message definitions by delegating to the shared cause definition. Keep First ask independent. Preserve current routing and visuals in this chunk: legacy launch messages may still omit path chips until Chunk 2. Reuse existing types; avoid renaming the state model. Align the compact compass dialog's cause explanations and Settings instructions with the shared source where practical, preserving its existing actions, presentation and detection-only behavior. Build and run focused copy/action/dialog tests. Report which values are now shared and any remaining duplication. Commit, update reports/status, and stop. No push/upload.

Acceptance: four causes cannot drift in wording/actions; First ask unchanged; existing destinations still work. Any temporary omission of launch chips is explicit and removed in Chunk 2.

### Consolidation Chunk 2 — unified destinations and functioning recovery

Agent prompt:

> Implement Consolidation Chunk 2 from `docs/STEP-5.10a-LOCATION-CONSOLIDATION.md`. Route launch without a saved city and all explicit acquisition failures to the existing illustrated cause screen. Remove the stopped-moon cause destinations and the acquisition-only Location Off dialog branch; retain the moon for First ask and searching, and the compact dialog for compass-only requests. Implement the full entry/recovery contract in §3 in this chunk so no newly unified screen has broken actions. Reuse Chunk 6 transition sequencing and constants: known blocked states skip searching; attempted failures respect the existing minimum, with clean loader-to-illustration handoff. Preserve successful ordinary launch, loader/Aha recovery, Settings auto-fetch, city search/cancel/pick, saved-city fallback, and onboarding internals. Keep existing DEBUG route names but make messageDenied/messageServicesOff/messageRestricted/messageNoFix exercise the new launch destinations; preserve messageFirstAsk. Build and run focused launch, failure, recovery, search and compass regression suites. Record representative entrance/recovery evidence if available; state capture limits. Commit, update reports/status, and stop. No push/upload.

Acceptance: both contexts settle on identical cause presentation including chips; every visible action works; retry and Settings recovery return to the same shared destination after another miss. No ready-screen placeholder flash, duplicate prompt, stuck skeleton or lost city pick. Invitation remains distinct.

### Consolidation Chunk 3 — regression matrix, visual review and final handoff

Agent prompt:

> Implement Consolidation Chunk 3 from `docs/STEP-5.10a-LOCATION-CONSOLIDATION.md`. Verify the matrix below using deterministic services/clocks and relevant existing tests, adding missing behavioral coverage rather than duplicating implementation. Fix consolidation regressions within scope. Build and run the full suite once focused checks pass. Compare paired launch/explicit cause screens at default sizing, and preserve/check existing large-text and Reduce Motion behavior. Capture continuous entrances/recovery if possible; sampled stills do not prove smoothness. Update the inventory to distinguish the newly built behavior from its historical baseline, mark this plan's implemented chunks, and reconcile superseded loader/failure documentation. List remaining physical-device or deferred accessibility checks explicitly. Commit, update reports/status, and stop for review. No push/upload.

Verification matrix:

| Area | Required cases |
|---|---|
| Cause destinations | Each of four causes at launch without saved city and after main/search explicit request; same copy/art/actions/chips |
| Cause detection | Timeout, immediate location error, reverse-geocoding failure, permission withdrawn mid-request |
| Invitations | First ask allow/deny/unanswered; onboarding allow/deny/city alternative remain usable |
| Retry | Success, second failure, fast failure, repeated tap; one request; minimum searching before failure |
| Settings | Unchanged, changed blocked cause, newly granted, not determined, repeated foreground; access granted starts once |
| City search | Open/cancel/pick from every cause; restricted row hidden; recent pick offline; search/resolve errors stay in sheet |
| Concurrency | Pick city while location pending; late result cannot overwrite it; foreground cannot cancel explicit request |
| Saved data / compass | Saved-city launch with off/failing location; compass-only enable and Settings return preserve city; quiet detection failure stays quiet |
| Motion / layout | No old city/card flash or loader/headline overlap; correct stagger; paired settled positions; light/dark; Reduce Motion; background/dismissed illustration stops |

Default-size iPhone 17 is the main flow-review target; check SE 3/large text for regressions against existing behavior. Additional accessibility redesign remains deferred. Record existing SE 3 AX2/AX3 scrolling and Restricted's accessibility-visible reserved secondary control separately from new regressions. Do not silently declare these resolved.

## 6. Separate follow-ups

- Decide whether onboarding's decline acknowledgment should proceed directly to focused city search.
- ~~Decide whether return from Settings as not determined should lead to First ask instead of retaining guidance.~~ Decided in Chunk 2b: First ask.
- Review full accessibility behavior and small-screen layout issues already recorded.
- Review continuous motion and real Settings routes on a physical device; DEBUG background-grants-access fixtures do not verify system navigation.
- *(Chunk 2b)* **Searching cat in the launch flow.** Show the searching cat while locating; the moon still flies into the card on success, and the cat exits some way (wave goodbye, poof away, scamper off). To be explored later. `searching.svg` is delivered but unused.
- *(Chunk 2b)* **Offline continuation.** If a fix succeeds but the city can't be named, continue with the coordinates labeled "Your location" (the moon times are computed on the device).
- *(Chunk 2b)* A connectivity monitor that retries the moment a signal returns, without leaving the app.
- *(Chunk 2c)* First ask: a character or illustration to invite allowing location (design TBD; the searching cat is one candidate).
- *(Chunk 2c)* Retry No fix the moment connectivity returns, without leaving the app (the Chunk 2c monitor makes this cheap; not in that pass).
- *(Chunk 2c)* Restricted offline: its body mentions searching while no action shows.

No additional approval is required for the implementation scope above. Separate follow-ups do not block these chunks; preserve their current behavior and report them.
