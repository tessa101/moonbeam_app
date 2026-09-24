# Decision Log

> One entry per meaningful choice. Newest at the top. Keep it short.
> Format: **date · decision**, then why and what else we considered.

---

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
- **Caveat:** Only the *target* was changed, because the Xcode tooling exposes no project-level
  setting and forbids hand-editing `project.pbxproj`. The project level still reads 27.0. The target
  wins, so the app is genuinely 26.0, but **a new target would inherit 27.0** — set the project
  level in Xcode (Project ▸ Info ▸ iOS Deployment Target) before adding the test target.

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
