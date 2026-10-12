# Location consolidation: automated simulator review

October 12, 2026. Tessa authorized simulator execution, overriding build-for-testing-only. Stop immediately on pseudo-terminal or CoreSimulator errors remains in force. No physical-phone checks are declared complete by this review.

## Completed evidence

- Real simulator access, boot, installation, launch, PNG capture and continuous H.264 recording all work with host access. No simulator was erased.
- iPhone 17 / iOS 27: all four causes captured at launch and after explicit acquisition. Settled copy, actions, chips and positions match. Animated artwork differs by frame as expected.
- iPhone 17 AX3: all four messages fit; artwork shrinks; actions stay visible.
- SE3 fit-check simulator / iOS 27: all four causes fit at default text size. At AX3 the body/path require scrolling, matching the existing deferred issue; the actions remain visible. No accessibility redesign performed.
- Light system appearance was exercised. The app stays dark by its existing `UIUserInterfaceStyle=Dark` setting; this is not a separate light app theme.
- Native Device Hub actions: telescope search opens the sheet; its location row returns to the telescope without a compact dialog. No fix search opens and cancelling preserves No fix.
- Actual continuous recovery video captures show No fix → searching → Aha → main. Normal motion preserves the ride/flight. Reduce Motion skips those motions. Settings’ Reduce Motion switch was enabled for review and restored to its original off state; capture script restores appearance/text size.

## Bug found and corrected

The before video at approximately 3.5 seconds shows the departing searching moon over the incoming No fix headline. FailureLoadIn started the headline after 0.15 seconds while the loader's opacity exit took 0.3 seconds. Settled screenshots and view-model tests could not catch it.

`finishLoader` now marks whether a failure follows a visible loader. The shared failure entrance adds one existing stagger beat to its text/actions only in that case, so the headline starts when `ContentLoadIn.duration` has elapsed. The illustration still crossfades immediately; direct blocked entrances retain their old timing. No new duration or animation curve was introduced.

Temporal tests assert the headline cannot begin during the outgoing loader fade, with and without a path chip. Existing flow tests verify attempted failure carries the handoff flag and direct denied launch does not. Build-for-testing passed. After recordings in normal and Reduce Motion show loader-only → illustration with departing moon → headline after moon removal. Sampled details are checked at 10 frames/second; the source movies remain available for continuous review.

## Local artifacts and repeatable capture

Evidence lives in `.agent-reports/5.10a-simulator-review/` (local, not all images committed):

- `iphone17-dark/paired-contact-sheet.jpg`
- `iphone17-light/`, `iphone17-ax3/contact-sheet.jpg`
- `se3-default/contact-sheet.jpg`, `se3-ax3/contact-sheet.jpg`
- `reduce-motion/recoveryAha-continuous.mp4` (before)
- `reduce-motion-fixed/handoff-detail.jpg` and movie (after)
- `normal-motion-fixed/handoff-detail.jpg` and movie (after)

`scripts/review_location_simulator.py` captures an already-booted simulator with an installed DEBUG build. It does not erase/reset permissions, run tests, or retry errors. The `--record recoveryAha` option records an actual simulator stream, not reconstructed stills. `scripts/run_xcodebuild_guarded.py` monitors build/test output, stops the process group on PTY/CoreSimulator errors and limits runs to ten minutes.

## Repeat a review

Use a fresh output directory, an already-booted simulator UUID, and the installed DEBUG build. Host access is required; permission/environment errors must stop the run rather than trigger retries.

```sh
python3 scripts/review_location_simulator.py --device UUID --output OUTPUT_DIR
python3 scripts/review_location_simulator.py --device UUID --output NEW_OUTPUT_DIR --text-size accessibility-extra-large --launch-only
python3 scripts/review_location_simulator.py --device UUID --output VIDEO_DIR --record recoveryAha
```

To run the full suite with the guard after a successful build-for-testing:

```sh
python3 scripts/run_xcodebuild_guarded.py --log TEST_LOG -- test-without-building \
  -project moonbeam-app/moonbeam-app.xcodeproj -scheme moonbeam-app \
  -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mb-dd \
  -parallel-testing-enabled NO
```

These commands are recorded for repeatability; Tessa does not need to run them for this completed review. Reduce Motion was toggled through the simulator Settings UI; the capture script does not toggle it itself.

## Prioritized phone review: results reported October 12

| Check | Tessa’s result | Assessment |
|---|---|---|
| First ask → Never → return | Telescope | Pass: automatic guidance |
| Telescope → While Using → return | Main screen with saved location; success | Pass: recovery destination; request count was not separately measured |
| Services-off Open Settings | Opens app Settings, not global Location Services | Expected landing. The chip explains Back → Privacy & Security → Location Services; walking that remaining path was not reported |
| Cat → restore connectivity in Control Center → dismiss | Success | Pass: device recovery; exact retry count was not separately measured |
| Moon flight/haptic feel | Success | Pass: subjective device review |

These results complete the four reported pass checks and confirm the expected Services-off Settings landing. They do not assert completion of the broader original device checklist. No new code change is required by the reported outcomes.

Fresh-install onboarding and real Screen Time Restricted controls can be deferred to a separate session. Their deterministic behavior remains covered by the existing suite. Full VoiceOver focus/scrolling review, SE AX2/AX3 scrolling, and the previously recorded Restricted reserved-control concern are not declared resolved. Hardware GPS, native unanswered-prompt/background behavior, and physical offline-recents behavior are also not proven by fake routes; revisit if the short phone checks reveal a discrepancy.

## Test execution

Post-fix full suite passed in the agent’s simulator run: **757 tests in 59 suites, 115.934 seconds, TEST EXECUTE SUCCEEDED**. No pseudo-terminal or CoreSimulator errors. Run used `test-without-building` with parallel testing disabled; no further Terminal run is needed for this change.
