# 5.13.4 — sentence token buttons

**Closed 2026-10-16 at Tessa’s request.** Saved full-suite results independently confirmed: 891 tests / 1515 cases pass. Physical-phone verification was not performed by either agent. Remaining 5.14 work moves to a new chat.

Date and place tokens now remain inside the sentence's native `Text` layout while real SwiftUI buttons draw and hit-test the rendered token fragments. This keeps the existing shared scale and Dynamic Type wrapping instead of moving the sentence into a flow layout.

- A custom text attribute identifies token runs; `SentenceTokenRenderer` reports one rectangle per wrapped fragment and can draw either the surrounding words or token ink.
- Each token uses one button whose content shape is the union of its fragments. Every fragment is at least 44 × 44 pt. Date targets expand upward and place targets downward so the close-set lines do not steal one another's taps.
- The token style uses the shared `PressFeedback`, including the 100 ms minimum hold and Reduce Motion opacity-only behavior.
- The visible buttons are also the VoiceOver buttons. Labels, hints, activation, and the detecting-place hide/reveal path are covered; the old accessibility-only stand-ins and URL-link routing are gone.
- `ButtonStyleDriftTests` no longer has a sentence-token allowlist.

Validation (iPhone 17 simulator, iOS 27):

- Focused: 28/28 pass — 24 combinations of four sentence fixtures, 375/402 pt widths and Large/AX1/AX5; pending-place accessibility; three button-style drift checks.
- Each geometry case asserts 44 pt fragment targets, horizontal containment, no date/place target intersection, wrapped AX5 place fragments, native accessibility frames, and activation of the correct sheet.
- Default and AX5 previews reviewed for Today and Rancho Santa Margarita; typography, icons, underline, punctuation and wrapping remain intact.
- Full suite: 891 tests / 1515 cases pass.
- The screenshot-heavy place-change test's full-suite wall-clock allowance moved from 200 to 250 ms after repeatable 217 ms observations under suite load. It passes alone before and after; 250 ms remains safely below the removed 400 ms delay it guards against.

Not performed: physical-phone tap/VoiceOver check, installation, or push.
