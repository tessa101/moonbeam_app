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
- [ ] **Search field shows the city with a "Change" / "Edit" button.** Tapping the button or anywhere on the field opens the search sheet (Tessa, 2026-09-26)
- [x] **Content scrolls under the status bar** — ✅ **Settled 2026-09-30 (Tessa, device, iOS 26):** Design 1.1's solid `bg` status bar backing and the top amber glow look right (5.1, c203caa). Original note: — **pulled forward into a build fix (4.15, 2026-09-30, Tessa: "it's annoying")**; this item stays open only for final styling. *Built:* soft top scroll edge effect on iOS 27; system bar material behind the status bar on iOS 26, where the device showed no edge effect for a bare `ScrollView`. (device, 2026-09-29): when the main screen is scrolled, the prompt and search field slide under the time / Dynamic Island with no background, so the city name overlaps the clock. Needs a safe-area background (material or solid) or a pinned header. Seen on every compass screenshot where the page is scrolled down
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
  - ~~Can't be checked in the app until there's date picking~~ Date picking is built (Step 3): pick Oct 3 to see it
- [ ] **"No moonrise today" / "No moonset today" on other days.** Wrong once the selected day isn't today (e.g. "No moonrise on Oct 3"?). Not reworded in Step 3
- [ ] How to signal that illumination/phase are for **tonight's local midnight**
- [ ] Time zone label placement in the table
- [ ] Compass direction format ("105° ESE"): degrees, letters, or both?

## Date control and calendar sheet (Step 3, built plain; DATE.md §9)
- [ ] **Copy that assumes "tonight"** when another date is picked: the screen prompt "Where are you watching the moon tonight?" and the midnight note (e.g. "Oct 3 · at midnight")
- [ ] Getting back to today takes two taps (open calendar → Today). Revisit with the relative-day chips idea.
- [ ] **Arrow styling and hit areas; the field's chevron**
- [ ] **Show the time zone in the date** when the place's day differs from the device's?
- [ ] **Calendar sheet header:** Today · title · Cancel, plus Done after the month/year wheel. Check it's clear and fits at large text sizes. Also check that six-row months fit the medium detent (it scrolls)
- [ ] **App left open across the place's midnight:** the day only moves on the next foreground (Decision 1). Revisit if it's noticed
- [ ] **Custom look for ‹ / › and the calendar sheet**, or keep the system style? (Tessa, 2026-09-26)
- [ ] **Relative-day chips always visible** (Today, Tomorrow, …), with the selected one highlighted, instead of a Today chip that only appears off today (Tessa, 2026-09-26)

## Compass (Step 4; COMPASS.md)
- [ ] **Portrait lock.** App is locked to portrait for v1 so the compass stays readable and heading stays simple (COMPASS.md §1, decision F). Deliberate choice under WCAG 1.3.4 (orientation essential for a compass). Revisit landscape later; upgrade path is allowing rotation and matching the heading orientation to the device
- [ ] **iPhone-only for v1** (COMPASS.md §1). iPad dropped so the portrait lock doesn't fight iPad multitasking; revisit with landscape
- [ ] **Enable-location hint** (location off): copy, placement, and whether it opens the Location Off dialog or the system prompt. Built as a plain placeholder
- [ ] **Proximity copy (4.6, reworded 4.11):** Nearby note "You're in {Detected city} but {City} is nearby"; Far message "You're a bit too far from {City} to view the compass accurately" (both placeholder; tone in the design pass; was "Directions for {City}" / "Compass is only available near this location"). Far may later offer "search for a city near you". Never include a distance
- [ ] **Lock feedback:** visual treatment built in 5.4 (amber pill, dot ring + glow, dial halo; DESIGN-1.1.md §3.3); haptic tap on acquire is in 4.5 — check it feels right (strength, not too frequent)
- [ ] **Low-accuracy state:** look and copy. The threshold is now hysteresis: enter above 25°, leave below 20° (was a single 15° line; device test 2026-09-29). Tune further on device if needed. **Reason is inline for now (4.10; Precise copy replaced in 4.12):** "We think you're near {City}, but the compass needs Precise Location to point the right way." + "Use Precise Location" (temporary alert; the only button since 4.14), then "There you are! The compass is happy now." for ~3 s once it's on; or "Move away from metal, magnets or a charger, or wave your phone in a figure 8" (built 4.10; the reason line replaces "Compass accuracy is low"). Decide in the design pass whether an ⓘ bottom sheet or floating dialog with fuller tips is worth adding
- [ ] Layout under the moon table, dial styling, typography (wireframe pending)
- [ ] **Plain dial as built (4.4)**, things to decide in the design pass:
  - ~~the N/E/S/W letters rotate with the dial~~ **Done (5.4):** letters and ↑/↓ are always upright
  - ~~target dots are unlabelled~~ **Done (5.4):** ↑ moonrise, ↓ moonset, bigger dot with no arrow for the live Moon (§11 Q4, proposed). Was: **target dots are unlabelled** — the rows that named them were removed in 4.7, so nothing says which dot is which until you lock. Likely fix: small labels or distinct shapes per target. The locked dot is just bigger and tinted
  - at AX sizes the top indicator grows and sits close to the "Compass" header
  - no animation, to avoid a long spin across 359° → 0°
- [ ] **Placeholder copy (4.4):** hint "Turn on location to use the compass." + "Turn On Location"; low accuracy "Compass accuracy is low" (no calibration advice)
- [ ] **Moonrise / Moon overlap** right after moonrise: which label should win (device QA, STATUS.md Next 7.3)

## Accessibility (part of the design pass)
- [ ] Dynamic Type up to the largest accessibility sizes, on every screen
- [ ] VoiceOver labels and reading order (e.g. "ESE" read as "east-southeast", time zone read in full)
- [ ] Color contrast (WCAG AA), especially on dark/night themes
- [ ] Touch targets ≥ 44 pt (clear button, "Use my location", Cancel)
- [ ] Reduce Motion, if any animation is added
- [ ] Dark mode (people use this app at night)
- [ ] **Date row + calendar sheet (Step 3, deferred from device QA):** the date field reads "Date, Today, Saturday, …" and VoiceOver swipe up/down moves a day; ‹ / › announce the new date and read "dimmed" at ±366; the sheet's Today button reads "dimmed" on today; at accessibility text sizes the row stays usable and the sheet opens at large

## Motion and feedback (noted 2026-10-01, Tessa)
- [ ] **Tap animation on buttons:** a pressed-state animation (e.g. a slight scale/opacity dip) for the primary, secondary and text-link buttons, the ‹ › day buttons and the sentence tokens. Put it in the shared button styles (`PrimaryButtonStyle`, `SecondaryButtonStyle`, `TextLinkButtonStyle`) so every button picks it up; respect Reduce Motion. After the TestFlight build with 5.7

## Brand / product
- [ ] Display name: **"Moon Signal"** for now (was "Moonbeam"; DECISIONS.md 2026-09-28). Lives in `AppInfo.name`; confirm final name with design partner
- [ ] Primary persona (confirm with design partner)

## Later
- [x] ~~Recently searched cities list (weather-app pattern; storage already shaped for it)~~ Built in Step 2.1 (SEARCH-RECENTS.md)
