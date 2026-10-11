# Step 5.10a Consolidation Chunk 2b: device-test fixes

> Decided with Tessa, October 10, 2026, after Chunk 2's full suite passed and she tested on a device.
> **Approved scope; not yet implemented.** Runs before Consolidation Chunk 3. **Supersedes `STEP-5.10a-LOCATION-CONSOLIDATION.md` §3 rows 9 and 10** (see items 1 and 2) and the "Settings return, not determined" follow-up in §6.
> Read the Chunk 2 entry in `.agent-reports/latest.md`, `STEP-5.10a-LOCATION-CONSOLIDATION.md` §3 and §6, and `design/1.6-location-error-illustrations/ILLUSTRATIONS_MOTION.md`.

## Environment

Do not run `xcodebuild test` or `simctl`: the runner can't open a pseudo-terminal in the agent's environment and hangs. `build-for-testing` works; use it to check compilation. If any build step hits a pseudo-terminal or CoreSimulator error, stop immediately and report the command and last output. No retries. Hand Tessa the test commands to run in Terminal.

## Process

Four items, in order. One commit per item, a `.agent-reports/progress.log` line before each, `build-for-testing` after each. Record each decision in `docs/DECISIONS.md` (Tessa, 2026-10-10). Stop after item 4. Don't start Chunk 3. No push.

## 1. No fix (offline): one secondary action, automatic retry

Why: offline, both Try again and the city search depend on the same connection (GPS can work, but naming the city needs a network, so it ends as No fix). Try again only helps if the user fixes the connection without leaving the app. Fixing it means leaving the screen (or opening Control Center), and the app should just work when they come back. iOS can't deep-link to Wi-Fi or cellular settings, so there's no useful primary action.

- **No primary button.** The only action is the secondary text link **"Enter a city instead"**. Keep the primary's 56 pt slot empty and hidden from VoiceOver, so the link sits at the same height as on the other causes' screens (the mirror image of Restricted, which keeps its secondary's spacer).
- **Body:** "Check your cellular or Wi-Fi connection. We'll look again when you come back." Set the default-size line breaks by hand; VoiceOver reads it as one sentence. Headline stays "Couldn't find your location".
- **Replaces §3 row 10:** when the scene becomes active after being inactive or backgrounded, and the failure is still No fix with access authorized, run one automatic search through the existing path (searching loader, then Aha and flight on success, or the same No fix screen on another miss, respecting `LocationLoader.minimumSearchBeforeMessage`).
  - At most one automatic retry per activation, and none while a search is in flight.
  - Check that dismissing Control Center produces the same inactive-to-active transition.
  - No connectivity monitor and no new dependency in this pass.
- Update every consumer of the old No fix copy and actions (launch message, failure screen, any dialog or test). Remove Try again's wiring only where it is now unreachable, and say what you removed.
- **Tests:** No fix has no primary; the link works; foreground retry fires once; two activations don't stack; a second miss returns to the same screen; Settings recovery for the other causes is unchanged.

## 2. Settings return as "not determined" goes to First ask

Why: "Ask Next Time Or When I Share" is not determined, and iOS can still show the system prompt in it. The telescope's Open Settings was the wrong action there, and the screen looped between the telescope and Settings. "While Using" must not be required.

- **Replaces §3 row 9, at launch and for explicit requests:** a return from Settings with status not determined goes to **First ask** (stopped moon, "Use my location", which triggers the system prompt on tap). No automatic prompt.
- Unchanged: unchanged blocked state keeps its guidance; a different blocked cause switches; newly authorized fetches once.
- **Permission-off chip** becomes **"Settings › Moon Signal › Location"** (set the two-line break and the VoiceOver label). The compass-only dialog uses the same text through the shared cause definition.
- "Never" in Settings is the app's own denial, so it stays the telescope. The map is only for the device-wide Location Services switch. No change.
- **Tests:** denied, then Ask Next Time in Settings, then return: First ask, then tap: prompt; no telescope loop. Rewrite the old "services on keeps guidance" test to the new rule.

## 3. Vertical alignment: moon screens match the illustrated screens

The First ask screen, the launch moon screens and the searching loader sit lower than the illustrated failure screens (headline at about 61% of the screen height against about 49%).

- Align them at the default size: the moon occupies the illustration's frame (240 × 312, top at 90 pt), headline top at 406 pt, primary and link at the same heights.
- The searching loader to illustration crossfade must not jump vertically.
- Find where the moon screens' constants live and reuse the failure layout's constants rather than duplicating them.
- **Preserve the Aha flight.** Re-verify its start position and path from the moved moon, and keep its tests passing, or update them with a note.
- Large text and Reduce Motion behave as today. Report measured positions before and after.

## 4. Crescent direction in the cause illustrations

The crescents in the telescope, map and locked-map art are lit on the left. They should be lit on the right, matching the app's waxing convention (the loader cycle already runs lit-right while waxing; don't change it).

- Mirror **only the moon layers** (`moon`, `moon-halo`, `moon-disc`) horizontally about the art's center line, in the `anim` SVGs for permission-off, services-off and restricted. Don't mirror the telescope or the map.
- Update the moon pivots in `IllustrationSpec` and `ILLUSTRATIONS_MOTION.md`. Re-run `scripts/slice_illustrations.py`. Do not redraw.
- Produce **before and after images of all three at the default size** for Tessa's approval, and commit this as its own change so it can be reverted.
- If mirroring breaks the composition (the moon colliding with the tube or the map), stop and report instead of adjusting by hand.

## Add to the follow-ups (§6 of the consolidation plan)

- **Searching cat in the launch flow.** Show the searching cat while locating; the moon still flies into the card on success, and the cat exits some way (wave goodbye, poof away, scamper off). To be explored later. `searching.svg` is delivered but unused.
- **Offline continuation.** If a fix succeeds but the city can't be named, continue with the coordinates labeled "Your location" (the moon times are computed on the device).
- A connectivity monitor that retries the moment a signal returns, without leaving the app.
