# Decision Log

> One entry per meaningful choice. Newest at the top. Keep it short.
> Format: **date · decision**, then why and what else we considered.

---

### 2026-09-29 · 4.8 + 4.9: sensors that got stuck, and a compass gone after overnight
- **Likely root cause of stuck low accuracy (4.9): iOS paused location updates.**
  `pausesLocationUpdatesAutomatically` defaults to true. Apple's docs say that for When In Use
  apps a pause "ends access to location changes until the app … restart[s] those updates". True
  heading is only valid while location updates run, so every reading lost it. Nothing in the
  session restarted itself; toggling Location in Settings stopped and restarted it, which is why
  that cleared it. Pausing is now off; sessions only run in the foreground with the compass on screen.
- **Self-healing anyway: `HeadingSessionMonitor`** (pure, tested). It restarts location updates if
  a valid magnetic heading keeps arriving without a true heading for 5 s (throttled to once per
  10 s), or on a pause callback. It restarts the whole session if authorization or Precise
  Location changes while running. The first authorization callback is the baseline; losing
  permission is left to `LocationViewModel`, which hides the compass.
- **Answers to the device-test questions:**
  - Does the heading manager start before authorization is settled? No. The compass only starts
    once `LocationViewModel` sees authorized.
  - Did anything restart it on an authorization change, an `accuracyAuthorization` change, or
    foreground? Not while running. Foreground only restarted it because background had stopped
    it. Both are now handled.
- **4.8 (compass gone after an overnight background):** not reproduced on device. The likely
  path is iOS terminating the app overnight and the launch fix failing or timing out, so nothing
  is detected. Before the fix, that was only retried on a permission change. Now each foreground
  with location authorized and nothing detected retries detection quietly. It's detection only,
  and a failure neither shows the "couldn't find" message nor switches the place.
- **`LocationService.isPreciseLocationOff`** (new) reaches the compass through `CompassContext`,
  for the DEBUG readout now and the 4.10 reason line.
- **DEBUG readout** under the compass, compiled out of Release (checked). It shows heading,
  accuracy, `accuracyAuthorization`, visibility, detected, targets, lock and sensors. It's shown
  in every state, even hidden, since "the compass is gone" is one of the things it diagnoses.

### 2026-09-29 · Low-accuracy reason shown inline
- When the compass is in low accuracy, one line under the heading says why: "Precise Location is off"
  (with a Settings button) when `accuracyAuthorization` is reduced, otherwise a metal/magnets +
  figure-8 tip. Placeholder copy.
- **Considered:** an ⓘ button opening a bottom sheet or floating dialog. Deferred to the design pass;
  inline keeps the common fix one tap away for testing.
- Low accuracy that stays stuck until Location is toggled in Settings is treated as a bug (4.9),
  not something to explain.

### 2026-09-29 · Compass follow-ups from first device test (4.5–4.7)
- **Haptic on lock (4.5):** one firm tap when a lock is acquired; none on release. Promoted from
  fast-follow now that locking works on device.
  - *As built:* `CompassViewModel.lockAcquisitionCount` goes up on each acquire, including a switch
    straight from one target to another (a new lock). The view plays
    `.sensoryFeedback(.impact(weight: .heavy))` when it changes. Release, holding, low accuracy and
    stopping don't change it. SwiftUI plays system feedback, which the System Haptics setting
    governs. The docs don't say so explicitly, so it's a device QA check.
- **Near, not same city (4.6):** the compass shows within 60 mi of the detected location. Rise/set
  bearings depend mostly on latitude, so within 60 mi they differ by well under 1° (inside the ±5°
  lock). Nearby shows "Directions for {City}"; Far hides the compass with "Compass is only
  available near this location". No distance is ever shown (screenshot privacy). Turn On Location
  from the compass hint updates detection only and keeps the searched city.
  - *As built:*
    - `CompassViewModel.Visibility` is now `.hidden / .locationOff / .here / .nearby / .far`, and
      `showsCompass` is Here or Nearby. The sensors, targets and Moon ticks follow `showsCompass`.
    - The radius is `nearbyRadiusMeters` = 60 × 1,609.344 m, inclusive. Distance is
      `Place.distanceMeters(to:)`, the haversine `isSameCity` already used, now internal rather
      than private. It's measured to the detected place's coordinates (the reverse-geocoded map
      item nearest the fix).
    - `nearbyNote` is stored, not derived, so moving between two Nearby cities updates it.
    - `LocationViewModel.turnOnLocationForCompass()` runs the same permission flow as "Use my
      location", but a fix only records the detected place. **Settings trip** (Tessa, answering
      the agent's question): if the dialog came from the compass hint, the automatic fetch on
      return is detection-only too. Pressing the main button clears that.
    - A failed detection-only fix shows the existing "Couldn't find your location" message.
- **Target rows removed (4.7):** they repeated the moon table; the compass keeps the heading
  readout and lock label.
  - *As built:* the `ForEach` of rows and `targetAccessibilityLabel(for:)` are gone; `targetText`
    stays for the lock label. **Dial VoiceOver** (Tessa, answering the agent's question): the live
    moon's bearing had no text left anywhere, and the dial was hidden from VoiceOver. So
    `CompassDial` is now one element labelled with `CompassViewModel.targetsAccessibilityLabel`
    ("Targets: moonrise, 72 degrees east-northeast; …"). It's hidden when there are no targets. No
    visible change. This supersedes the 2026-09-28 4.4 note that the dial is decorative.
- **Considered:** 30 mi radius (too tight for a metro area); "may not be exact" copy for Nearby
  (undersells a <1° difference); showing the distance (privacy).

### 2026-09-28 · Step 4.4: compass view (plain)
- **"On screen" comes from `onScrollVisibilityChange` and `onDisappear` only, not `onAppear`.**
  The main screen's stack isn't lazy, so `onAppear` fires on insertion even with the compass below
  the fold, which would start the sensors off screen. `onScrollVisibilityChange` also fires on
  appearing if already past its threshold (checked in the SwiftUI docs), so it covers insertion.
  `onDisappear` covers removal.
- **Only `.background` stops the sensors;** `.inactive` (Control Center, the permission prompt) doesn't.
- **The hint's button runs `useMyLocation()`**, the existing flow: the system prompt if not yet
  asked, otherwise the Location Off dialog.
- **One VoiceOver element for the heading.** In low accuracy it reads "Compass accuracy is low"
  rather than an untrustworthy number, and it's marked "updates frequently". The dial is
  decorative (hidden from VoiceOver); the lock label and target rows carry the same information.
- **Copy lives in `CompassViewModel`** (placeholders and row text), so the view holds no strings of
  its own except the "Compass" header.

### 2026-09-28 · Step 4.3: compass view model
- **`CompassViewModel` is fed, not wired.** `LocationViewModel` pushes a `CompassContext` (place,
  detected place, permission state, the selected day's `MoonDay`, is-today). The compass never reads
  location state itself, so `LocationViewModel` stays the one owner of place, day and permission.
- **Moonrise and moonset targets come from the table's own `MoonDay`**, not a second
  `moonDay(for:on:)` call. The compass can't disagree with the table, and the existing tests that
  count moon-service calls are unaffected.
- **Sensors run only while shown, on screen and in the foreground.** A task iterates the heading
  stream for as long as they run, which is what holds it. Stopping clears the reading and lock, so
  a stale heading is never shown.
- **The "Moon" ticker runs only with the sensors.** Each tick recomputes the moon's azimuth and
  whether it's up. Foreground and "selection became today" recompute at once. The sleep is injected
  so tests fire ticks by hand.
- **Lock rules live in a pure `CompassLock`.** Acquire ≤ 5° (inclusive), release > 8°, nearest
  wins, an exact tie goes to moonrise, then moonset, then moon. A locked target that disappears
  (the moon sets, a new day has no moonrise) is released.
- **Visibility with location on but nothing detected is hidden.** A searched city can only be
  "where you are" by matching a detected place (§2). If detection failed or hasn't run, nothing
  proves it.
- **Bearing copy is whole degrees then letters ("72° ENE"), rounded so 359.6° reads "0°".** Same
  order as the moon table. The letters use the unrounded azimuth, as the table does.
- **The moon table now uses the same `CompassFormatter.bearing(for:)`** (review follow-up), so the
  table and compass can't disagree. Two visible changes in the table: 359.6° reads "0° N", not
  "360° N". An exact half degree now rounds half away from zero (72.5° → "73°"), where the table
  used to round half to even ("72°"), matching the compass.
- **4.3b wiring: `LocationViewModel` owns the compass** (`let compass`) and takes a
  `headingService` in its initializer. Every place and day change already goes through
  `reloadMoonTable()`, which now also pushes the context. The permission prompt and
  `sceneDidBecomeActive()` push it too. A new `sceneDidEnterBackground()` forwards to the compass.
- **The detected place is remembered for the session** (not persisted) from the last successful
  fix, including a launch fix that doesn't replace the saved place. A later failed fix keeps it.

### 2026-09-28 · Step 4.2: HeadingService
- **Delegate API wrapped in an `AsyncStream`.** CoreLocation has no async heading sequence (checked
  against iOS 26 docs), and `CLLocationUpdate.liveUpdates()` carries no heading. `start()` returns
  the stream; `stop()` finishes it.
- **Heading and location updates share one manager and one session**, started and stopped
  together. It's a separate manager from `CoreLocationService`'s, so stopping the compass can't
  cut off a location fetch in flight. Location runs at kilometre accuracy, since true heading
  only needs a rough position for declination.
- **A cancelled or dropped stream ends the session** (via `onTermination`), guarded by a session
  counter so a late termination can't stop a newer session. The consumer must keep the stream
  while it wants readings.
- **No compass hardware → neither sensor starts** and the stream yields one `.unavailable`. This is
  the simulator path, and it's tested for real.
- **Only `headingFailure` and `denied` errors mean "unavailable".** A transient "location unknown"
  is ignored, so the compass doesn't flicker into low accuracy.
- **Low accuracy = no true heading, unknown accuracy, or accuracy > 15°.** Exactly 15° is still
  usable ("worse than 15°", COMPASS.md §1). Lives on `HeadingReading` as a named constant.

### 2026-09-28 · App name: Moon Signal (working name)
- **Display name is "Moon Signal" for now**, replacing the working name "Moonbeam". The location
  permission prompt already uses it (96e5042). `AppInfo.name` and the home-screen display name
  (`INFOPLIST_KEY_CFBundleDisplayName`) now follow; the repo, project and target names
  (`moonbeam`, `moonbeam-app`) stay as-is.
- Still revisitable; final name to confirm with the design partner.

### 2026-09-28 · Compass: moon-up, data model, iPhone-only, 16-point names
- **Moon-up = latest rise is after latest set**, both from the moon table's own rise/set search
  (upper limb, standard refraction), searched back from now. The compass can't disagree with the
  table, and it covers a moon that rose last night.
- **Data model is additive only:** new `MoonPosition` (azimuth, isUp) and
  `MoonService.moonPosition(for:at:)`. Rise/set bearings already existed in `MoonEvent.azimuth`.
  Plus a new `HeadingService` protocol (CoreLocation + fake).
- **v1 is iPhone-only** (`TARGETED_DEVICE_FAMILY` 1,2 → 1), so the portrait lock doesn't fight
  iPad multitasking.
- **16-point direction names on the compass**, from `CompassFormatter`, same as the table.
- **Considered:** altitude > 0° for moon-up (measures the centre, so it's off from the table by a
  minute or two at each rise and set); portrait-locked iPad; 8-point names like Apple's Compass
  (one bearing would get two names on one screen).

### 2026-09-26 · Step 3 review follow-ups
- **The moon table no longer shows the city or the date.** The search field shows the city and
  the date control shows the day, so `ContentView` doesn't repeat them. This removes
  `SpikeMoonTableViewModel.dayText` from Decision 2 below. `day` stays, because the rollover check
  compares against it.
- **Shorter date label: "Sun, Sep 27", with the year only in a different year** from the place's
  today ("Mon, Jan 4, 2027"), and no relative word. The chip already says you're off today, and the
  long "Tomorrow · Sun, Sep 27, 2026" wrapped onto two lines at default size. The VoiceOver value
  keeps the relative word and year. The year is compared in the place's zone and in the calendar
  the label is written in.
- **Today chip tap target is 44 pt (NFR4), and it looks the same.** The bordered capsule gets a
  44 pt minimum-height frame and a rectangular content shape. A tap just above the visible capsule
  registers (checked in the simulator).
- **Accepted for now: the same day number after browsing with the month arrows waits for Done.**
  Sep 27 selected → arrow to October → tap Oct 27: to the picker this looks exactly like turning
  the wheel (the day number is kept, and the month changes), so Decision 4's detection treats it as
  a draft and shows Done instead of closing. It's one extra tap in an uncommon case. A custom
  calendar (DATE.md §8, V2) would report taps directly and remove the guess.
- **The date field fills the space between ‹ and ›, with the label centred.** Its width no longer
  follows the date text, so the arrows and chip don't shift as you step through days. The row
  switches to stacked (chip under the row) only at accessibility text sizes, so the default-size
  `ViewThatFits` fallback is gone.
- **The Today chip is always visible, and disabled on today** instead of hidden. The row keeps one
  shape, and the chip's place is learnable. `showsTodayChip` → `isOnToday`, with the meaning
  inverted. With no place it's `true`, so the chip is disabled (the control is hidden then anyway).
  VoiceOver reads it as "Go to today, dimmed".
- **The Today chip is removed from the date row** (supersedes "always visible, disabled on today"
  above). The row is just ‹ [field] ›, and going back to today is the calendar sheet's Today button,
  which is disabled when the selected day is already today (`isOnToday`). The trade-off: back to
  today is now two taps (open the calendar, then Today). That's logged in DESIGN-REVIEW.md, to
  revisit with the relative-day chips idea.
- **Location screen order:** prompt → search field → "Use my location" → finding/failed status →
  date control → time zone label → moon table. The location button and its status now sit with
  the search field they're the alternative to, and the date control sits directly above what it
  changes.

### 2026-09-26 · Step 3: date selection (DATE.md)
- **Decision 1: the midnight rollover happens only when the app comes back to the foreground.**
  `sceneDidBecomeActive()` moves a following-today selection to the place's new day. Nothing moves it
  while the app stays open in the foreground; the next foreground or day action catches up. A timer
  to the place's next midnight would need a second, injectable time source to test. DATE.md §3 is
  amended to match.
- **Decision 2: `SpikeMoonTableViewModel.init(…, today:)` → `day:`.** It keeps the day, and `dayText`
  formats it rather than `Date()`. Once the day is selectable, the table isn't always for today.
- **Decision 3: the time zone label follows the selected day, sampled at local noon.** Both the
  "different zone?" check and the abbreviation use `daySelection.noon(in:now:)`, not `now()`. A picked
  day across a DST change gets that day's label (Sydney on Nov 25 → AEDT), and Phoenix shows one after
  LA falls back. Noon, not midnight, because DST changes happen overnight: noon has the offset for
  nearly all of the day, so LA's changeover day (Nov 1) counts as after the change.
- **Decision 4: the calendar sheet's month/year wheel moves a highlight, not the selection.** In
  the simulator, the graphical `DatePicker`'s wheel changed its selection (Sep 27 → Oct 27), and the
  sheet, which closes on a pick, closed as soon as the wheel moved. A change that keeps the day
  number, or clamps it to the month's last day, is now a draft (`calendarDraft`). The sheet stays
  open and a Done button confirms it. Any other change is a tap on a new day, which picks and closes
  (DATE.md §2). The ambiguous case, the same day number in another month, also waits for Done.
  Considered: Done for every pick (an extra tap, against §2), and leaving the wheel as it was.
- **Tapping the already-selected date doesn't close the sheet.** The picker doesn't report a tap on
  its current selection (checked in the simulator). Cancel or a drag closes it. DATE.md §2 is struck
  through to match.
- **`DaySelection` anchors every day at local noon.** Noon always exists, and midnight doesn't in
  zones whose DST starts at 00:00 (Santiago, 2026-09-06). Days move with `date(byAdding: .day)`,
  never by 86,400 s. Range: today ±366 in the place's zone, clamped on every move and resolve, so a
  picked day that drifts out of range (rollover, city change) lands on the nearest end.
- **A picked day stays `.day` even when it becomes today** (rollover or city change), as §3 says.
  The Today chip and the "Today ·" prefix come from the resolved day, so they're still correct.
- **Date label formatting lives in `Formatting/DayLabelFormatter`**, not in the view model. The
  relative word comes from the offset from the *place's* today, so `Date.RelativeFormatStyle` (whose
  today is the device's) doesn't fit. Tests pin `en_US`.
- **The date field's accessibility: label "Date", with the date as its value.** VoiceOver reads the
  new value after each adjustable swipe, and taps on ‹ / › / Today post an announcement. This
  replaces the single `dateAccessibilityLabel` in DATE.md §4.
- **`FakeMoonService` added**, the last service without a fake. It records `requestedDates`, so
  tests check which day reached the service.
- **Sydney 2026-09-23 and Mar Vista 2026-10-03 through the view model are engine-derived guards**
  (±2 min), because ASTRONOMY.md §5 has no USNO rows for them yet.

### 2026-09-26 · Step 2.1: search sheet with recent cities (SEARCH-RECENTS.md)
- **Decision A: the sheet's "Use my location" row closes the sheet, then runs the main-screen
  flow.** The flow starts from the sheet's `onDismiss`, not from the tap. SwiftUI can't present
  the Location Off dialog while the search sheet is still up from the same view, so waiting keeps
  one code path and avoids stacked sheets. The dialog's "Search instead" does the reverse: it
  reopens the sheet once the dialog has closed.
- **Decision B: the location row is hidden when you're already viewing your detected location.**
  The sheet takes `showsUseMyLocation` from `LocationViewModel`, the same rule as the main-screen
  button. Tapping it there would only re-detect the same place.
- **Decision C: the "Back to {City}" chip is removed.** Recents cover going back to a saved city,
  one tap further away. `lastViewed` stays, because launch still falls back to it when location is
  off, denied or fails. A launch fix still doesn't overwrite it.
- **`PlaceStore` is class-only (`AnyObject`).** The plan's `mutating` recents helpers couldn't be
  called through a `let` reference, even on a class. Both stores are classes and a store is shared
  storage, not a value, so the protocol says so and the helpers aren't `mutating`.
  Considered: keeping `mutating` and using `var` everywhere, which reads as if the store were copied.
- **Resolve failures show `.failed`, whatever the error.** The sheet stays open and nothing is
  picked. The old `LocationViewModel.choose` showed "No matching cities" when a resolve found
  nothing, but that's wrong for a city the user just saw listed. The current "Can't search right
  now" copy isn't right either; logged for the design pass.
- **Type-ahead starts at 2 characters** (`SearchSheetViewModel.searchMinimumCharacters`). Shorter
  queries never reach `MKLocalSearchCompleter`: 0 characters shows recents, and 1 filters them
  (case- and diacritic-insensitive prefix match on any word of name, region or country). The
  threshold is one constant, so it can move to 3 after device testing.
- **8 recents, picked places only.** Picks from search (suggestions or recents) are added, most
  recent first, with the oldest dropped at 9. The detected location never is, because the
  "Use my location" row covers it. Re-picking the same city moves it to the top: same name, region
  and country, or within ~1 km (`Place.isSameCity(as:)`). Recents live under their own
  `recentPlaces` key, seeded once from an existing `lastViewed`. Whether that place was detected
  isn't persisted, so it's seeded regardless.

### 2026-09-25 · Location view model, screen and dialog: the calls LOCATION.md left open
- **The 10 s timeout cancels the fix; it doesn't just stop waiting.** `LocationViewModel` runs
  `currentPlace()` in its own task, with a watchdog that cancels it when the timeout fires.
  Cancelling is what ends `CLLocationUpdate.liveUpdates()`. If the view model only stopped
  awaiting, updates would keep running in the background. Tested with `FakeLocationService`,
  which now records cancelled fixes.
- **A launch detection doesn't overwrite the last-viewed place. Picks do.** §3 says that picking
  any place ("search, detect, or chip") makes it last-viewed. That covers a "Use my location" tap,
  but not the automatic fix at launch. If launch saved it, the "Back to {City}" chip would be gone
  by the next launch. So the chip reduces to one rule: show it when `lastViewed != place`.
- **A current location is never named after `mapItem.name`.** For a reverse geocode, that's the
  nearest street address. Without `cityName`, the mapping uses the first component of
  `cityWithContext`. With neither, it fails, and `CoreLocationService` throws
  `couldNotIdentifyPlace`. Search results keep the `mapItem.name` fallback, because there it names
  the locality the user picked. The rule is `Place.placeName(...)`, tested without MapKit. Because
  the mapping never produces a `locality` that differs from `name`, the "Mar Vista, Los Angeles"
  display-name test was dropped.
- **The time zone label uses the system abbreviation, which isn't always "AEST".** In `en_US`,
  `TimeZone.abbreviation(for:)` gives "GMT+10" for Sydney. Apple only has short names for zones
  the locale commonly uses. That's still unambiguous, so no hand-kept abbreviation table.
- **Refusing at the system prompt ends there.** No Location Off dialog follows straight away. The
  user just answered, so the dialog would nag. The next tap shows it.
- **A failed fix after a tap shows a message: "Couldn't find your location. Try again, or search
  for a city."** §3 only covers failures at launch, which fall back quietly. A tap that did
  nothing visible for up to 10 s would read as broken. Placeholder copy, for the design pass.
- **One dialog title for all three variants.** §4 gives only "Location is off for {AppName}".
- **Foreground re-check is transition-based.** Any change from not authorized to authorized while
  the app was in the background triggers a fetch, whether or not the user got to Settings through
  the dialog. Returns from the system prompt are skipped, so they don't start a second fetch.

### 2026-09-25 · Location services: the API choices behind LOCATION.md §6
Five choices made while building `Place`, `LocationService`, `PlaceSearchService` and `PlaceStore`.
The screen, the view model and the Location Off dialog are still to come.

- **The one-shot fix is `CLLocationUpdate.liveUpdates()`, stopped after the first location.** It's
  the async-native path, so there's no delegate bridging for the fix itself. `requestLocation()`
  would work too, but needs a delegate and a continuation. The `authorizationDenied`,
  `authorizationRestricted` and `locationUnavailable` flags have to be checked as well: the sequence
  doesn't *end* when a fix becomes impossible, it just stops yielding, which would hang the caller.
  Authorization still goes through `CLLocationManager.requestWhenInUseAuthorization()` — the only
  API that controls *when* the prompt appears, which §3 depends on.
- **Reverse geocoding is `MKReverseGeocodingRequest`, as §6 requires.** Confirmed against the iOS 26
  SDK: `MKMapItem.placemark` and `CLGeocoder` are deprecated in 26, and `MKMapItem` gained
  `location`, `address` and `addressRepresentations`.
- **`Place.region` is derived by string, because iOS 26 exposes no administrative-area property.**
  `MKAddressRepresentations` gives `cityName` ("Sydney") and `cityWithContext` ("Sydney, NSW") and
  nothing between them; the component-wise route was `MKPlacemark.administrativeArea`, the very API
  §6 tells us to avoid. So `Place.regionComponent` takes whatever `cityWithContext` has beyond the
  city, and returns `nil` unless the city is confirmed to be the leading component — an unexpected
  format yields no region rather than a wrong one. Covered by tests, rejection cases included.
  Worth revisiting if a later SDK adds the property.
- **`suggestions(for:)` returns an `AsyncThrowingStream`, not the `AsyncStream` §6 specifies.**
  §3 asks for a "Can't search right now. Check your connection." state, and a non-throwing stream
  can't tell a failed search from one that matched nothing. LOCATION.md §6 updated to match.
- **`resolve(_:)` re-searches by address text rather than replaying the `MKLocalSearchCompletion`.**
  §6 says "via `MKLocalSearch`", which this is: the suggestion's two displayed lines are rejoined
  into a `naturalLanguageQuery`, filtered to localities. Replaying the completion object would be
  marginally more precise, but `MKLocalSearchCompletion` isn't `Sendable`, so keeping one would stop
  `PlaceSuggestion` being a value type that fakes and previews can construct.
- **The time zone label compares *offsets*, not identifiers.** §5 says "whenever
  `place.timeZone` ≠ `TimeZone.current`", which reads as identifier equality. Compared that way,
  "US/Pacific" and "America/Los_Angeles" would label a place as elsewhere while showing identical
  times. `Place.isInDifferentTimeZone(from:on:)` takes the device zone as a parameter, which also
  makes it testable — a test process can't change `TimeZone.current`.
- **Isolation split:** these three services are main-actor isolated (the project default), because
  `CLLocationManager` and MapKit both expect a single UI-bound home. `Place`, `PlaceSuggestion`,
  `LocationAuthState` and the MapKit→`Place` mapping stay `nonisolated`, so results cross back into
  the domain layer — and into `MoonService` — without a hop. Note that a `nonisolated` type's
  *extensions* don't inherit that: `Place+MapKit.swift` needs its own `nonisolated`.

### 2026-09-23 · Validate illumination against USNO at local noon, not at the displayed moment
- **Decision:** `AstronomyEngineMoonService` gains an internal `illumination(at:)`. Tests compare
  USNO's `fracillum` against that helper **at local noon**, and assert the displayed
  tonight's-midnight value (94%) separately as an engine-derived regression guard.
- **Why:** USNO samples `fracillum` at local noon. Comparing it to our displayed value would fail by
  ~3 points for a reason that has nothing to do with correctness, and the tempting "fix" — widening
  the tolerance to 5% — would destroy the test's power. Sampling the same moment USNO does isolates
  the maths from the display convention, so each assertion tests one thing.
- **Result:** USNO confirms rise 17:19 and set 03:37 (engine: 17:18:30, 03:37:09, both within
  ±2 min), 91% at local noon (engine 90.9%), and Waxing Gibbous. §5 is no longer TBD.
- **Kept internal, not private:** the helper is `internal` so tests can reach it via
  `@testable import` while the C API stays confined to this one type, per the architecture rule.
- **Not covered by USNO:** rise/set azimuth. USNO doesn't publish it — the reason we calculate on
  device at all (§1) — so azimuth assertions remain engine-derived and are labelled that way.

### 2026-09-23 · The whole domain layer is `nonisolated`, not just the service
- **Decision:** `nonisolated` on `Place`, `MoonEvent`, `MoonDay`, `MoonPhase`, the `MoonService`
  protocol, `AstronomyEngineMoonService` and `CompassFormatter`.
- **Why:** `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` isolates everything unannotated, which makes
  pure value types and pure functions main-actor state. Marking only the service wasn't enough:
  tests still failed to compile because `MoonDay.rise`, `MoonEvent.azimuth` and the `MoonService`
  requirement were all main-actor isolated, so reading a result off the main actor was illegal.
  These types have no mutable or shared state, so isolation buys nothing and costs a hop.
- **Consequence:** Test suites are marked `nonisolated` too, so they genuinely exercise the code off
  the main actor. Views and view models stay main-actor isolated by default, which is what we want.

### 2026-09-23 · Unit tests live in an app-hosted target, driven by a shared scheme
- **Decision:** `moonbeam-appTests` is a Swift Testing bundle **hosted in the app** (`TEST_HOST` +
  `BUNDLE_LOADER` + a target dependency), and the `moonbeam-app` scheme is **shared** in
  `xcshareddata/xcschemes/`.
- **Why hosted:** `@testable import moonbeam_app` needs the app's Swift module. An unhosted bundle
  with no dependency on the app fails with "Unable to resolve module dependency: 'moonbeam_app'".
  Creating the target with the host app attached wires `TEST_HOST` and the dependency correctly;
  creating it standalone does not, and the dependency can't be added without editing
  `project.pbxproj`, which the Xcode tooling forbids.
- **Why shared:** Xcode's autocreated schemes carry no test action, so `xcodebuild test` fails with
  "Scheme moonbeam-app is not currently configured for the test action". Sharing the scheme puts the
  test action in version control. Committing it is deliberate — don't let Xcode replace it.
- **Also:** The test target inherits none of the app's language settings, so Swift 6, complete strict
  concurrency, iOS 26.0 and iOS-only platforms had to be set on it explicitly. The template defaults
  were Swift 5.0, iOS 27.0 and a multiplatform `SDKROOT = auto`.

### 2026-09-23 · Swift 6 language mode with complete strict concurrency
- **Decision:** `SWIFT_VERSION = 6.0` and `SWIFT_STRICT_CONCURRENCY = complete`, matching what
  CLAUDE.md already required. The Xcode template had shipped 5.0.
- **Outcome:** Builds clean with no errors and no concurrency warnings, so no source changes and no
  suppressions were needed. The existing code was already compatible: the models are value types of
  Sendable members, so they pick up implicit `Sendable`; the service is a stateless `struct` whose
  C calls are all local; and the spike's statics are immutable.
- **Note:** The template also sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and
  `SWIFT_APPROACHABLE_CONCURRENCY = YES`, both left as-is. Those make unannotated code MainActor
  isolated, which is why calling the spike from `App.init` is fine. When the test target lands,
  expect to mark the astronomy helpers `nonisolated` so tests can call them off the main actor.

### 2026-09-23 · Minimum iOS 26.0
- **Decision:** `IPHONEOS_DEPLOYMENT_TARGET = 26.0`, the value PRODUCT.md §8 recommended. The
  template had 27.0.
- **Why:** 26 is a wide enough net for a new app while still avoiding legacy baggage; nothing in the
  codebase needs a 27-only API. Verified by building and running at 26.0 — the moon table still
  prints identical values, including 94% illumination.
- **Where it's set:** Both the project and the target read **26.0**, in Debug and Release, so new
  targets inherit the right floor. Getting there took two passes: the target was set first, then the
  project level went 27.0 → 26.6 → 26.0 in Xcode. Claude can only set the *target* level — the
  Xcode tooling exposes no project-level build setting and forbids hand-editing `project.pbxproj`,
  so project-wide changes have to be made in the UI.

### 2026-09-23 · Pin Astronomy Engine v2.1.19; call `Astronomy_SearchRiseSetEx`, not the macro
- **Why:** `Astronomy_SearchRiseSet` is a C *macro* in v2.1.19, so Swift can't see it. The
  underlying function `Astronomy_SearchRiseSetEx` takes an extra `metersAboveGround`, which we
  pass as 0.0 to match the 0 m observer height. ASTRONOMY.md §2 lists the macro name; treat that
  table as naming the capability, not the exact symbol.
- **Considered:** A static-inline shim in the bridging header (more moving parts for no gain).

### 2026-09-23 · Illumination and phase are sampled at tonight's local midnight
- **Decision:** Sample at the **end** of the selected day in the place's time zone, computed with
  `calendar.date(byAdding: .day, value: 1, to: localMidnight)` — not by adding 24 hours, which is
  wrong on the 23- and 25-hour days around a DST transition. The rise/set search window is
  unchanged: it still starts at the *start* of the local day and runs one day.
- **Why:** The app answers "how bright is the moon tonight?", so a fixed nightly anchor is right.
  Sampling the current time would make the number drift during the day and make the value
  irreproducible in tests; the start of the day is stale by evening, which is when people look.
- **Why it matters:** Illumination moves ~6 points across one day (Mar Vista, 2026-09-23: 87.8% at
  the start, 90.9% at noon, 93.6% at the end), far beyond the ±1% tolerance. Rise/set times and
  azimuths are unaffected. The §5 reference illumination is now **94%**, and this unblocks task #3.
- **Considered:** Local current time (drifts, untestable), local noon (matched the old 91% reference
  but has no product meaning), start of the selected day (stale by evening).

### 2026-09-23 · Astronomy Engine on the device; USNO for tests only
- **Why:** USNO has no rise/set azimuth, needs a network connection, and has had outages. Astronomy Engine is MIT-licensed, works offline, and covers every V1 field.
- **Considered:** USNO as the live API, SwiftAA, a hand-rolled Meeus algorithm.

### 2026-09-23 · Docs live in the repo under `docs/`, with CLAUDE.md at the root
- **Why:** Versioned with the code, and Claude Code picks up `CLAUDE.md` automatically.
- **Considered:** Keeping docs only in Obsidian or Notion (they'd drift from the code).

### 2026-09-23 · No separate API.md
- **Why:** There's no runtime API. Data-source research lives in `ASTRONOMY.md`.

### 2026-09-23 · SwiftUI + MVVM-lite + protocol services
- **Why:** Simple, testable, and easy for Claude to follow consistently.
