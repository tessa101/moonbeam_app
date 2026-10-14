# 5.12b.3a "One container": findings, 2026-10-13

Spec: DECISIONS.md 2026-10-13 "5.12b.3"; `docs/LOCATION-OFF-FLOW.md` §5.3–§5.5; design
`design/1.9-location-off-flow/TRANSITION.md` + `Location Off Transitions.dc.html` (option 1d).

## Part 1: S1 inside the card (static)

- **`LocationOffCard`** (new) is the one container for both states.
  - The card: full width inside the 20 pt margins, 1 pt border #3A2E35 (`guideRowBorder`), no fill, content clipped,
    corners 24 expanded and 20 collapsed.
  - Collapsed, the card *is* the row: one border. The row's warm look (S3–S6: #211A1F fill, #4A3A2E border) is now
    the card's.
  - `CompassGuideRow` is now the row's content only (avatar, text, chevron, the one button). It sits 1 pt inside the
    card's border, so the avatar is at (13, 13) and the row is 78 pt.
- **Expanded:** ghost at **180 pt** (`CompassGhost.artSize`, was 210), centred, 20 pt from the top. Then the body 12 pt
  under the ring (no title), Turn On Location 14 pt under the body (20 pt in from each side), Maybe later 4 pt under
  that, and 12 pt to the bottom. The height is the content's own.
- **Measured** (iPhone 17, default size, from the border pixels in `1-s1-card.png`): expanded card **381 pt**
  (441.7 → 823.0), collapsed **78 pt** (441.7 → 519.7). The spec expected about 386 expanded. The 5 pt difference is
  our Turn On Location (`.secondary`, `Theme.Metrics.secondaryButtonHeight`) being a little shorter than the mock's
  56 and the body's real line height. I didn't pad it out to 386.
- `CompassView` shows the card wherever `showsLocationOffPrompt`, with `isCollapsed = showsLocationGuideRow`.
  Restricted keeps the chip. The dismissed flag, tap-to-reopen and S2–S6 are unchanged (tests below).
- Tests: LocationOffGuideTests, CompassLocationPromptTests and CompassViewModelTests, **152/152 pass** (Xcode).

| Shot | What it shows |
|---|---|
| `1-s1-card.png` | S1 in the card (`locationOff.moonDown`), default size. |
| `2-s1-card-ax3.png` | S1 in the card at AX3, scrolled: the whole card fits (borders y ≈ 185–800). Body, CTA (2 lines) and Maybe later aren't clipped or overlapping; gaps 14 and 4 by hierarchy frames. |
| `3-row-s4.png` | The collapsed card as the S4 row (one border, warm fill). |

At AX3 a tap round trip (Maybe later → one row button → tap → S1) works. That row read "Moonrise in 34 min" because
`locationOff.moonDown`'s fixture puts the next rise 34 min out.

## Part 2 "before": the swap as a plain cut

`before.mov` (simulator recording, variable rate up to 60 fps) was resampled to a constant 60 fps with ffmpeg. I then
diffed each frame against the one before it over the card's lower part (y 640–830 pt, below the turning ring) with
`/tmp/swapframes.py` (copied below as `swapframes.py`):

- **S1 → row (Maybe later): one frame.** Frame 1035 (17.250 s) is the only changed frame, with a mean change of 7.9.
- **Row → S1 (tap the row): one frame.** Frame 1751 (29.183 s), mean change 7.9.
- No other frame changed in that region. Both swaps are hard cuts. `before-frames/f1034|f1035.png` and
  `f1750|f1751.png` show the frame before and after each cut.

## Part 2: one-clock transition

- `LocationOffCardMotion` is the pure timing table and evaluator. All nine tracks use
  `cubic-bezier(0.32, 0.72, 0, 1)`; collapse is 740 ms and expand mirrors it. The title track is absent.
- One `TimelineView` drives the card. The measured heights (381 / 76 pt) and corner radii (24 / 20) share the card
  track. The DEBUG readout follows the changing layout height.
- The ring scales from 1 to 52/180 and travels between measured centres. On the iPhone 17 run the real vector was
  approximately **(-142.0, -71.3) pt**, rather than the mock's `(-136, -71)`.
- The hidden ghost is stopped in the settled row; screenshots ten seconds apart are byte-identical. Prompt/row hit
  testing is off during the run and returns at the destination.
- Reduce Motion runs all fades and the height over 200 ms, without scale, travel or offsets.
- VoiceOver hierarchy checks pass: only the destination layer is exposed in flight.
- Focused motion/phase tests: **14/14 pass**. Xcode build passes.

### Visual-capture limitation

The Xcode interaction API has no recorder, and sandboxed `simctl io recordVideo` cannot connect to CoreSimulatorService,
so the requested after-video/constant-60-fps extraction could not be produced. Screenshot sampling shows the direct
card geometry and accessibility hierarchy staying at `y ≈ 442`, and the pure evaluator has no 60 fps discontinuity.
However, delayed screenshots around +1 s sometimes capture the enclosing ScrollView's presentation layer at
`y ≈ 218` before it returns, while the hierarchy remains at `y ≈ 442`. The investigation is in
`after/DEVICE-VERIFICATION.md`; this discrepancy is recorded rather than represented as passing video evidence.
