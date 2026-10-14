# 5.12b.3a Part 2 device verification

- Runtime: iPhone 17 simulator, iOS 27.0, 402 x 874 pt, Debug `-screenState locationOff`.
- Expanded card: approximately 381 pt high on screen (`y = 442...823`), close to the expected 386 pt. The ring is 180 pt and visually centred at approximately `(201, 552)`.
- Collapsed card: 76 pt high (`y = 442.7...518.7`). The avatar accessibility frame is `44.2 x 44.2`, centred at `(59.0, 480.7)`.
- Derived centre travel: avatar centre minus expanded compass centre = approximately `(-142.0, -71.3)` pt. The settled collapsed avatar occupies that destination.
- Settled expanded hierarchy contains the prompt controls and does not contain the row. Settled collapsed hierarchy contains only the row button and does not expose `PREVIEW`, the prompt body, `Turn On Location`, or `Maybe later`. An in-flight expand hierarchy likewise exposes the destination prompt layer only, not the visually fading row layer.
- The DEBUG readout settles directly under each measured card height.

## Issue found

Both transition captures taken roughly midway through the 740 ms animation show the scroll content offset displaced upward by about 224 pt: the heading and moon-information card disappear above the viewport and the animated location card is at about `y = 218`, although both settled endpoints put it at `y = 442`. After the animation the content snaps back to the settled offset. This violates the no-single-frame-jump requirement and means the content below the card is not merely following the card-height track; the enclosing scroll view is also shifting/clamping during the transition.

`collapse-mid.png` and `expand-mid.png` show the displacement. `collapsed-settled.png` and `expanded.png` show the stable endpoints.

## Recording limitation

The Xcode interaction API provides screenshots/hierarchies but no video operation. A direct `simctl io recordVideo` attempt could not connect to CoreSimulatorService from the command sandbox, so a 60 fps video/frame extraction and exact frame count could not be produced in this verification pass.

## Follow-up after `.defaultScrollAnchor(.top, for: .sizeChanges)`

Reverified from a clean install/run using the same iPhone 17 simulator and `-screenState locationOff`.

- Collapse is fixed: `fix-expanded-settled.png`, `fix-collapse-mid.png`, and `fix-collapsed-settled.png` all keep the heading, moon-information card, and location card top at their stable positions. The location card top remains approximately `y = 442`. At the captured midpoint its bottom is approximately `y = 595`, and the DEBUG readout starts at approximately `y = 615`; settled, the card bottom is approximately `y = 519` and the readout starts at approximately `y = 539`. This is consistent with the readout following the changing card height rather than jumping.
- Expand is **not fixed**: `fix-expand-mid.png` again shows the heading and moon-information card shifted entirely above the viewport, with the location card top at approximately `y = 218` rather than `y = 442`. `fix-reexpanded-settled.png` returns to the correct top position, so the upward offset still snaps back at the end of expansion.
- The in-flight expand accessibility hierarchy reports the logical destination geometry at `y = 442` and exposes prompt content only. The screenshot's presentation position differs from that logical hierarchy during the fault.
- Accessibility remains correct at both endpoints and in flight: no hidden row is exposed during expansion, and no hidden prompt is exposed once collapsed.

Follow-up evidence uses the `fix-` filename prefix. The remaining expand-only offset means the no-single-frame-jump requirement is still not met.

## Follow-up with general `.defaultScrollAnchor(.top)`

Reverified after replacing the role-specific size-change anchor with the general top anchor. Evidence uses the `fix2-` prefix.

- Results match the preceding run. Collapse remains stable: the location card top stays at approximately `y = 442` through `fix2-expanded-settled.png`, `fix2-collapse-mid.png`, and `fix2-collapsed-settled.png`, while the DEBUG readout follows the changing bottom edge.
- Expand still fails: `fix2-expand-mid.png` shows the location card at approximately `y = 218`, with the heading and moon-information card displaced above the viewport. `fix2-reexpanded-settled.png` then returns the card to approximately `y = 442`.
- The general anchor therefore does not fix the expand-only presentation offset/snap. Accessibility hierarchies continue to report the stable logical top geometry and expose only the appropriate layer.

## Follow-up with bound `ScrollPosition(edge: .top)`

Reverified after binding the scroll view to an explicit top-edge `ScrollPosition`. Evidence uses the `fix3-` prefix.

- Collapse remains correct. `fix3-collapse-mid.png` keeps the heading and moon-information card visible and the location card top fixed at approximately `y = 442`; the DEBUG readout follows the animated bottom edge.
- Expand remains incorrect. `fix3-expand-mid.png` again has the heading and moon-information card above the viewport and the location card at approximately `y = 218`. `fix3-reexpanded-settled.png` returns to approximately `y = 442`.
- Binding `ScrollPosition(edge: .top)` therefore does not stop the expand-only presentation offset or its end snap. Logical accessibility frames remain at the expected unshifted coordinates.

## Follow-up with disabled scroll-content offset adjustment

Reverified after applying `.transaction { $0.scrollContentOffsetAdjustmentBehavior = .disabled }` to `LocationOffCard`. Evidence uses the `fix4-` prefix.

- Collapse remains stable. The header and information card stay visible; the location card top stays at approximately `y = 442`, and the DEBUG readout follows its animated bottom edge.
- Expand still presents the same failure. `fix4-expand-mid.png` shows the header and information card above the viewport and the growing location card at approximately `y = 218`. `fix4-reexpanded-settled.png` returns the card to approximately `y = 442`.
- Disabling automatic offset preservation on the card's transaction therefore does not remove the expand-only offset or end snap. Logical hierarchy coordinates remain unshifted and accessibility-layer exposure remains correct.

## Follow-up with nested card `geometryGroup()`

Reverified after isolating `LocationOffCard` in an inner geometry group while retaining disabled scroll-content offset adjustment. Evidence uses the `fix5-` prefix.

- Collapse remains stable: the heading and information card stay in place, the location card top stays near `y = 442`, and the DEBUG readout tracks its shrinking bottom edge.
- Expand still fails. `fix5-expand-mid.png` has the location card near `y = 218`, with all preceding content above the viewport; the larger compass confirms this is a later in-flight expansion frame rather than a settled endpoint. `fix5-reexpanded-settled.png` returns to the normal `y = 442` position.
- The nested geometry group therefore does not isolate or prevent the expand-only presentation displacement and snap. Accessibility hierarchy coordinates remain logically unshifted.

## Follow-up with stable prompt subtree and measured collapsed frame

Reverified after keeping the prompt subtree permanently in the ZStack, explicitly framing the settled collapsed card to the measured row height, and pausing the clipped compass at rest. Evidence uses the `fix6-` prefix.

- Collapse midpoint is stable: `fix6-collapse-mid.png` keeps all preceding content in place and the card top near `y = 442`; the DEBUG readout follows the shrinking bottom edge.
- The settled collapsed row is 76 pt high (`y = 442.7...518.7` from its hierarchy). It has no visible residual compass/ring artwork. `fix6-collapsed-settled.png` and `fix6-collapsed-settled-plus10s.png` are byte-identical (SHA-256 `3a5a57e9d68a7238ddb76cd9f9fd9ce67a743cad614ad1b655f16ba20d6c7d7f`), confirming the clipped ghost is not continuing to redraw or rotate at rest.
- A delayed presentation-offset correction was observed after collapse: the first capture one second after the tap briefly showed the row around `y = 218`, while a later settled capture returned to `y = 442`. Thus the stable endpoint is correct, but there is still a post-transition presentation jump beyond the nominal 740 ms timeline.
- Expand still fails in flight. `fix6-expand-mid.png` presents the card around `y = 218`, with preceding content above the viewport, then `fix6-reexpanded-settled.png` returns to the expected top position.
- Keeping the subtree present did not remove the scroll/presentation displacement. Accessibility logical frames remain unshifted and hidden-layer exposure remains correct.

## Follow-up with offset adjustment disabled on the enclosing ScrollView

Reverified after moving `scrollContentOffsetAdjustmentBehavior = .disabled` to the enclosing ScrollView transaction. Evidence uses the `fix7-` prefix and captures midpoint, about one second later, and a later settled state.

- Collapse midpoint remains visually correct (`fix7-collapse-mid.png`): preceding content stays fixed and the card top is approximately `y = 442`.
- Around one second after collapse, `fix7-collapse-plus1s.png` still shows the row at approximately `y = 218`, with preceding content above the viewport. `fix7-collapsed-late.png` returns to approximately `y = 442`. The delayed offset correction therefore persists.
- Expand midpoint still fails (`fix7-expand-mid.png`): the growing card is around `y = 218` and preceding content is offscreen. By about one second, `fix7-expand-plus1s.png` has returned to the expected `y = 442`, matching `fix7-expanded-late.png`.
- Applying the disabled offset-adjustment behavior at the ScrollView does not prevent either the in-flight expand displacement or the delayed collapse displacement. Logical accessibility geometry remains unshifted.

## Follow-up with viewport-height content

Reverified after applying `.containerRelativeFrame(.vertical, alignment: .top)` to the ScrollView content VStack, while retaining disabled offset adjustment. Evidence uses the `fix8-` prefix and includes midpoint, about-one-second, and later captures.

- The initial layout remains unchanged: heading, information card, and expanded location card start at the same positions as earlier runs.
- Collapse midpoint is stable (`fix8-collapse-mid.png`), but `fix8-collapse-plus1s.png` still shifts the row to approximately `y = 218` and removes preceding content from the viewport. `fix8-collapsed-late.png` returns to approximately `y = 442`. The DEBUG readout remains visible immediately under the row in both shifted and stable captures.
- Expand midpoint is improved and remains at approximately `y = 442` (`fix8-expand-mid.png`), with preceding content still visible. However, `fix8-expand-plus1s.png` then shifts the expanded card to approximately `y = 218`; `fix8-expanded-late.png` returns to `y = 442`.
- Keeping content at least viewport-height changes when the expand displacement appears but does not eliminate the delayed presentation offset/snap in either direction.

## Follow-up with nonanimated phase bookkeeping

Reverified after wrapping both phase-start and phase-settle bookkeeping in a transaction with `disablesAnimations = true` and disabled scroll-offset adjustment, while retaining viewport-height content. Evidence uses the `fix9-` prefix.

- Collapse midpoint remains stable at approximately `y = 442`, but `fix9-collapse-plus1s.png` still presents the row around `y = 218`. The later capture returns to `y = 442`.
- Expand midpoint also remains stable at approximately `y = 442`, but `fix9-expand-plus1s.png` still presents the expanded card around `y = 218`. The later capture returns to `y = 442`.
- Disabling animation and offset adjustment on the phase bookkeeping transactions does not remove the settle-boundary displacement. It behaves the same as `fix8`.

## Follow-up with transition-scoped ScrollView lock

Reverified after propagating transition state to `LocationScreen` and applying `.scrollDisabled` only during the transition, including the callback follow-up that changes the lock inside the phase's no-animation/no-offset-adjustment transaction. Evidence uses the `fix10-` prefix.

- Collapse midpoint remains stable at approximately `y = 442`, but `fix10-collapse-plus1s.png` still shows the row around `y = 218`; `fix10-collapsed-late.png` later returns to `y = 442`.
- The settled row remains tappable: tapping it initiated the expansion shown in `fix10-expand-mid.png`.
- Expand midpoint remains stable at approximately `y = 442`, but `fix10-expand-plus1s.png` still shows the expanded card around `y = 218`; `fix10-expanded-late.png` later returns to `y = 442`.
- The settled prompt remains tappable: tapping Maybe later initiated the second collapse shown in `fix10-prompt-retap-mid.png`.
- Transition-scoped `.scrollDisabled` therefore preserves interaction recovery correctly but does not remove the settle-boundary presentation displacement.

## Follow-up with `.scrollBounceBehavior(.basedOnSize)`

Reverified from a fresh install after adding size-based bounce behavior on top of viewport-height content, transition-scoped scroll lock, and disabled automatic offset adjustment. Evidence uses the `fix11-` prefix.

- Collapse midpoint remains stable at approximately `y = 442`, but `fix11-collapse-plus1s.png` still shows the row around `y = 218`; `fix11-collapsed-late.png` returns to `y = 442`. Collapse's delayed displacement persists.
- Expand is improved: `fix11-expand-mid.png`, `fix11-expand-plus1s.png`, and `fix11-expanded-late.png` all keep the heading and information card visible and keep the location card top around `y = 442`. No expand settle jump was observed in this run.
- Settled interaction recovery works: the row tap initiated expansion and the settled Maybe later button initiated the second collapse captured in `fix11-prompt-retap-mid.png`.
- Size-based bounce therefore fixes the expand direction in this capture but not the delayed collapse displacement; the overall no-jump requirement is still unmet.

## Follow-up with geometry-driven settled-row scroll lock

Reverified after retaining the scroll lock for a settled collapsed row only when `ScrollGeometry` reports content height no greater than the viewport. Evidence uses the `fix12-` prefix.

- Collapse is fixed in this run: `fix12-collapse-mid.png`, `fix12-collapse-plus1s.png`, and `fix12-collapsed-late.png` all keep preceding content visible and the row near `y = 442`. The DEBUG readout remains visible immediately below it.
- Expand midpoint is stable, but `fix12-expand-plus1s.png` shifts the expanded card to approximately `y = 218` with preceding content offscreen. `fix12-expanded-late.png` returns to `y = 442`. This regresses the expand direction that was stable in `fix11`.
- Default-size settled interactions work: the row tap initiated expansion and the settled Maybe later tap initiated the second collapse in `fix12-prompt-retap-mid.png`.
- An AX/tall-content scroll test was attempted after the default run, but the interaction session expired during artifact preservation and could not be reused; this part remains unverified.
- The geometry-driven lock fixes the remaining collapse jump but the overall no-jump requirement remains unmet because the expand settle jump returned.

## Follow-up with directional transition lock

Reverified after locking transition scrolling only for collapse, leaving expansion unlocked under size-based bounce, while retaining the geometry-driven short-row lock. Evidence uses the `fix13-` prefix.

- Collapse is stable at all captured timings: `fix13-collapse-mid.png`, `fix13-collapse-plus1s.png`, and `fix13-collapsed-late.png` keep preceding content visible and the row near `y = 442`; the DEBUG readout remains visible.
- Expand midpoint is stable, but `fix13-expand-plus1s.png` again shifts the expanded card to approximately `y = 218`; `fix13-expanded-late.png` returns to `y = 442`. The fix11 expand result was not reproduced with this combined policy.
- Settled interactions work: the row initiated expansion and Maybe later initiated the second collapse (`fix13-prompt-retap-mid.png`).
- An AX-size launch override was attempted, but the simulator remained at the default text size (`fix13-ax-attempt.png`); therefore tall collapsed scrolling could not be verified in this pass.
- The collapse direction now passes, but the overall no-jump requirement remains unmet because expansion still has a delayed settle displacement.

## Follow-up with pre-expansion unlock and yield

Reverified after unlocking the short collapsed ScrollView in a no-adjustment transaction, yielding once on the main actor, then changing the model and starting expansion. Evidence uses the `fix14-` prefix.

- Collapse remains stable at midpoint, about one second, and later; the row stays near `y = 442` and the DEBUG readout remains visible.
- The settled row tap works and initiated expansion, but the pre-expansion unlock/yield did not fix the delayed expansion displacement: midpoint is stable, `fix14-expand-plus1s.png` shifts the expanded card to approximately `y = 218`, and `fix14-expanded-late.png` returns to `y = 442`.
- The settled Maybe later tap also works and initiated the second collapse in `fix14-prompt-retap-mid.png`.
- The overall no-jump requirement remains unmet because expansion still shifts at the settle boundary.

## Follow-up with consistently scrollable content

Reverified after removing callback/scroll-lock machinery and making the ScrollView content consistently at least viewport height plus one point, while retaining size-based bounce and disabled automatic offset adjustment. Evidence uses the `fix15-` prefix.

- Initial expanded and settled collapsed layout remain correctly top-aligned; the collapsed DEBUG readout remains visible immediately below the row.
- Collapse is stable at midpoint, about one second, and later; the row remains near `y = 442` with preceding content visible.
- Expand midpoint is stable, but `fix15-expand-plus1s.png` shifts the expanded card to approximately `y = 218`; `fix15-expanded-late.png` returns to `y = 442`.
- Settled row and Maybe later taps both work.
- Keeping the content consistently beyond the scrollability threshold does not eliminate the expand settle-boundary displacement, so the no-jump requirement remains unmet.

## Follow-up with explicit expanded rest height

Reverified after retaining the measured expanded card height at rest instead of changing `.frame(height:)` to `nil` at settle. Evidence uses the `fix16-` prefix.

- Collapse remains stable at midpoint, about one second, and later; the row stays near `y = 442` and the DEBUG readout remains visible.
- Expand midpoint is stable, but the explicit expanded rest height does not remove the fault: `fix16-expand-plus1s.png` shifts the expanded card to approximately `y = 218`, while `fix16-expanded-late.png` returns to `y = 442`.
- Settled row and Maybe later taps both work.
- The expansion displacement is therefore not caused by replacing its explicit animated height with an intrinsic-height frame at settle. The no-jump requirement remains unmet.

## Follow-up with clamped transition phase at rest

Reverified after removing the phase-settle state transition: the phase retains its direction and returns a clamped final frame, while `timelineIsRunning` alone stops TimelineView updates. Evidence uses the `fix17-` prefix.

- Collapse remains stable at midpoint, about one second, and later. The settled row has no residual compass artwork. `fix17-collapse-plus1s.png` and `fix17-collapsed-late.png` are byte-identical (SHA-256 `3a5a57e9d68a7238ddb76cd9f9fd9ce67a743cad614ad1b655f16ba20d6c7d7f`), confirming no visible ghost rotation or redraw at rest.
- Expand midpoint is stable, but removing the settle-phase mutation does not remove the observed delayed displacement: `fix17-expand-plus1s.png` presents the expanded card around `y = 218`, and `fix17-expanded-late.png` returns to `y = 442`.
- Settled row and Maybe later taps both work; hit testing recovers correctly under `timelineIsRunning` plus the external destination.
- Because the expand displacement remains despite no geometry/accessibility phase mutation at 740 ms, that mutation was not its cause. Logical hierarchy geometry remains at `y = 442` even when the screenshot presentation is shifted.
