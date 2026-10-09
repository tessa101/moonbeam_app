# Build 5.10a.9 — card rises above the skeleton (LOADER.md §12.3, DECISIONS.md 2026-10-09)

Updated October 9, 2026. The code was already in the working tree on top of `40cb423` (`ContentLoadIn.swift`, `MoonCardSkeleton.swift`), uncommitted and never compiled; this run built and tested it. No app code changed.

## What's in it (as written in the working tree)
- **Card:** sits above the skeleton (`zIndex(2)`) and lands as a fade plus a **16 pt** rise (`cardLandingRise`), **0.45 s** ease-out after the **+0.1 s** card delay. Before, an 8 pt rise was hidden under the skeleton's opaque frame.
- **Skeleton:** exits in **0.25 s** (`skeletonExitAnimation`, same +0.1 s delay), beneath the card.
- **Constant:** `PlaceCardRegion.replacementAnimation` (0.5 s) is removed; the two landing fades now use the new animations.
- **Reduce Motion:** instant swap. The 5.10a.8 no-animation-while-replacing rule is kept.

## Tests
- No test used `replacementAnimation` or the changed timings. The only replay value the tests pin, `replayDuration` 0.4, is unchanged. Nothing needed fixing.
- **Added** `ContentLoadInTests.cardLandingOverSkeleton()`. It pins:
  - rise 16 pt, more than the launch 8 pt;
  - card 0.45 s;
  - skeleton exit 0.25 s, shorter than the card's landing;
  - card delay 0.1 s.
- **Runs** (1-minute limits, heartbeats before and after each):

| Suite | Result |
|---|---|
| `ContentLoadInTests` | 7/7 |
| `PlaceSkeletonTests` | 11/11 |
| `PlaceChangeLayoutTests` | 1/1 (old-card ink check still clean) |
| Full suite | **991/991** |

## Flags (not changed)
1. **Stale comment:** `ContentLoadIn.cardLandingAnimation`'s comment still says "same timing as the card's own replay", but it's now 0.45 s against the replay's 0.4 s.
2. **Stray line:** a blank line is left where `replacementAnimation` was, in `PlaceCardRegion`.
3. **Still open from earlier:**
   - stale threshold comments in `LocationViewModel.swift`;
   - `placeRevealFade` is a literal 0.3;
   - the DECISIONS.md entries sit at the bottom of the file;
   - no way into search after a failed My location.
4. **Untested:** the rise itself (the card visibly moving above the skeleton) isn't covered by a test. Device check.
