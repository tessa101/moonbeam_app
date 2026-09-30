# Step 4: Compass

**Status:** Built, plain v1 (4.1–4.4). **Follow-ups 4.5–4.13 built (4.11–4.13 on 2026-09-30).** Device QA pending, STATUS.md Next 7. Wireframe pending — layout/styling in design pass · **Decided:** 2026-09-27, updated 2026-09-29 · **Owner:** Tessa
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
- **What lock does:** visual change + label, plus **one firm haptic tap when a lock is acquired** (4.5). No haptic on release or while holding. Follows the system haptics setting.
- **Readout:** the compass shows only the live heading ("72° ENE") and the lock label. **No target rows under the dial** (4.7) — rise/set bearings are already in the moon table above. Dots on the dial are unlabelled until locked (design pass). **VoiceOver reads the targets from the dial** as one element ("Targets: moonrise, 72 degrees east-northeast; moon, 140 degrees southeast"), since the live moon's bearing appears nowhere else.

### Accuracy

- **Low-accuracy state, with hysteresis like the lock:** it **enters** when device heading accuracy is worse than **25°**, and **leaves** only when it's better than **20°**. In between, it keeps its current state. It's always low with no true heading or unknown accuracy. No lock while in low accuracy; no custom calibration flow.
- *Why (device test 2026-09-29):* the DEBUG readout showed iOS's reported accuracy wandering ±11.8° (locked) → ±27.3° (low, phone charging) → ±13.4° (locked). With the original single 15° line, the compass flipped in and out of low accuracy as it wandered. It wasn't stuck. 25/20 is the new starting value; tune further on device if needed.
- **Low-accuracy reason, inline (4.10, decided 2026-09-29):** in low accuracy, one plain line under the heading says *why*, so the user can fix it:
  - **Precise Location off** (`accuracyAuthorization == .reducedAccuracy`): "Precise Location is off" + a button to Settings — **superseded by 4.12** (below)
  - **Otherwise** (poor accuracy, cause unknown): "Move away from metal, magnets or a charger, or wave your phone in a figure 8". "Charger" was added after the device test, where charging took accuracy to ±27°.
  - Placeholder copy. No ⓘ / sheet for now; revisit in the design pass if more causes or detail are needed.
  - *As built:* the reason line **replaces** the generic "Compass accuracy is low" line. The generic line shows only when no cause is known: no reading yet, or no compass at all, where neither the tip nor Settings would help. VoiceOver reads the pair: "Compass accuracy is low. Precise Location is off". **Open Settings** sits outside that element so VoiceOver can reach it, and opens the app's page in Settings, where Location › Precise Location lives. The reason follows the hysteresis, so it stays until accuracy is back below 20°.
- **Precise Location off → no lock (device test 2026-09-30):** iOS still sends a true heading with Precise off, but reports accuracy of ±81–86°. So the compass stays in low accuracy: dial visible and greyed, no lock, no haptic. Right after switching Precise off, readings can stay good for a while; the reduced accuracy shows after a pause or relaunch.
- **Precise Location is the default, opt-out (4.12, decided 2026-09-30):**
  - Remove `NSLocationDefaultAccuracyReduced` from Info.plist, so the system permission prompt shows **Precise: On** by default. Users have to opt out.
  - The permission prompt's text (`NSLocationWhenInUseUsageDescription`) tells them in that moment that the compass needs Precise Location: *"Moon Signal uses your location to show when and where the moon rises and sets, and to point the compass. Keep Precise Location on so the compass can find the moon."* (placeholder)
  - Existing installs keep whatever they have; people already on approximate get the flow below.
- **If they opted out: ask in context with a temporary prompt (4.12).** Replaces the 4.10 "Precise Location is off" line and its Open Settings button:
  - Line: **"We think you're near {City}, but the compass needs Precise Location to point the right way."** {City} is the selected place (Here or Nearby). Placeholder copy.
  - Button: **"Use Precise Location"** → `requestTemporaryFullAccuracyAuthorization(withPurposeKey:)`. iOS shows an in-app alert with our purpose string; one tap, no trip to Settings. Lasts for this session of use; iOS reverts it later, and the line comes back next time.
  - Info.plist `NSLocationTemporaryUsageDescriptionDictionary`, key `Compass`: *"The compass needs Precise Location to point at the moon. We never see your location, and it's never shown on screen."* (placeholder; see §3 Privacy wording)
  - ~~Secondary text link **"Always use Precise Location"** → the app's page in Settings, for people who don't want to be asked every session.~~ **Removed (4.14, 2026-09-30):** two CTAs felt wrong. **One button only: "Use Precise Location".**
  - **The alert is Apple's and can't be changed (4.14):** the temporary full-accuracy alert only ever offers **Don't Allow / Allow Once**. "Allow While Using App" exists only on the first location-permission prompt; iOS has no API to make Precise permanent from inside an app. Permanent Precise is Settings › Moon Signal › Location › Precise Location, which the user finds on their own for now. (Design pass may revisit a gentle "keep it on" nudge after the aha line.)
  - If the user declines the alert, nothing changes: same line, same button.
- **Aha moment (4.12):** when Precise Location turns on **while the compass is on screen** (from the button above, or on return from Settings), the reason line is replaced for ~3 s by **"There you are! The compass is happy now."** (placeholder), then fades to the normal readout. VoiceOver announces it. It shows **only on that change** (`accuracyAuthorization` reduced → full), never on an ordinary recovery from low accuracy (charger, metal), which would make it constant. No extra haptic; the first lock's tap is the payoff.
- *As built (4.12):* `LocationService.requestTemporaryPreciseLocation(purposeKey:)` wraps the async `requestTemporaryFullAccuracyAuthorization`; the purpose key is `LocationViewModel.compassPrecisePurposeKey` (`"Compass"`), and a test checks the app's Info.plist has it, and no `NSLocationDefaultAccuracyReduced`. After the alert the compass gets a fresh context straight away. Use Precise Location is a bordered button outside the heading's VoiceOver element (4.14: now the only button; the "Always…" link and its Settings action are gone). The aha line counts as "on screen" when the compass is shown and scrolled into view, **not** foreground: on return from Settings the new context arrives before the scene is active again. It uses the view model's injected sleep, so tests clear it by hand. VoiceOver hears it as an announcement.
- **Stuck low accuracy is a bug, not a reason (4.9):** device test 2026-09-29 showed "Compass accuracy is low" that only cleared after toggling Settings › Moon Signal › Location off/on. Fixed at the sensor level (with the 4.8 overnight bug), not explained to the user.
  - *As built:* iOS's automatic pause of location updates is off. For When In Use apps a pause ends location updates until the app restarts them, and true heading goes with them; a phone held still for a compass is exactly when iOS pauses. A `HeadingSessionMonitor` restarts location updates when readings keep a magnetic heading but no true heading for 5 s (at most every 10 s), or on a pause. It restarts the whole session when authorization or Precise Location changes while it's running.
  - *4.8 (compass gone after overnight):* the likely path is the app relaunching, the launch fix failing, and "Nothing detected" never being retried. Now each foreground retries detection quietly while authorized with nothing detected. It's detection only, so the place never changes and a failure shows nothing.

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

The rule is **near**, not **same city** (4.6): moonrise/moonset bearings depend mostly on latitude, and within 60 mi they differ by well under 1° — inside the ±5° lock.

| State | When | Compass | Message (placeholder copy) |
|---|---|---|---|
| **Location off** | Off / denied / not determined | Hidden | "Turn on location to use the compass" + **Turn On Location** button |
| **Here** | Selected place is the detected city (`isSameCity`) | **Shown** | none |
| **Nearby** | Different city, within **60 mi (~97 km)** of the detected location | **Shown** | "You're in {Detected city} but {City} is nearby" (4.11; was "Directions for {City}") |
| **Far** | More than 60 mi from the detected location | Hidden | "You're a bit too far from {City} to view the compass accurately" (4.11; was "Compass is only available near this location") |
| **Nothing detected** | Location on, no fix yet / failed with no earlier fix | Hidden | none |

- **Location off → enable to see it.** True-north heading is only valid while location updates run, and magnetic heading alone is ~11–12° off in LA (outside lock tolerance). No manual "I'm here" override in v1.
- **Turn On Location keeps the searched city (4.6).** From the compass hint, the button turns on location and updates *detection only* — it does **not** switch the selected place to the detected one. The states above then apply (Here / Nearby / Far). The main screen's existing "Use my location" button keeps its current behavior. **This includes the trip through Settings** (Tessa, 2026-09-29): if the Location Off dialog was opened from the compass hint, the automatic fetch on return from Settings (LOCATION.md §4) also updates detection only. From the main button, that fetch still switches to the detected place.
- **Main-screen "Use my location" button removed (4.11, 2026-09-30),** except on the empty first-launch state (no place saved yet). Device test: next to the Nearby note it read as confusing and disconnected. Returning to your location is the "Use my location" row in the search sheet (SEARCH-RECENTS.md), which keeps the switch-to-detected behavior. *As built:* the sheet row keeps its old rule (shown whenever the place isn't the detected location); the main button adds "and no place yet". The user can search anywhere; the compass area only says when the place isn't exactly where they are, or why the compass is gone.
- **City names use "City, ST" (4.13):** {City} and {Detected city} in the Nearby, Far and Precise copy read like "Irvine, CA" (LOCATION.md "Place name on screen").
- **Nearby/Far name the cities, never the distance.** Showing the detected city is city-level, the same as the search field already shows when viewing your location.
- **Nearby note says what it shows, not that it's wrong.** At ≤60 mi the error is under 1°, so no "may not be exact" wording.
- **Never show the distance** ("25 mi away") — with the city name, a screenshot would reveal roughly where someone is (same reason GPS coordinates were dropped).
- Distance is measured between the detected location and the selected place's coordinates; neither is ever shown.
- All copy is placeholder; final copy in the design pass (DESIGN-REVIEW.md).
- Past and future dates at your location still show the compass — rise/set bearings are useful for planning where to stand.

## 3. Rules

- **Privacy wording (4.12 research, 2026-09-30).** What the app may say about location, and why:
  - **Can say:** "We never see your location" / "we don't collect it": the app has no servers, no analytics and no networking of its own (no `URLSession`, no SDKs). Apple's definition of *collect* is sending data off the device where the developer can access it beyond the real-time request, and Apple says developers aren't responsible for disclosing what Apple's own frameworks (MapKit) collect. The App Store privacy label can be **Data Not Collected**.
  - **Can say:** "It's never shown on screen": true today (no coordinates, no distance; city names only).
  - **Can't say:** "never leaves your phone" or "never shared". City search and reverse geocoding (`MKReverseGeocodingRequest`) send it to Apple.
  - **Can't say (today):** "we don't store it". The detected place is saved on the phone as last-viewed, with the reverse-geocoded coordinates (UserDefaults). It stays on the device, but it is stored.
  - **Must:** App Review 5.1.1(ii): purpose strings must "clearly and completely describe your use of the data", so the permission text names the compass as well as rise/set. 5.1.5: notify and get consent before using location.
  - **Revisit these claims** if the app ever adds analytics, crash reporting with location, a backend or a widget that syncs.

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
- Readings are a new value type, `HeadingReading` (`trueHeading: Double?`, `accuracy: Double?`), built in 4.2. Its derived `isLowAccuracy` moved out to `CompassAccuracy` with the hysteresis (2026-09-29), because the rule needs the previous state. `nil` means CoreLocation reported the value as invalid. There's no magnetic field, so nothing can fall back to magnetic.

## 5. Open questions

- Enable-location hint: final copy, placement, and whether it opens the existing Location Off dialog or the system prompt (design pass)
- ~~Other-city state~~ **Settled 2026-09-29:** replaced by the Nearby / Far states (§2, 4.6).
- Final copy for the Nearby note and Far message (design pass). Far may later add something like "we can still show you the data for the city you searched" or "search for a city near you to see the compass"
- Wireframe: layout, typography, and how the compass sits under the moon table (design pass — v1 build is plain/unstyled)

## 6. Tests

- Fake heading provider (device compass isn't available in the simulator)
- Lock acquires within ±5°, releases outside ±8°
- Nearest target wins on acquire; lock holds on current target until release even if another becomes nearer
- Low-accuracy hysteresis: enter above 25°, leave below 20°, keep state in between; always low with no true heading or unknown accuracy; no lock in that state
- Target bearings pulled from the *selected* day and place, not always today
- "Moon" target only present when selected day is today and the moon is up (§3) — including moon-up-since-last-night case
- "Moon is up" agrees with rise/set times at the boundaries (same horizon definition): down one minute before the table's rise, up one minute after; mirrored at set
- Lock and heading labels use 16-point names (e.g. 72° → ENE), matching `CompassFormatter`
- Visibility matrix (§2): Here and Nearby shown; Far hidden with message; nothing detected hidden; hint when location off, denied, or not determined
- 60 mi boundary: just inside → Nearby, just outside → Far (e.g. Huntington Beach from LA = Nearby; San Diego from LA = Far)
- Nearby note never contains a distance; it names the detected city and the selected city
- Far message names the selected city
- Main-screen "Use my location" shown only on the empty first-launch state; the sheet row still switches to the detected place
- Precise off (reduced): the "We think you're near {City}…" line, Use Precise Location calls the temporary request with purpose key `Compass`; it's the only button (4.14)
- Declining the temporary alert leaves the state unchanged
- Aha line appears once on reduced → full while visible, clears after ~3 s; never on a low → good accuracy recovery with full accuracy throughout
- Turn On Location from the compass hint keeps the searched place selected; the main "Use my location" still switches to the detected place
- Haptic fires once on lock acquire; not on release, not while holding, not on a hold that continues across readings
- No target rows rendered under the dial
- 30 s tick adds the "Moon" target when the moon rises and removes it when it sets; foreground triggers an immediate recompute (fake clock)
- Heading and location updates start/stop together: on show, hide, scroll-out, background

## 7. V2 (parking lot)

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
- **2026-09-29 (Tessa, first device test):** Compass works at a basic level on device. Three follow-ups:
  - **4.5 Haptics:** one firm tap on lock acquire; none on release. Promoted from fast-follow.
  - **4.6 Proximity:** "same city" → "within 60 mi". States: Here (no note), Nearby (shown + "Directions for {City}"), Far (hidden + "Compass is only available near this location"). No distance ever shown (privacy). Turn On Location from the compass hint keeps the searched city. Supersedes the 2026-09-28 "other-city fully hidden" default.
  - **4.7 Remove target rows** under the dial; keep heading readout + lock label. Rows duplicated the moon table.
- **2026-09-29 (Tessa, agent questions before 4.6/4.7):**
  - Settings trip from the compass hint → the fetch on return is detection-only; the main button's is unchanged (§2).
  - With the rows gone, the dial becomes one VoiceOver element that reads its targets ("Targets: moonrise, 72 degrees east-northeast; moon, 140 degrees southeast"). No visible change (4.7).
- **2026-09-29 (Tessa, device test):** low accuracy got stuck until Location was toggled in Settings → sensor restart bug (4.9, with 4.8). Haptic still missing after a lock. Low-accuracy reason shown **inline** under the heading (4.10); ⓘ sheet deferred to the design pass.
- **2026-09-30 (Tessa, precise flow):** 4.12. Fresh installs have no location until asked; when they agree, Precise defaults **on** (drop `NSLocationDefaultAccuracyReduced`) and the prompt text says the compass needs it. Opt-outs get "We think you're near {City}, but the compass needs Precise Location to point the right way" + **Use Precise Location** (temporary full-accuracy alert carrying the privacy wording) + "Always use Precise Location" → Settings. Aha line "There you are! The compass is happy now." only on reduced → full. Privacy wording rules in §3.
- **2026-09-30 (Tessa, 4.12 device test):** 4.14: remove "Always use Precise Location"; one button. The temporary alert's Don't Allow / Allow Once is fixed by iOS (no "Allow While Using"), so permanent Precise stays a Settings-only path.
- **2026-09-30 (Tessa, device test):** 4.10 reasons both seen on device (Precise off; interference while charging). Precise off never locks (±81–86°): keep as is. Location off hides the compass: as specced. Nearby/Far work (LA, Los Feliz, Huntington Beach = Nearby from Irvine; La Jolla = Far). **4.11:** Nearby note → "You're in {Detected city} but {City} is nearby"; Far → "You're a bit too far from {City} to view the compass accurately"; main-screen "Use my location" removed except on the empty first-launch state.
- **2026-09-30 (Tessa):** 4.15 — fix content scrolling under the status bar now, not in the design pass. Spec in STATUS.md 7.6.
