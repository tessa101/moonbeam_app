# Step 5.5: accessibility reflow

Source: DESIGN-1.1.md §4 and DECISIONS.md, October 12. Implement in small reviewable steps.

- **5.5a — moon card (first pass built 2026-10-16):** 64 pt phase glyph above text, a separate row of two equal 60 pt day controls; locale-ordered time/day-period rows at AX sizes so the existing rise/set pair can fit without shrinking. Retain the full-width status and wrapping guidance below; stack complete events when their ideal widths do not fit. Verify default and AX1/2/3/5 at both phone widths.
- **5.5b — event/connector edge cases:** finish the longer-time, prior-night, missing-event and status matrix; address the SE connector where needed without shrinking accessible text.
- **5.5c — compass:** pinned bar vs readout overlap/duplication, dial sizing and Large Content Viewer for capped compass letters.
- **5.5d — whole-flow review:** large text through sheets, onboarding and failure screens; VoiceOver order and loader/Reduce Motion review, followed by device QA.

5.13 search-flow design remains pending with Tessa. Sentence-token tap targets/press feedback are tracked under 5.13.4. The telescope will be replaced by the ready-to-look cat animation. Disabled Today is left as is per Tessa.

5.5a validation: 879 tests / 1316 cases pass. Full-height card captures at both phone widths, standard and AX1/2/3/5: `.agent-reports/5.5a/`. Whole-screen, scrolling and VoiceOver verification remains in the later steps.
