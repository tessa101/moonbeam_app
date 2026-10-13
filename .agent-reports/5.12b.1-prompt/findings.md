# 5.12b.1 location-off prompt (S1): build + simulator check, 2026-10-13

Spec: `docs/LOCATION-OFF-FLOW.md` §2, §4, §6; design `design/1.9-location-off-flow/README.md` "S1: Prompt".

## What was built

- **Ghosted compass (`CompassGhost`)** is the live `CompassDial` itself, not a new drawing. At its 196 pt design face
  the dial's frame is exactly 260 pt wide (the handoff's 260-unit space), so it's laid out there and scaled to 210 pt.
  The layer is at opacity 0.42 with a 1.2 pt blur. The ring turns by feeding the dial a heading of −rotation, because
  the dial places marks at azimuth − heading.
- **Motion (`CompassGhostMotion`)**: the 12 s table (0 → −70 → hold → 40 → hold → 0), each move eased with
  cubic-bezier(.45, 0, .55, 1). Reduce Motion, the background and off screen show the still 0° frame, decided by
  `LocationIllustration.shouldAnimate` (no paused timeline).
- **Data**: the selected day's rise and set from the card's `MoonDay`, plus the live moon if it's today and up, in new
  `CompassViewModel.ghostTargets` / `ghostArc`. The arc comes from the same `MoonPass` lookup as the live dial, so it
  runs the way the moon goes. With no rise or no set there's only the dot that exists and no arc. The live
  `targets`/`arc` stay empty with location off, so the lock, pulse and pinned bar are unaffected.
- **Copy** in `CompassViewModel`: title "Your moon compass is ready"; body "With location on, you'll see the live
  compass to point your way" (no final period). Maybe later's hint is the spec's.
- **Maybe later**: `.textLink(color: teaserBody)`, which is SemiBold 16, ≥ 44 pt and full width, 4 pt under the CTA.
  It calls `dismissLocationPrompt()`.
- **`locationPromptDismissed`** is in `OnboardingStore` (protocol, UserDefaults, in-memory fake). `CompassViewModel`
  gets the store through its initializer, and `LocationViewModel` passes its own. The flag is cleared on grant (the
  first update with `.authorized`), by Show onboarding (`forceShow`), by Forget saved place, and by
  `-resetOnboarding`. The view model reads the flag back on every `update`, so the DEBUG resets take effect without a
  relaunch.
- **Placeholder row (`CompassGuideRow`)**: "Compass guide is waiting" / "Tap whenever you want directions", hairline
  #3A2E35 border, radius 20, padding 12/16/12/12, "›" in #6E5C66. There's no avatar and no countdown. Tapping it calls
  `reopenLocationPrompt()`, which only lasts this launch.
- **Renamed** `showsLocationOffTeaser` → `showsLocationOffPrompt`. Restricted keeps the chip, with no prompt, row or
  Maybe later.
- **Deleted**: `CompassTeaser.swift`, `CompassTeaserMotion.swift`, `Illustrations.xcassets/compassTeaser/` (6
  imagesets) and `CompassTeaserTests.swift`.
- **New DEBUG states**: `-screenState locationOff.dismissed` (the row) and `locationOff.restricted` (the chip, now
  shown on the real home screen; 5.12 could only show it in a preview).

**Is OnboardingStore the right home?** Yes, it's good enough. It's already the per-install first-run flag store with
an in-memory fake and the DEBUG resets, and this flag is in that family. The one wrinkle is that the compass view
model now depends on a store named for onboarding. If more non-onboarding flags arrive, rename it (e.g.
`FirstRunStore`) rather than add a second store.

## Build and tests

- `xcodebuild build-for-testing` (iPhone 17 sim): succeeded, no new warnings. Rebuilt after the row accessibility fix
  below: succeeded.
- `xcodebuild test-without-building` **hung**, the same sandbox issue as in 5.12: "Pseudo Terminal Setup Error,
  Operation not permitted", so the runner never launched. I stopped it at 10 min.
- Xcode `RunSomeTests` (iPhone 17): CompassLocationPromptTests, OnboardingStoreTests, OnboardingDebugTriggerTests,
  LoaderFlowTests and CompassViewModelTests, **223/223 pass**. The new tests cover gating (restricted off; denied, not
  determined and services off on), store round-trip + DEBUG reset, Maybe later persisting across a relaunch, the row
  reopening S1 without clearing the flag, the flag cleared on grant, read-back after a reset, the ghost data
  (rise+set+arc, rise only = no arc, none when restricted), copy, and the motion table. `forceShow` and
  `forgetSavedPlace` now assert the flag is cleared. The suite has `.timeLimit(.minutes(1))`.
- **Full suite not run.** Run it in Terminal.

## Screenshots (iPhone 17, iOS 27, Debug, dark)

| Shot | What it shows |
|---|---|
| `1-s1-default.png` | `-screenState locationOff` (denied). Ghost mid-turn (ring rotated); fixed needle at 12; rise/set dots, arc and the moon glyph on it; PREVIEW pill sharp over the blur. Title on 1 line, body on 2, then Turn On Location and Maybe later. |
| `2-s1-reduce-motion.png` | Reduce Motion on (set in the Settings UI): north up at 0°. Two captures 3 s apart were byte-identical, so it's still. |
| `3-s1-ax3.png` | AX3 (accessibility-extra-large), scrolled to the prompt. The title wraps, the body runs to 4 lines and the CTA to 2. Art stays 210 pt. No clipping or overlap by hierarchy frames. |
| `4-placeholder-row.png` | `-screenState locationOff.dismissed`: the row in place of S1, no Turn On Location. |
| `5-restricted-chip.png` | `-screenState locationOff.restricted`: the old chip + Turn On Location, with no prompt, row or Maybe later. |

Interaction (AX3, via device interaction): tapping Maybe later showed the row, and tapping the row brought S1 back.

**Found and fixed during the check:** the row was exposed as two nested buttons, one also reading "›". The cause was
an extra `accessibilityElement(children: .ignore)` around the `Button`. Now it's one button labelled "Compass guide is
waiting, Tap whenever you want directions", with its hint and the chevron hidden from VoiceOver. The automation tree
still lists the button's child texts. Confirm with VoiceOver on the phone that it reads as one element.

Simulator state restored afterwards: text size Large, Reduce Motion off.

## Differences from the handoff drawing (please look)

The handoff's S1 art is a simplified ring (#5E4D57 2 pt ring, solid 4 pt amber arc, 6 pt dots, Nunito "N" inside).
Reusing the real dial, as asked, means the ghost shows the live compass's look instead:
- The lit face, ticks, degree numbers and Young Serif N/E/S/W.
- The arc in the live style: dotted. Moon down, it's dimmed to 30% like the live next-pass arc, so at 0.42 it's very
  faint.
- The dial's fixed **needle** is the "static north tick". It's 3 pt and sits from inside the rim to under the arc's
  track, not the handoff's 4 pt line from the top edge.
- Target labels ("↑ Rise" …) are off for the ghost (new `CompassDial.showsTargetLabels`, default true).
- PREVIEW uses the **system monospaced** font (medium, `.caption2` = 11 pt), with tracking 0.12 em. The README says IBM
  Plex Mono is in the app, but it isn't bundled. Adding it means adding a font, so ask first.
- "Today's real rise and set" is the **selected day's**, the one the card shows. On another date the ghost shows that
  date's rise and set, with no moon.

## Not done (out of scope)

Row states S3–S6, avatars, countdown and VoiceOver focus moves (5.12b.2); fades and height transitions (5.12b.3).
The swap is a plain cut.

## Noticed, not touched

At AX3 the madlib's "Date, today" and "Place, Irvine, CA" buttons overlap by ~33 pt in the accessibility frames.
This is the existing header layout (5.5 AX reflow), not part of this change.
