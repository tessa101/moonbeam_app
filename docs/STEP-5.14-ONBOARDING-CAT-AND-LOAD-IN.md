# Step 5.14: the cat on the landing screen, and onboarding load-ins

_Tessa, 2026-10-15. Reconciled for the next agent run, 2026-10-16. Partly built: 5.14.1 landed the
landing/upsell load-ins and page fades, and 5.14.0 now integrates the landing searching cat. The
ready-to-look replacement is implemented (tests pending); the declined-screen load-in remains. Search/cancel
design (5.13.1–.2) stays with Tessa; do not implement that flow here._

## Current baseline and newer art

- Read `.agent-reports/5.14-handoff.md` first. 5.5a–d and 5.13.4 are closed; do not reopen them without a new issue.
- `OnboardingLandingScreen` and `OnboardingLocationScreen` already use indexed `ContentLoadIn` blocks.
  `OnboardingScreenChange` already supplies the 0.2 s exit and delayed VoiceOver announcement for those screens.
  The declined screen still swaps instantly and has no block load-in.
- Landing now uses the **searching cat**, as in §1. It uses the existing vector sources; its calm 1a tail sway is distinct
  from the 1f searching scan/flick/signal-ring animation. Do not add those story beats to the landing.
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
  Both come from the illustration system, not new code: `haloBreath` (shared by the cat states) and the `tail`
  move. Today's landing halo is a static glow (`OnboardingMoon`, 18% accent blur); the pulse is the illustration's.
  Under Reduce Motion: still art, no sway, no pulse.
- **As built in 5.14.0:** `searching.svg` is sliced into full-canvas vector halo, disc, tail, body and combined
  head/paw layers. The shared illustration renderer runs `haloBreath`, disc breathing and the calm 1a tail loop
  (0 → +4° → 0 → −3° → 0 over 4.2 s); head/paw stay still. Motion starts after the art's 300 ms load-in lands.
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
| 1 Landing | cat + halo, "Moon Signal", tagline, Get started |
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
- Test build succeeds. **Tests not run**: `test-without-building` hits `Pseudo Terminal Setup Error` in the agent
  environment, and the Xcode action fails on signing (phone destination). Simulator stills (iPhone 17 default, launch
  and explicit; SE 3 default; xxxLarge) and a 16 s idle recording are in `.agent-reports/5.14-ready-to-look/`.
  Remaining: focused and full suites, Reduce Motion/AX4+/VoiceOver/light-mode checks, and phone review.

### Subsequent run — 5.14.2 declined-screen load-in

This run remains held while 5.13.1–.2 search/cancel design is unresolved. Do not treat this prompt as a decision
about Got it, sheet content, cancel destinations or sleeping-cat placement.

Agent prompt:

> Once Tessa has finalized the relevant 5.13 search/cancel flow, implement only the remaining declined-screen presentation in STEP-5.14 §2 against that finalized code. Reuse indexed ContentLoadIn for moon, title, body, primary action and secondary action in that order. Extend the existing OnboardingScreenChange handover to the declined screen: 0.2 s outgoing fade, incoming stagger, and ScreenChanged after the title starts. Preserve existing transition cancellation/reentrancy handling and avoid changing the view model's permission/search decisions. Retain the dimmed moon unless Tessa has explicitly approved sleeping-cat placement; if approved, the supplied sleeping composite stays still, with tail animation deferred. Keep the system permission prompt and sheet motion native. Verify deny/Settings return and the finalized search/cancel/pick paths, including fast repeated actions and Reduce Motion; run focused onboarding tests, then one full suite and build. Record a short continuous flow if available and state any physical-device VoiceOver/motion checks still needed. Update spec/status/reports and stop. No push/upload or phone install.
