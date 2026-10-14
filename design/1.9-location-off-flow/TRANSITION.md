# Transition spec: prompt ↔ row (option 1d, "One container")

Reference: open `Location Off Transitions.dc.html` and use option **1d** (press Replay; set Tweaks → slow motion to 3× to study it).

## Layout change to S1
S1 now sits **inside the same outlined card as the row**, so the two states are one container that resizes.
- Card: 350pt wide (screen width − 40), border 1pt #3A2E35, corner radius **24** expanded → **20** collapsed, no fill. Height **420** expanded → **78** collapsed. Content is clipped to the card.
- Positions inside the card when expanded (top-left origin, pt):
  - Compass preview: 180×180 at (85, 20); centre (175, 110). Same ghosted ring and rotation loop as S1, scaled to 180.
  - "Preview" pill: centred on the compass.
  - Title "Your moon compass is ready": top 212, centred, Young Serif 20 / 26.
  - Body: top 246, width 300, centred, Nunito Sans 15 / 1.45, #B9A898.
  - Turn On Location: (20, 304), 310×56.
  - Maybe later: (20, 364), 310×44.
- Collapsed (S2 to S6): the card *is* the row (row border = card border). Avatar 52 at (13, 13); title/subtitle at x 79, vertically centred; chevron 16 from the right.

## Collapse (tap Maybe later)
Easing for every track: **cubic-bezier(0.32, 0.72, 0, 1)** (iOS-style ease-out). Times in ms from tap.

| Element | Start | Duration | From → To |
|---|---|---|---|
| Maybe later | 0 | 180 | opacity 1→0, y +0→+10 |
| Turn On Location | 20 | 180 | opacity 1→0, y +0→+10 |
| Body | 40 | 180 | opacity 1→0, y +0→+10 |
| Title | 60 | 180 | opacity 1→0, y +0→+10 |
| Preview pill | 0 | 140 | opacity 1→0 |
| **Compass** | 60 | 560 | scale 1→**0.2889** and translate (−136, −71) so its centre lands on the avatar centre (39, 39). Opacity holds at 1 until 60% of the move, then →0 |
| Card height | 60 | 560 | 420→78 |
| Card corner radius | 60 | 560 | 24→20 |
| Avatar (sleeping cat) | 400 | 320 | opacity 0→1, scale 0.85→1 |
| Row title + subtitle | 440 | 300 | opacity 0→1, x −8→0 |
| Chevron | 480 | 260 | opacity 0→1 |

Total ≈ 740 ms. The compass's scale-out into the avatar slot is the hero move; the cat fades in where the ring lands.

## Expand (tap the row)
Play the same timeline **mirrored**: each track's reversed start = 740 − (start + duration), with from/to swapped. In practice: chevron, text and avatar fade out first, the card grows and the ring scales up out of the avatar spot back to centre, then title, body, CTA and Maybe later fade in last (bottom-most last).

## Implementation notes (SwiftUI)
- Build the card as one view whose height animates; use `matchedGeometryEffect` or explicit scale/offset for the compass → avatar move. The numbers above assume the compass anchor is its centre.
- Keep the compass's rotation loop running during the move.
- Disable taps on the prompt buttons once collapse starts, and on the row until it finishes.
- **Reduce Motion:** replace with a 200 ms crossfade plus height change; no scale move.
- Row copy stays the current state's copy (S2 "Compass guide is waiting", or S3 to S6 moonrise copy). Expanding never changes the row's state.
