# Build 5.10 findings

_2026-10-08 · COMPASS-1.1.md §9.16 item 2; STATUS.md Roadmap item 2_

## Day arrows float

**Cause:** `PressFeedback` used `.animation(_:value:)` on each button's content. A tap releases the pressed state in the same SwiftUI update that changes the selected date. That value-based animation therefore applied its spring transaction not only to scale and opacity, but also to the tapped button's transient header relayout. The released chevron animated from the stale position; its untapped sibling had no `isPressed` change and stayed put.

**Fix:** use SwiftUI's scoped `.animation(_:body:)` overload around only `scaleEffect` and `opacity`. The pressed look still springs, while date/header geometry is outside that animation.

**Regression test:** `MoonCardHeightTests.dayStepsKeepLayoutFixed(width:)` renders the real astronomy/card state for 61 sequential dates (30 before and after October 3, 2026) at the iPhone 17 and iPhone SE 3 card widths. Both cases pass. The range includes October 3's missing-rise state and October 25 → 26. Card height remains fixed; the arrow hit areas are fixed 44 pt frames in `DayStepButtonStyle`, so the arrow row and downstream readout/dial y positions do not change.

**Verification:** build-for-testing succeeded; the focused test passed 2/2 cases. Reference renders:

- `day-arrows-today.png`
- `day-arrows-no-rise.png`

## Landing haptic

Pending the second 5.10 item/commit.
