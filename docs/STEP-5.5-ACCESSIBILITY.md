# Step 5.5: accessibility reflow

Source: DESIGN-1.1.md §4 and DECISIONS.md, October 12. Implement in small reviewable steps.

- **5.5a — moon card (first pass built 2026-10-16):** 64 pt phase glyph above text, a separate row of two equal 60 pt day controls; locale-ordered time/day-period rows at AX sizes so the existing rise/set pair can fit without shrinking. Retain the full-width status and wrapping guidance below; stack complete events when their ideal widths do not fit. Verify default and AX1/2/3/5 at both phone widths.
- **5.5b — event/connector edge cases (built/reviewed 2026-10-16):** finish the longer-time, prior-night, missing-event and status matrix; address the SE connector where needed without shrinking accessible text.
- **5.5c — compass (built 2026-10-16; device gesture check pending):** pinned bar vs readout overlap/duplication, dial sizing and Large Content Viewer for capped compass letters.
- **5.5d — whole-flow review (simulator checkpoint 2026-10-16; device sign-off pending):** large text through sheets, onboarding and failure screens; VoiceOver order and loader/Reduce Motion review, followed by device QA.

5.13 search-flow design remains pending with Tessa. Sentence-token tap targets/press feedback are tracked under 5.13.4. The telescope will be replaced by the ready-to-look cat animation. Disabled Today is left as is per Tessa.

5.5a validation: 879 tests / 1316 cases pass. Full-height card captures at both phone widths, standard and AX1/2/3/5: `.agent-reports/5.5a/`. Whole-screen, scrolling and VoiceOver verification remains in the later steps.

**5.5a.1 scrolling follow-up (2026-10-16):** main-screen content now uses a viewport minimum rather than a fixed viewport height. Six full-screen AX bottom-reachability cases and two default prompt/guide transition cases pass; full suite 881 tests / 1324 cases pass. Tessa confirmed scrolling on device; VoiceOver review remains.

5.5b: reviewed 108 card renders (nine scenarios, both widths, default + AX1–AX5) and nine lock cases. Removed absent AX guidance space; AX zone labels now follow the complete time. SE connector fit rule retained. Full suite 883 tests / 1441 cases pass. Details: `.agent-reports/5.5b/findings.md`. Compass pass 5.5c is now built.

5.5d simulator checkpoint: 40 hosted flow cases cover AX1/AX5 onboarding, four failure causes, calendar/search at both phone dimensions, plus AX5 searching/First Ask loaders. UIKit large-text traits also applied for native controls. Top/bottom captures reviewed; no new product-code issue found. Full suite 889 tests / 1490 cases pass. Source review confirms existing VoiceOver labels/focus wiring and Reduce Motion paths; actual spoken order, keyboard/sheet gestures, motion feel and Large Content Viewer require physical-device sign-off. Checklist and evidence: `.agent-reports/5.5d/findings.md`. **Keep 5.5d open until those checks pass.**
