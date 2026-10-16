# 5.13.3e follow-up: stable calendar height — 2026-10-16

The saved `after-part2-final/se3-ax1-other-scrolled.png` reveals a regression in `f6bc5b1`: the SE sheet shrinks from 393.9 pt before scrolling to 105.8 pt afterward. The fitted height used the calendar bottom in global coordinates minus the sheet top. Scrolling changes that difference.

The follow-up measures `ScrollGeometry.contentSize.height + contentInsets.top`, independent of scroll offset. The top inset accounts for the navigation area without a fixed toolbar height. The system adds the bottom safe area to the custom detent. Initial/invalid measurements and content exceeding the presenting viewport retain the large fallback. Calendar behavior and toolbar styles are unchanged.

Validation:
- Xcode build and full iPhone 17 iOS 27 suite passed: 878 tests / 1307 cases, 70 suites, 37.213 seconds. Six new sizing cases cover scrolling, overscroll and content-height changes.
- Device Hub visual checks: the current large-text fixtures on iPhone 17 and SE3 show the complete October grid, including October 25–31. Repeated scroll attempts on the settled SE sheet leave its visible height unchanged. The fitted sheet now has room for the whole grid at this setting, so this does not exercise an actual overflowing scroll view.
- The shell simulator connection was unavailable; execution and visual checks used Xcode and Device Hub. No service restart attempted.
- Shared launch arguments temporarily selected the existing `otherDate` fixture and were restored byte-for-byte afterward.
- Remaining: physical phone review, the full text-size/month matrix, and an overflowing calendar scroll check. No T2 installation, upload or push performed. Calendar follow-up approved for commit by Tessa.
