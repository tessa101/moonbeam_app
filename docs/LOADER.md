# Step 5.9 Spec: Launch loader

> Source: Claude Design `design/1.1/Moon Signal Loader.dc.html` (concepts 1a Phase cycle, 1b Moonrise,
> 1c Orbit + skeleton, plus shared timing). Replaces the stock `ProgressView` "Finding your location…" launch
> state (DESIGN-REVIEW.md, Location screen, "Launch loading state" bug, 2026-10-01).
> Owner: Tessa · _Decided 2026-10-02_ · **Build after 5.4.6** (the skeleton copies the final main-screen layout)

Items marked **(proposed)** are Cowork defaults; Tessa confirms or changes them before the agent builds.

---

## 1. When the loader runs

Only while the **launch location fetch** is in progress (authorized, LOCATION.md §3, up to 10 s). Moon data is
computed on the device and is effectively instant, so the fetch is the only wait.

- **No fetch, no loader:** location not determined / denied / off → straight to the last-viewed place or the empty
  first-launch state, as now (with the soft fade, §2.1).
- **Onboarding:** after Allow, the same rules apply to the first fetch.
- **Applies to new and returning users alike.** The loader never shows the last-viewed place (§3).

## 2. Three tiers, by how long the fetch takes

| Fetch takes | What shows |
|---|---|
| **Under 400 ms** | No loader. The main screen **fades in softly** (§2.1). |
| **400 ms – 2 s** | **Skeleton** of the main screen (from 1c), city included (§3). |
| **Over 2 s** | **Phase cycle** (1a): the skeleton cross-fades to the moon running through its phases, "Finding your location…" (§4). |
| **10 s** | Fetch times out: as LOCATION.md (last-viewed place if any, else the empty state with the failed-fetch note). |

### 2.1 Transitions **(proposed values)**
- **Main screen in (under 400 ms):** opacity 0 → 1 over 250 ms, ease-out. No slide.
- **Skeleton → real screen:** the layout is the same, so placeholder bars cross-fade to the real text in place,
  250 ms. Nothing moves.
- **Skeleton → phase cycle (at 2 s):** cross-fade, 300 ms.
- **Phase cycle → real screen:** once the phase cycle shows, keep it **at least 700 ms**, then fade to the main
  screen over 250 ms (the design's rule), so it never flashes.
- **Reduce Motion:** all cross-fades stay (opacity only is fine under Reduce Motion); no shimmer, no phase
  animation (§3, §4).
- Transitions are polished app-wide later (DESIGN-REVIEW.md "Motion and feedback"); use these until then.

## 3. Skeleton (400 ms – 2 s)

The main screen's real layout with placeholders, so the change to real content doesn't shift anything.

- **Sentence:** the plain words are real; **both tokens are skeleton bars**, the date and the city. We don't
  know the location yet, so the city can't be shown, and the date depends on the place's calendar.
  - **Supersedes LOCATION.md §89** ("show the last-viewed place's name as a placeholder"): the loader never shows
    the last-viewed name, for new or returning users.
  - The bars sit where the tokens go, at token height, in `surfaceRaised`, radius 6. **(proposed)** City bar about
    the width of "Los Angeles, CA".
- **Moon card:** real labels ("↑ Moonrise", "↓ Moonset"), flat placeholder bars for the date, phase, times,
  directions and the Up now row. ‹ › hidden **(proposed)**. Same card size as the real one.
- **Compass:** the dial face with its ticks at the real position and size; no readout, no needle, no targets.
  **(proposed)** No orbiting moon: the phase cycle takes over long waits, so the skeleton stays quiet.
- **Shimmer:** one slow sweep across the bars (1.8 s, `textPrimary` 6% at its peak), as in the 1c mock.
  Reduce Motion: no shimmer, the bars are static.
- **"Finding your location…"** (footnote, `textSecondary`) between the card and the dial.
- Not interactive: tokens, ‹ › and the dial don't respond.

## 4. Phase cycle (over 2 s)

Concept 1a, the onboarding moon.

- Centred moon glyph, **140 pt**, its lit fraction running through a full month every **4.8 s**, smooth ease,
  never settling on a "done" shape. Glow behind it breathes on the same 4.8 s loop (`accent` 32% radial).
- "Finding your location…" under it (`textSecondary`, body).
- No sentence, card or compass: a clean screen (the design's "first run" state, used for everyone).
- **Reduce Motion:** the glyph holds still at full; only the glow fades slowly.
- Same glyph code as the card and onboarding (`PhaseGlyph`), driven by an animated lit fraction.

## 5. Accessibility

- VoiceOver announces **"Finding your location"** once, when the skeleton or phase cycle first appears (not again
  at the 2 s switch). The skeleton's bars are hidden from VoiceOver.
- When the real screen arrives, focus goes to the sentence header.
- AX sizes: the skeleton follows the 5.5 reflow when that's built; the phase cycle's text scales and wraps.

## 6. Also fixes

- The DEBUG compass readout never shows during loading.
- The Show onboarding button (TestFlight/DEBUG) is hidden during loading.
- No "a city" token while locating.

## 7. Not in this step

- Concept 1b (Moonrise): not used.
- 1c's orbiting moon settling onto a rise/set dot: not used.
- App-wide transition polish (DESIGN-REVIEW.md "Motion and feedback").

## 8. Tests

- Tier selection on a fake clock and fake location service: fix at 300 ms → no loader, main screen fade;
  at 1 s → skeleton, no phase cycle; at 3 s → skeleton, then phase cycle at 2 s; phase cycle shown at least 700 ms
  even when the fix lands right after the switch
- 10 s timeout → last-viewed place or empty state, as LOCATION.md
- No fetch (denied / not determined / off) → no loader
- The skeleton never contains the last-viewed place's name
- VoiceOver announcement fires once per launch
- Reduce Motion: no shimmer, no phase animation

## Decision log

- **2026-10-02 (Tessa):** Loader by wait time: under 400 ms no loader, the screen loads in softly; about 1–2 s, the
  1c skeleton, with the **city as a skeleton too** (location unknown, so no last-viewed placeholder); longer, the
  **1a phase cycle**, for new and returning users. Built after 5.4.6 as Step 5.9. Transitions everywhere get a
  polish pass later.
