# Day arrows still float: device video analysis (2026-10-09)

Source: Tessa's device video `arrow_bug_2.mov` (T2 iPhone, 58.7 s, 60 fps, build 5.10 `cb98c6e`, Irvine, "today" = Thu Oct 8).
Method: tracked the vertical position of each ‹ / › button in every frame (3,521 frames) and flagged jumps of more
than 8 px; matched each jump to the frame where the card's date label changed; read the dates from the frames.
Frames: `arrows-float-2-frames.jpg` (1/60 s apart; › jumps up in the first frame of a date change, then eases back).

## The motion
- In the **first frame** of the date change the tapped button is ~120 px (~40 pt) above its place, above the card's
  top edge. It eases back over **0.37–0.40 s**. The other button, the card height, the readout and the dial don't move.
- Float start = the date label's first changed frame, to the frame (no delay).

## Which dates (13 floats, all of them)
| t (s) | tapped | from → to | to |
|---|---|---|---|
| 13.10 | › | Sun Oct 18 → Mon Oct 19 | **Mon Oct 19** |
| 15.07 | › | Sun Oct 18 → Mon Oct 19 | **Mon Oct 19** |
| 17.67 | › | Sun Oct 18 → Mon Oct 19 | **Mon Oct 19** |
| 29.20 | ‹ | Tue Oct 20 → Mon Oct 19 | **Mon Oct 19** |
| 21.40 | › | Sun Oct 25 → Mon Oct 26 | **Mon Oct 26** |
| 22.87 | ‹ | Tue Oct 27 → Mon Oct 26 | **Mon Oct 26** |
| 26.25 | ‹ | Tue Oct 27 → Mon Oct 26 | **Mon Oct 26** |
| 32.17 | › | Sun Oct 25 → Mon Oct 26 | **Mon Oct 26** |
| 24.85 | › | Tue Oct 27 → Wed Oct 28 | **Wed Oct 28** |
| 33.17 | › | Tue Oct 27 → Wed Oct 28 | **Wed Oct 28** |
| 39.27 | › | Tue Nov 10 → Wed Nov 11 | **Wed Nov 11** |
| 43.08 | › | Tue Nov 10 → Wed Nov 11 | **Wed Nov 11** |
| 44.57 | ‹ | Thu Nov 12 → Wed Nov 11 | **Wed Nov 11** |

- **Every arrival on Mon Oct 19, Mon Oct 26, Wed Oct 28 and Wed Nov 11 floated (13/13), from either side, with
  either arrow.** The other ~60 date changes in the video (Oct 7 → Nov 14) never did. Not tap timing, not direction.
- The 2026-10-03 video (`arrows-float-frames.png`) shows the same dates (› Oct 25 → 26; ‹ to Oct 19).
- Dates 46.3 s onward (the page scrolls) are excluded.
- 4.6 s: tapping Today from the calendar sheet did not float (the sheet was open).

## What the four dates have in common: not found
Not label width (float and non-float dates overlap). Card data on the float dates (Irvine):
| Date | Phase | Rise | Set |
|---|---|---|---|
| Mon Oct 19 | Waxing Gibbous · 65% | 2:44 PM · 113° ESE | 12:20 AM · 244° WSW |
| Mon Oct 26 | Waning Gibbous · 98% | 6:16 PM · 64° ENE | 7:44 AM · 293° WNW |
| Wed Oct 28 | Waning Gibbous · 87% | 7:57 PM · 56° ENE | 10:10 AM · 303° WNW |
| Wed Nov 11 | Waxing Crescent · 9% | 8:47 AM · 124° SE | 6:23 PM · 236° SW (Moonset boxed) |

Neighbors that never float: Oct 18, 20, 21, 25, 27, 29, Nov 9, 10, 12, 13.
