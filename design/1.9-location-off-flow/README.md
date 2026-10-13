# Handoff: Location off, compass prompt + moon guide

**This replaces `design_handoff_location_off_teaser/`** (which pointed to option 1b). The final direction is the ghosted real compass prompt plus the dismissed "moon guide" row with the calico cat.

## About the design files
`Location Off Flow.dc.html` is an HTML design reference. Open it in a browser to see all six states. Rebuild them natively in SwiftUI using the app's existing patterns. In the mock, the header, the phase/rise-set card and the CTA button copy the existing production components; **keep those exactly as they are**. Only the parts described below are new.

Fidelity: **high** for the new parts (colours, sizes, copy, motion).

## What changes
On the home screen, when location is off, remove the warning chip ("!" + "Turn on location to use the compass."). In its place, show **S1** until the user dismisses it, then show the row (**S2 to S6**).

## S1: Prompt
Order, top to bottom, below the rise/set card: compass preview, title, body, CTA, "Maybe later".

**Ghosted compass preview**: 210×210pt, centred.
- This is a copy of the live compass ring, drawn in a 260×260 space: ring r 104 (stroke #5E4D57, 2pt), today's rise→set arc (#F2C27B, 4pt, round caps) with 6pt end dots, moon marker (r 10 #F7E7BD over r 16 #F2C27B at 30%), and an "N" label. Pass the real rise/set azimuths into the existing ring component, so you don't need a new drawing.
- Whole layer: **opacity 0.42, blur 1.2pt**.
- Motion: the ring group rotates in a 12s loop. Keyframes: 0° (0s) → −70° (3s) → hold to 4.8s → 40° (7.8s) → hold to 9.6s → 0° (12s). Each move uses ease-in-out cubic-bezier(.45, 0, .55, 1). The effect is a phone slowly being turned.
- A static north tick sits above the ring (#F5EADB, 4pt, from y 0 to 34). It doesn't rotate.
- "PREVIEW" pill, centred over the ring: IBM Plex Mono 11pt, tracking 0.12em, #F2C27B, background #1B1519, 1pt border #4A3A2E, fully rounded, padding 7×11.
- Reduce Motion: static at 0°.

**Copy**
- Title: "Your moon compass is ready". Young Serif 20pt, #F5EADB, centred.
- Body: "It just needs to know where you are to point the right way." Nunito Sans 15pt, line height 1.45, #B9A898, centred, max width 300.

**Buttons** (4pt vertical spacing between them)
- Turn On Location: the existing button. Opens the system permission flow, or Settings if permission was previously denied.
- **Maybe later**: a text-only button, 44pt tall, full width, Nunito Sans SemiBold 16pt, #B9A898. No background or border. It sets `locationPromptDismissed = true` (persisted) and swaps S1 for the row with a short crossfade and height collapse (~250ms).

## S2 to S6: Dismissed row
A single tappable row placed where S1 was. Padding 12 / 16 / 12 / 12, corner radius 20, 14pt gap between items: avatar (52pt circle, no border, no fill), a two-line text stack, and a chevron "›" (24pt).

| State | When | Avatar | Title | Subtitle | Styling |
|---|---|---|---|---|---|
| S2 | Default: no moonrise within 3 hr, moon down | `sleeping.svg` | Compass guide is waiting | Tap whenever you want directions (Regular 13, #B9A898) | border #3A2E35, no fill, chevron #6E5C66 |
| S3 | Moonrise 1 to 3 hr away | `searching.svg` | Moonrise in 2 hr 15 min | Want her to show you where? (SemiBold 13, #F2C27B) | border #4A3A2E, fill #211A1F, chevron #F2C27B |
| S4 | Moonrise 1 to 59 min away | `searching.svg` | Moonrise in 40 min | same as S3 | same as S3 |
| S5 | Moonrise until 15 min after | `searching.svg` | The moon is rising now | same as S3 | same as S3 |
| S6 | 15 min after moonrise until moonset | `searching.svg` | The moon is up now | same as S3 | same as S3 |

- Titles are Nunito Sans SemiBold 16pt, #F5EADB.
- Countdown format: "X hr Y min" from 1 hr up; drop "0 min" ("Moonrise in 2 hr"); "X min" under 1 hr. Update once a minute.
- After moonset, the row returns to S2.
- **Tapping the row** (any state) shows S1 again. If the user taps Maybe later again, it returns to the row.
- Accessibility: the whole row is one button. Label = title + subtitle. Hint: "Shows the moon compass preview."

## Avatars
- **`assets/sleeping.svg`**: the final sleeping calico, a layered 1254×1254 artboard. Layers: `moon-glow` (hidden, `display="none"`; don't ship it), `moon-disc`, `ground-shadow`, `tail-underpaint`, `body`, `paws`, `head`, `tail` (the tail is separate so it can be animated later). For the 52pt avatar, draw the artboard at **1.2× the avatar size** (62.4pt), offset by **x = −5.8pt, y = −5.2pt**, and clip to the circle. The whole cat (tail included) and the moon fit inside. In general: `side = 1.2 × d`, `x = d/2 − side × 0.51`, `y = d/2 − side × 0.50`.
  - The file is large (~650 KB) for a 52pt image. For production, export a @3x PNG/HEIC of the cropped avatar, or flatten the vector in the asset catalog (Preserves Vector Data on).
- **`assets/searching.svg`**: the existing awake calico. Its `moon-halo` circle is hidden (`display="none"`); don't ship it. It's drawn at 52×68pt, shifted up 6pt and clipped to the circle (same as in the app today).

## State and persistence
- `locationPromptDismissed: Bool`: persisted per install. Reset it when location is granted, then revoked again later? **Recommended: yes**, so they see S1 once more.
- Restricted location (MDM or parental controls): don't use this flow. Keep the existing restricted message, because the CTA can't help. *Please confirm.*
- Location granted: remove the prompt and the row; the live compass takes their place.

## Tokens
Background #1B1519 · Text #F5EADB · Muted #B9A898 · Amber #F2C27B · Hairline #3A2E35 · Warm border #4A3A2E · Warm fill #211A1F · Chevron muted #6E5C66
Fonts: Young Serif, Nunito Sans, IBM Plex Mono. All are already in the app.

## Files
- `Location Off Flow.dc.html`: all six states, the rules table and the asset preview.
- `assets/sleeping.svg`: the new sleeping cat (final).
- `assets/searching.svg`: the awake cat (existing).
- `support.js`: needed to open the HTML.
