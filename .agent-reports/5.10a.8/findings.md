# Build 5.10a.8 — one-frame swap when a replacement begins (LOADER.md §12.3, DECISIONS.md 2026-10-09)

Updated October 9, 2026. The code was already in the working tree on top of `0eff26f` (`MoonCardSkeleton.swift`, `MadlibSentence.swift`), uncommitted and never compiled; this run built it and added a test check. No app code changed.

## What's in it (as written in the working tree)
- **`PlaceCardRegion`:** while `isReplacingPlace` is true, the transaction's animation is cleared (`transaction.animation = nil` as well as `disablesAnimations`), and the two `.animation(value:)` fades on `cardPlaceholder` and `moonTable != nil` are nil. So the old card and the skeleton swap in one frame.
- **`MadlibSentence`:** the same for the city line while the place is pending; its token fade is nil then too.
- **Landing:** still animates, because `isReplacingPlace` is false by then.

## Test added (`PlaceChangeLayoutTests`)
- **Probe:** the card slot's frame.
- **Control:** at rest the real card's text reads as ink (≥ 200 light pixels).
- **Main check:** on every sample where the finding skeleton shows, from the first drawn frame of the replacement on, the card slot has no ink. The finding skeleton has no text, only dark blocks and a 10% highlight, so any ink there is the old card. The test also asserts that the first drawn frame was actually checked.
- **Why offset 0 is skipped:** the first run failed only there (2199 px). The view-model state already read `.finding`, but SwiftUI hadn't drawn the frame yet, so the capture still showed the old card. Every later sample was clean.
- **Does the check catch the bug?** I ran it against 0eff26f's versions of the two files (5.10a.8 temporarily removed, then restored from `/tmp/mb-5108/`). It **fails**: old-card ink 2188 → 1601 → 453 → 348 px over samples 1–4, the fade-out from video 5. With 5.10a.8 it passes.

## Runs (1-minute limits, heartbeats before and after)
| Suite | Result |
|---|---|
| `PlaceSkeletonTests` | 11/11 |
| `PlaceChangeLayoutTests` | 1/1, after the offset fix |
| Full suite | **990/990**, after restoring 5.10a.8 |

- The full suite included `PlaceChangeLayoutTests`, which fails without 5.10a.8, so it ran the restored code.

## Flags (not changed)
1. Still open from earlier: three stale threshold comments in `LocationViewModel.swift` (lines 118, 136, 235); `placeRevealFade` is a literal 0.3; the DECISIONS.md entries sit at the bottom of the file.
2. Still open from 5.10a.3: after a failed My location, the hidden city line leaves no way into search.
3. The new check covers the card slot only. The city line's one-frame hide isn't pixel-checked.
