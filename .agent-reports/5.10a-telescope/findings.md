# 5.10a telescope redraw — chunk 3 findings (2026-10-12)

## Captures
| File | What | How |
|---|---|---|
| `iphone18pro_default_denied.png` | `locationFailed.denied`, default text | Xcode preview `24 Failed: App permission off` (DebugScreenState) |
| `iphone18pro_AX1_denied.png` | permission off, AX1 | `LocationFailureView` preview "Permission off" + Dynamic Type override |
| `iphone18pro_AX5_denied.png` | permission off, AX5 | same, AX5 |
| `se3_default_denied.png` | `-screenState locationFailed.denied`, iPhone SE 3 | "SE3 fit check" simulator via Xcode device interaction (no simctl) |
| `motion/1_rest_t0.png` | rest: tube 0°, glint 0, star hidden | `ImageRenderer` of the frame at t = 0 |
| `motion/2_hold_t40.png` | hold: tube −7°, glint 0.82, star ~0.9 | t = 0.40 × 6.59 s |
| `motion/3_wobble_maxtilt_t62.png` | wobble at max tilt: tube −7.5°, glint 0.95 | t = 0.62 × 6.59 s |
| `motion/4_star_peak_t54.png` | star at full size, tube −5.8° | t = 0.54 × 6.59 s |

On disk only (not committed): `iphone18pro_*_servicesOff_compare.png`, `motion/5_reduce_motion_still.png` (same as rest, as specified).

## Notes
- Previews always render on iPhone 18 Pro (they ignore the run destination), so "default/AX1/AX5" are iPhone 18 Pro, not iPhone 17.
- The DebugScreenState preview gave the wrong preview whenever a Dynamic Type override was set (index off by two), so the AX shots use `LocationFailureView`'s "Permission off" preview. It's the same view `locationFailed.denied` shows, without the launch wrapper.
- **Heights unchanged vs other causes:** at default size, the services-off headline, chip, button (y 1236–1330 px) and link land on the same rows as denied. The art frame is sized from all causes' tallest copy, not the art, so it can't differ by cause.
- **AX4+ hides the art** for every cause (`LocationFailureLayout`, existing rule). Services off at AX5 matches.
- **SE 3:** nothing is truncated. The art's unrotated frame is 160 × 208 pt at y 90–298, and the headline starts at y 302. In the accessibility tree the tube/glint frames reach y 306, but that's the rotated bounding box mid-tilt, not drawn pixels.
- **Star clearance (geometry, viewBox units):** at 0°, −7° and −7.5°, the nearest tube/glint outline point is ≥ 54.9 from the star's centre (star radius 11), and the star clears the crescent's edge by 38.6. Frames 3 and 4 confirm it visually.
- Pre-existing, not touched: the "Open Settings" label renders smaller at AX sizes than the link below it (it was also in the earlier 5.10a captures).
