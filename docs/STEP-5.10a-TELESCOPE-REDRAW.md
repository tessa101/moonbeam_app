# Step 5.10a: Telescope redraw (permission-off illustration)

> Owner: Tessa · 2026-10-12 · Decision: **Option A**, moon lit on the LEFT (matches the original D2 art). Supersedes the Chunk 2b mirror for this illustration only. Lens glint: kept.

## Why
The shipped telescope (`permissionOff_*` slices) came from a flat vector reconstruction that doesn't match the approved D2 art (`design/d2-luminous-calico/reference/d2-approved.png`, third panel). The slicing was faithful; the source art was not. Redrawn art + preview: `design/1.7-telescope-redraw/` (`compare.png`, `telescope_motion_AB.mp4`, generator `gen.py`).

## Art (use as-is, do not redraw)
`design/1.7-telescope-redraw/A-lit-left/`: `permissionOff_moonHalo.svg`, `_moonDisc.svg`, `_stand.svg`, `_tube.svg`, `_lensGlint.svg`. All 400 × 520, same viewBox and z-order as today, plus the new glint on top. Replace the four existing `permissionOff_*` imagesets and add `permissionOff_lensGlint`. Same import settings (Preserve Vector Data, Single Scale, Original). If Xcode drops gradients on any layer, fall back per layer (PDF, then PNG @3x) and say which.
Z-order: moonHalo, moonDisc, stand, tube, lensGlint, (star on top).

## Motion (numbers unchanged unless listed)
- Tilt keyframes unchanged (6.59 s: 0 / .22 / .50 / .56 / .62 / .68 / .72 / .90 / 1 → 0° / −7° / −7° / −5.5° / −7.5° / −6.5° / −7° / 0° / 0°).
- **Tube pivot (155, 335) → (204, 330)** (the mount head's centre in the new art). `lensGlint` uses the SAME pivot and the SAME rotation as the tube (it rides on the tube).
- **Moon centre (halo scale pivot) for this state: (190, 203)**, not `crescentMoonCentre` (250, 212). Do not change services/restricted.
- **Star centre (128, 122) → (326, 150).** Star keyframes unchanged.
- **New `lensGlint` opacity**, 6.59 s, same easing: offsets 0 / .18 / .28 / .50 / .56 / .62 / .68 / .74 / .90 / 1 → 0 / .10 / .85 / .80 / .55 / .95 / .70 / .60 / 0 / 0. (Glint warms up as the tube rises, flickers with the wobble, fades on the way down.)
- Halo and disc breathing unchanged (5.88 s).
- Reduce Motion: static frame, glint opacity 0, star hidden.

## Chunks (one commit each, progress.log line before each)
1. Import the five layers, replace the old slices, update `IllustrationSpec.permissionOff` (layers, pivots, glint motion, star centre). Add whatever part/channel the glint needs to the spec types; nothing hard-coded in views.
2. Tests: pivot conversion for (204, 330), glint keyframe sampling at a few offsets, Reduce Motion shows no glint. Update `IllustrationSpecTests`/`IllustrationMotionTests` for the changed numbers.
3. Screenshots of `-screenState locationFailed.denied` at default, AX1, AX5 and iPhone SE 3, plus three frames of the motion (rest, hold, wobble). Check the art frame, headline and primary button heights are unchanged vs the other causes, and the star clears the crescent and the tube at max tilt.

Environment notes from earlier chunks apply: no `xcodebuild test`, no `simctl`; use `build-for-testing` and give me test commands for Terminal.
