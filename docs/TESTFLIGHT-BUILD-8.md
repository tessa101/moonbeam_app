# TestFlight 1.0 (8)

Prepared October 6, 2026. App display name: Moon Signal.

## Comparison baseline

The last recorded TestFlight upload is **1.0 (7)** on October 3. STATUS.md records builds 6 and 7 as the same app uploaded twice. The local October 3 archive confirms version 1.0, build 6. The source comparison is `c695c94..1b66c3e`; this includes the later build-number change to 7. App Store Connect has not been independently checked for a later upload.

## What changed

- **New launch experience:** the launch background matches the app. Fast location fixes skip the loader; slower fixes show a cycling moon and “Finding your location…” instead of an empty main screen. The loader remains visible long enough to avoid flashing.
- **Launch reliability:** potentially blocking Location Services reads moved off the main thread, existing installs avoid unnecessary permission reads during app initialization, and foreground handling no longer cancels the launch location fetch. The previously reported device stall was not conclusively reproduced; these changes address its suspected cause.
- **Clearer location states:** with no saved city, dedicated screens explain permission not yet requested, permission denied, Location Services disabled, restricted access, and a failed location fix. Actions offer permission, Settings, retry, or city search as appropriate. A saved city remains the fallback.
- **Recovery feedback:** successful recovery shows a greeting and city name. The moon advances to the card’s actual phase, then shrinks and flies into its position. The sentence, card, and compass arrive in sequence, with a soft landing haptic.
- **Visual polish:** smoother moon timing and stopping, a visible earthshine dark side in the loader and onboarding, tighter line heights, narrower message text, and balanced default-size line breaks. Loader messages have large-text layout adaptations.
- **TestFlight helper:** “Forget saved place” clears the last city and recent cities so testers can repeat the empty-location flow. It leaves permission and onboarding completion intact. “Show onboarding” remains available. Both helpers are limited to DEBUG/TestFlight.

Astronomy calculations, city-search logic, and compass logic have no functional changes in this comparison. This is primarily a launch and location-flow release.

## Assessment

Suitable for another TestFlight round: the current source builds and the full automated suite passes. Manual testing should concentrate on permissions and recovery because these are the largest behavior changes.

Known unfinished work carried forward:

- The dedicated loader VoiceOver / Reduce Motion review remains deferred (LOADER.md §10.6), including exposure of the outgoing invisible location label to VoiceOver. Existing motion accommodations do not constitute a completed accessibility review.
- The broader main-screen accessibility reflow (5.5) remains deferred.
- Loader transition timing and the landing haptic need a physical-device feel check.
- The previously parked day-arrow movement issue is not addressed by this release.

## Verification

- Full iPhone 17 simulator suite: **648 tests / 970 cases in 49 suites passed**; `xcodebuild test` succeeded.
- Signed Release archive: succeeded; its app bundle confirms **CFBundleShortVersionString 1.0 / CFBundleVersion 8**, minimum iOS 26.0, Moon Signal display name, all four font declarations, privacy manifest, and export-compliance flag.
- Release warnings remain in unchanged code: deprecated formatting and receipt APIs, vendored Astronomy Engine comma-operator warnings, and skipped optional App Intents metadata extraction. No compile errors.
- Archive: `/Users/tc/app-ideas/moonbeam/build/releases/Moonbeam-1.0-build-8.xcarchive`.
- Test results: `/private/tmp/moonbeam-build8-tests.xcresult`.
- Upload status: **succeeded October 6, 2026 at 9:13 PM PDT**. Apple reports “Uploaded package is processing”; availability to testers has not yet been verified. The App Store Connect browser session is signed out, so the tester notes below have not been saved in Apple’s web interface.

## What to Test — ready to paste

This build improves launch and location recovery:

• A new animated moon loader while finding your location.
• Clearer messages when location access is off, restricted, or unavailable, with Settings, retry, and city-search options.
• Smoother recovery: the moon changes to today’s phase and lands in the moon card with a soft haptic.
• Refined moon shading, message typography, and transitions into the main screen.

Please test cold launch, denying location access, enabling it in Settings and returning, retrying a failed fix, and searching for a city instead. Check the transition and haptic on your phone, plus large text, VoiceOver, and Reduce Motion.

The temporary “Forget saved place” button clears your saved city and recent cities so you can repeat these flows. “Show onboarding” is still available. Accessibility polish remains in progress.
