# Build 5.10a.4 — slower, ordered place-change landing (LOADER.md §12.3, DECISIONS.md 2026-10-09)

Updated October 9, 2026. The code was already in the working tree, uncommitted and never compiled; this run built and tested it. Behaviour unchanged.

## What's in it (as written in the working tree)
- **City line:** 0.8 s fade (`placeRevealFade` = `replayDuration + 0.1`) with an 8 pt rise; fade only with Reduce Motion.
- **Card:** lands at +0.25 s, 0.7 s ease-out with the rise (`ContentLoadIn.cardLandingAnimation`). The skeleton leaves on the card's clock.
- **Compass:** loads in at +0.6 s, 0.7 s.
- **Reduce Motion:** card swap instant, as before.
- **Launch load-in:** unchanged.

## The stall
- The last log line was "build-for-testing done" (12:48). That build had succeeded. The run stopped when the next call, the Xcode test run, was rejected, before any test started.
- At resume there were no `xcodebuild` / `xctest` / app processes on the Mac or in the booted iPhone 17 simulator, so nothing to kill.

## Tests
- `PlaceSkeletonTests` (suite limit 1 min) and `PlaceChangeLayoutTests` (suite + test limit 1 min): unchanged, all pass. `replayPolicy()` already used the new `replay*` constants from the working tree.
- `ContentLoadInTests`:
  - added `.timeLimit(.minutes(1))`;
  - its launch-timing tests don't depend on the replay timings and were left alone;
  - added `placeChangeLanding()`, which pins `replayDuration` 0.7, card 0.25, compass 0.6, the order, and replay slower than launch.
- The three suites: 18/18 pass, no hang. Full suite **990/990 pass**.

## Flags (not changed)
1. **The 0.8 s reveal may still play at 0.15 s.** As in 5.10a.3: the inner `.animation(placeTokenFade, value: placeText)` probably decides the city line's opacity and offset when it lands. Not checked on screen; watch it on the device.
2. **Stale comment and a magic number:** `placeRevealFade`'s comment still says "fades in", from the 0.5 s version, and its duration is `replayDuration + 0.1`, an unnamed 0.1 (CLAUDE.md: no magic numbers).
3. **DECISIONS.md:** the new entry is again at the bottom of the file under `##`, not at the top under `###`.
4. **Still open from 5.10a.3:** after a failed My location, the hidden city line leaves no way into search.

## Not done
- No simulator or device recording of the new landing this run.
