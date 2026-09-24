# Moonbeam: Product Brief

> Source of truth for *what* we're building and *why*.
> If code and this doc disagree, one of them is wrong, so fix it on purpose.
> Items marked **TBD** are open questions to resolve before they block work.

_Last updated: 2026-09-23_

---

## 1. One-liner

Tell me when and where to look for the moon, tonight, from where I am.

## 2. Problem

Moon data is easy to find but awkward to use. Most apps and sites give you
a rise time with no direction, or bury it in astronomy jargon. If you want
to catch a moonrise over the ocean or a skyline, you need the **time** and the
**compass direction** together, plus some idea of how bright the moon will be.

## 3. Goals

- **G1:** Answer "when and where does the moon rise and set?" for any city in under 5 seconds.
- **G2:** Accurate to within ±2 minutes and ±2° of USNO reference data.
- **G3:** Works fully offline once a location is known. Calculations run on the device.
- **G4:** Build a clean, modular foundation the UX/UI exploration can sit on top of.

### Non-goals (V1)

- Not a general astronomy or planetarium app
- No accounts, sync, or backend
- No AR or camera overlay (see Future ideas)

## 4. Users

| Persona | Need | Example moment |
|---|---|---|
| **Moon chaser** (primary) | Time + direction to catch a moonrise | "Where will the full moon come up over the water tonight?" |
| **Photographer** | Plan shots around rise/set azimuth and illumination | "Is it bright enough, and where will it be at golden hour?" |
| **Curious looker** | Quick glance at phase and brightness | "Why is the moon so big tonight?" |

**TBD:** Confirm the primary persona with the design partner.

## 5. Use cases

1. **UC1:** Type a city → see today's rise, set, phase, and illumination.
2. **UC2:** Read the rise/set direction as a compass heading (e.g. "ESE · 105°").
3. **UC3:** Handle days with no moonrise or moonset (this happens about once a month).
4. **UC4 (V1.1):** Use current location instead of typing a city.
5. **UC5 (V1.1):** Look at a different date.

## 6. Features

| Feature | V1 | Notes |
|---|---|---|
| Manual city input + geocoding | ✅ | City → lat/lon/time zone |
| Moonrise time + direction | ✅ | Azimuth in degrees + 16-point compass |
| Moonset time + direction | ✅ | Same format |
| Lunar phase (name) | ✅ | e.g. "Waxing Gibbous" |
| Illumination % | ✅ | Whole-number percent |
| Current location (GPS) | ➖ | V1.1, needs permission UX |
| Date picker | ➖ | V1.1 |
| Saved locations | ➖ | Later |

## 7. Requirements

### Functional

- **FR1:** Times display in the **selected city's** time zone, not the device's.
- **FR2:** If there's no rise or set on a given day, show "No moonrise today," never a blank.
- **FR3:** Direction shows as degrees + cardinal (e.g. `105° ESE`).
- **FR4:** Geocoding failure shows a clear, recoverable error.
- **FR5:** Illumination and phase are calculated for **tonight's local midnight** — the end of the selected day in the city's time zone. The app answers "how bright is the moon tonight?", so the value shouldn't drift as the day wears on. See ASTRONOMY.md §3.

### Non-functional

- **NFR1 · Accuracy:** ±2 min / ±2° versus USNO for test locations.
- **NFR2 · Performance:** Calculation < 50 ms on device.
- **NFR3 · Offline:** Everything except geocoding works with no network.
- **NFR4 · Accessibility:** Full VoiceOver labels (read "east-southeast," not "ESE"), Dynamic Type, and WCAG AA contrast in light and dark mode.
- **NFR5 · Privacy:** No analytics or tracking in V1. Location is never stored or sent anywhere except the geocoder.

## 8. Constraints

- iOS only, SwiftUI, native Apple frameworks first
- Minimum iOS: **26.0** (set 2026-09-23; no legacy baggage for a new app)
- Single third-party dependency allowed: Astronomy Engine (MIT, vendored C source)
- Solo build with Claude Code; design partner joins at the UX/UI phase

## 9. V1 scope (definition of done)

- [ ] Type a city, see a table with all five fields
- [ ] Values match USNO for 3 reference cities (test suite passes)
- [ ] No-rise / no-set days handled
- [ ] VoiceOver pass on the table
- [ ] Runs on a physical device

## 10. Future ideas (parking lot)

- AR "look here" arrow or compass overlay showing the rise point
- Map view with a rise/set azimuth line from your location
- Notifications ("Moonrise in 30 min, look ESE")
- Home Screen / Lock Screen widgets
- Month calendar of phases
- Supermoon, eclipse, and blue moon callouts
- Moon altitude over time (arc chart)
- Apple Watch complication
