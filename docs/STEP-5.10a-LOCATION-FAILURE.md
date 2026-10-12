# Step 5.10a: Fail search location (prompt chunks for Claude Code)

> **Historical build plan, reconciled October 12, 2026:** `STEP-5.10a-LOCATION-CONSOLIDATION.md` and its 2b/2c amendments are implemented and supersede the original Try again flow, split launch-moon destinations, and acquisition Location Off dialog below. Current behavior uses one illustrated destination per cause, No fix retries once on foreground, not-determined Settings return goes to First ask, and the compact dialog remains compass-only. Chunks 1–6 below remain implementation history; existing art/layout/motion specifications remain in force.

> Owner: Tessa · Drafted 2026-10-09, updated 2026-10-10 · Design: canvas "Location Failure States": **Option D (revised)** layout + **"Error states with the calico illustrations"** (final art) + "Illustration motion reference".
> Read first: LOCATION.md §3–§4, LOADER.md §10 and §12, DESIGN-1.1.md §2 (tokens) and §3.1, and `design/1.6-location-error-illustrations/` (see "Handoff files" below). Behavior doesn't change unless this doc says so.
> Work in small chunks, one commit each, with a progress note after each.
> **Where this doc and the handoff's README.md disagree on the message screens, this doc wins** (README describes the earlier flow: the moon stays as the hero, "Search for a city instead"). The handoff's `ILLUSTRATIONS_MOTION.md` is the source of truth for motion numbers.

## Decisions (Tessa)
- Layout: **Option D**: no sentence, no card. Illustration, headline, body, buttons pinned to the bottom.
- **The calico illustration replaces the dimmed moon** on every failure screen (the moon is inside each illustration).
- Casting by cause: **No fix → calico "Huh?"** · **App permission off → telescope** · **Services off → map** · **Restricted → map with lock**. **Searching keeps today's loader**; the calico and the other illustrations appear on the failure screens only. (`searching.svg` is delivered but unused for now.)
- **"Search for a city instead"** is always the secondary action (except Restricted, where **Search for a city** is the primary).
- **No playful line for now.** Parked; revisit later (placement options are on the canvas, "Where the playful line lives").
- Illustration, headline and primary button sit at the **same height on every cause**.
- Motion: approved direction is "Playful beats" at 0.85× (already baked into the numbers in ILLUSTRATIONS_MOTION.md).

## Handoff files (already in the repo)
`design/1.6-location-error-illustrations/`: `assets/anim/` (`searching.svg`, `location-not-found.svg`, `permission-off.svg`, `services-off.svg`, `restricted.svg`: 400 × 520, transparent, layers named by `data-part`), `ILLUSTRATIONS_MOTION.md` (keyframes, pivots, durations), `Location Illustrations Motion.dc.html` + `support.js` (animated reference, open in a browser).
**Still fallback:** `design/d2-luminous-calico/stills/*.svg` and `D2Illustrations.xcassets` (already compiled with `actool`; image names `d2-searching`, `d2-location-not-found`, `d2-permission-off`, `d2-services-off`, `d2-restricted`). The `anim` SVGs are the source for the layered, animated version. Older `design/1.4-location-flow` and `1.5-loader-polish` are unchanged and not part of this step.

## Decisions from Chunk 2 (Tessa, 2026-10-10)
- **First ask is not a failure.** It has no `LocationFailure` case, art or copy in this step. It stays on the launch loader's stopped moon + message, sharing the same message-block code (`MessageText`, `MessageActions`, `MessageCopy`). Revisit later.
- **Shared view now, swap later.** `LocationFailureView` exists and shows through the DEBUG `-screenState locationFailed.*` states. The launch loader's four failure messages (denied, services off, restricted, no fix, no saved place) **keep the moon until Chunks 3 and 6** wire the swap and its transition, so Aha's flight from the moon stays intact and no half-built transition ships.
- Large-text layout rule changed (see Layout).

## Causes, copy, art and actions
Line breaks are fixed at default size (manual `\n`); fall back to natural wrapping at AX sizes. VoiceOver reads headline and body as one sentence each, without the breaks.

| Cause | Detect | Art | Headline | Body | Path chip | Primary | Secondary |
|---|---|---|---|---|---|---|---|
| App permission off | `denied` | `permission-off` (telescope) | Can't see / your location *(Chunk 2c)* | Allow location access to see / where the moon is from here. | Settings › Moon Signal › / Location *(Chunk 2b; was “… › Location › While Using the App”)* | Open Settings | Search for a city instead |
| Services off | `servicesOff` | `services-off` (map) | Location / Services are off | Turn them on to see where / the moon is from here. | Back to Settings › Privacy & Security › / Location Services *(Chunk 2c)* | Open Settings | Search for a city instead |
| No fix | timeout (10 s), CoreLocation error, offline / reverse-geocode failure | `location-not-found` (calico) | Couldn't find / your location | Check your cellular or Wi-Fi / connection. We’ll look again / when you come back. *(Chunk 2b; was “Check your signal and try again, or search for a city.”)* | none | none: room kept; looks again on return to the app (Chunk 2b; was Try again) | Search for a city instead |
| Restricted | `restricted` | `restricted` (map + lock) | Can't see / your location *(Chunk 2c)* | Location access is limited on / this iPhone. You can still / search for a city. | none | Search for a city | none (keep the 44 pt spacer so the primary doesn't move) |

## Layout (default size, 393 pt wide)
- Background `bg` with the top glow, as everywhere.
- Illustration: the 400 × 520 art shown **240 pt wide × 312 pt tall**, centred, **top at 90 pt** (the art has built-in margin; its visible content starts ~40 pt lower). The headline starts ~4 pt under the art frame (frame bottom at 402 pt). Don't crop or re-scale per cause; same frame everywhere so headline and buttons line up.
- Headline: Young Serif 28, line height ×1.22, centred, max width 300. Then 14 pt gap, body: Nunito Sans 17, ×1.45, centred, max width 290.
- Path chip (denied, services off only): 16 pt under the body; 1 pt `stroke` border, radius 14, padding 8 / 14, `surfaceRaised` fill, footnote-size `textSecondary`, centred, two lines as in the table.
- Bottom block: side margins 28, bottom padding 30. Primary: 56 pt capsule, `accent` fill, `onAccent` text, glow `accent` 25% radius 30. Under it, 6 pt gap, the text link: 44 pt tall, Nunito Sans 600 16, `accent`. Then an 18 pt spacer.
- Large text / small screens (updated 2026-10-10 after Chunk 2 shots): the message matters more than the art. At accessibility sizes the illustration drops to ~96 pt first (hidden at AX4+ if still needed), then copy scales to ~0.8×. Headline and body must be fully readable without scrolling on iPhone SE 3 at AX1–AX3; at AX5 only the message region may scroll, and the primary button stays visible. The art never takes space from the words.
- Hidden on this screen: the sentence, pinned compass bar, DEBUG readout, Show onboarding, the "a city" token.

---

## Chunk 1: Failure model (no UI)
> Claude Code prompt

Add a `LocationFailure` enum: `.permissionDenied`, `.servicesOff`, `.restricted`, `.noFix`. Map into it from `LocationAuthState` (denied, servicesOff, restricted) and from fetch errors (CoreLocation error, the 10 s timeout, offline or reverse-geocoding failure → `.noFix`, fast, no 10 s wait).

On `LocationViewModel` add `locationFailure: LocationFailure?`. Set it when a **user-started or launch search with no saved place** fails (Use my location from the search sheet, Try again, the permission flows, the launch fetch with no saved place). A **launch fetch with a saved place keeps today's behavior** (saved place + small location note). Don't change that.

On failure: cancel the timeout and the in-flight request, take the view model out of the loading stage cleanly (no stale skeleton state), flip the sentence's place token back to "a city" internally, and don't restore the previous place. Try again must start a fresh search without stacking requests.

Tests (fakes + fake clock): each auth state and error maps to the right case; timeout at 10 s → `.noFix`; failure cancels the request; Try again doesn't stack; saved-place launch doesn't set `locationFailure`.
Report back with the mapping table and any case that didn't fit.

## Chunk 2: Failure screen view (still art)
> Claude Code prompt

Build `LocationFailureView(failure:)` from the Layout and copy table above, using Theme tokens and fonts only (no new colors). Reuse the existing loader message block where possible; **don't build a second message screen**. If the launch message screens (LOADER.md §10.3) are close enough, make this the one shared view and say how you merged them.

Illustration: for now show the **still art only**, from `D2Illustrations.xcassets` (add it to the app target or copy its image sets into the app's asset catalog). Put a small `LocationIllustration(kind:)` view in front of the art so chunk 4 can swap the still for the animated version without touching the screen.

Actions: Open Settings → `UIApplication.openSettingsURLString`; Try again → restart the search; Search for a city instead → open the search sheet with the field focused; Search for a city (restricted) → same sheet. Put the path chips and all copy in one place, with the app name in the existing constant.

Accessibility: headline and body each read as one sentence; the illustration is decorative (hidden from VoiceOver); focus moves to the headline when the screen appears; every control ≥ 44 pt; Dynamic Type per §10.5.
Add DEBUG `-screenState locationFailed.<denied|servicesOff|noFix|restricted>` for screenshots. Shots at default, AX1, AX5, and iPhone SE 3 for each cause. Check that illustration frame, headline and primary button are at the same height across all four.

## Chunk 3: Wire it in
> Claude Code prompt

First ask stays on the loader moon (see Decisions from Chunk 2). If wiring the launch failures can't be done without touching the moon / Aha flight, stop and ask before choosing.

Show `LocationFailureView` in place of the main content whenever `locationFailure != nil`. Re-check permission when the app returns from Settings; if it's now authorized, clear the failure and fetch automatically, then continue into the existing recovery flow (loader → Aha → load-in). Entering a city clears the failure and goes through the §12 place-change flow (`loadInGeneration` bump, old place stays out). Don't touch the date controls or compass.

Tests: return from Settings with access granted → fetch starts once; Enter a city → failure cleared and place-change load-in plays; Open Settings only offered for denied and services off.

*As built (2026-10-10):* the failure screen replaces the main content only once the screen is up (`failureScreen`); a launch with no saved place keeps the loader moon's message (Decisions from Chunk 2). **Recovery (Tessa):** Try again and a return from Settings with access both run the existing loader → Aha → flight into the card; another miss brings the failure screen back. **Dialog (Tessa):** the main screen's Use my location no longer opens the Location Off dialog; the compass's Turn On Location and the launch loader's search row keep it.

## Chunk 4: Import the illustrations as layers
> Claude Code prompt

Read `design/1.6-location-error-illustrations/ILLUSTRATIONS_MOTION.md` and open the four failure SVGs in `assets/anim/` (skip `searching.svg`). Each file has a `<g data-part="...">` tree (top-level parts: `foreground`, plus `body`, `look` [head + paw], `tail`, `moon`, `moon-halo`, `moon-disc`, `tube`, `stand`, `map`, `route`, `lock`, `question`, `head`, depending on the state). Art sits inside `<g transform="translate(dx -130)">`, so keep that transform on every slice.

1. Write `scripts/slice_illustrations.py`. For each SVG, emit one SVG **per animated part** and one per static run between them, **preserving the original z-order**, each with the same root, `viewBox="0 0 400 520"`, and the shared `<defs>` (gradients). Strip the `<metadata>` / c2pa block. Output to a temp folder.
2. Import each slice into the asset catalog (`Illustrations.xcassets`, one folder per state, names like `locNotFound_head`). Set **Preserve Vector Data** and **Single Scale**, Render As **Original**. All slices share the 400 × 520 canvas, so stacking them with no offsets reproduces the full art.
3. If Xcode drops anything in the SVG import (gradients, the dashed `moon-ring`, strokes), **fall back per layer, in this order**: PDF (via `rsvg-convert` or Inkscape), then PNG at @3x. Say which layers needed the fallback. Don't redraw anything.
4. Build `LocationIllustration(kind:)` as a `ZStack` of the layers at 400 × 520 design size, scaled to the 240 × 312 frame. Put the pivot table from `ILLUSTRATIONS_MOTION.md` in one `IllustrationSpec` struct per state: pivot in viewBox coordinates, converted to `UnitPoint(x / 400, y / 520)` for `rotationEffect` / `scaleEffect`. Still render first (no motion). Screenshot all four at default size and compare against the canvas board "Error states with the calico illustrations".

Report back with which layers imported cleanly and which used a fallback.

*As built (2026-10-10):* `scripts/slice_illustrations.py` cut the four failure SVGs into 19 slices (each keeps the whole document, defs and transforms; only its own shapes), written into `Illustrations.xcassets` (`locNotFound/`, `permissionOff/`, `servicesOff/`, `restricted/`) as single-scale vector image sets rendered as Original. **All 19 imported cleanly as SVG; no PDF or PNG fallback** (gradients, the dashed ring and strokes all render). The anim SVGs' shapes are identical to the D2 stills', and the stacked layers match the old stills on screen to within 2/255 per pixel, so the D2 stills were removed from `Assets.xcassets`. `IllustrationSpec` holds each state's layers (with the parts each moves with: route and lock move with the map) and the pivot table.

## Chunk 5: Motion
> Claude Code prompt

Animate `LocationIllustration` per `ILLUSTRATIONS_MOTION.md`, "Playful beats" at 0.85× (**use its numbers as written; they are already scaled**). All keyframe durations, offsets, angles and pivots live in the per-state `IllustrationSpec`, nothing hard-coded in views.

- Drive parts with `TimelineView(.animation)` and one shared time value per illustration (seamless loops). Easing for every segment is `cubic-bezier(.42,0,.58,1)` unless the doc says otherwise.
- Moon breathing is shared by all states (halo scale/opacity, disc brightness, 5.88 s); the calico's not-found "empty moon" ring rotates linearly every 56.5 s.
- Parts you add yourself, with the numbers in the doc: signal rings (searching), the star sparkle (permission off), the travelling spark with waypoint glow (services off), the spark bounce and lock shake (restricted). The star path and spark formulas are in the doc.
- **Reduce Motion:** show the static frame (offset 0, spark hidden, question mark visible at scale 1). No loops, no timeline.
- Pause loops when the view is off-screen or the app is backgrounded (`scenePhase`).
- Nothing on this screen may animate after it is dismissed; check that the `TimelineView` stops (the acceptance list below).

Tests: spec values unit-tested (pivot conversion, keyframe sampling at a few offsets, spark smoothstep and bounce, lock shake decays to 0 by 1.06 s). Reduce Motion renders no `TimelineView`. Report with a short screen recording of each state if you can.

## Chunk 6: Loading → failure transition (reuse the existing location-screen sequence)
> Claude Code prompt

**Don't invent new timings.** The failure screen must transition in exactly like the other location message screens already built (LOADER.md §10.3 "Search → message", §2.1 / §11.2.7 `ContentLoadIn`). First find where those constants and the sequence live in the code (`LocationLoader`, `ContentLoadIn`, the message block) and reuse them. The only difference is that the illustration takes the moon's place.

Sequence (numbers are the existing ones; use the constants, not these literals):
1. **Search content out:** the searching loader (moon, glow, "Finding your location…" label) fades out in 0.3 s, after the existing minimum search time (≥ 1.2 s) so the app feels like it looked first.
2. **Illustration in:** the illustration for the cause crossfades in as the loader leaves, with the same fade + rise the message uses (opacity + short rise, same curve). It sits in its final frame; no flight, no scale.
3. **Text and buttons follow:** headline, body, (path chip), primary, secondary load in after the illustration, one after another with the existing `ContentLoadIn` stagger (150 ms), same per-block motion (opacity 0 → 1, 8 pt rise as an offset, 300 ms ease-out; layout never moves).
4. Failures that arrive instantly (denied, services off, restricted, with the loader never shown) skip step 1 and run steps 2–3 only.
5. **Return after a fix** (Try again, back from Settings): same rule as the other message screens, i.e. the failure content is removed immediately, then the loader resumes as today.
Reduce Motion: same order, opacity only, no rise. VoiceOver: announce the headline once the message is in, then focus the primary button.
Tests: step order and start times use the existing constants; text blocks start after the illustration; Reduce Motion drops the rise; instant failures skip the loader fade. Report where you reused each constant.

**From the Chunk 3 recordings (Tessa, 2026-10-10; `.agent-reports/5.10a-chunk3/recordings/`), owned by this chunk:**
1. A ~0.5 s flash of the main screen with an empty sentence (no city) and the placeholder card, between the search sheet closing and the failure screen appearing (recordings 01 and 05).
2. When the failure screen returns after a missed Try again, the loader moon fades out over the headline (~0.2 s, recording 04).
3. A fast failure flashes the loader: there's no 1.2 s minimum search time before the failure screen yet.
4. VoiceOver check: Restricted's hidden "Search for a city instead" (kept for its 44 pt room) must be skipped.

---

## Tests (overall)
- Each cause shows the right art, headline, body, chip and actions; line breaks match the table at default size.
- Illustration frame, headline top and primary button top are identical across the four causes.
- Failure cancels the in-flight request and timeout; no shimmer or skeleton left; the old place doesn't return.
- Try again restarts cleanly; return from Settings with access granted fetches automatically.

## Acceptance
- [ ] Each of the four causes matches the canvas "Error states with the calico illustrations" on an iPhone 17 and SE 3 at default, AX1 and AX5
- [ ] "Search for a city instead" works from every cause except Restricted, whose primary does the same
- [ ] No sentence, card shimmer or "a city" token visible on the failure screen
- [ ] Reduce Motion shows the still art, no loops
- [ ] Animation stops when leaving the screen or backgrounding; nothing animates endlessly once the screen is gone

## Decisions made on open questions (Tessa, 2026-10-10)
1. Illustrations on **failure screens only**; loading keeps today's loader.
2. Services off and Restricted both use the map: fine for now.
3. **Merge** the launch message screens (no saved place) into this one view.

## Still open
- Failure with a saved place on a user-started search (e.g. Use my location): show this screen, or reopen the saved place with the small note? This doc assumes this screen; LOADER.md §12.2 step 5 assumed the card-slot line.
- Exact built positions: the mocks approximate them (art top 90 pt, 240 × 312 frame). If the built screens differ, send a screenshot and the numbers get matched.
