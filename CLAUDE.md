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
xcodebuild -project moonbeam-app/moonbeam-app.xcodeproj -scheme moonbeam-app \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
# TBD: add `test` once a test target exists
```
