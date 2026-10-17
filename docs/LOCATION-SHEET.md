# Location Sheet: restyle of the compact Location Off dialog

**Status:** Built (`bcff3ac`) and accepted 2026-10-13 · **Decided:** 2026-10-13 · **Owner:** Tessa
**Item:** 5.12a
**Design reference:** Claude Design artboard "Moon Signal Location Sheet v2" (three causes, specs card)

---

## 1. Scope

Restyle `LocationOffDialog.swift`, the compact sheet that opens from the compass ("Turn On Location") and the paths that still use it. Today it is the functional version: plain headline, bold path line, default buttons, `[.medium, .large]` detents.

STEP-5.10a-LOCATION-CONSOLIDATION.md said "Do not redesign the dialog in this pass." That pass is implemented; this is the follow-up.

**In scope:** layout, type, color, detent, dismissal, secondary-button title.
**Out of scope:** the illustrated failure screens, routing, cause copy and Settings paths, the compass teaser, the telescope redraw. Don't touch `LocationFailure+Copy.swift` values, `IllustrationSpec`, `CompassTeaser*`, or anything under `design/1.7*` / `design/1.8*`.

## 2. Contract: words and actions don't change

Everything on the sheet still comes from `variant.failure.copy` (`LocationFailure+Copy.swift`): headline, body, `pathChipLines`, `primaryTitle`, and the Settings/search actions. For reference:

| | Denied | Services off | Restricted |
|---|---|---|---|
| Title | Can’t see your location | Location Services are off | Can’t see your location |
| Body | Allow location access to see where the moon is from here. | Turn them on to see where the moon is from here. | Location access is limited on this iPhone. You can still search for a city. |
| Path | Settings › Moon Signal › Location | Back to Settings › Privacy & Security › Location Services | none |
| Primary | Open Settings | Open Settings | Search for a city |
| Secondary | Search for a city instead | Search for a city instead | none |

**One copy change, to remove a fork:** the dialog hard-codes `"Search instead"` for its secondary. Use the shared `LocationFailure.searchInsteadTitle` ("Search for a city instead") like the failure screens. Update any test that asserts the old title.

The path stays one pointer, not numbered steps. Chunk 2b decided any choice but Never works, so there is no "Choose While Using the App" step.

## 3. Layout (per artboard)

- Floating sheet, 8 pt inset, 40 pt corners, height fits content, nothing empty below the actions. Scrim 50% black.
- Grabber 36×5 pt, 6 pt from top. Close button 30 pt visual, 44 pt target (`Theme.Metrics.minimumHitTarget`), top-right, label "Close".
- 24 pt side padding, 8 pt grid. Title Young Serif 24/30 (`Theme.Fonts.display`, 24 pt), body 17/24, path 15/20 Nunito Sans Bold.
- Path sits in an inset group: 20 pt radius, 16 pt padding, 52 pt min height. It should read as a pointer, not a third action. Restricted has no path, so no group.
- Primary: 52 pt filled pill, full width. Secondary: 48 pt outlined pill (1 pt accent at 40%, accent text), 8 pt below. 24 pt above the primary. Both clear the home indicator by 34 pt.
- Tokens, not hexes: sheet `surfaceRaised`, path group `surface`, primary `accent` on `onAccent`, title `textPrimary`, body `textSecondary`, path `textBody`. Reuse the accent pill style from the failure screens if it is within 4 pt of these sizes.

## 4. Behavior

- Detent fits measured content height (`.height(...)`, or a preference-key measurement); `.presentationDragIndicator(.visible)`. Keep the `ScrollView` so large text scrolls past the largest detent.
- On iOS 26 the system sheet already floats with inset and rounded corners. Check it matches §3 instead of hand-drawing one. If it doesn't, report the difference and stop before faking it.
- Dismiss: grabber swipe, close button, or tapping outside. All three just dismiss, as today (`locationOffDialogDidDismiss`).
- Search for a city instead: unchanged (`searchInsteadOfLocation`, reopens search once the sheet has gone).
- Open Settings: unchanged, including the auto-fetch when access is granted on return.
- Dynamic Type: title and path wrap, never truncate.

## 5. Acceptance criteria

- [ ] Denied, services-off and restricted render per §3 on iPhone 17 and iPhone SE (3rd generation)
- [ ] No clipped or overlapping text at default size and at AX3
- [ ] Copy matches the shared definitions; the secondary reads "Search for a city instead"
- [ ] Grabber swipe, close button and outside tap each dismiss
- [ ] Search and Open Settings behave exactly as before; existing `LocationViewModel*` and `CompassViewModel*` tests pass
- [ ] VoiceOver order: title, body, path, primary, secondary, Close (path keeps `pathChipAccessibilityLabel`)
- [ ] Screenshots of the three variants (default type, AX3) in `.agent-reports/5.12a-location-sheet/`

## 6. Resolved items (2026-10-13)

- Close button: kept, as in the mock.
- Button heights: primary uses the failure screens' 56 pt `.primary` style (within the 4 pt allowance); secondary is a new 48 pt `.outlined` style (`Theme/OutlinedButtonStyle.swift`).
- "Search for a city instead" stays secondary; not promoted to equal weight.

Follow-ups outside this item: the full test suite is still to run in Terminal; at AX3 the madlib sentence behind the sheet overlaps itself (5.5 AX reflow).

## 7. Agent prompt

> Build 5.12a, the location sheet restyle, per `docs/LOCATION-SHEET.md` (§1–§5). Layout and style of `LocationOffDialog` only; copy and actions stay on the shared `LocationFailure` definitions, apart from the secondary title in §2. Don't touch the compass teaser, telescope art, or `LocationFailure+Copy.swift` values. Findings + screenshots: `.agent-reports/5.12a-location-sheet/`. Before changing anything, screenshot the current dialog in all three variants and list the differences from the spec. Add a DECISIONS entry and update latest.md. One commit. Run the focused `LocationViewModel*` / `CompassViewModel*` tests, then install a Debug build on the T2 iPhone. Stop there.

## 8. Interaction with the onboarding rework (2026-10-16)

This sheet is unchanged. It stays the post-onboarding surface (compass "Turn On Location" and the failure paths). In the first-run `noCity` state, an OS-level denial does not open this sheet: the main screen's CTA becomes "Open Settings" instead (see [ONBOARDING-MOD-MAIN.md](ONBOARDING-MOD-MAIN.md)). "Search for a city instead" here still reopens search; if no city has been set when search closes, the app lands on `noCity`.
