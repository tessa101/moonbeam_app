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
> **Superseded again by §9.14 (5.4.7):** Up now is a middle column between rise and set; no row.

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
- **5.4.7** Up now as the middle column between rise and set (§9.14)

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
  > **Superseded by §9.14 (5.4.7):** the pill row and the down line go; Up now becomes the middle column.
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
- **5.4.7** Up now as the middle column (§9.14), after 5.4.6c
- **5.4.8 + 5.6, one run (Tessa, 2026-10-03), one commit each, 5.4.8 first:**
  - **5.4.8** "After midnight" smaller (§9.16 item 1; the ‹ › bug, item 2, is parked)
  - **5.6** Pinned bar (§9.6); the 5.4.6 / 5.4.7 device check is done (§9.16). Fit report against the 5.4.8 card.
    AX sizes: best effort, report what breaks; 5.5 fixes it.
- Then **5.9** launch loader (LOADER.md), then **5.5** AX reflow last.

### 9.9 Tests
- Header: date line then "Phase · N% lit"; VoiceOver still says "at midnight"
- Up now: up → pill text with bearing; locked on Moon → outlined; down → "Rises …" variants; hidden other dates
  (replaced by §9.14's tests in 5.4.7)
- Bottom bar: Precise off / low accuracy / aha / Nearby → bar with the right copy and button; priority order;
  location off / Far unchanged
- Labels: gap from dot equal (± 1 pt) at 0°, 90°, 180°, 270° and 45° steps
- Pinned bar: shows when the dial centre is below the fold, hides when on screen; lock turns it amber


### 9.10 Device check after 5.4.6a (Tessa, 2026-10-02 night) — fold into 5.4.6b
Source: device screenshots, iPhone 17. 5.4.6b / 5.4.6c weren't built yet, so the dial size and the Precise note
placement are still 5.4.5's; those are covered by §9.3 and §9.4.

- **Phase line (option A):** "Phase · N% lit" stays on **one line**; at the default size it scales down to 0.85x
  before wrapping (same idea as the sentence fit rule). Card height stays the same across phases.
- **Card cells:** less space between the label ("↑ Moonrise") and the time: ~2 pt (was 4), keeping the Young Serif
  ascenders clear. Time → direction gap unchanged.
- **Lock pill smaller:** text 24 → **20 pt**, padding scaled down to match (~10 / 18). The **direction letters**
  ("ENE", "S") use the smaller day-period treatment from the card times (smaller size, same baseline).
  Apply the same to the **unlocked readout** so pill and readout still match (no jump on lock).
- **Needle shorter:** it only needs to point at the degree. Starts ~6 pt above the arc track and ends at the inner
  end of the major ticks (~28 pt total at the current dial; scale with the dial). Readout → dial gap shrinks with it.
- **Dial bigger:** as §9.3 (~300 pt face target); the device dial still looks small.
- **Missing rise / set:** cells **top-aligned** (label on the same line as the other column's label; nothing centred).
  Copy replaces "No moonrise today" / "No moonset today":
  - Line 2 (body, `textBody`): **"After midnight"**
  - Line 3 (where the direction goes, `textSecondary`): the next event, **"Sun 12:20 AM"** (place's zone).
  - VoiceOver: "Moonrise, after midnight, Sunday 12:20 AM."
  - If the next event is more than a day away (polar edge): line 2 "Not today", no line 3.
  - Why it's true: a day with no moonrise is always one where the moon rose late the night before and next rises
    just after midnight.
- **Precise / accuracy notes:** must be in the bottom bar (§9.4); still 5.4.6c.

### 9.11 As built (5.4.6b) — fit report `.agent-reports/5.4.6/5.4.6b-fit.md`
- **Dial size:** set by the screen's width, not height: the "↑ Rise" / "↓ Set" labels at 3 and 9 o'clock must end
  inside the screen (they may use the 20 pt side margin). That caps the face at **260 pt on a 402 pt phone** (233 pt
  on the SE 3); §9.3's ~300 pt would push a side label ~20 pt off screen. Vertically it fits on the iPhone 17, so
  no shrink for height. Ticks, number and letter distances, letters and crosshair scale from the 196 pt dial.
- **Gaps:** sentence → card 28 (was 20), card → readout 32 (was 24), readout → needle top ~35 (was ~12). The dial's
  frame keeps a label's room (38 pt) above and below the arc, so a label near 12 o'clock never hits the readout.
- **Needle:** 6 pt above the arc to the inner end of the heavy ticks: 43 pt at 260 pt (not §9.10's ~28 pt
  estimate; those endpoints give 38 pt even at the old 196 pt dial).
- **Labels:** placed by `CompassTargetLabels.centreDistance`, 10 pt from the mark's edge to the label's box at any
  angle (the "Now" label from the Moon glyph's edge, 12 pt radius).
- **Arc:** travelled part a solid hairline while locked, dots otherwise; still 30%.
- **Lock pill / readout:** Young Serif 20 pt, direction letters at 0.6× (12 pt) on the baseline; pill padding 8 / 16.
- **Phase line:** steps 1, 0.95, 0.9, 0.85 at the default size, then two lines. On the SE 3, "Waning Crescent ·
  42% lit" still needs two lines at 0.85 (card +25 pt there).
- **"After midnight":** the next day's event from `moonDay(for:on:)`, so no new service call; "Not today" when the
  next day has none either.


### 9.12 Device check after 5.4.6b (Tessa, 2026-10-03) — fold into 5.4.6c
- **Readout and lock pill:** degrees at the **card time size** (`Fonts.display`, Young Serif 24, `.title2`); direction
  letters as **real capitals at 0.7x** (~17 pt), same face, on the baseline. Not small caps (single letters read as
  lowercase "w"). Readout and pill stay identical so nothing jumps on lock. Pill padding back to ~10 / 18.
- **Missing rise / set cell:** "↑ Moonrise" and "↓ Moonset" labels on the **same baseline** (the missing cell sits ~5 pt
  low now). **"After midnight" / "Not today" use the time font** (`Fonts.display`, `textPrimary`) in the time's slot;
  the next time ("Sun 12:20 AM") stays in the direction slot. If "After midnight" doesn't fit the column at the
  default size, scale it down (min 0.8x) before wrapping.
- **Needle:** ~28 pt as §9.10 asked. Keep the tip where it is (inner end of the heavy ticks) and start it lower, just
  above the arc track, or shorten it into the tick ring; whichever gives ~28 pt. Report the length.
- **Phase line:** **always one line** at the default size, on every phone. Steps down to 0.7x (was 0.85x); if it
  still doesn't fit at 0.7x, drop " lit" ("Waning Crescent · 42%"). VoiceOver unchanged.
- **Bottom label in the home-indicator band:** accepted for now; recheck with the bottom bar.

### 9.13 As built (5.4.6c) — report `.agent-reports/5.4.6/5.4.6c-bar.md`
- **Bar:** as §9.4. Heights at the default size: Precise 82 (Use Precise beside the text; under it at AX sizes),
  low accuracy / Nearby 64, aha 48. Text capped at AX1, so a bar is at most ~193 pt (AX5 was up to 498 on the SE 3).
- **On load it covers the dial's bottom:** iPhone 17 bar tops 758–792 vs face bottom 814 (centre 684 clear); SE 3 bar
  tops 585–619 vs centre 628.5, so the centre is covered. Content scrolls clear above it.
- **Held note:** the bar is a safe-area inset, so at large sizes it can push the compass off screen and stop the
  sensors. The bar keeps its last note while they're paused, until the next reading (Precise's goes if Precise turns
  on; aha isn't held). Without it the bar flickered in and out.
- **§9.12:** readout / pill Young Serif 24, capitals at 0.7×, pill 10 / 18; missing-cell labels aligned, "After
  midnight" in the time font (0.8× before wrapping); needle 28 pt to the heavy ticks; phase line to 0.7×, then
  without " lit". On the SE 3 the no-moonrise "After midnight" still wraps at 0.8×.

### 9.14 5.4.7 Up now moves between rise and set (Tessa, 2026-10-03)
Source: `design/1.3-upnow/` mocks **7a** (up now), **7b** (locked on the Moon), **7c** (not up), Tessa 2026-10-03, after her paper
sketch. **Goal:** win back vertical space by removing the Up now row under rise / set (~34 pt; the space goes
under the dial, gaps unchanged). **Only the moon card's rise / set / Up now area changes.** Header row, phase line,
sentence, gaps, dial, needle, readout, lock pill, bottom bar and everything else stay as built (§9.13).
The mocks' sentence token ("now" / "tonight") is not adopted: **keep "today"**.

- **Moon up (today only), 7a:** one row, three columns: **↑ Moonrise · Up now · ↓ Moonset** (chronological).
  - Moonrise column leading, Moonset column trailing, Up now centred between them. Rise / set cells as built.
  - **Up now cell**, top-aligned with the other two:
    - Label slot: the **moon phase glyph** (`PhaseGlyph`, ~16 pt), sitting **on the connector line**.
    - Time slot: **"Up now"**, Young Serif in `accent`, a step smaller than the times (match the mock, ~20 pt).
    - Direction slot: live bearing **"266° W"**, same style as the cells' direction line, `accent`.
  - **Connector line** at the labels' centre line, between the Moonrise label and the Moonset label, broken by the
    glyph: **rise → glyph thin solid**, **glyph → set dotted**, same colour / opacity as the dial's arc (travelled
    solid, remaining dotted). Decorative, hidden from VoiceOver.
  - The **separate Up now row is removed**. Live updates on the 30 s tick, as now.
- **Locked on the Moon, 7b:** the Up now cell gets the lock highlight like Moonrise / Moonset (1 pt `accent`
  border, `accent` 10% fill, radius 14). The connector line stops at the outline. Unlocked: transparent border, so
  nothing shifts on lock.
- **Moon down, or other dates, 7c:** **no middle column.** Rise stays leading, set stays trailing, and **one dotted
  line at 40%** joins their labels (matches the dim arc on the dial). The down line ("● Rises …") is **dropped**.
- **Card height is the same in both states**, so nothing below it moves when the moon rises or sets.
- **Fit:** at the default size, text in a cell (time, "Up now", "After midnight") scales down to **min 0.8x** before
  wrapping; never an ellipsis. The connector is the first thing to give: it shrinks to a minimum of ~12 pt per side,
  then hides. Report column widths and any scaling on the iPhone 17 and SE 3.
- **AX sizes (proposed):** if three columns don't fit, keep rise / set as built (no connector) and show Up now as the
  5.4.6a pill row under them.
- **VoiceOver:** strings unchanged (§3); reading order Moonrise → Up now → Moonset.
- **Watch on device:** in the morning the moon rose *last night*, but the Moonrise column shows *tonight's* rise
  (7a: up at 7:54 AM, "11:10 PM" on the left). The solid "rise → now" line can read as "rose at 11:10 PM". Tessa
  decides from the screenshots; no change in 5.4.7.
- **Report:** space saved (pt) and the dial's bottom edge vs the fold on the iPhone 17, in `.agent-reports/5.4.7/`.
- **Screenshots:** moon up unlocked · locked on Moon · locked on rise · moon up on a no-rise day ("After midnight")
  · moon down · other date · AX1 · AX5. iPhone 17 and SE 3.
- **Tests:** up → three cells in order with the live bearing; down → two cells, no down line; other date → two
  cells; card height equal up vs down; lock on Moon → middle cell outlined; lock on rise / set unchanged; AX
  fallback → pill row; connector hidden from VoiceOver; VoiceOver order.

### 9.15 As built (5.4.7) — report `.agent-reports/5.4.7/5.4.7-upnow.md`
- Card **46 pt shorter** up and down (the pill plus its 10 pt spacing); iPhone 17 face bottom 814 → 768 (106 above
  the fold), SE 3 dial centre 628.5 → 582.5. Up = down height at every size (a hidden twin of the other state).
- Rise and set hug the card's ends in both states; Up now centred between; lock outlines hug their cell.
- Fit: connector (12 pt line + 4 pt clear each end) → no connector → 90% → 80% → wrap at 80% (default size) or the
  pill fallback (other sizes). iPhone 17: connector, 100%. SE 3: no connector, 100%. No-rise day: wraps at 80% on both.
  AX1 / AX5: pill fallback on both, VoiceOver order kept.
- "Up now" Young Serif 20 pt on the times' baseline; glyph 16 pt (scales with `.footnote`); dots 2 / 5 pt.
- AX5 "57° E…" fixed (direction and next-time lines take their own height).

### 9.16 Device check after 5.4.7 (Tessa, 2026-10-03) — build as 5.4.8
1. **"After midnight" / "Not today" smaller.** Its own smaller size in the time slot instead of `Fonts.display` 24
   (supersedes §9.12's "time font" for these two strings only). Young Serif, `textPrimary`, the **largest size that fits
   one line** in its column on the SE 3 at the default size, between **15 and 20 pt**; report the size. It no longer
   pulls the other columns down to 80% (drop the shared scale for this case): the other cells stay at 100%, the card
   keeps its normal height, and "Sun 12:20 AM" stays in the direction slot. AX sizes: wraps as now, never an ellipsis.
2. **Parked (Tessa, 2026-10-03), not in 5.4.8; tracked in DESIGN-REVIEW.md "Date control".** ‹ › bug is back: the
   tapped arrow floats out of the card. Tessa's device video (2026-10-03; frames
   `design/bugs/arrows-float-frames.png`, 1/8 s apart): tap ›, the date changes, and the › button jumps ~40 pt **up,
   above the card's top edge**, then slides back into the row over ~0.3–0.5 s; the other arrow stays put. Same with ‹ going back
   (Oct 19). It happens on some taps, not all (seen Sun Oct 25 → Mon Oct 26). The rest of the card doesn't move.
   - Looks like the button is animating from a stale or alternate position when the header re-lays out for the new
     date (e.g. the phase line changing length: "Full Moon · 100% lit" → "Waning Gibbous · 98% lit"). Suspects: a
     `ViewThatFits` / AX branch in the header row (the AX layout puts ‹ › on a different row) giving the button a new
     identity, an implicit `.animation` on the header picking up the position change, or `PressFeedback`'s spring.
     Find the real cause; don't just switch animation off for the card.
   - **Rule:** stepping days must never move the ‹ › buttons, the card's height, the readout or the dial.
     (Earlier related fix: DECISIONS.md "The date field fills the space between ‹ and ›".)
   - **Test:** step ‹ › through 30 days either side of today (Irvine, include Oct 3, the no-rise day, and Oct 25 → 26)
     on the iPhone 17 and SE 3 at the default size; ‹ › frames, card height and readout y identical every day, with
     animations on. Add it as a UI/layout test so it can't come back. Report the cause.
   - Also confirm the no-rise day's card no longer grows (~20 pt in 5.4.7); item 1 should fix that.
   - **Update 2026-10-09:** still floats after the 5.10 fix, and only on certain dates; see §9.19.

### 9.17 As built (5.4.8) — report `.agent-reports/5.4.8/5.4.8-after-midnight.md`
- **"After midnight" / "Not today": 13 pt Young Serif** (`Theme.Fonts.missingEvent`, scales with `.title2`), **below
  item 1's 15–20 pt**. On the SE 3 with the moon up, the Moonrise column has 100.5 pt of text width beside Up now and
  Moonset, and "After midnight" needs 113.4 pt at 15 pt. The largest size that fits is 13.3 pt (16.8 pt on the
  iPhone 17). One line, the other columns at 100% and the same card height won over the range; Tessa to confirm.
- Out of the columns' shared scale. It sits in a time's slot and on its baseline, so "Sun 12:20 AM" stays on the
  directions' line. The same size in the two-column states.
- No-rise card = normal card at the default size: iPhone 17 181.3 pt, SE 3 181.5 pt on both days (it grew ~20 pt
  in 5.4.7). AX sizes wrap as before, never an ellipsis.

### 9.18 As built (5.6) — report `.agent-reports/5.6/5.6-pinned-bar.md`
- **Rule:** `CompassViewModel.showsPinnedBar` = compass shown (Here / Nearby) and the dial's centre below the fold.
  The fold is the scroll view's bottom edge, which is the home indicator's top, or the bottom bar's top when a note
  shows. `LocationScreen` measures both in global coordinates. The sensors also run while the bar shows (COMPASS.md
  §1).
- **Bar:** 64 pt capsule, 16 pt side margins, 8 pt above the home indicator or the note (an overlay, so it doesn't
  move the fold). Ultra-thin material under `#342830` at 82%, 1 pt white 12% border, shadow. Live readout left (as
  the readout above the dial, dimmed in low accuracy); **Compass ↓** right, an amber capsule that scrolls the compass
  block to the top (readout first, dial under it). Locked: amber fill, the lock text in `onAccent`, the button dark.
  Text capped at AX1, like the bottom bar.
- **Fit, default size (5.4.8 card):** the bar **never shows** on either phone. iPhone 17 centre 638 vs fold 840
  (no note) / 759 (Precise). SE 3 centre 582.5 vs fold 667 / **585.5** (Precise, low accuracy: 3 pt clear) / 603.5
  (Nearby). It shows at xxxLarge on the SE 3 always, and on the iPhone 17 with a note; at AX1 and up on both.
- **AX:** "readout + Compass ↓" doesn't fit at AX1 for most readouts, so the button drops to **"↓"** (same label for
  VoiceOver) and the readout may shrink to 0.5×; never an ellipsis. What breaks is 5.5's (see the report).

### 9.19 Day arrows still float after 5.10 (Tessa, 2026-10-09) — build as 5.10b
Source: device video `arrow_bug_2.mov` (T2 iPhone, build 5.10 `cb98c6e`), analysed frame by frame at 60 fps by Cowork.
Frames and the per-event table: `design/bugs/arrows-float-2-frames.jpg`, `design/bugs/arrows-float-2.md`.
- **5.10's fix did not remove it.** Scoping `PressFeedback`'s spring to scale / opacity (§9.16 item 2) stays, but it
  was not the whole cause. The 61-day layout test passes because it renders **settled** cards; the bug is a ~0.4 s
  transient after the tap.
- **What happens:** in the first frame of the date change the tapped button is ~40 pt above its place (above the
  card's top edge), then eases back over 0.37–0.40 s. The other button, the card height, the readout and the dial
  don't move. Either arrow, either direction.
- **It depends on the date you land on, not on the tap.** 13 floats in the video, and all 13 landed on **Mon Oct 19**
  (4×), **Mon Oct 26** (4×), **Wed Oct 28** (2×) or **Wed Nov 11** (3×). Every arrival on those four dates floated;
  the other ~60 date changes (Oct 7 – Nov 14, Irvine, today = Thu Oct 8) never did. The 2026-10-03 video shows the
  same dates (› Oct 25 → 26, ‹ to Oct 19). So the §9.16 "same for every tap" theory (the pressed state releasing in
  the same update) can't be the whole story: something in those days' data changes what the header / arrows lay out,
  or the identity of the button.
- **Not label width** (float and non-float dates overlap). What the four dates share is **not known** from the
  video. Their card data (rise / set / phase) is in `arrows-float-2.md`.
- **5.10b, in this order (don't fix first):**
  1. **Reproduce:** step onto Oct 19, Oct 26, Oct 28 and Nov 11 and their neighbors (animations on, iPhone 17 and
     SE 3, default size).
  2. **Diff:** dump the day model the card and header read for each float date vs its neighbors; report what differs.
  3. **Trace:** what in the header / arrows depends on that data (view identity: `.id`, conditional branches,
     `ViewThatFits`; implicit `.animation`; transitions; `PressFeedback`).
  4. **Fix the cause** (not by switching animation off for the card) and report it.
  5. **Test:** the existing settled-layout test can't see this. Add one that **samples the ‹ › frames during the
     0.5 s after the tap** (UI test, ~16 ms samples, or rendered frames across the transition) for **both arrows
     onto all four dates**, plus a spread of other dates. Frames must equal their resting frames in every sample.
- **Also (Tessa, parked, after the fix):** the ‹ › need a slight tap response. Do it with `PressFeedback` once the
  float is fixed, so the two don't mask each other (DESIGN-REVIEW.md "Date control").

### 9.20 As built (5.10b) — report `.agent-reports/5.10b/findings.md`
- **Cause:** the madlib's date-dependent shared font scale fed fractional font metrics into `SentenceLine`. Its
  promised fixed full-size line slot used `minHeight`, so some scales grew the sentence's layout height during the
  tap transaction and moved the entire card below it. There was no arrow identity or date-model branch.
- **Fix:** the line slot now has an exact full-size height. Card animation stays on; 5.10's scoped press animation
  stays.
- **Regression:** both arrow frames are sampled every ~16 ms for ~0.5 s after animated steps onto all four reported
  dates from both directions, plus three spread dates. Post-fix device coordinates are invariant. 973 cases pass.

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
- **2026-10-02 night (Tessa, device after 5.4.6a):** phase line one line (0.85x); tighter label → time; lock pill
  20 pt with small direction letters (readout too); shorter needle; bigger dial; missing rise/set top-aligned, "After
  midnight" + next time. §9.10.
- **2026-10-03 (Tessa, after 5.4.6b):** readout/pill at the card time size with 0.7x capital directions; missing
  rise/set labels aligned, "After midnight" in the time font; needle ~28 pt; phase line always one line. §9.12.
- **2026-10-03 (Tessa, sketch → mocks 7a–7c in `design/1.3-upnow/`):** 5.4.7: Up now moves into the rise / set row
  as a middle column (rise · Up now · set) to win back vertical space; removed when the moon isn't up. Phase glyph on
  a connector line (solid rise → now, dotted now → set); not up = one dotted line at 40%; card height equal in both
  states; down line dropped; keep "today". Nothing else on the screen changes. §9.14.
- **2026-10-03 (Tessa, device after 5.4.7):** "After midnight" in a smaller font (no shared 80% scale, no wrap); the
  tapped ‹ › floats above the card when stepping days (video), written up in §9.16 item 2 but **parked** for later.
  §9.16 item 1 builds as 5.4.8.
- **2026-10-09 (Tessa, device video of build 5.10):** the day arrows still float, on some dates only (Oct 19, Oct 26,
  Oct 28, Nov 11). 5.10b reproduces first, then fixes the cause and adds a frame-sampling test. Slight tap response on
  ‹ › parked until after. §9.19.
