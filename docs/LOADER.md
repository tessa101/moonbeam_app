# Step 5.9 Spec: Launch loader (and the main screen load-in, §12)

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
- **Phase cycle → real screen:** once the phase cycle shows, keep it **at least 1.1 s** (700 ms until 2026-10-06; Tessa raised it so the §10.2 entrance isn't cut off), then the load-in above, so it
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
  at 1 s → phase cycle; phase cycle shown at least 1.1 s (was 700 ms) even when the fix lands right after 400 ms
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
  .92 → 1.06 on the same loop, brightest at full; the disc's own glow is the mock's 40 px. ~~Starts at new when
  it appears, as the mock does.~~ **5.9.1 (Tessa):** starts at a waxing crescent, 25% lit (phase angle 60°,
  `PhaseCycle.startElapsed`, 0.97 s into the month), then runs on as before. 25% sits on the fast part of the
  ease, so it reaches first quarter 0.23 s after appearing and full at 1.43 s. Text: `Theme.Fonts.body` (17 pt;
  the mock has 16), `textSecondary`, 28 pt below.
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

**Follow-up (2026-10-05, §10.7).** The switch is now never read on the main actor: `LocationService` gained
`refreshAuthorizationState()`, which reads `locationServicesEnabled()` on a detached task (still only for
`notDetermined` / `denied`) and caches it; `authorizationState` stays synchronous and never blocks. The launch's
400 ms clock now starts **before** the permission read, so a slow read shows the moon. `App.init`'s onboarding check
reads the permission only for a new install. Device probe (T2 iPhone, 3 cold launches, authorized): `ready` at
250–430 ms, the switch never read; the only main-thread gap (100–140 ms) is SwiftUI's first layout, before any
location work.

## 10. Location flow: messages, recovery and "Aha" (Tessa's handoff, 2026-10-05)

**Source:** `design/1.4-location-flow/` (README.md, `Location Flow Prototype.dc.html`, `LocationFlowReference.swift`).
The handoff is a **prototype**: follow its **flow, timing, copy and motion ideas**; where it differs from the built
loader, **the built version wins** (moon 140 pt, label 17 pt `body`, `PhaseGlyph`, theme tokens). Amendments below
override the handoff README.

### 10.1 When it applies
- **Saved place:** any issue (off, denied, restricted, not asked, no fix) → **open the saved place** with its small
  location note. The message screens are for **no saved place only**.
- **New installs:** onboarding asks for location as now. **First ask** is only for existing installs that report
  `notDetermined` (Ask Next Time, expired Allow Once).
- **Restricted:** app-permission headline, **no Open Settings**; "Search for a city" becomes the primary button.
  Body (Tessa, 2026-10-06): "Location access is limited on this iPhone. You can still search for a city." The
  button sits where the other messages' button does (the missing link's room is kept).
- **Offline / city can't be named** (reverse geocoding fails without the network, fast, no 10 s wait) → **No fix**.

### 10.2 Moon
- **Real direction:** forward month via `PhaseGlyph` (lit right while waxing). The handoff's sliding-shadow math runs
  it in reverse; don't use it. Keep its timing and the idea of a **hold phase** where the moon starts, and where it
  stops when searching stops.
- **Hold phase = a waxing gibbous (Tessa, 2026-10-06):** ~83% lit, lit on the right, a thin dark sliver on the
  **left**, mirrored from the handoff's waning one (sliver on the right). From rest the month grows toward full, so
  the cycle starts by brightening and "Aha" (§10.4) reaches full in a fraction of a second rather than running
  through new. The onboarding moon (`OnboardingMoon`) matches it.
- **Entrance:** the moon appears at the hold phase (fade + 8 pt rise), the label follows at 320 ms, the cycle starts
  at 840 ms (handoff "Entrance"). Replaces "start at a waxing crescent".
- **Stopping:** keep running forward (2.6× speed) to the hold phase, then freeze; never stop mid-cycle. Glow switches
  from breathe to pulse (handoff timings).

### 10.3 Messages
Handoff copy and buttons (first ask / app permission off / services off / no fix), searching ≥ 1.2 s before any
message, label out 0.3 s, then the message fades in and rises 16 pt (handoff "Search → message"). Return after a fix:
message removed instantly, glow back to breathe, label back in 0.2 s later, cycle resumes. Don't Allow in the iOS
prompt → app permission off.
- **Known reason (Tessa, 2026-10-06):** if the message is asked for before the cycle has started (the entrance's
  840 ms), the moon stays at the hold phase instead of starting and then spinning a whole month back to it. The
  1.2 s minimum stays; the message is in at ~1.55 s (was ~3.3 s).

### 10.4 "Aha" — only after a recovery
- Plays **only** when a fix lands after a message or the iOS prompt. Ordinary launches (fast or slow) use the
  content load-in (§2.1), not Aha.
- Line rotates (don't repeat the previous one): **"Aha, there you are!"**, **"Hey, found you."**, **"There we are."**
  (Tessa may add more), with the city row under it (pin + "City, ST").
- Timing per the handoff ("Search → Aha → city"): moon runs to full, glow flares, hold ~2 s, then the moon flies into
  the card's phase slot (real frame) and settles on the real phase while the screen fades in.
- **VoiceOver:** "<line> <City, ST>", e.g. "Aha, there you are! Rancho Santa Margarita, CA".
- **As built (5.9.2 4/6):** plays after Try again, Allow at First ask's prompt, a return from Settings and the
  search sheet's Use my location from a message. ~~"Finding your location…" stays ≥ 1.8 s after it returns, then~~
  (superseded 2026-10-06, below) `LocationLoader.showAha`: moon runs out at 2.6× to full, glow flares, Aha fades in (0.6 s after 0.5 s, rises
  10 pt), hold 2 s. Then the screen is built under the loader (`launchStage = .ready`) and the moon flies 0.85 s
  into the card glyph's real frame (anchor preference), full → the day's phase, glow → 0.35; Aha out in 0.22 s,
  3 pt up; the screen fades in (0.6 s after 0.25 s, no rise) and the card's own glyph appears as the moon lands.
  Lines don't repeat within a session (not persisted across launches). Reduce Motion: no fly, the loader fades.
  DEBUG `-screenState recoveryAha`.
- **Fix (default-size flow pass, 2026-10-06), then Tessa's call C the same day:** after 1.8 s of searching from
  the hold phase the moon was already past full, so the run-out to full went through new and Aha's text was in over
  a dark moon. **Now:** the run to full starts **as soon as the fix lands**, under the label; label out, flare and
  Aha only once the moon is at full, and not before the label has been up 0.7 s (its fade-in). The handoff's 1.8 s
  minimum is gone. A fix while waxing: Aha ~0.7 s after the label; past full: ≤ 1.85 s after the fix.

### 10.5 Small screens and large text
- When the message block doesn't fit under the moon (SE 3, AX sizes), **scale down**: the moon shrinks (to ~96 pt)
  and moves up, and the headline / body step down together (to ~0.8×); the button keeps its 56 pt height. Scroll
  only if it still doesn't fit at AX sizes.
- Check: iPhone 17 and SE 3 at default, AX1, AX5, for each message.
- **As built (5.9.2 5/6):** the loader measures the current message at the current Dynamic Type size. It keeps the
  140 pt centred moon and full-size copy when that natural height fits; otherwise the moon becomes 96 pt and rises
  28 pt while the headline and body use 0.8× base sizes (still relative to Dynamic Type). If that compact form does
  not fit, only the message region scrolls. The primary CTA stays exactly 56 pt high; its visual title uses the
  default content size while the full title remains available to VoiceOver. Secondary text actions continue to
  scale and wrap.

### 10.6 Reduce Motion, VoiceOver

**Deferred by Tessa, 2026-10-06:** step 6/6 and other accessibility work are pending. The next pass focuses on
main location flows and animations at default text size (DECISIONS.md, "Default-size flows and animations
first"). Preserve the completed §10.5 layouts. The invisible outgoing "Finding your location…" label's VoiceOver
exposure is a known deferred issue.
Per the handoff: moon still at the hold phase, no rise / pulse / fly, every step cross-fades 0.3 s. VoiceOver:
"Finding your location" once, then the message headline (focus moves to it).

### 10.7 Engineering notes
- `CLLocationManager.locationServicesEnabled()` (used to tell "services off" from "denied") can block the main
  thread; call it off the main actor. It may be behind the launch stall (§9).
- Re-check status on authorization changes and when the scene becomes active.
- Hidden on every loader / message screen: pinned bar, DEBUG readout, Show onboarding, "a city".

## 11. Step 5.9.3: Loader polish (text, transitions, moon easing)

> Source: Tessa's device check 2026-10-06 + handoff zip
> `moon_loader_anim_polish.zip`. Only `MoonLoader.swift` is in the repo (`design/1.5-loader-polish/`); the
> prototype `Moon Loader Polish.dc.html` and its README weren't in the export. Its timing constants are all in the Swift.
> Target look for the message screens: Tessa's four prototype screenshots (line breaks in §11.1.3).
> Behavior doesn't change unless this doc says so. Owner: Tessa · _Drafted 2026-10-06_

Items marked **(proposed)** are Cowork defaults. Tessa's answers are in §11.6.

---

### 11.1 Line height and text width only (5.9.3a, built last)

#### 11.1.1 Moon and text placement: unchanged
**Cancelled (Tessa, 2026-10-06):** the moon and the label, message, "Aha" and button positions stay exactly as built.
Nothing moves. Only line height and text width (below) change, and the animation (§11.2, §11.3).
Earlier drafts of this section (moon up 50%, then 80 pt) are dropped.

#### 11.1.2 Line height
Targets from the prototype, as **line height = size × multiple**:

| Text | Font / size | Line height |
|---|---|---|
| Headline | Young Serif 28 | ×1.22 → 34.2 pt |
| Body | Nunito Sans 17 | ×1.45 → 24.7 pt |
| "Aha" | Young Serif 25 | ×1.2 → 30 pt |
| Label | Nunito Sans 16 | ×1.3 → 20.8 pt |

Use SwiftUI's total line-height modifier (`lineHeight(.multiple(factor:))`) rather than `lineSpacing`, which only
adds space on top of the font's natural line height and cannot tighten Young Serif. Put it in `Theme.swift` as one
helper so the loader, onboarding and anything later share it. The multiple follows the Dynamic Type-scaled font.
Check Young Serif descenders aren't clipped on a 2-line headline.

#### 11.1.3 Text width
The prototype uses balanced wrapping (`text-wrap: balance`) inside 28 pt side insets. SwiftUI has no balance, so
the lines run edge to edge. Fix:
- **Max widths:** headline **300 pt**, body **290 pt**, centred, inside the 28 pt insets.
- **Match these breaks at the default size** (from the screenshots). The copy is fixed, so a manual `\n` per message
  is fine. Fall back to natural wrapping at AX sizes and when the line wouldn't fit; never truncate.

| Message | Headline | Body |
|---|---|---|
| First ask | Find the moon / from where you are | Moon Signal uses your location to show / when and where the moon rises and sets. |
| App permission off | Moon Signal can't / see your location | Allow location access to see / where the moon is from here. |
| Services off | Location / Services are off | Turn them on to see where / the moon is from here. |
| No fix | Couldn't find / your location | Check your signal and try / again, or search for a city. |

- Restricted keeps the App-permission-off copy, Search only (as built).
- VoiceOver reads the headline and body as one sentence each, without the breaks.

### 11.2 Transitions (5.9.3b)

#### 11.2.1 "Finding your location…" exits smoothly after permission
**Symptom:** after Allow, the label sits there, then moves out.

> **Cowork note (2026-10-06), reconciling with what's built:** this was drafted against the handoff's 1.8 s search
> minimum, which `c98757e` (call C) already removed. As built, the label waits for **its own 0.7 s** and for **the
> moon's run to full** (up to ~1.85 s) before it leaves, which is the likely pause. Apply the fix to those: count the
> 0.7 s from the start of the search session, and since §11.2.2 drops the run to full before Aha, the label starts
> leaving as soon as the fix lands. Read "1.8 s" below as "the label's minimum".
**Likely cause (confirm in code and report it):** the 1.8 s minimum-on-screen rule starts when the label
*appears*. After a permission return the label only came back 0.2 s ago, so a fix that lands right away has to
wait out the rest of the 1.8 s with nothing happening, then fades.
**Fix:**
- Start the 1.8 s minimum from **the start of the search session** (first moon appearance, or Try again / return
  from Settings), not from the label's appearance. After a permission return the label may already be satisfied.
- Exit: fade 0.35 s ease-in-out, drifting up 6 pt, continuous, no hold step after the fix is in.
- **"Aha" overlaps the exit:** delay 0.15 s (was 0.5 s), fades in 0.6 s, rises 10 pt as before.
- The moon never pauses during any of this.
- Report the cause and the measured gap between "fix received" and "label starts leaving" (target < 50 ms once the
  minimum is satisfied).

#### 11.2.2 The moon finds the real phase after "Aha"
**Symptom:** at "Aha" the moon is a full moon, doesn't move, then flies into the card, where the real phase
appears. It also seems to run the wrong way.

New sequence (replaces "the moon advances to full" in §10 and the handoff README):
1. "Aha" appears (§11.2.1 timing). The moon is at its current loader phase.
2. **The moon runs forward to today's real phase and stops there.** It's the same phase and lit fraction the card
   will show (same selected day, place and midnight sampling, so it lands without a swap).
3. Beat of 0.4 s with the moon at rest.
4. "Aha" fades (0.22 s, up 3 pt). The moon flies and shrinks into the card's phase slot (0.85 s, same curve).
   The city screen fades in as before.

**Direction (the bug):** the phase only ever goes **forward in time**: new → waxing, lit from the **right**
→ full → waning, lit from the **left** (northern-hemisphere orientation, matching `PhaseGlyph`). Never reverse and
never jump. Distance forward `d = (f_real − f_now) mod 1`, in the loader's phase space (0 new, 0.5 full).
- From the real phase: `f_real = acos(1 − 2k) / 2π` when waxing; `1 − that` when waning. (k = lit fraction, as
  drawn by the 4b terminator.)

**Time (the "not enough time" bug):** duration `D = clamp(0.9 + 2.0·T, 1.6, 4.2)` s, where `T` is the total travel in
laps (`d` normally, `d + 1` on the first run), **ease in-out** per the
handoff curve (`q − 0.85·sin(2πq)/2π`). Starts 0.35 s after "Aha" is visible so the eye has landed on it.
Glow follows lit fraction as now (flares near full, then settles to the real k).

**First time or fresh install: at least one full pass (Tessa 2026-10-06).** On the first completed find after
install, travel `T = d + 1` laps, so the moon always sweeps through every phase at least once and lands somewhere
between 1 and 2 laps (about 1.5 on average, never a tidy lap count, so it doesn't feel mechanical). It still ends on
the real phase. Later launches go straight there (`T = d`). Persist a flag
(`hasSeenFirstFindPass`, `UserDefaults`); the DEBUG "Show onboarding" reset clears it.

**Skips:** a fix within 400 ms never shows the loader, so no ride (unchanged). Reduce Motion: the moon is drawn
at the real phase straight away, crossfades only, no ride, no extra lap.

**As built (5.9.3b, 2026-10-06):** the stall was the label waiting for the moon's run to full (up to 2.05 s), plus
the 0.7 s counting from the label's return and an 8 pt snap at the start of its exit. Now the label leaves at the fix
(2.7–3.0 ms measured), counted from `sessionStartedAt`. Aha at +0.15 s; the moon keeps running and rides
(`PhaseRide`) from +0.5 s, rests 0.4 s, flies with the phase unchanged. The glow breathes with k through it all (the
Aha flare is no longer used). The first ride's lap uses `OnboardingStore.hasSeenFirstFindPass`, only on a recovery
(an onboarding Allow has no Aha). Reduce Motion: 2 s hold, 0.3 s cross-fade to the real phase. Report:
`.agent-reports/5.9.3/findings.md`.

#### 11.2.3 Recovery order: moon first, "Aha" near the end (Tessa, 2026-10-06, after 5.9.3b) — 5.9.3b.2
Replaces §11.2.2 steps 1–2 and the ride's start time. Applies to every recovery (return from Settings, Try again,
Allow at First ask, the search sheet's Use my location from a message). Values marked (proposed) are Cowork's.
1. **Back in the app, the moon is already moving.** The cycle runs with "Finding your location…" as now.
2. **Fix lands → the ride starts at once**, continuing from the cycle **at its current speed** (no ease-in, so no
   hitch where the cycle hands over), and **eases out** to a soft stop on today's real phase. Duration and laps as
   §11.2.2 (`D = clamp(0.9 + 2.0·T, 1.6, 4.2)` s, first-install `+1` lap). The label leaves as built (at the fix).
3. **"Aha" floats up toward the end of the ride**: starts **1.0 s before the moon lands** (proposed; at the ride's
   start if `D` < 1.0 s), same 0.6 s fade + 10 pt rise, so it's fully in ~0.4 s before the landing.
4. **Soft landing, then a brief pause: 0.6 s** at rest on the real phase (proposed; was 0.4 s), so "Aha" + city has
   ~1.6 s on screen before it goes.
5. Then as built: "Aha" fades (0.22 s, up 3 pt), the moon shrinks and flies into the card's phase slot (0.85 s), the
   screen fades in.
- Reduce Motion: unchanged (§11.2.2).
- The extra first-install lap stays recovery-only (an onboarding Allow has no Aha).
- Tests: ride starts at the fix with the cycle's velocity (no speed dip at the handover); Aha starts at `D − 1.0 s`
  (or 0); rest 0.6 s before the flight; label exit unchanged.

**As built (5.9.3b.2, 2026-10-06):** the ride starts at the fix at the cycle's speed (a cubic ease-out, start slope =
that speed, end slope 0); Aha at landing − 1.0 s, never sooner than 0.15 s after the label starts leaving; rest
0.6 s (`PhaseRide.restBeat`). One addition: a cubic can start at most 3× the ride's average speed without
overshooting, so a fast cycle just short of the target **shortens the ride** (`D = 3T / speed`) rather than dipping.
Report: `.agent-reports/5.9.3/findings.md`.

#### 11.2.4 No pause after the landing (Tessa, 2026-10-06, after 5.9.3b.2) — 5.9.3b.3
Replaces §11.2.3 step 4 and the 0.6 s rest (`PhaseRide.restBeat`).
- The moon still **lands softly** on the real phase (the ride's ease-out, unchanged), then **goes straight into the
  flight**: scale + fly into the card's phase slot (0.85 s, as built), with no hold at rest.
- The flight should start from the landing's near-zero speed and ease in, so landing → flight reads as one motion,
  not a stop and a restart.
- **"Aha" stays through the flight** (proposed): without the pause it would only be readable ~0.4 s. It now fades
  during the flight's second half (starts 0.4 s into the flight, 0.3 s, up 3 pt) as the city screen fades in.
  "Aha" still starts 1.0 s before the landing.
- Tests: no rest between ride end and flight start; Aha fade starts 0.4 s into the flight.

**As built (5.9.3b.3, 2026-10-06):** `PhaseRide.restBeat` removed; the flight starts at the landing (only a ride
shorter than the label's exit waits for Aha). The flight's existing `cubic-bezier(.65, 0, .25, 1)` already starts from
rest, so no curve change. Aha fades from 0.4 s into the flight over 0.3 s (`LocationLoader.ahaLeaveDelayIntoFlight`,
`ahaLeaveDuration`). Both eases meet at zero speed, so the moon barely moves for ~0.3 s around the landing; check on
the device. Report: `.agent-reports/5.9.3/findings.md`.

#### 11.2.5 Flight overlaps the landing (Tessa, 2026-10-06, after 5.9.3b.3 on the device) — 5.9.3b.4
**Problem (as the 5.9.3b.3 note predicted):** the ride eases out to zero speed and the flight eases in from zero, so
the moon sits nearly still for ~0.3 s around the landing. Tessa: as soon as it eases into place, it should start
to shrink and move to the card.
- **Overlap:** the flight (scale + move) starts **0.25 s before the phase ride ends** (proposed). The phase finishes
  settling on today's phase during the flight's first 0.25 s, so the moon is never at rest.
- **Flight curve starts moving at once:** replace `cubic-bezier(.65, 0, .25, 1)` with an ease-out that has speed at
  the start, e.g. `cubic-bezier(.3, .3, .25, 1)` (proposed). Duration stays 0.85 s.
- Aha: unchanged (in 1.0 s before the landing, fades from 0.4 s into the flight over 0.3 s).
- Short rides (`D` < 0.5 s): the flight starts at the ride's midpoint instead.
- Tests: flight start = ride end − 0.25 s; the phase reaches the real value before the moon reaches the card glyph;
  moon speed never drops to ~0 between ride and flight.

**As built (5.9.3b.4, 2026-10-06):** flight at ride end − 0.25 s (`LocationLoader.flightOverlapWithRide`; the ride's
midpoint under 0.5 s), on `cubic-bezier(.3, .3, .25, 1)` (`AhaFlight.curve`). Aha's rules are unchanged, so it's
readable ~1.15 s before its fade. Report: `.agent-reports/5.9.3/findings.md`.

#### 11.2.6 Aha out earlier; main screen loads in around the flight (Tessa, 2026-10-06, after 5.9.3b.4) — 5.9.3b.5
**Problem:** "Aha" was still fading while the compass came in (the screen fades in as one block from 0.25 s into the
flight; Aha faded from 0.4 s), so the text sat over the compass.
- **Aha leaves as the flight starts:** fade 0.25 s, drifting up 6 pt, starting at flight start (replaces §11.2.4's
  "fades from 0.4 s into the flight"). Gone before anything else appears. Aha still comes in 1.0 s before landing.
- **Main screen loads in by block, not as one fade**, using §2.1's load-in (opacity + 8 pt rise, 300 ms ease-out),
  sequenced around the flight (flight start = 0) (proposed):
  - **Sentence:** 0.30 s (after Aha is gone)
  - **Moon card:** 0.45 s, so it's in as the moon lands in its phase slot (0.85 s); the card's glyph takes over at
    the landing as now
  - **Compass** (and the bottom bar / pinned bar): **1.0 s**, after the moon has landed
- Nothing on the main screen appears while Aha is still visible.
- Reduce Motion: as built (no flight), same order, opacity only.
- Scope: the recovery → Aha path only. The fast-launch and phase-cycle load-ins (§2.1) stay as they are; the app-wide
  transition pass is still later (DESIGN-REVIEW.md "Motion and feedback").
- Tests: Aha fully out before the sentence starts; block start times as above; compass starts after the landing.

**As built (5.9.3b.5, 2026-10-06):** Aha leaves at flight start (`LocationLoader.ahaLeaveDuration` 0.25 s,
`ahaLeaveDrift` 6 pt). After Aha the blocks load in at `ContentLoadIn.afterAhaDelay(for:)`: 0.30 / 0.45 / 1.0 s, with
§2.1's fade and 8 pt rise (the old single 0.6 s fade is gone). §2.1's own load-in and Reduce Motion are unchanged.
Report: `.agent-reports/5.9.3/findings.md`.

#### 11.2.7 Main screen stagger 150 ms everywhere; haptic as the moon lands (Tessa, 2026-10-06, after 5.9.3b.5) — 5.9.3b.6
**Stagger:** every main-screen load-in uses the same per-block motion (the sentence's: opacity 0 → 1 with the 8 pt
rise, 300 ms ease-out) and a **150 ms stagger**: **sentence → card (+150 ms) → compass (+300 ms)**. Tessa's guess at
the number; it should read as a light stagger, not a sequence to watch.
- Applies to all three load-ins: fast launch (< 400 ms), after the phase cycle (§2.1, was 70 ms), and after Aha
  (§11.2.6, was 0.30 / 0.45 / 1.0 s → now **0.30 / 0.45 / 0.60 s** from the flight start). The compass now comes in
  just before the moon lands (0.85 s); Aha is gone by 0.25 s, so nothing overlaps.
- The bottom bar / pinned bar come in with the compass.
- Keep the stagger in one constant (`ContentLoadIn`) so it's easy to tune on the device.
- Reduce Motion: same order and stagger, opacity only.

**Haptic when the moon locks into the card (new):** one light tap at the moment the flying moon lands in the
card's phase slot (the card's glyph takes over).
- `.sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger:)` (proposed): softer than the compass
  lock's `.impact(weight: .heavy)`, so the two feel different. Honors the System Haptics setting, as the compass does.
- Only on the recovery → Aha → flight path (the only time the moon flies). Once per landing, never on a launch
  without Aha.
- Reduce Motion (no flight): play it as the cross-fade to the main screen ends.
- Tests: landing increments the haptic trigger once; no trigger on a fast launch or after the phase cycle; stagger
  start times 0 / 150 / 300 ms, after Aha 0.30 / 0.45 / 0.60 s.

**As built (5.9.3b.6, 2026-10-06):** `ContentLoadIn.stagger` 0.15 s; after Aha `afterAhaStart` 0.30 s + the same
stagger (0.30 / 0.45 / 0.60 s). Haptic: `LocationLoader.landingCount` (bumped in `didLand()` only after a real
flight) drives `.sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6))` on `LocationScreen`. Reduce Motion
taps at the end of the 0.2 s loader cross-fade. Report: `.agent-reports/5.9.3/findings.md`.

### 11.3 Moon smoothness (5.9.3c)

Adopt the handoff's `MoonLoader.swift` timing and easing.
- **Style: 4b `.terminator` (decided, §11.6).** True phases, and its lit fraction is the same geometry as the
  card's `PhaseGlyph`, so the moon lands on the card with no visual swap. 4c and 4d are flat (eclipse-like): nice,
  but the card glyph would pop when it takes over. **Only 4b in the app, no `MoonStyle` switch** (Tessa, §11.6);
  4c / 4d stay in `design/1.5-loader-polish/MoonLoader.swift` as reference.
- Cycle 4.8 s: 2.2 s sweep new→full, 0.4 s hold at full, 2.2 s sweep full→new; each sweep eased in-out.
  Dark side `#2A2127` (earthshine), never a hole in the background.
- Halo and tight glow driven by the lit fraction `k` (no separate clock): halo opacity 0.12 + 0.88k, scale
  0.94 + 0.1k; tight glow 20 pt at 0.35k.
- **Stop (more easing, proposed):** the handoff runs at 2.6× then freezes abruptly at k = 0.85. Make the last
  ~0.4 s of that run decelerate (ease-out) into the hold phase, then start the halo pulse. Moon "comes in and out"
  with easing at both ends.
- Entrance: moon fades 0.9 s ease-out and rises 8 pt over 1.2 s (`cubic-bezier(0.16,1,0.3,1)`); label at 320 ms;
  cycle starts at 840 ms. Same as the handoff.
- Size stays as built (140 pt), not the handoff's 132.

**As built (5.9.3c, 2026-10-06):** `PhaseCycle` has the handoff's 2.2 / 0.4 / 2.2 s month and sine ease;
`PhaseGlyph` already draws the 4b terminator, so no new drawing. Dark side `Theme.Colors.moonEarthshine`, blended to
the card's `surface` during the flight. Halo and tight glow follow k. The stop is a 2.6× run, then a linear slowdown
to rest over the last 0.4 s (`MoonMotion.stopEaseDuration`), which adds 0.2 s (longest run-out 2.05 s, was 1.85 s).
Not adopted: a `MoonStyle` type (only 4b is drawn) and the handoff's 0.8 pt blur on the lit layer (the card glyph is
sharp). Report: `.agent-reports/5.9.3/findings.md`.

### 11.4 Build order (one commit each, small runs)
- **5.9.3c** Moon smoothness: adopt `MoonLoader.swift` timing, 4b, eased stop (§11.3). Before b, because b relies on
  the real-phase geometry.
- **5.9.3b** Transitions: label exit, Aha overlap, phase ride, first-run lap (§11.2).
- **5.9.3a** Line height and text width (§11.1.2, §11.1.3), last and small. No position changes.

### 11.5 Tests
- Line-height helper applies each style's target multiple and follows Dynamic Type.
- Break table: each message's default-size text matches §11.1.3.
- `f_real` from (k, waxing) round-trips with the 4b lit fraction at 0, 25, 50, 75, 100% for waxing and waning.
- Ride travel `T` is always forward: `d ∈ [0,1)` normally, `d + 1` on first run (so ≥ 1); duration clamps at 1.6 / 4.2 s.
- 1.8 s minimum counts from session start; a fix arriving after the minimum starts the exit with no added delay
  (fake clock).
- First-run flag set after the first ride, not set when the loader was skipped; DEBUG reset clears it.
- Reduce Motion: no ride, moon at the real phase, crossfades.

### 11.6 Decided (Tessa, 2026-10-06)
0. **Moon and text positions unchanged** (§11.1.1). Animation first (§11.2, §11.3); line height and width after (§11.1.2, §11.1.3).
1. **Moon style: 4b terminator, only.** No `MoonStyle` switch in the app (as built in 5.9.3c). 4c and 4d stay in
   `design/1.5-loader-polish/MoonLoader.swift` as reference for later.
2. Moon up 50% / 80 pt: dropped.
3. **First install: at least one full pass, about 1.5 laps** (`T = d + 1`, §11.2.2). Later launches: straight to the real phase.
4. **No blur on the moon's light/dark edge for now** (the handoff's 0.8 pt): the edge stays sharp like the card's
   glyph, so the landing doesn't change sharpness. Revisit at the device check if the edge looks harsh.
5. **Onboarding moon matches the loader:** earthshine dark side (`Theme.Colors.moonEarthshine`), not `bg`. Built 2026-10-06.

## 12. Step 5.10a: One load-in for the main screen; place change transition (Tessa, 2026-10-08)

**Problem (device videos, build 8, "Use my location" from the search sheet):**
1. As the sheet closes, the **old place shows again** in full (New York's card and its "too far" note), then
   "Finding your location…" appears above the card and **pushes it down**.
2. The new place **swaps in one frame**: sentence, card and compass together, no load-in. `ContentLoadIn` only runs
   `onAppear`, so it plays once per launch and never again.
3. The **compass letters fly through the centre**: the dial first shows north-up (no heading yet), then each letter
   animates its `.position` in a straight line to its new spot, so N/E/S/W cross in the middle.

### 12.1 One load-in, replayed whenever the screen's content is replaced
`ContentLoadIn` stays the one load-in (sentence → card +150 ms → compass +300 ms, fade + 8 pt rise, 300 ms ease-out,
§11.2.7). It becomes **replayable**: keyed to a **content generation** on the view model instead of `onAppear`.
- `LocationViewModel.loadInGeneration` (proposed name) bumps when the main screen's content is replaced. The modifier
  watches it: on a bump it snaps its block out (`isIn = false`, no animation) and loads in again with the usual
  delays. Launch keeps working as now (the first generation).
- After "Aha" keeps its own start (`afterAhaStart`); every other replay uses the plain delays.
- **Rule: replay when *where* changes, not *when*.**

| Event | Load-in |
|---|---|
| Launch: fast, after the phase cycle, after Aha | Yes (as built) |
| Place change: search pick, recent, Use my location, Forget saved place → new place | **Yes: card + compass.** The sentence stays and only the city token cross-fades (§12.9) |
| Back from the background, same place | No |
| Back from the background, detected place changed | Yes |
| Date change (arrows, calendar), midnight rollover | No load-in. The card's values **cross-fade quickly in place** (opacity only, ~150 ms ease-out, no rise or movement). Tessa, 2026-10-08 |
| Same place re-detected / refreshed | No |

- Reduce Motion: same order and stagger, opacity only (as now).
- Every future main-screen entry uses this; no second load-in.

### 12.2 Place change sequence
1. **Old place out as soon as the change starts** (pick made, or the sheet closes on Use my location): sentence
   place token, card and compass fade out, 150 ms. The old place's card, compass and notes never show again.
2. **Sentence city token switches straight away** to the new name (a pick), or to "your location" until the fix
   lands (Use my location). The rest of the sentence doesn't move.
3. **Ready under 400 ms** (a picked city: it's all computed on the phone): no placeholder, straight to the §12.1
   load-in.
4. **Over 400 ms** (GPS): **placeholder A**, the card skeleton (§12.3), until the fix lands; then the skeleton
   cross-fades into the real card (200 ms) and the compass loads in at its usual +300 ms. The sentence doesn't
   replay if it's already showing the new place.
5. Fix fails: the skeleton's line reads "Couldn't find your location. Try again, or search for a city." (current
   copy), in the card's place; the old place does not come back.

### 12.3 Placeholder A: card skeleton
- Same size and position as the real card (two-column layout), so nothing moves when the real card replaces it.
- Phase slot: the moon outline in `moonEarthshine`, breathing slowly (opacity 0.4 ↔ 0.7, 1.6 s ease-in-out);
  Reduce Motion: still, at 0.55.
- **5.10a.3 (Tessa, 2026-10-09):** no text while finding. Quiet blocks where the moon (filled disc), the date and
  phase lines, ‹ › and the time/direction rows go, inside the card's outline and divider, with a soft highlight
  sweeping left to right (1.4 s linear, repeating) over the blocks only. Reduce Motion: still blocks. A failure keeps
  the blocks still and shows the failure line in the header's place. The skeleton and real card cross-fade (0.5 s, slowed from 200 ms by Tessa 2026-10-09) with no
  text on either side of the swap to ghost through.
- **5.10a.4 (Tessa, 2026-10-09): slower, ordered landing.** City line first (0.8 s fade, 8 pt rise), then the card
  at +0.25 s, then the compass at +0.6 s, each 0.7 s ease-out with the 8 pt rise (`ContentLoadIn.replay*`). The
  skeleton leaves on the card's clock. Reduce Motion: no rise, card swap instant as before. Launch load-in unchanged.
- **5.10a.5 (Tessa, 2026-10-09, from device video 2):** (1) The replaced place's card is gone the instant the change
  starts: no fade-out of old data (it used the new card's slow fade by mistake). (2) The city line hides at once
  (0.15 s) and is let in once, after the new name is already in place, so "a city" / the old name never cross-fade
  into it. (3) The card's frame is the skeleton's and never fades or moves; only its content fades and rises 8 pt
  into it (same 0.25 s delay, 0.7 s) while the skeleton's blocks fade out above it. The fast path (no skeleton) still
  replays the whole card block. Reduce Motion: instant swap.
- **5.10a.6 (Tessa, 2026-10-09, video 3): faster, simpler.** Too slow, and the content-only fade looked bad. City line:
  cross-fade only, 0.3 s, no movement. Card: the whole card fades and rises 8 pt, like the compass (0.4 s, +0.1 s);
  compass +0.25 s, 0.4 s. Supersedes the 5.10a.4/5.10a.5 timings and the content-only rise above.
- **5.10a.7 (Tessa, 2026-10-09, video 4): no leftovers.** The replaced card and city line are gone in the frame the
  replacement starts (the old card used to linger ~0.5 s: a `.identity` removal keeps a view on screen for the whole
  animation, here the sheet's dismissal). The skeleton shows in that same frame, with no 400 ms wait and no empty
  slot, and holds at least 350 ms. Supersedes §12.2 step 4's "over 400 ms" and the threshold in §12.9.
- **5.10a.8 (Tessa, 2026-10-09, video 5):** the 5.10a.7 instant removal didn't take on device: the old card still faded
  out (~0.25 s) over the skeleton fading in, and the city line faded too. Cause: `disablesAnimations` lost to the
  ambient `.animation(value:)` fades. Now those fades are switched off while a replacement is pending and the
  transaction's animation is cleared, so the swap is a hard cut in one frame; the landing still animates.
- **Sentence during My location (5.10a.3):** the city line ("in 📍 City, ST?") is hidden, not a stand-in like "your
  location", and fades in (0.5 s ease-out, opacity only) when the city is known. It keeps its slot, so nothing
  moves; VoiceOver reads the sentence without the place until then. Supersedes §12.2 step 2's "your location".
- No compass and no bottom bar until the real card is in.
- VoiceOver: the skeleton reads "Finding your location"; focus moves to the card when it lands.

### 12.4 Compass entrance
- **Wait for the first heading** before the compass block loads in, so the dial never appears north-up first. If no
  heading arrives within 0.5 s, load in with the no-heading look (as now) and turn when it arrives.
- **Rotate the dial as one piece** by the shortest path (unwrap the angle, never animate across 0/360). Letters,
  numbers and targets ride the rotation; their `.position` is never animated independently.
- **Settle (Tessa):** the dial loads in ~10° off true and eases into the real heading over 0.5 s
  (`.spring(duration: 0.5, bounce: 0)` or ease-out, proposed). Direction of the offset: against the last heading
  change, so it reads as "finding" north.
- Reduce Motion: fade in, already aligned; no settle.

### 12.4.1 Compass polish from build 8 testing (Tessa, 2026-10-07), built with 12.4
- **Degree readout:** sits closer to the top tick (gap to be tuned on the device; start at half the current gap).
  While the dial is turning toward a rise / set / Now target and the lock is about to engage, the readout **fades
  out** (150 ms) so the lock pill shows alone; it fades back in when the lock releases. No overlap of readout and
  pill.
- **Now pulse:** the Now (moon) target keeps pulsing **until the user locks onto Now**, not until the dial first moves.
  Locking on rise or set doesn't stop it. Stops for the session once Now is locked (as now after the first lock).
- Tests: readout opacity 0 while locked, 1 otherwise; pulse continues after a rise lock, stops after a Now lock.

### 12.5 Tests
- `loadInGeneration` bumps on each place change, not on a date change, a same-place refresh or a foreground return.
- A place change hides the old card before the new one shows (no frame with the old place after the change starts).
- Under 400 ms: no skeleton. Over 400 ms (fake clock): skeleton, then card, then compass at +300 ms.
- No vertical movement of the card between skeleton and real card (same frame).
- Dial rotation takes the shortest path across 0/360 (350° → 10° turns 20°, not 340°); letter positions are
  derived from the rotation, not animated.
- Compass waits for the first heading, up to 0.5 s.

### 12.6 Build order (one commit each)
- **5.10a.1** Replayable `ContentLoadIn` + `loadInGeneration`; old place out on change; sentence token switches
  straight away (§12.1, §12.2 1–3).
- **5.10a.2** Card skeleton (§12.3, §12.2 4–5).
- **5.10a.2b** Device-check fixes: sentence stays, only the city cross-fades; hold the card slot; skeleton minimum (§12.9).
- **5.10a.3** Compass entrance: wait for heading, rotate as one piece, settle (§12.4); readout fade + Now pulse (§12.4.1).

### 12.7 As built — 5.10a.1
- `ContentLoadIn` now keys its existing stagger to `loadInGeneration`.
- Search picks replace the old place before sheet dismissal. “Use my location” removes the old place and switches
  the sentence token to “your location” immediately; a failed replacement never restores the old card.
- Generation changes only when *where* changes, not for a date, same-city refresh, or unchanged foreground return.
  Findings: `.agent-reports/5.10a/5.10a.1-findings.md`.

### 12.8 As built — 5.10a.2
- `PlaceCardRegion` (`MoonCardSkeleton.swift`) owns the card slot. `LocationViewModel.cardPlaceholder` is `.finding`
  after `placeSkeletonThreshold` (400 ms, injectable), `.failed` when the replacement ends without a place. The
  stock `ProgressView` and the failure text above the card are gone.
- The skeleton draws over the replaced card rendered `hidden()`, so it has that card's frame. Failure copy shows on
  the skeleton's line, and the moon holds still at 0.55.
- A refused prompt or Location Off during a replacement also reads as the failure (DECISIONS.md 2026-10-08, 5.10a.2).
- Cross-fade 200 ms ease-out (none with Reduce Motion). VoiceOver focus moves to the card when it lands.
- Compass and its bottom bar stay hidden until the real card is in (`isReplacingPlace`).
- Tests: `PlaceSkeletonTests` (6). Findings: `.agent-reports/5.10a/5.10a.2-findings.md`.

### 12.9 Device check after 5.10a.2 (Tessa, 2026-10-09) — build as 5.10a.2b
Source: device video `5.10a.2_bug.MP4` (build `e967f46`, Use my location with Fri Oct 16 selected), analysed frame by
frame. Timeline and frames: `design/bugs/place-change-2.md`, `design/bugs/place-change-2-frames.jpg`.
**What the video shows:**
1. The pending sentence reads "the moon **today** in your location" (the selected date is dropped), then Oct 16 comes
   back. It looks like a stale placeholder.
2. That sentence then **fades out with everything else** (one fully blank frame) and **loads in again**, a second
   entrance. §12.2 step 4 said the sentence doesn't replay.
3. With the old card gone and no skeleton yet, the content below moves up ~100 pt, then back down (the slot isn't held).
4. The skeleton shows for only ~0.2 s (the fix landed ~0.7 s after the tap) and reads as a flash.

**Decision (Tessa): the sentence stays, keeps the date, only the city changes.**
- **The sentence never leaves.** On a place change it isn't faded out and doesn't replay its load-in. The date token
  keeps the selected date at all times ("on Fri, Oct 16", "today", …). Only the **city token** changes: "your
  location" while a fix is pending, then the city's name; it **cross-fades in place** (opacity only, ~150 ms ease-out,
  like a date change, §12.1). No frame without the sentence. Reduce Motion: same fade (a fade isn't motion).
  A picked city's token switches at once (as 5.10a.1).
- **Replay covers the card, the compass and the bottom blocks only.** `ContentLoadIn` still loads the sentence in on
  launch (the first generation) and after Aha; a place change replays only the blocks below it (card → +150 ms
  compass).
- **Hold the card slot from the first frame the old card leaves.** An invisible slot with the replaced card's frame
  stays until the skeleton or the real card is there, so nothing below it (compass area, notes, bottom bar, the DEBUG
  buttons) moves.
- **Skeleton minimum (proposed, tune on device): once shown, it stays at least 350 ms**, so a fix that lands soon
  after 400 ms doesn't flash it. If the fix lands before 400 ms there's no skeleton (§12.2 step 3). The cost: a fix
  between 400 and 750 ms waits for the minimum.
- Failure keeps its copy inside the skeleton (§12.8); the sentence then reads "your location" until the user picks or
  retries.
- **Tests:** the sentence view is never absent or at opacity 0 across a place change, and its date token equals the
  selected date in the pending state; sentence load-in doesn't replay on a place change (only on the first
  generation); card slot height identical from old-card-out to skeleton to real card; skeleton visible ≥ 350 ms when
  shown; under 400 ms no skeleton.
- Amends §12.1's table (the place-change row loads in the card and compass, not the sentence) and §12.2 steps 1–2
  (the sentence's place token isn't faded out; it cross-fades to the new text).

### 12.10 As built — 5.10a.2b
- **Sentence:** `.contentLoadIn(.sentence)` with no generation; `ContentLoadIn.replaysOnPlaceChange(.sentence)` is
  false, so it loads in once per screen arrival (launch, after Aha). The city token cross-fades with
  `MadlibSentence.placeTokenFade` (opacity content transition, 150 ms ease-out, also under Reduce Motion).
- **Date while pending:** `MadlibFormatter.sentence(dateTimeZone:)` reads the selection in the replaced place's zone,
  so the token keeps "on Fri, Oct 16" through the wait and after a failure.
- **Replay:** card at 0, compass +150 ms (`ContentLoadIn.replayDelay`). The card has its own
  `cardLoadInGeneration`. It doesn't bump when a skeleton held the slot, so the skeleton cross-fades into the card
  with no blank frame. The compass block (and the DEBUG buttons and bottom bar) is held out (`isActive: false`) while
  a replacement is pending.
- **Slot:** `PlaceCardRegion` shows the replaced card `hidden()` from the first frame, until the skeleton or card.
- **Minimum:** `placeSkeletonMinimum` 350 ms. The skeleton task keeps running through it, and a fix that lands
  meanwhile waits on it.
- Tests: `PlaceSkeletonTests` (+5) and `PlaceChangeLayoutTests`. The layout test samples the real sentence, slot and
  load-in modifiers every 16 ms through a 700 ms fix. It checks: sentence ink present (with an empty-strip
  control), date unchanged, content below unmoved, skeleton ≥ 350 ms. Findings:
  `.agent-reports/5.10a/5.10a.2b-findings.md`.

## Decision log

- **2026-10-08 (Tessa, device videos of a place change):** the old place mustn't show after a change; placeholder A
  (card skeleton) only when the new place takes over 400 ms; one load-in, replayed whenever the place changes; the
  compass turns as one piece and settles ~10° into true heading (§12).
- **2026-10-06 (Tessa, after 5.9.3b.5):** main screen blocks load in with a 150 ms stagger everywhere (sentence →
  card → compass); a light haptic when the moon lands in the card (§11.2.7).
- **2026-10-06 (Tessa, after 5.9.3b.4):** Aha was over the incoming compass. Aha leaves as the flight starts; after a
  recovery the main screen loads in by block around the flight, compass last after the landing (§11.2.6).
- **2026-10-06 (Tessa, after 5.9.3b.3):** cut further: the moon starts shrinking and moving to the card as it
  eases into place, no near-still moment (§11.2.5).
- **2026-10-06 (Tessa, after 5.9.3b.2):** no pause after the moon lands; soft landing, then straight into the
  scale + flight into the card (§11.2.4).
- **2026-10-06 (Tessa, after 5.9.3b):** recovery order changes: the moon rides to the real phase as soon as the fix
  lands, "Aha" floats up near the end of the ride, soft landing, brief pause, then the flight (§11.2.3).
- **2026-10-06 (Tessa, after 5.9.3c):** 4b only, no style switch (4c / 4d kept as reference); no edge blur for
  now; onboarding moon gets the earthshine dark side to match the loader.
- **2026-10-06 (Tessa, answers):** 4b; moon doesn't move, animation only; first-install moon passes at least once, ~1.5 laps.
- **2026-10-06 (Tessa, device check):** line height tighter to the design; narrower text (balanced
  breaks); label exit smoother after permission; after "Aha" the moon moves to the real phase, forward only, with
  enough time and easing, with one extra pass on first install; moon smoother with more easing. Handoff
  `moon_loader_anim_polish.zip` supplies the moon timing.
- **2026-10-05 (Tessa):** Location flow from her handoff (`design/1.4-location-flow/`), amended in §10: saved place
  wins; onboarding stays for new installs; restricted has no Settings button; offline = No fix; scale down on small
  screens / large text; real moon direction; "Aha" only after a recovery, with rotating lines; built sizes win, the
  handoff's timing and flow are what matter.
- **2026-10-05 (Tessa):** Location off with no saved place: no "a city" screen. Brief moon attempt, then the moon
  stops in place and a message + Turn on Location CTA move in from the bottom (§10). With a saved place, show it.
- **2026-10-05 (Tessa):** Device launch waited several seconds with no moon: a bug, fix it. A quick launch should
  show the **content loading in**, not a scrim fading out (§2.1).

- **2026-10-03 (Tessa):** No compass dial, just the moon loading. Skeleton tier dropped; over 400 ms the 1a phase
  cycle shows for everyone. Interim transition values locked.
- **2026-10-02 (Tessa):** Loader by wait time: under 400 ms no loader, the screen loads in softly; about 1–2 s, the
  1c skeleton; longer, the 1a phase cycle. Built as Step 5.9. _(Skeleton superseded 2026-10-03.)_
