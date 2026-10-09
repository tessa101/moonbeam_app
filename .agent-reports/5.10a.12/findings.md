# Build 5.10a.12 — separate fade and rise curves (LOADER.md 5.10a.12, DECISIONS.md 2026-10-09)

Updated October 9, 2026. The code was already in the working tree on top of `75dc26a` (`ContentLoadIn.swift`, `MoonCardSkeleton.swift`, `ContentLoadInTests.swift`), uncommitted and never compiled; this run built and tested it. No code or test changes.

## What's in it (as written in the working tree)
- **Why (video 8):** with one shared ease-out, about 70% of the rise was done while the card was still faint, so it looked like a fade in place.
- **Fix:** `RisingIn` now drives opacity and offset from two states, on separate curves:
  - **fade** 0.25 s ease-out (`cardFadeAnimation`);
  - **rise** 0.55 s ease-in-out over the 24 pt (`cardRiseAnimation`);
  - both after +0.1 s.
  The card is opaque well before the rise ends, so it's seen travelling.
- **Tests:** `ContentLoadInTests.cardLandingOverSkeleton()` also pins fade 0.25, rise 0.55, and fade < rise.

## Runs (1-minute limits, heartbeats before and after)
| Suite | Result |
|---|---|
| `ContentLoadInTests` | 7/7 |
| `PlaceSkeletonTests` | 11/11 |
| `PlaceChangeLayoutTests` | 1/1 |
| Full suite | **991/991** |

- No stale processes at the start, so nothing was killed. I set Xcode's destination to iPhone 17 before the tests. No stalls.

## Flags (not changed)
1. **`cardLandingAnimation` is now half-used.** `RisingIn` no longer uses it; it's still the ambient `.animation(value: moonTable != nil)` in `PlaceCardRegion`, which RisingIn's explicit `withAnimation` overrides. Its comment ("same timing as the card's own replay") was already out of date. Could go, or be documented as the ambient fallback.
2. **Stale test text:** the `cardLandingOverSkeleton()` name still says "16 pt" and its comment says both start on the delay. Still open from 5.10a.11.
3. **Still open:**
   - `landsOverSkeleton` never resets;
   - the `.zIndex(2)` indent;
   - stale threshold comments;
   - literal 0.3 in `placeRevealFade`;
   - the DECISIONS.md entries sit at the bottom of the file;
   - no way into search after a failed My location.
4. **Untested:** the visible travel. Device check.
