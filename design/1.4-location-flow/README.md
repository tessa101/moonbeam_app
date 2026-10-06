# Handoff: Location loader + location-off flow (Moon Signal, iOS)

## Overview
This flow replaces the placeholder "Where can I find the moon today in a city?" screen. On every launch, the app shows the onboarding moon loader while it gets a location fix. If it can't get one, because permission was never asked, permission is denied, Location Services are off, or the fix timed out, the moon stops and pulses, and a message explains what to do. Once that's fixed, the search resumes, then "Aha! There you are.", then the city screen.

## About the design files
`Location Flow Prototype.dc.html` is a **design reference built in HTML**, not production code. Open it in a browser to watch each scenario; `support.js` must sit next to it. Rebuild the flow natively in the app's existing SwiftUI codebase, using its patterns, fonts, and colors. `LocationFlowReference.swift` is a starting sketch of the state machine and moon animation, not drop-in code.

## Fidelity
High fidelity. Colors, type, timing, and copy are final. All measurements are in points on a 393 × 852 canvas (iPhone 15/16 Pro). Position the moon from screen center, not from absolute y.

---

## Screens and states

All states share one screen with a `#1B1519` background, plus a soft top glow: an ellipse about 520 × 420 pt centered 120 pt above the top edge, a radial gradient from `rgba(242,194,123,0.08)` to transparent.

### 1. Searching (loader)
- **Moon:** 132 pt circle, centered horizontally, center at y = 413 (about 13 pt above screen center). Lit color `#F2E6CF`, outer shadow `0 0 40 rgba(242,194,123,0.35)`.
- **Phase shadow:** a `#1B1519` circle the same size as the moon, clipped to the moon's circle, sliding horizontally (see Animation).
- **Glow:** a radial gradient circle 2.2× the moon's diameter (extends 60% past each edge), from `rgba(242,194,123,0.32)` to transparent. It "breathes" while searching.
- **Label:** "Finding your location…" in Nunito Sans Regular 16/21, color `#C9B7A6`, centered, top at y = 510.

### 2. Message (search stopped)
The moon stays exactly in place, finishes its phase, stops at the onboarding phase, and the glow pulses. The label is replaced by a centered block from y = 500 with 28 pt side insets and a 40 pt bottom inset:
- **Headline:** Young Serif 28 / 1.22, `#F5EADB`, balanced wrap.
- **Body:** Nunito Sans Regular 17 / 1.45, `#E4D6C6`, 12 pt below the headline.
- **Spacer** (flexible).
- **Primary button:** full width, 56 pt tall, radius 28, fill `#F2C27B`, label Nunito Sans Bold 18 `#1B1519`, shadow `0 0 30 rgba(242,194,123,0.18)`.
- **Secondary link:** "Search for a city instead", Nunito Sans SemiBold 17, `#F2C27B`, 22 pt below the button. It opens the existing city search.

| Scenario | Condition | Headline | Body | Button → action |
|---|---|---|---|---|
| First ask | `authorizationStatus == .notDetermined` | Find the moon from where you are | Moon Signal uses your location to show when and where the moon rises and sets. | **Use my location** → `requestWhenInUseAuthorization()` |
| App permission off | `.denied` and services enabled | Moon Signal can’t see your location | Allow location access to see where the moon is from here. | **Open Settings** → `UIApplication.openSettingsURLString` |
| Location Services off | `CLLocationManager.locationServicesEnabled() == false` | Location Services are off | Turn them on to see where the moon is from here. | **Open Settings** → same URL (iOS can't deep-link to the system switch) |
| No fix | Authorized, no fix after 10 s | Couldn’t find your location | Check your signal and try again, or search for a city. | **Try again** → restart the search in place |

- `.restricted` (parental controls): use the app-permission copy. Decide whether to hide Open Settings, since the user can't change it.
- Don't Allow in the system prompt: switch to the "App permission off" message.

### 3. System prompt (first ask only)
This is the native CoreLocation alert, drawn over the paused loader with the message still visible underneath (see `reference/system-permission-prompt.png`). The purpose string (`NSLocationWhenInUseUsageDescription`) is:
> Moon Signal uses your location to show when and where the moon rises and sets, and to point the compass. Keep Precise Location on so the compass can find the moon.

### 4. Searching again
Same as state 1.

### 5. Found: "Aha!"
- "Aha! There you are." in Young Serif 25 / 1.2, `#F5EADB`, single line, centered, top at y = 506.
- City row 10 pt below it: a 14 × 17 pin icon (stroke `#F2C27B`, 1.8 pt, filled dot) with 6 pt gap, then the city ("Rancho Santa Margarita, CA") in Nunito Sans SemiBold 16 `#F2C27B`.
- The moon runs to full and the glow flares once.

### 6. City screen
The existing main screen. The moon flies from the loader into the 44 pt phase circle at the top-left of the info card (in the prototype that's x = 39, y = 253, but use the real frame of that slot) and settles on the real current phase.

---

## Animation and timing

### Moon phase cycle (identical to the onboarding loader)
- One cycle lasts 4.8 s and loops.
- The shadow circle's x offset, as a fraction of the moon's diameter:
  - First half: 0 → +1.0
  - At 50% it jumps to −1.0
  - Second half: −1.0 → 0
- Each half uses `cubic-bezier(0.45, 0, 0.55, 1)`.
- The **onboarding hold phase** is offset +0.75, which leaves a dark sliver on the right.
- **Stopping:** keep advancing forward at 2.6× speed until the offset reaches the hold phase, then freeze. Never pause mid-cycle, because that can leave a new (fully dark) moon. The message appears only after the moon has frozen.
- **Glow:**
  - Searching ("breathe"): 4.8 s ease-in-out loop, opacity 0.45 → 1 → 0.45, scale 0.92 → 1.06.
  - Stopped ("pulse"): 1.8 s ease-in-out loop, opacity 0.35 → 1, scale 0.9 → 1.18.
  - "Aha" ("flare"): 1.4 s ease-out, once, opacity 0.5 → 1 → 0.8, scale 1 → 1.7 → 1.15.

### Entrance (every launch)
| t | What happens |
|---|---|
| 0 ms | The moon, already at the hold phase, fades in (opacity 0→1, 0.9 s ease-out) and rises 8 pt (1.2 s, `cubic-bezier(0.16,1,0.3,1)`). |
| 320 ms | The label does the same: opacity 0.7 s ease-out, rises 8 pt over 0.9 s with the same curve. |
| 840 ms | The phase cycle starts. |

### Search → message
- Show the search for **at least 1.2 s** before any message, even when the status is already known. This makes it feel like the app looked first.
- When the moon freezes, the label fades out over 0.3 s. The message then fades in (0.45 s, 0.35 s delay) and rises 16 pt (0.6 s, `cubic-bezier(0.2,0.7,0.3,1)`).

### Return after a fix (shipped option: "gone instantly")
- Trigger: `locationManagerDidChangeAuthorization`, or `scenePhase == .active` with permission now granted. For No fix, it's tapping Try again.
- The message is removed **immediately** (no animation). The moon stays put and its glow switches from pulse back to breathe.
- 0.2 s later, the label fades and rises in (same as the entrance), and the phase cycle resumes.
- If the user returns and permission is still off, stay on the message and keep pulsing.

### Search → Aha → city
- Keep "Finding your location…" up for at least 1.8 s after it appears. Then fade it out over 0.3 s.
- "Aha" fades in over 0.6 s (0.5 s delay) and rises 10 pt (0.8 s, `cubic-bezier(0.16,1,0.3,1)`). The moon advances to full and the glow flares.
- Hold for about 2.0 s, then go to the city screen:
  - "Aha" fades out **fast**: 0.22 s, drifting up only 3 pt.
  - The moon moves and shrinks into the card's phase slot over 0.85 s, `cubic-bezier(0.65,0,0.25,1)`. Its glow drops to 0.35 opacity.
  - The city screen fades in over 0.6 s, after a 0.25 s delay.
- A returning user with a fix within 400 ms skips the loader entirely (existing loader rule).

### Reduce Motion
The moon holds still at the hold phase. There's no rise, pulse, or fly. Every step crossfades over 0.3 s. VoiceOver announces "Finding your location" once, then the message headline.

---

## State machine
```
entering → searching ──fix──────────────────────────► found → city
                │
                └─(issue, ≥1.2 s, moon frozen)─► message(issue)
                                               │
                     first ask:  button → systemPrompt ─allow─► searching
                                                        └─deny──► message(.appDenied)
                     denied/off: button → Settings … foreground + granted ─► searching
                     no fix:     Try again ────────────────────────────────► searching
                     any:        Search for a city instead ────────────────► city search
```
State needed:
- `step`: entering, searching, message, systemPrompt, found, city
- `issue`: firstAsk, appDenied, servicesOff, timeout
- `moonFrozen: Bool`
- the phase offset, driven by a display-link timeline

A 10 s timeout timer runs while `searching`.

## Design tokens
- **Colors:**
  - Background: `#1B1519`
  - Ink: `#F5EADB`
  - Moon lit: `#F2E6CF`
  - Moon shadow: `#1B1519`
  - Accent: `#F2C27B`
  - Secondary text: `#C9B7A6`
  - Body text: `#E4D6C6`
  - Card: `#1E171C`
  - Hairline: `#3D3139`
- **Fonts:** Young Serif (headlines, "Aha", times) and Nunito Sans (UI). Both are Google Fonts; bundle them.
- **Radii:** button 28, card 24.

## Files
- `Location Flow Prototype.dc.html`: the interactive reference. Pick a scenario at the top and use the step chips under the phone.
- `support.js`: runtime for the prototype.
- `LocationFlowReference.swift`: SwiftUI sketch of the moon view and flow timing.
- `reference/onboarding.png`, `reference/system-permission-prompt.png`: screenshots of the current onboarding screen and the system location prompt.
