# Map: where to stand to see the moonrise

Status: 6.1 built 2026-11-24, awaiting Xcode build and phone check. Planned 2026-11-24 (Tessa agreed the approach in chat; entry, line length and style settled the same day). Flat map first, then a 3D view, tried in sequence on
the phone. Terrain-obstruction maths, Look Around and AR are parked (§8).

_Last updated: 2026-11-24_

---

## 1. Problem

The compass tells you which way to face. It doesn't tell you **where to stand**. To catch a moonrise over the ocean,
between two buildings or above a ridge, you need to see what lies along the rise bearing from a spot, and to try
other spots.

## 2. The idea that makes it simple

Within a city the rise and set bearings are effectively the same everywhere: moving 5 km changes the azimuth by a
tiny fraction of a degree and the time by seconds. So the map doesn't recalculate anything when you move the spot. It
draws the selected day's bearing from wherever you put the pin, and you look at what's along it.

## 3. What it does (step 6.1, flat map)

1. **Entry (Tessa, 2026-11-24).** Tapping the **Moonrise** or **Moonset** area of the card opens the map, with the
   tapped event's line emphasised. The cells become buttons (VoiceOver hint: "Opens the map"). A different or
   additional entry point can come later.
2. **Sheet.** A full-height sheet with a Done button. The map (`Map` from SwiftUI MapKit) opens in **satellite**
   (hybrid, with labels), `.flat` elevation (Tessa, 2026-11-24). A style switch offers **Explore** (the standard map);
   **3D** joins it in 6.2.
3. **"Stand here" pin.** A fixed pin at the centre of the map; you pan the map under it (like ride-share pickup
   pins). That avoids custom drag code and is easy to use one-handed. It starts at the place's coordinate.
4. **Bearing lines** from the pin:
   - Moonrise: amber (`Theme` accent); moonset: a dimmer light line. The tapped one is drawn thicker.
   - Their times and bearings sit in a legend card at the bottom of the sheet ("↑ Moonrise / 4:42 PM · 58° ENE"),
     not at the lines' far ends, which are usually off screen at the starting zoom (6 km camera distance).
   - Length: `bearingLineLength` = 30 km (a named constant; Tessa agreed 2026-11-24, tune on the phone). Drawn as a geodesic, since
     an azimuth is the starting direction of a great circle.
   - Times use the **place's** time zone, as everywhere.
   - The lines are for the **selected day** (the card's ‹ › date), not always today.
   - If the day has no rise or set (FR2), that line uses the next one, the same event the card shows, and the label
     says its day ("Sun 12:20 AM"). While the moon is up, the card shows the current pass ("↑ Rose"), so the map
     uses that pass's rise and set.
5. **Follow me.** (Map buttons, top left of the map: Follow me, turn with phone, and in 3D look along; the top bar
   holds only the style switch and Done, Tessa 2026-11-25.) On by default whenever location is allowed (Tessa, 2026-11-24, after 6.1c: the top-left arrow
   wasn't obvious). If you're more than 50 km from the place (browsing another city), the map goes back to the place,
   since its bearings wouldn't apply where you stand. The button (top left) switches to your GPS position with the map **turning with your phone** (MapKit's
   heading-following user location). The pin is then you. Panning the map leaves Follow me; the button brings it
   back. Hidden when location is off or not allowed, and the map still works on the searched place. When the place
   already is your detected location, the map opens following you.
6. **North / heading.** Outside Follow me the map is north-up with MapKit's compass control; rotating with two
   fingers works as usual.
7. **No connection.** Uses the existing `ConnectivityService`. With no network the sheet says the map needs a
   connection (copy TBD, tone of the existing offline messages) and still shows the bearing as text.
8. **Lock while turning (6.1e).** While the map turns with the phone, a line locks when the phone points along it,
   with the compass's rules (acquire ±5°, hold ±8°, COMPASS.md §1): a heavy haptic, as the compass gives, and the line
   and its tag turn amber. Otherwise the selected line is light and the other faint. Each legend cell shows which way
   to turn: "Turn 23° right", then "Facing it". MapKit gives no heading accuracy, so there's no low-accuracy rule.
9. **Moonrise / Moonset switch (6.1d).** The legend's two cells, side by side like the card's, select a line; so does
   tapping a line's tag. Each line carries a tag near the pin ("Moonrise 58°"), a quarter of the view away, so it
   stays on screen at any zoom.
10. **Turn and lock at any spot (6.1f, Tessa 2026-11-25).** Drag the map or tap a spot to stand there, and the map
    keeps turning with the phone and locking there, as it does at your own location. The map runs its own heading
    session (the shared `HeadingService`, one session at a time, so the compass pauses while the sheet is open and
    resumes after). Away from your location the view turns the camera itself in 3° steps, only once the camera has been
    still for 300 ms (never mid-drag); while following you MapKit does. The lock uses the phone's heading and the compass's low-accuracy rule. A toolbar toggle (compass icon) turns
    turning off and on; Follow me turns it back on. Looking along a line pauses it. Tapping while looking along
    re-aims from the tapped spot.

### Accessibility

- The map's accessibility summary reads the bearing in words: "Moonrise direction from the pin: 58 degrees,
  east-northeast, at 4:42 PM."
- Every control has a plain label ("Follow my location", "Show in 3D", "Done"). Overlays use Dynamic Type.
- Check light and dark contrast of the line labels over both the standard and satellite map.

## 4. Step 6.2: 3D

1. **3D** joins the style switch (Satellite / Explore / 3D) and turns on `.realistic` elevation (terrain, and 3D
   buildings where Apple has them), plus MapKit's pitch control. The pin and lines stay.
2. Built (2026-11-24) on satellite imagery (`.hybrid(elevation: .realistic)`); try the standard map on the phone if
   satellite reads badly in 3D. Switching to 3D tilts the camera to 60° where it is (`threeDPitch`); leaving 3D lays it
   flat. While following you the camera is MapKit's, so the tilt comes from the pitch control or a two-finger drag.
3. Where Apple has no 3D data, the map just tilts flat. There's no reliable public way to ask "is 3D available
   here?", so the toggle is always shown. **Check on the phone** whether that's confusing.

## 5. Step 6.3: "Look along the line" (try on the phone)

Built 2026-11-24. Switching to 3D goes straight to this view (Tessa 2026-11-25: the binoculars alone weren't obvious);
the binoculars button (map buttons, top left) toggles it and the 3D overview, which says "Tap the binoculars to look
along the moonrise line". It places the camera behind the pin, facing the selected line's
bearing and tilted toward the horizon (`lookAlongDistance` 250 m, `lookAlongPitch` 80°; 600 m read as "pretty high
up", Tessa 2026-11-25): roughly what's in that direction. The pin is the ground under the camera's eye (drawn as a map
annotation, since the camera's centre is out on the line), so **dragging the view moves where you stand** and the
lines follow (Tessa liked dragging the pin before). A note gives the real eye height from the tilt MapKit allowed
("Seen from about 140 ft up · drag to move"). Switching Moonrise / Moonset turns the view to the other line. The button again, Follow me, or leaving 3D ends it.

Unknown until tried on a device: MapKit clamps the tilt (more so zoomed out), so the eye sits about
`distance × cos(pitch)` up, about 100 m at best, not eye level. If it doesn't read well, keep 6.2 and drop this.

## 6. Architecture

- New feature folder `Features/Map/`:
  - `MoonMapView`: SwiftUI, no logic. MapKit's `Map` is a view, so no new service protocol is needed.
  - `MoonMapViewModel`: `@Observable`, takes the place, the day's rise/set (or next) events, the connectivity
    service and the clock through its initializer. Holds pin coordinate, mode (follow me / explore), style (flat / 3D).
  - `BearingLine`: a `nonisolated` value with the start, bearing, length and computed end coordinate (the
    great-circle "destination point" formula). Pure and testable.
- Labels come from the existing `CompassFormatter` and `MoonTableFormatter`. No formatting in models.
- `LocationViewModel` creates the map view model on demand from what the card already has. No change to `MoonDay`,
  `MoonEvent` or `MoonService`.
- No new dependency: MapKit is already linked (search and reverse geocoding). No new permission: location When In
  Use is already asked for. No Info.plist or privacy-manifest change expected.
- ARCHITECTURE.md gets the `Features/Map/` folder and MapKit's new use when 6.1 lands.

## 7. Tests (Swift Testing)

- `BearingLine` destination maths: known points (equator, 90°, 111.195 km → 1° of longitude; north from the equator;
  across the antimeridian; Mar Vista 105° for 30 km against a reference value) within 1 m.
- Labels: rise/set label text in the place's time zone, including a next-day event and a DST day.
- View model: follow me ↔ explore transitions; follow me hidden without location; offline state; lines for the
  selected day; nil rise or set uses the next event.

## 8. Parked (not in 6.x)

- **The moon's path at any time** (Tessa, 2026-11-24): see where the moon is and will be, not only at rise and set,
  e.g. the pass drawn as a fan of bearings with times, or the moon's current direction as a third line. Bigger than
  6.x; pairs with the moon's-climb idea below.

- **Moon's climb** on the line: ticks for the first hour after rise with its altitude ("+20 min: 4° up"), so you can
  judge when it clears a hill. Needs altitude samples next to `MoonPass.path`. A good next step after 6.3.
- **Look Around** (street-level imagery): probably can't be aimed at a bearing through the public API, and coverage
  is patchy. A 30-minute spike before relying on it.
- **Real obstruction maths** (when it clears the ridge): needs ground-height data along the line. Apple has no public
  API; it would mean a new dependency, a network service and possibly sending location to a third party (conflicts
  with NFR5 and the one-dependency rule). Hills only, not buildings.
- **AR camera view**: the honest "what will I see". Already a PRODUCT.md future idea and a V1 non-goal.

## 9. Open questions

- Copy for the offline state and the line labels' exact wording.
- Later: another entry point besides the rise/set cells.

Settled 2026-11-24 (Tessa): entry is the rise/set cells; lines 30 km; satellite by default with Explore (and later
3D) as options.
