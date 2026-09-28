# Step 4: Compass

**Status:** Ready for build (wireframe pending — layout/styling in design pass) · **Decided:** 2026-09-27, updated 2026-09-28 · **Owner:** Tessa
**Fills:** PRODUCT.md — new "Compass" feature
**Depends on:** Step 2 location (built), Step 3 date selection (built)
**Unblocks:** turning a rise/set bearing (e.g. 072°) into something you can actually point yourself at

---

## Problem

**Today:** The moon table gives rise/set direction as a bearing. Nothing helps you turn and actually face it.
**Change:** Add a live compass at the bottom of the main screen that shows device heading and calls out when you're pointed at moonrise, moonset, or the moon.

## 1. Placement & behavior

- Lives at the bottom of the main screen, below the moon table. Live while visible.
- Rotating dial, similar to Apple's Compass app: N/E/S/W + degree ticks, a fixed heading indicator, live device heading in large type (e.g. "72° E").
- Target bearings come from the **selected day and place** (Step 3 date picker + Step 2 location): moonrise azimuth and moonset azimuth.
- **"Moon" target:** only when the selected day is **today** and the moon is currently up (§3). Shows its live azimuth, labeled **"Moon"**, same lock behavior. On any other date, only Moonrise/Moonset targets show.

### Lock

- **Lock at ±5°, release at ±8°** of a target bearing. The gap prevents flicker at the edge.
- **Nearest target wins** when acquiring a lock; one label at a time.
- **Hold until release:** once locked, the lock stays on that target until heading moves outside ±8° of it — even if another target becomes nearer. No switching mid-lock.
- **Lock copy:** target name + that target's bearing, same style as live heading — e.g. **"Moonrise · 72° E"**, "Moonset · 288° W", "Moon · 140° SE".
- **What lock does in v1:** visual change + label only. **No haptics in v1** — haptic feedback is a fast-follow once lock works on device (§7).

### Accuracy

- **Low-accuracy state** when device heading accuracy is worse than **15°**, or true heading is unavailable. Locking to ±5° means little beyond that. No lock while in low accuracy; no custom calibration flow.
- 15° is a starting value — tune after device testing.

### Orientation

- **App locked to portrait for v1** (Info.plist). A rotating screen makes the compass hard to read and complicates heading.
- Revisitable: upgrade path is allowing rotation and setting the heading orientation to match the device. Logged in DESIGN-REVIEW.md as a deliberate choice (WCAG 1.3.4 permits orientation lock where essential; a compass qualifies).

## 2. When the compass shows

The compass only makes sense where you're standing. "Where you are" comes from device location; searching a city can't prove you're in it.

| Location services | Selected place | Compass |
|---|---|---|
| On | Detected location | **Shown** |
| On | Searched city that matches detected city (`isSameCity`) | **Shown** |
| On | Any other city | **Hidden** |
| Off / denied / not determined | Any city | **Hidden, with an enable-location hint** |

- **Location off → enable to see it.** True-north heading is only valid while location updates run, and magnetic heading alone is ~11–12° off in LA (outside lock tolerance). No manual "I'm here" override in v1.
- **Enable-location hint:** in place of the compass, a short message along the lines of "Turn on location to use the compass," leading into the existing Location Off flow. **Exact copy, placement, and flow TBD** in the design pass; v1 build uses plain text + a button to the existing Location Off flow.
- **Other city (location on):** hidden. Whether this state also gets a quiet note is open (§5).
- Past and future dates at your location still show the compass — rise/set bearings are useful for planning where to stand.

## 3. Rules

- **No GPS coordinates shown, at all.** Rejected as invasive — exact lat/long on screen means any screenshot exposes where someone lives. Only compass bearings/degrees are ever shown.
- **No elevation shown.** Rejected — elevation only makes sense as a live sensor reading, and the app has no way to detect it.
- **"Moon is up" = moon's altitude above the horizon**, using the **same horizon definition as the rise/set calculation** so it always agrees with the moon table. Not derived from the selected day's rise/set times — those miss the case where the moon rose last night and is still up this morning.
- **Visibility stays simple:** up = visible. No "can you actually see it" math (terrain, buildings, minimum viewing angle). Clouds are the only exception, out of scope until weather is added.
- **True north, not magnetic** — matches Apple's Compass app. Use the device's true-north heading directly (CoreLocation `trueHeading`); don't compute declination ourselves.
- Live heading is always current; target bearings follow the selected day.

## 4. Data model

- **Pending (G):** the agent's plan proposes a protocol change to the moon data model. Per CLAUDE.md, show the exact change for review before touching it. Additive fields (e.g. rise/set azimuths) are likely fine; renames or removals of anything existing need a closer look.

## 5. Open questions

- Enable-location hint: final copy, placement, and whether it opens the existing Location Off dialog or the system prompt (design pass)
- Other-city state: fully hidden, or a quiet note ("Compass is available at your current location")?
- Wireframe: layout, typography, and how the compass sits under the moon table (design pass — v1 build is plain/unstyled)

## 6. Tests

- Fake heading provider (device compass isn't available in the simulator)
- Lock acquires within ±5°, releases outside ±8°
- Nearest target wins on acquire; lock holds on current target until release even if another becomes nearer
- Low-accuracy state when accuracy > 15° or true heading unavailable; no lock in that state
- Target bearings pulled from the *selected* day and place, not always today
- "Moon" target only present when selected day is today and moon altitude is above the horizon — including moon-up-since-last-night case
- "Moon is up" agrees with rise/set times at the boundaries (same horizon definition)
- Visibility matrix (§2): shown at detected / same-city; hidden for other city; hint when location off, denied, or not determined

## 7. V2 (parking lot)

- Haptic feedback on lock (fast-follow)
- Landscape support (heading orientation matched to device)
- "I'm here" manual override for users who keep location off (magnetic heading + bundled magnetic-declination model)
- AR view (point the camera to "see" the moon) — no scope yet, just noted

---

## Decision log

- **2026-09-27 (Tessa):** Compass added at the bottom of the main screen — next step after Step 3, ahead of the design pass. GPS coordinates dropped from scope entirely (privacy: screenshot exposure). Elevation dropped (no live sensor). Visibility simplified to up/down + clouds-only. Lock state shows "Moonrise"/"Moonset"/"Moon" + bearing, never coordinates.
- **2026-09-28 (Tessa):** Step 3 date picker is built; compass binds to selected date and place. "Moon" target only on today. Compass shown only at the user's current location — hidden for other cities. Location off → hidden with enable-location hint; no manual override in v1.
- **2026-09-28 (Tessa, agent questions A–G):**
  - A: show only at detected location / same-city match (per §2)
  - B: lock holds until release; no switching mid-lock
  - C: moon-up from altitude, same horizon definition as rise/set
  - D: low-accuracy threshold 15°, tune on device
  - E: lock is visual + label only in v1; haptics fast-follow
  - F: app locked to portrait for v1; landscape revisitable
  - G: protocol change pending review — agent to show exact change first
