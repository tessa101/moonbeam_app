# Build 5.10a.14 — `.geometryGroup()` on the load-in (LOADER.md 5.10a.14, DECISIONS.md 2026-10-09)

Updated October 9, 2026. The change was already in the working tree on top of `23f58ac` (one line in `ContentLoadIn.swift`'s body, plus the docs), uncommitted and never compiled; this run built and tested it. No code or test changes.

## What's in it
- **Why (video 10):** measured frame by frame, the card's frame, glyph, ‹ ›, date line and hairline rose with the load-in offset. The phase line and the whole rise/set area, both built in `ViewThatFits`, stayed where they end up.
- **Fix:** `.geometryGroup()` before the block's `.opacity` / `.offset` resolves the block's geometry first, so every child moves as one unit.

## Runs (1-minute limits, heartbeats before and after)
| Suite | Result |
|---|---|
| `ContentLoadInTests` | 7/7 |
| `PlaceSkeletonTests` | 11/11 |
| `PlaceChangeLayoutTests` | 1/1 |
| Full suite | **991/991** (includes the day-arrow frame-sampling tests) |

- No stale processes at the start, so nothing was killed. I set Xcode's destination to iPhone 17 before the tests.

## Flags (not changed)
1. **Scope:** `ContentLoadIn` wraps every block, so `.geometryGroup()` also applies to the sentence, the compass block (dial, DEBUG buttons) and the bottom bar, at launch, after Aha and on every replay. That's probably what's wanted (one-unit motion everywhere), but the compass dial and the launch load-in are worth a look on the device too.
2. **Untested:** no test samples the inner `ViewThatFits` children's positions during the rise. `PlaceChangeLayoutTests` only checks the slot frame and the content below. A frame-sampling check of the phase-line position would pin this.
3. **Still open:**
   - stale threshold comments;
   - literal 0.3 in `placeRevealFade`;
   - the DECISIONS.md entries sit at the bottom of the file;
   - no way into search after a failed My location;
   - the possible extra 0.2 s cross-fade on the card layer (5.10a.13).
