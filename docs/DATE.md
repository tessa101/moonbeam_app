# Step 3: Date selection

**Status:** Draft, ready for review · **Decided:** 2026-09-26 · **Owner:** Tessa
**Fills:** PRODUCT.md UC5 / "Date picker" (V1.1), ARCHITECTURE.md §5 "TBD: date selection state"
**Unblocks:** ASTRONOMY.md §5 USNO rows checked in the UI; the Mar Vista 2026-10-03 no-moonrise day (DESIGN-REVIEW.md, Moon table)

---

## Problem

**Today:** The app only shows the moon for today. You can't plan ahead, check last night, or look at edge-case days in the UI.
**Change:** Add a date control under the city with previous/next buttons, a month calendar for jumping further, and a one-tap way back to today.

## 1. Date control (main screen)

Placed directly under the city name, above the moon table (sketch #3).

```
 ‹   [📅  Today · Sat, Sep 26, 2026  ⌄]   ›      (Today)
```

- **Field (center):** calendar icon + date label + chevron. Tapping it opens the calendar sheet (§2).
- **Previous ‹ / Next › buttons** on either side of the field: move one day back or forward. The moon data updates right away. No animation in this step (swipe/card transitions are V2, §7).
- **Today chip:** shown only when the selected day **isn't** today in the place's time zone. Tapping it goes back to today. Hidden when already on today.
- **Label format:**
  - Relative word + date when it applies: `Today · Sat, Sep 26, 2026`, `Tomorrow · Sun, Sep 27, 2026`, `Yesterday · Fri, Sep 25, 2026`
  - Otherwise just the date: `Sat, Oct 3, 2026`
  - Use the device locale's date format (`Date.FormatStyle`); the relative words follow the place's "today" (§3), not the device's.
- **Range:** today ±366 days. The ‹ or › button is disabled at the limit.

## 2. Calendar sheet

- Bottom sheet, **medium detent** (large if Dynamic Type needs it), drag indicator visible.
- Contents: a month calendar (`DatePicker` with `.graphical` style, date-only), limited to the §1 range. Today is marked by the system style.
- **Tapping a date sets it and closes the sheet.** Tapping the date that's already selected also closes it.
- Header: title **Choose a date**, trailing **Cancel** (closes without changing anything). Also a **Today** button in the header so "back to today" works from the sheet too.
- The graphical picker can't show a moon glyph on each day. That comes with the custom calendar in V2 (§7); don't build a custom grid now.

## 3. Rules

- **A date belongs to the place.** The selected day is a calendar day (year, month, day) in the **selected place's time zone**, not a moment in time. "Today" means today in that city. Example: at 8 PM Sep 26 in LA, Sydney's today is Sep 27.
- **Two modes:**
  - **Following today** (default): the selection tracks the place's today. Changing city recalculates it (switching to Sydney can move the label from Sep 26 to Sep 27). If the app is open or comes back to the foreground after the place's midnight, it moves to the new day.
  - **Picked date**: set by ‹, ›, or the calendar. Stays on that calendar day when the city changes (Oct 3 in LA → Oct 3 in Sydney).
  - Landing on the place's today with ‹/› or the calendar goes back to "following today". The Today chip does the same.
- **Past dates are allowed** (within the range).
- **Not saved:** every launch opens on today. The picked date lives only for the session.
- **Illumination/phase** keep FR5: sampled at the end of the **selected** day in the place's time zone (ASTRONOMY.md §3). Nothing changes in the engine.

## 4. Architecture changes

- New `Models/DaySelection.swift` (nonisolated value type):
  ```swift
  enum DaySelection: Equatable, Sendable {
      case today                      // follows the place's current day
      case day(year: Int, month: Int, day: Int)
  }
  ```
  With helpers that take a place's `TimeZone` and a `now`:
  `resolvedDay(in:now:) -> DateComponents`, `startOfDay(in:now:) -> Date`, `offset(by days: Int, in:now:) -> DaySelection` (becomes `.today` when it lands on today), and range clamping. Uses a Gregorian `Calendar` with the place's time zone, and `date(byAdding: .day, …)`, never +86 400 s.
- `LocationViewModel`:
  - `private(set) var daySelection: DaySelection = .today`
  - `func previousDay()`, `func nextDay()`, `func goToToday()`, `func select(day: DateComponents)`
  - `var isCalendarPresented = false`
  - Computed: `dateLabel`, `dateAccessibilityLabel`, `showsTodayChip`, `canGoBack`, `canGoForward`
  - Passes `daySelection.startOfDay(in: place.timeZone, now:)` to `MoonService.moonDay(for:on:)` wherever it passes today now.
  - Recompute on place change and in `sceneDidBecomeActive()` (the midnight rollover in §3).
- **Inject a clock** (`now: () -> Date`, default `Date.init`) into the view model so tests can pin "now".
- New `Features/Location/DateControl.swift` (row) and `Features/Location/CalendarSheet.swift`. Plain visuals, same as the rest of Step 2.
- Update ARCHITECTURE.md §5 (replace the TBD) and PRODUCT.md §6 ("Date picker" → built) when this lands.

## 5. Accessibility (build now, polish in the design pass)

- ‹ / › buttons: labels **"Previous day"** / **"Next day"**; at least 44×44 pt hit targets; disabled state announced.
- Date field: button, label e.g. **"Date: Today, Saturday, September 26, 2026"**, hint **"Opens calendar"**.
- Also give the field `.accessibilityAdjustableAction` so VoiceOver swipe up/down moves one day. That's the VoiceOver version of ‹/› (and of swiping later).
- Today chip: label **"Go to today"**.
- Changing the day announces the new date (the moon table updates with it).

## 6. Tests (Swift Testing, fixed clock + fakes as before)

**DaySelection**
- `.today` resolves to the place's day: LA 2026-09-26 20:00 PDT → LA Sep 26, Sydney Sep 27
- `offset(+1)` from today → `.day(Sep 27)`; `offset(-1)` from `.day(Sep 27)` back to today → `.today`
- Across DST: LA 2026-11-01 (fall back) and a Sydney DST change: next/previous land on the right calendar day and start of day
- Month and year boundaries (Dec 31 → Jan 1)
- Clamps at ±366 days

**LocationViewModel**
- Starts on `.today`; no Today chip
- Next day → label "Tomorrow · …", chip shown, `MoonService` called with Sep 27 in the place's time zone
- Today chip → `.today`, chip hidden
- Calendar pick sets the day and closes the sheet; Cancel changes nothing; picking today → `.today`
- City change while following today → follows the new city's today; while on a picked date → same calendar day in the new city
- `sceneDidBecomeActive` after the place's midnight: following today → advances; picked date → unchanged
- ‹ disabled at −366, › disabled at +366
- Relaunch (new view model) → `.today`

**Values**
- Mar Vista 2026-10-03 → no moonrise ("No moonrise today" state, FR2)
- ASTRONOMY.md §5 rows selectable by date (Sydney and Mar Vista 2026-09-23) and match through the view model

## 7. Acceptance criteria

- [ ] Date control shows under the city with ‹ and ›; the default label is "Today · {date}"
- [ ] ‹ / › change the day by one and the moon data updates
- [ ] Tapping the field opens a month calendar; tapping a date sets it and closes the sheet
- [ ] Today chip appears only off today, and one tap returns to today
- [ ] "Today" is the place's today, not the device's
- [ ] Past dates work; range is ±366 days with the buttons disabled at the ends
- [ ] Relaunch opens on today
- [ ] VoiceOver: labeled buttons, adjustable date field
- [ ] Mar Vista Oct 3 shows the no-moonrise state in the UI
- [ ] All tests pass under Swift 6 strict concurrency

## 8. V2 (parking lot)

- Swipe between days (cards or paging) with a more satisfying transition. Reuses `offset(by:)`.
- Custom month calendar with a phase glyph per day (merges with PRODUCT.md "Month calendar of phases").
- Week strip view with key data per day, weather-app style.

## 9. For DESIGN-REVIEW.md

- Copy that assumes "tonight" when another date is picked: screen prompt "Where are you watching the moon tonight?" and the midnight note → e.g. "Oct 3 · at midnight"
- Today chip placement: beside the field vs. under it; whether the chip or the field's "Today ·" prefix is enough on its own
- Arrow styling and hit areas; the field's chevron
- Should the date show the time zone when the place's day differs from the device's?

## Open questions

- Range ±366 days OK, or wider? (Accuracy is only validated against USNO near the reference dates.)
- Keep the picked date on relaunch? Draft says no.
