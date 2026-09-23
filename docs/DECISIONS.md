# Decision Log

> One entry per meaningful choice. Newest at the top. Keep it short.
> Format: **date · decision**, then why and what else we considered.

---

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
