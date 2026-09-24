# Astronomy: Data Sources & Conventions

> Why we calculate moon data the way we do, and how we know it's right.

_Last updated: 2026-09-23_

---

## 1. Decision: calculate on the device

| | Astronomy Engine | USNO API |
|---|---|---|
| Role | **Runtime engine** | **Test reference only** |
| Network | None | Required |
| Rise/set direction (azimuth) | ✅ | ❌ Not provided |
| Rise/set times | ✅ | ✅ |
| Phase + illumination | ✅ | ✅ |
| License / cost | MIT, free | Public, free |
| Risk | Vendored code, we own it | Has had outages; could change |

**Why:** USNO doesn't give direction, which is half the point of the app, and
it adds a network dependency. Astronomy Engine gives us everything offline, and
USNO keeps it honest in tests.

- Astronomy Engine: https://github.com/cosinekitty/astronomy
- USNO endpoint: `https://aa.usno.navy.mil/api/rstt/oneday?date=YYYY-MM-DD&coords=LAT,LON&tz=OFFSET`

## 2. Integration

- Vendor `astronomy.c` + `astronomy.h` into `Moonbeam/Vendor/Astronomy/`.
- Expose them to Swift through a bridging header (or a module map).
- Only `AstronomyEngineMoonService` touches the C API. Everything else talks to the `MoonService` protocol.
- Pin the version: record the release tag in `Vendor/Astronomy/VERSION`.

Key C functions:

| Need | Function |
|---|---|
| Rise / set time | `Astronomy_SearchRiseSetEx(BODY_MOON, observer, DIRECTION_RISE/SET, start, 1.0, 0.0)` |
| Direction at that moment | `Astronomy_Equator` → `Astronomy_Horizon` → `.azimuth` |
| Phase angle | `Astronomy_MoonPhase(time)` (0 new, 90 first quarter, 180 full, 270 last quarter) |
| Illumination | `Astronomy_Illumination(BODY_MOON, time).phase_fraction` |

In v2.1.19 `Astronomy_SearchRiseSet` is a macro wrapping `…Ex`, so it isn't visible to Swift.
`Astronomy_Equator` and `Astronomy_Horizon` take `astro_time_t *`, so the event time needs to be
held in a `var` and passed with `&`.

## 3. Conventions

These must match USNO or the tests will drift.

- **Rise/set definition:** moment the moon's *upper edge* crosses the horizon, with standard atmospheric refraction (Astronomy Engine default, same as USNO).
- **Search window:** local midnight → next local midnight in the **city's** time zone.
- **Elevation:** 0 m by default (**TBD:** use elevation if it's cheap to get).
- **Azimuth:** degrees clockwise from true north (not magnetic).
- **Compass:** 16-point (N, NNE, NE … NNW), each sector 22.5° wide, centered on its heading.
- **Illumination moment:** **tonight's local midnight** — the end of the selected day in the city's
  time zone (PRODUCT FR5). Compute it as `calendar.date(byAdding: .day, value: 1, to: localMidnight)`,
  never `localMidnight + 24 * 3600`, so 23- and 25-hour DST days land on the right instant.
  Illumination moves ~6 points across a single day (87.8% at the start of 2026-09-23 → 93.6% at the
  end), far more than the ±1% tolerance, so the moment has to be exact for tests to mean anything.

> **Moment mismatch with USNO.** USNO's `fracillum` is sampled at **local noon**, not at the end of
> the day, so its percentage will not equal ours and that is expected, not a bug. For 2026-09-23 at
> Mar Vista, USNO reports 91% and the engine agrees at local noon (90.9%) — while the app displays
> 94%, the value at tonight's local midnight. Validate illumination against USNO **at local noon**
> via `AstronomyEngineMoonService.illumination(at:)`; assert the displayed midnight value separately
> as an engine-derived regression guard. Rise/set times are directly comparable and need no such
> adjustment.

### Phase names (from phase angle)

| Angle | Name |
|---|---|
| 0° ± 6° | New Moon |
| 6°–84° | Waxing Crescent |
| 84°–96° | First Quarter |
| 96°–174° | Waxing Gibbous |
| 174°–186° | Full Moon |
| 186°–264° | Waning Gibbous |
| 264°–276° | Last Quarter |
| 276°–354° | Waning Crescent |

**TBD:** The ±6° windows are a common convention, not a standard. Revisit with design.

## 4. Edge cases

- **No rise or set in the window:** happens about monthly because the moon rises ~50 min later each day. Return `nil` and show "No moonrise today."
- **Set before rise** on the same day is normal. Don't assume order.
- **DST transitions:** always compute with the city's `TimeZone`, never a fixed offset.
- **High latitudes:** the moon can stay up or down for long stretches. Out of scope for V1, but it mustn't crash.

## 5. Validation data

Reference values for tests. Fill in from USNO (run from a local machine,
since the cloud sandbox couldn't reach it).

The Mar Vista row is confirmed against USNO. Read it with §3's moment mismatch
in mind: the two illumination figures are the *same* calculation sampled at
different instants, not a disagreement. Engine values were rise 17:18:30 and
set 03:37:09, both within ±2 min of USNO. USNO also reports Waxing Gibbous,
with the next full moon on 2026-09-26 at 09:49 PDT.

| City | Lat, Lon | Date | Rise | Set | Illum % | Source |
|---|---|---|---|---|---|---|
| Los Angeles (Mar Vista) | 34.00, -118.43 | 2026-09-23 | 5:19 PM · 105° ESE | 3:37 AM · 252° WSW | 91% @ local noon · 94% displayed | **USNO** (times, illum @ local noon) + **Astronomy Engine** (azimuth, illum @ tonight's midnight) |
| **TBD:** Reykjavík (high lat) | | | | | | |
| **TBD:** Sydney (southern hemisphere) | | | | | | |
| **TBD:** a no-moonrise day | | | | | | |

Tolerance: ±2 min time, ±2° azimuth, ±1% illumination.
