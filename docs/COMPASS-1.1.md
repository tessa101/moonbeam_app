# Step 5.4.x Spec: Compass 1.1 (before 5.5)

> Source: Claude Design `design/1.1/Moon Signal Compass 1.1.dc.html` (section 4a, four states) and the
> "now" pulse video. Extends DESIGN-1.1.md §3.1, §3.3 and §3.3a (5.8 arc) and COMPASS.md.
> Behavior doesn't change unless this doc says so. Owner: Tessa · _Decided 2026-10-02_

Items marked **(proposed)** are Cowork defaults Tessa accepted ("agree with recommendations"); build them as written.

---

## 1. What changes

| Area | As built (5.3 / 5.4 / 5.8) | Now |
|---|---|---|
| Sentence | "Where will the moon / be 📅 tonight / in 📍 [city]?" | **"Where can I find / the moon 📅 today / in 📍 [city]?"** (§2) |
| Date token | "tonight" / "on Sat, Oct 3" | **"today"** / "on Sat, Oct 3" |
| Moon card | Header, phase, rise/set | + **Up now** row; lock highlights the matching cell (§3) |
| Heading indicator | 6 × 17 capsule outside the arc | **Needle** from under the readout into the tick ring (§4) |
| Ticks | Dots every 15° | Lines every 2°, longer every 10°, heavy every 30° |
| Degree numbers | None | Every 30° between cardinals, **fixed size** |
| Cardinals | Nunito Sans 600 | **Young Serif** |
| Centre | Plain face | Fixed crosshair |
| Target labels | ↑ / ↓ inside the rim | **"↑ Rise", "↓ Set", "Now"** outside the arc; pulse on the Moon (§5) |
| Accuracy notes | Note pill below the dial | **Under the readout**, above the dial (§4.1) |

Unchanged from 5.8: 196 pt dial, the arc (track, dots, travelled/remaining styles, which pass, direction),
the 24 pt Moon glyph (28 locked), rise/set dots on the arc, lock pill, halo, haptic.

## 2. Sentence

- Copy, three forced lines: **"Where can I find" / "the moon 📅 [date]" / "in 📍 [city]?"**. Replaces the
  "Where will the moon / be 📅 [date] / in 📍 [city]?" lines (DECISIONS.md 2026-10-01 "Madlib sentence").
- **Fit rule unchanged:** at the default size (`.large`) the three lines share one scale, minimum 0.7×, and only
  then wrap; at every other size nothing shrinks and long lines wrap. **No ellipsis, ever.** The mock's fixed
  three lines with "Rancho Santa Mar…" is not adopted.
- **Date token:** "today" when the selected day is today (replaces "tonight"); "on Sat, Oct 3" otherwise; with
  the year for another year. VoiceOver "Date, today, button". With no place, "today" is plain words (as
  "tonight" was). Tessa wants to try "today" and see how it feels.
- VoiceOver header: "Where can I find the moon today in Irvine, C A?". Order unchanged.
- Update tests and previews that expect "tonight" or the old lines.

## 3. Up now row (moon card)

> **Superseded by §9.2 (5.4.6a):** a one-line pill when up, "● Rises …" when down, no bar. VoiceOver unchanged.

Third row in the card, under rise/set. Same height whether the moon is up or down.

- **Moon up:** "Up now" (footnote 600, `textBody`) left, live bearing "266° W" (`accent`) right. Below, a
  progress bar from the **last rise** to the **next set**, those times at each end (11 pt, `textSecondary`).
  Track `stroke`, filled part `accent` 60%.
  - **Thumb = the moon phase glyph** (~14 pt, `PhaseGlyph`, 1.5 pt `surface` outline, soft `accent` glow), not
    the mock's plain white dot.
  - If the two different rise times on screen (last night's in the bar, today's in the column) still read badly
    on device, **drop the bar's end times**. Tessa decides from the screenshots.
- **Moon down:** grey dot (`#5E4D57`), "Below the horizon"; right **(proposed)**: "Rises in 34 min" under
  60 min, else "Rises at 10:06 PM", or "Rises tomorrow 9:12 AM".
- **Other dates (proposed):** row hidden (the dial has no Moon target then either).
- **Refresh:** the Moon target's 30 s tick and foreground recompute (COMPASS.md §1).
- Style: fill `#251C22`, radius 14, padding 8 / 10.
- **VoiceOver:** up: "Moon up now, west, 266 degrees. Rose 10:06 PM, sets 1:28 PM." Down: "Moon below the
  horizon, rises in 34 minutes."

**Lock highlight:** on lock, the matching cell (Moonrise, Moonset, or Up now for Moon) gets a 1 pt `accent`
border, `accent` 10% fill, radius 14, label in `accent`. Unlocked cells keep a transparent border so nothing
shifts. No VoiceOver change.

## 4. Dial

Geometry below is the mock's (104 pt dial radius) scaled to our 98 pt: multiply by ~0.94.

- **Readout:** Young Serif **24** unlocked and in the pill (mock had 28 / 22; keep equal so nothing jumps).
  Slot rules as built.
- **Needle:** 3 pt round-capped line from just under the readout (or under the accuracy note, §4.1) into the
  tick ring, crossing the arc at 12 o'clock. `textPrimary`; `accent` on lock. Replaces the capsule. Fixed.
- **Ticks** (placed at azimuth − heading, as built): every 2° minor (1 pt, `#5E4D57`), every 10° mid (1.4 pt,
  `#A8939C`), every 30° heavy (2.2 pt, `textBody`); **N tick `accent`**. Outer end at the rim; lengths ~7 / 11 /
  15 pt. Minor ticks are under 3:1, decorative; mid and heavy carry the reading. Check on device for shimmer
  while turning; fallback is 5° minors.
- **Degree numbers:** 30, 60, 120, 150, 210, 240, 300, 330 (not on cardinals), ~72 pt from the centre.
  - **Nunito Sans 600, 11 pt, fixed** (`Font.custom(_:fixedSize:)`, no Dynamic Type), `.monospacedDigit()`,
    `#A8939C`, upright.
  - **Hidden from VoiceOver**, no Large Content Viewer: nice to have, not needed. No IBM Plex Mono.
- **Cardinals:** **Young Serif**, 17 pt cap kept (`.subheadline`), upright, ~58 pt from the centre.
  N `accent`, E/S/W `textPrimary`.
- **Crosshair:** fixed, ±28 pt, 1 pt `#5E4D57`, 2 pt centre dot `tick`. Decorative, hidden from VoiceOver.

### 4.1 Accuracy notes move under the readout (Tessa, 2026-10-02)

> **Superseded by §9.4 (5.4.6c):** the notes move to a fixed bar above the home indicator.
In low accuracy there's no lock, so the space under the readout is free. Use it for the warning until it's
resolved.

- **Moves:** the low-accuracy line (generic or reason), the Precise Location line with **Use Precise Location**,
  and the aha line ("There you are!…"). Same `CompassNote` style and copy, centred, max width 330, directly
  under the readout. The needle starts below the note.
- **Stays below the dial:** Nearby. **Unchanged:** location off and Far (dial hidden, note alone).
- **Readout:** still shows the live heading; dial greyed as built.
- **Layout (proposed):** the dial moves down while the note shows. The 25° / 20° hysteresis keeps it from
  flicking. If it still jumps on device, reserve the space instead (fallback, not built now).
- **VoiceOver:** unchanged (the low-accuracy line is already part of the readout's label; the button stays
  reachable after it).

## 5. Targets on the arc

- **Labels:** "↑ Rise", "↓ Set", "Now": Nunito Sans 700, 12 pt fixed, `textBody`, `bg` text shadow, upright,
  **outside the arc** (~24 pt beyond the track, ~138 pt from the centre). Replace the ↑ / ↓ inside the rim.
  - **Locked target drops its label** (the pill says it).
  - **Collisions (proposed):** when two labels would overlap (~15° apart), "Now" keeps its label, the other drops
    its text; its dot stays.
  - Check the block still fits 353 pt wide (labels add width at 3 and 9 o'clock).
- **Pulse:** with the moon up, a ring expands from the Moon glyph (radius 10 → 24 pt beyond the glyph edge,
  `accent` 2 pt, opacity 0.8 → 0, 1.8 s, repeating).
  - Stops at the **first lock on any target**; doesn't return until the app relaunches.
  - **Reduce Motion:** a static 2 pt `accent` ring instead, same stop rule.
  - None when the moon is down or on other dates. Hidden from VoiceOver.

## 5a. Sensors start when any part of the compass is visible (fix, 2026-10-02)

- **Bug (device, after 5.4.1):** the Up now row pushed the dial partly below the fold. `onScrollVisibilityChange`
  defaults to a 0.5 threshold, so the sensors stayed off until half the compass was on screen: blank readout,
  dimmed marks, no turning until you scroll.
- **Fix:** `onScrollVisibilityChange(threshold: 0.1)` in `LocationScreen`; `onDisappear` unchanged. COMPASS.md §1
  "on screen" now means **any part of the compass visible**. Build before 5.4.2.

## 6. Pinned-bar rule: decided (2026-10-02)

See §9.6: the bar shows when the dial's centre is below the fold (SE-size phones, AX sizes). Built as 5.6.

## 7. Build order (one commit each)

- **5.4.1** Up now row + lock highlight (§3)
- **5.4.2** Dial: readout 24, needle, ticks, numbers, serif cardinals, crosshair (§4)
- **5.4.3** Accuracy notes under the readout (§4.1)
- **5.4.4** Target labels outside the arc, collision rule, pulse + Reduce Motion (§5)
- **5.4.5** Sentence: new lines, "today" token (§2)
- **5.4.6a–c** Layout pass (§9.8), after Tessa's device review of 5.4.2–5.4.5

Screenshots for each, at default size on the smallest supported phone and a 393 pt phone: moon up / locked on
set / locked on moon / moon down / low accuracy / Precise off / Nearby.

## 8. Tests

- Date token: today → "today"; other day → "on Sat, Oct 3"; other year with the year; no place → plain "today"
- Sentence lines: "Where can I find" / "the moon [date]" / "in [city]?"; fit rule unchanged; never truncates
- Up now: up → bearing + last rise / next set; down → "Rises in N min" under 60, "Rises at …", "Rises tomorrow …";
  hidden on other dates; changes on the 30 s tick when the moon rises or sets (fake clock)
- Lock highlight: rise → Moonrise cell, set → Moonset cell, moon → Up now; none unlocked
- Accuracy note placement: low accuracy / Precise off / aha → under the readout; Nearby → below the dial
- Label collision: within the threshold, "Now" keeps its label
- Pulse: on with the moon up and no lock yet this launch; off after the first lock and stays off; off when down

## 9. 5.4.6 Layout pass (Tessa, 2026-10-02 evening)

> Source: `design/1.2-layout/` (Tessa's mocks + the 5.4.5 device screenshot). Replaces the earlier A / B / C
> spacing options. **Goal:** a bigger dial that, with its arc and labels, sits above the fold at the default size
> on a 402 pt iPhone 17. SE-size phones and AX sizes use the pinned bar (§9.6).

### 9.1 Sentence
- Tighter line height (the mock's lines sit closer than 1.5×; start at ~1.2× and match the mock).
- **Keep "today"** (the mocks say "tonight"; ignore that). Fit rule unchanged.
- More space between the sentence and the card than now (see §9.7).

### 9.2 Moon card
- **Header row:** phase glyph (real `PhaseGlyph`, ~44 pt) left; two text lines; ‹ › right. Replaces the separate
  phase block and its divider.
  - Line 1: **"Today · Fri, Oct 2"** (date on top, as now). Line 2: **"Last Quarter · 53% lit"** (phase name
    `textPrimary`, "· 53% lit" `textSecondary`). Drop "at midnight" (illumination is still computed at local
    midnight; VoiceOver keeps "53 percent lit at midnight").
  - Divider under the header row stays.
- **Rise / set:** tighter padding and gaps (card padding 16 → 12, internal gap 14 → 10; columns hug content).
  **AM / PM stays the smaller size, as built.** Time zone abbreviation unchanged.
- **Up now (replaces §3's bar):**
  - Moon up: one-line pill **"● Up now · 266° W"** (`accent` text, `#251C22` fill, radius = height / 2,
    ~36 pt tall). No progress bar, no end times, no thumb.
  - Locked on the Moon: pill gets the 1 pt `accent` outline (the lock highlight, §3).
  - Moon down: plain line **"● Rises 11:10 PM"** (grey dot, `textSecondary`, no fill), "Rises in 34 min" under
    60 min, "Rises tomorrow 9:12 AM" as before. No "Below the horizon" text.
  - Other dates: hidden (unchanged).
  - VoiceOver unchanged from §3.
- **Lock highlight on rise / set:** unchanged (Moonrise / Moonset cell outlined).
- **As built (5.4.6a):** card padding 12 all round (was 16 / 18), row gap 10, rise/set cells lose their 76 pt
  minimum height (equal widths kept, for the lock outline). Phase line falls back to two lines ("Waning Crescent"
  / "21% lit") when it doesn't fit, never a stranded "·". At AX sizes the two text lines sit under the glyph and
  ‹ ›. Pill 36 pt min height, lock = 1 pt `accent` outline. Down with no rise in reach: the line is hidden.

### 9.3 Compass
- **Dial bigger:** target ~300 pt across the face (≈ 75–80 % of a 402 pt screen) with the arc close around it.
  Scale ticks, numbers (still **Nunito Sans 11 pt fixed**), cardinals and crosshair with it. Find the largest
  size that fits on the iPhone 17 at the default size with §9.7's spacing; report it.
- **Needle:** shorter; starts just under the readout and ends in the tick ring (the readout → dial band shrinks).
- **Locked on the Moon:** the Moon glyph sits at 12 o'clock on the arc, over the needle's top.
- **Arc:** close around the face; travelled part solid when locked, dotted when unlocked (match the mock).
- **Labels "↑ Rise" / "↓ Set" / "Now":** even gap from their dot at every angle (label placed along the radius,
  ~10 pt from the dot's outer edge to the nearest edge of the text). Fixes the 5.4.4 uneven spacing.
- Unchanged: readout 24 pt, lock pill, pulse until first lock (with "Now" label), collision rule, Reduce Motion.

### 9.4 Bottom bar for notes (reverses 5.4.3 / §4.1)
One bar just above the home indicator: radius 24, `#251C22` fill, 1 pt `stroke` border, 16 pt side margins,
icon left, text (footnote, `textBody`), optional button right. **Fixed** to the bottom (`safeAreaInset(edge:
.bottom)`), so content scrolls above it, never under it. The top of the screen never moves when it appears.

| State | Icon | Copy | Button |
|---|---|---|---|
| Precise off | location-dotted | "Using your approximate location. Precise gives a better reading." | **Use Precise** (amber) |
| Compass accuracy low | "!" in an amber circle | "Compass accuracy is low. Move away from metal or a charger, or wave your phone in a figure 8." (**one line of copy for every low-accuracy reason**) | none |
| Aha | as built | as built ("There you are!…") and its timing | none |
| Nearby | as built | as built | none |

- Low accuracy: heading and dial stay put and dim to 50 %; no lock. When it recovers, the bar goes away and the
  heading fades back in.
- Priority if two apply: Precise off > low accuracy > Nearby > aha (one bar at a time).
- **Unchanged:** location off and Far (dial hidden, note alone, as built).
- **VoiceOver:** the bar reads right after the readout; the button stays reachable.
- The 25° / 20° hysteresis stays for accuracy; the "dial jumps down" fallback is no longer needed.

### 9.5 States to screenshot
Moon up unlocked (pulse, "Now") · locked on Moon · locked on rise · locked on set · moon down · other date ·
Precise off · low accuracy · aha · Nearby · location off · Far. On iPhone 17 (402 pt) and SE 3, at default,
AX1 and AX5.

### 9.6 Pinned bar rule (closes §6; build as 5.6)
- Shows when the **dial's centre is below the fold** (in practice: SE-size phones and AX sizes). Hides once the
  centre is on screen. Sensors keep running while it shows.
- Glass bar: live readout left, **"Compass ↓"** (amber) right; tap scrolls the dial up under the heading.
- On lock the bar turns amber and shows the lock text.
- With a bottom note (§9.4) on small phones: the note keeps the bottom, the pinned bar sits on top of it.
- AX sizes: same rules as before (DESIGN-1.1.md reflow); check on device.

### 9.7 Spacing
Tessa wants **more space** between: sentence → card, card → readout / pill, readout / pill → dial. Pay for it
with §9.1–9.3's tightening. Start from the mock's proportions; report each gap in pt and the dial's bottom
edge (arc and labels included) vs the fold on iPhone 17 and SE 3 in `.agent-reports/5.4.6/`. If it doesn't fit
on the iPhone 17, shrink the dial before the gaps, and say by how much.

### 9.8 Build order (one commit each)
- **5.4.6a** Card: header row, tighter rise/set, Up now pill / down line (§9.2)
- **5.4.6b** Compass: bigger dial, shorter needle, arc, Moon at 12 on lock, even labels, spacing, sentence line
  height (§9.1, 9.3, 9.7) + fit report
- **5.4.6c** Bottom bar for notes, reverting 5.4.3 (§9.4)
- **5.6** Pinned bar (§9.6), after Tessa checks 5.4.6 on device

### 9.9 Tests
- Header: date line then "Phase · N% lit"; VoiceOver still says "at midnight"
- Up now: up → pill text with bearing; locked on Moon → outlined; down → "Rises …" variants; hidden other dates
- Bottom bar: Precise off / low accuracy / aha / Nearby → bar with the right copy and button; priority order;
  location off / Far unchanged
- Labels: gap from dot equal (± 1 pt) at 0°, 90°, 180°, 270° and 45° steps
- Pinned bar: shows when the dial centre is below the fold, hides when on screen; lock turns it amber

## Decision log

- **2026-10-02 (Tessa):** Compass 1.1 reviewed. Keep the Up now row, lock highlight, needle, ticks, crosshair,
  text target labels and the pulse. Sentence: adopt the mock's lines ("Where can I find / the moon [date] / in
  [city]?") but keep the existing fit rule, never an ellipsis. Date token **"today"** for today (replaces
  "tonight"; try it). Degree numbers fixed-size, nice to have. Cardinals in **Young Serif**. Up now thumb is the
  **moon glyph**; if the two rise times still feel off, drop the end times. **Accuracy warnings go under the
  readout** (no lock is possible then). Other gaps: Cowork's recommendations (other dates hidden, collision
  rule, Reduce Motion pulse, equal readout sizes; pinned-bar rule decided before 5.5).
- **2026-10-02 (Tessa, after the 5.4.1 device check):** the dial sits partly below the fold and stays frozen until
  scrolled. Fix the sensor threshold now (§5a). Spacing waits: build 5.4.2–5.4.5 first, then a **5.4.6 spacing pass**
  on the finished screen (§9), then the pinned-bar rule.
- **2026-10-02 evening (Tessa, layout mocks in `design/1.2-layout/`):** bigger dial; compact card header (date over
  "Phase · N% lit"); Up now as a one-line pill; notes in a fixed bottom bar (reverses 5.4.3); pinned-bar rule; even
  label gaps. Keep "today", small AM/PM, Nunito Sans numbers, real phase glyph. Spec §9.
