# Step 5.10a.3 — Compass entrance on every reload

Implements LOADER.md §12.4 and §12.4.1, widened by Tessa (2026-10-12): the entrance must run **every time the compass
reloads with new information**, not just on a city change.

## Evidence
Tessa's phone recording, 2026-10-12 (launch, Irvine, CA): `compass_on_launch_bug.mov` (copy to
`.agent-reports/5.10a.3/` before starting; it is local and gitignored). Sampled frames:
1. Dial fades in **north-up** with a stale readout (`179° s`).
2. Rise / Set / Now markers and the letters **collapse to the dial centre** for ~1-2 frames.
3. Dial spins to the real heading (~185-190°) while the readout ticks 179 → 185 → 190.
Total ~0.7 s; ends correct. The city-change case was already fixed and looks right on the phone.

## Contract
- Same entrance (§12.4) for every genuine entrance trigger: launch, place change, return to foreground, heading or
  location arriving late, recovery from a failure screen. List the triggers actually found in code and say which
  already share the path.
- Revised 2026-10-16: a date-only change updates markers in place and does not replay the settle.
- Wait for the first heading (≤ 0.5 s), then load in aligned or ~10° off and settle over 0.5 s. Never show north-up
  first. No heading in 0.5 s: no-heading look, turn when it arrives.
- Dial, letters, numbers and targets rotate as **one piece**, shortest path, unwrapped angle. No independent
  `.position` animation: the centre collapse above is that bug.
- Readout shows the final heading when it appears; no 179 → 190 counting during the entrance.
- Reduce Motion: fade in, already aligned, no settle.
- Also in scope (§12.4.1): readout fades out while a lock is about to engage; Now pulse continues until Now is locked.

## Tests
- Frame-sampling test (as 5.10b) that **fails on today's launch behaviour**: no frame with the dial north-up when the
  heading is not north; no frame with targets inside the centre radius; readout never shows a stale value.
- One test per reload trigger above proving it goes through the same entrance.
- Reduce Motion variant. §12.4.1 readout and pulse tests.

## Environment
Do not run `xcodebuild test` or `simctl` (pseudo-terminal hang). `build-for-testing` only; give me exact Terminal
commands. Log to `.agent-reports/progress.log` before each step. One commit. Do not push.
