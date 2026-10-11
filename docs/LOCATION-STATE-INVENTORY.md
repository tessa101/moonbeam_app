# Location states: inventory and consolidation review

October 10, 2026. Based on the implementation after 5.10a Chunk 6.
Sections 1–5 describe the implementation after Chunk 6, before consolidation. On October 10, Tessa approved the focused consolidation pass in `STEP-5.10a-LOCATION-CONSOLIDATION.md`: shared cause presentations across launch/explicit acquisition, with onboarding preserved and separate follow-ups deferred. That document defines scope and agent chunks; implementation is pending.
Scope: location acquisition, city search, recovery, and related compass guidance; not every moon/date display variant.

## 1. What counts as a failure?

There are **four failure causes**, regardless of entry point:

- **App permission denied:** the app cannot access location; offer Settings or city search.
- **Location Services off:** the device-wide switch is off; offer Settings or city search.
- **Restricted:** access is limited by controls/profile; offer city search.
- **No fix:** timeout (10 s), location error, or inability to name the location, including reverse-geocoding failure. Offer retry or city search.

First ask, an unanswered permission prompt, searching, approximate location, a distant selected city, and no matching search results are not these failures. A city-search service error is a separate failure of city search.

The new work introduced `LocationFailure` and the illustrated full-screen presentation. The underlying causes already existed in launch messages/dialogs. A launch with a saved city still falls back to that city. An explicit Use my location request that fails does not restore the previous city.

## 2. Regular flow and entry states

| State | Scenario | Current text / visual | How to reach or test |
|---|---|---|---|
| Onboarding location invitation | New install reaches the location page | Small moon; “Find the moon from where you are”; explanation includes rises/sets and compass; “Keep Precise Location on so the compass can find the moon.” Use my location / Search for a city instead | Show onboarding or reset onboarding; check both actions. Permission appears only after the tap |
| System permission prompt | User chooses Use my location while authorization is not determined | Native iOS prompt over current screen | Reset permission; allow, deny, Allow Once; leave unanswered and verify no fabricated failure |
| Onboarding decline acknowledgment | Don't Allow during onboarding | Dimmed small moon; “That’s okay”; explanation of city lookup and compass access; Got it / Enable location | Deny onboarding prompt; check Got it and Settings route |
| First ask after onboarding | Existing install, no saved city, Ask Next Time / expired Allow Once | Stopped loader moon; “Find the moon from where you are”; “Moon Signal uses your location to show when and where the moon rises and sets.” Use my location / Enter a city instead | DEBUG `messageFirstAsk`; real device with Ask Next Time, no saved city. Allow → recovery; deny → denied launch message |
| Waiting | Launch fetch inside first 400 ms, or neutral handoff before instant illustrated failure | Background only; no text/art | DEBUG `launchFast`; confirm no loader flash; separately verify instant failure entrance |
| Finding location | Launch takes >400 ms, explicit Use my location, or retry | Phase-cycle moon/glow; “Finding your location…” | DEBUG `launchSlow`, `loading`; explicit Use my location. Check success, early error, timeout |
| Found at ordinary launch | Automatic location fetch succeeds | Main sentence, real moon card, eligible compass; ordinary load-in | `launchFast`, `launchSlow`; no recovery Aha required |
| Found after recovery / explicit main location request | Location succeeds after first ask, retry, Settings recovery, or main Use my location | Moon phase ride; rotating “Aha, there you are!” / “Hey, found you.” / “There we are.” plus city; flight into card | `recoveryAha`; `locationFailed.noFix` then Try again; test Settings recovery on device |
| Saved-city fallback | Launch cannot locate, or access off, but last-viewed city exists | Saved city's normal sentence/card; compass hint or hidden compass depending on authorization/detection. No full-screen failure | Save a city; relaunch with denied/services-off/restricted and with a failed authorized fetch. `locationOff` covers saved city + denied |
| City selected | Pick suggestion or recent, including from a failure screen | Search dismisses; selected city appears; card/compass place-change load-in; failure clears | Open search from each entry, pick city; verify old location does not reappear and selected date follows existing rules |

Searching uses the existing moon, not the delivered `searching.svg`. Recovery Aha and the compass's “There you are!” note are different success moments.

## 3. Four causes, eight current full-screen presentations

Every cause currently has a **launch/no-saved-city moon message** and an **illustrated failure after an explicit request from the ready screen**. Text below is exact current copy with display line breaks removed.

| Cause | Headline | Body | Illustrated art | Actions | Settings chip on illustrated version |
|---|---|---|---|---|---|
| Permission denied | Moon Signal can’t see your location | Allow location access to see where the moon is from here. | Telescope + moon/star | Open Settings; Enter a city instead | Settings › Moon Signal › Location › While Using the App |
| Services off | Location Services are off | Turn them on to see where the moon is from here. | Map + moon/travelling spark | Open Settings; Enter a city instead | Settings › Privacy & Security › Location Services |
| No fix | Couldn’t find your location | Check your signal and try again, or search for a city. | Calico “Huh?” + empty moon ring/question mark | Try again; Enter a city instead | None |
| Restricted | Moon Signal can’t see your location | Location access is limited on this iPhone. You can still search for a city. | Map + moon/lock | Search for a city; no secondary | None |

The launch versions use the **same headline/body/action words**, but keep the stopped moon and **omit the Settings chips**. Restricted wraps differently. Both already share `MessageCopy`, `MessageText`, and `MessageActions`; copy values still live in separate `LocationIssue` and `LocationFailure` definitions.

| Presentation | Scenario | DEBUG route | Real behavior check |
|---|---|---|---|
| Launch denied | No saved city, app permission denied | `messageDenied` | Forget saved place with denied permission; Settings grants → auto recovery |
| Launch services off | No saved city, device switch off | `messageServicesOff` | Forget saved place; switch off; return unchanged, then enable |
| Launch restricted | No saved city, restricted access | `messageRestricted` | Fake service for deterministic coverage; controlled device/profile if available; search is only action |
| Launch no fix | No saved city, fetch fails/timeouts | `messageNoFix`; `loading` waits for timeout | Inject location error and geocoding error separately; real offline run is a supplementary check |
| Illustrated denied | Ready screen → Use my location with denied permission | `locationFailed.denied` | Saved city → Use my location; verify telescope/chip and city search |
| Illustrated services off | Ready screen → Use my location with services off | `locationFailed.servicesOff` | Same with device switch off; verify map/chip |
| Illustrated restricted | Ready screen → Use my location with restricted access | `locationFailed.restricted` | Fake restricted service; only city-search primary; no visible secondary |
| Illustrated no fix | Ready screen → Use my location; fetch fails | `locationFailed.noFix` | Try again succeeds; previous city stays out |
| Illustrated no fix again | Retry also fails; same state, not a fifth cause | `locationFailed.noFixAgain` | Try again → loader → same failure; repeat/double tap starts only one request |

DEBUG routes are launch arguments: `-screenState <route>` or the corresponding Xcode previews. They prove deterministic presentations; they do not prove real system Settings behavior. In denied/services-off illustrated fixtures, **any background trip grants fake access**, not just an actual Settings change.

## 4. Dialog and city-search states

| State | Scenario | Current text / art | How to test |
|---|---|---|---|
| Location Off dialog: denied | Compass Turn On Location, or Use my location from search opened over a launch message | No illustration. “Location is off for Moon Signal”; explanation with app Settings path; Open Settings / Search instead | `locationOff` → Turn On Location; also `messageDenied` → Enter a city instead → Use my location |
| Location Off dialog: services off | Same entry points, device switch off | Same title; body names device Location Services/path; same actions | Fake service or real device switch; verify returning from Settings preserves selected city for compass-only request |
| Location Off dialog: restricted | Compass attempt with restricted access | Same title; “Location access is restricted on this device. Search for a city instead.” Search for a city only | Fake restricted compass context. Search row is hidden when restricted |
| Search empty | Sheet opens with keyboard, empty query | Search field/Cancel; Use my location when eligible; Recent rows if any; no illustration | Open from main, onboarding, launch message, each failure. Row hidden for restricted or already-detected selected location |
| Search one character | Local recent filtering only | Matching Recent rows, or blank list; no error | Type one character with matching and nonmatching recents |
| Search suggestions / waiting for batch | Query has 2+ characters | Suggestions; prior list remains while batch arrives; no separate illustrated loading state | Type 2+ characters using fake delayed batches; rapid edits must not deliver stale results |
| No city results | Search succeeds with empty batch | “No matching cities”; no illustration | Fake empty results; this is an empty result, not GPS failure |
| City search failed | Suggestions or selected suggestion resolution throws | “Can't search right now. Check your connection.” Sheet stays open; no illustration | Fake suggestions error and resolve error separately; edit query to recover; no location failure screen |
| Search canceled | User dismisses without picking | Returns to originating message/failure/main screen | Cancel from all four failures and launch messages; failure must remain until successful recovery/pick |

## 5. Related regular compass states

These retain usable city/moon data. They should not become full-screen location failures.

| State | What is shown | Test route / scenario |
|---|---|---|
| Location off | Normal card; hint “Turn on location to use the compass.” / Turn On Location; no failure illustration | `locationOff`; try denied/services-off/restricted separately |
| No detected location yet | Normal saved/searched city card; compass hidden | Authorized failed launch with saved city; quiet foreground retry fails without replacing city |
| Here | Normal live compass, no distance note | `moonUp`, `moonDown`; lock variants are compass display states |
| Nearby | Compass + “You're in [detected] but [selected] is nearby” | `nearby`; boundary at 60 miles |
| Far | No compass; “You're a bit too far from [selected] to view the compass accurately” | `far`; choose distant city |
| Precise off | Compass + “Using your approximate location. Precise gives a better reading.” / Use Precise | `preciseOff`; accept/decline temporary precision prompt on device |
| Low heading accuracy | Compass + “Compass accuracy is low. Move away from metal or a charger, or wave your phone in a figure 8.” | `lowAccuracy`; physical device interference and recovery |
| Precise restored | “There you are! The compass is happy now.” briefly replaces note | `aha`; real temporary precision acceptance |

## 6. Consolidation review and approved first pass

Approved: unify cause copy/art/layout/actions across launch and explicit acquisition, share recovery, and retain the distinct invitation, saved-city, compass-only and city-search contexts. Onboarding's ending and Settings return as not determined remain separate follow-ups; preserve current behavior for now. The table retains the broader review recommendations; use `STEP-5.10a-LOCATION-CONSOLIDATION.md` for the implementation contract.

| Candidate | Recommendation | Reason / boundary |
|---|---|---|
| Launch failure vs explicit-request failure, same cause | **Share exact copy, art, layout, and actions.** Use the illustrated screen for all four causes in both contexts | The user's next step is identical. Current art difference reflects implementation history. Keep entry timing appropriate: known permission failures skip searching; attempted fixes respect minimum search time |
| Copy definitions for four causes | **One source of truth**, including Settings chips | Already almost identical; prevents future drift. First ask remains separate |
| Failure recovery | **Share loader → Aha → main sequence** | Retry and Settings recovery already converge. Another failure should return to the same cause presentation whichever entry started it |
| Denied vs services off | **Keep distinct text and art** | App permission and device switch require different instructions. Telescope vs map helps explain the distinction |
| Denied vs restricted | **Share headline if useful; keep body, art, actions distinct** | Restricted cannot be fixed by the offered permission switch; lock and city-search primary matter |
| Timeout, GPS error, reverse-geocoding failure | **Keep grouped as No fix** for now | Same practical options. Revisit “Check your signal” if real testing shows it misleads people with a working GPS but unavailable city naming |
| Onboarding invitation vs First ask | **Share core headline/explanation and action vocabulary; keep context-specific layout for now** | Both are permission invitations. Onboarding additionally explains compass/precision. No failure art unless a separately designed invitation illustration is approved |
| Onboarding “That’s okay” vs denied failure | **Review the consecutive screens** | Got it currently leads to a no-saved-place denied launch message. Two explanations of denial may be redundant. Consider acknowledgment → focused city search; this is a product proposal, not current behavior |
| Compass Location Off dialog vs full-screen failure | **Reuse cause wording/Settings instructions, retain a compact dialog** | Compass request is detection-only; existing city data stays usable. Replacing the whole screen would imply the chosen city failed |
| Search-row Use my location vs main Use my location | **Converge acquisition behavior; preserve compass-only distinction** | Same explicit request should have the same outcome. Search over a launch message currently routes through loader messages/dialogs; test this route when unifying |
| City-search service failure vs No fix | **Keep separate** | Search problem belongs inside the sheet. “Couldn't find your location” would misdescribe typing a city |
| Saved-city fallback vs explicit failed request | **Keep separate** | Automatic launch can preserve usable saved data. Explicit replacement needs a clear outcome; avoid silently restoring the old city |

Suggested target: one permission invitation family, one searching/recovery family, **four cause-specific failure presentations**, compact compass guidance, and city-search states within the sheet. Share by cause and next action, not simply by “location is unavailable.”

## 7. Acceptance checklist for a consolidation pass

1. Cover each failure cause at launch with no saved city and after main/search Use my location. Same cause must settle on identical copy/art/actions.
2. Known denied/services-off/restricted: no searching flash. No fix after a search: minimum 1.2 s searching before failure; clean crossfade and ordered entrance. No old city/card or moon over the headline.
3. Retry succeeds → loader/Aha/flight; retry fails → same failure. Double tap, repeated foreground, and city selection during fetch must not stack requests or allow late results to overwrite selection.
4. Settings: unchanged permission keeps failure; changed cause switches presentation; granted access fetches once. “Ask Next Time” currently keeps illustrated failure; explicitly decide whether it should move to First ask when consolidating.
5. Search from each cause focuses field; cancel preserves origin; pick clears failure and uses city load-in. Restricted exposes no Use my location row. Recent selection still works without network.
6. Saved-city launch and compass-only requests retain chosen city; quiet failed detection does not show full-screen failure. City-search errors stay in sheet.
7. Check default size/light/dark, Reduce Motion, background/dismissal animation lifecycle, VoiceOver focus/control visibility, and small-screen large text. SE 3 AX2/AX3 scrolling and restricted's accessibility-visible reserved secondary control remain recorded review items.

## 8. Evidence and limits

Chunk 6 report: build-for-testing succeeds; full suite **1099/1099** reported passing. This inventory was checked against source; no app changes or fresh test run were made for this documentation review.

Default-size simulator stills show settled screens and sampled entrance/retry handoffs. **Continuous motion capture was unavailable**, so smoothness and precise visible durations still need a running-app review. Additional accessibility checks remain deferred.

Sources: `LocationViewModel.swift`, `LocationIssue.swift`, `LocationFailure+Copy.swift`, `DebugScreenState.swift`, `SearchSheet.swift`, `SearchSheetViewModel.swift`, onboarding views/copy, `CompassViewModel.swift`; `.agent-reports/latest.md`; `.agent-reports/5.10a-chunk6/recordings/README.md`; `STEP-5.10a-LOCATION-FAILURE.md` and `LOADER.md`.
