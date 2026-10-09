# Place change after 5.10a.2: device video analysis (2026-10-09)

Source: Tessa's device video `5.10a.2_bug.MP4` (T2 iPhone, 17.6 s, 60 fps, build 5.10a.2 `e967f46`), Use my location
from the search sheet with Fri Oct 16 selected, previous place New York, new place Irvine. Frames:
`place-change-2-frames.jpg` (15 fps, 6.3 s → 8.1 s of the video; crop of the main screen).

## Timeline (video seconds)
| t | What shows |
|---|---|
| ~6.5 | Tap Use my location; the sheet starts to close |
| 6.57–6.9 | Sentence already reads "Where can I find the moon **today** in 📍 **your location**?" (the selected date, Fri Oct 16, is gone). Nothing below it |
| 6.9 | The debug buttons (Show onboarding / Forget saved place) fade in **directly under the sentence**: no card, no slot |
| 7.03 | The buttons drop ~100 pt as the skeleton frame appears |
| 7.03–7.2 | Skeleton card visible: "Finding your location…", quiet bars. **About 0.2 s** |
| 7.23 | **Blank screen: the sentence is gone too** |
| 7.3–7.37 | Sentence loads in again as "on Fri, Oct 16 / Irvine, CA?", overlapping the fading "your location" ghost |
| 7.4–7.7 | Card loads in, then the compass (150 ms stagger, as built) |

The fix landed ~0.7 s after the tap, so the skeleton (400 ms threshold) showed for ~0.2 s and vanished with the
sentence.

## Problems
1. **Stale-looking sentence:** the pending sentence says "today" (generic) while Oct 16 is selected, then Oct 16
   comes back.
2. **Sentence blanks and replays:** it fades out with everything else and loads in again (a second entrance), instead
   of staying put (LOADER.md §12.2 step 4: "the sentence doesn't replay").
3. **Layout jump:** the content below moves up ~100 pt while there's no card or skeleton, then back down.
4. **Skeleton flash:** ~0.2 s is too short to read; it looks like a glitch.
