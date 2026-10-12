# Step 5.10a Consolidation Chunk 2c: offline search, copy, and two checks

> Decided with Tessa, October 11, 2026, from her device test of Chunk 2b (full suite passed on `e6d8ed5`).
> **Implemented October 11, 2026.** Amends `STEP-5.10a-CHUNK-2B-DEVICE-FIXES.md` item 1 (which said "no connectivity monitor"; item 2 below reverses that on purpose). Tessa ran the full suite twice on October 12: 754 tests in 59 suites passed (36.440 s and 37.632 s).
> Read `STEP-5.10a-LOCATION-CONSOLIDATION.md` §3, the 2b doc, and the Chunk 2b entry in `.agent-reports/latest.md`.

## Environment and process

Do not run `xcodebuild test` or `simctl`: the runner can't open a pseudo-terminal here and hangs. `build-for-testing` works. If a build step hits a pseudo-terminal or CoreSimulator error, stop immediately and report the command and last output. No retries. Hand Tessa the test commands to run in Terminal.

Four items, in order, one commit each, a `.agent-reports/progress.log` line before each, `build-for-testing` after each. Record decisions in `docs/DECISIONS.md` (Tessa, 2026-10-11). Stop after item 4. Don't start Chunk 3. No push.

## What Tessa observed (device, 2026-10-11)

Settings names below are iOS's: "Never", "Ask Next Time Or When I Share" (not determined), "While Using the App".

| Network | Location setting | Result |
|---|---|---|
| Airplane + Wi-Fi on | Never | Telescope; search works. As designed. |
| Airplane + Wi-Fi on | Ask | First ask; search works. As designed. |
| Airplane + Wi-Fi off | Ask | **Cat (No fix), not First ask.** See item 3a. |
| Airplane + Wi-Fi off | Never | Telescope. Search **doesn't work** (no network). |
| Airplane + Wi-Fi off | Never, Open Settings, Ask, back | First ask. As designed (2b item 2). |
| Airplane + Wi-Fi off | First ask, Use my location, Don't allow | Telescope. As designed. |
| Airplane + Wi-Fi off | First ask, Use my location, Allow once | Cat. As designed (authorized, no fix, can't name a city). |
| Airplane + Wi-Fi off | Open Settings, Never, back | Telescope. As designed. |
| Cell only, weak | Never | Telescope; search works. As designed. |
| Cell only | Open Settings, Ask, back | First ask. As designed. |
| Cell only | Use my location, Allow once | Found; main screen. |
| Cell only | Forget saved place, relaunch (Allow once expired) | First ask; Use my location, Allow while using: found. |
| Cell only | Forget saved place, relaunch (Allow while using) | Main screen with location. As designed. |
| Cell only | Forget saved place, set Never, relaunch | **First ask before the telescope.** See item 3b. |

## 1. Copy

- **"Enter a city instead" becomes "Search for a city instead"**, everywhere it's used (the shared constant `LocationFailure.enterCityTitle`, the launch message link, the failure screen, tests, docs, DEBUG, VoiceOver labels). Restricted's primary stays "Search for a city". Don't touch the onboarding screen's own "Search for a city instead" or the search sheet's placeholder.
- **Permission-off and Restricted headline** (they share one string): "Moon Signal can't see your location" becomes **"Can't see your location"**. Default-size line breaks: "Can't see / your location". VoiceOver reads it as one sentence. The compass-only dialog follows because it reads the shared cause copy.
- **Keep `AppInfo.name`** in the Settings path chip and in First ask's body, so a future app rename flows through the constant. Remove it only from the headline.

## 2. Hide the search action when it can't work (offline)

Why: with no connection, the search sheet can only fail ("Can't search right now") except for recents. A button that leads to an error is a dead end.

- **Rule:** a search action (the "Search for a city instead" link on the four causes and on First ask, and Restricted's primary "Search for a city") shows only when **the device has a network path OR the recents list isn't empty**. Recents work offline (tapping one picks it without resolving).
- **Connectivity source:** Apple's Network framework (`NWPathMonitor`), behind a small protocol with a fake for tests. This is a system framework, not a third-party dependency, and it **reverses the 2b "no connectivity monitor" line on purpose**. A satisfied path counts as online, even if weak.
- **Live:** the monitor updates the screen while it's showing; the action fades in or out (Reduce Motion: opacity only, no motion). Stop observing when the screen is gone.
- **Layout:** keep the action's slot (the 44 pt link slot, and Restricted's primary slot) reserved when hidden, so nothing moves when it appears. Hidden actions are hidden from VoiceOver and not tappable.
- **Unchanged:** Open Settings (Permission off, Services off); First ask's Use my location (the system prompt works offline); onboarding's own search link; the search sheet itself and the main screen's place token (they keep their own offline message).
- **Known oddity, don't fix now:** Restricted offline with no recents has no action, though its body says "You can still search for a city." The button returns when the connection does. Record it.
- **Tests (fake monitor):** each cause, with network on and off, with and without recents; the slot is reserved; it updates live; VoiceOver hides it while hidden; First ask's Use my location stays.

## 3. Two checks (reproduce first, fix only if it's a bug)

**3a. Not determined, offline, showed the cat.** Tessa saw No fix (cat) with "Ask" selected, airplane + Wi-Fi off. First ask never depends on the network, so a not-determined launch with no saved city must show First ask. Likely cause: "Allow once" was still active (authorized) from earlier in the session, so the fix failed offline; that would be correct. Verify in code and tests that notDetermined + no saved city + a failing fix lands on First ask, regardless of network, and add the test if it's missing. Report which it was.

**3b. Never + Forget saved place showed First ask before the telescope.** §3 row 1 says denied at launch with no saved city goes straight to the telescope. Tessa's order is unclear, so check both:
1. Never set before launching, no saved city: must open the telescope directly.
2. App already on First ask, then Never set in Settings, then back: must switch to the telescope (First ask foreground with access turned off).
Trace the launch path after `forgetSavedPlace()` for both. Fix only a real bug, and report the cause with the test that fails first.

## 4. Services off: say the first step in the chip

Why: every Open Settings button uses `UIApplication.openSettingsURLString`, which can only open the app's own Settings page. Services off is a device-wide switch outside that page, and iOS has no public link to it (the private `App-Prefs:` URL gets apps rejected; don't use it). Tessa tested this on a device (2026-10-11): Open Settings from the compass dialog lands on the app's page and Services can't be turned on there.

- Keep the Open Settings button for Services off.
- Change the Services off chip (`LocationFailure.pathChipLines`) to **"Back to Settings › Privacy & Security ›" / "Location Services"**, so the first step (tap the back arrow at the top left) is in front of the user. Set the VoiceOver label to read it as a path.
- The compass dialog shows the same text through the shared cause definition; check it still fits.
- Permission off's chip is unchanged: its fix is on the app's own page.
- Tests: the chip's lines and VoiceOver label for Services off; Permission off unchanged; the dialog shows the new text.

## Follow-ups to add (§6 of the consolidation plan)

- First ask: a character or illustration to invite allowing location (design TBD; the searching cat is one candidate).
- Retry No fix the moment connectivity returns, without leaving the app (the monitor from item 2 makes this cheap; not in this pass).
- Restricted offline: its body mentions searching while no action shows.

## Tessa's device checklist (cases not covered by 2026-10-11's run)

Fold into Chunk 3's "needs device review" list.

1. **Services off** (Settings › Privacy & Security › Location Services off): the map screen at launch and from Use my location, online and offline. Open Settings opens the app's page only.
2. **Restricted** (Screen Time › Content & Privacy › Location Services): the locked-map screen; the only action is search.
3. **Saved city + every failure state** (Never, Services off, offline): the saved city opens with no failure screen, and the compass shows its hint or hides.
4. **Explicit routes while blocked:** the search sheet's "Use my location" row, and the main screen's Use my location, with Never, Services off and offline. No Location Off dialog should appear; the matching failure screen should.
5. **Compass-only Turn On Location** (the dialog stays): the new headline and path text, Open Settings, and the city is kept.
6. **Telescope → Open Settings → While Using → return:** one automatic fix, Aha, the moon flies into the card. Also with airplane + Wi-Fi off (it should end at the cat).
7. **No fix recovery:** on the cat, turn Wi-Fi/airplane on in Control Center without leaving: nothing should happen; leave and return: loader, then main. One retry only.
8. **Unanswered system prompt:** First ask, Use my location, then background the app without answering: stays on First ask.
9. **Real onboarding** (fresh install, not Forget saved place): Don't Allow, "That's okay", Got it, then the standard destination; and "Search for a city instead".
10. **Pick a city offline from recents** (recents exist): works; and a failed explicit Use my location offline with recents still shows the search action.
11. **Visual:** SE-size and large text, Reduce Motion.
