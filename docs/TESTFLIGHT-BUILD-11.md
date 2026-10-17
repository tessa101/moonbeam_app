# TestFlight 0.1 (11)

Prepared October 17, 2026. App display name: **Hello Luna** (renamed from Moon Signal; bundle ID unchanged,
`com.t-alien.moonbeam-app`). Previous build: 0.1 (10). Uploaded by Tessa from Xcode Organizer; out for friends' testing.

## Release scope

Everything since 0.1 (10), shipped as is. The SE 3 AX3 moon-start decision is still open and not in this build.

- Rename Moon Signal to Hello Luna: display name, location usage string, `AppInfo.name`, tests, docs (`df37726`).
- Housekeeping (`daae061`): `MoonTableSpike` gated behind `#if DEBUG` (Release no longer runs or compiles it);
  `contentSpace` made `nonisolated`, which clears the one new build-10 warning.
- Search/cancel flow, noCity state (persisted across relaunch), search sheet with location row and five cities.
- "Got it" enters noCity through the moon animation (5.14 section 6); root handover moved into `RootScreen`.
- Ready-to-look cat replaces the permission-off telescope; landing cat and tail motion retunes (5.14).
- Shared pressed state on every button (5.13.3), accessibility reflow (5.5), sentence token buttons (5.13.4).
- Compass: date-only changes no longer replay the entrance.

## Verification

- Focused suites pass: `LocationScreenScrollingTests`, `LoaderFlowTests`, `LocationFailureScreenTests`,
  `PlaceChangeLayoutTests` (rerun alone).
- Full suite from Terminal: 27 issues, all known: 26 in "Sentence token buttons" (command-line only, pass in Xcode)
  and one `PlaceChangeLayoutTests` timing bound that passes alone.
- Release build: succeeded; the `contentSpace` warning is gone; no new warnings against build 10.
- Version: `MARKETING_VERSION` 0.1, `CURRENT_PROJECT_VERSION` 11. If App Store Connect rejects 11 as a duplicate, bump to 12.

## What to Test (TestFlight text)

```
Hello Luna 0.1 (11)

The app is now called Hello Luna (it was Moon Signal). Everything else is the same app you've been testing, with a lot more polish on the first-run experience. Please focus on the first 2 minutes.

WHAT'S NEW
• First launch: a searching cat on the landing screen, and a new moon animation when you tap "Got it".
• If you say no to location: a "That's okay for now" screen, then the main screen waits for you to pick a city. There's a new search sheet with your location option and five suggested cities, plus a "Start with [city]" link.
• The cat now replaces the telescope on the location-off screen.
• Buttons now show a clear pressed state everywhere.
• Large text sizes (Settings > Accessibility > Display & Text Size > Larger Text) now scroll and reflow properly.
• Stepping through dates no longer replays the compass animation.

PLEASE TRY
1. Fresh start: scroll to the bottom of the main screen and tap "Show onboarding". Go through it once allowing location and once denying it.
2. Deny path: open the search sheet, then tap Cancel. You should land back on the main screen, never stuck.
3. Search a city and pick one. Does the compass and moon table load?
4. Close the app completely and reopen it a few times. Does it always land somewhere sensible?
5. Turn on a big text size and look at every screen.
6. Tap the underlined words in the sentence at the top. Are they easy to hit?

TELL ME ABOUT
• Any time you see a telescope. You shouldn't.
• Any blank or black flash between screens.
• Words that are hard to tap, cut off, or overlapping.
• Anything that felt slow, janky, or confusing.

To reset: "Forget saved place" at the bottom of the main screen. Thank you!
```

## Remaining

- SE 3 AX3 moon start (recommended: start the flight from the screen's top edge).
- App icon redesign (needed by 1.0).
- Remove TestFlight-only tools (Show onboarding, Forget saved place, debug panel, BuildChannel) in the submission build only.
- Version 1.0 and the App Store Connect checklist.
