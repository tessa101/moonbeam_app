# Step 5.9 Spec: Launch loader

> Source: Claude Design `design/1.1/Moon Signal Loader.dc.html`, concept **1a Phase cycle** ("First run · no saved
> place" frame). Replaces the stock `ProgressView` "Finding your location…" launch state (DESIGN-REVIEW.md, Location
> screen, "Launch loading state" bug, 2026-10-01).
> Owner: Tessa · _Decided 2026-10-02, simplified 2026-10-03_ · **Build after 5.6, before 5.5**

**2026-10-03 change:** no skeleton and no compass dial. One loader only: the centred phase-cycle moon. The
skeleton tier (old §3) and its card/dial placeholders are dropped.

---

## 1. When the loader runs

Only while the **launch location fetch** is in progress (authorized, LOCATION.md §3, up to 10 s). Moon data is
computed on the device and is effectively instant, so the fetch is the only wait.

- **No fetch, no loader:** location not determined / denied / off → straight to the last-viewed place or the empty
  first-launch state, as now (with the soft fade, §2.1).
- **Onboarding:** after Allow, the same rules apply to the first fetch.
- **Applies to new and returning users alike.** The loader never shows the last-viewed place.

## 2. Two tiers, by how long the fetch takes

| Fetch takes | What shows |
|---|---|
| **Under 400 ms** | No loader. The main screen **fades in softly** (§2.1). |
| **Over 400 ms** | **Phase cycle** (§3): the moon running through its phases, "Finding your location…". |
| **10 s** | Fetch times out: as LOCATION.md (last-viewed place if any, else the empty state with the failed-fetch note). |

Between launch and 400 ms the screen is plain `bg` (no content, no spinner), so a fast fix never flashes a loader.

### 2.1 Transitions
- **Main screen in (under 400 ms) — content loads in, not a scrim fading out (Tessa, 2026-10-05):** the
  background stays solid and unchanged; nothing dims or lifts over the whole screen. The content blocks animate in
  where they'll sit, top to bottom: **sentence → moon card → compass**, each opacity 0 → 1 with an **8 pt rise**,
  300 ms ease-out, **staggered 70 ms**. Same load-in after the phase cycle (instead of a whole-screen cross-fade):
  the loader fades out (200 ms) and the blocks load in as it goes. **(proposed values)**
- **Reduce Motion:** opacity only, no rise; the stagger may stay.
- **Phase cycle in (at 400 ms):** opacity 0 → 1 over 250 ms.
- **Phase cycle → real screen:** once the phase cycle shows, keep it **at least 700 ms**, then the load-in above, so it
  never flashes.
- Phase cycle under Reduce Motion: no phase animation (§3).
- Interim values; transitions get an app-wide polish pass later (DESIGN-REVIEW.md "Motion and feedback").

## 3. Phase cycle

Concept 1a, the onboarding moon, on a clean screen (no sentence, card, compass or pinned bar).

- Centred moon glyph, **140 pt**, its lit fraction running through a full month every **4.8 s**, smooth ease,
  never settling on a "done" shape. Glow behind it breathes on the same 4.8 s loop (`accent` 32% radial), plus the
  faint top glow from the mock.
- "Finding your location…" under it (`textSecondary`, body), as in the mock.
- **Reduce Motion:** the glyph holds still at full; only the glow fades slowly.
- Same glyph code as the card and onboarding (`PhaseGlyph`), driven by an animated phase angle.
- **Motion reference:** `design/1.1/loader-1a-phase-cycle.mov` (5.6 s screen recording of the mock). One month
  ≈ 4.8 s; it eases through new and full; the glow is brightest at full.
- **Direction (Tessa, 2026-10-03): astronomically correct, forward** (new → lit right → full → lit left → new),
  matching `PhaseGlyph` on the card. The recording plays the month in reverse; follow its timing and glow, not its
  direction.

## 4. Accessibility

- VoiceOver announces **"Finding your location"** once, when the phase cycle appears. The glyph is hidden from
  VoiceOver (decorative); the text is the label.
- When the real screen arrives, focus goes to the sentence header.
- AX sizes: the text scales and wraps; the glyph stays 140 pt.

## 5. Also fixes

- The DEBUG compass readout never shows during loading.
- The Show onboarding button (TestFlight/DEBUG) is hidden during loading.
- The pinned compass bar (5.6) is hidden during loading.
- No "a city" token while locating.

## 6. Not in this step

- The skeleton (old 1c tier), 1c's orbiting moon / compass dial, concept 1b (Moonrise).
- App-wide transition polish (DESIGN-REVIEW.md "Motion and feedback").

## 7. Tests

- Tier selection on a fake clock and fake location service: fix at 300 ms → no loader, main screen fade;
  at 1 s → phase cycle; phase cycle shown at least 700 ms even when the fix lands right after 400 ms
- 10 s timeout → last-viewed place or empty state, as LOCATION.md
- No fetch (denied / not determined / off) → no loader
- The loader never shows the last-viewed place's name, the pinned bar, the DEBUG readout or Show onboarding
- VoiceOver announcement fires once per launch
- Reduce Motion: no phase animation

## 8. As built (Build 5.9, 2026-10-05)

Report and shots: `.agent-reports/5.9/`.

- **Stage:** `LaunchStage` (`waiting` / `phaseCycle` / `ready`) on `LocationViewModel.launchStage`, moved only by
  `start()` (`locateAtLaunch()`): a 400 ms wait raced against the fix; if the wait wins, the phase cycle, and the
  screen waits for the 700 ms hold as well as the fix. `onboardingDidFinish` puts it back to `waiting` (§1, and no
  flash of the old screen after Show onboarding). The waits come through an injected `sleep`, as in
  `CompassViewModel`.
- **Screen:** `LocationScreen` builds the real screen only at `ready`, so the sentence, card, compass, pinned bar,
  bottom note, DEBUG readout and Show onboarding can't show while loading (§5). The launch task, scene handling
  and sheets moved to the outer container, so they run while loading. ~~Every stage change fades 250 ms
  ease-out, Reduce Motion included.~~ **5.9.1:** the phase cycle fades in 250 ms and out 200 ms (ease-out);
  the real screen has no fade of its own. Its blocks load in (`ContentLoadIn`, §2.1's values): sentence → card
  (with the Use my location / status rows) → compass (with Show onboarding and the bottom note bar), opacity
  0 → 1 and an 8 pt rise as an offset (layout never moves), 300 ms ease-out, 70 ms apart; Reduce Motion drops
  the rise. They run once, when the screen arrives: a compass or note that turns up later only slides in, as
  before. Same after the phase cycle, while it fades out.
- **Waiting (0–400 ms):** the screen's backdrop (`ScreenBackground`, `bg` plus the faint top glow) with nothing on
  it. The glow is kept so the backdrop doesn't change when the loader fades in.
- **Phase cycle:** `LaunchPhaseCycle` (view) + `PhaseCycle` (pure maths). `PhaseGlyph` at 140 pt on `bg`, its
  `PhaseGlyphGeometry` from an angle eased per half month with the mock's `cubic-bezier(.45, 0, .55, 1)`; lit
  fraction `(1 − cos φ) / 2`, forward. Glow: `accent` 32% radial, 2.2 moons across, opacity .45 → 1 and scale
  .92 → 1.06 on the same loop, brightest at full; the disc's own glow is the mock's 40 px. Starts at new when it
  appears, as the mock does. Text: `Theme.Fonts.body` (17 pt; the mock has 16), `textSecondary`, 28 pt below.
- **Reduce Motion:** glyph still at full; the glow keeps its opacity fade, no scale.
- **VoiceOver:** "Finding your location" announced once per launch (`phaseCycleDidAppear()`); glyph hidden; on
  `phaseCycle → ready` a screen-changed notification moves focus to the first element, the sentence header.
- **Timeout:** as LOCATION.md §3, quietly: last-viewed place, or the empty state. **No failed-fetch note** at
  launch; §2's "with the failed-fetch note" isn't in LOCATION.md, which this follows. Flagged for Tessa.
- **DEBUG:** `-screenState loading` (a fix that hangs until the 10 s timeout) for screenshots.

## 9. Device bug (2026-10-05, build 5e2ba79)

On Tessa's iPhone (existing install, location authorized) the launch showed **plain background for well over a few
seconds**, then faded to the screen. **The phase cycle never appeared**, though the wait was far past 400 ms. The
simulator shots were fine. Likely something holds the main actor during launch (so the 400 ms timer can't fire), or
the stage logic misses a path on device. Either way: **any launch wait over 400 ms must show the moon.**

**Findings (Build 5.9.1, 2026-10-05).** Report `.agent-reports/5.9.1/5.9.1-launch-fix.md`.
- **Not reproduced** on the T2 iPhone (iPhone 17 Pro, iOS 26.6.2): ~10 cold launches, from the Mac and from the
  home screen (one probably after a restart), all `ready` in 0.25–0.45 s after process start; no prewarm. The
  stage logic works on the device: with the fix held 3 s, the phase cycle was on screen at 579 ms.
- **Likely cause:** `CLLocationManager.locationServicesEnabled()`, read on the main thread twice in `App.init`
  (before the first frame) and again in `start()` (before the 400 ms wait starts). Xcode recorded its runtime
  warning on this device ("can cause UI unresponsiveness if invoked on the main thread"). A stall there shows
  plain background, then the screen, and never the moon: the reported symptom. It measured 0 ms in every launch
  traced here, so this is the fit, not a capture. **Fix:** it's read only when the status is `notDetermined` or
  `denied` (the two it changes), so an authorized launch never calls it.
- **Also fixed:** the 4.8 foreground retry could cancel the launch fetch when the scene turned active before the
  fetch started; the launch then dropped its fix and opened with no place. `sceneDidBecomeActive` now leaves
  fetching to `start()` until the stage is `ready`.
- **Kept:** `os_signpost` intervals around the launch (`LaunchSignposts`, subsystem `com.t-alien.moonbeam-app`,
  category `Launch`), so a stall on device can be caught in Instruments' os_signpost / Time Profiler.

## Decision log

- **2026-10-05 (Tessa):** Device launch waited several seconds with no moon: a bug, fix it. A quick launch should
  show the **content loading in**, not a scrim fading out (§2.1).

- **2026-10-03 (Tessa):** No compass dial, just the moon loading. Skeleton tier dropped; over 400 ms the 1a phase
  cycle shows for everyone. Interim transition values locked.
- **2026-10-02 (Tessa):** Loader by wait time: under 400 ms no loader, the screen loads in softly; about 1–2 s, the
  1c skeleton; longer, the 1a phase cycle. Built as Step 5.9. _(Skeleton superseded 2026-10-03.)_
