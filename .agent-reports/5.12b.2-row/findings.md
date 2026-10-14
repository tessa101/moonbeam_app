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
