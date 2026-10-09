# Step 5.11 Spec: Moon state on the card (+ altitude, edge-case voice)

> Owner: Tessa · _Decided 2026-10-08_ (from build 8 testing, 2026-10-07) · Builds on COMPASS-1.1.md §9.14 (Up now
> middle column, 5.4.7) and §9.10 ("After midnight" + next time).
> **Problem:** the card only explains the moon when it's up. When it's down, the user has to work out from two times
> whether it's coming or already gone, and on days when it has already risen and set it reads as "nothing tonight"
> with no next step.

## 1. States (today only)
The middle column shows on **today** in every state, not just when the moon is up. Other dates keep the two columns
as built (there's no "now" on another day).

| State | When | Middle column title | Under it |
|---|---|---|---|
| **Up now** | moon above the horizon | Up now | `266° W · 23° up` |
| **Not up yet** | down, next rise is later **today** | Not up yet | `in 3h 20m` |
| **Set for today** | down, already set today, next rise is **after midnight** | Set for today | `Back late tonight, 12:20 AM` (Tessa, 2026-10-08) |

- "Up" is the existing rule (latest rise later than latest set, `AstronomyEngineMoonService.moonPosition`), so the
  card, the compass and the lock pill always agree.
- Rise and set columns are unchanged (including "After midnight" + next time, §9.10).
- The middle column replaces `UpNowFormatter.downTitle` "Below the horizon" (kept unshown since 5.4.7): the down state
  is now split into Not up yet / Set for today.

### 1.1 Rise column while the moon is up: the rise of the moon you're seeing (Tessa, 2026-10-08, option A)
**Problem:** in the morning the moon rose last night, but the Moonrise column shows today's calendar rise (tonight's,
e.g. 11:10 PM) left of "Up now", and the line from it reads as "rose at 11:10 PM" (COMPASS-1.1.md §9.14 watch item).
- **Today, moon up:** the rise column shows **this pass's rise**: `Rose 10:06 PM` with `last night` under it (or
  `today` when it rose today, where it simply reads as now: the time with no extra line). Source: `UpNow.Pass.riseTime`
  (already computed, unshown).
- Likewise the set column shows **this pass's set** (`Sets 1:28 PM`), which is usually today's anyway; when it's after
  midnight it keeps "After midnight" + the time (§9.10).
- Moon down, or another date: calendar rise and set, as built.
- Tonight's calendar rise isn't lost: it's the next day's card, and Set for today / Not up yet already name the next
  rise.
- VoiceOver: "Moonrise, last night, 10:06 PM."
- Tests: at 8 AM with the moon up since 10:06 PM the night before, the rise column reads `Rose 10:06 PM` / `last night`;
  after it sets, the column returns to the calendar rise.

## 2. Countdown (Not up yet)
- Format: `in 45 min` under an hour, `in 3h 20m` from an hour, `Rising now` in the last minute.
- Updates once a minute (the existing clock tick); no seconds.
- When it reaches the rise, the column switches to Up now (same in-place change as now, no load-in replay; LOADER.md
  §12.1).

## 3. Altitude (Up now)
- `23° up`, after the bearing: `266° W · 23° up`. Whole degrees from `horizontal.altitude` (already computed in
  `moonPosition`), rounded; minimum shown `1° up` while the moon is "up" by the rise/set rule but the centre is still
  just below 0° (the upper limb is over the horizon).
- Updates with the compass's position updates; no animation on the number.
- Wraps under the bearing at AX sizes (5.5 reflow) rather than truncating.
- VoiceOver: "Moon up now, west, 266 degrees, 23 degrees above the horizon."

## 4. Voice: edge cases only (B now; A, an always-on answer line under the sentence, after the design review)
One quiet line under the card's columns, **only** in the confusing states. Facts first, at most one wry aside. Plain
text for VoiceOver (it reads the line as written).

| Case | Line (proposed, Tessa to edit) |
|---|---|
| Set for today | "It set at 2:23 PM, so tonight's a moonless sky. Good night for stars." |
| No moonrise on this date (any date) | "No moonrise today. It rose late last night and slips past midnight." |
| No moonset on this date (any date) | "No moonset today. It stays up past midnight and sets tomorrow." |
| Full moon (illumination ≥ 99%) | "Full moon. It rises around sunset and stays up all night." |
| New moon (illumination ≤ 1%) | "New moon. It's up, but lost in the sun's glare." |

- One line at most; priority top to bottom if more than one applies.
- Copy lives in one table (`MoonVoice`, proposed) so A can reuse it later.
- No line in ordinary states.

## 5. Open
- ~~"Tomorrow night" wording~~ → **"Back late tonight, 12:20 AM"** (Tessa, 2026-10-08). If the next rise is later
  than ~4 AM, say "Back tomorrow, 4:35 AM" instead (proposed).
- **Full / new moon lines (proposed default):** only on the **calendar day of the exact full or new moon** in the
  place's time zone, not an illumination threshold (≥ 98% lasts two to three days). Voice copy stays draft until a
  device read-through.
- Polar edge cases (moon up or down all day): out of scope; keep current fallbacks.

## 6. Tests
- State selection at fixed times for one place: before rise → Not up yet; between rise and set → Up now; after set
  with next rise after midnight → Set for today; other dates → no middle column.
- Countdown text: 59 min → `in 59 min`; 60 min → `in 1h 0m`; < 1 min → `Rising now`.
- Altitude rounds, never shows `0° up` or negative while up.
- Voice line: only in the listed cases, one at most, priority order.
- Card, compass and lock pill agree on up/down at every rise and set (existing rule).

## 7. Build order (one commit each)
- **5.11.1** Middle column on today in all three states + countdown + this pass's rise/set while up (§1, §1.1, §2).
- **5.11.2** Altitude in Up now (§3).
- **5.11.3** Edge-case voice line (§4).
