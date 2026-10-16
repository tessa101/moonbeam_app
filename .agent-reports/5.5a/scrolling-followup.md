# 5.5a.1 — restore scrolling through large text (2026-10-16)

Tessa reported that enlarged main-screen content could not be reached by scrolling on any device. The card-only 5.5a renders did not exercise full-screen scroll extent.

## Reproduction and cause

A hosted test of the real LocationScreen failed at both 375 × 667 and 402 × 874, at AX1/AX3/AX5 (all six cases). The content frame was constrained to the container height plus one point by `containerRelativeFrame(.vertical)`, introduced in `fb16d962` for prompt/guide transition stability. Overflow was drawn outside that frame, but UIScrollView's content extent stayed near one screen. The SE-sized test reported content 606 pt versus scroll bounds 667 pt, with no usable range.

## Fix

Use a minimum content height of the measured scroll viewport plus one point. Short prompt/guide states retain their scrollable layout model; longer content contributes its natural height. The existing offset-adjustment policy remains disabled, and the fold uses the same viewport geometry as before. Onboarding already uses a minimum height; no matching fixed-content-frame use was found elsewhere.

## Validation

- Same six full-screen cases pass after the fix. Each checks a meaningful scroll range, enabled scroll/pan, and reaching the bottom content offset.
- Two additional default-size cases verify that location prompt collapse/expand leaves the top offset unchanged and the guide continues to fill the viewport.
- Full suite: **881 tests / 1324 cases, 72 suites, zero failures**, 36.531 seconds. `/private/tmp/moonbeam-scroll-final.xcresult`.
- Before result: `/private/tmp/moonbeam-scroll-before2.xcresult`; focused after result: `/private/tmp/moonbeam-scroll-after.xcresult`.
- These are full-screen hosted UIKit/SwiftUI tests with programmatic scrolling, not a physical finger/VoiceOver check. No phone installation, push or release upload. Broader 5.5 review remains open.
