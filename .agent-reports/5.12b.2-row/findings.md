# 5.12b.1b + 5.12b.2: findings, 2026-10-13

Spec: DECISIONS.md 2026-10-13 "5.12b.1b" and "5.12b"; `docs/LOCATION-OFF-FLOW.md` §2, §3, §4, §8.

## Part 1: 5.12b.1b S1 polish

- **PREVIEW** is a plain word: no fill or border. It's Nunito Sans SemiBold 11, caps, 0.12 em, in `dialNumber`
  (#A8939C), centred over the ring, hidden from VoiceOver (with the art), and capped at `.xxxLarge`.
  `previewPillBorder` is removed.
- **No title.** S1 is the ghost, the body, Turn On Location and Maybe later. The art is hidden from VoiceOver, so the
  body is read first. `locationPromptTitle` and the `teaserTitle` font tokens are removed (nothing else used them).
- **Arc direction** follows the sky. `CompassGhostGeometry` takes `crossesSouth` (`latitude >= 0`): at or north of
  the equator it runs clockwise via the south, and south of the equator anticlockwise via the north. Tested with
  Sydney (−33.87°): 60° → 300° passes due north and never the south.
- **No rise and no set:** no moon marker, even with the moon up (ring, N and tick only). Tested.
- Tests: CompassLocationPromptTests + CompassViewModelTests **136/136 pass** (Xcode).
- `0-s1-polish.png`: `-screenState locationOff.moonDown`, mid-turn, showing the gray PREVIEW and the body with no title.

## Part 2: 5.12b.2 guide logic (no UI)

- **`LocationOffGuide`** (pure enum, `Features/Compass/LocationOffGuide.swift`) has the cases `.waiting` (S2),
  `.moonriseIn(minutes:)` (S3 at 60 min or more, S4 at 1–59), `.rising` (S5) and `.up` (S6), plus `stage` and
  `isActive`. The rules follow §3.1:
  - any date but today is S2
  - moon down: a rise within 3 h (at most 180 rounded-up minutes) is S3/S4; under a minute away, or just past while
    the moon still reads down, is S5; otherwise, or with no rise, S2
  - moon up: S5 until 15 min after this pass's rise, then S6; up with no pass found is S6
- **Agreement with the card:**
  - **Up/down** is `MoonPosition.isUp`, the compass's 5.11 rule.
  - **This pass's rise** is `MoonPass.rise.date`, the date `UpNow.Pass.riseTime` formats. I didn't use the
    `TimeText` itself: it's display text, and with location off there's no `UpNow`, because the card's Up now only
    exists with the compass shown.
  - **Minutes** come from the card's rounding, moved into a shared `UpNowFormatter.countdownMinutes(until:from:)`.
    The card's own countdown now calls it too, and a test pins both to 100 min / "in 1h 40m".
- **Next rise** comes from `nextMoonrise(after:)`, so it can be after midnight. It's cached the way the card caches it:
  looked up again only once a minute past.
- **`LocationOffGuideFormatter`** holds the titles and subtitles, the hint and the label. The countdown wording is only
  in `countdown(minutes:)` ("2 hr 15 min", "2 hr", "40 min"), so switching to "2h 15m" is one function.
- **Tick:** `CompassViewModel.locationGuide` is recomputed in `rebuildTargets()`. While the sensors are off, the 60 s
  guidance clock that keeps the card's guidance line current calls that. So the row uses the card's existing clock and
  adds no new timer.
- Tests: `LocationOffGuideTests` (16) cover S2–S6 and every boundary (3 h and 3 h + 1 s; 60, 59 and 59.5 min; 1 min
  and 59 s; rise + 15 min − 1 s and + 15 min), up since last night, after moonset, another date, 10:30 PM → 12:20 AM
  = "1 hr 50 min", the format and wording, and the view model (down, up/rising, restricted). With
  CompassLocationPromptTests, CompassViewModelTests and UpNowFormatterTests: **175/175 pass**.
