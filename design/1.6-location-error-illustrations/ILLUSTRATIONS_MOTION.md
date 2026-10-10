# Handoff: Location state illustrations, animated ("Playful beats" at 0.85×)

## Overview
Five illustrations of the luminous calico for the location states. Each one loops a tiny story. The approved direction is **row B, "Playful beats", at 0.85× speed** (cards 1f–1j in the reference). Every duration below is already scaled to 0.85×, so use the numbers as written.

## About the design files
`Location Illustrations Motion.dc.html` is a **design reference built in HTML**. Open it in a browser next to `support.js` and `assets/anim/`. Its speed already defaults to 0.85×, and row B is the one to build; row A is the rejected alternative. Rebuild the motion natively in the SwiftUI app. Don't embed the HTML. Recommended approach: convert each SVG to vector assets layered by `data-part` group, or rebuild the shapes as SwiftUI `Shape`s, then drive each part with `TimelineView(.animation)` using the keyframes below. Exporting to Lottie or Rive from the same layers also works.

## Fidelity
High fidelity. The art is final (the D2 vectors). Timing, amplitude, and pivots are final.

## Assets
`assets/anim/*.svg`: 400 × 520 viewBox, transparent, with named layers in `data-part` attributes:

| File | State | Animated parts |
|---|---|---|
| `searching.svg` | Searching | `moon-halo`, `moon-disc`, `look` (head and paw together), `tail` |
| `location-not-found.svg` | No fix (timeout) | `moon` (contains `moon-ring`), `head`, `tail`, `question` |
| `permission-off.svg` | App permission off / first ask | `moon-halo`, `moon-disc`, `tube` |
| `services-off.svg` | Location Services off | `moon-halo`, `moon-disc`, `map`, `route` (path plus 3 waypoint circles) |
| `restricted.svg` | `.restricted` | `moon-halo`, `moon-disc`, `map`, `route`, `lock` |

**Coordinates:** each file's art sits inside a `<g transform="translate(dx -130)">`. The pivots below are already converted to **viewBox coordinates** (0–400 × 0–520). Scale them with the rendered size.

## Easing
Unless noted, each keyframe segment uses ease-in-out (`cubic-bezier(.42,0,.58,1)`). Every loop repeats forever and is seamless. Keyframe offsets are fractions of the loop.

## Shared by all states: moon breathing
- **Halo** (`moon-halo`): scale 0.95 → 1.06 → 0.95 and opacity 0.7 → 1 → 0.7, loop **5.88 s**, pivot at the moon center.
- **Disc** (`moon-disc`): brightness 1 → 1.06 → 1 on the same 5.88 s loop.
- **Moon centers (viewBox):** searching (215, 202); permission, services, and restricted (150, 212); not found (173, 202). Not-found has no halo; see its own section.

---

## 1f · Searching: "Scan and signal"
- **Look** (`look`): rotation, pivot (237, 268), loop **7.53 s**.
  - Offsets 0 / .14 / .36 / .50 / .64 / .86 / 1 → 0° / −5° / −5° / 0° / +5° / +5° / 0°. It looks left, holds, looks right, holds.
- **Tail** (`tail`): rotation, pivot (117, 452), loop **3.76 s**.
  - Offsets 0 / .62 / .72 / .80 / .88 / 1 → 0° / 0° / +9° / −4° / +7° / 0°. It rests, then flicks.
- **Signal rings:** 2 circles you add behind `moon-disc`. Center (215, 202), r 135, no fill, stroke `#EDBA69` 1.6 pt.
  - Each ring goes from scale 1 / opacity 0.6 to scale 1.5 / opacity 0, ease-out, loop **4.24 s**.
  - The second ring is offset by 2.12 s.

## 1g · Not found: "Huh?"
- **Head** (`head`): rotation, pivot (170, 280), loop **5.18 s**.
  - Offsets 0 / .08 / .16 / .22 / .60 / .74 / 1 → 0° / 0° / −10° / −8° / −8° / 0° / 0°. It snaps into a tilt, settles, holds, and returns.
- **Question mark** (`question`): pivot (255, 193) at its base, same 5.18 s loop.

  | Offset | Transform | Opacity |
  |---|---|---|
  | 0 | scale 0, rotate −20° | 0 |
  | .10 | scale 0, rotate −20° | 0 |
  | .20 | scale 1.2, rotate 8° | 1 |
  | .27 | scale 1, rotate 0° | 1 |
  | .62 | scale 1, rotate 0° | 1 |
  | .74 | scale 0.6, up 10 pt | 0 |
  | 1 | scale 0 | 0 |

  The pop lands at the same moment the head tilts.
- **Tail** (`tail`): rotation, pivot (230, 455), loop **3.06 s**.
  - Offsets 0 / .2 / .45 / .7 / 1 → 0° / +7° / −5° / +5° / 0°.
- **Empty moon** (`moon`, the dashed ring): rotates 0 → 360° linearly every **56.5 s** around (173, 202).

## 1h · Permission off: "Almost a star"
- **Telescope** (`tube`): rotation around the mount, pivot (155, 335), loop **6.59 s**.
  - Offsets 0 / .22 / .50 / .56 / .62 / .68 / .72 / .90 / 1 → 0° / −7° / −7° / −5.5° / −7.5° / −6.5° / −7° / 0° / 0°.
  - It tilts up, holds, wobbles, and drops back. The stand doesn't move.
- **Star:** you add it. A 4-point sparkle at (272, 122), 22 pt across, fill `#F7E7BD`. The path, centered at 0,0:
  `M0 -11 Q1.4 -1.4 11 0 Q1.4 1.4 0 11 Q-1.4 1.4 -11 0 Q-1.4 -1.4 0 -11Z`
  - Same 6.59 s loop, pivot at its own center:

  | Offset | Scale | Rotation | Opacity |
  |---|---|---|---|
  | 0 | 0 | 0° | 0 |
  | .26 | 0 | 0° | 0 |
  | .36 | 1 | 45° | 1 |
  | .46 | 0.7 | 60° | 0.8 |
  | .54 | 1 | 90° | 1 |
  | .66 | 0 | 135° | 0 |
  | 1 | 0 | 135° | 0 |

## 1i · Services off: "Fading trail"
- **Map float** (`map`): translateY 0 → −4 pt → 0, loop **6.47 s**.
- **Waypoints** (the 3 circles in `route`): base opacity 0.45.
- **Spark:** you add it. A core circle r 6.5 `#F7E7BD`, plus a glow circle r 16 `#F2C27B` at 0.22 opacity. It moves along the `route` path, on a **4.71 s** cycle:
  - **Travel, 0 → 3.06 s:** progress = smoothstep(t/3.06) × 0.62 of the path length. Smoothstep is `x²(3−2x)`.
  - **Opacity:** fades in over the first 0.25 s (×0.85). It also fades linearly to 0 over the last 35% of the travel, so it fizzles out partway.
  - **Rest:** hidden for the rest of the cycle.
- **Waypoint glow:** each waypoint's opacity = 0.45 + 0.55 × max(0, 1 − distance to spark / 40 pt) × spark opacity.

## 1j · Restricted: "Bump"
- **Spark:** same as 1i, on a **4.71 s** cycle.
  - **Travel, 0 → 1.88 s:** goes to the stop point, the first point on the path where x ≥ 154 in viewBox coordinates (just left of the lock).
  - **Bounce, 1.88 → 2.70 s** (u = 0…1 over 0.82 s): progress = stop − 0.05·sin(πu) − 0.02u, and opacity = 1 − u.
  - **Rest:** hidden for the rest of the cycle.
- **Waypoints:** same proximity glow as 1i.
- **Lock** (`lock`): pivot (175, 298) at the top of the shackle. The shake starts the moment the spark arrives (s = seconds since 1.88 s):
  - angle = 10° · sin(23.8·s) · e^(−3.83·s), for 0 < s < 1.06.
  - Otherwise 0°.

---

## Placement and states
- These map onto the existing flow's issues:
  - Searching → `searching`
  - `timeout` → not found
  - `appDenied` and `firstAsk` → permission off
  - `servicesOff` → services off
  - `.restricted` → restricted
- **Open question for design:** where these sit in the location flow. The current flow (README.md) uses the moon loader as the hero. Confirm with design whether an illustration replaces the moon on message screens, or is used elsewhere (for example in the compass and empty states), before wiring it in.
- **Reduce Motion:** show the static frame (offset 0, spark hidden, question mark visible at scale 1). No loops.
- Pause the loops when the view is off-screen or the app is in the background.

## Colors used
- Amber: `#F2C27B` and `#EDBA69`
- Cream: `#F7E7BD`
- Waypoints: `#DFB173`
- Everything else comes from the SVGs as-is.

## Files
- `Location Illustrations Motion.dc.html`: animated reference. Row B is approved; its speed defaults to 0.85×.
- `assets/anim/*.svg`: the five layered vector sources.
- `support.js`: runtime for the reference.
