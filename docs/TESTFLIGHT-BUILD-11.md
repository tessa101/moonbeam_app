# TestFlight 0.1 (11)

Prepared October 17, 2026. App display name: **Hello Luna** (renamed from Moon Signal; bundle ID unchanged,
`com.t-alien.moonbeam-app`). Previous build: 0.1 (10).

## Release scope

Everything since 0.1 (10): 5.13.3 shared pressed state, 5.13.4 sentence token buttons, 5.14 onboarding cat and
load-ins, the ready-to-look cat replacing the permission-off telescope, 5.5 accessibility reflow, the noCity flow
with the search sheet (cancel flow decided and built), the "Got it" moon entry, the compass date-step fix, and
the pre-launch housekeeping (MoonTableSpike gated behind DEBUG, `contentSpace` Sendable warning fixed). The app
rename to Hello Luna is in this build.

Not in this build: the SE 3 AX3 moon-start decision (shipped as is), the app icon redesign.

## Verification

- Full suite in Terminal (iPhone 17 simulator): only the known failures. 25 to 26 SentenceTokenTests
  (command-line-only) and one PlaceChangeLayout timing flake that passes alone.
- Rename suites (LoaderFlowTests, LocationFailureScreenTests) and LocationScreenScrollingTests: pass.
- Release build: succeeded, contentSpace warning gone, no new warnings versus build 10.
- Version: `MARKETING_VERSION` 0.1, build 11.

## What to Test (pasted into TestFlight)

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
