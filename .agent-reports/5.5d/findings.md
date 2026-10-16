# 5.5d — simulator review, 2026-10-16

The simulator layout review found no new product-code defect in the cases below. Added reproducible hosted-screen coverage and retained the existing app behavior. **5.5d remains open for physical-device accessibility sign-off.**

## Layout coverage

- Landing, location upsell and declined onboarding; all four location failure screens; calendar and search: AX1 and AX5 at 375×667 and 402×874 dimensions (36 cases).
- Searching loader and First Ask permission message at AX5, both dimensions (four cases).
- Captured each at top and bottom. Checked horizontal containment, enabled touch scrolling for overflow, and that programmatic scrolling reaches the content's bottom. Onboarding AX5 additionally must have a real scroll range, guarding against a fixed-height container hiding enlarged content.
- Native calendar/search controls receive UIKit preferred-content-size traits as well as the SwiftUI Dynamic Type environment. These hosted windows exercise phone dimensions on the iPhone 17 simulator; they do not reproduce every native SE safe-area/keyboard condition.
- Reviewed contact sheets in `review/`. Onboarding actions follow scrolling content; failure text scrolls where needed while actions remain visible. First Ask's scrolling message includes its actions. Calendar shows the complete month. Long recent-city labels wrap.
- Existing fixed-size failure primary controls, smaller fallback message text and system calendar typography are intentional earlier decisions; unchanged. The app is configured for Dark appearance; existing Theme contrast coverage remains applicable.

## VoiceOver structure review

Reviewed source wiring, not a spoken-device pass: decorative moons/illustrations and hidden measurements leave the accessibility tree; onboarding/failure headlines have heading traits; message copy has plain sentence labels; Settings paths have spoken comma-separated labels; unavailable actions are hidden from VoiceOver. Main sentence exposes its header then token actions; event cells and compass retain their combined full-word labels. Existing focus wiring covers onboarding screen changes, failure headlines and location prompt/guide/dial swaps. Actual swipe order, focus timing and announcements still need the device checks below.

## Reduce Motion review

Reviewed the live view wiring and existing tests: ContentLoadIn/FailureLoadIn retain fades and remove rises; compass settle/lock effects, ghost motion, illustration timelines and button scaling respect Reduce Motion. Loader recovery uses the no-ride path, a static/crossfading moon and no spatial flight under Reduce Motion. Existing full-suite tests cover these decisions. This is source/model coverage; perceived motion on a physical device is pending.

## Validation

Full suite: **889 tests / 1490 cases / 75 suites, zero failures**, 62.159 s (`/private/tmp/moonbeam-55d-complete.xcresult`). Final onboarding real-scroll assertion: all 12 focused cases pass (18.385 s), `/private/tmp/moonbeam-55d-reachability.xcresult`. No product source, device installation or push in this pass.

## Device sign-off still required

1. Largest text: scroll the main screen, all three onboarding pages and failure messages to their last line/action. Open the calendar as a sheet, exercise month/year selection and Done/Cancel; search with the keyboard visible, edit/clear text, select a result/recent and delete a recent.
2. VoiceOver: swipe through the main sentence/actions, card date controls/events/status and compass. Confirm full direction names, no decorative/hidden elements and no duplicate readout. After onboarding changes focus should start at the heading; after Maybe later it should move to the guide, reopening the guide to the prompt, and enabling location to the dial. Check failure headline focus and action order.
3. Reduce Motion enabled: cold launch, retry/recovery, place change and prompt collapse/expand should use fades without spatial rises/spins/flight or button shrink. Verify both switching it on and returning to normal motion.
4. At large text, press and hold each N/E/S/W letter for its Large Content Viewer. Check unlocked and wrapped locked readouts; the pinned summary should disappear when the main readout enters view.

Search redesign (5.13), sentence-token tap feedback (5.13.4), ready-to-look cat artwork and remaining onboarding animation (5.14) keep their separate scope.
