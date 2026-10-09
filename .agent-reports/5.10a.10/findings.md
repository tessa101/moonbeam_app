# Build 5.10a.10 — card rises as one unit (LOADER.md 5.10a.10, DECISIONS.md 2026-10-09)

Updated October 9, 2026. The code was already in the working tree on top of `9a57097` (`MoonCardSkeleton.swift` only), uncommitted and never compiled; this run built and tested it. No code or test changes.

## What's in it (as written in the working tree)
- **The change:** the real card no longer lands through a transition. Per video 6, the transition's offset moved only the date line and the arrows. It's now wrapped in a new private `RisingIn` view. On appear, `RisingIn` fades the card from 0 and lifts it from +16 pt (`cardLandingRise`) with `cardLandingAnimation` (0.45 s, +0.1 s), as one unit.
- **When it rises:** only when `landsOverSkeleton` is set, which happens once a placeholder has held the slot, and not with Reduce Motion. Launch and other first appearances keep their own load-in. The card's transition is now `.identity`, and it keeps `zIndex(2)` above the skeleton.

## Runs (1-minute limits, heartbeats before and after)
| Suite | Result |
|---|---|
| `ContentLoadInTests` | 7/7 |
| `PlaceSkeletonTests` | 11/11 |
| `PlaceChangeLayoutTests` | 1/1 (old-card ink check clean) |
| Full suite | **991/991** |

- **The reported hang:** none was found. There were no `xcodebuild` / `xctest` / app processes on the Mac or in the simulator, so nothing was killed. As before, the earlier stop was the interrupted test call.
- **First try at the suites:** Xcode's destination was back on the T2 iPhone ("requires a development team"). Switched to iPhone 17. No suite stalled.

## Flags (not changed)
1. **`landsOverSkeleton` is never reset.** It stays true after the first skeleton. In practice:
   - a later search pick keeps the same `RisingIn` view, so it doesn't rise again;
   - but a card that first appears after a failure placeholder (fail, then pick a city) will rise 16 pt.
   5.10a.5's version reset it when a replacement began. Probably fine, but worth a look on the device.
2. **Formatting:** `.zIndex(2)` is indented one level too deep, and there's a double blank line before `RisingIn`.
3. **Untested:** the rise isn't covered by a test (there's no view-level animation test).
4. **Still open:**
   - `cardLandingAnimation`'s comment says it matches the replay;
   - stale threshold comments;
   - literal 0.3 in `placeRevealFade`;
   - the DECISIONS.md entries sit at the bottom of the file;
   - no way into search after a failed My location.
