# 5.5a — moon card accessibility reflow (2026-10-16)

Implemented the first card pass from DESIGN-1.1.md §4 and the October 12 decision.

- At AX sizes the 64 pt phase glyph sits above date/phase text, with day controls in a separate row of equal-width, 60 pt rounded buttons. Existing 100 ms hold, Reduce Motion behavior, disabled state and haptics remain. Standard sizes retain their 32 pt visual/44 pt targets.
- AX times place the day-period run on its own line, retaining locale order. The existing ideal-width rise/set pair now fits ordinary content through AX3 at both phone widths without shrinking. AX5 stacks the complete events.
- Full-width status and guidance remain below. AX status uses its actual text height; the historical hidden longest-status placeholder no longer adds blank space. Standard-size up/down height stability remains tested. The former AX1 height-equality case was removed deliberately: the agreed AX layout grows with the actual content rather than reserving a fixed height.

## Verification

- Final build and full iPhone 17 iOS 27 suite: **879 tests / 1316 cases, 71 suites, zero failures**, 37.770 seconds. Result: `/private/tmp/moonbeam-55a-final.xcresult`.
- Ten new hosted layout cases verify equal-width 60 pt controls at AX1/2/3/5, no overlap or horizontal escape, and unchanged 44 pt controls at standard size, at card widths 335 and 362 pt.
- Reviewed all ten full-height ImageRenderer captures in `card-review/`: standard, AX1/2/3/5 at SE and iPhone 17 card widths. Fixture: detected Irvine, October 2 at 07:53, live engine; prior-night rise, Up now, altitude and guidance. No clipped content in these captures. These are card renders, not screenshots of two running devices, and do not verify scrolling or VoiceOver.
- First full run had a timing-sensitive CompassEntranceFrameTests failure (185° versus 190° at sample 13); it did not repeat in the next full run or the final full run. No compass code/test was changed.

## Next

5.5b: complete the longer-time, missing-rise/set, down-state countdown/return, other-date and lock-highlight matrix; review the SE connector. 5.5c: pinned bar/readout overlap, dial and Large Content Viewer. 5.5d: whole-screen scrolled layouts, VoiceOver, Reduce Motion and physical-device checks. No device installation or push in this step.
