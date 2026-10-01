# Moon Signal: Design Brief (visual exploration)

> For the first visual pass: take this to Claude Design (and the design partner).
> Behavior is decided and built. This pass decides **how it looks and feels**.
> Backlog of open design items: DESIGN-REVIEW.md. Owner: Tessa · _Drafted 2026-09-30, updated 2026-09-30 to match build 2_

---

## 1. The app in one line

Tell me **when and where** to look for the moon tonight, from where I am, and point me at it.

- **Primary user (working assumption):** the *moon chaser*, who wants to catch a moonrise over the ocean or a skyline. Also photographers (planning around direction + brightness) and curious lookers (quick glance at phase).
- **When it's used:** outside, often at dusk or night, phone held up, sometimes one-handed.
- **Name:** "Moon Signal" (working name).

## 2. What to design first

**Round 1, one screen only: the main screen**, in 3 distinct visual directions, each shown in:
1. **Tonight, here:** detected city, moon table, compass live (not locked)
2. **Compass locked** on Moonrise
3. **No-moonrise day** (Oct 3)

Pick a direction → **Round 2** extends it to the other screens in §5.

### Directions to try (starting points, not rules)
| | Direction | Feel |
|---|---|---|
| A | **Quiet / editorial** | Big type, lots of space, calm. Data read like a headline |
| B | **Night instrument** | Observatory / nautical tool, precise, dial-forward, red-light-friendly |
| C | **Warm / lunar-tactile** | Soft, textural, glow and phase imagery, friendly |

Each direction should show: palette (dark first), type scale, how the moon table reads, the compass dial, the lock moment.

## 3. Main screen: content, top to bottom

This is the order as built. Layout can change; the content can't.

1. **Prompt:** "Where are you watching the moon tonight?"
2. **Place field:** shows the city as **"Los Angeles, CA"**. Tapping it opens the search sheet. It's a button that looks like a field.
3. **Date control:** ‹ · "Wed, Sep 30" · › (the year shows only for another year: "Mon, Jan 4, 2027"). Tapping the date opens a month calendar sheet; its **Today** button is the way back to today. There's no "Today" chip on the main screen (removed in Step 3), and the label doesn't say "Today" (VoiceOver does).
4. **Time zone label:** only when the place's time zone ≠ the phone's: city + zone abbreviation, e.g. **"Sydney · AEST"** (VoiceOver: "Times shown in Sydney time, AEST"). Some locales show "GMT+10" instead of "AEST".
5. **Moon table:** Moonrise · Moonset · Phase · Illumination
6. **Compass:** live dial, heading readout, lock label, status notes

### Sample data (real values, Astronomy Engine; use these, not lorem ipsum)
| Place · date | Moonrise | Moonset | Phase | Illum. |
|---|---|---|---|---|
| **Los Angeles, CA · Today, Wed Sep 30** | 9:10 PM · 58° ENE | 11:17 AM · 301° WNW | Waning Gibbous | 75% |
| Los Angeles, CA · Sat Oct 3 | **No moonrise today** | 2:27 PM · 302° WNW | Waning Crescent | 42% |
| Los Angeles, CA · Sat Sep 26 | 6:39 PM · 82° E | 6:42 AM · 274° W | Waning Gibbous (a day after full) | 99% |
| Sydney, NSW · Thu Oct 1 (label "Sydney · AEST") | 11:13 PM · 56° ENE | 7:58 AM · 302° WNW | Waning Gibbous | 72% |

- Times are in the **place's** time zone.
- Illumination/phase are for **tonight's local midnight** (design question: how to signal that, e.g. "at midnight").
- Direction = degrees + 16-point letters ("58° ENE"). Order and emphasis are open.
- A missing rise or set is never blank. It's a sentence ("No moonrise today").

## 4. Compass: states

A rotating dial like Apple's Compass: N/E/S/W, degree ticks, fixed heading indicator, live heading in large type ("72° ENE"). **Dots on the dial** mark Moonrise, Moonset, and **Moon** (live position; only today, only when it's up).

| State | What shows |
|---|---|
| **Live** | Dial + heading "72° ENE". Target dots unlabelled today (a known problem: find a way to tell them apart, like labels, shapes or icons) |
| **Locked** (within ±5° of a target) | "**Moonrise · 58° ENE**". Visual change + one haptic tap. *This is the hero moment; make it feel like finding something* |
| **Nearby** (searched city within 60 mi of you) | Compass shows + note: "You're in Irvine, CA but Los Angeles, CA is nearby" |
| **Far** | Compass hidden: "You're a bit too far from Sydney, NSW to view the compass accurately" |
| **Needs Precise Location** | "We think you're near Irvine, CA, but the compass needs Precise Location to point the right way." + **Use Precise Location**. Then briefly: "There you are! The compass is happy now." |
| **Low accuracy (interference)** | "Move away from metal, magnets or a charger, or wave your phone in a figure 8" |
| **Location off** | Compass hidden: "Turn on location to use the compass." + **Turn On Location** |

Copy above is placeholder; tone is part of this pass. Never show a distance or coordinates.

## 5. Round 2 screens (after a direction is picked)

- **Search sheet:** field + "Use my location" row + **Recent** list (swipe to delete) + suggestions ("Los Angeles, CA / United States"); empty "No matching cities"; error "Can't search right now. Check your connection."
- **Calendar sheet:** month grid, Today, Cancel. Future idea: phase glyph per day
- **Location Off dialog** (custom, not a system alert): Denied / Services off / Restricted variants, "Search for a city instead", "Open Settings"
- **First launch:** empty field, prompt, "Use my location". Should it feel inviting or moon-y?
- **Loading** (up to 10 s finding location) and **failed** ("Couldn't find your location. Try again, or search for a city.")

## 6. Constraints (non-negotiable)

- **iOS 26, iPhone, portrait only.** SwiftUI, system components where sensible (sheets, Liquid Glass materials, SF Symbols). Custom where it earns it (dial, table)
- **Dark mode is primary** (used at night); light mode must also work
- **Accessibility:** WCAG AA contrast in both modes · Dynamic Type up to the largest accessibility sizes (the table and dial must reflow, not truncate) · 44 pt touch targets · Reduce Motion respected · VoiceOver reads "east-northeast", not "ENE"
- **Privacy:** no coordinates, no distances, no maps of the user's position
- **Status bar:** content scrolling under the clock is fixed with the iOS 26 system scroll edge effect (blur/fade). Only its final styling is open; a pinned header is still an option
- No accounts, no ads, no onboarding carousel

## 7. Open questions this pass should answer

1. Degrees or letters first? ("58° ENE" vs "ENE · 58°")
2. How do target dots on the dial say which is which?
3. Should N/E/S/W letters stay upright as the dial turns?
4. "Tonight" copy when another date is picked ("…the moon on Oct 3?")
5. Relative-day chips (Today, Tomorrow, …) vs the current ‹ date ›
6. Phase: name only, or a rendered moon/glyph too?
7. How to show "at midnight" for illumination without jargon
8. Custom or system look for ‹ ›, the calendar and sheets

## 8. Deliverables from exploration

- 3 directions × 3 states of the main screen (round 1)
- Chosen direction → all screens in §5 + dark/light + one large-text example
- **Design system:** color tokens (dark/light, with contrast ratios), type scale mapped to Dynamic Type styles, spacing, corner radii, dial spec, lock animation/feedback notes

Next step after that: Cowork turns the chosen system into `docs/DESIGN.md` (tokens + component specs) for the Xcode agent.
