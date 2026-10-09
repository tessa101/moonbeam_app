# Build 5.10a.11 — skeleton out first, bigger card rise (LOADER.md 5.10a.11, DECISIONS.md 2026-10-09)

Updated October 9, 2026. The code was already in the working tree on top of `99eca76` (`ContentLoadIn.swift` constants and the matching `ContentLoadInTests` expectations), uncommitted and never compiled; this run built and tested it. No code or test changes.

## What's in it (as written in the working tree)
- `skeletonExitDuration` 0.25 → **0.1 s**. `skeletonExitAnimation` has **no delay** (was +0.1 s), so the skeleton is gone by the time the card starts at +0.1 s.
- `cardLandingRise` 16 → **24 pt**. The card's landing is otherwise unchanged (0.45 s, +0.1 s).
- `ContentLoadInTests.cardLandingOverSkeleton()` now expects 24 pt and 0.1 s, and adds `skeletonExitDuration <= replayCardDelay`.

## Runs (1-minute limits, heartbeats before and after)
| Suite | Result |
|---|---|
| `ContentLoadInTests` | 7/7 |
| `PlaceSkeletonTests` | 11/11 |
| `PlaceChangeLayoutTests` | 1/1 |
| Full suite | **991/991** |

- No stale processes at the start, so nothing was killed.
- Xcode's destination was on the T2 iPhone again; I switched it to iPhone 17 before the tests (no failed attempt this time).
- No stalls.

## Flags (not changed)
1. **Stale test text** in `cardLandingOverSkeleton()`:
   - its display name still says "a visible 16 pt rise", but it checks 24;
   - its last comment says "Both start on the card's replay delay", but the skeleton now has no delay.
2. **Still open:**
   - `landsOverSkeleton` never resets;
   - the `.zIndex(2)` indent;
   - `cardLandingAnimation`'s comment says it matches the replay;
   - stale threshold comments;
   - literal 0.3 in `placeRevealFade`;
   - the DECISIONS.md entries sit at the bottom of the file;
   - no way into search after a failed My location.
3. **Untested:** the rise and the exit order on screen. Device check.
