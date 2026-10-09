# Builds 5.10a.6 + 5.10a.7 — place change, together (LOADER.md §12.2–12.3, §12.9; DECISIONS.md 2026-10-09)

Updated October 9, 2026. The code was already in the working tree on top of `c45ecf7`, uncommitted and never compiled. This run built it and updated the tests to the new behaviour. No app code changed.

## What's in it (as written in the working tree)
- **5.10a.6:**
  - City line: opacity cross-fade only (no rise), 0.3 s reveal.
  - Replay timings: 0.4 s, card +0.1 s, compass +0.25 s.
  - The whole card fades and rises in (`riseTransition`). The 5.10a.5 content-only rise and `risesCardContent` are removed.
- **5.10a.7:**
  - When a replacement begins, the replaced card and the city line go in the same frame: `.transaction(value:)` disables animations, so the sheet's dismissal animation can't carry them out slowly.
  - The skeleton shows at once (`showsPlaceSkeleton = true` in `beginReplacingPlace`). `placeSkeletonThreshold` is removed; the 350 ms minimum stays.

## Build
- App target compiled first time. The tests failed to compile, as you expected: `PlaceChangeLayoutTests.swift:122` used `placeSkeletonThreshold`.

## Test updates (behaviour, not the other way round)
- **`PlaceSkeletonTests`:**
  - The injected sleep now only times the 350 ms minimum, so the stubs are renamed `minimumPassed` / `minimumPending`.
  - `minimumPending` is kept only where the fix fails (a failure cancels the minimum) or for a retry, which has no minimum running. A landed fix would otherwise wait out its 30 s sleep, so `pendingSentenceKeepsSelectedDate` moved to `minimumPassed`.
  - "Under 400 ms: no skeleton" became `skeletonShowsAtOnce()`: `.finding` while the first fix is still out.
  - `cardReplayOnlyWithoutSkeleton()`: Use my location now always lands over a skeleton, so it never bumps `cardLoadInGeneration`; a pick still does.
- **`PlaceChangeLayoutTests`:** line 122 now checks the skeleton is in by sample ≤ 1 and within 200 ms of the start (`immediateSkeletonBound`). My first bound (3 × 16 ms) failed at 62 ms because each sample includes a ~30 ms screen capture. The sample-index check passed both times.
- **`ContentLoadInTests`:** `placeChangeLanding()` updated to the new values (0.4 / 0.1 / 0.25).

## Runs (each with a 1-minute limit, heartbeats before and after)
| Suite | Result |
|---|---|
| `ContentLoadInTests` | 6/6 |
| `PlaceSkeletonTests` | 11/11 |
| `PlaceChangeLayoutTests` | 1/1 (second run, after the bound fix) |
| Full suite | **990/990** |

- First attempt at the suites: Xcode's destination was back on the T2 iPhone ("moonbeam-appTests requires a development team"). Switched to iPhone 17.
- No hangs.

## Flags (not changed)
1. **Stale comments:** in `LocationViewModel.swift`, lines 118 ("taken past the threshold"), 136 ("before the §12.2 threshold") and 235 (`placeChangeSleep`: "the card skeleton's 400 ms threshold") still describe the removed threshold.
2. **Magic number:** `placeRevealFade` is now a literal `0.3`.
3. **DECISIONS.md:** the new entries are again at the bottom of the file under `##`.
4. **Still open from 5.10a.3:** after a failed My location, the hidden city line leaves no way into search.
5. **Untested:** the visible behaviour (old card and city line gone in the same frame, whole-card rise) has no test. Device check only.
