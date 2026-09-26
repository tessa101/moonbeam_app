# Step 2.1 Change: Search sheet with recent cities

**Status:** Built 2026-09-26 (commits 648f049 → 3e9d695); device QA pending · **Decided:** 2026-09-26 · **Owner:** Tessa
**Amends:** Step 2 location spec (`docs/LOCATION.md`), which now points here and strikes through what this supersedes.

---

## Problem

**Expected:** Tapping the search field shows the user's recently searched cities right away, in a separate bottom sheet with the search field at the top.
**Observed:** Nothing appears until 2 characters are typed, then type-ahead matches show.
**Change:** Show recents first. Type-ahead takes over once 2 characters are typed.

## 1. Main screen

- The search field on the main screen becomes a **tap target that opens the search sheet**. It shows the current city name (or the placeholder "Search for a city") and doesn't take text input itself.
- **Superseded from Step 2:** "tapping into the field selects all of its text" and the in-field (x) on the main screen. The sheet always opens with an empty field, so neither is needed there.
- "Use my location" button stays as it is.
- **"Back to {City}" chip removed** (Decision C, 2026-09-26): recents cover it, one extra tap away. `lastViewed` stays, since launch still falls back to it when location is off or fails.

## 2. Search sheet

- Presented as a bottom sheet (`.sheet`, large detent so the keyboard and list both fit). Drag indicator visible.
- **Search field pinned at the top**, empty, **auto-focused with the keyboard up**. Trailing **Cancel** dismisses without changing the place. The field has its own clear (x) while it holds text.
- Placeholder: **Search for a city**

### List states (driven by character count of the trimmed query)

| Query | List shows |
|---|---|
| **0 chars** | "Use my location" row (with location icon), then a **Recent** section: saved places, most recent first |
| **0 chars, no recents** | "Use my location" row only |
| **1 char** | Recents filtered to matches (case- and diacritic-insensitive prefix match on any word of the city, region or country). No matches → empty list, no error copy |
| **2+ chars** | Type-ahead suggestions from `PlaceSearchService`, with the existing states: results / "No matching cities" / "Can't search right now. Check your connection." |
| Cleared back to 0 | Back to the recents view |

- Type-ahead threshold is a single constant (`searchMinimumCharacters = 2`) so it's easy to move to 3 after testing.
- "Use my location" row: **tapping it closes the search sheet, then runs the same flow as the main-screen button** (LOCATION.md §4: permission prompt, fetch, or Location Off dialog). If the dialog appears, "Search instead" reopens the search sheet. (Decision A, 2026-09-26: one code path, no stacked sheets.)
- **Hide the "Use my location" row when the current place is the detected location**, mirroring `showsUseMyLocation` on the main screen. (Decision B, 2026-09-26.)

### Picking a row
Resolve (if a suggestion) → dismiss the sheet → load moon data → update `lastViewed` and recents (§3).

### Removing recents
Swipe-to-delete on a recent row. No "Clear all" in V1.

## 3. Recents rules

- **Cap: 8**, most recent first. Oldest drops off when a 9th is added.
- **Only picked places are added**: a search suggestion or a recent. The detected current location is **not** added (the "Use my location" row covers it).
- Re-picking an existing recent **moves it to the top** instead of duplicating. Identity: same locality + region + country, or coordinates within ~1 km.
- Persisted across launches.

## 4. Architecture changes

- `PlaceStore`
  - Keep `lastViewed: Place?` (can still be the detected location; drives launch logic unchanged).
  - Add `recents: [Place] { get }`, `func addRecent(_ place: Place)`, `func removeRecent(_ place: Place)`. Cap and dedupe live in the store, not the view.
  - Migration: on first run after update, if a `lastViewed` exists and wasn't the detected location, seed `recents` with it. If that can't be known, seed it anyway.
- New `Features/Location/SearchSheetViewModel.swift` (`@Observable`, `@MainActor`): owns query, list state enum (`.recents`, `.filteredRecents`, `.suggestions`, `.noResults`, `.error`), and the threshold logic.
- New `Features/Location/SearchSheet.swift`: plain visuals, same as the rest of Step 2.
- `LocationViewModel`: presents the sheet and receives the picked `Place`.

## 5. Tests (Swift Testing, fakes as before)

**SearchSheetViewModel**
- Empty query → `.recents` in most-recent-first order; search service not called
- Empty query, no recents → location row only
- 1 char → filtered recents; search service not called
- "syd" with recent "Sydney, NSW, Australia" → match; "é" matches "e" (diacritics)
- 2 chars → search service called; suggestions shown
- Clearing the field → back to `.recents`
- Existing no-results and network-error states still map correctly at 2+ chars

**PlaceStore recents**
- Adding a 9th drops the oldest
- Re-adding an existing place moves it to the top, count unchanged
- Near-duplicate (same city, coordinates ~500 m apart) dedupes
- Remove works; recents survive a new store instance
- Migration seeds recents from an existing `lastViewed`

**Flow**
- Picking from search adds to recents; "Use my location" does not
- Cancel leaves place, `lastViewed` and recents unchanged
- "Use my location" row hidden when the current place is the detected location
- Tapping the location row dismisses the sheet, then runs the main-screen flow; with permission denied, the Location Off dialog shows and "Search instead" reopens the sheet

## 6. Acceptance criteria

- [ ] Tapping the main-screen field opens a bottom sheet with the field focused and keyboard up
- [ ] Recents appear immediately with no typing
- [ ] 1 character filters recents; 2+ characters shows type-ahead
- [ ] Clearing the field returns to recents
- [ ] Picking a place dismisses the sheet, loads the moon, and moves that place to the top of recents
- [ ] Max 8 recents, no duplicates, swipe to delete, persisted across launches
- [ ] Detected location never appears in recents
- [ ] All tests pass under Swift 6 strict concurrency

## 7. For DESIGN-REVIEW.md

- ~~Is the "Back to {City}" chip still needed now that recents exist?~~ Resolved: removed (Decision C).
- Sheet visuals: section header style, row layout (city bold + region/country secondary), location row icon
- VoiceOver: field focus on present, "Recent" announced as a header, swipe-to-delete exposed as a custom action
- Threshold 2 vs 3 characters after real-device testing

## 8. Implementation plan (approved 2026-09-26)

### Findings from the current code
- `UserDefaultsPlaceStore` keeps a JSON array under `lastViewedPlaces`, capped at 1; `lastViewed` reads its first entry.
- `lastViewed` can be a *detected* place ("Use my location" saves it). Recents can't include detected places, so **recents must be a separate list**. The "recents is just a cap change" comment in the store no longer holds.
- All search state lives in `LocationViewModel` (`searchText`, `suggestionsState`, `searchTask`, `updateSuggestions`, `clearSearch`, `isFillingSearchField`, and `show()` writing into the field).
- Type-ahead currently fires at 1 character.
- The Location Off dialog is a `.sheet` on `LocationScreen`; SwiftUI can't present it while the search sheet is up from the same view (hence Decision A).

### Files
**Add**
- `Features/Location/SearchSheetViewModel.swift`: query, `ListState`, threshold, recents filtering, resolve
- `Features/Location/SearchSheet.swift`: plain visuals
- `moonbeam-appTests/SearchSheetViewModelTests.swift`

**Change**
- `Services/Location/PlaceStore.swift`: `recents` + shared cap/dedupe/remove extension
- `Services/Location/UserDefaultsPlaceStore.swift`: new `recentPlaces` key + one-time migration
- `Services/Location/InMemoryPlaceStore.swift`: `recents` storage
- `Models/Place.swift`: add `isSameCity(as:)`. **Leave `==` unchanged** (`removeRecent` relies on exact equality to delete only the swiped row)
- `Features/Location/LocationViewModel.swift`: remove search state; add `isSearchPresented`, `presentSearch()`, `select(_ place:)`; `choose`/`goBack` add to recents; `show()` stops writing a search field
- `Features/Location/LocationScreen.swift`: field → button that opens the sheet; remove select-all and (x)
- `moonbeam-appTests/LocationViewModelTests.swift`: move search tests to the sheet test file; add flow tests
- `moonbeam-appTests/PlaceStoreTests.swift`: recents tests

### `PlaceStore` API
```swift
protocol PlaceStore {
    var lastViewed: Place? { get set }   // unchanged; may be a detected place
    var recents: [Place] { get set }     // raw storage; callers use the helpers below
}

extension PlaceStore {
    static var maximumRecents: Int { 8 }
    func addRecent(_ place: Place)    // dedupe via isSameCity → move to front → cap
    func removeRecent(_ place: Place) // exact ==, so a swipe deletes only its own row
}
```
Deliberate deviation from §4's `recents { get }`: the settable requirement lets both stores share one implementation of cap and dedupe.
**As built:** `PlaceStore` is class-only (`AnyObject`), so the helpers aren't `mutating` and callers can hold the store in a `let` (DECISIONS.md 2026-09-26).

### `isSameCity(as:)`
Same `name` + `region` + `country`, **or** coordinates within ~1 km. Uses `name` rather than `locality` because `locality` is often nil and neighbourhoods (Mar Vista) keep their own name.

### List state
```swift
enum ListState: Equatable {
    case recents([Place])               // 0 chars; empty → location row only
    case filteredRecents([Place])       // 1 char; empty → blank list, no error copy
    case suggestions([PlaceSuggestion]) // 2+ chars
    case noResults
    case failed                         // search or resolve failed
}
```
- Going from 1 to 2 characters, keep the filtered recents on screen until the first type-ahead batch arrives (no blank flash during the 250 ms debounce; no loading case needed).
- Queries under the threshold never reach `MKLocalSearchCompleter`.
- Resolve failures show `.failed` in the sheet; the sheet stays open.

### Migration
- `lastViewed` stays on `lastViewedPlaces`, cap 1: launch logic untouched.
- Recents use a new key, `recentPlaces`. If the key is **absent**, seed it from `lastViewed` (if any), then write the key (even as `[]`) so the seed runs once.
- Whether the old `lastViewed` was detected can't be known (`isCurrentLocation` isn't persisted), so it's seeded regardless, per §4. Worst case: one detected city appears once and can be swiped away.

### Known edge cases (accepted)
- ~~The chip can add a detected place to recents.~~ Moot: the chip is removed (Decision C). Remaining case: the one-time migration may seed a detected city (see Migration).
- ~~Possible existing bug: `backToPlace` compares by exact coordinates.~~ Moot: the chip is removed (Decision C).

### Docs to update in the final step
LOCATION.md §2 (recents no longer out of scope), §3 select-all and (x) (superseded), §8 acceptance item on select-all; DESIGN-REVIEW.md (§7 items); DECISIONS.md; STATUS.md.

### Build order (tests green at each step)
1. Store layer + `isSameCity` + PlaceStore tests
2. `SearchSheetViewModel` + tests
3. `SearchSheet` UI + wiring into `LocationViewModel`/`LocationScreen` + flow tests
4. Docs + commit

Also shipped: Decision C, removing the chip (a137f08), between steps 3 and 4.
