# 5.12 location-off teaser (option 1b): build + simulator check, 2026-10-12

## Build and tests

- **First build:** the app target compiled as written. The test target failed with 3 errors: `CompassTeaserTests`
  read `CompassViewModel.locationOffTeaserTitle`/`Body` and called `showsLocationOffTeaser(for:)`, which are
  main-actor isolated, from a nonisolated suite.
- **Fix:** `@MainActor` on the suite, as `CompassViewModelTests` does. No change to geometry, copy or motion.
- `build-for-testing` (iPhone 17 sim) passes, again after the preview below was added.
- `CompassTeaserTests`: **10/10 pass**. `CompassViewModelTests`: **112/112 pass** (Xcode, iPhone 17).
- **The full suite did not complete.** `xcodebuild test` hung because the sandbox blocked the runner's pseudo
  terminal ("Operation not permitted"), so the runner never launched; it was stopped at 10 min. Xcode's
  `RunAllTests` then ran from about 16:16 to 17:50 and ended with "result bundle incomplete". Another agent was
  using the same Xcode for the telescope work at the time. The tool call couldn't be stopped at 10 min. Run the
  full suite from Terminal:

      xcodebuild test -project moonbeam-app/moonbeam-app.xcodeproj -scheme moonbeam-app \
        -destination 'platform=iOS Simulator,name=iPhone 17'

## Simulator (iPhone 17, iOS 27, Debug, `-screenState locationOff` = denied)

| Shot | What it shows |
|---|---|
| `1-teaser.png` | Teaser in place of the chip, between the card and **Turn On Location**. Art 180 pt; title on one line; body on two lines. Measured gap from teaser to button: 21.9 pt (spec 22). Animation running (needle mid-hunt in an earlier capture, on the moon in this one). |
| `2-restricted.png` | **Xcode preview, not the running app** (new `CompassView` preview "Location off, restricted"). The old chip "Turn on location to use the compass." stays above the unchanged button. |
| `3-reduce-motion.png` | Reduce Motion on: settled frame (needle 62° on the moon, glow lit, full size). Three captures over 3.3 s were byte-identical, so it is still. |
| `4-ax3.png` | AX3 (accessibility-extra-large), Reduce Motion still on, scrolled to the teaser. Title wraps to 2 lines, body to 4, button label to 2; nothing clips or overlaps. The art stays 180 pt. |

## Notes

- **Restricted on the real home screen isn't reachable in Debug.** `-screenState messageRestricted` and
  `locationFailed.restricted` both open the "Can't see your location" failure screen, and the Debug search fake has no
  cities, so you can't pick one there. That's why `2-restricted.png` is a preview. `restrictedKeepsNote` and
  `hintWhenNotAuthorized(.restricted)` cover the logic.
- **Restricted keeps the chip** is still the handoff's assumption **to confirm** with design (DECISIONS 2026-10-12).
- The handoff README lists `assets/compass/` (layered SVGs + `preview.html`), but `design/1.8-location-off-teaser/` has
  only `assets/anim/`. The six layers are already in `Illustrations.xcassets/compassTeaser`, so nothing is blocked.
- **VoiceOver:** the hierarchy shows one combined element, "Point your phone at the moon, With location on, …", with the
  layer images nested inside it. I didn't check whether VoiceOver ever stops on an image. Check with VoiceOver on the phone.
- **Simulator state:** Reduce Motion was turned on in Settings, then back off; text size is back to Large. To set Reduce
  Motion on the simulator, use the Settings UI: `simctl spawn … defaults write com.apple.Accessibility
  ReduceMotionEnabled` had no effect. My first teaser shot went to the "SE3 fit check" simulator by mistake (two were
  booted), and I deleted it. On that simulator I set appearance to dark and text size to Large.
