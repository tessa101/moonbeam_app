# Onboarding rework: Mod main (no city) state

_Decided by Tessa, 2026-10-16 (flow diagram: https://claude.ai/artifact/6QGmF7exDqHz44yWVwrHYF). Resolves the cancel-search question left open in STEP-5.13-ONBOARDING-DECLINE-SEARCH.md and replaces the earlier idea of closing Search back to wherever the user came from. Read LOCATION.md and LOCATION-SHEET.md first and match their patterns and tokens. Do not add dependencies._

## Goal
Every exit from first-run Search lands on one stable screen. No dead ends, no bottom-sheet scolding.

## Model
One main screen, two states: `noCity` (Mod main) and `resolved(city)` (Main). Do not build a second page.

noCity state:
- Same headline component as Main (`MadlibSentence`), not a second one: "Where can I find the moon [calendar icon] today in [pin icon] a city?" The empty city slot shows the placeholder "a city" in the same gold underlined token style as a resolved city, so it reads as tappable; tapping it opens Search.
- Layout (design update, 2026-10-16): the headline sits vertically centred in the space between the Back chevron (top left) and the CTA block (bottom), and grows to fill it. The widest line fills the width, the three lines take at most 80% of that height, and it stops at 2.5× the sentence's full size (`MadlibScale.filling`, `Theme.Fonts.sentenceMaximumFillScale`). Where the sentence doesn't fit at full size it falls back to Main's shared scale (shrink at the default size, wrap elsewhere). Accessibility sizes never grow: the text keeps the reader's size and wraps, and the screen scrolls if it must.
- The calendar icon and "today" show as on Main but aren't a control in noCity (no button, no calendar). They become one once a city is set.
- The empty card slot and the debug tools sit below the fold, so they never move the headline.
- Flat "Enable location" CTA at the bottom: Open Settings when location is denied or Location Services are off, hidden when restricted.
- Tertiary link under the CTA: "Start with [major city in their time zone]".
- Once a city is set, the headline goes back to Main's top-left layout at its usual size.

## Flow
1. Landing > Upsell.
2. Upsell:
   - Use location > OS prompt. Allow > Main (resolved). Don't Allow > "That's OK" (existing screen) > Got it > noCity. Restricted also shows That's OK, as before.
   - Search for a city > noCity directly (search does not auto-open; the user taps the city token).
   - "That's OK" stays in the flow. It is the acknowledgment after a denial at the OS prompt, and only Got it leaves it.
3. noCity:
   - Tap city token > Search sheet. Close > back to noCity. Pick city > sheet dismisses, city fills in place, CTA fades out.
   - Tap Enable location > OS prompt over this screen. Allow > fills city in place. Deny > CTA becomes "Open Settings" (deep link to app settings).
   - Tap "Start with [city]" > fills that city in place, CTA fades out. The city comes from the device time zone, which needs no permission. Hide the link if the time zone has no mapped city.
   - Back (chevron or swipe) > Upsell. Allowed only while in noCity.
4. When state becomes resolved, clear onboarding history so Back never returns to Upsell.
5. Telescope is unchanged, but only reachable from the resolved Main screen when location is denied or the lookup fails after onboarding. Never in first-run.

Debug onboarding replay follows the same first-run isolation. Entering noCity clears the current in-memory place,
moon card, replacement and lookup state, but does not delete the saved place or recents. A saved or previously
displayed city must not fill noCity, including when location is already authorized. Only the explicit
LocationAllowed outcome may begin GPS resolution; if that request fails, the screen remains truly noCity. Normal
returning-user launches still restore the saved place.

## Time zone to city table (starting point, keep in one lookup)
- America/Los_Angeles > Los Angeles
- America/Denver, America/Phoenix > Denver
- America/Chicago > Chicago
- America/New_York > New York
- America/Anchorage > Anchorage
- Pacific/Honolulu > Honolulu
- Anything else: hide the link for V1.

## Tests to add (don't run; Tessa runs them in Terminal)
- Time zone to city lookup: mapped zones return the expected city, unmapped return nil.
- noCity to resolved on search pick, location success, and "Start with" tap.
- Search close from any entry point leaves state at noCity.

## Acceptance checks
- Search close from every entry point lands on noCity.
- No path reaches Upsell via Back after a city is set.
- Don't Allow at the OS prompt shows That's OK, and Got it lands on noCity with the CTA reading Open Settings.
- Location denied at OS level shows Open Settings, never a dead CTA.
- Placeholder token is visibly tappable and passes the existing accessibility label rules.
- Returning users with a saved city are unchanged.

## Out of scope
Telescope redesign, copy polish, analytics.

## Relaunch and noCity (Tessa, 2026-10-16)

noCity is stable across relaunch. After Got it or Search instead, a relaunch with no saved city and no location access lands on noCity, not the permission-off screen. Quitting on "That's okay" before Got it still shows the permission-off screen. Cleared when a city is picked or saved, or when permission becomes authorized. Spec: STEP-5.14 §6.4.
