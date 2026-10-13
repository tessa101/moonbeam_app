# 5.12a location sheet restyle: findings (2026-10-13)

Spec: `docs/LOCATION-SHEET.md` §1–§5. Simulators: iPhone 17 and "SE3 fit check" (iPhone SE 3rd gen), iOS 27.0.

## How the captures were made

The dialog only opens from a tap on the compass teaser, and restricted can't be set on the simulator. So the first
change (before touching the dialog) was three DEBUG-only screen states that open the real sheet over the saved
Irvine: `-screenState locationOffDialog.denied | .servicesOff | .restricted`. `before/` was captured with those states
and the **unchanged** dialog; `after/` with the restyle. Both sets were captured on iPhone 17 and SE 3. "Before" AX3 is
iPhone 17 only; "after" AX3 is both devices.

## Before: differences from the spec (`before/`)

| | Before (functional) | Spec §2–§4 |
|---|---|---|
| Detent | `[.medium, .large]`: half the screen, mostly empty under the actions | One `.height` detent fitting the content, nothing empty below |
| Fill | System Liquid Glass (translucent, art shows through) | `surfaceRaised` |
| Grabber | System, shown (multi-detent default) | Visible (`.presentationDragIndicator(.visible)`) |
| Close button | None | 30 pt visual / 44 pt target, top-right, "Close" |
| Title | System `.headline` (SF, 17 semibold) | Young Serif 24/30, `textPrimary` |
| Body | System body, default colour | Nunito Sans 17/24, `textSecondary` |
| Path | Bold system text line | Nunito Sans Bold 15/20 `textBody` in a 20 pt-radius `surface` group, 16 pt padding, 52 pt min |
| Primary | Plain text button | 52 pt filled `accent` pill, `onAccent` text, full width |
| Secondary | Plain text "Search instead" | 48 pt outlined pill (accent 40%), accent text, "Search for a city instead" |
| Spacing | `.padding()` (16), 16 pt between all rows | 24 pt sides, 8 pt grid, 24 pt above primary, 8 pt between buttons |
| AX3 | Actions below the medium detent; the sheet must be dragged up to reach them | Sheet grows to fit; ScrollView scrolls past the largest detent |
| Floating / inset / corners / scrim | Already system: 8 pt inset, ~35–40 pt corners, ~50% dim | 8 pt inset, 40 pt corners, 50% black |

Spec wording nits (no code impact): §3 names `Theme.Layout.minimumHitTarget` and `Theme.Typography.display`; the
tokens are `Theme.Metrics.minimumHitTarget` and `Theme.Fonts.display`.

## §4 system-sheet check: matches, not hand-drawn

Measured on the before captures (pixel scan):

- Side inset 8.0 pt (iPhone 17 and SE 3); bottom gap ≈ 8 pt. Matches §3.
- Scrim: app `bg` #1B1519 reads #0E0B0D outside the sheet, ≈ 52% darker. Matches 50% black.
- Corners: system concentric radius, roughly 35–40 pt by scan (a continuous curve, so the scan can only estimate
  it). Not exactly a set 40 pt, but it's the system shape and can't be set without hand-drawing. Accepted as matching.
- Floats on the SE 3 too (no home indicator): same 8 pt inset.

So the dialog keeps the system sheet and sets only `presentationBackground(surfaceRaised)`, a fitted detent and the
visible grabber. Nothing is faked.

## After (`after/`)

- **Layout:** as §3 on both devices, all three variants. Restricted has no path group and one button.
- **Primary** reuses the failure screens' `.primary` style (56 pt, within 4 pt of 52, as §3 allows). **Secondary** is
  a new `.outlined` style (`Theme/OutlinedButtonStyle.swift`, 48 pt). The existing `.secondary` style is a filled
  `surfaceRaised` pill with `textPrimary` text, not the outlined accent pill §3 asks for.
- **Home indicator:** the floating sheet adds its own bottom safe area on Face ID iPhones (about 30 pt on iPhone 17)
  and none on the SE. A fixed 34 pt pad gave about 66 pt under the buttons on iPhone 17, so the 34 pt now *includes*
  the sheet's safe area (`max(0, 34 − safe area)`). That's 34 pt under the last action on both devices.
- **AX3:** title, body and path wrap with no clipping, overlap or truncation. On iPhone 17 everything fits at the
  largest height. On SE 3 the sheet reaches its largest detent and the secondary scrolls into view, per §4. Buttons
  scale with Dynamic Type (not pinned like the failure screen's).
- **Interactions** (iPhone 17, device-interaction subagent, `after/interaction-*.png`): Close ✓, outside tap ✓,
  grabber swipe ✓ each dismiss; "Search for a city instead" closes the sheet, then search opens ✓. Open Settings was not
  tapped (it leaves the app). Its code path is unchanged: `openURL` then `onOpenedSettings`, and the auto-fetch on
  return is covered by `LocationViewModelTests`.
- **VoiceOver order** (hierarchy dump): system grabber, title (header), body, path ("Settings, Moon Signal,
  Location" from `pathChipAccessibilityLabel`), Open Settings, Search for a city instead, Close. Matches §5. The
  path is one element (`children: .ignore`). The dump still lists the inner text, so check on the phone with
  VoiceOver that it isn't read twice.

## Tests

Xcode RunSomeTests on iPhone 17: LocationViewModelTests, LocationViewModelCompassTests, LocationViewModelDayTests,
OnboardingMainScreenTests (`LocationViewModelOnboardingTests.swift`), CompassViewModelTests: **216/216 cases pass**.
No test asserted "Search instead", so no test needed changing. Full suite not run.

## Not done / open

- Light mode contrast: not checked. The app is forced dark (Info.plist), so there's no light sheet.
- §6 open items untouched: Close button kept, 56 pt primary (token) with 48 pt outlined secondary, search not
  promoted.
- Pre-existing, out of scope: at AX3 the madlib sentence behind the sheet overlaps itself ("the moon" / "I find"
  collide, `before/iphone17-servicesOff-ax3.png`). That's 5.5 territory.
