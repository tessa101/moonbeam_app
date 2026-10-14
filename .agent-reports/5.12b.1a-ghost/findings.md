# 5.12b.1a plain ghost ring: build + simulator check, 2026-10-13

Spec: DECISIONS.md 2026-10-13 "5.12b.1 follow-up"; `docs/LOCATION-OFF-FLOW.md` §2. Reference: the S1 `<svg>` in
`design/1.9-location-off-flow/Location Off Flow.dc.html` (r="104").

## What changed

- **`CompassGhost` is now a plain ring drawn for this.** It no longer uses `CompassDial`. It's drawn in the 260-unit
  space and scaled to 210 pt:
  - ring r 104, `faint` (#5E4D57), 2
  - solid arc, rise to set clockwise, `accent` (#F2C27B), 4, round caps
  - end dots r 6
  - moon marker: r 10 #F7E7BD (new `Theme.Colors.ghostMoon`) over r 16 accent at 30%
  - "N" Nunito Sans Bold 14 in #B9A898, centred 14 units inside the ring's top
  - north tick #F5EADB, 4, y 0 to 34, round caps
  The ring group turns (ring, arc, dots, moon, N) and the tick stays fixed outside the rotation. The whole layer is at
  opacity 0.42 with a 1.2 pt blur; the pill isn't ghosted.
- **`CompassGhostGeometry`** (new, pure) does the placement: `point(atAzimuth:)` = (130 + 104 sin a, 130 − 104 cos a),
  the clockwise sweep, the arc as 1° steps, the dots, and the marker. The marker sits at the live moon if it's up,
  otherwise at the arc's midpoint. With no rise or no set, there's only the dot that exists, no arc and no marker
  (unless the moon is up, see below).
- **View model:** `ghostTargets`/`ghostArc` and their pass lookup are replaced by one `ghostGeometry`, built from the
  selected day's rise and set and the live moon (today and up only). Gating, the placeholder row, the 12 s loop and
  the still frame are unchanged.
- **PREVIEW** is Nunito Sans SemiBold 11 (`relativeTo: .caption2`), all caps, tracking 0.12 em. That replaces the
  system mono; nothing else on the pill changed.
- **Removed:** `CompassDial.showsTargetLabels` (only the ghost used it) and `CompassGhostMotion.heading(forRingDegrees:)`.
  `CompassDial` is back as it was before 5.12b.1.
- **New DEBUG state** `-screenState locationOff.moonDown` (denied, fake moon down), for the midpoint marker.

## Build and tests

- `xcodebuild build-for-testing` (iPhone 17 sim): succeeded after one test-only compile fix.
- Xcode `RunSomeTests`: CompassLocationPromptTests, CompassViewModelTests, CompassDialSizeTests and
  CompassTargetLabelsTests, **172/172 pass**. The new tests:
  - point math against the mock's samples: 115° → (224.3, 174.0) and 243° → (37.3, 177.2), within 0.05, plus north
    at (130, 26)
  - the arc running clockwise rise → set through due south, and the sweep across north (300 → 60 = 120°)
  - dots and arc with both ends, set only, and rise only
  - the marker at the live azimuth when up, and at the midpoint when down (also across north)
  - the view model feeding up vs down
- **Full suite not run.** `xcodebuild test` is still blocked by the sandbox PTY, so I didn't try it again. Run it in
  Terminal.

## Screenshots (iPhone 17, iOS 27, Debug, dark)

| Shot | What it shows |
|---|---|
| `1-s1-moon-down.png` | `-screenState locationOff.moonDown`, mid-turn. Rise 57° and set 304° dots, solid arc through the south, marker at the arc's midpoint. |
| `2-s1-moon-up.png` | `-screenState locationOff`, mid-turn. Same arc, marker at the live moon (266°). |
| `3-s1-reduce-motion.png` | Reduce Motion on (Settings UI), moon down. North up at 0°: rise right, set left, marker due south. Two captures 3 s apart were byte-identical. |
| `4-s1-ax3.png` | AX3, scrolled to the prompt. Ring 210 pt; title, body, CTA (2 lines) and Maybe later are not clipped or overlapping (hierarchy frames). |

Simulator restored afterwards: text size Large, Reduce Motion off.

## Please look

- **Southern hemisphere:** "clockwise from rise to set" is right where the moon passes through the south. In the
  southern hemisphere it passes through the north, so the true path runs anticlockwise (the live dial follows the
  pass and does this). For Sydney (rise ~60°, set ~300°) the ghost's arc currently goes the long way, through the
  south. Fix if wanted: draw the shorter way round between rise and set. That's right for most passes, but not for
  near-polar ones. Or use the pass direction, as the live dial does.
- **The PREVIEW pill scales with Dynamic Type** (`.caption2`). At AX3 it's large and covers much of the ring, which
  stays at 210 pt (`4-s1-ax3.png`). The mono pill in 5.12b.1 did the same. Capping it (e.g. `.dynamicTypeSize(...
  .xxLarge)`) would be a one-line change. Not done, because the brief said nothing else about the pill changes.
- **The moon is up but the day has no rise or set:** I show the live moon's marker (it's real data). The brief listed
  ring, N, tick and dots for that case. Easy to drop if you'd rather not show it.
- **"N" vs the tick at 0°:** with N centred 14 units inside the ring (y 40) and the tick to y 34 with a round cap, the
  cap just touches the top of the N. The mock's numbers give the same (its N baseline is at y 44). Visible only near
  north-up, under the blur.
- "N" is a fixed 14 in the art (`Theme.Fonts.ghostNorth`). It's decorative, hidden from VoiceOver, and the drawing
  stays 210 pt at every text size.
