# Step 5.16: strip TestFlight-only tools, then 1.0

Status: planned 2026-10-17. Runs last, after friend feedback. The tools below are removed only from the submission
build; friends keep them until then.

Source decisions: DECISIONS.md 2026-10-01 (Show onboarding in TestFlight, "Temporary: remove before the 1.0 App Store
build"), 2026-10-06 (Forget saved place, same note); STATUS.md; APP-STORE-PREP.md item 8.

## Why remove them, not just rely on the gate

`BuildChannel` shows the buttons only when the receipt is `sandboxReceipt` (TestFlight), and hides them on `receipt`
(App Store). An ordinary App Store build is therefore already clean. But App Review can run an app with a sandbox
receipt, which would look like TestFlight to that check, so the buttons could reach a reviewer. Removing the code is the
safe route. Removing it also drops the one deprecation warning (`appStoreReceiptURL`, deprecated since iOS 18).

## Bundle ID (resolved 2026-10-17)

The Hello Luna App Store Connect record uses `com.t-alien.moonbeam-app`, the same bundle ID the app already has. No
bundle ID change is needed.

## (Superseded) question before the run: bundle ID

The app was renamed to Hello Luna and a new App Store Connect record was created (2026-10-17). The bundle ID has been
unchanged (`com.t-alien.moonbeam-app`). A bundle ID can belong to only one app record. Before archiving, confirm which
record owns it: either the new Hello Luna record has its own bundle ID, or the old record was renamed. If the bundle ID
has to change, that is part of this step and needs its own decision (it also changes the Keychain, UserDefaults
container, and any saved-place state for TestFlight testers).

## Scope

### Remove from the submission build

- [ ] "Show onboarding" button and its action wiring (bottom of the main screen)
- [ ] "Forget saved place" button and `forgetSavedPlace()` entry point, if only the button uses it
- [ ] The debug panel ("Show debug tools") and its readouts
- [ ] `BuildChannel` (`isTestFlight`, `showsOnboardingButton`, the forms taking the receipt URL and DEBUG flag) and every
      caller
- [ ] `Bundle.main.appStoreReceiptURL` usage (the deprecated call)
- [ ] Test data that exists only for TestFlight or debugging: sample or fixture places, mock times, debug-only seeds.
      Previews and tests keep theirs, but they must not ship in the Release target.
- [ ] Debug-only logging and signposts that print in Release

### Keep

- DEBUG-only launch arguments (`-forceOnboarding`, `-onboardingPage`, scheme args). They are already compiled out of
  Release; leave them for development.
- Tests and previews, including `BuildChannelTests` only if the type still exists. Delete tests for removed types.
- Everything the real user flow needs: onboarding, search sheet, persisted noCity, Got it moon entry, compass.
- `LaunchSignposts` subsystem naming, unless it prints to the console in Release.

### Not in this step

Telescope removal (done), status bar scrim (5.15), banner/pill overlap (undecided), app icon (done).

## Chunks (progress update after each; stop where marked)

1. **Inventory (report only, no edits). STOP for Tessa's OK.**
   - Grep for: `BuildChannel`, `showsOnboardingButton`, `isTestFlight`, `sandboxReceipt`, `appStoreReceiptURL`,
     `Show onboarding`, `Forget saved place`, `forgetSavedPlace`, `Show debug tools`, `#if DEBUG`, `DEBUG readout`,
     `print(`, `NSLog`, `os_log`, `Logger`, fixture, sample, mock, seed.
   - Report each hit as file:line with what it is, and mark it Remove, Keep, or Ask.
   - List the debug panel's contents.
   - List anything that looks like test data, and which target it lives in (app vs tests vs previews).
2. **Removal (after OK).** Delete the items marked Remove, delete the tests for removed types, fix call sites. Build
   Debug and Release with no new warnings; the `appStoreReceiptURL` warning should be gone. Run the full suite and
   compare with the known failures (25 SentenceTokenTests, the PlaceChangeLayout flake).
3. **Release binary check.** Build Release and run `strings` on the binary for: `Show onboarding`, `Forget saved
   place`, `BuildChannel`, `sandboxReceipt`, `Show debug tools`, `-forceOnboarding`, `-onboardingPage`, the DEBUG method
   names. Note: `strings` can't see strings of 15 bytes or fewer ("Show onboarding" is 15), so also check the compiled
   symbols (`nm`) and run the Release app in the simulator to confirm the buttons are absent.
4. **Version.** Set `MARKETING_VERSION` to 1.0 and the build number to **10** (decided by Tessa 2026-10-17: 1.0 builds
   (1) to (9) are already used; 0.1 (10) and (11) are a different version train, so 1.0 (10) doesn't collide).
   If the upload is rejected for a duplicate build number, go one higher than the highest uploaded 1.0 build. Do not
   edit a signed archive; rebuild.
5. **Archive.** Signed Release archive. Verify in the archive's Info.plist: display name Hello Luna, version 1.0, build,
   bundle ID, iOS 26.0 minimum, fonts, privacy manifest present (no tracking, no collected data), export compliance
   key. Do not upload. Tessa uploads from Xcode Organizer.

## Rules for the agent

- No push, no upload, no install on the phone unless asked.
- Commit once per chunk, small messages.
- Report-only items stay report-only.
- Short progress update after each chunk, so a long run isn't mistaken for a stall.

## After the run (Tessa)

- [ ] Install the archive's build via TestFlight (or run Release from the icon) and confirm: no Show onboarding, no
      Forget saved place, no debug tools, first run still works
- [ ] Upload to the Hello Luna record, attach the build, submit for review
