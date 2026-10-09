# Build 5.10a.3 — hidden city line, shimmer skeleton (LOADER.md §12.3, DECISIONS.md 2026-10-09)

Updated October 9, 2026. The code was already in the working tree, uncommitted and never compiled; this run built it, tested it and fixed one test error. Behaviour unchanged.

## What's in it (as written in the working tree)
- **Sentence:** during My location the city line is laid out but hidden (`Sentence.placeIsPending`). It can't be tapped, VoiceOver skips it, and it fades in at 0.5 s (`MadlibSentence.placeRevealFade`). The "your location" stand-in (`replacementPlaceToken`, `standInText:`) is removed.
- **Skeleton:** no text while finding. Blocks for the moon, the date and phase lines, ‹ › and the rise/set rows, with a highlight sweeping left to right (1.4 s linear, repeating; still with Reduce Motion). A failure keeps the blocks still and shows the failure line in the header. Skeleton ↔ card cross-fade 0.5 s (was 0.2 s).

## Build and tests
- `xcodebuild build-for-testing`: compiled first time, no errors.
- Xcode's destination was on the T2 iPhone, so test runs failed with "moonbeam-appTests requires a development team". I switched it to iPhone 17.
- 1 failure: `MadlibFormatterTests/pendingPlace()` expected `[.date]` tokens but got `[]`. The test called the formatter with no place and no `dateTimeZone`, and then the date is plain words by design. In the app, a pending place always comes with the replaced place's zone (5.10a.2b), so the test now passes `dateTimeZone: .gmt` as the real call does. Test fix only.
- Full suite **989/989 pass**.

## Flags (not changed; for Tessa)
1. **After a failure there's no way into search.** The city line stays hidden and can't be tapped while `isReplacingPlace` is true, which is still the case after a failure. The failure line says "search for a city", but the city token seems to be the only way into search (LOADER.md §10), and VoiceOver drops the place button too. §12.9 used to keep "your location" tappable here.
2. **The 0.5 s reveal may play at 0.15 s.** When the city lands, the place text and `placeIsPending` change in the same update. `.animation(placeTokenFade, value: placeText)` sits inside `.animation(placeRevealFade, value: placeIsPending)`, and the inner one probably decides the line's opacity. Not checked on screen; worth a look on the device.
3. **DECISIONS.md:** the new entry is at the bottom of the file under `##`. The file's rule is newest first, under `###`.
4. **Build number:** "5.10a.3" was the compass entrance in STATUS.md and LOADER.md §12.6. This build reuses the number; the compass entrance needs a new one.

## Not done
- No simulator or device screenshots of the shimmer this run.
