# Build 5.10b — day-arrow transient

Updated October 9, 2026.

## Reproduction before the fix

Reproduced the §9.19 dates first on an iPhone 17 simulator with animations enabled and the unmodified 5.10 build. Oct 19, Oct 26, Oct 28, and Nov 11 all settled with both arrow frames at `y = 211.3`; ordinary neighboring dates settled at `y = 212.0`. The date/phase labels, rise/set rows, and debug readout moved by the same 0.7–0.8 pt, while the visible madlib lines stayed anchored. This confirmed that the arrow was not changing identity or moving independently: the whole card below the sentence was receiving a different upstream height.

The supplied 60 fps device frames remain the evidence for the much larger transient: the interaction tooling can inspect only settled accessibility frames, not freeze the first ~0.4 seconds after a tap.

Screenshots: `before-oct-18.png`, `before-oct-19.png`. The original frame sequence and event table are in `design/bugs/arrows-float-2-frames.jpg` and `design/bugs/arrows-float-2.md`.

## Model diff and dependency trace

The day-model dump found no value common only to the four affected dates. The arrow/header path has no date-dependent `.id`, transition, implicit animation, or conditional button branch. `MoonCard`'s phase label uses `ViewThatFits`, but the identical displacement of every lower row ruled it out.

The dependency was upstream: `MadlibSentence` derives one shared scale from the natural widths of its date-dependent lines. `SentenceLine` documented a fixed full-size slot but implemented only `.frame(minHeight:)`. At some fractional scales, the font's intrinsic line box exceeded that minimum. The resulting date-dependent fractional height changed the card's coordinate during the press-release/date-change transaction, producing the stale-coordinate arrow excursion seen in the video.

## Fix

`SentenceLine` now uses an exact full-size line-slot height. The sentence can still choose its shared scale, but its font metrics can no longer change the space allocated above the card. The card animation remains enabled; the 5.10 `PressFeedback` scoping remains intact.

Post-fix device inspection found both arrows invariant on Oct 18 → 19, Oct 26, Oct 28, and Nov 10 → 11:

| Element | Frame / position on every checked date |
|---|---|
| Previous arrow | `{{288.0, 211.3}, {44.0, 44.0}}` |
| Next arrow | `{{332.0, 211.3}, {44.0, 44.0}}` |
| Date label | `y = 212.2` |
| Phase label | `y = 232.2` |
| Rise/set content | `y = 284.2` |

Screenshots: `after-oct-18.png`, `after-oct-19.png`, `after-nov-10.png`, `after-nov-11.png`. No overlap, cropping, or alignment regression was visible.

## Regression test and verification

`DayStepAnimationTests` hosts the real sentence and card, observes the production arrow frames, and samples both arrows every 16 ms for 32 frames (~0.512 seconds) after an animated day step. It enters each target from both directions and covers Oct 19, Oct 26, Oct 28, Nov 11, plus Oct 14, Oct 23, and Nov 5. Every sample must equal the resting frame.

- Focused animation test: passed.
- Full Xcode suite: **973 / 973 passed**.
- Build for testing: passed.
