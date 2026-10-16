# iPhone 17 before findings (5.13.3c)

Device: iPhone 17 simulator, 402 × 874 points. The build was launched with the DEBUG `otherDate` / `longPhaseName` fixtures and explicit `UIPreferredContentSizeCategoryName` launch arguments.

## Headline

- Default (`UICTContentSizeCategoryL`): the long-phase baseline headline is at `y=74.0, h=23.3`; the moon card begins at `y=199.3`. This is the card-position comparison baseline.
- AX1 (`UICTContentSizeCategoryAccessibilityM`), other date: overlap is plainly visible. “Where can I find” overlaps “the moon”, and “Oct 3” overlaps “in Irvine, CA?”. The accessibility hierarchy reports the sentence as `y=82.0, h=71.0`, while the rendered text visibly occupies substantially more height. The card begins at `y=242.0`.
- AX3 (`UICTContentSizeCategoryAccessibilityXL`), other date: severe overlap is plainly visible across all four rendered headline rows. The hierarchy reports the combined sentence as only `y=74.0, h=50.7`; the date button is `y=154.3, h=80.3`, the place button is `y=242.7, h=80.3`, and the card begins at `y=265.3`.
- At AX1 and AX3, the visually overflowing date/place tokens do not agree with their reported hit frames. Attempts at the reported date hit point and at the visible date text opened the place-search sheet or did nothing. This prevented calendar coverage at AX sizes and is consistent with the same fixed-slot overflow.
- The existing DEBUG screen-state fixture always supplies Irvine. `FakePlaceSearchService` has no scripted suggestions in `DebugScreenState`, so a Rancho Santa Margarita runtime capture was not reachable without source edits (which this before-capture task prohibited).

## Calendar sheet

- Default, other-date selection, without Done: the sheet presents at only about 78 points tall (`y≈796` to the bottom). Only the drag indicator, Today, “Choose a date”, and Cancel are visible; the month grid is completely absent/offscreen. This reproduces the height bug on iPhone 17.
- AX1 / AX3: blocked by the headline token overflow/hit-testing issue described above; the calendar could not be opened reliably from the overflowing date token without editing the fixture/app.
- A first AX1 calendar attempt also terminated the app with an iOS 27 simulator accessibility-bundle conflict (`UIAccessibilityLoaderWebShared` duplicated in WebKit/WebCore). A clean session was then used for the remaining captures.

## Captures

- `iphone17-default-headline-card-baseline.png` (+ hierarchy)
- `iphone17-ax1-headline-long-date.png` (+ hierarchy)
- `iphone17-ax3-headline-long-date-overlap.png` (+ hierarchy)
- `iphone17-default-calendar-other-date-without-done.png` (+ hierarchy)

