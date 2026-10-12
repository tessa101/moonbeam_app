# TestFlight 0.1 (9)

Prepared October 12, 2026. App display name: Moon Signal. Previous uploaded release: 1.0 (8).

## Release scope

This is an interim release of completed location consolidation, place-change transitions, and day-arrow feedback. The planned moon-state redesign (5.11), broader accessibility reflow (5.5), and location-off compass preview (5.12) remain deferred.

- Launch and explicit location requests now share illustrated permission-denied, Services-off, Restricted, and No fix destinations. First ask retains its invitation.
- Returning from Settings updates the destination automatically. First ask → Never returns to the telescope; restored access recovers to the main screen.
- No fix explains cellular/Wi-Fi connectivity and retries when returning to the app. City-search actions hide offline when there are no recent cities; their layout space stays reserved.
- Services-off guidance explains how to navigate back from the app Settings page to global Location Services.
- Place changes use a reserved card skeleton and coordinated content arrival; day arrows have press feedback and a soft haptic.
- The departing searching moon finishes fading before the failure headline arrives, including with Reduce Motion.

## Verification

- Latest full simulator suite: **757 tests in 59 suites passed in 115.934 seconds**, TEST EXECUTE SUCCEEDED. No app logic changed after that run; this preparation changes version/build settings only.
- Phone review passed: First ask → Never → telescope; telescope → While Using → main screen; Control Center connectivity recovery; moon flight/haptic feel. Services-off Open Settings lands on the app Settings page as designed.
- Signed Release archive: **ARCHIVE SUCCEEDED**. Verified version **0.1**, build **9**, bundle identifier, Moon Signal display name, iOS 26.0 minimum, four fonts, privacy manifest, and non-exempt encryption flag. Strict signature verification passed with macOS trust-service access (sandbox-only check initially could not validate the trust chain).
- Archive: `/Users/tc/app-ideas/moonbeam/build/releases/Moonbeam-0.1-build-9.xcarchive`. Log: `build/releases/moonbeam-build9-archive.log`.
- Upload: not performed during this preparation; App Store Connect acceptance and tester availability remain unverified.
- Version naming follows the October 8 decision: 0.1 (9), retaining the increasing build number. If Apple rejects the lower marketing version, the documented fallback is 1.0; do not edit the signed archive to change its version.

## Remaining review

Fresh onboarding, real ScreenTime Restricted behavior, full VoiceOver focus, and broader accessibility/device checks remain deferred. SE large-text failure messages may require scrolling. Restricted while offline with no recents still has no action; offline compass-dialog behavior is unchanged pending Tessa’s decision.

## What to Test — ready to paste

This build brings clearer location messages and smoother recovery:

• Matching illustrated screens when location permission is off, Location Services are off, access is restricted, or a location cannot be found.
• Automatic recovery when returning from Settings or restoring connectivity.
• City-search options that reflect connectivity and your recent cities.
• Smoother place changes, moon transitions, and day-arrow feedback.

Try denying location access, enabling it in Settings and returning, restoring connectivity, and searching for a city instead. Check large text, VoiceOver, and Reduce Motion if you use them.

“Forget saved place” clears your saved city and recents so you can repeat these flows. “Show onboarding” remains available. Accessibility polish is still in progress.
