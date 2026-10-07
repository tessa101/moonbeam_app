# Decision Log

> One entry per meaningful choice. Newest at the top. Keep it short.
> Format: **date · decision**, then why and what else we considered.

---

### 2026-10-06 · Build 5.9.3c: moon smoothness as built (LOADER.md §11.3)
- **Eased stop:** a constant 2.6× run, then speed falling linearly to zero over the last 0.4 s (all slowdown when the
  stop is nearer than that). Arrives with no jolt and adds 0.2 s to every run-out.
- **4b is `PhaseGlyph`:** same terminator geometry as the handoff's path, so it's reused rather than redrawn. No
  `MoonStyle` type yet, because 4c/4d aren't drawn in the app (open for Tessa).
- **Earthshine disc** blends to the card's `surface` during the flight, and the tight glow to the card's 30%, so the
  card glyph takes over with no swap. The handoff's 0.8 pt lit-layer blur was left out for the same reason.
- **Considered:** an S-curve (smoothstep) stop. Rejected, because it would also ease the start of the run-out, where
  §11.3 only asks for the end.

### 2026-10-06 · Build 5.9.3b: label exit and the phase ride as built (LOADER.md §11.2)
- **The ride starts 0.35 s after Aha starts showing** (its 0.15 s delay), so 0.5 s after the label leaves. Until
  then the moon runs on at the normal speed: it never pauses.
- **Glow breathes with k through Aha** rather than the one-off flare, per §11.2.2 "glow follows lit fraction".
  The flare mode is left in the code, unused, until Tessa's check.
- **First-find flag on `OnboardingStore`**, not a new store: it's first-run state, and Show onboarding /
  `-resetOnboarding` already reset that store. Set only once a ride completes.
- **Label exit split:** Aha gets the 0.35 s drift-up exit; the message exit stays 0.3 s in place. Both no longer
  snap 8 pt (the rise is reset on re-entry).
- **DEBUG `recoveryAha`'s fix takes 1 s** after Try again, so it exercises a fix after the label's minimum.
- **Considered:** starting the ride's ease from the running speed (no slow start). Not done, because §11.2.2 names
  the handoff curve. Left for the device check.

### 2026-10-06 · After 5.9.3c: 4b only, no edge blur, onboarding moon earthshine
- **Decisions (Tessa):** only 4b in the app, no `MoonStyle` switch; 4c / 4d stay in `design/1.5-loader-polish/` as
  reference. Onboarding's moon gets the earthshine dark side to match the loader.
- **Edge blur:** left out for now (agent's 5.9.3c call: the card glyph is sharp, so a blurred loader moon would change
  sharpness on landing). Revisit at the device check. LOADER.md §11.6.

### 2026-10-06 · Loader polish, Step 5.9.3 (LOADER.md §11)
- **Decisions (Tessa, device check + answers):**
  - **Moon and text positions unchanged.** Only line height and text width change (5.9.3a), plus the animation.
  - **Moon style 4b terminator**, timing and easing from the handoff's `MoonLoader.swift`
    (`design/1.5-loader-polish/`); an eased stop into the hold phase (5.9.3c).
  - **Label exit:** no pause after the fix; Aha overlaps the exit (0.15 s delay).
  - **After Aha the moon runs forward to today's real phase** (never backwards), eased, 1.6–4.2 s, then flies into
    the card. Replaces "moon runs to full" before Aha (§10.4, call C). **First find after install: one extra lap**
    (`hasSeenFirstFindPass`) (5.9.3b).
  - Line height to the prototype's multiples via one `Theme` helper; max widths 300 / 290 pt with fixed breaks at
    the default size (5.9.3a).
- **Order:** 5.9.3c → 5.9.3b → 5.9.3a, one commit each, small runs.
- **Considered:** 4c sliding shadow and 4d light wash (flat, the card glyph would pop); moving the moon up 50% / 80 pt
  (dropped).

### 2026-10-06 · Forget saved place (DEBUG / TestFlight, temporary)
- **Decision (Tessa):** a "Forget saved place" button beside Show onboarding, in the same builds (`BuildChannel.
  showsOnboardingButton`), **removed with it before the 1.0 App Store build**. Clears the last-viewed place and
  recents, then runs the launch flow again (`LocationViewModel.forgetSavedPlace()`), so the no-saved-place loader,
  its messages and Aha can be tried without reinstalling. Permission and the onboarding flag are left alone.
- **As built:** the two links sit side by side, stacked when they don't fit (`ViewThatFits`). Authorized, the flow
  just finds you again (an ordinary launch); to see a message, turn location off for Moon Signal first.

### 2026-10-06 · Loader timing: known reasons, minimum hold, Aha from the fix
- **Decisions (Tessa), on the flow pass's A/B/C:**
  - **A.** A reason already known when the loader appears (permission off etc., no saved place): no spin. The moon
    stays at the hold phase and the message is in at ~1.55 s, not ~3.3 s. "Waiting 3 s just to be told location is
    off feels slow." Built: if the cycle hasn't started (840 ms), the moon holds; the 1.2 s minimum stays.
  - **B.** Minimum loader time 0.7 → 1.1 s, so the entrance isn't cut off halfway.
  - **C.** Not "Aha up to 1.85 s later": start the run to full **as soon as the fix lands**; Aha comes in when the
    moon is at full. The 1.8 s search minimum goes; the label still gets 0.7 s (its fade-in) so it never flashes.
    Supersedes the entry below.

### 2026-10-06 · Aha waits for a full moon _(superseded above, C)_
- **Found (default-size flow pass):** the waxing hold phase was meant to make Aha reach full in ~0.3 s, but Aha starts
  after 1.8 s of searching, by which point the moon has passed full. The run-out to full then went through new
  (~1.5 s at 2.6×) while Aha's text faded in (fully in at 1.1 s): text over a dark moon. The 4/6 follow-up test
  measured from the hold phase, not where the flow actually is.
- **Decision (agent, within Tessa's "fix jumps and awkward pauses"):** run out to full under "Finding your location…";
  label out, flare and Aha only at full. Keeps the handoff's order (moon full → flare → Aha) and the never-backwards
  rule. Cost: Aha up to 1.85 s later. **Alternative for Tessa:** cut the search minimum so the moon is still waxing
  (≤ 0.88 s after the label), which keeps Aha fast but departs from the handoff's 1.8 s. LOADER.md §10.4.

### 2026-10-06 · Default-size flows and animations first; accessibility deferred
- **Decision (Tessa):** defer Build 5.9.2 step 6/6 (VoiceOver, Reduce Motion and other accessibility work) for now.
  Focus next on the main location flows and animations at default text size: fast/slow launch, messages,
  permission Allow/Don't Allow, return from Settings, retry, city search, saved-place fallback and recovery → Aha
  → main screen.
- **Review:** moon entrance, forward cycle, stop at the waxing hold phase, recovery to full, greeting timing and
  flight into the card; fix jumps, flashes, overlaps and awkward pauses. Record simulator checks and anything
  needing a real-device check.
- **Deferred, not removed:** LOADER.md §10.6 remains pending, including hiding the invisible outgoing searching
  label from VoiceOver. Preserve the completed step 5/6 small-screen and large-text layouts.

### 2026-10-06 · Hold phase mirrored to a waxing gibbous
- **Decision (Tessa):** the loader's hold phase and the onboarding moon are a waxing gibbous (~83% lit, dark sliver on
  the left), not the handoff's waning one. LOADER.md §10.2.
- **Why:** from rest the month grows toward full; Aha's run to full is ~0.2 s instead of going round through new
  (seen in the 4/6 recording, where Aha's line was in before the moon was full).

### 2026-10-06 · 5.9.2 (4/6): "Aha" after a recovery, as built
- **Spec:** LOADER.md §10.4 (as built). The loader stays over the screen during the flight, so the moon can fly
  into the card glyph's real frame; the screen fades in under it instead of the staggered load-in.
- **The loader has its own clock** (`LocationViewModel(loaderNow:)`, real time by default): its moon is drawn against
  the display's real time, and DEBUG screen states pin `now` to a fixed "today", which made the flight read as
  already over. Tests pin both.
- **Line rotation is per session**, kept in memory: persisting the last line would need a new store value (asked
  before adding).
- **Restricted** (Tessa): own body copy; button aligned with the other messages'.

### 2026-10-05 · Location flow handoff adopted, with amendments
- **Source:** Tessa's handoff `design/1.4-location-flow/`; spec LOADER.md §10 (supersedes the earlier §10 draft).
- **Amendments (Tessa):** saved place opens directly; onboarding stays for new installs (First ask = existing
  installs only); restricted: no Open Settings; offline → No fix; small screens / AX: moon and text scale down;
  moon runs the real direction; "Aha" only after a recovery, rotating lines ("Aha, there you are!", "Hey, found
  you.", "There we are."), VoiceOver reads line + city; built sizes win (140 pt moon, 17 pt label), the handoff's
  timing and flow are what matter.

### 2026-10-05 · Location off, no saved place: attempt, then an on-screen prompt
- **Decision (Tessa):** instead of the "a city" + Use my location screen, a brief phase-cycle attempt (~1.2 s), then
  the moon stops in place and "Can't find your location" + **Turn on Location** (opens Settings) move in from the
  bottom (small rise, fade in). Search for a city as a secondary link. Spec LOADER.md §10.
- **With a saved place:** unchanged; show it with the location-off note.
- **Considered:** the existing Location Off sheet over the moon (rejected: on-screen is calmer, no pop-up).

### 2026-10-05 · 5.9.1: the launch stall, fixed at its likely cause
- **Spec:** LOADER.md §9 (findings). Report `.agent-reports/5.9.1/5.9.1-launch-fix.md`.
- **Not reproduced** on the T2 iPhone; fixed at the likely cause: `locationServicesEnabled()` (a main-thread
  blocking call Xcode flagged on this device) is read only for `notDetermined` / `denied`. `LocationAuthState`
  takes it as an `@autoclosure`; no other API change.
- **4.8 retry:** skipped until `launchStage == .ready`, rather than letting `locate()` refuse to cancel a launch
  fetch: `start()` owns the launch, and a failed launch still gets its retry on the next foreground.
- **Loader month starts at a waxing crescent, 25% lit (Tessa)**, replacing 5.9's "starts at new, as the mock".
  The start is solved from the eased angle (bisection) rather than hard-coded, so it stays 25% if the curve changes.
- **Not done:** no Instruments trace. This session can't write the per-user cache folder `xctrace` needs; the
  timings came from a temporary probe (removed). The signposts stay for Tessa's own trace.

### 2026-10-05 · Launch: content loads in; the device stall is a bug
- **Decision (Tessa):** a quick launch shows the content **loading in** (sentence → card → compass, fade + 8 pt
  rise, staggered), not a whole-screen fade that reads as a scrim lifting. The background never changes. Same
  load-in after the phase cycle. Values proposed in LOADER.md §2.1.
- **Bug:** on her iPhone (existing install) the backdrop showed well past 400 ms, several seconds, and the phase
  cycle never appeared (LOADER.md §9). Any wait over 400 ms must show the moon.

### 2026-10-05 · Build 5.9 as built: launch loader
- **Spec:** LOADER.md (all sections); as built §8. Report `.agent-reports/5.9/5.9-launch-loader.md`.
- **Stage as view-model state:** `LocationViewModel.launchStage` (`waiting` → `phaseCycle` → `ready`), set only by
  the launch fetch; the screen builds the real content only at `ready`, which is what keeps the pinned bar, DEBUG
  readout, Show onboarding and "a city" off the loader (§5). Waits injected as `sleep`, like `CompassViewModel`.
- **Choices not in the spec:** the 0–400 ms screen keeps the backdrop's faint top glow (so nothing changes when the
  loader fades in); the month starts at new when the loader appears (as the mock); text at `body` 17 pt (mock 16).
- **Not done:** no failed-fetch note on a launch timeout. LOADER.md §2 mentions one, but defers to LOCATION.md §3,
  which falls back quietly. **Tessa to confirm.**

### 2026-10-03 · Launch loader simplified: the phase-cycle moon only
- **Decision (Tessa):** "There's no compass dial, just a moon loading." Under 400 ms, no loader (soft fade in);
  over 400 ms, the centred 1a phase cycle (140 pt moon, 4.8 s month, "Finding your location…"), held at least
  700 ms; 10 s timeout as LOCATION.md. Spec LOADER.md (rewritten).
- **Dropped:** the 400 ms – 2 s skeleton (sentence/card bars + quiet dial). It predated 5.4.7's two card shapes,
  and two loaders in a row read as busy.
- **Also:** the 2026-10-02 proposed timings (250 ms fades, 700 ms hold) are locked as interim values; the pinned
  compass bar is hidden while loading.
- **Direction:** the phase cycle runs forward, as the real month (lit right while waxing), not reversed as in the
  mock recording (`design/1.1/loader-1a-phase-cycle.mov`).

### 2026-10-03 · Build 5.6 [spike] as built: pinned compass bar
- **Spec:** COMPASS-1.1.md §9.6, DESIGN-1.1.md §4.1; as built §9.18. Report `.agent-reports/5.6/5.6-pinned-bar.md`.
- **Rule as a view-model state:** `showsPinnedBar` = compass shown and `isDialCentreBelowFold`. The screen reports
  the dial's centre and the fold (the scroll view's bottom edge: home indicator, or a bottom note's top) in global
  coordinates. **Sensors:** shown && (on screen || bar showing) && foreground, so the bar's heading is live even at
  AX5, where the whole compass is below the fold (DESIGN-1.1.md §4.1 asked for this rule).
- **Overlay, not an inset:** the bar floats over the content so it doesn't move the fold it's shown for (an inset
  would push the dial further down). It sits 8 pt above the bottom note's inset.
- **"Compass ↓" scrolls the compass block to the top** (readout first, dial under it): my reading of "scrolls the
  dial up under the heading".
- **At AX sizes** "readout + Compass ↓" mostly doesn't fit, so the button becomes "↓" (VoiceOver: "Go to compass")
  and the readout may shrink to 0.5×, instead of the ellipsis the first try showed. Text capped at AX1, like the
  bottom bar.
- **Fit (5.4.8 card):** at the default size the bar never shows on the iPhone 17 or the SE 3. On the SE 3 with the
  Precise / low-accuracy note, the dial's centre is only 3 pt above the note (582.5 vs 585.5). It shows at xxxLarge
  (SE 3 always; iPhone 17 with a note) and at every AX size.
- **Not built:** a compact dial in the bar (DESIGN-1.1.md "not decided"); none in the spec.

### 2026-10-03 · Build 5.4.8 [spike] as built: "After midnight" 13 pt, below the 15–20 pt range
- **Spec:** COMPASS-1.1.md §9.16 item 1; as built §9.17. Report `.agent-reports/5.4.8/5.4.8-after-midnight.md`.
- **Decision:** 13 pt Young Serif (`Theme.Fonts.missingEvent`, relative to `.title2`), one size everywhere.
- **Why below 15:** on the SE 3, moon up, the Moonrise column has 100.5 pt of text width (323 pt row − Up now 95 −
  Moonset 95.5 − two 6 pt gaps − 20 cell padding). "After midnight" is 7.56 pt wide per point: 113.4 at 15 pt, 98.3
  at 13 pt. Any size in the range either wraps (the card grows ~20 pt again) or needs the other columns shrunk;
  item 1 rules out both.
- **Considered:** 15 pt and wrap on the SE 3; trimming the missing cell's 10 pt padding (only reaches 14.6 pt);
  sizing per phone (16 pt on the iPhone 17, 13 pt on the SE 3). **Tessa to pick** between 13 everywhere and per phone.
- **Slot:** it holds a time's slot and baseline (a hidden time-sized sample, like "Up now"), so "Sun 12:20 AM" stays
  on the directions' line and the card keeps its height.

### 2026-10-03 · Build order: 5.4.8 + 5.6 in one run; 5.5 AX reflow last
- **Decision:** build 5.4.8 ("After midnight" smaller, COMPASS-1.1.md §9.16 item 1) and 5.6 (pinned bar, §9.6) in
  the same agent run, 5.4.8 first, **one commit each**. Then 5.9 launch loader, then **5.5 AX reflow last**.
- **Why:** 5.4.8 is small, and Tessa's device check after 5.4.7 (§9.16) clears 5.6's gate. 5.4.8 goes first because
  it changes the no-rise day's card height, which moves where the dial sits and so when the pinned bar shows.
- **AX in 5.6:** build the bar at AX sizes as far as the current layout allows and report what breaks; fixing it
  is 5.5's job, not a blocker for 5.6.
- **Changes:** STATUS.md had 5.9 before 5.6; 5.9 now follows 5.6.

### 2026-10-03 · 5.4.8: smaller "After midnight"; ‹ › bug parked
- **Decision:** "After midnight" / "Not today" get their own smaller Young Serif size (15–20 pt, largest that fits one
  line on the SE 3), so the no-rise day no longer scales every column to 80% and wraps. Spec: COMPASS-1.1.md §9.16
  item 1.
- **Parked:** the ‹ › bug is back (the tapped arrow floats ~40 pt above the card and slides back; frames
  `design/bugs/arrows-float-frames.png`). Written up with suspects and a day-stepping test in §9.16 item 2 and
  DESIGN-REVIEW.md "Date control"; Tessa will come back to it later.
- **Why:** Tessa on device after 5.4.7: the wrapped "After midnight" was too big.
- **Considered:** 70% for that cell only, or "Sun 12:20 AM" in the label slot (5.4.7 report options).

### 2026-10-02 · Build 5.4.6a [spike] as built: compact card header, Up now pill
- **Spec:** COMPASS-1.1.md §9.2. Choices the spec left open:
- **Padding:** 12 pt on all four sides (the spec said 16 → 12; horizontal was 18). Rise/set "hug content" read as
  dropping the cells' 76 pt minimum height; the cells keep equal widths so the lock outlines match.
- **Phase line:** "Last Quarter · 53% lit" on one line, else the name over "21% lit" (long names like Waning
  Crescent don't fit beside the glyph and ‹ › on a 402 pt phone); a wrapped "·" at a line's end looked broken.
- **AX sizes:** glyph and ‹ › on one row, the date and phase lines full width under them (squeezed between, the
  text wrapped a word per line).
- **Moon down, no rise found:** the line is hidden (the spec drops "Below the horizon", leaving nothing to say).
- **Copy:** "Rises 10:06 PM" on screen (was "Rises at …"); VoiceOver still says "rises at".
- **Kept for now:** `UpNow.Pass.progress` and `UpNow.title` "Below the horizon" are no longer shown; left in the
  model to keep this step small. Remove when 5.4.6 settles.

### 2026-10-02 · Build 5.4.6b [spike] as built: dial 260 pt by width, gaps, short needle, even labels
- **Spec:** COMPASS-1.1.md §9.1, §9.3, §9.7, §9.10; as built in §9.11. Fit: `.agent-reports/5.4.6/5.4.6b-fit.md`.
- **Dial sized by width, 260 pt on a 402 pt phone (233 on the SE 3), not ~300:** the side labels sit outside the
  arc, so face radius + 16 arc gap + 7 dot + 10 label gap + ~38 label must end inside the screen. Height wasn't the
  limit: on the iPhone 17 the whole dial, labels included, ends 12 pt above the screen's bottom (22 pt into the
  home-indicator area). Considered: labels inside the arc at the sides (back to 5.4.3-style clutter), a fixed 300 pt
  dial (labels off screen), a 238 pt face that clears the home indicator (smaller than the mock). **Tessa to check
  on device** whether a label in the home-indicator band is OK.
- **Gaps:** 28 / 32 / ~35 pt (§9.7); the dial's frame reserves a label's height above the arc, which is most of
  the readout → needle gap.
- **Needle:** built to §9.10's endpoints (43 pt); its "~28 pt" estimate doesn't match those endpoints.
- **Moon at 12 on lock:** drawn at the heading (within the lock's 5° / 8°), over the needle.
- **"After midnight":** the next day's `MoonDay`, no new `MoonService` method. FR2, ASTRONOMY.md, DESIGN-1.1.md
  §3.2 and DESIGN-REVIEW.md updated.
- **DEBUG `-screenState <kind>`** (`DebugScreenState`): opens the app on one faked compass state (13 kinds), so the
  real app can be screenshotted on any simulator and text size; previews can't pick the device and the simulator
  has no compass. Compiled out of release builds, like `-forceOnboarding`.

### 2026-10-03 · Build 5.4.6c [spike] as built: bottom bar, held note, text cap
- **Spec:** COMPASS-1.1.md §9.4, §9.12; as built in §9.13. Report: `.agent-reports/5.4.6/5.4.6c-bar.md`.
- **Use Precise beside the text below AX sizes, under it at AX sizes**, chosen by text size: `ViewThatFits` judged
  the wrapping text by its one-line width and always stacked (127 pt bar).
- **Bar text capped at AX1** (my call; Tessa to confirm): uncapped, AX5 bars covered half the iPhone 17 and three
  quarters of the SE 3. Considered: a scrolling bar (fiddly for a short note), no cap.
- **Held note while the sensors are paused:** the inset can cover the compass enough to stop the sensors, which
  cleared the note and made the bar flicker. The last note stays until the next reading. Considered: measuring the
  compass's visibility ignoring the bar (no clean way with `onScrollVisibilityChange`).
- **Stale 5.4.6b tests fixed** on their first run: call counts with the next-day lookup, Mar Vista next rise 12:22 AM
  (the engine's value; STATUS's "00:21" was approximate). No tolerance changed.

### 2026-10-03 · Build 5.4.7 [spike] as built: three columns, hidden twin, AX pill fallback
- **Spec:** COMPASS-1.1.md §9.14; as built in §9.15. Report: `.agent-reports/5.4.7/5.4.7-upnow.md`.
- **Saves 46 pt, not ~34:** the pill's 36 plus the card's 10 pt spacing above it.
- **Equal height by a hidden twin:** the row lays out the other state (down: three columns with a placeholder
  "359° NNW") hidden underneath, so up and down take the taller height at any size. Considered: a fixed minimum
  height (breaks with Dynamic Type), measuring both and storing the max (two passes, flicker).
- **Rise and set hug their ends in both states** (7a, 7c), so Moonset doesn't move when the moon rises; lock outlines
  now hug the cell instead of half the row. Where two hugging cells don't fit, the 5.4.6c halves.
- **Fit ladder:** connector at 100% → no connector at 100 / 90 / 80% → at the default size, wrap at 80%; at other
  sizes, the pill fallback. AX1 and AX5 take the fallback on both phones, read Moonrise → Up now → Moonset.
- **Connector needs 12 pt of line + 4 pt clear each end:** hidden on the SE 3 at the default size (15.75 pt gaps).
  Dots 2 pt / 5 pt (the card's scale), at the arc's colours; the down line `accent` 40% as specified.
- **`UpNow.line` replaced by `UpNow.pillText(bearing:)`:** the down line is gone. Three line tests became two.
- **Fixed on the way:** AX5 cut the Moonrise direction to "57° E…" in the two halves, also without 5.4.7's
  changes (likely since 5.4.6c's fill-to-row-height). The direction and next-time lines take their own height.
- **Open (Tessa):** no-rise day wraps all three columns at 80%; no connector on the SE 3; moon down no longer speaks
  the next rise in VoiceOver; AX1 "midnigh / t" (before 5.4.7).

### 2026-10-03 · 5.4.7: Up now moves between Moonrise and Moonset
- **Decision:** Remove the Up now pill row. With the moon up (today only) the rise / set row becomes three columns:
  ↑ Moonrise · Up now · ↓ Moonset, the phase glyph on a connector line (solid rise → now, dotted now → set) and the
  live bearing under "Up now". Lock on the Moon outlines that cell. Moon down or other dates: two columns joined by a
  dotted line at 40%; the "Rises …" line is dropped. Card height equal in both states. Spec: COMPASS-1.1.md §9.14;
  mocks `design/1.3-upnow/` 7a–7c.
- **Why:** Wins back ~34 pt of vertical space for the dial without touching anything else on the screen.
- **Considered:** Keeping the pill row (costs the space); a middle column with no connector (the mock reads better
  with it). Open: tonight's rise shown left of "Up now" in the morning; Tessa judges from the screenshots.

### 2026-10-03 · After 5.4.6b on device: readout size, capitals, "After midnight" font, needle, one-line phase (Tessa)
- **Spec:** COMPASS-1.1.md §9.12, built with 5.4.6c.
- Readout and lock pill at the card time size (Young Serif 24); direction letters real capitals at 0.7x, not small caps.
- Missing rise/set: labels aligned with the other column; "After midnight" in the time font.
- Needle ~28 pt. Phase line always one line (0.7x, then drop " lit"). Bottom label near the home indicator: accepted.

### 2026-10-02 · After 5.4.6a on device: card, lock pill, needle, "After midnight" (Tessa)
- **Spec:** COMPASS-1.1.md §9.10, built with 5.4.6b.
- Phase line on one line (shrinks to 0.85x); label → time gap ~2 pt; lock pill and readout 20 pt with small direction
  letters (like AM/PM); needle only reaches the major ticks; dial bigger (§9.3).
- **"No moonrise today" → "After midnight"** with the next time under it ("Sun 12:20 AM"); cells top-aligned.
  "Not today" if the next event is over a day away (polar). Supersedes the FR2 wording.

### 2026-10-02 · 5.4.6 layout pass: bigger dial, compact card, notes in a bottom bar, pinned-bar rule (Tessa)
- **Spec:** COMPASS-1.1.md §9 (replaces the A / B / C spacing options). Source: `design/1.2-layout/` (Tessa's mocks).
- **Card:** one header row (glyph · "Today · Fri, Oct 2" over "Last Quarter · 53% lit" · ‹ ›); "at midnight" dropped
  visually, kept in VoiceOver; tighter rise/set, AM/PM stays small; Up now becomes a one-line pill ("● Up now · 266° W"),
  "● Rises 11:10 PM" when down. No progress bar.
- **Compass:** bigger dial (~300 pt face target), shorter needle, Moon glyph at 12 o'clock on lock, even label gaps,
  more space between sentence / card / readout / dial, paid for by tightening. Degree numbers stay Nunito Sans.
- **Notes:** Precise off, low accuracy (one copy line), aha and Nearby move to a fixed bar above the home indicator;
  the dial dims in place. **Reverses 5.4.3** (notes under the readout). Precise copy: "Using your approximate location.
  Precise gives a better reading." + **Use Precise**.
- **Pinned bar (closes §6):** shows when the dial's centre is below the fold (SE, AX); "Compass ↓" scrolls to it;
  amber on lock; sits above a bottom note. Built as 5.6.
- **Kept:** "today" (mocks say "tonight"), real phase glyph, rise/set lock outline, location off / Far as built.
- **Why:** on device (5.4.5) the dial ran ~90 pt below the fold and felt too small; the notes pushed it further.

### 2026-10-02 · Launch loader by wait time: fade, skeleton, phase cycle (Tessa)
- **Spec:** LOADER.md (Step 5.9, build after 5.4.6). Source: `design/1.1/Moon Signal Loader.dc.html`.
- **Under 400 ms:** no loader; the main screen fades in softly.
- **400 ms – 2 s:** skeleton of the main screen (concept 1c), with **the city and date tokens as skeleton bars**:
  the location isn't known yet. Supersedes LOCATION.md §89's last-viewed name as a placeholder.
- **Over 2 s:** the onboarding moon's **phase cycle** (concept 1a), for new and returning users; shown at least 700 ms.
- **10 s:** timeout as LOCATION.md. Concept 1b and 1c's orbit-and-settle are not used.
- **Why after 5.4.6:** the skeleton copies the final main-screen layout.
- **Later:** transitions get an app-wide polish pass (DESIGN-REVIEW.md "Motion and feedback").

### 2026-10-02 · Compass sensors start when any part is visible; spacing pass after 5.4.5 (Tessa)
- **Bug (device, after 5.4.1):** the Up now row pushed the dial partly below the fold, and the sensors only start at
  SwiftUI's default 0.5 visibility threshold, so the dial stayed frozen (blank readout, dimmed marks) until scrolled.
- **Fix now:** `onScrollVisibilityChange(threshold: 0.1)`; COMPASS.md §1 "on screen" = any part visible
  (COMPASS-1.1.md §5a).
- **Spacing later:** build 5.4.2–5.4.5 unchanged, then **5.4.6 spacing pass** (COMPASS-1.1.md §9) on the finished
  screen: tighten first (option A), dial 180 pt or a merged header only if needed. Then the pinned-bar rule.
- **Why wait:** the needle, accuracy note, outside labels and new sentence all change the heights.

### 2026-10-02 · Compass sensors start when any part of it is visible (Tessa)
- **Decision:** COMPASS.md §1 "on screen" means **any part of the compass visible**, not half of it.
  `onScrollVisibilityChange(threshold: 0.1)` in `LocationScreen` (was the default 0.5); `onDisappear` still
  stops the sensors on removal.
- **Why:** with the card taller (Up now) and the dial lower, the dial often peeks above the fold at the default
  size; at 0.5 it showed but stayed off (no heading, no lock, no Up now tick) until scrolled halfway in.

### 2026-10-02 · Compass 1.1: Up now row, needle and ticks, labels on the arc, accuracy notes under the readout, "today" (Tessa)
- **Spec:** COMPASS-1.1.md (5.4.1–5.4.5, build before 5.5). Source: `design/1.1/Moon Signal Compass 1.1.dc.html`.
- **Card:** new **Up now** row (live bearing; bar from last rise to next set with the moon glyph as thumb; "Below
  the horizon · Rises in …" when down; hidden on other dates). On lock the matching cell is outlined amber.
- **Dial:** needle from under the readout into the ticks (replaces the capsule); ticks every 2° / 10° / 30°;
  fixed-size degree numbers every 30° (Nunito Sans 11 pt, no Dynamic Type, hidden from VoiceOver); cardinals in
  Young Serif; fixed crosshair; readout 24 pt locked and unlocked.
- **Targets:** "↑ Rise", "↓ Set", "Now" labels outside the arc (locked one drops its label; "Now" wins a
  collision); pulse ring on the Moon until the first lock this launch, static ring under Reduce Motion.
- **Accuracy notes** (low accuracy, Precise Location + its button, aha line) move **under the readout**: no lock
  is possible then, so the space is free. Nearby stays below the dial.
- **Sentence:** "Where can I find / the moon 📅 [date] / in 📍 [city]?" (supersedes the 2026-10-01 "Where will
  the moon / be … / in …" lines); fit rule unchanged, never an ellipsis. Date token **"today"** replaces "tonight".
- **Considered:** the mock's fixed three lines with an ellipsis (hides the city, fights AX reflow); "now" as the
  date token (a moon state, not a date; wrong when the moon is down); IBM Plex Mono numbers (a third font, 10 pt).
- **Open:** the pinned bar's rule now that the dial sits lower (decide before 5.5); drop the Up now end times if
  the two rise times confuse on device.
- **As built, Build 5.4.1 [spike], Up now row:**
  - **One source with the dial.** `CompassViewModel.upNow` is built from the same position, pass and 30 s tick as
    the live Moon target, so the card's "266° W" and the lock pill can't differ by a tick. So the row shows
    exactly where the Moon target can: **today with the compass shown** (Here / Nearby). It's hidden with
    location off, in Far, and with a searched city that hasn't been matched to a detection yet (the simulator's
    usual state). **To decide:** whether it should show for any place (it's about the place, not where you are).
    That would need its own foreground tick, since the compass's tick runs only while its sensors do.
  - **Refresh:** on context change (place, day, permission), foreground, and the compass's tick. While the compass
    is off screen (e.g. below the fold on a small phone) the row holds its last values ("Rises in 34 min" stops
    counting) until one of those happens.
  - **Next rise:** a new `MoonService.nextMoonrise(for:after:)`, the table's rise search run forward from now
    (Astronomy Engine, 30-day reach). Looked up once per down spell, and again a minute after it passes.
    Copy beyond the three proposed: rising after tomorrow (tomorrow has no moonrise) reads "Rises Sun 12:05 AM";
    nothing in reach leaves the right side empty. The countdown rounds up, so never "0 min".
  - **Bar:** times in the place's zone with no zone abbreviation (11 pt); thumb is the card's phase glyph, 14 pt,
    in a 1.5 pt `surface` ring with an amber glow, kept inside the bar's ends. At AX sizes the headline and the
    bar stack (bar over the two times). Moon down keeps the bar's line, hidden, so the height doesn't change.
  - New tokens: `surfaceInset` `#251C22`, `faint` `#5E4D57` (decorative), `Fonts.caption` (11 pt, `.caption2`).
- **As built, Build 5.4.1 [spike], lock highlight:** `MoonCardCell(lockedOn:)` maps the compass's lock to a cell (rise → Moonrise,
  set → Moonset, Moon → Up now). Every cell is now a padded box (8 / 10, radius 14) with a clear 1 pt border, so a
  lock changes only colours. To give the outline room, **Moonrise and Moonset are boxes 6 pt apart, as in the
  HTML, and 5.2's hairline divider between them is gone**; the cells reach 6 pt into the card's padding, so their
  text sits 5 pt inside the header's (the HTML's offset). The two boxes match heights. Amber label on the
  highlight fill: about 8.7:1.
- **As built, 5.4.2 dial:** readout was already Young Serif 24 unlocked and in the pill (`Fonts.display`), no change.
  Ticks are four paths (2° / 10° / 30° / N) from 1 pt inside the rim, lengths 7 / 11 / 15; numbers 72 pt out,
  `dialNumber` `#A8939C` (5.1:1 on `dialTop`); cardinals 58 pt out (were 64), E/S/W now `textPrimary`. The needle
  starts where 5.4's capsule did (the same 17 pt lead, so the dial doesn't move) and ends 12 pt inside the rim, as
  deep as a mid tick. Until 5.4.4 the old ↑ / ↓ inside the rim overlap the numbers near them. Shimmer: device check.
- **As built, 5.4.3 accuracy notes:** the status line (low accuracy, Precise Location, aha) and Use Precise Location
  sit between the readout and the dial, 10 pt under the readout (the notes' own spacing), so the dial and its needle
  move down while they show; with nothing to say there's no gap. Nearby stays 14 pt under the dial. No spacing
  values changed. Placement is two view slots fed by the existing `statusLineText` / `offersPreciseLocation` and
  `nearbyNote`, so §8's placement check is the previews, not a unit test.
- **As built, 5.4.4 labels + pulse:** `CompassTargetLabels` decides the labels: locked drops its own; within 15°
  "Now" keeps its label, and rise beats set if those two collide (near the poles only; not in the spec). Labels sit
  138 pt out (24 beyond the track), Nunito 700 12 pt fixed, `textBody` with a `bg` halo; at 3 / 9 o'clock they
  reach ~160 pt from the centre, inside a 353 pt block. At 3 / 9 o'clock "Now" nearly touches the Moon's disc (the
  HTML's geometry). The ↑ / ↓ inside the rim are gone. Pulse: `CompassViewModel.showsMoonPulse` (Moon target present
  and `hasLockedThisLaunch` false; the flag is set on the first lock and never cleared). Ring radius 10 → 24 pt,
  2 pt `accent`, 0.8 → 0 over 1.8 s; Reduce Motion: a still ring at 17 pt.

### 2026-10-01 · Show onboarding button also in TestFlight builds (Tessa)
- **Why:** testers (and Tessa on a phone without Xcode) need to see onboarding again without deleting the app
  and resetting location and privacy. Launch arguments don't exist in TestFlight, so the button is the way.
- **Decision:** the "Show onboarding" button (DECISIONS.md 2026-10-01 "DEBUG onboarding trigger") also shows in
  **TestFlight** builds. It stays hidden in App Store builds.
- **How:** a runtime check, not a build setting: show it when `DEBUG`, or when
  `Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"` (TestFlight; App Store builds have
  `receipt`). One small `BuildChannel` helper (`isTestFlight`) so the check lives in one place and is
  testable with an injected URL. The launch arguments (`-forceOnboarding`, `-onboardingPage`) stay DEBUG-only.
- **Same rules:** it opens the same forced flow and never writes stored state (no completed flag, place or
  permission). Text-link style, 44 pt, at the bottom of the main screen.
- **Release check changes:** the button text and its code are now **in** the Release binary on purpose. What must
  stay out of Release: the launch-argument names. With an App Store receipt the button is not shown.
- **Temporary:** remove the button and `BuildChannel` before the 1.0 App Store build (STATUS.md).
- **Tests:** `BuildChannel` with `sandboxReceipt`, `receipt`, nil; the button's visibility in each; a forced run
  from the button still writes nothing.
- **As built:** `BuildChannel` (`isTestFlight`, `showsOnboardingButton`, plus forms taking the URL and DEBUG flag
  for tests). The forced flow (`OnboardingViewModel.forceShow`, was `debugShow`) and its two flags are now compiled
  in Release; the app passes the button's action only when `BuildChannel.showsOnboardingButton`. Launch-argument
  parsing stays in `#if DEBUG`.
  - **One warning:** `Bundle.appStoreReceiptURL` is deprecated since iOS 18 (StoreKit's `AppTransaction` is the
    replacement, async). Kept as decided, read in one place.
  - **Release check:** `nm` finds 0 symbols for the launch-argument code (Debug: 20). `strings` finds 0
    `-forceOnboarding`. **`strings` can't check strings of 15 bytes or fewer** ("Show onboarding",
    `-onboardingPage`, `sandboxReceipt`): Swift keeps them inline in the code, so 0 hits there means nothing,
    which also applies to the build 3 `-onboardingPage` check. Symbols are the check that counts.

### 2026-10-01 · Onboarding: Location Services off sends Use my location to Settings, not "That's okay" (Tessa)
- **Bug (device):** with location off, tapping Use my location on the upsell lands on "That's okay". The view
  model maps every non-authorized answer (`.denied`, `.restricted`, `.servicesOff`) to `locationDeclined`, but §5
  says "That's okay" follows **Don't Allow** only. With Location Services off the system can't show the prompt,
  so nobody declined anything.
- **Fix:** `useMyLocation()` reads the state **before** requesting.
  - `.notDetermined` before, `.denied` after: a real Don't Allow → "That's okay" (unchanged).
  - `.servicesOff` (before or after), or `.denied` when it was already denied before the tap (no prompt could
    show): **open the app's Settings page** (`UIApplication.openSettingsURLString`, as "Enable location" does) and
    **stay on the upsell**. Back in the foreground: authorized → main screen as for Allow (the existing
    Settings-return rule, extended to the upsell); still off → stays on the upsell, tappable again.
  - `.restricted` (parental controls / MDM): Settings can't help; keep "That's okay" for now.
- **Limit:** the public API only opens Moon Signal's own Settings page, not the top-level Location Services
  switch (Privacy & Security > Location Services). Copy for that is a later design question.
- **Tests:** per case above (before/after states, Settings opened once, stays on the upsell, return authorized,
  return still off, real Don't Allow unchanged), on `FakeLocationService`.
- **Spec:** DESIGN-1.1.md §5 updated.
- **As built:** `OnboardingViewModel.useMyLocation()` doesn't request at all when the state is already `.denied` or
  `.servicesOff` (no prompt could show); it bumps `settingsRequestCount`, which `OnboardingView` turns into the
  Settings URL, as "Enable location" does. The upsell's Settings return only applies after that trip, so a forced
  upsell with location allowed doesn't close itself. 7 new tests.
- **Simulator (iOS 27):** the Settings URL brought Settings forward on whatever page it was last on (or its home
  screen), not Moon Signal's page; "Enable location" uses the same URL. **Check on device.**

### 2026-10-01 · DEBUG onboarding trigger for testing (Tessa)
- **Why:** onboarding only shows on a fresh install, so testing it means deleting the app. A temporary DEBUG
  button/launch argument lets us see it any time (and on TestFlight-style device builds from Xcode).
- **Launch arguments (DEBUG only, not in Release, like `-resetOnboarding`):**
  - `-forceOnboarding`: show onboarding regardless of saved place, permission and the completed flag.
  - `-onboardingPage landing|upsell|declined`: start on that page (default landing).
  - Neither changes any stored state: no flag written, no place cleared, no permission touched. Finishing
    onboarding in a forced run returns to the normal app as usual but leaves `onboardingCompleted` as it was.
- **Also:** a small "Show onboarding" button in a DEBUG-only spot on the main screen, for devices where launch
  arguments are awkward. It opens the same forced flow. Compiled out of Release (check with `strings`, as for
  `-resetOnboarding`). **Temporary:** remove before the 1.0 App Store build.
- **Tests:** a DEBUG-only unit test per argument; the forced run never writes the store.
- **As built:** `OnboardingViewModel.applyDebugLaunchArguments(_:)` (called by the app at launch) and
  `debugShow(startingAt:)` (the button, at the bottom of the main screen under the compass readout, text-link
  style). A forced run skips the completed-flag write on every exit; everything else (outcome, return to the main
  screen, `start()`) is as usual. `-onboardingPage` alone also picks the page of a natural first run, but doesn't
  make it forced. Unknown page names mean the landing.
  - **(new) Forced "That's okay" while location is allowed** stays up: its Settings-return rule would otherwise
    close it the moment the scene became active. A real Settings return in a forced run (denied at the prompt,
    then allowed) still goes back to the app.
  - Release check (`strings`): `-forceOnboarding`, `-onboardingPage`, "Show onboarding" and the DEBUG method names:
    0 hits; the Debug binary has them; control `onboardingCompleted` present.

### 2026-10-01 · 5.8 moon arc: as built
- **Data:** new `MoonPass` model (rise, set, azimuths every 15 min, unwrapped) and
  `MoonService.moonPass(for:containing:)`: the latest rise before the moment to the next set after it, with the
  same rule as `moonPosition`'s "up", so a pass exists exactly when the Moon target does. Sampling stays in
  `AstronomyEngineMoonService` (the only C API caller). `CompassViewModel.arc` (`CompassArc`) is what the dial
  draws; the 30 s tick only moves the Moon along it and looks the pass up again only when the moon rises or sets.
- **Which pass:** moon up: the pass containing now. Otherwise (moon down, or another day): the pass containing
  a minute after the selected day's moonrise. Taken literally from §3.3a, so on today after the moon has set,
  the arc is today's finished pass (dimmed), not tomorrow's.
- **Rise/set dots are the targets, not the arc's ends.** Each dot sits on the arc's track at the selected day's
  moonrise / moonset bearing (the lock, the card and VoiceOver all use those). Usually that's exactly an arc end.
  On a pass that starts the day before or ends the day after, the arc's end and the day's dot can be a few
  degrees apart. **Open for Tessa:** keep this, or move the dots to the pass's own ends (the lock and the card's
  times would then disagree on those days).
- **No moonrise, moon down:** no arc; the moonset dot still shows (dimmed) on the track, since it's still a
  lockable target. §3.3a's "no markers" was read as "no arc markers".
- **Locked Moon:** grows 24 → 28 pt (the 22 pt locked size would shrink it). The bg disc grows with it.
- **Dimmed marks:** dot and glow are grouped, then backed with `bg`, so a 30% dot reads as one dim dot and the
  arc's end dot doesn't show through.
- **Size:** the dial view is 260 × 277 pt (radius 130 all round, plus the 17 pt capsule). 5.4's was 220 × 230,
  so the block is **~47 pt taller**, not §3.3a's 25 to 30 (that estimate started from ~250). Not shrunk to
  180 pt: not yet checked on a small phone.
- **Halo vs arc:** in the screenshot the halo barely shows past the face (it reaches 116 pt, the arc is at 114),
  so it doesn't fight the arc. Left as is; review `4-locked-on-moonrise.png`.

### 2026-10-01 · Tap animation on buttons: go, spec (Tessa)
- **Decision:** build the pressed-state animation from DESIGN-REVIEW.md "Motion and feedback" now, after the
  DEBUG onboarding trigger and before 5.5.
- **Look (proposed, tune on device):** scale 0.96 + opacity ~0.8 while pressed, quick spring (~0.15 s) back.
  **Reduce Motion:** opacity only, no scale.
- **Where:** the shared styles (`PrimaryButtonStyle`, `SecondaryButtonStyle`, `TextLinkButtonStyle`), so every
  button picks it up; also the ‹ › day buttons and the sentence tokens, which don't use those styles today.
  No per-view animation code.
- **As built:** one `PressFeedback` modifier (`Theme/PressFeedback.swift`: scale 0.96, opacity 0.8,
  `.spring(duration: 0.15)`), applied by `PrimaryButtonStyle`, `SecondaryButtonStyle`, `TextLinkButtonStyle` and
  the card's `DayStepButtonStyle` (the circle shrinks, not its 44 pt target). It replaces each style's own pressed
  opacity (0.75 / 0.6 / 0.6 / 0.6), so the dip is a little lighter than before. Reduce Motion: opacity only, still
  animated (a fade isn't motion). Disabled opacity unchanged.
  - **Not done: the sentence tokens.** They're links inside one `Text` (that's how the sentence wraps and fits,
    §3.1a), so SwiftUI gives no per-token pressed state to animate. **Open for Tessa:** leave them (the system
    link tap is the feedback); or dim the whole sentence while a token is pressed; or rebuild the tokens as real
    buttons, which would mean redoing the sentence's layout and fit rules.

### 2026-10-01 · Moon marker: rise-to-set arc outside the dial, option B, 24 pt glyph (Tessa)
- **Why:** device check: the ~20 pt mini glyph is hard to tell apart from the cream rise/set dots on the rim.
- **Decision:** from the arc mock-ups (`design/1.1/moon-arc-mockups.html`), **option B**: a dotted amber arc
  outside the rim from moonrise to moonset, the moon glyph (**24 pt**) riding on it, the part already travelled a
  faint hairline and the rest dotted. Rise and set dots move to the arc ends; the rim keeps ticks and letters.
  Dial 196 pt. Spec: DESIGN-1.1.md §3.3a. New build item **5.8**, before 5.5.
- **Also decided in the spec:** the heading capsule moves outside the arc; moon down shows the next pass dimmed
  with no glyph; the path is drawn from sampled azimuths (so southern-hemisphere and near-overhead passes go
  the right way round); VoiceOver unchanged.
- **Cost:** the compass block grows about 25 to 30 pt in height (about 277 pt against about 250 pt). Shrink the
  dial to 180 pt first if it pushes the compass too far down on small phones.
- **Open:** the lock halo (amber) against the amber arc, checked on a screenshot; the 5.6 pinned bar's compact
  dial; AX 260 pt dial proportions (5.5).
- **Considered:** A (arc without the travelled hairline), C (rise/set dots stay on the rim, lighter arc with end
  caps). B was picked for showing how much of the pass is left.

### 2026-10-01 · 5.7 onboarding: placeholder copy, Settings return, completed flag (Tessa)
- **Copy:** the mockup's copy ships as-is in 5.7 (`Moon Signal Madlib 1.0.dc.html` §3d: tagline, upsell, info box,
  "That’s okay"; including its missing final period). It's the designer's placeholder; final copy comes later and
  swaps in one file, `Features/Onboarding/OnboardingCopy.swift`.
- **(new) Back from Settings:** after Enable location, "That's okay" stays up. If permission is authorized when the
  app returns to the foreground, onboarding goes to the main screen as for Allow; otherwise it stays.
- **(new) Completed flag:** onboarding shows only with no saved place **and** permission not determined **and**
  onboarding not yet completed. Any exit (Allow, Got it, Search instead, the Settings return) sets the flag, so
  Search instead → Cancel → relaunch (still no place, still not determined) doesn't show it again. Stored by
  `OnboardingStore` (`UserDefaults` key `onboardingCompleted`); DEBUG builds clear it with the launch argument
  `-resetOnboarding`.
- **As built:** `OnboardingViewModel` decides show/skip and the steps and reports an `Outcome` to
  `LocationViewModel.onboardingDidFinish(_:)`; the app root swaps onboarding for `LocationScreen`. Allow (Allow Once
  included) and the Settings return both run the normal launch flow (`start()`, a launch fix, so the detected city
  isn't saved as last-viewed, as on any launch). Search instead opens the search sheet from `start()`. A prompt
  dismissed with no answer stays on the upsell. The moon on each screen is the 5.2 `PhaseGlyph` (fixed waning
  gibbous, as drawn, on `bg`, glow scaled to size). New `PrimaryButtonStyle`, `TextLinkButtonStyle`.
- **Order:** 5.7 is built before 5.5 (AX reflow) and 5.6 (pinned bar), which are deferred until after it.
- **Considered:** a full-screen cover over the main screen (its dismissal would have to finish before the search
  sheet could present); keeping the flag in `PlaceStore` (not about places).

### 2026-10-01 · Rise/set times: smaller day period, found by its date field (Tessa)
- **Look:** "PM" in Young Serif at 60% of the time's 24 pt (`Theme.Fonts.dayPeriod`, relative to `.title2` like
  the digits, so both scale together), same `textPrimary`, baseline-aligned in one `Text`. Digits and the zone
  abbreviation unchanged.
- **How it's found:** `Date.FormatStyle`'s attributed output marks the day period as the `.amPM` date field;
  `TimeText` splits on that, never on the string "AM"/"PM". Checked: en_US "9:10 PM", ar_EG "٧:١٣ ص" (last),
  ko_KR "오후 9:10" (first), en_GB / de_DE / ja_JP / zh_CN 24-hour (no day period, nothing shrinks).
- **Deprecated API, on purpose:** `Date.FormatStyle.attributed` warns ("deprecated in iOS 18: use
  `attributedStyle`"). Its replacement tags runs with `DateFormatFieldAttribute`, which has no reachable key from
  Swift here: no `dateFormatField` dynamic member, and subscripting by the attribute type crashes the Swift 6.4
  compiler. So `attributed` stays, the build has this one warning, and switching is a one-line change once the
  key is usable.
- **Wrapping:** the card draws the formatter's narrow no-break space as an ordinary space and gives the
  concatenated `Text` the display font as its base. Without both, at AX sizes the time was truncated ("10:06…")
  or broke inside "AM". The plain `time(_:in:)` string (VoiceOver, tests) keeps the formatter's spacing.
- **Considered:** matching "AM"/"PM" text (fails in ko, ar); `Text(date, format:)` (no per-field styling).

### 2026-10-01 · §11 Q4 revised: the live Moon marker is a mini phase glyph (Tessa)
- **Why:** on device, the plain 18 pt Moon dot read as a second moonrise target (same colour and shape as the
  rise/set dots, just bigger).
- **Marker:** the moon card's `PhaseGlyph` at ~20 pt: the same lit fraction and elliptical terminator, `moonLit`
  fill over a dark disc, the card's soft glow. Its phase comes from the selected day's `MoonDay` (midnight
  illumination, phase angle), so it always matches the card. Placed, not rotated, so it stays upright as the
  dial turns; no arrow.
- **Locked:** like the other targets: grows to 22 pt, 4 pt `accent` ring, strong glow. The pill stays "Moon · 275° W".
- **VoiceOver:** the dial reads the Moon as "Moon now, west, 275 degrees" (direction first, as the moon card
  does); rise/set entries are unchanged. The lock label ("Pointing at moon, 275 degrees west") is unchanged.
- **Considered:** a ring or outline dot (still a dot); a moon emoji or SF Symbol (doesn't show tonight's phase).

### 2026-10-01 · Madlib sentence: "Where will the moon be…", new breaks, default-size fit rule (Tessa)
- **Copy:** **"Where will the moon be [date] in [city]?"**, the spec's original wording (§3.1), replacing
  "Where can I find the moon [date] in [place]?". VoiceOver header to match ("Where will the moon be tonight
  in Los Angeles, CA?"). Supersedes the copy in "Madlib copy, fixed three lines" below.
- **Three forced lines:** "Where will the moon" / "be 📅 [date]" / "in 📍 [city]?". The block still reserves
  three full-size lines, so the card doesn't move.
- **Fit rule, default Dynamic Type size (`.large`) only:** all three lines share one scale, the smallest any
  line needs to fit on one line, **minimum 0.7× (about 19 pt)**. Below that the scale holds at 0.7 and that line
  wraps. This replaces 5.3 fix 1's 0.8 minimum, and its "a line that can't fit doesn't set the scale" exception.
  That exception existed for AX sizes, which no longer shrink.
- **Every other size (smaller or larger, AX included):** no shrinking. The text scales with Dynamic Type as before,
  and long lines wrap. At these sizes a token may break between its words, so a city wider than the line wraps at a
  space instead of inside a word. At the default size tokens stay whole (non-breaking spaces, §3.1).
- **Always attached:** each icon to its token's first word (non-breaking space); the "?" to the city (no space,
  and line breaking never breaks before "?", UAX #14). **Not** a U+2060 word joiner: with one, any line that had to
  shrink never finished laying out (previews hung until it was removed).
- VoiceOver order unchanged: the sentence (header), then "Date, …" and "Place, …" buttons.
- **Considered:** keeping the 0.8 exception (lets two lines stay bigger while one wraps, but they no longer match,
  and the rule asks for one size); shrinking at every non-AX size (would undo a reader's smaller/larger choice).

### 2026-10-01 · 5.4 compass restyle: as built
- **Still face, moving marks:** the face doesn't rotate; ticks, letters and target dots are placed at
  azimuth − heading. Letters and ↑/↓ stay upright without counter-rotation, and the face's gradient light
  stays at the top as in the HTML. On screen it moves like the old turning dial. Still not animated
  (a 359° → 0° turn would spin the long way); only the lock change animates, and not with Reduce Motion.
- **Readout slot holds still:** 40 pt (scaled with `.title2`) with the pill overflowing it, as the
  HTML's 42 px pill overflows its 40 px slot. Young Serif's line height makes our pill ~51 pt, so a
  growing slot moved the dial ~11 pt on every lock.
- **Notes:** one `CompassNote` style for low accuracy, Precise Location, Nearby, location off, Far and
  the aha line (§3.3 proposed). VoiceOver: the low-accuracy and aha lines stay in the readout's label /
  the announcement as before, so the pill copy is hidden from VoiceOver; Nearby, Far and location off
  are read as text. Buttons are `SecondaryButtonStyle`, at most 330 pt wide.
- **Tick token:** `#807075` (§2, §7); `ThemeTests` now also checks ticks on `dialTop`.
- **Left for 5.5:** the 260 pt AX dial and the letters' Large Content Viewer. The letters already stop
  at 17 pt (the §2 token).
- **Considered:** rotating the whole face with counter-rotated labels (the HTML's method; also turns the
  face's light and the inner highlight with the phone).

### 2026-10-01 · 5.3 madlib sentence: as built
- **VoiceOver "button", in order:** the sentence is one set of `Text` lines with link tokens (wraps like
  text; taps via `OpenURLAction`). VoiceOver would read links inside a text, so `.accessibilityChildren`
  replaces it with the sentence as a header, then a real `Button` per token ("Date, tonight", "Place, Los
  Angeles, C A"), with hints. Checked in the simulator's accessibility tree.
- **Spoken region:** an all-caps region of up to 3 letters ("CA", "NSW") is spelled out via the
  `accessibilitySpeechSpellsOutCharacters` attribute; words ("England") aren't.
- **No place:** "tonight" is plain words, not a token: a day needs a place's calendar, and §3.1's example
  draws no 📅 there. While the launch fix runs, the last-viewed city stands in for "a city" (LOCATION.md §3,
  as the old search field did).
- **Shrink before wrap (§3.1a):** per line, `ViewThatFits` over: full size on one line; one line scaled
  as far as 0.8 (measured by the line at 0.8, shown scaled just enough); wrapped. Each line keeps a
  full-size line's height so the card doesn't move.
- **Custom symbols:** SF Symbols templates can't hold strokes, so the HTML's 1.7 strokes were outlined with
  CoreGraphics (`copy(strokingWithWidth:)` + `union`) into Regular-M symbolsets. Scaled with Dynamic Type
  and tinted amber inside `Text`.
- **Considered:** one `Text` with `\n` breaks (can't shrink one line); `Text` + concatenation (deprecated
  on iOS 26, interpolation instead); real buttons laid over the text (token positions unknown once it wraps).

### 2026-10-01 · Madlib copy, fixed three lines, custom token icons
- *(Copy and line breaks superseded the same day: see "Madlib sentence: 'Where will the moon be…'" above.)*
- Sentence copy: **"Where can I find the moon [date] in [place]?"** (was "Where will the moon be…"). Alternative
  recorded, not chosen: "Where will the moon rise and set [on date] in [place]?" (too long).
- Always three lines with explicit breaks (lead / date token + "in" / place token + "?"), reserving the height so
  the card doesn't jump; a long city shrinks before wrapping. DESIGN-1.1.md §3.1a.
- Token icons drawn from the design's SVGs as custom symbols, not SF `calendar` / `mappin`.

### 2026-09-30 · 5.2 follow-ups: times round to the minute; degrees in VoiceOver
- **Rounding (Tessa: 9:09 / 2:26 shown where the brief and USNO give 9:10 / 2:27):** `Date.FormatStyle`
  drops the seconds, so the engine's LA 21:09:52 read "9:09". The card's times now round to the nearest
  minute, half a minute up (USNO's convention: the §5 row's 17:18:30 is USNO's 17:19). The spike table
  truncated too, so this predates 5.2. The engine values and the ±2 min test tolerances are unchanged.
  A rise at 23:59:45 now reads "12:00 AM"; acceptable, as USNO does the same.
  `MoonTableSpike`'s console print still truncates; it isn't user-facing.
- **Degrees in VoiceOver (Tessa):** rise/set labels end with the whole degrees after the direction:
  "Moonrise at 9:10 PM, east-northeast, 58 degrees", as §3.2's example. Same rounding as the visible
  "58° ENE" (`CompassFormatter.spokenDegrees`). Supersedes "not added" in "5.2 moon card" below.
- **Considered:** rounding in `AstronomyEngineMoonService` (would change `MoonEvent` for the compass and
  tests; it's a display rule, so it lives in the formatter).

### 2026-09-30 · 5.2 moon card: as built
- **Hairlines:** one, between the phase row and the rise/set row, as the HTML draws it. §3.2 says "three
  rows separated by hairlines"; §9 acceptance is "matches the HTML", so the HTML won. Header → phase is
  spacing only.
- **Zone per time, sampled at the event:** each rise/set time gets its own abbreviation, taken at that
  moment, not at the day's noon as the old label line was. On a DST changeover day a 01:00 set and a
  20:00 rise can differ (Phoenix vs LA on Nov 1: only the rise shows "PST"). Still the system's
  `TimeZone.abbreviation(for:)`, so `en_US` shows "GMT+10" for Sydney.
- **Zone wraps under the time at default size:** a column is ~145 pt on a 393 pt phone; "11:13 PM" in
  Young Serif 24 plus "GMT+10" needs ~165. So it stacks (the §3.2 fallback) nearly always, and the card
  grows ~22 pt for another zone. Open for Tessa: accept, or shrink/shorten something.
- **VoiceOver wording:** the spike's labels kept as §3.2 says ("Moonrise at 5:18 PM, east-southeast"),
  plus the zone in the old label's words: "Moonrise at 11:13 PM Sydney time, GMT+10, east-northeast".
  §3.2's example also has "56 degrees"; not added, since the rule says "unchanged". *(Added in the
  5.2 follow-ups, above.)*
- **Spike UI removed:** `ContentView`, `SpikeMoonTableViewModel` and its tests are gone; the card's model is
  `Features/MoonTable/MoonTableViewModel` (text from `Formatting/MoonTableFormatter`). `MoonTableSpike`
  (console print at launch) stays; it isn't spike UI.
- **`DateControl` interim:** ‹ › and VoiceOver's adjustable day stepping moved to the card's header; the
  field is left only to open the calendar until 5.3's date token replaces it.
- **Phase glyph:** a terminator half-ellipse with semi-axis `|1 − 2k|`, so the lit area is exactly `k`
  (tested by polygon area). Northern orientation only (Sydney shows waning lit on the left; flip is backlog).
- **Considered:** sampling the zone at noon as before (wrong on changeover days once it sits beside a
  specific time); a `Grid` for the rise/set row (the HStack with a centred hairline overlay is simpler and
  matches the CSS grid for equal columns).

### 2026-09-30 · 5.1 theme: static Nunito Sans, app-wide defaults
- **Fonts:** Nunito Sans is bundled as three static weights (Regular, SemiBold, Bold from
  googlefonts/NunitoSans), not the variable font: exact PostScript names, no axis handling in
  `Font.custom`. Young Serif from google/fonts. OFL texts ship in the bundle beside them.
- **Defaults:** the app root sets the body font and `textPrimary`, and the `AccentColor` asset is the
  amber, so unstyled text and the sheets pick up the theme (DESIGN-1.1.md §6) until each step styles them.
- **Considered:** the variable font (one file, but weight via axes is less predictable); no root
  defaults (each step would show mixed SF / Nunito until 5.4).

### 2026-09-30 · Design 1.1: Madlib (direction C) is the design direction
- **Chosen:** Claude Design "Madlib 1.0" (`design/1.1/`), spec in DESIGN-1.1.md (Step 5). The prompt becomes
  a sentence with two tappable tokens (date → calendar, place → search); one moon card (date + ‹ ›, phase
  glyph, rise/set); restyled compass with upright letters, ↑/↓ target labels and an amber lock pill; an
  AX reflow; a pinned compass bar when the dial is below the fold; four onboarding screens.
- Answers DESIGN-BRIEF.md §7 Q1–Q8 (table in DESIGN-1.1.md §1). The card's date label says "Today ·" again.
- **Dark only** for 1.1 (forced dark); light mode with Round 2.
- **No place yet:** place token reads "a city"; card and compass hidden; Use my location as a secondary button.
- **Time zone:** small abbreviation next to the moonrise/moonset times, replacing the "Sydney · AEST" line.
- **Onboarding:** new installs only (no saved place, permission not determined); DEBUG reset.
- Fonts: Young Serif + Nunito Sans (OFL), bundled, scaled with Dynamic Type via `relativeTo:`.
- Open: live Moon dot style (proposed in DESIGN-1.1.md §11 Q4); VoiceOver order at AX2 and final
  onboarding copy come from the designer.

### 2026-09-30 · Search ranks smart, then closest; 4.15 status bar fix now
- **Ranking (Tessa):** the most prominent / expected place first, distance from the user only as
  the tiebreak. No more biasing results to the user's area. Fuzzy matching from MapKit is fine.
  Replaces "ranking waits on Tessa" in Step 2.2 (SEARCH-RECENTS.md §0).
- **4.15 status bar (Tessa):** the main screen's content slides under the clock with no background.
  Fix it now with the iOS 26 system treatment: the scroll edge effect at the top (content fades /
  blurs under the status bar, as in system apps), not a custom header. Final styling stays in the
  design pass.
- **Considered:** a solid bar color (fine fallback if the edge effect doesn't apply to a bare
  `ScrollView`); pinning the prompt + search field as a header (bigger layout change, design pass).

### 2026-09-30 · 4.14: one Precise button; Step 2.2 search quality
- **4.14 (Tessa):** two CTAs ("Use Precise Location" + "Always use Precise Location") felt wrong.
  One button now. The temporary alert only offers Don't Allow / Allow Once; that's iOS, and there's
  no in-app way to make Precise permanent, so "Allow While Using" can't be added there. Permanent
  Precise stays in Settings.
- **Step 2.2 (Tessa):** type-ahead misses Singapore and Tokyo and ranks London, ON above London, UK.
  Approved: widen the filter so city-states and metro-level cities appear (region/country results
  only on a name match), and resolve the exact tapped row. Ranking change waits on a before/after
  table from the agent. Spec: SEARCH-RECENTS.md §0.

### 2026-09-30 · 4.13: place names read "City, ST"
- **Decision (Tessa):** the search field and compass copy show "Irvine, CA", not "Irvine".
- **How it scales:** use Apple's locale-aware `cityWithContext` (already stored as `Place.region`)
  and take its first part. US/Canada/Australia and other federal countries get the state or
  province; elsewhere Apple may give a country or nothing, and we fall back to the city. No
  per-country rules to maintain.
- **Considered:** our own table of which countries use states (brittle, never finished); always
  "City, Country" (reads oddly at home: "Irvine, United States").
- **To verify on device:** Irvine, Sydney, Toronto, London, Paris, Tokyo, Singapore, Reykjavík,
  Mexico City. Record what Apple returns in the as-built notes.

### 2026-09-30 · 4.12: Precise Location on by default; ask in context if they opted out
- **Why:** `NSLocationDefaultAccuracyReduced` made every new install approximate, and with Precise
  off iOS reports ±81–86° heading accuracy, so the compass never locked out of the box.
- **Decision (Tessa):** drop the key, so when someone agrees to location the prompt shows Precise
  **on**; they have to opt out. The permission text says, in that moment, that the compass needs
  it. For opt-outs, the compass line reads "We think you're near {City}, but the compass needs
  Precise Location to point the right way" with **Use Precise Location**, which calls
  `requestTemporaryFullAccuracyAuthorization` (in-app alert, one tap, this session only), plus
  "Always use Precise Location" → Settings. The privacy reassurance lives in the temporary
  alert's purpose string. When Precise turns on with the compass visible: "There you are! The
  compass is happy now." for ~3 s.
- **Privacy wording:** rules in COMPASS.md §3. Short version: "we never see your location" and
  "never shown on screen" are true; "never leaves your phone" and "never shared" are not (MapKit
  goes to Apple); "we don't store it" isn't true yet (last-viewed keeps coordinates on the phone).
- **Considered:** keeping approximate as the default and only asking in context (more private up
  front, but every new user hits the warning); Settings link only (most friction).
- Supersedes the 2026-09-29 note "city-level is enough" (LOCATION.md) and 4.10's Open Settings button.

### 2026-09-30 · 4.11: Nearby/Far copy; main-screen "Use my location" only on first launch
- **Device test (Tessa):** with a nearby city selected, "Directions for {City}" plus the
  "Use my location" button under the search field read as confusing and disconnected.
- **Nearby note:** "You're in {Detected city} but {City} is nearby". **Far message:** "You're a bit
  too far from {City} to view the compass accurately". Both placeholder; tone revisited in the
  design pass. Still no distance shown.
- **Main-screen "Use my location" removed,** except on the empty first-launch state (no place
  saved), where nothing is selected yet. Everywhere else, tapping the search field opens the sheet,
  whose "Use my location" row keeps the old button's behavior (switches to the detected place).
  Amends LOCATION.md ("Use my location" button, launch logic) and SEARCH-RECENTS.md.
- **Precise Location off:** iOS reports ±81–86° heading accuracy, so the compass never locks.
  Kept as is: greyed dial, no lock or haptic, "Precise Location is off" + Open Settings.
- **Considered:** hiding the dial when Precise is off (treat like location off); testing whether
  the heading itself is wrong or only its reported accuracy. Not now.

### 2026-09-29 · Low-accuracy hysteresis: enter above 25°, leave below 20°
- **The device readout showed low accuracy was real, not stuck:** sensors running, true heading
  present, `accuracyAuthorization` full, visibility Here. iOS's reported accuracy went ±11.8°
  (locked) → ±27.3° (low, phone charging) → ±13.4° (locked). The single 15° line made the
  compass flip in and out of low accuracy as it wandered.
- **Now hysteresis, like the lock:** enter low accuracy above 25°, leave only below 20°, and keep
  the current state in between. It's always low with no true heading or unknown accuracy. The
  compass starts low (no reading yet), so a first reading has to be under 20°. Stopping the
  sensors resets it to low.
- **Model change:** `HeadingReading` loses `isLowAccuracy` and `lowAccuracyThresholdDegrees`. A rule
  that needs the previous state can't be a property of one reading. The rule is now a pure
  `CompassAccuracy.isLow(after:wasLow:)`. `CompassViewModel` stores the state, and
  `CompassLock.next` takes `heading` + `isLowAccuracy` instead of a reading.
- **Considered:** just raising the single line to 25° (it would still flicker at the edge); a
  time-averaged accuracy (slower to react, harder to test).

### 2026-09-29 · 4.8 + 4.9: sensors that got stuck, and a compass gone after overnight
- **Likely root cause of stuck low accuracy (4.9): iOS paused location updates.**
  `pausesLocationUpdatesAutomatically` defaults to true. Apple's docs say that for When In Use
  apps a pause "ends access to location changes until the app … restart[s] those updates". True
  heading is only valid while location updates run, so every reading lost it. Nothing in the
  session restarted itself; toggling Location in Settings stopped and restarted it, which is why
  that cleared it. Pausing is now off; sessions only run in the foreground with the compass on screen.
- **Self-healing anyway: `HeadingSessionMonitor`** (pure, tested). It restarts location updates if
  a valid magnetic heading keeps arriving without a true heading for 5 s (throttled to once per
  10 s), or on a pause callback. It restarts the whole session if authorization or Precise
  Location changes while running. The first authorization callback is the baseline; losing
  permission is left to `LocationViewModel`, which hides the compass.
- **Answers to the device-test questions:**
  - Does the heading manager start before authorization is settled? No. The compass only starts
    once `LocationViewModel` sees authorized.
  - Did anything restart it on an authorization change, an `accuracyAuthorization` change, or
    foreground? Not while running. Foreground only restarted it because background had stopped
    it. Both are now handled.
- **4.8 (compass gone after an overnight background):** not reproduced on device. The likely
  path is iOS terminating the app overnight and the launch fix failing or timing out, so nothing
  is detected. Before the fix, that was only retried on a permission change. Now each foreground
  with location authorized and nothing detected retries detection quietly. It's detection only,
  and a failure neither shows the "couldn't find" message nor switches the place.
- **`LocationService.isPreciseLocationOff`** (new) reaches the compass through `CompassContext`,
  for the DEBUG readout now and the 4.10 reason line.
- **DEBUG readout** under the compass, compiled out of Release (checked). It shows heading,
  accuracy, `accuracyAuthorization`, visibility, detected, targets, lock and sensors. It's shown
  in every state, even hidden, since "the compass is gone" is one of the things it diagnoses.

### 2026-09-29 · Low-accuracy reason shown inline
- When the compass is in low accuracy, one line under the heading says why: "Precise Location is off"
  (with a Settings button) when `accuracyAuthorization` is reduced, otherwise a metal/magnets +
  figure-8 tip. Placeholder copy.
- **Considered:** an ⓘ button opening a bottom sheet or floating dialog. Deferred to the design pass;
  inline keeps the common fix one tap away for testing.
- Low accuracy that stays stuck until Location is toggled in Settings is treated as a bug (4.9),
  not something to explain.
- *As built (4.10):*
  - `CompassViewModel.lowAccuracyReason` is `.preciseLocationOff` / `.interference` / `nil`.
    Precise-off comes from `CompassContext.isPreciseLocationOff`
    (`LocationService.isPreciseLocationOff`, 337a7f1).
  - No reason with no reading yet (it would flash on every start) or with `.unavailable` (no
    compass).
  - The reason line replaces the generic "Compass accuracy is low" line, which remains when there
    is no known cause and as the start of the VoiceOver label.
  - Tip copy gained "or a charger" (Tessa, after the device test).
  - The DEBUG readout gains a `reason:` line.

### 2026-09-29 · Compass follow-ups from first device test (4.5–4.7)
- **Haptic on lock (4.5):** one firm tap when a lock is acquired; none on release. Promoted from
  fast-follow now that locking works on device.
  - *As built:* `CompassViewModel.lockAcquisitionCount` goes up on each acquire, including a switch
    straight from one target to another (a new lock). The view plays
    `.sensoryFeedback(.impact(weight: .heavy))` when it changes. Release, holding, low accuracy and
    stopping don't change it. SwiftUI plays system feedback, which the System Haptics setting
    governs. The docs don't say so explicitly, so it's a device QA check.
- **Near, not same city (4.6):** the compass shows within 60 mi of the detected location. Rise/set
  bearings depend mostly on latitude, so within 60 mi they differ by well under 1° (inside the ±5°
  lock). Nearby shows "Directions for {City}"; Far hides the compass with "Compass is only
  available near this location". No distance is ever shown (screenshot privacy). Turn On Location
  from the compass hint updates detection only and keeps the searched city.
  - *As built:*
    - `CompassViewModel.Visibility` is now `.hidden / .locationOff / .here / .nearby / .far`, and
      `showsCompass` is Here or Nearby. The sensors, targets and Moon ticks follow `showsCompass`.
    - The radius is `nearbyRadiusMeters` = 60 × 1,609.344 m, inclusive. Distance is
      `Place.distanceMeters(to:)`, the haversine `isSameCity` already used, now internal rather
      than private. It's measured to the detected place's coordinates (the reverse-geocoded map
      item nearest the fix).
    - `nearbyNote` is stored, not derived, so moving between two Nearby cities updates it.
    - `LocationViewModel.turnOnLocationForCompass()` runs the same permission flow as "Use my
      location", but a fix only records the detected place. **Settings trip** (Tessa, answering
      the agent's question): if the dialog came from the compass hint, the automatic fetch on
      return is detection-only too. Pressing the main button clears that.
    - A failed detection-only fix shows the existing "Couldn't find your location" message.
- **Target rows removed (4.7):** they repeated the moon table; the compass keeps the heading
  readout and lock label.
  - *As built:* the `ForEach` of rows and `targetAccessibilityLabel(for:)` are gone; `targetText`
    stays for the lock label. **Dial VoiceOver** (Tessa, answering the agent's question): the live
    moon's bearing had no text left anywhere, and the dial was hidden from VoiceOver. So
    `CompassDial` is now one element labelled with `CompassViewModel.targetsAccessibilityLabel`
    ("Targets: moonrise, 72 degrees east-northeast; …"). It's hidden when there are no targets. No
    visible change. This supersedes the 2026-09-28 4.4 note that the dial is decorative.
- **Considered:** 30 mi radius (too tight for a metro area); "may not be exact" copy for Nearby
  (undersells a <1° difference); showing the distance (privacy).

### 2026-09-28 · Step 4.4: compass view (plain)
- **"On screen" comes from `onScrollVisibilityChange` and `onDisappear` only, not `onAppear`.**
  The main screen's stack isn't lazy, so `onAppear` fires on insertion even with the compass below
  the fold, which would start the sensors off screen. `onScrollVisibilityChange` also fires on
  appearing if already past its threshold (checked in the SwiftUI docs), so it covers insertion.
  `onDisappear` covers removal.
- **Only `.background` stops the sensors;** `.inactive` (Control Center, the permission prompt) doesn't.
- **The hint's button runs `useMyLocation()`**, the existing flow: the system prompt if not yet
  asked, otherwise the Location Off dialog.
- **One VoiceOver element for the heading.** In low accuracy it reads "Compass accuracy is low"
  rather than an untrustworthy number, and it's marked "updates frequently". The dial is
  decorative (hidden from VoiceOver); the lock label and target rows carry the same information.
- **Copy lives in `CompassViewModel`** (placeholders and row text), so the view holds no strings of
  its own except the "Compass" header.

### 2026-09-28 · Step 4.3: compass view model
- **`CompassViewModel` is fed, not wired.** `LocationViewModel` pushes a `CompassContext` (place,
  detected place, permission state, the selected day's `MoonDay`, is-today). The compass never reads
  location state itself, so `LocationViewModel` stays the one owner of place, day and permission.
- **Moonrise and moonset targets come from the table's own `MoonDay`**, not a second
  `moonDay(for:on:)` call. The compass can't disagree with the table, and the existing tests that
  count moon-service calls are unaffected.
- **Sensors run only while shown, on screen and in the foreground.** A task iterates the heading
  stream for as long as they run, which is what holds it. Stopping clears the reading and lock, so
  a stale heading is never shown.
- **The "Moon" ticker runs only with the sensors.** Each tick recomputes the moon's azimuth and
  whether it's up. Foreground and "selection became today" recompute at once. The sleep is injected
  so tests fire ticks by hand.
- **Lock rules live in a pure `CompassLock`.** Acquire ≤ 5° (inclusive), release > 8°, nearest
  wins, an exact tie goes to moonrise, then moonset, then moon. A locked target that disappears
  (the moon sets, a new day has no moonrise) is released.
- **Visibility with location on but nothing detected is hidden.** A searched city can only be
  "where you are" by matching a detected place (§2). If detection failed or hasn't run, nothing
  proves it.
- **Bearing copy is whole degrees then letters ("72° ENE"), rounded so 359.6° reads "0°".** Same
  order as the moon table. The letters use the unrounded azimuth, as the table does.
- **The moon table now uses the same `CompassFormatter.bearing(for:)`** (review follow-up), so the
  table and compass can't disagree. Two visible changes in the table: 359.6° reads "0° N", not
  "360° N". An exact half degree now rounds half away from zero (72.5° → "73°"), where the table
  used to round half to even ("72°"), matching the compass.
- **4.3b wiring: `LocationViewModel` owns the compass** (`let compass`) and takes a
  `headingService` in its initializer. Every place and day change already goes through
  `reloadMoonTable()`, which now also pushes the context. The permission prompt and
  `sceneDidBecomeActive()` push it too. A new `sceneDidEnterBackground()` forwards to the compass.
- **The detected place is remembered for the session** (not persisted) from the last successful
  fix, including a launch fix that doesn't replace the saved place. A later failed fix keeps it.

### 2026-09-28 · Step 4.2: HeadingService
- **Delegate API wrapped in an `AsyncStream`.** CoreLocation has no async heading sequence (checked
  against iOS 26 docs), and `CLLocationUpdate.liveUpdates()` carries no heading. `start()` returns
  the stream; `stop()` finishes it.
- **Heading and location updates share one manager and one session**, started and stopped
  together. It's a separate manager from `CoreLocationService`'s, so stopping the compass can't
  cut off a location fetch in flight. Location runs at kilometre accuracy, since true heading
  only needs a rough position for declination.
- **A cancelled or dropped stream ends the session** (via `onTermination`), guarded by a session
  counter so a late termination can't stop a newer session. The consumer must keep the stream
  while it wants readings.
- **No compass hardware → neither sensor starts** and the stream yields one `.unavailable`. This is
  the simulator path, and it's tested for real.
- **Only `headingFailure` and `denied` errors mean "unavailable".** A transient "location unknown"
  is ignored, so the compass doesn't flicker into low accuracy.
- **Low accuracy = no true heading, unknown accuracy, or accuracy > 15°.** Exactly 15° is still
  usable ("worse than 15°", COMPASS.md §1). Lives on `HeadingReading` as a named constant.

### 2026-09-28 · App name: Moon Signal (working name)
- **Display name is "Moon Signal" for now**, replacing the working name "Moonbeam". The location
  permission prompt already uses it (96e5042). `AppInfo.name` and the home-screen display name
  (`INFOPLIST_KEY_CFBundleDisplayName`) now follow; the repo, project and target names
  (`moonbeam`, `moonbeam-app`) stay as-is.
- Still revisitable; final name to confirm with the design partner.

### 2026-09-28 · Compass: moon-up, data model, iPhone-only, 16-point names
- **Moon-up = latest rise is after latest set**, both from the moon table's own rise/set search
  (upper limb, standard refraction), searched back from now. The compass can't disagree with the
  table, and it covers a moon that rose last night.
- **Data model is additive only:** new `MoonPosition` (azimuth, isUp) and
  `MoonService.moonPosition(for:at:)`. Rise/set bearings already existed in `MoonEvent.azimuth`.
  Plus a new `HeadingService` protocol (CoreLocation + fake).
- **v1 is iPhone-only** (`TARGETED_DEVICE_FAMILY` 1,2 → 1), so the portrait lock doesn't fight
  iPad multitasking.
- **16-point direction names on the compass**, from `CompassFormatter`, same as the table.
- **Considered:** altitude > 0° for moon-up (measures the centre, so it's off from the table by a
  minute or two at each rise and set); portrait-locked iPad; 8-point names like Apple's Compass
  (one bearing would get two names on one screen).

### 2026-09-26 · Step 3 review follow-ups
- **The moon table no longer shows the city or the date.** The search field shows the city and
  the date control shows the day, so `ContentView` doesn't repeat them. This removes
  `SpikeMoonTableViewModel.dayText` from Decision 2 below. `day` stays, because the rollover check
  compares against it.
- **Shorter date label: "Sun, Sep 27", with the year only in a different year** from the place's
  today ("Mon, Jan 4, 2027"), and no relative word. The chip already says you're off today, and the
  long "Tomorrow · Sun, Sep 27, 2026" wrapped onto two lines at default size. The VoiceOver value
  keeps the relative word and year. The year is compared in the place's zone and in the calendar
  the label is written in.
- **Today chip tap target is 44 pt (NFR4), and it looks the same.** The bordered capsule gets a
  44 pt minimum-height frame and a rectangular content shape. A tap just above the visible capsule
  registers (checked in the simulator).
- **Accepted for now: the same day number after browsing with the month arrows waits for Done.**
  Sep 27 selected → arrow to October → tap Oct 27: to the picker this looks exactly like turning
  the wheel (the day number is kept, and the month changes), so Decision 4's detection treats it as
  a draft and shows Done instead of closing. It's one extra tap in an uncommon case. A custom
  calendar (DATE.md §8, V2) would report taps directly and remove the guess.
- **The date field fills the space between ‹ and ›, with the label centred.** Its width no longer
  follows the date text, so the arrows and chip don't shift as you step through days. The row
  switches to stacked (chip under the row) only at accessibility text sizes, so the default-size
  `ViewThatFits` fallback is gone.
- **The Today chip is always visible, and disabled on today** instead of hidden. The row keeps one
  shape, and the chip's place is learnable. `showsTodayChip` → `isOnToday`, with the meaning
  inverted. With no place it's `true`, so the chip is disabled (the control is hidden then anyway).
  VoiceOver reads it as "Go to today, dimmed".
- **The Today chip is removed from the date row** (supersedes "always visible, disabled on today"
  above). The row is just ‹ [field] ›, and going back to today is the calendar sheet's Today button,
  which is disabled when the selected day is already today (`isOnToday`). The trade-off: back to
  today is now two taps (open the calendar, then Today). That's logged in DESIGN-REVIEW.md, to
  revisit with the relative-day chips idea.
- **Location screen order:** prompt → search field → "Use my location" → finding/failed status →
  date control → time zone label → moon table. The location button and its status now sit with
  the search field they're the alternative to, and the date control sits directly above what it
  changes.

### 2026-09-26 · Step 3: date selection (DATE.md)
- **Decision 1: the midnight rollover happens only when the app comes back to the foreground.**
  `sceneDidBecomeActive()` moves a following-today selection to the place's new day. Nothing moves it
  while the app stays open in the foreground; the next foreground or day action catches up. A timer
  to the place's next midnight would need a second, injectable time source to test. DATE.md §3 is
  amended to match.
- **Decision 2: `SpikeMoonTableViewModel.init(…, today:)` → `day:`.** It keeps the day, and `dayText`
  formats it rather than `Date()`. Once the day is selectable, the table isn't always for today.
- **Decision 3: the time zone label follows the selected day, sampled at local noon.** Both the
  "different zone?" check and the abbreviation use `daySelection.noon(in:now:)`, not `now()`. A picked
  day across a DST change gets that day's label (Sydney on Nov 25 → AEDT), and Phoenix shows one after
  LA falls back. Noon, not midnight, because DST changes happen overnight: noon has the offset for
  nearly all of the day, so LA's changeover day (Nov 1) counts as after the change.
- **Decision 4: the calendar sheet's month/year wheel moves a highlight, not the selection.** In
  the simulator, the graphical `DatePicker`'s wheel changed its selection (Sep 27 → Oct 27), and the
  sheet, which closes on a pick, closed as soon as the wheel moved. A change that keeps the day
  number, or clamps it to the month's last day, is now a draft (`calendarDraft`). The sheet stays
  open and a Done button confirms it. Any other change is a tap on a new day, which picks and closes
  (DATE.md §2). The ambiguous case, the same day number in another month, also waits for Done.
  Considered: Done for every pick (an extra tap, against §2), and leaving the wheel as it was.
- **Tapping the already-selected date doesn't close the sheet.** The picker doesn't report a tap on
  its current selection (checked in the simulator). Cancel or a drag closes it. DATE.md §2 is struck
  through to match.
- **`DaySelection` anchors every day at local noon.** Noon always exists, and midnight doesn't in
  zones whose DST starts at 00:00 (Santiago, 2026-09-06). Days move with `date(byAdding: .day)`,
  never by 86,400 s. Range: today ±366 in the place's zone, clamped on every move and resolve, so a
  picked day that drifts out of range (rollover, city change) lands on the nearest end.
- **A picked day stays `.day` even when it becomes today** (rollover or city change), as §3 says.
  The Today chip and the "Today ·" prefix come from the resolved day, so they're still correct.
- **Date label formatting lives in `Formatting/DayLabelFormatter`**, not in the view model. The
  relative word comes from the offset from the *place's* today, so `Date.RelativeFormatStyle` (whose
  today is the device's) doesn't fit. Tests pin `en_US`.
- **The date field's accessibility: label "Date", with the date as its value.** VoiceOver reads the
  new value after each adjustable swipe, and taps on ‹ / › / Today post an announcement. This
  replaces the single `dateAccessibilityLabel` in DATE.md §4.
- **`FakeMoonService` added**, the last service without a fake. It records `requestedDates`, so
  tests check which day reached the service.
- **Sydney 2026-09-23 and Mar Vista 2026-10-03 through the view model are engine-derived guards**
  (±2 min), because ASTRONOMY.md §5 has no USNO rows for them yet.

### 2026-09-26 · Step 2.1: search sheet with recent cities (SEARCH-RECENTS.md)
- **Decision A: the sheet's "Use my location" row closes the sheet, then runs the main-screen
  flow.** The flow starts from the sheet's `onDismiss`, not from the tap. SwiftUI can't present
  the Location Off dialog while the search sheet is still up from the same view, so waiting keeps
  one code path and avoids stacked sheets. The dialog's "Search instead" does the reverse: it
  reopens the sheet once the dialog has closed.
- **Decision B: the location row is hidden when you're already viewing your detected location.**
  The sheet takes `showsUseMyLocation` from `LocationViewModel`, the same rule as the main-screen
  button. Tapping it there would only re-detect the same place.
- **Decision C: the "Back to {City}" chip is removed.** Recents cover going back to a saved city,
  one tap further away. `lastViewed` stays, because launch still falls back to it when location is
  off, denied or fails. A launch fix still doesn't overwrite it.
- **`PlaceStore` is class-only (`AnyObject`).** The plan's `mutating` recents helpers couldn't be
  called through a `let` reference, even on a class. Both stores are classes and a store is shared
  storage, not a value, so the protocol says so and the helpers aren't `mutating`.
  Considered: keeping `mutating` and using `var` everywhere, which reads as if the store were copied.
- **Resolve failures show `.failed`, whatever the error.** The sheet stays open and nothing is
  picked. The old `LocationViewModel.choose` showed "No matching cities" when a resolve found
  nothing, but that's wrong for a city the user just saw listed. The current "Can't search right
  now" copy isn't right either; logged for the design pass.
- **Type-ahead starts at 2 characters** (`SearchSheetViewModel.searchMinimumCharacters`). Shorter
  queries never reach `MKLocalSearchCompleter`: 0 characters shows recents, and 1 filters them
  (case- and diacritic-insensitive prefix match on any word of name, region or country). The
  threshold is one constant, so it can move to 3 after device testing.
- **8 recents, picked places only.** Picks from search (suggestions or recents) are added, most
  recent first, with the oldest dropped at 9. The detected location never is, because the
  "Use my location" row covers it. Re-picking the same city moves it to the top: same name, region
  and country, or within ~1 km (`Place.isSameCity(as:)`). Recents live under their own
  `recentPlaces` key, seeded once from an existing `lastViewed`. Whether that place was detected
  isn't persisted, so it's seeded regardless.

### 2026-09-25 · Location view model, screen and dialog: the calls LOCATION.md left open
- **The 10 s timeout cancels the fix; it doesn't just stop waiting.** `LocationViewModel` runs
  `currentPlace()` in its own task, with a watchdog that cancels it when the timeout fires.
  Cancelling is what ends `CLLocationUpdate.liveUpdates()`. If the view model only stopped
  awaiting, updates would keep running in the background. Tested with `FakeLocationService`,
  which now records cancelled fixes.
- **A launch detection doesn't overwrite the last-viewed place. Picks do.** §3 says that picking
  any place ("search, detect, or chip") makes it last-viewed. That covers a "Use my location" tap,
  but not the automatic fix at launch. If launch saved it, the "Back to {City}" chip would be gone
  by the next launch. So the chip reduces to one rule: show it when `lastViewed != place`.
- **A current location is never named after `mapItem.name`.** For a reverse geocode, that's the
  nearest street address. Without `cityName`, the mapping uses the first component of
  `cityWithContext`. With neither, it fails, and `CoreLocationService` throws
  `couldNotIdentifyPlace`. Search results keep the `mapItem.name` fallback, because there it names
  the locality the user picked. The rule is `Place.placeName(...)`, tested without MapKit. Because
  the mapping never produces a `locality` that differs from `name`, the "Mar Vista, Los Angeles"
  display-name test was dropped.
- **The time zone label uses the system abbreviation, which isn't always "AEST".** In `en_US`,
  `TimeZone.abbreviation(for:)` gives "GMT+10" for Sydney. Apple only has short names for zones
  the locale commonly uses. That's still unambiguous, so no hand-kept abbreviation table.
- **Refusing at the system prompt ends there.** No Location Off dialog follows straight away. The
  user just answered, so the dialog would nag. The next tap shows it.
- **A failed fix after a tap shows a message: "Couldn't find your location. Try again, or search
  for a city."** §3 only covers failures at launch, which fall back quietly. A tap that did
  nothing visible for up to 10 s would read as broken. Placeholder copy, for the design pass.
- **One dialog title for all three variants.** §4 gives only "Location is off for {AppName}".
- **Foreground re-check is transition-based.** Any change from not authorized to authorized while
  the app was in the background triggers a fetch, whether or not the user got to Settings through
  the dialog. Returns from the system prompt are skipped, so they don't start a second fetch.

### 2026-09-25 · Location services: the API choices behind LOCATION.md §6
Five choices made while building `Place`, `LocationService`, `PlaceSearchService` and `PlaceStore`.
The screen, the view model and the Location Off dialog are still to come.

- **The one-shot fix is `CLLocationUpdate.liveUpdates()`, stopped after the first location.** It's
  the async-native path, so there's no delegate bridging for the fix itself. `requestLocation()`
  would work too, but needs a delegate and a continuation. The `authorizationDenied`,
  `authorizationRestricted` and `locationUnavailable` flags have to be checked as well: the sequence
  doesn't *end* when a fix becomes impossible, it just stops yielding, which would hang the caller.
  Authorization still goes through `CLLocationManager.requestWhenInUseAuthorization()` — the only
  API that controls *when* the prompt appears, which §3 depends on.
- **Reverse geocoding is `MKReverseGeocodingRequest`, as §6 requires.** Confirmed against the iOS 26
  SDK: `MKMapItem.placemark` and `CLGeocoder` are deprecated in 26, and `MKMapItem` gained
  `location`, `address` and `addressRepresentations`.
- **`Place.region` is derived by string, because iOS 26 exposes no administrative-area property.**
  `MKAddressRepresentations` gives `cityName` ("Sydney") and `cityWithContext` ("Sydney, NSW") and
  nothing between them; the component-wise route was `MKPlacemark.administrativeArea`, the very API
  §6 tells us to avoid. So `Place.regionComponent` takes whatever `cityWithContext` has beyond the
  city, and returns `nil` unless the city is confirmed to be the leading component — an unexpected
  format yields no region rather than a wrong one. Covered by tests, rejection cases included.
  Worth revisiting if a later SDK adds the property.
- **`suggestions(for:)` returns an `AsyncThrowingStream`, not the `AsyncStream` §6 specifies.**
  §3 asks for a "Can't search right now. Check your connection." state, and a non-throwing stream
  can't tell a failed search from one that matched nothing. LOCATION.md §6 updated to match.
- **`resolve(_:)` re-searches by address text rather than replaying the `MKLocalSearchCompletion`.**
  §6 says "via `MKLocalSearch`", which this is: the suggestion's two displayed lines are rejoined
  into a `naturalLanguageQuery`, filtered to localities. Replaying the completion object would be
  marginally more precise, but `MKLocalSearchCompletion` isn't `Sendable`, so keeping one would stop
  `PlaceSuggestion` being a value type that fakes and previews can construct.
- **The time zone label compares *offsets*, not identifiers.** §5 says "whenever
  `place.timeZone` ≠ `TimeZone.current`", which reads as identifier equality. Compared that way,
  "US/Pacific" and "America/Los_Angeles" would label a place as elsewhere while showing identical
  times. `Place.isInDifferentTimeZone(from:on:)` takes the device zone as a parameter, which also
  makes it testable — a test process can't change `TimeZone.current`.
- **Isolation split:** these three services are main-actor isolated (the project default), because
  `CLLocationManager` and MapKit both expect a single UI-bound home. `Place`, `PlaceSuggestion`,
  `LocationAuthState` and the MapKit→`Place` mapping stay `nonisolated`, so results cross back into
  the domain layer — and into `MoonService` — without a hop. Note that a `nonisolated` type's
  *extensions* don't inherit that: `Place+MapKit.swift` needs its own `nonisolated`.

### 2026-09-23 · Validate illumination against USNO at local noon, not at the displayed moment
- **Decision:** `AstronomyEngineMoonService` gains an internal `illumination(at:)`. Tests compare
  USNO's `fracillum` against that helper **at local noon**, and assert the displayed
  tonight's-midnight value (94%) separately as an engine-derived regression guard.
- **Why:** USNO samples `fracillum` at local noon. Comparing it to our displayed value would fail by
  ~3 points for a reason that has nothing to do with correctness, and the tempting "fix" — widening
  the tolerance to 5% — would destroy the test's power. Sampling the same moment USNO does isolates
  the maths from the display convention, so each assertion tests one thing.
- **Result:** USNO confirms rise 17:19 and set 03:37 (engine: 17:18:30, 03:37:09, both within
  ±2 min), 91% at local noon (engine 90.9%), and Waxing Gibbous. §5 is no longer TBD.
- **Kept internal, not private:** the helper is `internal` so tests can reach it via
  `@testable import` while the C API stays confined to this one type, per the architecture rule.
- **Not covered by USNO:** rise/set azimuth. USNO doesn't publish it — the reason we calculate on
  device at all (§1) — so azimuth assertions remain engine-derived and are labelled that way.

### 2026-09-23 · The whole domain layer is `nonisolated`, not just the service
- **Decision:** `nonisolated` on `Place`, `MoonEvent`, `MoonDay`, `MoonPhase`, the `MoonService`
  protocol, `AstronomyEngineMoonService` and `CompassFormatter`.
- **Why:** `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` isolates everything unannotated, which makes
  pure value types and pure functions main-actor state. Marking only the service wasn't enough:
  tests still failed to compile because `MoonDay.rise`, `MoonEvent.azimuth` and the `MoonService`
  requirement were all main-actor isolated, so reading a result off the main actor was illegal.
  These types have no mutable or shared state, so isolation buys nothing and costs a hop.
- **Consequence:** Test suites are marked `nonisolated` too, so they genuinely exercise the code off
  the main actor. Views and view models stay main-actor isolated by default, which is what we want.

### 2026-09-23 · Unit tests live in an app-hosted target, driven by a shared scheme
- **Decision:** `moonbeam-appTests` is a Swift Testing bundle **hosted in the app** (`TEST_HOST` +
  `BUNDLE_LOADER` + a target dependency), and the `moonbeam-app` scheme is **shared** in
  `xcshareddata/xcschemes/`.
- **Why hosted:** `@testable import moonbeam_app` needs the app's Swift module. An unhosted bundle
  with no dependency on the app fails with "Unable to resolve module dependency: 'moonbeam_app'".
  Creating the target with the host app attached wires `TEST_HOST` and the dependency correctly;
  creating it standalone does not, and the dependency can't be added without editing
  `project.pbxproj`, which the Xcode tooling forbids.
- **Why shared:** Xcode's autocreated schemes carry no test action, so `xcodebuild test` fails with
  "Scheme moonbeam-app is not currently configured for the test action". Sharing the scheme puts the
  test action in version control. Committing it is deliberate — don't let Xcode replace it.
- **Also:** The test target inherits none of the app's language settings, so Swift 6, complete strict
  concurrency, iOS 26.0 and iOS-only platforms had to be set on it explicitly. The template defaults
  were Swift 5.0, iOS 27.0 and a multiplatform `SDKROOT = auto`.

### 2026-09-23 · Swift 6 language mode with complete strict concurrency
- **Decision:** `SWIFT_VERSION = 6.0` and `SWIFT_STRICT_CONCURRENCY = complete`, matching what
  CLAUDE.md already required. The Xcode template had shipped 5.0.
- **Outcome:** Builds clean with no errors and no concurrency warnings, so no source changes and no
  suppressions were needed. The existing code was already compatible: the models are value types of
  Sendable members, so they pick up implicit `Sendable`; the service is a stateless `struct` whose
  C calls are all local; and the spike's statics are immutable.
- **Note:** The template also sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and
  `SWIFT_APPROACHABLE_CONCURRENCY = YES`, both left as-is. Those make unannotated code MainActor
  isolated, which is why calling the spike from `App.init` is fine. When the test target lands,
  expect to mark the astronomy helpers `nonisolated` so tests can call them off the main actor.

### 2026-09-23 · Minimum iOS 26.0
- **Decision:** `IPHONEOS_DEPLOYMENT_TARGET = 26.0`, the value PRODUCT.md §8 recommended. The
  template had 27.0.
- **Why:** 26 is a wide enough net for a new app while still avoiding legacy baggage; nothing in the
  codebase needs a 27-only API. Verified by building and running at 26.0 — the moon table still
  prints identical values, including 94% illumination.
- **Where it's set:** Both the project and the target read **26.0**, in Debug and Release, so new
  targets inherit the right floor. Getting there took two passes: the target was set first, then the
  project level went 27.0 → 26.6 → 26.0 in Xcode. Claude can only set the *target* level — the
  Xcode tooling exposes no project-level build setting and forbids hand-editing `project.pbxproj`,
  so project-wide changes have to be made in the UI.

### 2026-09-23 · Pin Astronomy Engine v2.1.19; call `Astronomy_SearchRiseSetEx`, not the macro
- **Why:** `Astronomy_SearchRiseSet` is a C *macro* in v2.1.19, so Swift can't see it. The
  underlying function `Astronomy_SearchRiseSetEx` takes an extra `metersAboveGround`, which we
  pass as 0.0 to match the 0 m observer height. ASTRONOMY.md §2 lists the macro name; treat that
  table as naming the capability, not the exact symbol.
- **Considered:** A static-inline shim in the bridging header (more moving parts for no gain).

### 2026-09-23 · Illumination and phase are sampled at tonight's local midnight
- **Decision:** Sample at the **end** of the selected day in the place's time zone, computed with
  `calendar.date(byAdding: .day, value: 1, to: localMidnight)` — not by adding 24 hours, which is
  wrong on the 23- and 25-hour days around a DST transition. The rise/set search window is
  unchanged: it still starts at the *start* of the local day and runs one day.
- **Why:** The app answers "how bright is the moon tonight?", so a fixed nightly anchor is right.
  Sampling the current time would make the number drift during the day and make the value
  irreproducible in tests; the start of the day is stale by evening, which is when people look.
- **Why it matters:** Illumination moves ~6 points across one day (Mar Vista, 2026-09-23: 87.8% at
  the start, 90.9% at noon, 93.6% at the end), far beyond the ±1% tolerance. Rise/set times and
  azimuths are unaffected. The §5 reference illumination is now **94%**, and this unblocks task #3.
- **Considered:** Local current time (drifts, untestable), local noon (matched the old 91% reference
  but has no product meaning), start of the selected day (stale by evening).

### 2026-09-23 · Astronomy Engine on the device; USNO for tests only
- **Why:** USNO has no rise/set azimuth, needs a network connection, and has had outages. Astronomy Engine is MIT-licensed, works offline, and covers every V1 field.
- **Considered:** USNO as the live API, SwiftAA, a hand-rolled Meeus algorithm.

### 2026-09-23 · Docs live in the repo under `docs/`, with CLAUDE.md at the root
- **Why:** Versioned with the code, and Claude Code picks up `CLAUDE.md` automatically.
- **Considered:** Keeping docs only in Obsidian or Notion (they'd drift from the code).

### 2026-09-23 · No separate API.md
- **Why:** There's no runtime API. Data-source research lives in `ASTRONOMY.md`.

### 2026-09-23 · SwiftUI + MVVM-lite + protocol services
- **Why:** Simple, testable, and easy for Claude to follow consistently.
