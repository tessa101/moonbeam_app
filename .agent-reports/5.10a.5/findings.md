# Build 5.10a.5 — place change polish (LOADER.md §12.3, DECISIONS.md 2026-10-09)

Updated October 9, 2026. The code was already in the working tree on top of `911f5b5`, uncommitted and never compiled; this run built and tested it. No code or test changes needed.

## What's in it (as written in the working tree)
- **Old card:** `PlaceCardRegion` gives the real card `.transition(.identity)`, so the replaced place's card is gone the instant the change starts.
- **City line** (`MadlibSentence`):
  - a `placeRevealed` state hides the line when detection starts;
  - it's let back in once, with `withAnimation(placeRevealFade)` in `onChange`, after the new name is already in place;
  - so the old name and "a city" no longer cross-fade into the new one.
- **Card content** (`MoonCard`): landing over a skeleton (`risesCardContent`, new in `AhaFlight.swift`'s environment values), the frame stays and only the content fades and rises 8 pt (`cardLandingAnimation`), while the skeleton fades out above it (`zIndex(1)`).
- **Unchanged:** the fast path (no skeleton) replays the whole card block. Reduce Motion: instant swap.

## The hang report
- The run was reported hung at 13:24 during the three suites. At resume there were no `xcodebuild` / `xctest` / app processes on the Mac or in the booted iPhone 17 simulator, so nothing was killed. As in the last two runs, the stop came when the test call was interrupted.
- Each suite then ran on its own, with a 1-minute limit and heartbeats before and after:
  - `ContentLoadInTests`: 6/6
  - `PlaceSkeletonTests`: 11/11
  - `PlaceChangeLayoutTests`: 1/1, no hang
- On the opacity-0 hypothesis: the layout test's pixel check only reads the sentence's rectangle, over a fixed 80 samples, and never waits on the card's pixels. The card content's fade can't block it.
- Full suite **990/990 pass**.

## Tests
- No test assumed the old card's slow fade-out or a rising card block: the skeleton tests are view-model level, and the layout test checks the slot frame and the sentence. So nothing needed updating.
- **Gap:** no test covers 5.10a.5's view behaviour: the old card gone in the first frame, the content rising inside a fixed frame, and the single reveal. Device check only, for now.

## Flags (not changed)
1. **City reveal timing:** probably resolved. The reveal is now its own animation after the text is in, so the 0.15 s token fade shouldn't take it over. Worth a look on the device.
2. **Comment:** the `risesCardContent` comment in `AhaFlight.swift` says "5.10a.4" for this 5.10a.5 change.
3. **DECISIONS.md:** the new entry is again at the bottom of the file under `##`.
4. **Still open from 5.10a.3:** after a failed My location, the hidden city line leaves no way into search.
