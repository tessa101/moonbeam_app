# Build 5.10c — day-arrow press and haptic

Updated October 9, 2026.

## Values used

| Property | Value |
|---|---|
| Pressed circle scale | **0.88** |
| Pressed fill | **`surfaceRaised` + 10% white** |
| Minimum visible pressed state | **90 ms** |
| Release animation | **0.15 s spring** |
| Step haptic | **soft impact, intensity 0.5** |
| Hit frame | **44 × 44 pt**, unchanged |

The scale and lighter fill apply only to `DayStepButtonStyle`. Reduce Motion keeps the fill response but removes the scale. The shared `PressFeedback` values and every other button are unchanged.

The haptic trigger increments only when an enabled arrow performs its step. Disabled arrows do not run the action or trigger feedback; calendar and Today selection do not use this path.

## Minimum hold and layout regression

A quick release does not clear the pressed look until 90 ms has elapsed from press-down. A longer hold releases immediately on touch-up. The extended `DayStepAnimationTests` now drives press-down, a quick release, and the date step for both arrows onto Oct 19, Oct 26, Oct 28, and Nov 11 from both directions, plus three spread dates. It samples both 44 pt arrow frames every 16 ms for ~0.5 seconds after release and measures the visible pressed-state interval at ≥ 90 ms.

The companion test asserts the exact visual/haptic values, one haptic trigger for one enabled step, none for a disabled step, and none for direct calendar selection.

## Simulator verification

- A 0.3 s held press on › advanced exactly one day.
- A quick tap on › advanced exactly one day.
- Resting and released frames were identical: previous `{{288, 211.3}, {44, 44}}`; next `{{332, 211.3}, {44, 44}}`.
- The card remained `{{0, 62}, {402, 592.7}}`; rise/set content remained at `y = 284.2`.
- No stable-state overlap, clipping, alignment, or color issue was found.

The interaction capture API records after touch-up, so it cannot preserve the live 0.88/lighter-fill frame. Haptic feel cannot be assessed in the simulator; the implementation and trigger count are covered by the test, and the Debug build is installed on T2 for the physical check.

Screenshots: `resting.png`, `held-press-released.png`, `quick-tap-released.png`.

## Verification

- Focused §9.20 tests: **2 / 2 passed**.
- Full Xcode suite: **974 / 974 passed**.
- Debug build: passed.
