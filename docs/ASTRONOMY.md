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
| Rise / set time | `Astronomy_SearchRiseSet(BODY_MOON, observer, DIRECTION_RISE/SET, start, 1.0)` |
| Direction at that moment | `Astronomy_Equator` → `Astronomy_Horizon` → `.azimuth` |
| Phase angle | `Astronomy_MoonPhase(time)` (0 new, 90 first quarter, 180 full, 270 last quarter) |
| Illumination | `Astronomy_Illumination(BODY_MOON, time).phase_fraction` |

## 3. Conventions

These must match USNO or the tests will drift.

- **Rise/set definition:** moment the moon's *upper edge* crosses the horizon, with standard atmospheric refraction (Astronomy Engine default, same as USNO).
- **Search window:** local midnight → next local midnight in the **city's** time zone.
- **Elevation:** 0 m by default (**TBD:** use elevation if it's cheap to get).
- **Azimuth:** degrees clockwise from true north (not magnetic).
- **Compass:** 16-point (N, NNE, NE … NNW), each sector 22.5° wide, centered on its heading.
- **Illumination moment:** **TBD** (current time vs. local midnight; see PRODUCT FR5).

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

| City | Lat, Lon | Date | Rise | Set | Illum % | Source |
|---|---|---|---|---|---|---|
| Los Angeles (Mar Vista) | 34.00, -118.43 | 2026-09-23 | 5:18 PM · 105° ESE | 3:37 AM · 252° WSW | 91% | Astronomy Engine (JS). **TBD:** confirm vs USNO |
| **TBD:** Reykjavík (high lat) | | | | | | |
| **TBD:** Sydney (southern hemisphere) | | | | | | |
| **TBD:** a no-moonrise day | | | | | | |

Tolerance: ±2 min time, ±2° azimuth, ±1% illumination.
