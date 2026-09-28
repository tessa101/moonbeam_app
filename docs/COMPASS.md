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
- Rotating dial, similar to Apple's Compass app: N/E/S/W + degree ticks, a fixed heading indicator, live device heading in large type (e.g. "72° ENE").
- **Direction names are 16-point** everywhere, from the existing `CompassFormatter` — same letters as the moon table, so one bearing never gets two names on screen. (Degrees-vs-letters order is still an open design-review item; the compass follows whatever the table settles on.)
- Target bearings come from the **selected day and place** (Step 3 date picker + Step 2 location): moonrise azimuth and moonset azimuth.
- **"Moon" target:** only when the selected day is **today** and the moon is currently up (§3). Shows its live azimuth, labeled **"Moon"**, same lock behavior. On any other date, only Moonrise/Moonset targets show.

### Lock

- **Lock at ±5°, release at ±8°** of a target bearing. The gap prevents flicker at the edge.
- **Nearest target wins** when acquiring a lock; one label at a time.
- **Hold until release:** once locked, the lock stays on that target until heading moves outside ±8° of it — even if another target becomes nearer. No switching mid-lock.
- **Lock copy:** target name + that target's bearing, same style as live heading — e.g. **"Moonrise · 72° ENE"**, "Moonset · 288° WNW", "Moon · 140° SE".
- **What lock does in v1:** visual change + label only. **No haptics in v1** — haptic feedback is a fast-follow once lock works on device (§7).

### Accuracy

- **Low-accuracy state** when device heading accuracy is worse than **15°**, or true heading is unavailable. Locking to ±5° means little beyond that. No lock while in low accuracy; no custom calibration flow.
- 15° is a starting value — tune after device testing.

### Targets & refresh

- A day with no moonrise or no moonset (ASTRONOMY.md §4) simply has no target for it.
- **"Moon" target refresh:** every **30 s** while the compass is on screen, recompute the moon's azimuth **and re-check moon-up** — so the target appears or disappears if the moon rises or sets while you're looking. Also recompute immediately on return to foreground, and when the selection becomes today.

### Sensor lifecycle

- Heading updates **and the location updates that true heading depends on** start together and stop together.
- **Stop when the compass scrolls off screen or is hidden** (§2 state change), and on background. The main screen is a non-lazy `VStack` in a `ScrollView`, so `onAppear`/`onDisappear` fire only on insert/remove, not on scroll — scroll-out uses `onScrollVisibilityChange` (iOS 18+; target is 26). If that proves unreliable on device, background-only stop is acceptable for v1.
- Sheets (search, calendar, location off) cover the compass without firing either; v1 leaves sensors running under a sheet.

### Orientation

- **App locked to portrait for v1** (`INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = UIInterfaceOrientationPortrait`; built). A rotating screen makes the compass hard to read and complicates heading.
- **v1 is iPhone-only** (`TARGETED_DEVICE_FAMILY = 1`, was `1,2`, on the app and test targets; the iPad orientation key is removed; built). Portrait-locking iPad would fight iPad multitasking; iPad support is a later step.
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
- **"Moon is up" = its most recent rise is later than its most recent set**, both found with the **same rise/set search the moon table uses** (upper limb, standard refraction — ASTRONOMY.md). One definition, so the compass can never disagree with the table. Searches backward from *now*, not within the selected day, so it covers the moon that rose last night and is still up this morning. A plain altitude > 0° check was rejected: it measures the disc's centre and would disagree with the table for a minute or two at every rise and set.
- **Visibility stays simple:** up = visible. No "can you actually see it" math (terrain, buildings, minimum viewing angle). Clouds are the only exception, out of scope until weather is added.
- **True north, not magnetic** — matches Apple's Compass app. Use the device's true-north heading directly (CoreLocation `trueHeading`); don't compute declination ourselves.
- Live heading is always current; target bearings follow the selected day.

## 4. Data model

**Approved (G), additive only.** Rise/set bearings already exist (`MoonEvent.azimuth`, true north), so `MoonDay` and `MoonEvent` are unchanged.

```swift
/// Where the moon is in the sky at one moment, seen from one place.
nonisolated struct MoonPosition: Equatable {
    /// Degrees clockwise from true north.
    let azimuth: Double
    /// True when the moon is above the horizon, using the same definition as rise/set.
    let isUp: Bool
}

nonisolated protocol MoonService {
    func moonDay(for place: Place, on date: Date) -> MoonDay
    func moonPosition(for place: Place, at date: Date) -> MoonPosition   // new
}
```

- `AstronomyEngineMoonService` and `FakeMoonService` both implement it.
- New `HeadingService` protocol (CoreLocation + fake): true heading, accuracy, and start/stop that also drives the continuous location updates true heading needs. No new dependency.
- Readings are a new value type, `HeadingReading` (`trueHeading: Double?`, `accuracy: Double?`, derived `isLowAccuracy`), built in 4.2. `nil` means CoreLocation reported the value as invalid. There's no magnetic field, so nothing can fall back to magnetic.

## 5. Open questions

- Enable-location hint: final copy, placement, and whether it opens the existing Location Off dialog or the system prompt (design pass)
- Other-city state: fully hidden, or a quiet note ("Compass is available at your current location")? v1 build: fully hidden.
- Wireframe: layout, typography, and how the compass sits under the moon table (design pass — v1 build is plain/unstyled)

## 6. Tests

- Fake heading provider (device compass isn't available in the simulator)
- Lock acquires within ±5°, releases outside ±8°
- Nearest target wins on acquire; lock holds on current target until release even if another becomes nearer
- Low-accuracy state when accuracy > 15° or true heading unavailable; no lock in that state
- Target bearings pulled from the *selected* day and place, not always today
- "Moon" target only present when selected day is today and the moon is up (§3) — including moon-up-since-last-night case
- "Moon is up" agrees with rise/set times at the boundaries (same horizon definition): down one minute before the table's rise, up one minute after; mirrored at set
- Lock and heading labels use 16-point names (e.g. 72° → ENE), matching `CompassFormatter`
- Visibility matrix (§2): shown at detected / same-city; hidden for other city; hint when location off, denied, or not determined
- 30 s tick adds the "Moon" target when the moon rises and removes it when it sets; foreground triggers an immediate recompute (fake clock)
- Heading and location updates start/stop together: on show, hide, scroll-out, background

## 7. V2 (parking lot)

- Haptic feedback on lock (fast-follow)
- Landscape support (heading orientation matched to device)
- iPad support
- "I'm here" manual override for users who keep location off (magnetic heading + bundled magnetic-declination model)
- AR view (point the camera to "see" the moon) — no scope yet, just noted
- **Expire the detected place after N hours.** v1 keeps the last detected place for the whole session, and a failed fix doesn't clear it (DECISIONS.md 2026-09-28, Step 4.3). Edge case: you're detected in LA, travel with the app backgrounded (not terminated), then a fix fails in the new city. A searched "Los Angeles" would still show the compass, with LA's bearings, though you're no longer there. Fix: give the detected place a timestamp and stop counting it after N hours (N TBD)

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
- **2026-09-28 (Tessa, follow-up defaults):** other-city fully hidden in v1; no target for a missing rise/set; "Moon" target refreshes every 30 s (azimuth + moon-up re-check) and immediately on foreground; heading and its location updates stop together when the compass leaves the screen or the app backgrounds (background-only acceptable for v1 if scroll-out detection is unreliable).
- **2026-09-28 (Tessa, final four):** `MoonPosition` + `moonPosition(for:at:)` approved (G resolved). Moon-up = latest rise after latest set, via the table's rise/set search (supersedes "from altitude" in C). v1 iPhone-only; portrait lock applies to iPhone. 16-point direction names throughout.
