# Step 5 Spec: Design 1.1 (Madlib, direction C)

> Source: Claude Design, `design/1.1/Moon Signal Madlib 1.0.dc.html` (sections 3b main screen, 3c AX2 reflow,
> 3d onboarding). `Moon Signal Round 1.dc.html` is the earlier exploration, for reference only.
> Open the HTML in a browser to see it; values below are read from it.
> Brief: DESIGN-BRIEF.md · backlog: DESIGN-REVIEW.md · Owner: Tessa · _Drafted 2026-09-30_

**Behavior doesn't change** unless this doc says so. Everything in LOCATION.md, SEARCH-RECENTS.md,
DATE.md and COMPASS.md still holds; this pass is how it looks, plus onboarding, the moon card (the
task #4 table) and the pinned compass bar, which are new.

Items marked **(proposed)** fill gaps the design doesn't cover. They're Cowork's defaults; Tessa
confirms or changes them in §11 before the agent builds the step that uses them.

---

## 1. What the design answers (DESIGN-BRIEF.md §7)

| Brief question | Answer in 1.1 |
|---|---|
| 1. Degrees or letters first | **Degrees first:** "58° ENE" (as built) |
| 2. Which target dot is which | A small amber **↑** (Moonrise) or **↓** (Moonset) sits just outside each dot, on the dial's rim |
| 3. N/E/S/W upright | **Yes.** Letters and ↑/↓ counter-rotate so they always read upright |
| 4. "Tonight" when another date is picked | The date token reads **"tonight"** for today, **"on Sat, Oct 3"** otherwise |
| 5. Relative-day chips vs ‹ date › | Neither: the date is a **token in the sentence** (opens the calendar), plus small **‹ ›** on the card |
| 6. Phase glyph | **Yes,** a rendered moon next to the phase name |
| 7. "At midnight" | **"75% lit at midnight"** under the phase name |
| 8. Custom or system ‹ › | **Custom:** 32 pt round buttons inside 44 pt hit areas |

## 2. Tokens

### Colors (dark)
| Token | Hex | Use | Contrast |
|---|---|---|---|
| `bg` | `#1B1519` | Screen background, status bar backing | |
| `surface` | `#1E171C` | Moon card | |
| `surfaceRaised` | `#2A2127` | ‹ › buttons, secondary buttons | |
| `stroke` | `#3D3139` | Card border, hairlines, onboarding info box border | |
| `strokeRaised` | `#4A3B45` | ‹ › and secondary-button border | |
| `textPrimary` | `#F5EADB` | Body text, times, headings | 15.1:1 on bg, 14.8:1 on surface |
| `textSecondary` | `#C9B7A6` | Labels ("↑ Moonrise", date label, "75% lit…") | 9.0:1 on surface |
| `textBody` | `#E4D6C6` | Onboarding body copy | 12.6:1 on bg |
| `accent` | `#F2C27B` | Tokens, directions, N, ↑/↓, primary buttons, lock pill | 10.9:1 on bg, 10.7:1 on surface |
| `onAccent` | `#1B1519` | Text on amber | 10.9:1 |
| `moonLit` | `#F2E6CF` | Phase glyph and dial dots | |
| `dialTop` / `dialBottom` | `#30252C` / `#221A1F` | Dial face, radial gradient centred 50% / 40% | |
| `tick` | `#7E6C72` | Dial ticks | 3.5:1 on `dialBottom` at the rim (non-text, ≥3:1); 2.997:1 on `dialTop` |
| `accentGlow` | `accent` at 8–70% | Glows (see components) | |

Contrast is WCAG AA or better for all text. **Known gap:** the ‹ › button edge is 1.7:1 against the
card; acceptable because the glyph (13:1) identifies the control, but note it in the a11y pass. Also for
the a11y pass: `tick` is just under 3:1 against `dialTop`, fine while ticks stay near the rim (5.4).

**Light mode:** dark only for 1.1; the app is forced dark (§11 Q1, decided). Light mode comes with Round 2.

### Type
Two bundled fonts (both SIL Open Font License, from Google Fonts): **Young Serif** (display) and
**Nunito Sans** (UI; variable, use 400/600/700). Register via `UIAppFonts`. Every size scales with
Dynamic Type through `Font.custom(_:size:relativeTo:)`; put them in one place (`Theme.swift`).

| Role | Font | Default pt | relativeTo |
|---|---|---|---|
| Madlib sentence | Young Serif | 27, line height 1.5 | `.title` |
| Onboarding hero ("Moon Signal") | Young Serif | 40 | `.largeTitle` |
| Onboarding title | Young Serif | 30 | `.title` |
| Time (9:10 PM), heading readout, lock pill | Young Serif | 24 | `.title2` |
| Phase name | Nunito Sans 600 | 17 | `.headline` |
| Body, "No moonrise today", primary button | Nunito Sans 400 / 700 | 17 | `.body` |
| Text link ("Search for a city instead") | Nunito Sans 600 | 16 | `.callout` |
| Illumination line, direction ("58° ENE") | Nunito Sans 400 | 14 | `.subheadline` |
| Card date label, "↑ Moonrise" labels, notes | Nunito Sans 600 / 400 | 13 | `.footnote` |
| Dial letters N/E/S/W | Nunito Sans 600 | 15, **capped at 17** | `.subheadline` |
| Dial ↑/↓ labels | Nunito Sans 700 | 14, **fixed** | n/a |

The status bar stays the system's (SF).

### Spacing, radii, effects
- Main screen side margins **20**; content starts **12** below the status bar. Onboarding margins **28**.
- Madlib → card **20**; card → compass block **24**.
- Card: radius **24**, 1 pt `stroke` border, padding **16 / 18** (v / h), internal gap **14**.
- ‹ › : 32 pt circle, `surfaceRaised` fill, 1 pt `strokeRaised` border, inner top highlight (white 6%),
  shadow 0 2 6 black 25%. 44 pt hit area.
- Primary button: height **56**, capsule, `accent` fill, `onAccent` text, glow `accent` 25% radius 30.
- Secondary button: height **52**, capsule, `surfaceRaised` fill, `strokeRaised` border, `textPrimary` text.
- Background: a faint amber radial glow at the top (`accent` 8% → 0, ~520 × 420, centred, top −120).
- Status bar: solid `bg` behind it (replaces 4.15's system material on iOS 26; keep the iOS 27 soft
  edge effect, check it still reads on `bg`).

## 3. Main screen (3b)

Top to bottom. Replaces the prompt, the search-field button, `DateControl`'s row and the spike
`ContentView` table.

### 3.1 Madlib sentence
> Where will the moon be 📅 **tonight** in 📍 **Los Angeles, CA**?

- Plain words in `textPrimary`; two **tokens** in `accent`, underlined (1.5 pt, `accent` 55%), each led
  by an icon: SF Symbol `calendar` for the date, `mappin` for the place. Tokens are the only amber
  text that isn't data.
- **Date token:** "tonight" when the selected day is today; "on Sat, Oct 3" otherwise; with the year
  when it's another year ("on Mon, Jan 4, 2027", same rule as DATE.md). Tap → calendar sheet.
- **Place token:** `Place.nameWithRegion` ("Los Angeles, CA"). Tap → search sheet (SEARCH-RECENTS.md §1).
- Wrapping: at default sizes a token doesn't break inside (non-breaking spaces). At AX1+ it may
  break inside, but **its icon always stays attached to the first word**.
- The sentence is the screen's header.
- **VoiceOver:** reads the sentence, then each token as a button: "Date, tonight, button",
  "Place, Los Angeles, C A, button". Date token's label uses the spoken date for other days
  ("Date, Saturday, October 3"). Suggested build: a `Text` with `AttributedString` links (wraps like
  text) handled by an `OpenURLAction`, with the VoiceOver elements supplied separately. Agent: say in
  your plan how you'll get "button" (not "link") and the order right.
- **No place yet** (§11 Q2, decided): the place token reads **"a city"** (still a tappable token → search
  sheet): "Where will the moon be tonight in 📍 a city?". Card and compass are hidden. **Use my location**
  shows as a secondary button under the sentence; this is the one main-screen spot it stays (4.11).
  VoiceOver: "Place, choose a city, button".

### 3.2 Moon card
One card, three rows separated by 1 pt `stroke` hairlines.

1. **Header row:** date label left ("Today · Wed, Sep 30" on today, "Sat, Oct 3" otherwise),
   `textSecondary` footnote 600; **‹ ›** right. Behavior as DATE.md (day stepping, ±366, VoiceOver
   swipe up/down on the date and announcements). *Change from Step 3:* the visible label says
   "Today ·" again; it's the card's only "today" cue now that the calendar Today chip is gone.
2. **Phase row:** 44 pt phase glyph (glow `accent` 30% radius 18), then phase name (headline) over
   "75% lit at midnight" (`textSecondary`).
   - Glyph: draw the real lit fraction with a terminator (an ellipse edge), lit side by waxing/waning.
     The HTML fakes it with two circles; don't copy that. Northern-hemisphere orientation for 1.1
     (waning = lit on the left); southern flip goes in the backlog.
3. **Rise/set row:** two equal columns with a 1 pt vertical hairline, gap 18, min height 76.
   Each: label "↑ Moonrise" / "↓ Moonset" (footnote 600, `textSecondary`), time (Young Serif 24),
   direction "58° ENE" (subheadline, `accent`).
   - Missing event: the time and direction are replaced by **"No moonrise today"** (Nunito 17,
     `textPrimary`). Wording on other days is still open (DESIGN-REVIEW.md); keep it for now.
   - **Time zone** (§11 Q3, decided): when the place's zone differs from the phone's, a small zone
     abbreviation follows each time: "11:13 PM **AEST**" (footnote, `textSecondary`, baseline-aligned).
     Some locales give "GMT+10"; show what the formatter gives. It replaces the separate
     "Sydney · AEST" label line. If it doesn't fit beside the time it wraps under it.
   - VoiceOver: unchanged from the spike's labels (directions spoken in full), plus the zone in full
     when shown: "Moonrise, 11:13 PM Sydney time, A E S T, east-northeast, 56 degrees" (agent: reuse
     the existing `timeZoneAccessibilityLabel` wording).

### 3.3 Compass block
Centred, below the card.

- **Heading readout:** "72° ENE", Young Serif 24, `textPrimary`, in a 40 pt tall slot.
- **Dial:** 220 pt (260 at AX sizes), face = radial gradient `dialTop` → `dialBottom`, inner top
  highlight, soft drop shadow. Fixed heading indicator: 6 × 18 pt `textPrimary` capsule at 12 o'clock,
  just above the rim.
  - Ticks every 15°: 3 pt dots, 5 pt at N/E/S/W, `tick`, inset 10 pt.
  - Letters inset 24 pt; **N in `accent`**, E/S/W `textSecondary`; always upright.
  - Targets: 14 pt `moonLit` dots on the rim (glow `accent` 35% radius 10), with ↑ / ↓ in `accent`
    just outside, upright. Live Moon dot: see §11 Q4.
- **Locked:** the readout becomes an **amber pill**: "Moonrise · 58° ENE", Young Serif 24,
  `accent` fill, `onAccent` text, padding 9 / 18, glow `accent` 45% radius 36. The locked dot grows to
  22 pt with a 4 pt `accent` 35% ring and a strong glow, and the whole dial gets a soft amber halo
  (`accent` 28% → 0). Haptic as built (4.5). Reduce Motion: no animation, states just swap.
- **Notes** (low accuracy, Nearby, Precise, location off, the aha line): below the dial, a rounded
  (16) pill with `accent` 10% fill, a 20 pt amber "!" circle and footnote text, max width 330.
  The design only shows low accuracy; use the same style for the others (**proposed**), with
  Use Precise Location / Turn On Location as **secondary buttons** under the note. Copy unchanged
  (COMPASS.md). Far: the compass is hidden and only the note shows, centred.

## 4. AX sizes (3c), at `dynamicTypeSize.isAccessibilitySize`
The screen scrolls; containers reflow:
- Sentence wraps freely (rule in §3.1).
- ‹ › leave the header row and become their **own full-width row** of two equal buttons, 60 pt tall.
- Phase stacks: glyph (64 pt) above the text.
- Moonrise and Moonset **stack**, divided by hairlines.
- Dial is a fixed **260 pt**; letters capped at 17 pt and expose the **Large Content Viewer**. Only
  the heading readout scales.

### 4.1 Pinned compass bar (new)
When the compass is available (not hidden, not Far) and the dial is **out of view below**, pin a
glass bar near the bottom: 64 pt tall capsule, 16 pt from the edges, ultra-thin material (design:
`#342830` 82% + blur 20), 1 pt white 12% border, shadow.
- Left: live heading "72° ENE" (Young Serif). Right: amber button **"Compass ↓"** that scrolls to the dial.
- On lock the bar turns amber and reads "Moonrise · 58° ENE", so the lock can't be missed.
- Hide it once the dial is on screen. The dial's own `onScrollVisibilityChange` (sensors on/off) is
  unchanged; the bar uses the heading while the sensors are running, so the **sensors must also run
  while the bar shows** (agent: check this against COMPASS.md §1 "on screen" and propose the rule).
- In the design it's an AX feature, but the rule is "dial below the fold", so it can appear at any size.
- VoiceOver order and gestures at AX2 are still to come from the designer.

## 5. Onboarding (3d)
Four full screens, `bg` background, 28 pt margins, buttons pinned to the bottom.

1. **Landing:** 150 pt moon glyph with a big soft glow, "Moon Signal" (Young Serif 40), tagline
   "When and where to find the moon, and which way to look." (`textSecondary`, max width 280).
   **Get started** (primary).
2. **Location upsell (ours):** 64 pt glyph; title "Find the moon from where you are"; body "Moon Signal
   uses your location to show when and where the moon rises and sets, and to point the compass
   toward it."; an info box (1 pt `stroke`, radius 18, location icon) "Keep Precise Location on so the
   compass can find the moon." **Use my location** (primary) → the system prompt.
   **Search for a city instead** (text link, 44 pt tall) → main screen with the search sheet open; no
   prompt.
3. **System prompt (iOS):** its text is `NSLocationWhenInUseUsageDescription`, already the COMPASS.md
   wording. Precise defaults on (4.12).
4. **After Don't Allow:** glyph at 60% opacity, "That's okay", body "You can still look up locations,
   but to use the advanced features, like the compass, you'd need to enable location".
   **Got it** (primary) → main screen, empty state. **Enable location** (secondary) → app Settings.

- Allow → main screen with the detected city (normal §3 launch flow).
- The prompt is only ever triggered by a tap, never at launch (ARCHITECTURE.md).
- Landing tagline and "That's okay" copy are the designer's placeholders.
- **When it shows** (§11 Q5, decided): only when there's no saved place **and** location permission is
  not determined, so existing TestFlight installs skip it. Add a DEBUG-only way to re-run it.

## 6. Unchanged / not in this pass
Search sheet, calendar sheet and the Location Off dialog keep their current look (Round 2 screens,
DESIGN-BRIEF.md §5), but pick up the fonts and colors through the environment where it's free.
Loading and failed-fetch states keep their current copy; style them with the note pill.

## 7. Build order (one commit each)
5.1 **Theme:** color tokens, bundled fonts + `UIAppFonts`, type scale (`Theme.swift`), screen
    background + top glow, solid status bar backing. App forced dark (§11 Q1).
5.2 **Moon card:** header row (moves ‹ › out of `DateControl`), phase glyph + row, rise/set row.
    Delete the spike `ContentView` / `SpikeMoonTableViewModel` once nothing uses them, and the
    "Spike UI" line.
5.3 **Madlib sentence:** replaces prompt + search button; tokens open the sheets; VoiceOver per §3.1.
5.4 **Compass restyle:** readout, dial, upright letters, ↑/↓, lock pill + halo, notes.
5.5 **AX reflow** (§4).
5.6 **Pinned compass bar** (§4.1).
5.7 **Onboarding** (§5).
Then device QA with screenshots at default, AX1 and AX5 for every state in §3–5.

## 8. Tests
- Date token text: today / other day / other year; spoken labels.
- Onboarding routing: first-launch conditions; Allow / Don't Allow / Search instead outcomes.
- Pinned bar visibility rule (as a view-model state, not a UI test).
- Phase glyph lit-fraction geometry at 0, 25, 50, 75, 100% for waxing and waning.

## 9. Acceptance
- Matches the HTML at default size on an iPhone 16/17 (393 pt wide) in the three main states.
- Nothing truncates at AX5; every control ≥ 44 pt; VoiceOver reads directions in full and the
  sentence then its two buttons.
- No new behavior except §3.2 "Today ·" label, §4.1 bar and §5 onboarding.

## 10. Still to come from the designer
VoiceOver order and gestures at AX2 · final onboarding copy · Round 2 screens (sheets, dialog,
loading/failed) · light mode, if wanted.

## 11. Decisions (Tessa, 2026-09-30)
- **Q1 Light mode:** dark only for 1.1, app forced dark. Light comes with Round 2. ✅
- **Q2 No place yet:** "a city" token + secondary Use my location button; card and compass hidden (§3.1). ✅
- **Q3 Time zone:** a small zone abbreviation next to the moonrise and moonset times (§3.2), replacing
  the separate label line. ✅
- **Q4 Live Moon dot** (today, moon up): **(proposed, not yet confirmed)** an 18 pt `moonLit` dot with no
  arrow, labelled "Moon" only in the lock pill. Build it this way unless Tessa says otherwise.
- **Q5 Onboarding audience:** new installs only (no saved place, permission not determined); DEBUG
  reset to re-run. ✅

_Logged in DECISIONS.md 2026-09-30 "Design 1.1"._
