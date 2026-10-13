# Handoff: Location-off compass teaser

## Overview
When location is off, the home screen currently shows a warning chip ("Turn on location to use the compass.") above the **Turn On Location** button. To users this reads as nagging, because they can't see what they'd get. This change replaces the chip with a small animated compass that shows what the feature does.

**Build direction: 1b (animated cartoon compass).** Options 1a, 1c, 1d and 1e are in the file for context only. Do not build them.

## About the design files
`Location Off Teaser.dc.html` is a **design reference made in HTML**. Open it in a browser; it loads `support.js` and `assets/anim/searching.svg` (used by 1c only). Rebuild 1b natively in the app's existing SwiftUI patterns. Don't ship the HTML. `CompassTeaserReference.swift` is a starting sketch, not final code.

## Fidelity
High fidelity for the 1b teaser block: exact colors, geometry, copy and motion. The header, phase card and CTA in the mock are rough copies of the existing screen. **Keep the current production versions of those**, unchanged.

## Options in the file (for context)
- **1a, cartoon compass, still:** the same art as 1b with the needle fixed on the moon.
- **1b, cartoon compass, animated:** ✅ **BUILD THIS.**
- **1c, calico cat + compass:** liked, but parked. The final art would be a new illustration of the cat holding the compass. Possible future swap-in for 1b.
- **1d, ghosted real compass:** the real compass UI, dimmed and blurred.
- **1e, missing needle:** the real rise/set arc with a "?" where the needle goes.

## Screen: Home, location off (1b)

### Where it goes
- Remove the warning chip (the "!" icon and "Turn on location to use the compass.").
- Insert the teaser block between the phase/rise-set card and the **Turn On Location** button. The button stays the same: copy, style and action.
- Teaser block: vertical stack, centered, 10pt spacing, 4pt top padding. Screen gutters are unchanged (20pt).

### Teaser block contents (top to bottom)
1. **Compass illustration:** 180×180pt (see Geometry).
2. **Title:** "Point your phone at the moon". Young Serif 20pt, line height 26pt, #F5EADB, centered, one line.
3. **Body:** "With location on, this becomes a live compass that turns you toward it." Nunito Sans Regular 15pt, line height 1.45, #B9A898, centered, max width 300pt.

### Geometry
Authored in a 200×200 viewBox, rendered at 180pt (scale 0.9). All circles are centered at **(100, 104)** unless noted. Paint order, back to front:

| Layer | Spec |
|---|---|
| Glow | circle r 98, radial gradient #F2C27B, opacity .28 at center → 0 at edge |
| Bail (top loop) | circle at (100, 21), r 10, no fill, stroke #E9D3A6, width 5 |
| Bezel | circle r 76, fill #F7E7BD, stroke #C99A5B, width 3 |
| Face | circle r 62, fill #241B21 |
| E/S/W ticks | 8-unit lines just inside the face at 3, 6 and 9 o'clock (`M156 104h-8 M100 160v-8 M44 104h8`), #6E5C66, width 3, round caps |
| N tick | `M100 48v8`, #F2C27B, width 3, round cap |
| Glass shine | arc `M60 82 A46 46 0 0 1 84 60`, #F7E7BD at 18% opacity, width 5, round caps |
| Moon glow | circle at (181, 61), #F2C27B, animated (see Motion) |
| Moon disc | circle at (181, 61), r 8, #F7E7BD |
| Moon shadow (makes the crescent) | circle at (185, 58), r 7, filled with the **screen background** #1B1519 |
| Needle, north half | triangle (100,58) (108,104) (92,104), #F2C27B |
| Needle, south half | triangle (100,150) (108,104) (92,104), #6E5C66 |
| Hub | circle r 7 #F7E7BD, then circle r 2.5 #241B21 |

The needle group rotates around (100, 104). At 62° it points at the moon marker.

### Motion: "hunt, then find"
One 5.0s loop, repeating forever. Every segment uses ease-in-out, cubic-bezier(.45, 0, .55, 1).

| t (s) | 0 | 0.75 | 1.5 | 2.25 | 2.75 | 3.1 | 4.5 | 5.0 |
|---|---|---|---|---|---|---|---|---|
| Needle rotation | −30° | 40° | −12° | 78° | 56° | 62° | 62° (hold) | −30° |
| Moon glow opacity | .12 | .12 | .12 | .12 | .35 | .55 | .55 | .12 |
| Moon glow radius | 13 | 13 | 13 | 13 | 16 | 19 | 17 | 13 |

The story: the needle swings around searching, overshoots, settles on the moon, the moon brightens, it holds about 1.4s, then resets.

- **Reduce Motion:** don't animate. Show the settled frame (needle at 62°, glow at .55 opacity, r 19).
- Pause the animation when the view is off screen or the app is in the background.

## State
- Show the teaser whenever the existing "location off" UI would show (the debug panel's `visibility: locationOff`).
- Assumption, please confirm: for **restricted** (the user can't enable location), keep the current restricted messaging instead of the teaser, because the CTA can't help them.
- After location is granted, the real compass replaces the teaser. No extra transition is needed beyond what's already there.

## Design tokens
- Background #1B1519 · Text #F5EADB · Muted text #B9A898 · Amber #F2C27B
- Cream #F7E7BD · Bail #E9D3A6 · Bezel stroke #C99A5B · Face #241B21 · Needle south / ticks #6E5C66
- Fonts: Young Serif (title), Nunito Sans (body). These are already in the app.

## Assets: compass layers for Xcode
The files are in `assets/compass/`. Every layer is **200×200 on the same canvas**, so stacking them in a `ZStack` lines them up exactly. Scale the stack to 180pt. Add each one to the asset catalog with **Preserves Vector Data** on and **Render As: Original**. `preview.html` shows them all on the app background.

| File | Contents | Animate |
|---|---|---|
| `compass-1-glow.svg` | radial amber glow behind the compass | — |
| `compass-2-body.svg` | bail, bezel, face, ticks, glass shine | — |
| `compass-3-moon-glow.svg` | amber disc, r 19 at (181, 61) | opacity .12 → .55; scale .684 → 1, which is r 13 → 19. Anchor `UnitPoint(x: 0.905, y: 0.305)` |
| `compass-4-moon.svg` | crescent moon as a real path, so it works on any background (no shadow-circle trick) | — |
| `compass-5-needle.svg` | both needle halves, pointing north (0°) | `rotationEffect`, anchor **`UnitPoint(x: 0.5, y: 0.52)`** (the pivot is (100, 104), not the canvas center) |
| `compass-6-hub.svg` | center hub, drawn above the needle | — |
| `compass-settled.svg` | single flattened composite (needle at 62°, glow on) | Use for Reduce Motion, previews or App Store art |

Stack order, back to front: 1 → 6. Keyframes are in the Motion section above. The moon-glow layer's base opacity is 1, so drive `.opacity()` from the table.

## Files
- `Location Off Teaser.dc.html`: all five options. **1b is the one to build.**
- `CompassTeaserReference.swift`: a SwiftUI sketch of 1b.
- `assets/compass/`: layered SVGs for the 1b build (see Assets).
- `support.js`, `assets/anim/searching.svg`: needed to open the HTML (the SVG is for 1c only).
