# Design Review Backlog

> A running list of things to revisit during the UX/UI design pass. Add items as they come up;
> check them off (with the decision) when they're settled. Owner: Tessa.

_Started: 2026-09-26_

## Location screen (Step 2, built plain)
- [ ] **Visual design** of `LocationScreen`: prompt, search button (opens the sheet), "Use my location" ("Back to {City}" chip removed, Decision C)
- [ ] **Time zone label wording.** Currently "Sydney · GMT+10". Options: GMT+10 (precise, dev-ish) · "Sydney time" (friendliest, no lookup table) · AEST (familiar, needs a table). Leaning "Sydney time" with the offset in the VoiceOver label
- [ ] **Launch loading state** while the location fetch runs (up to 10 s): last-viewed name as placeholder, or a spinner?
- [ ] **Failed fetch message** is placeholder text: "Couldn't find your location. Try again, or search for a city." Check placement, tone, and that it doesn't vanish too quickly
- [ ] **Suggestions list states:** no results ("No matching cities") and network error ("Can't search right now. Check your connection.")
- [ ] **First-launch empty state:** does the empty field + prompt feel inviting, or does it need something moon-y?
- [ ] **Detected location shows the city** ("Los Angeles", not "Mar Vista"). Revisit if neighborhoods feel more personal
- [x] ~~**Select-all on tap + clear (x):** confirm the interaction feels right once styled~~ Superseded: the main-screen field now opens the search sheet (SEARCH-RECENTS.md §1)

## Search sheet (Step 2.1, built plain; SEARCH-RECENTS.md §7)
- [ ] **Sheet visuals:** section header style, row layout (city bold + region/country secondary), location row icon
- [ ] **VoiceOver:** field focus on present, "Recent" announced as a header, swipe-to-delete exposed as a custom action
- [ ] **Type-ahead threshold** 2 vs 3 characters, after real-device testing (`searchMinimumCharacters`)
- [ ] **Resolve-failure copy:** "Can't search right now" is wrong when the city was just listed as a suggestion

## Location Off dialog
- [ ] **Visual design** of `LocationOffDialog` (custom, not a system alert)
- [ ] **Per-variant titles.** All three currently share one title. Proposed:
  - Denied: *Location is off for Moonbeam*
  - Services off: *Location Services are off*
  - Restricted: *Location is restricted*
- [ ] Body copy and button labels once the visual tone is set

## Moon table (Task #4, not built yet)
- [ ] Table layout: rise time + direction, set time + direction, phase, illumination %
- [ ] **No moonrise / no moonset today** state (Mar Vista 2026-10-03 exercises it)
  - Can't be checked in the app until there's date picking (or open the app on Oct 3). Consider a date picker, even a dev-only one, so edge-case days can be checked in the UI
- [ ] How to signal that illumination/phase are for **tonight's local midnight**
- [ ] Time zone label placement in the table
- [ ] Compass direction format ("105° ESE"): degrees, letters, or both?

## Accessibility (part of the design pass)
- [ ] Dynamic Type up to the largest accessibility sizes, on every screen
- [ ] VoiceOver labels and reading order (e.g. "ESE" read as "east-southeast", time zone read in full)
- [ ] Color contrast (WCAG AA), especially on dark/night themes
- [ ] Touch targets ≥ 44 pt (clear button, "Use my location", Cancel)
- [ ] Reduce Motion, if any animation is added
- [ ] Dark mode (people use this app at night)

## Brand / product
- [ ] Display name "Moonbeam" (lives in `AppInfo.name`)
- [ ] Primary persona (confirm with design partner)

## Later
- [x] ~~Recently searched cities list (weather-app pattern; storage already shaped for it)~~ Built in Step 2.1 (SEARCH-RECENTS.md)
