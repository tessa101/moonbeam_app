# 5.5b — card edge cases and SE connector (2026-10-16)

## Changes

- AX guidance takes its actual height. Other dates no longer reserve an empty two-line guidance block. Standard-size height reservation and date-stepping stability remain intact.
- AX time-zone labels follow the complete time (digits, day period, zone), instead of appearing beside the digits above AM/PM. Standard-size fitting is unchanged.

## Matrix reviewed

108 full-height ImageRenderer cards: nine scripted scenarios × 335/362 pt card widths × default and AX1–AX5. Scenarios: long 11:59 PM/12:58 PM times, prior-night rise, missing rise with next-day event, missing set with next-day event, neither event in range, 11h 59m countdown, after-midnight return, other date, and a place/device time-zone difference. Fixture assertions verify the intended missing/status/zone branches. No clipped content observed in the reviewed cards. Wider strings stack earlier, including AX2 on SE for missing events where the iPhone 17 pair still fits. Shorter Rose/Sets content stays paired through AX3, and through AX4 at 362 pt; AX5 stacks it. These are static card renders, not whole-screen device screenshots or VoiceOver checks.

Nine lock cases cover rise/set/moon at default, AX3 and AX5 on the SE card width. Tests drive the real heading stream, verify the correct highlighted cell, compare identical before/after image dimensions, and verify a visual change. Selected lock renders reviewed: all outlines enclose their intended cell/section without moving content.

14 representative final images plus the earlier time-zone comparison matrix are in `review/`. Tests regenerate the complete matrix in the test host's temporary `moonbeam-5.5b` directory.

## SE connector

The compact three-column SE row deliberately omits the connector when a gap cannot fit its specified 12 pt line plus 4 pt inset at each end. The fit ladder removes that decoration before reducing text size. The other-date two-column SE row has room and shows its dotted connector. AX separates status from the event pair and does not need that connector. Kept the existing fit rule; no forced line, smaller AX text, or design-number change.

## Validation

- Final full suite: **883 tests / 1441 cases, 73 suites, zero failures**, 36.854 seconds. `/private/tmp/moonbeam-55b-complete.xcresult`. The 117 new cases are 108 render/fixture checks plus 9 lock checks.
- Existing standard-size card-height and full-screen scrolling/prompt-transition regressions pass. Tessa independently confirmed scrolling on device before this step.
- The expanded rendering load reproduced CompassEntranceFrameTests' wall-clock/frame-count assumption. A delivery wait alone exposed the same failure one frame earlier; the test now controls its logical entrance clock and waits for injected heading delivery. All pixel/readout assertions remain; no app compass code or durations changed. Test-only commit: `cca3cb0`. Two full runs after this repair passed (1405 cases before adding AX2/AX4; 1441 final).
- No phone install, push or upload. Actual on-phone/VoiceOver edge-case review remains part of 5.5d.

Next: **5.5c**, compass pinned-bar/readout overlap, dial sizing and Large Content Viewer.
