# Build 5.14.1: onboarding load-ins, landing and upsell (STEP-5.14 §2): 2026-10-15

## What changed

- `ContentLoadIn` is unchanged in timing (8 pt rise, 300 ms ease-out, 150 ms stagger, Reduce Motion keeps the fade
  and drops the rise). It gains a generic position, `.index(n)`, next to the main screen's `.main(Block)`.
  `contentLoadIn(index:)` loads a block in once on appearance at `n × 150 ms`; it never replays and ignores "Aha".
  The main screen's call sites and timings are untouched (`delay(for:)` now goes through `delay(forIndex:)`).
- Landing: moon (glyph + halo, unchanged), "Moon Signal", tagline, Get started (indices 0-3).
- Upsell: moon, title, body, Precise Location box, Use my location, Search for a city instead (indices 0-5).
- Between screens (`OnboardingScreenChange`, `OnboardingView`): the outgoing page fades out in 0.2 s
  (`ContentLoadIn.skeletonExitAnimation`), then the new page is put in place with animations off and its blocks
  load in. No slide or push. A step change mid-fade cancels the run; the next one carries on from the faded page.
- VoiceOver: `ScreenChanged` is posted 150 ms after the new page is in place, i.e. once the title (block 1 on both
  screens) has started, instead of at the step change (when the old page was still up).
- Not touched: "That's okay for now" (a change to it swaps at once and announces at once, as before), all copy,
  all button actions and styles, the moon glyph and halo. No cat.

## Measured (simulator recordings, frame timestamps, `onsets.py`)

Times are after the darkest frame of the fade-out (≈ the page swap); each onset has ≈ 40 ms detection lag.

| Block | Expected | Normal | Reduce Motion |
|---|---|---|---|
| Fade-out (tap → darkest) | 0.20 s | 0.18 s | 0.19 s |
| Moon | 0.00 | 0.04 | 0.05 |
| Title | 0.15 | 0.19 | 0.19 |
| Body | 0.30 | 0.35 | 0.34 |
| Precise Location box | 0.45 | 0.53 | 0.51 |
| Use my location | 0.60 | 0.66 | 0.65 |
| Search for a city instead | 0.75 | 0.80 | 0.80 |
| Rise at 30% faded in | ≈ 5 pt (8 pt ease-out) | 5.1-5.2 pt | 0.0 pt |

## Files

- `landing-to-upsell.mov`: launch with `-forceOnboarding`, landing, tap Get started, upsell.
- `landing-to-upsell-reduce-motion.mov`: the same with Reduce Motion on (confirmed on in Settings, then off again).
- `upsell-final.png`: the settled upsell.
- `onsets.py`: the measurement (half-res row means per frame at real pts).

## Caveats (read these)

1. **These are simulator recordings (iPhone 17, iOS 27), not device recordings.** The T2 iPhone can't be driven
   or recorded from this session (DeviceInteraction only selects simulators). The Debug build is installed on the
   T2 for Tessa's own recording.
2. Both videos end about 50 ms after the Search link starts (the recorder writes frames only on change and the tail
   after the stop didn't flush), so the last frame shows the link part-faded. `upsell-final.png` is the settled
   screen. Not padded, so nothing in the video is made up.
3. First launch of the landing: on the normal run the load-in plays under the system's app-launch zoom, so it's
   barely visible; on the Reduce Motion run (cross-fade launch) the landing's stagger is visible at ≈ 2.76 s.
4. VoiceOver timing is unit-tested (`OnboardingScreenChangeTests`), not heard: VoiceOver wasn't run here. Phone check
   needed: does focus land on the upsell title after Get started?
5. The working tree also holds the uncommitted 5.13.3 resume edits (Close and guide row on shared styles, ‹ › hold
   100 ms). They are **not** in this commit, but they were in the tree for the test run, the recordings and the T2
   build.
6. The landing's halo is a big blur; with `geometryGroup` + offset it rises with the glyph as one unit (no halo lag
   seen in the frames).

## Tests

`OnboardingScreenChangeTests` (5): indexed stagger matches the main screen's, upsell total 1.05 s, 0.2 s exit,
scope (landing/upsell load in, declined swaps), announce delay. Full suite in Xcode (iPhone 17): **1298/1298**.
