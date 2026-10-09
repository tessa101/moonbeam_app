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

**Finding: no clear bug; no code change.** COMPASS.md §4.5 belongs to compass lock acquisition and calls for one firm tap (`.impact(weight: .heavy)`). The landing feedback is a separate cue specified by LOADER.md §11.2.7: soft, intensity 0.6, deliberately distinguishable from the compass lock.

The implementation matches that split:

- `LocationScreen` observes `LocationLoader.landingCount` with `.sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger:)`.
- `landingCount` advances only from `didLand()`, once after `flyAway()` has recorded a real flight.
- A repeated landing callback is ignored, and a normal/fast launch without the recovery → Aha → flight path remains silent by design.
- Reduce Motion waits for the 0.2-second cross-fade, then uses the same trigger.

The focused existing test `Loader flow/landingHaptic()` covers one tap per flight, no tap without a flight, and no duplicate tap. The earlier full-flow tests also assert that fast launch and skipped loader paths leave `landingCount` at zero. The complete suite passes: **972/972**. A screenshot cannot prove a haptic; final physical-device installation is recorded below after both commits.
