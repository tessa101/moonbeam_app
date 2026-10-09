# Build 5.10a.13 — two-layer card slot; the card always lands with the ordinary replay (LOADER.md 5.10a.13, DECISIONS.md 2026-10-09)

Updated October 9, 2026. The code was already in the working tree on top of `8992871`, uncommitted and never compiled. This run built it, fixed the one compile error (in a test harness) and updated tests to the new behaviour. No app code changed.

## What's in it (as written in the working tree)
- **Two layers:** `PlaceCardRegion` takes `layer: .card | .placeholder`.
  - `LocationScreen` stacks both in one `ZStack(alignment: .top)`.
  - `.contentLoadIn(.card, generation: cardLoadInGeneration)` is on the **card layer only**: the real card, or the invisible slot of the replaced card's size.
  - The skeleton or failure layer sits on top, outside that load-in, and fades out over 0.2 s (`skeletonExitDuration`, no delay) as the card arrives.
- **Card replay:** `show()` always bumps `cardLoadInGeneration` when where changes, so the card lands exactly like a searched city's: 8 pt rise, 0.4 s, +0.1 s (video 9).
- **Removed:** `RisingIn`, `landsOverSkeleton`, `cardLandingRise`, `cardLandingDuration`, `cardLandingAnimation` and the `cardFade*` / `cardRise*` constants.

## Fixes (no design change)
- **Compile error:** `PlaceChangeLayoutTests.swift:254`, missing `layer:`. The harness now mirrors `LocationScreen`: the same two-layer ZStack, with the load-in on the card layer and the slot probe on the ZStack.
- **`PlaceSkeletonTests`:** `cardReplayOnlyWithoutSkeleton()` expected no card bump when a skeleton held the slot. It became `cardReplaysOnEveryLanding()`: Use my location bumps it (+1), and a pick bumps it again (+2).
- **Removed constants:** no other test referenced them. `ContentLoadInTests` had already been updated in the working tree.

## Runs (1-minute limits, heartbeats before and after)
| Suite | Result |
|---|---|
| `ContentLoadInTests` | 7/7 |
| `PlaceSkeletonTests` | 11/11 |
| `PlaceChangeLayoutTests` | 1/1 (old-card ink check still clean with two layers) |
| Full suite | **991/991** |

- No stale processes at the start, so nothing was killed. I set Xcode's destination to iPhone 17 before the tests.

## Flags (not changed)
1. **Possible double animation on the card layer.** Both layers carry `.animation(skeletonExitAnimation, value: cardPlaceholder)`. On the card layer, the swap from the hidden slot to the real card happens in that transaction, so it may also get a 0.2 s default opacity cross-fade underneath the block's replay. Probably invisible because the block snaps to 0 first, but worth a look on the device.
2. **Resolved:** `landsOverSkeleton` and its never-reset issue are gone with `RisingIn`.
3. **Still open:**
   - stale threshold comments;
   - literal 0.3 in `placeRevealFade`;
   - the DECISIONS.md entries sit at the bottom of the file;
   - no way into search after a failed My location.
4. **Untested:** the visible landing. Device check.
