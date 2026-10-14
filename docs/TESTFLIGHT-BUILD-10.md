# TestFlight 0.1 (10)

Prepared October 14, 2026. App display name: Moon Signal. Previous build: 0.1 (9) (archived 2026-10-12; upload
pending). Last build App Store Connect accepted: 1.0 (8).

## Release scope

Everything since 0.1 (9) (`d9eba76`). Confirmed on the phone by Tessa unless marked otherwise.

- **Moon states (5.11):** today's card always has a middle column: Up now (bearing plus altitude, e.g.
  `266° W · 23° up`), Not up yet (a countdown that updates each minute) or Set for today ("Back late tonight,
  [time]"). A today-only guidance line sits under the columns. Approved by Tessa 2026-10-12.
- **Compass entrance (5.10a.3):** one entrance on every reload: launch, place change, date step, foreground, late
  heading or location, failure recovery, back on screen. Confirmed.
- **Location off, prompt and guide (5.12b.1 to 5.12b.3b):** the ghost-ring compass prompt (S1) with Turn On
  Location and Maybe later; the guide row (S2 to S6) after Maybe later; the one-card collapse/expand; the off/on
  swap; the VoiceOver focus moves. Restricted keeps the chip. Confirmed.
- **Dial fits the screen height** (`45c2717`): the face is the smaller of the width's size and what leaves 4% of
  the height under it (196 to 300 pt). Confirmed.
- **Compass simplification, closed:** minor ticks every 5° (was 2°). Mid ticks, degree numbers and the crosshair
  are unchanged. Confirmed.
- **Debug tools panel** (`45c2717`): Show onboarding, Forget saved place and the compass readout in one block at
  the bottom of the main screen, with Hide/Show debug tools (remembered). TestFlight and DEBUG only.
- **Telescope redraw (5.10a):** the permission-off art from `6bbdd9a`, `ef0090b`, `763fe7c`, with the lens glint.
  **Phone check pending.** See Remaining review: Tessa's correction of 2026-10-12 says this is not the telescope
  she wanted.
- **Also in the build, not in the confirmed list:** the restyled Location Off sheet from the compass's Turn On
  Location (5.12a, `bcff3ac`). Its phone check was pending in STATUS.md.

Not in this build: 5.5 accessibility reflow, the telescope correction.

## Verification

- Full suite in Xcode (iPhone 17 simulator, iOS 27.0), after the version bump: **1287 / 1287 cases passed**,
  0 failed, 0 skipped (862 tests).
- Release build of the app target (`-configuration Release`, generic iOS, unsigned, 19 s): **BUILD SUCCEEDED**.
- Warnings, compared with a Release build of `d9eba76` (build 9) made the same way: **one new warning**,
  `LocationScreen.swift:348`, "main actor-isolated static property 'contentSpace' can not be referenced from a
  Sendable closure" (the `.onGeometryChange` added in `45c2717`). Not changed for this build; the likely fix is
  `nonisolated` on that string constant. The rest are the same as build 9: `appStoreReceiptURL` deprecated
  (`BuildChannel`, known), `attributed` deprecated (`MoonTableFormatter`), `-Wcomma` in `Vendor/` astronomy.c.
- Release bundle `Info.plist`: CFBundleDisplayName **Moon Signal**, version **0.1**, build **10**, bundle ID
  `com.t-alien.moonbeam-app`, MinimumOSVersion **26.0**, ITSAppUsesNonExemptEncryption **false**.
  `PrivacyInfo.xcprivacy` is in the bundle and lints OK.
- DEBUG-only code is out of the Release binary: no `DebugScreenState` symbols, no `screenState` /
  `resetOnboarding` launch-argument strings, no `-screenState` route names.
- TestFlight tools are still in: `BuildChannel.showsOnboardingButton` is in the binary and wired to Show
  onboarding and Forget saved place outside `#if DEBUG`. "Forget saved place", "Hide debug tools" and
  "Show debug tools" are in the binary's strings. ("Show onboarding" is 15 bytes, so Swift stores it inline, not in
  the string table.) They come out before 1.0.
- Not done here: the signed archive and upload (Tessa's, in Xcode Organizer).
- Version: `MARKETING_VERSION` stays **0.1** (decision of 2026-10-08). App Store Connect may reject 0.1 as lower
  than the uploaded 1.0 (8); the fallback is 1.0. Don't edit a signed archive to change it.

## Remaining review

- **Telescope:** Tessa's correction (2026-10-12, in `docs/STEP-5.10a-TELESCOPE-REDRAW.md`, not committed) says the
  shipped redraw (Option A) is the wrong art: she meant the original D2 telescope. Testers who deny location will
  see Option A. Ship it as is, or hold the build until the correction lands: Tessa's call.
- Location Off sheet (5.12a): phone check.
- Fresh onboarding, real Restricted (Screen Time), full VoiceOver focus, large text and other devices remain
  deferred to 5.5. SE large-text failure messages may need scrolling.
- Dial height fraction (4%) was a first guess; tune it on more devices.

## What to Test — ready to paste

This build brings a clearer moon card, a calmer compass and a new screen for when location is off:

• The moon card for today: does it say Up now (with how high the moon is), Not up yet (with a countdown) or Set for today? Check the short guidance line under it.
• The compass turning into place each time it reloads: opening the app, changing city, stepping the date, and coming back to the app.
• Turn location off for Moon Signal: you should see a compass preview with Turn On Location and Maybe later. Tap Maybe later for the guide row, tap the row to bring the preview back, and turn location on and off again to watch the swap. With VoiceOver, check where focus lands.
• The compass dial should fit on the screen without scrolling, and has simpler 5° ticks.
• Debug tools are now in one block at the bottom of the main screen. "Hide debug tools" hides them and the app remembers.
• The telescope picture on the location-permission screen has been redrawn. Its check on a real phone is still pending, so tell us how it looks.

"Forget saved place" clears your saved city and recents so you can repeat these flows. "Show onboarding" remains available. Accessibility polish is still in progress.
