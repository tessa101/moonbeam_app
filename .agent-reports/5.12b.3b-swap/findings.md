# Build 5.12b.3b: location off ↔ on swap: findings

## Part 1: reproduce and diff (no fix)

### How it was recorded

iPhone 17 simulator (iOS 27.0, `C86BA1FD…`), Debug build of the working tree at `fb16d96` plus Tessa's uncommitted
DebugPanel / dial-height changes (no swap code touched). `record-swaps.sh` goes through Settings as a user would:
compass on → open Settings, `simctl privacy revoke location` → back to the app (**on to off**) → Settings,
`grant` → back (**off to on**). Revoking doesn't kill the app (same pid before and after), so both returns are real
in-app swaps, not cold launches. Irvine, CA; it's the current-location place, so granting goes straight to `.here`.

`simctl io recordVideo` first failed with "Host recording is already in progress", left over from the 3a run's
recorder that died in the sandbox (`after.mov.sb-…`). No process was left; rebooting the iPhone 17 simulator cleared
it. Not done on the T2 iPhone: the agent can't record or screenshot the phone (devicectl only).

The simulator recorder only writes a frame when the screen changes, so a 60 fps resample repeats frames. Times below
come from the real capture timestamps (`regionprobe.py`: mean brightness of the dial, prompt and bottom-note regions
on each captured frame), converted to 60 fps frame numbers from the start of `before.mov`. `before-frames/` has the
crops (`crop-on-to-off.png`, `crop-off-to-on.png`, `raw-off-to-on.png`).

The simulator has no compass: the heading service sends `.unavailable` (no true heading), so the entrance always waits
the full 500 ms `headingWait` and then comes in with the no-heading look. The phone usually gets a heading within a
few frames, so its gap is shorter (§5.1's video: about 3 frames).

### Frame counts (before)

| Swap | Cut / change starts | Empty gap | Dial first visible | Dial fully in |
|---|---|---|---|---|
| **Off to on** | frame 918 (15.30 s): the prompt starts fading; gone by frame 926 (15.43 s) | frames 926–938: **13 frames** of empty slot (21 frames from the prompt starting to leave to the dial) | frame 939 (15.66 s) | about frame 955 (15.92 s) |
| **On to off** | frame 380 (6.34 s), as the app's live frames take over from the app-switch | **none** | (no dial: it fades out) | prompt fully in by frame 394 (6.56 s) |

On to off is a **13-frame crossfade**: the dial fades out while the prompt fades in at the same time, so both show at
part opacity (frames 383–389 in `crop-on-to-off.png`), with the low-accuracy note sliding down. The capture stalled for
117 ms in off to on (15.31–15.43 s, no frames written), so the prompt's exit there can only be bracketed, not counted
frame by frame.

### Cause: §5.1 confirmed, with one correction

**Confirmed.**

1. The location-off block is a plain `switch viewModel.visibility` in `CompassView.body`. No `.transition`, no
   animation of its own, so on its own it's a one-frame cut each way.
2. Off to on: the compass branch is inserted at opacity 0 because `CompassEntrance` starts `.waitingForHeading`
   (sensors start → `beginEntrance()`), and stays out until a heading or the 500 ms wait. That's the empty gap. Then
   it fades in over `ContentLoadIn.duration` (300 ms, `entranceFade`).

**Correction: an unrelated animation leaks into the swap.** `LocationScreen` puts
`.animation(bottomBarAnimation, value: viewModel.compass.bottomNote)` (0.3 s ease-in-out) on the whole scroll view.
Whenever the bottom note changes in the same update as `visibility` (it does on every swap where a note was showing:
the compass's notes only exist with the compass shown), that animation catches the `switch` too. SwiftUI then gives the
inserted and removed branches the default opacity transition at 0.3 s. On the simulator the low-accuracy note is
always up, so:

- on to off is a 0.3 s **crossfade**, both at part opacity together (not a cut);
- off to on, the prompt **fades out** over that 0.3 s instead of cutting, and the dial is still held out, so the slot
  is empty between them.

On the phone the result depends on whether a note was showing when the swap happened. With no note it's §5.1's cut.
That fits the off-to-on cuts in `location_on_off.mov`. It doesn't explain that video's on to off ("dial fades out about
0.25 s, then the block appears in one frame"), and I can't reproduce that order here. A 0.3 s ease-in-out removal
would look like that 0.25 s fade, but the block would then fade in with it, not cut in afterwards. Could Tessa check
it on the phone with the after-build?

**Is this "a different cause"?** I don't think so. Both §5.1 mechanisms are there and are the main problem; the leak
is an extra contributor that hides the cut sometimes. It matters for the fix: the swap has to run on its own
transaction, so the bottom bar's animation can't override its timing. I've taken that as "confirmed, with a
correction" and gone on to Part 2. If you read it as a different cause, Part 2 is a separate commit and can be
dropped.
