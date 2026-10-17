# Step 5.14: the cat on the landing screen, and onboarding load-ins

_Tessa, 2026-10-15. Reconciled for the next agent run, 2026-10-16. Partly built: 5.14.1 landed the
landing/upsell load-ins and page fades, and 5.14.0 now integrates the landing searching cat. The
ready-to-look replacement is implemented; the declined-screen load-in remains. Search/cancel
design (5.13.1–.2) stays with Tessa; do not implement that flow here._

**Status, 2026-10-16: both cat animations and 5.14.2 are done in the current worktree** (see §5.6 and the
5.14.2 result below). The ready-to-look retune (§5.2) and landing retune (§5.3, final values from the §5.5 second
pass) were verified by Tessa on her phone. The declined screen now uses the same page exit, indexed load-in and
VoiceOver timing as the other app-owned onboarding screens.

## Current baseline and newer art

- Read `.agent-reports/5.14-handoff.md` first. 5.5a–d and 5.13.4 are closed; do not reopen them without a new issue.
- `OnboardingLandingScreen` and `OnboardingLocationScreen` already use indexed `ContentLoadIn` blocks.
  `OnboardingScreenChange` already supplies the 0.2 s exit and delayed VoiceOver announcement for those screens.
  The declined screen still swaps instantly and has no block load-in.
- Landing now uses the **searching cat**, as in §1. It uses the existing vector sources; its calm 1a tail sway is distinct
  from the 1f searching scan/flick/signal-ring animation. Do not add those story beats to the landing.
  **Superseded in part by §5 (2026-10-16):** the landing tail and head/paw motion are retuned there.
- Permission-off's telescope is to be replaced with **1k Ready to look**, per the newer handoff:
  `design/1.10-ready-to-look/ILLUSTRATIONS_MOTION.md` and its HTML reference. Reuse the existing permission-off
  destination; this is an illustration replacement, not a change to routing or First ask's moon.
- The ready-to-look animation handoff intentionally uses a vector moon and separate raster cat layers
  (`rtl-{body,tail,head,ear}.png`). The still SVGs under `design/d2-luminous-calico/telescope-cat/svg-export/`
  are vector traces with background and moon included, **not animation rigs**. Do not substitute them for the rig
  or describe the animated cat as all-vector. The landing's vector requirement remains specific to its searching art.
- `design/d2-luminous-calico/sleeping-still-handoff/` supplies a vector sleeping **composite**. It does not expose
  independently animated SwiftUI layers, and tail motion is explicitly deferred. The declined screen keeps its
  dimmed moon until Tessa confirms a sleeping-cat placement; asset availability alone is not that decision.

## 1. The cat on the landing screen

- **Art:** the awake searching cat with the moon disc halo behind it (D2 "searching", the 1a "Look-around" still),
  replacing the 150 pt moon glyph on the landing. Title, tagline and Get started stay.
- **Motion (Tessa):** the halo's slow pulse stays, and the **tail sways** (the motion study's tail sway, about ±3°).
  _Tail and head/paw motion below is superseded by §5.3 (built in §5.4 Run 2): a bending tail, ±13.8° over 4.05 s,
  and a gentle ±3° head/paw look over 9.30 s. The halo/disc breath and Reduce Motion rules here still apply._
  Both come from the illustration system, not new code: `haloBreath` (shared by the cat states) and the `tail`
  move. Today's landing halo is a static glow (`OnboardingMoon`, 18% accent blur); the pulse is the illustration's.
  Under Reduce Motion: still art, no sway, no pulse.
- **As built in 5.14.0:** `searching.svg` is sliced into full-canvas vector halo, disc, tail, body and combined
  head/paw layers. The shared illustration renderer runs `haloBreath`, disc breathing and, as first built, the calm 1a
  tail loop (0 → +4° → 0 → −3° → 0 over 4.2 s) with head/paw still. _Since Run 2 (§5.4), the tail and head/paw use
  §5.3's motion instead._ Motion starts after the art's 300 ms load-in lands.
  Reduce Motion, an inactive/background scene and disappearance select still art/no timeline.
- **Size and layout:** use the failure screens' art frame rules (240 × 312 at default, shrinking at large text,
  hidden at AX4+ like the cause screens). The landing's first impression should still fit above the button on SE 3.
- **Not changed:** the upsell's small moon (it stays the visual before the system prompt and the launch loader's
  phase-cycle moon). "That's okay for now" keeps its dimmed moon until Tessa decides on a sleeping cat there.

## 2. Load-ins for the four screens

Reuse `ContentLoadIn` as is: each block fades in and rises 8 pt, 300 ms ease-out, 150 ms stagger, Reduce Motion keeps
the fade and drops the rise. Give it a generic block index for onboarding rather than the main screen's blocks.

| Screen | Order (each 150 ms after the last) |
|---|---|
| 1 Landing | cat + halo, "Hello Luna", tagline, Get started |
| 2 Upsell | moon, title, body, Precise Location box, Use my location, Search for a city instead |
| 3 iOS prompt | not ours; the upsell stays as it is under the dim |
| 4 That's okay for now | moon, title, body, Got it, Enable location |

- **Between screens:** the outgoing page fades out in 0.2 s (the skeleton-exit value), then the incoming page loads in
  with its stagger. No slide or push. First launch of the landing loads in on appearance.
- **Cat entrance:** the cat and halo arrive first; the halo pulse and tail sway start as the cat lands.
- **The sheet** (§5.13) uses the system sheet motion.
- No haptic. VoiceOver: announce the new screen as today (`ScreenChanged`), after the stagger starts.

## 3. Checks

Default size on iPhone 17 and SE 3, large text, Reduce Motion, VoiceOver order, device recording of landing →
upsell → That's okay for now → search → pick.

## 4. Agent prompt and bounded runs

Use one implementation agent. Run one chunk per invocation; leave the app usable, report the result, then stop.
Preserve pre-existing uncommitted docs/art. No push, upload, phone install, dependencies or unrelated housekeeping.
Focused checks first, one full suite after those pass. Keep visual samples lean; stop for a checkpoint after two
unsuccessful fixes or about ten minutes of debugging. Update this spec, `docs/STATUS.md`, and the agent reports
with actual results; separate automated checks, simulator observation and outstanding phone checks.

### Next run — 5.14.0 searching art and landing cat

Agent prompt:

> Implement the remaining landing-cat work in `docs/STEP-5.14-ONBOARDING-CAT-AND-LOAD-IN.md` (§1 and the current baseline), using `.agent-reports/5.14-handoff.md` as the session handoff. Read the repo rules and inspect current onboarding/illustration code before editing. Preserve completed 5.14.1 load-ins, 5.5 accessibility behavior and 5.13.4 token feedback. Slice the existing D2 searching vector into full-canvas layers for halo, disc, tail, head/paw and body, preserving transforms, gradients, clipping and stack order; inspect the existing layered searching SVG before doing new art work. Keep vector representation and use the existing illustration motion/rendering system. Replace the landing's 150 pt moon with the searching cat and moon halo. Use only the calm 1a tail sway (about ±3°) and shared halo breath; no scan, signal rings or tail flick. Consult the 1a reference for its loop, keeping the head/paw still. Start idle motion as the cat's entrance lands, pause it off-screen/in background, and render still art under Reduce Motion while retaining ContentLoadIn's fade. Reuse the failure screens' responsive art sizing (240 × 312 at default, shrinking with large text, hidden at AX4+); adapt landing spacing so the first impression and Get started fit on SE 3 at default size while preserving the scrollable accessible layout. Keep title, tagline, button actions, upsell moon, launch loader, declined screen and search flow unchanged. Add focused coverage for new motion/timing or layout rules where meaningful, run relevant illustration/onboarding checks, then one full suite and a build. Inspect iPhone 17 and SE 3 at default size, one representative large-text size and AX4+; check Reduce Motion and document VoiceOver limits. Capture one short entrance/idle recording if possible. Report art sources, motion behavior, results and remaining checks; update status/reports and stop. No push/upload or phone install.

Acceptance: the landing uses clean vector cat layers without seams or cropping; its existing four-block entrance
survives; halo/tail idle begins as the entrance lands; Reduce Motion has no loops/rise; Get started stays reachable
at all text sizes and fits above the fold at default size on SE 3. No claims of physical-device verification from
simulator stills.

### 5.14.0 implementation result — 2026-10-16

- Implemented the five vector layers and shared-renderer motion above. Landing layout is 240 × 312 by default,
  160 × 208 at xxxLarge, 96 × 124.8 at AX1–AX3, and hidden at AX4+. The shared scrollable onboarding page remains,
  with landing top spacing reduced to 24 pt so the default SE layout has room for the primary action.
- Xcode file diagnostics are clean and the project build succeeds with no errors. Asset checks find no raster
  `<image>` nodes or retained metadata in the new slices.
- Automated test results are unavailable: Xcode's focused test action stalled twice without producing results;
  the first was stopped at the repo's ten-minute limit and the bounded retry was stopped after one minute. Per the
  checkpoint rule, no full-suite attempt followed. Xcode's preview action then failed before rendering with a
  cancelled preview build description.
- Still outstanding: iPhone 17 and SE 3 visual checks at default size, representative large text, AX4+, and Reduce
  Motion; VoiceOver order; entrance/idle recording; full suite. No simulator/device visual claim, phone install,
  upload or push was made.

### Subsequent run — ready-to-look permission-off replacement

Agent prompt:

> Implement only the 1k Ready-to-look replacement described in this spec's current baseline and `design/1.10-ready-to-look/ILLUSTRATIONS_MOTION.md`. Replace the existing permission-off telescope art in the shared illustrated cause presentation, so launch and explicit permission failures use the same new cat. Use the supplied layered animation art, preserve its raster cat layers at their native resolution and vector moon, and match the handoff's pivots, transforms, nested breath/head/ear motion, independent loop durations and stack order. Reuse the current IllustrationSpec/LocationIllustration system; extend it narrowly where the approved nested transforms require it. Do not use the still vector exports as an animation rig or change First ask/onboarding upsell/launch moon routing. Keep cause copy, actions, chips, recovery, search/cancel behavior and other causes intact. Respect responsive art sizing, decorative accessibility, off-screen/background pausing and a static offset-zero Reduce Motion pose. Run focused illustration and permission-failure regression checks, then one full suite and build. Compare a default-size still against the reference, inspect SE 3 and representative large text, and capture a short idle recording if possible. Report actual results, asset fidelity and remaining phone checks; update status/reports and stop. No push/upload or phone install.

### Ready-to-look implementation result — 2026-10-16

- Permission off (launch and explicit) now draws 1k: vector disc, then the supplied `rtl-*` rasters, byte-identical
  and at native 800 × 860, placed at the foreground rect (40.225, 131.48, 332 × 356.9). Stack: tail, body, head,
  ear; ear nested in head; breath wraps all. Pivots, keyframes and loops (4.47 / 8.82 / 6.24 / 4.94 s; disc 5.88 s)
  are as the handoff gives them. Reduce Motion, background and off-screen show offset 0.
- Tessa's addition: 1h's star and its 6.59 s loop are kept, re-placed at (370, 118) to clear the full disc, the head
  and the tube.
- System extensions: per-axis scale tracks, an optional raster `placement` on `Layer`, and inside-out composition of
  nested transforms (unchanged output for the existing art).
- **Halo is not shown**: the 1k source sets `display="none"` on it and the reference renders none, though the prose
  says "shared breathing". Awaiting Tessa.
- Build succeeds. Focused suites 210/210 pass; full suite 1528 cases, 1502 pass. The 26 failures are pre-existing
  and unrelated (25 `SentenceTokenTests`, 1 load-timing `PlaceChangeLayoutTests`). Simulator stills (iPhone 17
  default, launch and explicit; SE 3 default; xxxLarge) and a 16 s idle recording are in
  `.agent-reports/5.14-ready-to-look/`. Remaining: Reduce Motion, VoiceOver and light-mode checks, and phone review.

### Subsequent run — 5.14.2 declined-screen load-in

This run remains held while 5.13.1–.2 search/cancel design is unresolved. Do not treat this prompt as a decision
about Got it, sheet content, cancel destinations or sleeping-cat placement.

Agent prompt:

> Once Tessa has finalized the relevant 5.13 search/cancel flow, implement only the remaining declined-screen presentation in STEP-5.14 §2 against that finalized code. Reuse indexed ContentLoadIn for moon, title, body, primary action and secondary action in that order. Extend the existing OnboardingScreenChange handover to the declined screen: 0.2 s outgoing fade, incoming stagger, and ScreenChanged after the title starts. Preserve existing transition cancellation/reentrancy handling and avoid changing the view model's permission/search decisions. Retain the dimmed moon unless Tessa has explicitly approved sleeping-cat placement; if approved, the supplied sleeping composite stays still, with tail animation deferred. Keep the system permission prompt and sheet motion native. Verify deny/Settings return and the finalized search/cancel/pick paths, including fast repeated actions and Reduce Motion; run focused onboarding tests, then one full suite and build. Record a short continuous flow if available and state any physical-device VoiceOver/motion checks still needed. Update spec/status/reports and stop. No push/upload or phone install.

### 5.14.2 result — 2026-10-16 (current uncommitted worktree)

- The declined screen's dimmed moon, title, body, Got it and Enable location are indexed blocks 0–4. They use the
  established 300 ms ease-out fade/rise and 150 ms stagger; Reduce Motion keeps the fade and removes the 8 pt rise.
- `OnboardingScreenChange` now includes the declined step, so its incoming title starts at 150 ms and
  `ScreenChanged` follows then. The outgoing page uses the existing 0.2 s skeleton-exit fade.
- The app-root onboarding/main handover now trails the model by that same 0.2 s exit, so Search instead, Got it and
  Back no longer remove the outgoing screen immediately. Incoming onboarding/main content retains its existing
  block load-in rather than receiving a new whole-layout animation.
- The no-city actions use the indexed load-in on arrival and retain their scoped opacity transition when a city is
  selected. Start with city remains a normal city pick: it bumps the place-change load-in and never shows GPS Aha.
- Focused transition and location-recovery validation: 19/19 cases pass; build-for-testing succeeds. A broader
  three-suite run was cancelled when the simulator visual session took control of Xcode, so it was not counted as a
  result. iPhone 17 simulator review found the declined stagger, Got it → noCity, Back → upsell, Search instead →
  noCity and Start with city destinations correct and uncropped. Start with used the normal city-content load-in and
  no GPS/Aha. The specified sequential exit/entrance leaves a brief background-only beat; phone feel remains to be
  reviewed. Physical-device Reduce Motion and VoiceOver timing remain to be checked.

## 5. Motion retune: ready-to-look and landing cats (Tessa, 2026-10-16)

Tessa compared options in a side-by-side preview (real art, handoff pivots, shared easing) and tuned both cats. **These numbers replace the earlier tail, ear and head/paw numbers** for the two cats, including ILLUSTRATIONS_MOTION.md 1k and §1's "calm ±3° sway, head/paw still". Easing for every segment stays `cubic-bezier(.42, 0, .58, 1)`. Everything not listed here is unchanged: head, breath, moon disc and star on ready-to-look; halo breath, disc breath, load-in timing and "idle starts as the entrance lands" on the landing. Reduce Motion, off-screen/background pausing, responsive sizing and decorative accessibility are unchanged.

### 5.1 Bendable tail (shared mechanism)

The tail sways as a whole instead of pivoting rigidly from its base. Cut the tail art into **7 horizontal bands**, base (bottom) to tip (top). Each band is nested inside the one below it and rotates about its own joint, so the tail curls and the tip follows the base.

- **Joint angle:** `a_i(t) = tailTrack(t − lag × loop × i/6) × w_i`, for band `i` = 0 (base) … 6 (tip). `tailTrack` is the tuned keyframe track in degrees.
- **Weights:** `w_0 = (1 − flex) + flex/7`, `w_i = flex/7` for `i ≥ 1`. They sum to 1, so the tip's total swing equals the tuned amount at lag 0.
- `flex = 0` and `lag = 0` must reproduce today's rigid swing about the base pivot (test it).
- Keep band count, flex and lag as named constants in the illustration spec, not in views.
- Bands overlap their lower neighbour slightly so no seam opens; the base band extends below the art and the tip band above it.
- Check joints for seams at the tail's extreme poses, not only at rest.

| Cat | Art | Tail span (local y) | Base pivot (joint 0) | Joint x, bands 0–6 | Overlap | Space |
|---|---|---|---|---|---|---|
| Ready-to-look | raster `rtl-tail.png`, native resolution, clipped with rects, no resampling | 639 to 902 | (351.8, 932) | 338.4, 350.5, 365.0, 366.1, 356.4, 324.7, 311.1 | ~4 image px | the cat group's image space (images placed at 215, 250) |
| Landing | vector tail layer of `searching.svg`, stays vector (clip or mask the existing layer) | 402.2 to 588.0 | (132, 582) | 117.5, 110.9, 97.9, 96.9, 102.0, 105.2, 93.3 | ~1.5 units | the art space inside `translate(-15 -130)` |

Band height = span ÷ 7. Joint `i` (1…6) sits at `y = spanBottom − i × bandHeight`, at the x above; joint 0 uses the existing pivot. (The base pivot lies a little below the art bottom, hidden behind the body.)

### 5.2 Ready-to-look (permission-off) cat

- **Tail:** loop **2.25 s**; base swing 0 / +20 / 0 / −15 / 0° at offsets 0 / .25 / .5 / .75 / 1; **flex 0.95, lag 0.30**.
- **Ear:** loop **5.35 s**; 0 / 0 / −21 / +7 / −8.7 / 0 / 0° at offsets 0 / .55 / .60 / .65 / .70 / .76 / 1; pivot unchanged (163.5, 193). A quick, larger flick, then a settle.
- Head (8.82 s), breath (4.47 s), disc breath and the star keep their current values.

### 5.3 Onboarding landing (searching) cat

- **Tail (retuned 2026-10-16, second pass):** loop **1.40 s**; base swing 0 / +11.7 / 0 / −11.7 / 0° at offsets 0 / .25 / .5 / .75 / 1; **flex 1.00, lag 0.44**; per-segment ease-in-out as before. A quick, rippling whole-tail sway: the swing is shared evenly along the 7 bands and the tip trails the base by 44% of the loop. _Was loop 4.05 s, ±13.8°, flex 0.80, lag 0.15 (first pass)._ The joint-holds-rest-until-its-lag rule from Run 2 still applies (the loop starts at rest as the entrance lands).
- **Head and paw** (the combined look layer): loop **9.30 s**; 0 / −3.2 / −3.2 / 0 / +3.3 / +3.3 / 0° at offsets 0 / .14 / .36 / .50 / .64 / .86 / 1; pivot (237, 268) viewBox. A gentle look left and right ("look-around lite"). Still no scan, signal rings or tail flick.
- Replaces §1's "head/paw stay still" and "calm 1a tail sway (0 → +4° → 0 → −3° → 0 over 4.2 s)".

### 5.4 Agent prompts (one chunk per invocation)

Run ready-to-look first. If it lands the bendable tail, the landing run reuses it; otherwise the landing run builds it once.

**Run 1: ready-to-look retune**

> Read `CLAUDE.md`, `.agent-reports/5.14-handoff.md`, `.agent-reports/5.14-ready-to-look/findings.md` and `docs/STEP-5.14-ONBOARDING-CAT-AND-LOAD-IN.md` (§5.1 and §5.2). Implement only the ready-to-look tail and ear retune described there, using its numbers exactly: the new ear keyframes and the bendable tail (7 raster bands from `rtl-tail.png` at native resolution, per-joint rotation with weights and lag as written). Extend IllustrationSpec / IllustrationMotion narrowly; keep spec constants named; flex 0 / lag 0 must reproduce the old rigid swing (test it). Preserve the shipped rig otherwise: stack order, head, breath, disc, star, Reduce Motion offset-zero still (every joint identity), pausing, accessibility-hidden art, other causes, copy, routing and onboarding. Run focused illustration tests first (new keyframes, joint weights, lag shift, rigid case), then one full suite and a build. The 25 SentenceTokenTests failures and the PlaceChange timing case are known and pre-existing. Render stills at the tail's extremes (+20° and −15° at peak) and inspect joints for seams at default size and SE 3; fix overlap rather than hide any seam. Capture a short idle recording if possible. Report actual results, seams, frame cost if measurable and remaining phone checks; update spec, STATUS and reports, then stop. No push, upload or phone install.

**Run 1 result — 2026-10-16 (`a7d3941`, not pushed)**

- Ear and tail use §5.2's numbers exactly. The bendable tail is `IllustrationTailBend` (7 bands, weights and lag as
  in §5.1, constants named in `IllustrationSpec`), drawn as 7 clipped copies of the native `rtl-tail.png` raster.
  Joint 0 is the existing pivot, so the table's band-0 x (338.4) is unused. Flex 0 / lag 0 reproduces the rigid swing
  (tested), and the Reduce Motion still has every joint at identity (tested).
- Seams: the tail base is translucent where it fades into the body, so a plain overlap would double its alpha. Each
  band therefore clears its own rect before drawing, and clear and mask share one aliased fill, so there's no
  see-through line. No gaps at the extreme poses (base +20° / −15°, tip-sum max/min) at 3× or 2×. Residual: 23 px
  on one device row per joint, only on the antialiased outline, max 37/255; stopped after two fixes, flagged for the
  phone.
- Focused 86/86. Full suite 1543: 1514 pass. 25 are the known `SentenceTokenTests`; 4 others
  (`LocationScreenScrollingTests` ×3, `PlaceChangeLayoutTests` blank-ink ×1) pass when rerun alone, and are newly
  seen. Build succeeds. Frame cost not measured. Stills and a 12 s idle recording are in
  `.agent-reports/5.14-retune-rtl/`. Run 2 can reuse the bend.

**Run 2: landing retune**

> Read `CLAUDE.md`, `.agent-reports/5.14-handoff.md`, `.agent-reports/5.14.0-findings.md` and `docs/STEP-5.14-ONBOARDING-CAT-AND-LOAD-IN.md` (§1, §5.1 and §5.3). Implement only the landing cat's tail and head/paw retune described in §5.3, using its numbers exactly. Reuse the bendable tail from the ready-to-look run if it has landed; otherwise build it once per §5.1, keeping the tail vector (clip or mask the existing tail layer, no rasterizing). Update §1's superseded motion text to point at §5. Preserve the entrance and idle-starts-as-it-lands rule, halo and disc breath, Reduce Motion (still art, joints identity), pausing, responsive sizing (240 × 312 default, shrinking at large text, hidden at AX4+) and the rest of the landing, upsell, loader, declined screen and search flow. Run focused tests first (new keyframes, joint weights, lag, head/paw track), then one full suite and a build. Inspect extreme-pose stills for seams at default size, SE 3, one large-text size, AX4+ and Reduce Motion; confirm Get started still fits above the fold on SE 3. Capture a short entrance-and-idle recording if possible. Report actual results, seams, frame cost if measurable and remaining phone checks; update spec, STATUS and reports, then stop. No push, upload or phone install.

**Run 2 result — 2026-10-16 (`e9a96bf`, not pushed)**

- Tail and head/paw use §5.3's numbers exactly. The tail reuses Run 1's `IllustrationTailBend` with §5.1's landing
  geometry (constants named in `IllustrationSpec`): 7 bands of the existing vector `searching_tail` slice, each masked,
  never rasterized, overlap 1.5 art units. Joint 0 is the existing pivot (117, 452) viewBox = (132, 582) art space, so
  the table's band-0 x (117.5) is unused. The `searching_look` layer now moves as `.head` about (237, 268).
- One narrow change to the shared bend: a joint holds its rest pose until its lag has passed. The landing loop starts
  at t = 0 as the entrance lands, and without this the upper joints would sample the track before 0, so the tip would
  jump to about −5° on the first frame. This has no effect on 1k, which runs on absolute time (DECISIONS.md).
- Seams (`ImageRenderer`, 240 pt art, 3× and 2×): no gaps at base +13.8° / −13.8°, at tip-sum ±12.5°, or at the
  head/paw look extremes (neck and raised paw stay joined). The largest single upper-joint turn is 1.6°. In the still,
  banded vs unbent differs on 1074 channels at 3× (565 at 2×), max 19/255, on the outline only. Not visible at 100%.
- Focused 82/82. Full suite 1564: 1538 pass. The failures are the 25 known `SentenceTokenTests` and
  `PlaceChangeLayoutTests` blank-ink, which passes alone (also seen in Run 1). Build succeeds. Frame cost not measured.
- Simulator (in-app, `-forceOnboarding`): SE 3 default, Get started above the fold; iPhone 17 default; SE 3 xxxLarge
  (160 pt art); AX3 (96 pt); AX4 art hidden with Get started reachable. A 12 s entrance-and-idle recording is on
  iPhone 17. Reduce Motion was **not** observed in the simulator: setting it with `defaults` didn't reach the app
  (one try). The still pose is covered by tests. Files: `.agent-reports/5.14-retune-landing/`.
- Remaining: phone feel (calm on first launch), Reduce Motion and VoiceOver on device, and frame pacing.

Acceptance: the tail reads as one flexing piece with no visible seams at its extreme poses; the ear flick is clearly livelier but still a flick, not a twitch loop; the landing head/paw look is gentle (±3°) and the cat still reads as calm on first launch; Reduce Motion shows the still pose; no regression in the other four causes or the landing layout.

### 5.5 Run 3: landing tail second pass

Only the landing tail numbers change (§5.3). Head and paw keep 9.30 s / ±3.2°. The ready-to-look cat is not touched.

> Read `CLAUDE.md` and `docs/STEP-5.14-ONBOARDING-CAT-AND-LOAD-IN.md` (§5.1 and §5.3). Change only the landing cat's tail constants to the values now in §5.3: loop 1.40 s, base swing ±11.7° (0 / +11.7 / 0 / −11.7 / 0 at .25 steps), flex 1.00, lag 0.44. Keep the head/paw track, the ready-to-look cat, the start-at-rest rule, Reduce Motion, pausing and layout as they are. With flex 1.00 and lag 0.44, check the tail at its extreme poses for seams and gaps at default size and SE 3 (the largest single-joint turn changes), and check the first second of the loop starts at rest with no jump. Update the existing tests that assert the old tail constants and add a check that the tip trails the base by lag × loop. Run focused illustration and onboarding tests first, then one full suite and a build. Known pre-existing failures: 25 SentenceTokenTests and the PlaceChangeLayoutTests blank-ink case. Update spec §5 result, STATUS and reports, then stop. No push, upload or phone install.

**Run 3 result — 2026-10-16 (`1e9bc53`, not pushed)**

- Only the landing tail constants changed: loop 1.40 s, 0 / +11.7 / 0 / −11.7 / 0°, flex 1.00, lag 0.44. Head/paw
  (9.30 s), ready-to-look, the start-at-rest rule, Reduce Motion, pausing and layout are unchanged.
- **The net swing is smaller than ±11.7°.** With flex 1 every joint gets 1/7 of the swing (1.67°), and lag 0.44 spreads
  the joints over 44% of the loop (the tip is 0.616 s behind the base), so their turns partly cancel. In steady state
  the tip's total turn peaks at about **±5.7°**, and the most S-shaped pose has a 3.2° spread between joints. The tail
  reads as a quick ripple, not a wide sweep. This is §5.1's formula at these values, not a code limit; flagged for
  Tessa's phone check.
- Seams (`ImageRenderer`, 240 pt art, 3× and 2×): **no gaps** at base ±11.7°, tip-sum ±5.7°, the most S-curled pose
  or the largest single-joint turn (1.67°, about Run 2's 1.58°, inside the 1.5-unit overlap). The still residual is
  unchanged from Run 2 (max 19/255, outline only).
- First second: joint angles are all 0 at t = 0, and the t = 0 frame is pixel-identical to the still, so idle starts
  without a jump. The tip-sum moves at most 0.27° per 120 Hz frame. Stills at 0.1 s steps show a smooth ease-out.
- Focused 90/90 (including the new tip-trails-base and first-second checks). Full suite 1572: 1546 pass. The failures
  are the 25 known `SentenceTokenTests` and `LocationScreenScrollingTests.bottomIsReachable` (SE, AX1), which passes
  alone (8/8; also seen in Run 1). Build succeeds. No in-app recording this run. Files:
  `.agent-reports/5.14-retune-landing-2/`.
- Remaining: phone feel (is ±5.7° net enough; does 1.40 s still read as calm), Reduce Motion and VoiceOver on device.

### 5.6 Closeout — 2026-10-16 (documentation only)

- **Done:** ready-to-look retune (§5.2, Run 1, `a7d3941`) and landing retune (§5.3, Run 2 `e9a96bf`, and the §5.5
  second pass, Run 3 `1e9bc53`).
- **Landing tail final values:** the §5.5 second pass: 1.40 s, 0 / +11.7 / 0 / −11.7 / 0°, flex 1.00, lag 0.44. The
  first-pass values (4.05 s, ±13.8°, flex 0.80, lag 0.15) are superseded. Head/paw stays 9.30 s, −3.2 / +3.3°.
- **Verified on Tessa's phone, 2026-10-16:** tail and ear feel, the whole-tail bend, the landing look-around and frame
  pacing. That covers the motion-feel and frame-pacing checks listed as remaining in the Run 1–3 results.
- **Not re-checked on device:** Reduce Motion and VoiceOver. The Reduce Motion still pose is covered by tests (every
  joint at identity), and the art remains `accessibilityHidden`.
- **Remaining 5.14 work:** only the declined-screen load-in (§2, 5.14.2), held until Tessa finalizes the 5.13
  search/cancel design.

### 5.7 Sleeping-cat placement: decided (Tessa, 2026-10-16)

Leave it alone for now. "That's okay for now" (onboarding screen 4) **keeps its dimmed moon**. The sleeping cat stays where it is already used: the "Maybe later" location-allowance prompt on the main screen. Any other placement is a post-launch question. The 5.14.2 declined-screen load-in therefore keeps the dimmed moon, with no sleeping-cat variant to build.

## 6. Got it → moon entry, and a noCity that survives relaunch (Tessa, 2026-10-16)

### 6.1 What the recording showed

Source: Tessa's screen recording of 2026-10-16 20:06, frame-measured (30 fps luminance).

- **Got it → noCity takes about 0.95 s and reads as an error.** A hard cut to pure black (RGB 0,0,0) for 0.23 s, about 0.1 s of empty app background, then the noCity blocks load in over about 0.6 s.
- **Cause (code read, not yet profiled).** `moonbeam_appApp.swift` `handOverRootScreen` takes the whole root group to opacity 0 for `OnboardingScreenChange.exitDuration` (0.2 s) with nothing behind it but the window's black. The new `LocationScreen` then starts in `.waiting` (`Color.clear`) until `start()` has awaited `refreshAuthorizationState()`, then `settleOnNoCity()` and the staggered load-in. One thing is unexplained: a plain opacity fade would ramp down over several frames, but the clip jumps to black in one. Verify the mechanism when fixing it.
- **Relaunch after not allowing lands on different screens.** `OnboardingViewModel.shouldShow` needs no saved place, onboarding not completed, and permission `.notDetermined`. The completed flag is set only by Got it, Search instead and Allow, never by quitting on "That's okay". `isNoCity` is set only by `onboardingDidFinish` and is not stored. So: denied (completed or not) → the permission-off cat; not determined and not completed → onboarding from the landing screen; not determined and completed → first-ask; and **after Got it, a relaunch loses noCity** and shows the cat.

### 6.2 Decisions (Tessa)

1. **Got it enters the main screen through the moon, not a blank.** The small moon on "That's okay" grows to the loader's mid-screen moon, runs the same phase ride as the location search, then the noCity screen loads in with the usual transition. It is the Aha flight in reverse. The blank screen goes away entirely: it looks like an error.
2. **noCity persists across relaunch.** If the user chose Got it or Search instead (no city, no location), relaunching with no saved city and no location access lands on noCity, not the permission-off cat. Quitting on "That's okay" before Got it keeps today's behavior (denied → the cat).
3. **No root handover may ever show the window's black.** The app background sits behind every root fade, so Search instead and Back to upsell are fixed even though they don't get the moon.

Defaults Tessa hasn't settled (tunable, flag after the phone check):
- **The moon's end.** Tessa is unsure what the moon does at the end. Default: it fades out in place as the noCity blocks load in, the loader's normal exit (`LaunchStage.phaseCycleFadeOutDuration`). There is no card on noCity for it to land in.
- **No label.** The loader's "Finding your location…" does not show here, since nothing is being located.
- **Scope.** Got it only. Search instead keeps its current handover plus the background fix.
- **Length.** There is nothing real to wait for on this path, so the moon time is a deliberate beat. Starting values: text exit 0.2 s, flight 0.85 s (`LocationLoader.flightDuration`, `AhaFlight.curve`, reversed), hold 0.6 s after landing, exit fade 0.25 s, then the usual stagger. That is longer than today's 0.95 s on purpose. If it feels slow on the phone, shorten the hold first, then the flight.

### 6.3 Spec: the moon entry

Visible sequence on Got it:

1. The title, body and both buttons fade out over 0.2 s (the existing exit). The moon stays exactly where it is, same size and dimming.
2. The moon travels from its 64 pt position on "That's okay" to the loader moon's resting frame (140 pt, or 96 pt compact, per `LaunchPhaseCycle`), over the flight duration. Its dimming (0.6 → 1) and the loader glow come in during the flight.
3. On landing it runs the loader's phase ride for at least the hold. It starts from the phase the declined moon shows now; the agent checks the two match and flags any jump.
4. The loader exits with its normal fade while the noCity blocks load in, staggered as usual.
5. At no frame is the window black, and no frame is a bare background with nothing animating.

Rules:
- **Persist first.** `finish()` stores the outcome before any animation starts, so a quit mid-transition relaunches into noCity.
- **Backgrounding mid-transition.** The transition finishes on return; it does not restart.
- **Reduce Motion.** No flight. The text fades out, the moon cross-fades to the loader's resting frame, a shortened hold, then the normal exit. Opacity only, like the existing loader.
- **VoiceOver.** No "Finding your location" announcement. `ScreenChanged` posts on the noCity screen as it does today.
- **Reuse.** Reuse `AhaFlight`, `LocationLoader` and `LaunchPhaseCycle`'s moon. Do not add a second moon implementation or a parallel loader.

### 6.4 Persisted noCity

- Store the outcome in the onboarding store (protocol, `UserDefaultsOnboardingStore`, `InMemoryOnboardingStore`) when `finish()` runs for Got it or Search instead on a non-forced run.
- **At launch**, if the flag is set, there is no saved place, and permission is not authorized: `start()` enters noCity (`isNoCity = true`) and settles on it, with no loader.
- **Authorized:** clear the flag and launch normally (locate).
- **Cleared when** a city is picked or saved (where `isNoCity` already goes false) and when permission becomes authorized.
- `restricted` and `servicesOff` use the existing noCity CTA rules. Debug replay keeps its current rules and never persists.
- `OnboardingViewModel.shouldShow` does not change.

### 6.5 Agent prompts (two runs, in order)

**Run 1: persisted noCity and the root background.**

```
You are the implementation agent for Moonbeam. Work in the existing Xcode project.

Read STEP-5.14 §6 (docs/STEP-5.14-ONBOARDING-CAT-AND-LOAD-IN.md) and docs/ONBOARDING-MOD-MAIN.md. Do 6.4 and the root background of 6.2 item 3 only. Do not start the moon entry (Run 2).

1. Persisted noCity per §6.4. The onboarding store protocol, UserDefaultsOnboardingStore and InMemoryOnboardingStore get the stored outcome. OnboardingViewModel.finish() records it for Got it and Search instead on a non-forced run, before onFinish and before isPresented flips. LocationViewModel.start() enters noCity for a persisted flag with no saved place and no authorization, and clears it when authorized, when a city is picked or saved, and when permission becomes authorized.
2. Root background. In moonbeam_appApp.swift mainContent, put ScreenBackground() behind the root group, outside the opacity, so handOverRootScreen's fade never reveals the window's black. Check for any other whole-screen opacity 0 swap that can show the window and fix those the same way.

Tests: store round trip; Got it and Search instead persist, Allow and forced runs do not; start() routing for flag set + no place + denied → noCity, + authorized → normal launch and flag cleared, + saved place → normal, pick clears it; quit-on-That's-okay (no Got it) leaves the cat path unchanged. Adjust tests that assert the old behavior.

Match existing patterns and tokens, add no dependencies, smallest change. Run focused suites with build-for-testing then test-without-building; one full suite after they pass (25 known SentenceTokenTests failures expected on the command line). Do not commit, push or install. Do not touch DECISIONS.md. Append one line per milestone to .agent-reports/progress.log.

Report: files changed, anything you interpreted, the exact test command, and what Tessa should check on the phone: relaunch after Got it lands on noCity; relaunch after quitting on "That's okay" still shows the cat; no pure-black frame in Search instead or Back to upsell.
```

**Run 2: the moon entry** (after Run 1 is checked on the phone).

```
You are the implementation agent for Moonbeam. Work in the existing Xcode project.

Read STEP-5.14 §6.2 and §6.3 (docs/STEP-5.14-ONBOARDING-CAT-AND-LOAD-IN.md). Build the Got it moon entry exactly as §6.3 describes, reusing AhaFlight, LocationLoader and LaunchPhaseCycle's moon; reversed Aha flight from the declined screen's OnboardingMoon frame to the loader's resting frame. Get the declined moon's global frame from the onboarding screen to the root and into LocationScreen's loader; the incoming loader starts at that frame. All durations are named constants in one place (text exit, flight, hold, exit fade), starting at the §6.2 values.

Persistence is already done in Run 1; keep it. Only Got it gets the moon. Search instead and Back to upsell keep their handovers. Check that the declined moon's phase matches the loader's starting phase and flag any jump.

Tests: the sequence's stage order and the minimum hold; Reduce Motion path (no flight); quit or background mid-transition still ends in noCity; no loader label on this path. Then record the simulator on iPhone 17 and SE 3 at default, AX3 and Reduce Motion, and extract frames across Got it: confirm no frame is pure black and none is a bare background with nothing moving. Report the frame check.

Smallest change, no new dependencies, match existing patterns. Focused suites first (build-for-testing then test-without-building), one full suite after. Do not commit, push or install. Do not touch DECISIONS.md. Append one line per milestone to .agent-reports/progress.log. Checkpoint after two unsuccessful fixes or about ten minutes of debugging.

Report: files changed, anything you interpreted, the exact test command, the frame-check result, and what Tessa should check on the phone: the moon's size, position and dimming continuity at Got it, the hold's feel, and the end of the moon.
```
