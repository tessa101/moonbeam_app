# Status bar scrim (main screen scroll)

Status: decided 2026-10-17. Build as one small run, one commit.

## Problem

On the main screen, the madlib headline ("Where can I find the moon today in Irvine, CA?") scrolls up under the status bar. The headline text collides with the time, signal, wifi, and battery icons, which makes the status bar hard to read.

## Decision

Fade scrim. A collapsing header (compact pinned "Irvine, CA · Today" line) is a post-launch idea, not part of 1.0.

## Spec

1. A top scrim pinned to the top of the screen, ignoring the safe area. A vertical gradient from the app background color (full opacity) to clear.
2. Height = top safe-area inset + extra. The extra is a named constant, starting at about 24pt.
3. Sits above the scroll content in z-order. Does not intercept touches (`allowsHitTesting(false)`).
4. Opacity follows scroll offset: 0 at the top of the scroll, ramping to 1 over the first ~40pt. The ramp distance is a named constant. No pop.
5. Uses the shared motion timing and easing already in the app. No new constants for motion. With Reduce Motion on, cross-fade with no movement.
6. Uses the shared background color token, not a hardcoded value.
7. Modular: its own small view or modifier, commented, reusable on other scrolling screens.

## If it doesn't show up

Check in this order:
- The scrim is below the ScrollView in z-order (it must be above).
- The opacity ramp never triggers (scroll offset not being read, stuck at 0).
- The gradient ignores the safe area but is too short to cover the status bar.

## Verify

- Run at default and at the largest Dynamic Type sizes.
- Before and after screenshots with the headline scrolled halfway under the status bar.
- The status bar stays legible and nothing else changes.

## Check and report (do not fix without asking)

- Do the search sheet and other scrolling screens have the same collision?
- Does the last piece of real content clear the floating compass pill (and the accuracy banner when it shows)? Report the bottom padding value.

## Related, not decided

At large text sizes the floating compass pill and the "Compass accuracy is low" banner cover the main card's date, phase, and rise/set rows. Options under consideration: (A) move the banner inline with the compass, keeping only the pill floating; (B) collapse the banner after a moment or at AX sizes; (C) make it dismissible. Leaning A. Keep as a separate chunk from the scrim so a bad result is easy to isolate.
