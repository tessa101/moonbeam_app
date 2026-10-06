# CLAUDE.md: Operating manual for Moonbeam

You're working on **Moonbeam**, an iOS app that shows when and where the moon
rises and sets. Read these before any non-trivial change:

@docs/PRODUCT.md
@docs/ARCHITECTURE.md
@docs/ASTRONOMY.md

Log meaningful choices in `docs/DECISIONS.md`. Check `docs/STATUS.md` for current state, and update it at the end of a session.

## Ground rules

1. **Stay in scope.** Only change what the task needs. Don't refactor, rename, or reformat unrelated code.
2. **Ask before** adding a dependency, changing a data model, or touching `Vendor/`.
3. **Build before declaring done.** Run the build and tests. If you can't, say so explicitly.
4. **Docs follow code.** If a change contradicts a doc, update the doc in the same change or flag it.
5. **Small steps.** Prefer several small, working commits over one big one.
6. **Report as you go (Tessa, 2026-10-06).** Update `.agent-reports/latest.md` after **every** commit, with what's
   done, what's next and anything blocked, so progress is visible if a run stops. If a task has more than ~3 parts,
   do the first parts, report, and stop rather than running for hours. Keep screenshot sets lean unless the prompt
   asks for the full matrix.
7. **Heartbeat and no hanging tests (Tessa, 2026-10-06).** Append a timestamped line to
   `.agent-reports/progress.log` at each step (e.g. `09:12 running tests`, `09:20 tests pass, committing 3/6`).
   Give async tests a time limit (`.timeLimit(.minutes(1))` on suites that wait on gates or continuations), so a
   stuck test fails instead of hanging the run. If a build or test run goes past ~10 minutes, stop it, log why, and
   report rather than waiting.

## Architecture rules

- SwiftUI views hold no business logic and no direct service calls.
- View models are `@Observable` and receive services through their initializer.
- Services are protocols. Real + mock implementations for each.
- Only `AstronomyEngineMoonService` may call the Astronomy Engine C API.
- Models are value types (`struct`/`enum`) with no formatting.
- All user-facing time formatting uses the **place's** `TimeZone`.

## Coding conventions

- Swift 6, strict concurrency on.
- Modular files: one primary type per file, named after the type.
- Comment the *why*, not the *what*. Every service and model gets a short doc comment.
- Use `// MARK: -` sections in files longer than ~80 lines.
- No force unwraps outside tests.
- No magic numbers. Name constants (e.g. `compassSectorWidth = 22.5`).

## Testing

- Framework: Swift Testing (`import Testing`).
- New formatter or service logic ships with tests.
- Astronomy tests compare against the reference table in `docs/ASTRONOMY.md` §5 with the stated tolerances.
- Never "fix" a failing astronomy test by loosening the tolerance without logging it in DECISIONS.md.

## Accessibility (not optional)

- Every data cell gets an `accessibilityLabel` in plain words ("Moonrise at 5:18 PM, east-southeast").
- Support Dynamic Type, with no fixed font sizes.
- Check light and dark mode contrast.

## Build & test

```bash
# Build
xcodebuild -project moonbeam-app/moonbeam-app.xcodeproj -scheme moonbeam-app \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

# Test (617 tests / 918 cases in the moonbeam-appTests target)
xcodebuild test -project moonbeam-app/moonbeam-app.xcodeproj -scheme moonbeam-app \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

The `moonbeam-app` scheme is **shared** (`xcshareddata/xcschemes/`) so that its test
action is in version control and `xcodebuild test` works from a fresh clone. Don't
delete it in favour of an autocreated scheme — autocreated schemes have no test
action, and `xcodebuild` then fails with "not currently configured for the test
action".
