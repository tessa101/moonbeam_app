# Step 4: Compass

**Status:** Spec confirmed, ready for the agent's plan · **Decided:** 2026-09-27, updated 2026-09-28 · **Owner:** Tessa
**Fills:** PRODUCT.md — new "Compass" feature
**Depends on:** Step 2 location (built), Step 3 date selection (built, `docs/DATE.md`)
**Unblocks:** turning a rise/set bearing (e.g. 072°) into something you can actually point yourself at

---

## Problem

**Today:** The moon table gives rise/set direction as a bearing. Nothing helps you turn and actually face it.
**Change:** Add a live compass at the bottom of the main screen that shows device heading and calls out when you're pointed at moonrise, moonset, or the moon.

## 1. Placement & behavior

- Lives at the bottom of the main screen, below the moon table. Live while visible.
- Rotating dial, similar to Apple's Compass app: N/E/S/W + degree ticks, a fixed heading indicator, live device heading in large type (e.g. "72° E").
- Target bearings come from the **selected day and place** (Step 3 date picker + Step 2 location): moonrise azimuth and moonset azimuth.
- **"Moon" target:** only when the selected day is **today** and the moon is currently up. Shows its live azimuth, labeled **"Moon"**, same lock behavior. On any other date, only Moonrise/Moonset targets show.
- **Lock state:** when device heading is within tolerance of a target, the compass locks onto it and labels it — "Moonrise", "Moonset", or "Moon" — plus that target's bearing in the same style as the live heading (e.g. "Moonrise · 72° E").
- **Haptic + extra visual feedback on lock is a fast-follow, not required for v1** — ship the visual lock first, add haptic once it's working on device.

## 2. When the compass shows

The compass only makes sense where you're standing. "Where you are" comes from device location; searching a city can't prove you're in it.

| Location services | Selected place | Compass |
|---|---|---|
| On | Detected location | **Shown** |
| On | Searched city that matches detected city (`isSameCity`) | **Shown** |
| On | Any other city | **Hidden** |
| Off / denied / not determined | Any city | **Hidden, with an enable-location hint** |

- **Location off → enable to see it.** The compass needs location on: true-north heading from the device is only valid while location updates run, and magnetic heading alone is ~11–12° off in LA (outside lock tolerance). No manual "I'm here" override in v1.
- **Enable-location hint:** in place of the compass, a short message along the lines of "Turn on location to use the compass," leading into the existing Location Off dialog / permission flow. **Exact copy, placement, and flow TBD** — to be worked out in the design pass. The agent builds a plain placeholder.
- **Other city (location on):** hidden. Whether this state also gets a hint is open (§4).
- Past and future dates at your location still show the compass — rise/set bearings are useful for planning where to stand.

## 3. Rules

- **No GPS coordinates shown, at all.** Rejected as invasive — exact lat/long on screen means any screenshot exposes where someone lives. Only compass bearings/degrees are ever shown.
- **No elevation shown.** Rejected — elevation only makes sense as a live sensor reading, and the app has no way to detect it. Skipped rather than shown wrong/static.
- **Visibility logic stays simple:** moon up = visible. No altitude-angle math; clouds are the only exception, out of scope until weather is added.
- **True north, not magnetic** — matches Apple's Compass app. Use the device's true-north heading directly (CoreLocation `trueHeading`); don't compute declination ourselves.
- Live heading is always current; target bearings follow the selected day.

## 4. Defaults and open questions

**Confirmed (Tessa, 2026-09-28):**
- Lock tolerance: lock at ±5°, release at ±8° (the gap prevents flicker)
- Lock copy: "Moonrise · 72° E"
- Targets close together: nearest bearing wins, one label at a time
- Low accuracy: show a "Low accuracy" state when heading accuracy is poor (> ~20°) or unavailable; no custom calibration flow
- Wireframe: don't block on it — the agent builds a plain, unstyled version; layout and styling in the design pass

**Still open (design pass):**
- Enable-location hint: copy, placement, and whether it opens the existing Location Off dialog or the system prompt
- Other-city state: fully hidden, or a quiet note ("Compass is available at your current location")?

## 5. Tests (sketch — the agent firms these up in its plan)

- Fake heading provider (device compass isn't available in the simulator)
- Lock triggers within tolerance, releases outside release threshold
- Nearest target wins when two are within tolerance
- Target bearings pulled from the *selected* day and place, not always today
- "Moon" target only present when selected day is today and moon is up
- Visibility matrix (§2): shown at detected / same-city; hidden for other city; hint when location off, denied, or not determined
- Uses device true-north heading; shows low-accuracy state when true heading is unavailable or accuracy is poor

## 6. V2 (parking lot)

- Haptic feedback on lock (likely fast-follow rather than true V2)
- "I'm here" manual override for users who keep location off (magnetic heading + bundled magnetic-declination model)
- AR view (point the camera to "see" the moon) — no scope yet, just noted

---

## Decision log

- **2026-09-27 (Tessa):** Compass added at the bottom of the main screen — next step after Step 3, ahead of the design pass. GPS coordinates dropped from scope entirely (privacy: screenshot exposure). Elevation dropped (no live sensor to back it up). Visibility simplified to up/down + clouds-only, no altitude math. Lock state shows "Moonrise"/"Moonset"/"Moon" + bearing, never coordinates.
- **2026-09-28 (Tessa):** Step 3 date picker is built; compass binds to selected date and place. "Moon" target only on today. Compass shown only at the user's current location — hidden when a different city is selected. Location off → compass hidden with a hint to enable location (option A); no manual override in v1. Hint copy and flow to be worked out in the design pass.
- **2026-09-28 (Tessa):** §4 proposed defaults confirmed as written. Spec committed to the repo as `docs/COMPASS.md`.
