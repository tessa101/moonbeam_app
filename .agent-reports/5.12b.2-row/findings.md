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

## Part 3: 5.12b.2 row UI

- **`CompassGuideRow`** is the real row, built per the handoff "S2 to S6" and §3:
  - layout: padding 12/16/12/12, radius 20, 14 pt gaps, a 52 pt avatar clipped to a circle, two lines, and a "›"
  - S2: #3A2E35 border, no fill, #6E5C66 chevron, subtitle Regular 13 in #B9A898
  - S3–S6: #4A3A2E border, #211A1F fill (new `guideRowActiveBorder`/`guideRowActiveFill`), accent chevron, subtitle
    SemiBold 13 in accent (new `guideRowSubtitleActive`)
  - titles: SemiBold 16 in #F5EADB
- **Avatars:** the prepared PNGs, copied as-is (52/104/156 px) into `Illustrations.xcassets/locationGuide/
  avatar_sleeping|avatar_searching.imageset` with Original rendering. Sleeping for S2, searching for S3–S6. No SVGs.
  They're drawn with `Image(decorative:)`, because the AX3 check found `Image(_:)` exposing the asset name
  "avatar_searching" in the tree.
- **Accessibility:** one button, labelled with the title and subtitle, hint "Shows the moon compass preview.", and the
  chevron hidden. Text wraps at AX sizes. Tapping still calls `reopenLocationPrompt()`, which isn't persisted.
- **Copy:** the row's text now comes from `CompassViewModel.guideRow` (the formatter). The placeholder statics
  `guideRowTitle`/`Subtitle`/`Hint` are removed from the view model.
- **DEBUG states** `-screenState locationGuide.s2 … .s6` run on the fixture's fixed 7:53 AM clock, after Maybe later:
  S2 next rise in 5 h, S3 in 2 hr 15 min, S4 in 40 min, S5 rose 5 min ago, S6 up since last night.
- Tests: LocationOffGuideTests, CompassLocationPromptTests, CompassViewModelTests, UpNowFormatterTests and
  LoaderFlowTests, **251/251 pass** (Xcode, before the one-line decorative-image change, which was then rebuilt).

| Shot | What it shows |
|---|---|
| `1-row-s2.png` | S2: quiet row, sleeping cat, "Compass guide is waiting / Tap whenever you want directions". |
| `2-row-s3.png` | S3: warm row, awake cat, "Moonrise in 2 hr 15 min / Want her to show you where?". |
| `3-row-s4.png` | S4: "Moonrise in 40 min". The card's guidance reads "Up at 8:33 AM" (7:53 + 40), so they agree. |
| `4-row-s5.png` | S5: "The moon is rising now". |
| `5-row-s6.png` | S6: "The moon is up now". |
| `6-row-s4-ax3.png` | S4 at AX3: title and subtitle each wrap to 2 lines, no truncation; avatar 52 pt; chevron centred. Tapping the row brought S1 back (checked by device interaction). |

Simulator restored afterwards: text size Large.

## Notes / open

- **The fixture's card moonrise doesn't match S3/S4.** The DEBUG states move the next rise but not the fake table's
  moonrise, so the card's Moonrise column still says 11:10 PM. That's only in the fixture: in the app, the card and
  the row both come from the moon service.
- **The VoiceOver focus moves in §3.3** (Maybe later → the row, row → S1's body) aren't built. They belong with the
  swap transitions in 5.12b.3.
- **The automation tree still lists the button's child texts** (the "›" and both lines) under the single button. The
  button has its own label, so VoiceOver should read it as one element, but check on the phone.
- The countdown is the handoff's "2 hr 15 min". The card says "in 2h 15m" (§7, open). Switching is one function,
  `LocationOffGuideFormatter.countdown(minutes:)`.
- Full suite not run (sandbox PTY): run it in Terminal.
