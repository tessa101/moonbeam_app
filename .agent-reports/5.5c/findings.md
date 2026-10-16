# 5.5c — compass accessibility, 2026-10-16

Implemented:
- AX dial keeps a 260 pt face target, constrained by the existing side-label width limit (233 pt on SE 3). It no longer shrinks to the space below an enlarged card. Default sizing retains its height budget.
- AX letters stop at 17 screen points and have 44 pt press-and-hold regions with SwiftUI Large Content Viewer. Existing single-element VoiceOver target summary remains.
- AX readout reserves natural height for wrapped lock text. A rounded panel contains multiline text; full dial/needle clearance is retained. Default readout slot and capsule remain.
- Existing pinned-summary rule already hides the overlay while the main readout is visible. No rule change required. Full-screen scroll checks now also assert the pinned summary is gone at the bottom. The larger phone at AX1 can already show the real readout initially, so an initial pinned summary is not always appropriate.

Validation:
- Six hosted compass cases: both phone widths, AX1/3/5, heading → rise lock → heading. Wrapped locks allocate extra height; release restores the original dial position. Twelve settled captures visually reviewed; lean set and contact sheet in `review/`.
- Three AX size cases, each with absent/tight/roomy height budgets. Existing default sizing tests retained.
- Six full-screen large-text scroll cases and two prompt-collapse/expand cases pass. Scroll check waits for the accuracy-note inset animation to settle before checking the final bottom.
- Full simulator suite: **885 tests / 1450 cases / 74 suites, zero failures**, 36.717 s. `/private/tmp/moonbeam-55c-final.xcresult`.

Remaining: physical-device Large Content Viewer gesture and VoiceOver review, plus whole-flow sheets/onboarding/failures/Reduce Motion under 5.5d. No device install or push.
