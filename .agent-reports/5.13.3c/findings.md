# Build 5.13.3c: calendar toolbar buttons back on the system style: 2026-10-15

Regression from 5.13.3 part 2 (`7b03608`): the calendar sheet's Today, Cancel and Done went onto `.inline`. On the T2
Today showed as "Tod…" on a dark pill. Fixed in `5b80b71` (checkpoint, at Tessa's request) plus the final commit.

## Reproduced (before, `before/`)

iOS 27 simulators only (the T2 is iOS 26.6.2; no iOS 26 runtime here). iPhone 17 and SE 3, default / AX1 / AX3,
today / other / done: **17 of 18** shots. Missing: `se3-ax3-today` (see "Other bugs").

- Today is "Tod…" (default) or "To…" (AX1, AX3) on its own small dark capsule, about 42-44 pt wide, in every shot.
  Cancel gets 50-61 pt.
- With Done at AX sizes, Cancel is truncated too ("Can…").
- Disabled Today is a faint gold (the style's 0.35 opacity), clearly dimmer than Cancel.

## Cause (confirmed with throwaway previews, `probe-1/2/3`; the probe file was deleted and never committed)

The suspected cause was only partly right:

1. **The squeeze comes from any custom `ButtonStyle` on a toolbar item, not from the 44 pt frame.** A bare style
   that just returns the label still gives "To…" on a small capsule. Without the 44 pt frame Today gets even
   narrower; with it the text wraps to "To-day" instead (`probe-1`, `probe-2`). With a custom style the bar treats
   the item as a custom view with its own small capsule.
2. **The dimming doesn't stack.** Under a custom style the system dims nothing: a bare style shows disabled Today
   at full strength (`probe-2`). The 0.35 was the only dimming. STEP-5.13 §4's "double-dimmed" isn't quite right;
   flagged here and not edited, since the file is Tessa's (untracked).

## Fix

- `CalendarSheet`: Today, Cancel and Done have no `.buttonStyle`, so they use the system style and keep the bar's
  glass. The comment points to STEP-5.13 §4 (corrected).
- `ButtonStyleDriftTests`: toolbar buttons are a rule, not a file allowlist. Inside `.toolbar`, `ToolbarItem` or
  `ToolbarItemGroup` a Button must have **no** custom style, so this regression now fails the test. Mutation check:
  `.inline` put back on Today fails with `CalendarSheet.swift line 46: toolbar Button on .inline`. The fixture covers
  a system toolbar button (passes) and `.held` in a `ToolbarItemGroup` (caught).
- Search sheet Clear and Cancel stay on `.inline`: they sit in a custom `HStack` beside the field, not in a toolbar.

## After (`after/`)

**17 of 18** calendar shots (the same `se3-ax3-today` gap) plus 4 search-sheet shots (iPhone 17, default and AX3).

- "Today" is in full at every size on both devices, in a normal-width capsule. Cancel fits beside Done at AX1/AX3.
- Once Done shows, the system shortens the title, since the buttons now get their full width: iPhone 17 AX1/AX3
  "Choose…", SE default "Choose a…", SE AX1/AX3 no title. That's the toolbar's own priority (buttons over title).
- Search sheet: Cancel (51.7 pt wide at default, 112 at AX3) and Clear (44 × 44) fit beside the field, nothing
  truncated. The list only had the Use my location row (no recents or suggestions on that simulator), so city rows
  weren't checked on screen.

## Needs Tessa: disabled Today looks enabled (dates back to build 10)

After the fix, disabled Today is cream like Cancel, with no dimming (pixels within 6/255 of enabled). Cause:
`moonbeam_appApp.swift:84` sets `.foregroundStyle(Theme.Colors.textPrimary)` on the app root (since Step 5.1). Sheets
inherit it, and an explicit foreground style overrides both the toolbar's tint (gold) and its disabled gray
(`probe-3`). Putting `.tint` on Today makes it gold but still doesn't dim it. Build 10 already had the root style and
system-styled calendar buttons, so this is how TestFlight 0.1 (10) already looks, not something this fix introduced.
Possible fixes (not done; your call): move the root `foregroundStyle` down onto the main screen's content so sheets
don't inherit it, or give the calendar sheet its own foreground. Either changes the toolbar from cream to the
system's tint and gray.

## Audit: `.inline` / `.row` in system-sized containers

| Use | Container | Verdict |
|---|---|---|
| Calendar Today, Cancel, Done | nav-bar toolbar | **was the bug**; now system |
| Search Clear, Cancel (`.inline`) | custom `HStack` | fine (shots) |
| Search Use my location, recents, suggestions (`.row`) | `List` rows | the List sets row height from the content; Use my location row 370 × 74-81 pt, no clipping. City rows not on screen this run |
| Location Off dialog Close (`.inline`) | custom overlay | fine (preview, 5.13.3 part 2b) |
| Compass guide row (`.row`) | custom card | fine |

No other `.toolbar` / `ToolbarItem` in the app.

## Other bugs seen (not fixed, outside this task)

1. **The headline overlaps itself at large text sizes.** AX3 on both devices; iPhone 17 AX1 on a non-today date.
   On SE AX3 the "today" link sits under "Irvine, CA" and can't be tapped, so the calendar can't be opened from
   today at that size.
2. **The SE's medium calendar sheet is clipped at default size:** the last week (25-31) is off the bottom.
3. The headline's accessibility frames don't match where the tokens draw (taps from the reported hit points opened
   the wrong token).

## Tests

Drift suite 3/3; full suite in Xcode (iPhone 17) **1301/1301** on `5b80b71`.
