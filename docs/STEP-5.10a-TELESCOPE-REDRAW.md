# Step 5.10a: Telescope redraw (permission-off illustration)

> **SUPERSEDED (Tessa, 2026-10-16): this task is removed from the plan. Do not run any chunk or the "pick up tomorrow" paths below.** The permission-off telescope is replaced by the 1k Ready-to-look cat (`docs/STEP-5.14-ONBOARDING-CAT-AND-LOAD-IN.md`, `design/1.10-ready-to-look/`). Kept for history only; the `6bbdd9a` art stays in the app until that replacement lands.

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

---

## CORRECTION (Tessa, 2026-10-12, 16:30): the art choice in this doc was wrong. Do not run chunks 2 and 3 as written.

"The left telescope" meant the **original D2 art** (far left of `design/1.7-telescope-redraw/compare.png`; source: `design/d2-luminous-calico/reference/d2-approved.png`, third panel), NOT Option A or B. Both A and B are vector redraws and neither is what she wanted. Chunk 1 (`6bbdd9a`) imported A, so the denied screen currently shows the wrong telescope.

Status: paused. Chunks 2 and 3 are on hold. Nothing pushed.

### Pick up tomorrow
1. Get the original telescope into layered form. The original is a shaded 3D-style raster; the crop in `d2-approved.png` is only about 360 x 450 px, too small for @3x. Options to offer her:
   - a. Ask for a higher-resolution render of the original, then cut it into raster layers (moon, stand, tube, glint) with the same layer names on the 400 x 520 canvas.
   - b. Trace it into vector again, matching the shading, rim light and the glow along the crescent's left edge more closely than A did.
   - c. Hybrid: raster for the shaded tube and stand, vector for the moon and halo so those can still breathe cleanly.
2. Replace the `permissionOff_*` layers from `6bbdd9a` once the right art exists.
3. Reuse from this round: the layer split and names, the tube pivot at the mount head, the lens glint idea (original motion notes: "the front lens catches moonlight now and then"), and the moon lit LEFT for this illustration. The pivot, star and glint numbers in this doc were computed for A's geometry and must be re-measured against the new art.
4. Still open: keep the lens glint? (Tessa hasn't answered.)
