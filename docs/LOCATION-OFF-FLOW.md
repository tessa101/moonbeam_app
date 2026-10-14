# Step 5.12b Spec: Location off, prompt + moon guide (and the swap polish)

> Owner: Tessa · _Decided 2026-10-13_ · Source: `design/1.9-location-off-flow/README.md` (the design handoff, which
> **replaces** `design/1.8-location-off-teaser/` and its option 1b) + Tessa's notes of 2026-10-13 + the video
> `location_on_off.mov` (local; measurements in §5).
> **Problem:** 5.12 (cartoon compass) is better than the warning chip but still reads as one fixed ask. Once someone
> says no, there's nothing left to bring them back, and the swap between the location-off block and the live compass
> hard-cuts.
> Supersedes: 5.12's cartoon compass (`CompassTeaser`, `CompassTeaserMotion`, `compassTeaser_*` assets). The 5.12
> decisions that still hold: restricted keeps the chip; Reduce Motion / background / off-screen show a still frame
> instead of a paused timeline; `showsLocationOffTeaser` gating.

## 1. What changes (summary)

| # | Change | Where |
|---|---|---|
| 1 | The prompt's art becomes a **ghosted real compass** that slowly turns (S1) | 5.12b.1 |
| 2 | New copy: Tessa's subhead only, no title | 5.12b.1 |
| 3 | **Maybe later**: a text button under Turn On Location; sets a persisted dismissed flag | 5.12b.1 |
| 4 | **Dismissed row** (S2 to S6): the moon guide, in a waiting state or an active moon-clock state | 5.12b.2 |
| 5 | Transitions: S1 ⇄ row, and location-off block ⇄ live compass, on the app's standard timing | 5.12b.3 |

Header, phase/rise-set card and the Turn On Location button are **unchanged**. Restricted keeps the existing chip and
dialog (no prompt, no row, no Maybe later): the CTA can't help there (the handoff's and 5.12's assumption; still to confirm).

## 2. S1: the prompt (5.12b.1)

Order under the card: ghosted compass, body, Turn On Location, Maybe later. **No title** (Tessa, 2026-10-13).

- **Ghosted compass:** exactly the handoff README ("S1: Prompt"): 210 pt, 260-unit space, ring r 104 / #5E4D57 2 pt,
  today's rise-to-set arc (#F2C27B, 4 pt, round caps, 6 pt end dots), moon marker, "N"; whole layer opacity 0.42, blur
  1.2 pt; static north tick; "PREVIEW" pill. **Plain ring, drawn for this (Tessa, 2026-10-13, option B):** not the
  live dial. Just the ring, the solid arc with its end dots, the moon marker and the "N", as in the handoff's mock
  (`design/1.9-location-off-flow/Location Off Flow.dc.html`, S1). Positions come from today's real rise and set
  azimuths: a point at azimuth `a` is `(130 + 104 sin a, 130 - 104 cos a)` in the 260-unit space (checked against the
  mock's 115° / 243° sample). The arc runs clockwise from rise to set. The moon marker sits at the live moon azimuth
  when the moon is up, otherwise at the arc's midpoint (proposed; the mock just puts it on the arc). "N" is Nunito
  Sans Bold 14, #B9A898, 14 units inside the ring at the top, and turns with the ring.
- **Motion:** the ring group turns on a 12 s loop, ease-in-out cubic-bezier(.45, 0, .55, 1) per move:
  0° at 0 s, -70° at 3 s, hold to 4.8 s, 40° at 7.8 s, hold to 9.6 s, 0° at 12 s. The tick and pill don't turn.
- **Reduce Motion:** static at 0°. **Background / scrolled out of view:** the still 0° frame (same rule as
  `LocationIllustration.shouldAnimate`), not a paused timeline.
- **No rise or set today** (high latitude, or a day with none): draw the ring, N and tick, plus whichever of the two
  dots exists; no arc. (Proposed default; the handoff doesn't cover it.)
- **Copy:**
  - ~~Title~~ removed (Tessa, 2026-10-13): S1 has no heading, just the compass and the line below it.
  - Body (Tessa, 2026-10-13, replaces the handoff's): **"With location on, you'll see the live compass to point your way"**.
    Nunito Sans 15 / 1.45, #B9A898, max width 300. No final period (as written); Tessa to confirm.
  - All strings live in `CompassViewModel` next to the existing placeholder copy.
- **Buttons:** Turn On Location is the existing button and flow (system prompt, or Settings if already denied). **Maybe
  later** is text-only: 44 pt tall, full width, Nunito Sans SemiBold 16, #B9A898, no background or border, 4 pt below
  the CTA. It sets `locationPromptDismissed = true` and swaps S1 for the row (§4).
- **Dynamic Type:** the body wraps; the art stays 210 pt. Maybe later keeps its 44 pt minimum.
- **VoiceOver:** the compass art and PREVIEW pill are hidden. The body is read first (no title);
  then the two buttons. Maybe later: hint "Hides this. You can bring it back from the compass guide."

### 2.1 As built (5.12b.1, 2026-10-13)

- 5.12b.1 as first built: `CompassGhost` was the live `CompassDial` scaled to 210 pt (face, ticks, numbers, dotted arc),
  which read muddy and hid the arc. **Replaced in 5.12b.1a** by the plain ring above (Tessa chose B). Rise/set are the
  **selected** day's (the card's), plus the moon if today and up.
- Built in 5.12b.1a as `CompassGhost` + `CompassGhostGeometry` (pure placement, tested). Open: the clockwise arc
  is wrong for southern-hemisphere passes, and the pill grows with Dynamic Type over the 210 pt ring at AX3.
- PREVIEW pill: **Nunito Sans SemiBold 11, all caps** (Tessa, 2026-10-13), not IBM Plex Mono (not bundled, not
  adding it). Tracking 0.12 em, #F2C27B, fill #1B1519, 1 pt #4A3A2E border, capsule, padding 7 / 11.
- `showsLocationOffPrompt` (renamed) gates it. After Maybe later a placeholder S2 row (`CompassGuideRow`, no avatar)
  stands in until 5.12b.2.

## 3. S2 to S6: the dismissed row (5.12b.2)

A single tappable row where S1 was. Layout and tokens per the handoff README ("S2 to S6"): padding 12/16/12/12, radius
20, 14 pt gaps, 52 pt avatar (no fill, no border, clipped to the circle), two-line text, chevron.

### 3.1 Which state

Computed from "now", the place and the selected day. **Today only**: on any other date the row is S2 (a countdown
means nothing on another day). It reuses the 5.11 rules, so the row, the card and the compass always agree on up/down.

| State | When (today, moon state from 5.11) | Avatar | Title | Subtitle |
|---|---|---|---|---|
| S2 | Moon down, next moonrise **more than 3 h** away (or none); and after moonset | sleeping | Compass guide is waiting | Tap whenever you want directions |
| S3 | Moon down, next moonrise 1 h to 3 h away | searching | Moonrise in 2 hr 15 min | Want her to show you where? |
| S4 | Moon down, next moonrise 1 to 59 min away | searching | Moonrise in 40 min | same |
| S5 | From moonrise until 15 min after | searching | The moon is rising now | same |
| S6 | 15 min after moonrise until moonset | searching | The moon is up now | same |

- The next moonrise can be **after midnight**: at 10:30 PM with a 12:20 AM rise the row reads "Moonrise in 1 hr 50 min"
  (proposed; the card's own "Set for today" wording is unchanged).
- "Rise" for S5/S6 is this pass's rise (`UpNow.Pass.riseTime`, 5.11 §1.1), so a moon that rose last night is S6, not S5.
- "Under a minute away" counts as S5.
- Styling: S2 border #3A2E35, no fill, chevron #6E5C66, subtitle Regular 13 #B9A898. S3 to S6 border #4A3A2E, fill
  #211A1F, chevron #F2C27B, subtitle SemiBold 13 #F2C27B. Titles Nunito Sans SemiBold 16, #F5EADB.
- Countdown format (handoff): "X hr Y min" from 1 hr; drop "0 min" ("Moonrise in 2 hr"); "X min" under 1 hr. Same
  once-a-minute tick as the card's countdown, and the same rounding, so the two never disagree by a minute.
  **Open (§7):** the card's own countdown reads "in 1h 39m".
- Pure logic goes in a value type (`LocationOffGuide`, proposed) with the formatter apart from it (CLAUDE.md); no
  logic in the view.

- **As built (5.12b.2):** `LocationOffGuide` (`Features/Compass`) and `LocationOffGuideFormatter` (`Formatting`).
  "This pass's rise" is `MoonPass.rise.date` (the date `UpNow.Pass.riseTime` shows), since `UpNow` doesn't exist with
  location off. Minutes come from the shared `UpNowFormatter.countdownMinutes`. The tick is the 60 s guidance clock.

### 3.2 Avatars

Prepared in `design/1.9-location-off-flow/avatars/` (`avatar_sleeping@1x/2x/3x.png`, `avatar_searching@1x/2x/3x.png`):
the handoff's crops, rendered from `sleeping.svg` / `searching.svg` at 52 pt. Use these, in a catalog imageset
(Original rendering), not the 650 KB vector: it would be re-rasterised on every scroll for a 52 pt picture.
`moon-glow` / `moon-halo` stay hidden. The sleeping art is already in `design/d2-luminous-calico/sleeping/`; its
separate tail layer is for a later wag and is **not** part of this work.

### 3.3 Behavior

- **Tap the row** (any state): shows S1 again, with the same transition as §5. Maybe later again: back to the row.
  Re-opening S1 is **not** persisted: a relaunch with the flag set shows the row.
- **Accessibility:** the whole row is one button. Label = title + subtitle. Hint "Shows the moon compass preview."
  At AX sizes the text wraps (no truncation); the avatar stays 52 pt; the chevron stays centred.
- VoiceOver focus: Maybe later moves focus to the row; tapping the row moves it to S1's body. **Not built yet** (goes with the 5.12b.3 swap).

## 4. State and persistence

- `locationPromptDismissed` (per install, persisted): lives in `OnboardingStore` (it already holds first-run flags),
  with the in-memory fake and the DEBUG reset (Show onboarding / Forget saved place clear it, as they clear
  `hasSeenFirstFindPass`). If the agent finds a better home, say so in the report.
- **Cleared when location is granted** (handoff recommendation, adopted): if they grant, then revoke later, they see
  S1 once more.
- Shows only where `showsLocationOffPrompt` (renamed from `showsLocationOffTeaser` in 5.12b.1) is true (not determined, denied, services off); rename it to what
  it now gates (`showsLocationOffPrompt`) and keep restricted on the chip.
- Location granted: prompt/row go; the live compass takes over (§5).

## 5. Transitions (5.12b.3)

### 5.1 What the video shows (`location_on_off.mov`, 60 fps, iPhone, 2026-10-13)

| Moment | What happens | Time |
|---|---|---|
| Turn on in Settings, return | the hint block **vanishes in one frame**; the dial then fades in after a short empty gap | cut at 4.48 s; dial rising from ~4.53 s |
| Turn off in Settings, return | the dial fades out (about 0.25 s), then the hint block **appears in one frame**, full opacity | dial 14.20 to 14.45 s |
| Turn on again | same as the first | cut at 24.35 s |

Cause (to confirm by a reproduce-and-diff step before any fix): the location-off block is a plain `switch` on
`visibility` with no transition, so it cuts; the dial is held out until the first heading (`CompassEntrance`
`.waitingForHeading`, up to 0.5 s), which is the empty gap. The dial's own fade-in is the standard one.

### 5.2 Target

Everything on the app's existing timings, not new ones:

- **Block in:** fade + 8 pt rise, 300 ms ease-out (`ContentLoadIn.duration`, `.rise`). **Block out:** 200 ms fade,
  no rise (`LaunchStage.phaseCycleFadeOutDuration`). Reduce Motion: the fades, no rise.
- **Location off to on:** the prompt/row stays (non-interactive) until the dial's entrance leaves
  `.waitingForHeading`, then one crossfade: prompt/row out 200 ms while the dial comes in 300 ms (readout and settle
  as `CompassEntrance` already does). No blank gap, and the height change eases with the fade rather than jumping.
- **On to off:** the dial out 200 ms, then the prompt/row in 300 ms with the rise, never both at full opacity.
  Sensors stop as now (visibility, not the animation, decides that).
- **S1 to row, row to S1:** the "One container" transition of §5.3 (supersedes the earlier ~250 ms crossfade).
- **Launch / place change / date step** keep their current load-ins (LOADER.md §12); only the swap changes.
- Fade and height share one animation so the scroll content never jumps under the user's finger.

### 5.3 Prompt ↔ row: "One container" (design option 1d; Tessa, 2026-10-13)

Source: `design/1.9-location-off-flow/TRANSITION.md` and `Location Off Transitions.dc.html` option 1d (Replay; slow
motion 3x to study). Where it disagrees with the S1 spec above, it wins, **except for the title**: Tessa removed S1's
title, so the title track and its space are dropped here.

**Why:** the video `preview_transition.MP4` (60 fps) shows S1 → row and row → S1 each change in **one frame**, three
cuts in six seconds, and everything below jumps with them.

**Layout change to S1.** S1 sits inside the same outlined card as the row, so the two states are one container that
resizes: 350 pt wide (screen width − 40), 1 pt border #3A2E35, no fill, content clipped to the card; corner radius
**24 expanded → 20 collapsed**. The ghost is **180 pt** here (not 210), centred, 20 pt from the card's top. Collapsed,
the card *is* the row (same border). Heights are the content's own (so Dynamic Type works), animated between the two
measured values; the mock's numbers are 420 expanded (with a title) and 78 collapsed. Without the title, expect about
386 expanded (proposed; derived: the body moves up 34 pt, to 212, the CTA to 270, Maybe later to 330).

**Collapse** (tap Maybe later). Every track eases with **cubic-bezier(0.32, 0.72, 0, 1)**
(`UnitCurve.bezier(startControlPoint: (0.32, 0.72), endControlPoint: (0, 1))`). Times in ms from the tap:

| Element | Start | Dur | From → To |
|---|---|---|---|
| Maybe later | 0 | 180 | opacity 1→0, y 0→+10 |
| Turn On Location | 20 | 180 | opacity 1→0, y 0→+10 |
| Body | 40 | 180 | opacity 1→0, y 0→+10 |
| PREVIEW word | 0 | 140 | opacity 1→0 |
| **Compass** | 60 | 560 | scale 1→0.2889 (52/180) and move so its centre lands on the avatar centre (39, 39 in the card); opacity holds at 1 until 60% of the move, then →0 |
| Card height | 60 | 560 | expanded → 78 (collapsed row height) |
| Card corner radius | 60 | 560 | 24 → 20 |
| Avatar (sleeping cat, or the awake one in S3 to S6) | 400 | 320 | opacity 0→1, scale 0.85→1 |
| Row title + subtitle | 440 | 300 | opacity 0→1, x −8→0 |
| Chevron | 480 | 260 | opacity 0→1 |

(The mock's title track, 60 ms start / 180 ms, is dropped.) Total about 740 ms. The compass scaling into the avatar
slot is the hero move. Derive the compass's move from the real geometry (avatar centre minus compass centre), not the
mock's (−136, −71).

**Expand** (tap the row): the same timeline mirrored, each track starting at 740 − (start + duration) with its from
and to swapped: chevron, text and avatar fade out first; the card grows and the ring scales up out of the avatar spot;
then body, Turn On Location and Maybe later fade in last (bottom-most last).

### 5.4 Rules for the One-container transition

- The ghost's rotation loop keeps running through the move.
- Taps on the prompt's buttons are disabled once a collapse starts, and on the row until the transition finishes
  (no interruption or reversing mid-way; it's 740 ms).
- **Reduce Motion:** a 200 ms crossfade plus the height change; no scale move, no offsets.
- The row keeps the current state's copy and avatar (S2, or S3 to S6); expanding never changes the row's state.
- Content below the card (the DEBUG readout today) moves with the card's height on the same curve, so nothing pops.
- VoiceOver: focus moves as in §3.3 once the transition ends (Maybe later → the row; row → S1's body).
- Timing and the state (which layer is shown, which taps are live) are pure and unit-tested; the animation is driven
  from one source (a progress value or keyframes), not a stack of unrelated delays, so the tracks can't drift.

### 5.5 Tests / evidence

- Pure timing constants and the state machine (which block is shown, when) in unit tests.
- Frame evidence: a screen recording of the three moments in §5.1 before and after, extracted at 60 fps (frame
  tracking, as in HANDOFF "Device videos"); the report says how many frames each swap takes.

## 6. Build order (one commit each, small runs)

- **5.12b.1** S1: ghosted compass, new copy, Maybe later, `locationPromptDismissed` (store, reset on grant, DEBUG
  reset), replace the cartoon compass (delete `CompassTeaser*` and `compassTeaser_*`). Row not yet built: Maybe later
  swaps to a placeholder S2 row without the countdown, to be completed next.
- **5.12b.2** The row: S2 to S6, state logic + formatter + tests, avatars, tap to reopen S1.
- **5.12b.3a** S1 in a card + the prompt/row "One container" transition (§5.3, §5.4). Reproduce-and-diff first.
- **5.12b.3b** The location off to on swap (§5.1 and §5.2 above), plus the VoiceOver focus moves (§3.3).

## 7. Open

- **Countdown wording:** the handoff's "Moonrise in 2 hr 15 min" sits a few points from the card's "in 1h 39m".
  Default is the handoff's; the alternative is the card's `1h 39m` form for one voice.
- Body copy has no final period (as given).
- After-midnight rises counted in S3/S4 (§3.1), and the no-rise/no-set ghost (§2): proposed defaults.
- The optional tail wag on the sleeping cat: later.

## 8. 5.12b.1b polish (Tessa, 2026-10-13, after the ghost ring)

- **PREVIEW is a plain word, not a pill:** no fill, no border, so it can't read as a button. Nunito Sans SemiBold 11,
  all caps, tracking 0.12 em, gray (`Theme.Colors.dialNumber`, #A8939C). Centred over the ring. Decorative: hidden from
  VoiceOver. Stops scaling with Dynamic Type at `.xxxLarge`, so it never covers the ring at AX sizes.
- **No title** on S1 (see §2).
- **Arc direction follows the sky, not always clockwise:** the arc runs rise to set through the side of the sky the moon
  crosses: via south (clockwise on the ring) for a place at or north of the equator, via north (anticlockwise) south of
  it. Fixes southern-hemisphere places.
- **No rise and no set today: no moon marker either** (ring, N and tick only). A marker with nothing to anchor it
  read as a stray dot.
