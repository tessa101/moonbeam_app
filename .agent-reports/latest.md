# Build 5.10a.3: hidden city line + shimmer skeleton

Updated October 9, 2026.

- **Done:** built and tested the uncommitted 5.10a.3 changes.
  - The city line is hidden during My location and fades in at 0.5 s.
  - The skeleton has shimmering blocks and no "Finding" text, and fades into the card at 0.5 s.
- Compiled first time. One test error fixed (test only): `pendingPlace()` omitted the zone a pending place always has. Full suite **989/989 pass**.
- **Flags for Tessa:**
  - After a failure the hidden city line leaves no way into search.
  - The 0.5 s reveal may run at the 0.15 s token fade.
  - The DECISIONS.md entry sits at the bottom of the file.
  - "5.10a.3" was the compass entrance's number.
- **Next:** Tessa's device check and answers to the flags; then the compass entrance, under a new number.
- Findings: `.agent-reports/5.10a.3/findings.md`.

---

# Build 5.10a.2b: sentence stays, slot held, skeleton minimum

Updated October 9, 2026.

- **Done:**
  - The sentence never leaves on a place change and keeps the selected date. Only the city token cross-fades: "your location", then the city.
  - The load-in replays for the card and compass only.
  - The card slot is held from the first frame.
  - The skeleton stays at least 350 ms once shown, then cross-fades into the card.
- **Tests:** 5 new in `PlaceSkeletonTests`, plus `PlaceChangeLayoutTests`, which samples every 16 ms through a 700 ms fix. Full suite **988/988 pass**.
- **Hang:** no stuck processes were found. The new suite didn't hang under time limits; its pixel check was broken (16-bit capture) and is fixed.
- **Not done:** no simulator recording or extracted frames this run; the 16 ms sampling test is the frame evidence.
- **Next:** Tessa's device check, then 5.10a.3 (compass entrance).
- Findings: `.agent-reports/5.10a/5.10a.2b-findings.md`.

---

# Build 5.10a.2: card skeleton during Use my location

Updated October 9, 2026. Continued from Codex's uncommitted work.

- **Done:** when the fix takes over 400 ms, a skeleton sized by the replaced card holds the slot. Moon outline breathing, quiet bars, "Finding your location…" on the date line. 200 ms cross-fade into the real card. No compass or bottom bar until the card is in. VoiceOver focus moves to the card.
- A failed fix, a refused prompt or Location Off shows "Couldn't find your location. Try again, or search for a city." inside the skeleton. A retry shows "Finding" at once.
- 6 new `PlaceSkeletonTests`; full suite **982/982 pass**.
- **Not done:** no on-screen check this run (a slow fix is hard to stage in the simulator); needs a device look.
- **Next:** 5.10a.3 compass entrance + readout fade + Now pulse (LOADER.md §12.4, §12.4.1).
- Findings: `.agent-reports/5.10a/5.10a.2-findings.md`.

---

# Build 5.10c: stronger day-arrow response

Updated October 9, 2026.

- ‹ › only: pressed scale **0.88**, `surfaceRaised` + **10% white**, visible for at least **90 ms**, then a **0.15 s spring** release.
- One **soft 0.5** impact per enabled arrow step; none for disabled arrows, Today, or calendar selection. Shared button feedback is unchanged.
- The extended regression drives press + quick release and samples both arrow frames every 16 ms for ~0.5 s across all four §9.19 dates, both directions, plus spread dates.
- Simulator held/quick presses each stepped exactly once, with invariant 44 pt arrow frames and card layout. Full suite: **974/974 pass**.
- Findings and screenshots: `.agent-reports/5.10c/`.

---

# Build 5.10b: day-arrow transient fixed

Updated October 9, 2026.

- Reproduced the four date-dependent cases before changing code and traced the movement to `MadlibSentence`: its documented fixed line slot used `minHeight`, so fractional font metrics could make the sentence's layout height date-dependent during the tap transaction.
- Changed the slot to an exact height; card animation and the 5.10 press-feedback scoping remain enabled.
- Added a regression that samples both arrow frames every 16 ms for ~0.5 seconds, entering all four reported dates from both directions plus three spread dates.
- Post-fix device inspection: identical arrow/card coordinates on Oct 18 → 19, Oct 26, Oct 28, and Nov 10 → 11. Full suite: **973/973 pass**.
- Findings and screenshots: `.agent-reports/5.10b/`.

---

# Build 5.10: day arrows + landing-haptic audit

Updated October 8, 2026.

- `569e3b3`: fixed the floating tapped day arrow by scoping `PressFeedback`'s spring to scale and opacity; the spring can no longer animate a concurrent date-header relayout.
- Added the COMPASS-1.1.md §9.16 regression: 61 sequential real card renders at iPhone 17 and SE 3 widths; 2/2 focused cases pass, including Oct 3 and Oct 25 → 26.
- Landing haptic: no clear bug and no code change. It is intentionally soft and recovery-flight-only (LOADER.md §11.2.7), distinct from COMPASS.md §4.5's firm compass-lock tap. Full suite: **972/972 pass**.
- Findings and screenshots: `.agent-reports/5.10/`.
- `5122505` was pushed first, before either 5.10 item.

---

# Codex takeover: TestFlight 1.0 (8)

Updated October 6, 2026.

- 5.9.3a is complete at `1b66c3e` (the earlier report below had not caught up).
- Last recorded upload: 1.0 (7), same content as build 6, October 3.
- App build number changed from 7 to 8 in Debug and Release; marketing version stays 1.0 as confirmed by Tessa.
- Current verification: 648 tests / 970 cases in 49 suites pass; signed Release archive succeeds and its bundle is verified as 1.0 (8).
- Release assessment and paste-ready tester notes: `docs/TESTFLIGHT-BUILD-8.md`.
- Archive: `/Users/tc/app-ideas/moonbeam/build/releases/Moonbeam-1.0-build-8.xcarchive`.
- Upload succeeded October 6 at 9:13 PM PDT; Apple reports the uploaded package is processing.
- Tester notes have not been saved in Apple’s web interface because the browser session is signed out.
- Next: paste the tester notes after processing; physical-device permission recovery, transition and haptic checks.
- Known deferred work: loader accessibility review, main-screen AX reflow (5.5), parked day-arrow movement issue.
- No commits created during this takeover yet.

---

# Agent report: Step 5 (Design 1.1, Madlib)

_Updated 2026-10-06. Newest commit first. All commits are **local** (not pushed)._
_The previous report (Step 4 compass, through TestFlight prep) is now `step-4-compass.md`._
_Spec: DESIGN-1.1.md §2, §3.1a, §3.2, §3.3, §3.3a, §5, §7, §11; COMPASS-1.1.md; LOADER.md · decisions: DECISIONS.md 2026-09-30 "Design 1.1", 2026-10-01, 2026-10-02, 2026-10-03, 2026-10-05._

---

## `87d26be` · Build 5.9.3b.6: 150 ms load-in stagger; haptic when the moon lands (LOADER.md §11.2.7) · **local**

| Item | Change |
|---|---|
| Stagger | One constant, `ContentLoadIn.stagger` = **150 ms** (was 70), everywhere: sentence 0 → card 0.15 → compass 0.30 s. After Aha: **0.30 / 0.45 / 0.60 s** from the flight start (compass was 1.0 s) |
| Haptic | Soft tap (`.impact(flexibility: .soft, intensity: 0.6)`) once as the flying moon lands in the card; never without a flight. Reduce Motion: at the end of the loader's 0.2 s cross-fade |
| Docs | Your §11.2.7 + DECISIONS, plus an as-built note |
| Tests | **969 cases, all pass** (Xcode's runner, iPhone 17; Xcode back on the T2 iPhone) |

**Recordings:** `5.9.3/settings-recovery-b6.mov` (+ `10-…-8fps.png`) and `fast-launch-b6.mov` (+ `11-…-10fps.png`, a real cold
relaunch with location allowed). Both show sentence → card → compass, 150 ms apart.

**Not checked:** the haptic itself, which the simulator can't play. Please feel it on the phone: denied → Settings → allow → back.

**Device:** Debug build of `87d26be` installed on the **T2 iPhone** and launched (devicectl).

**Next:** your device check, then **5.9.3a** (line height / text width).

---

## `3935a87` · Build 5.9.3b.5: Aha out earlier; main screen by block around the flight (LOADER.md §11.2.6) · **local**

| Item | Change |
|---|---|
| Aha | Leaves **as the flight starts**: 0.25 s fade, up 6 pt. Gone before anything on the main screen appears |
| Main screen (after a recovery) | By block from the flight start, §2.1's fade + 8 pt rise: **sentence 0.30 s, card 0.45 s** (in before the 0.85 s landing), **compass 1.0 s** (after it). Was one 0.6 s fade over everything |
| Unchanged | §2.1 fast-launch load-in; Reduce Motion |
| Docs | Your §11.2.6 + DECISIONS, plus an as-built note |
| Tests | **968 cases, all pass** (Xcode's runner, iPhone 17; Xcode back on the T2 iPhone) |

**Recording:** `5.9.3/settings-recovery-b5.mov` (+ `9-settings-recovery-b5-6fps.png`): a real Settings recovery. Aha
out as the moon starts to shrink, then sentence, card, compass in that order.

**Device:** Debug build of `3935a87` installed on the **T2 iPhone** and launched (devicectl).

**Next:** your device check, then **5.9.3a** (line height / text width).

---

## `c4adb31` · Build 5.9.3b.4: the flight overlaps the landing (LOADER.md §11.2.5) · **local**

| Item | Change |
|---|---|
| Overlap | Flight starts **0.25 s before the ride ends** (ride's midpoint if it's under 0.5 s); the phase settles during the flight |
| Curve | Flight `cubic-bezier(.3, .3, .25, 1)`: moves from the first frame (was `.65, 0, .25, 1`, from rest); still 0.85 s |
| Aha | Rules unchanged; now readable ~1.15 s before its fade (the flight starts 0.25 s earlier) |
| Docs | Your §11.2.5 + DECISIONS, plus an as-built note |
| Tests | **967 cases, all pass** (Xcode's runner, iPhone 17; Xcode back on the T2 iPhone). New: the moon is never at rest across the handover |

**Recording:** `5.9.3/settings-recovery-b4.mov` (+ `8-settings-recovery-b4-6fps.png`): a real Settings recovery. The
landing crescent is already shrinking and moving in the first frame after it settles (in b.3 it sat unchanged for 2 frames).

**Device:** Debug build of `c4adb31` installed on the **T2 iPhone** and launched (devicectl).

**Next:** your device check, then **5.9.3a** (line height / text width).

---

## `149ebfc` · Build 5.9.3b.3: no pause after the moon lands (LOADER.md §11.2.4) · **local**

| Item | Change |
|---|---|
| Rest | **Gone.** The flight starts at the soft landing. The flight's curve already starts from rest, so landing → flight is one motion (no curve change) |
| Aha | Stays into the flight; fades **from 0.4 s in, over 0.3 s** (was 0.22 s at the start), as the city screen comes in. Readable ~1.4 s |
| Timing | Fix → flight 1.6–4.2 s (0.6 s shorter) |
| Docs | Your §11.2.4 + DECISIONS, plus an as-built note |
| Tests | **961 cases, all pass** (Xcode's runner, iPhone 17; Xcode is back on the T2 iPhone) |

**Recording:** `5.9.3/settings-recovery-b3.mov` (+ `7-settings-recovery-b3-6fps.png`): a real Settings recovery in the simulator.

**Check on the phone:** both eases meet at zero speed, so the moon barely moves for ~0.3 s around the landing. It never
stops, but if it still reads as a pause, the next step is a quicker flight start (`cubic-bezier(.4, 0, .25, 1)`) or
starting the flight ~0.15 s before the landing.

**Device:** Debug build of `149ebfc` installed on the **T2 iPhone** and launched (devicectl).

**Next:** your device check, then **5.9.3a** (line height / text width).

---

## `59de60b` · Build 5.9.3b.2: recovery, moon first (LOADER.md §11.2.3) · **local**

| Item | Change |
|---|---|
| Order | Fix lands → the moon **rides on at once, at the cycle's own speed**, easing out to a soft stop on the real phase. Label leaves as built. **"Aha" floats up 1.0 s before the landing**; **0.6 s rest**; then the flight |
| Ease | Cubic from the cycle's speed to rest: no dip at the handover, never backwards. The handoff's slow start is gone |
| Judgement call | A fast cycle just short of the target would overshoot a 1.6 s ride, so the ride is **shortened** instead (speed carries on). Open for you |
| Timing | Aha + city on screen 1.6 s; fix → flight 2.2 s (short ride) to 4.8 s (longest first ride) |
| Docs | Your §11.2.3 + DECISIONS, plus as-built notes |
| Tests | **959 cases, all pass** (Xcode's runner; +11) |

**Recording:** `5.9.3/settings-recovery.mov` (+ `6-settings-recovery-4fps.png`): a real Settings recovery in the
simulator (denied → Settings → granted → back). The moon carries straight into the ride (first install, so a lap),
"There we are." near the end, soft stop, flight onto "Waning Crescent · 13% lit". Findings: `5.9.3/findings.md`.

**Device:** Debug build of `59de60b` installed on the **T2 iPhone** and launched (devicectl; the product has the new ride code).

**Next:** your device check of 5.9.3c / b / b.2 on the T2 iPhone, then **5.9.3a** (line height / text width).

---

## `e7b4584` · `f18a68f` · Build 5.9.3b: transitions + phase ride, onboarding earthshine · **local**

| Commit | Change |
|---|---|
| `e7b4584` **5.9.3b** | Label leaves **at the fix** (measured 2.7–3.0 ms; target < 50 ms), its 0.7 s counted from the session start; Aha exit 0.35 s drifting up 6 pt, Aha in at 0.15 s over it. The moon keeps running, then **rides forward to the card's real phase** (`PhaseRide`, 1.6–4.2 s, handoff ease), rests 0.4 s, flies with no phase change. **First ride after install: +1 lap** (`hasSeenFirstFindPass`; Show onboarding / `-resetOnboarding` clear it). Reduce Motion: 2 s hold, cross-fade to the real phase. Your doc changes included |
| `f18a68f` **Onboarding earthshine** | §11.6 item 5: onboarding moon's dark side is earthshine, matching the loader |
| Tests | **948 cases, all pass** (Xcode's runner; +20: ride, round-trip, flag, session minimum, Reduce Motion) |

**Label stall cause** (details in `5.9.3/findings.md`): it waited for the moon's run to full (up to 2.05 s), its 0.7 s
counted from its own return (+0.2 s), and its exit snapped 8 pt down as it began.

**Frames:** `5.9.3/aha-ride.mov`, `3-aha-ride-4fps.png` (first ride with its lap, landing on "Last Quarter · 53%"),
`4-label-aha-overlap.png`, `5-onboarding-earthshine.png`.

**For your check:** (1) the ride's ease starts slow after a running moon, so look for a hitch; (2) first Aha is now
~4.8 s; (3) the extra lap only happens on a *recovery*, because onboarding → Allow has no Aha; (4) the Aha flare isn't used
any more (glow follows k), the code is still there.

**Next:** your device check, then **5.9.3a** (line height / text width).

---

## `ab40fbe` · Build 5.9.3c: moon smoothness (LOADER.md §11.3) · **local**

Your prompt said 5.9.3a, but it pointed at §11.3 + `MoonLoader.swift`, which §11.4 calls **5.9.3c** (first in the
order), so I built that. Line height / text width (§11.1) aren't started.

| Item | Change |
|---|---|
| Month | Handoff timing: 2.2 s sweep, **0.4 s at full**, 2.2 s back; each sweep eased `q − 0.85·sin(2πq)/2π` |
| 4b | Already `PhaseGlyph`'s geometry: reused, so it lands on the card with no swap |
| Dark side | Earthshine `#2A2127`, blending to the card's disc during the flight |
| Glow | Halo 0.12 + 0.88k / scale 0.94 + 0.1k; tight glow 0.35k (no separate clock) |
| Stop | 2.6×, then slows steadily to rest over the last 0.4 s (was an instant freeze); +0.2 s per run-out |
| Docs | LOADER.md §11 + DECISIONS + STATUS from you, plus as-built notes; `design/1.5-loader-polish/` |
| Tests | **928 cases, all pass** (Xcode's runner; +5). The command-line `xcodebuild test` hung on "Pseudo Terminal Setup Error" after compiling and was stopped at 10 min |

Frames + findings: `5.9.3/` (cycle contact sheet, `loader-cycle.mov`, a held message moon). The eased stop isn't
recorded; tests cover it.

**Open for you:** `MoonStyle` switch not added (only 4b is drawn); handoff 0.8 pt blur left out; onboarding's moon
disc still `bg` (should it be earthshine too?).

**Next:** your check, then **5.9.3b** (transitions + phase ride).

---

## `6966469` · `926d0ec` · `c98757e` · `4c6928c` · Build 5.9.2 flow pass: your A/B/C calls + Forget saved place · **local**

| Commit | Change |
|---|---|
| `6966469` **A** | A reason known before the cycle starts (permission off etc., no saved place): the moon stays at the hold phase, no 2.6× spin. Message in at ~1.55 s (was ~3.3 s) |
| `926d0ec` **B** | Loader stays at least **1.1 s** (was 700 ms), so the entrance finishes (label in at 1.02 s) |
| `c98757e` **C** | Aha's run to full starts **as soon as the fix lands**; Aha at full. The 1.8 s search minimum is gone; the label keeps 0.7 s (its fade-in) so a fast fix doesn't flash it. Fix while waxing: Aha ~0.7 s after the label; past full: ≤ 1.85 s after the fix. Supersedes `1c3b8ac`'s "Aha up to 1.85 s later" |
| `4c6928c` **Forget saved place** | Beside Show onboarding, same builds (DEBUG / TestFlight), **removed with it before 1.0**. Clears last-viewed + recents, then reruns the launch flow. Permission and onboarding untouched |
| Tests | **622 tests / 923 cases, all pass** (Xcode's runner, iPhone 17 simulator). +5: known reason holds, fast-fix Aha, Aha past full, forget → message, forget → found again |
| Device | Debug build installed on the **T2 iPhone** and launched (devicectl; the product has `forgetSavedPlace`) |

**Try on the phone:** Settings → Moon Signal → Location → Never, then Forget saved place → the moon holds, "can't see
your location" at ~1.5 s → Open Settings → While Using → back: searching, then Aha as the moon reaches full, and the
flight into the card. With location allowed, Forget saved place is just an ordinary launch (it finds you again).

**Not checked:** the button pair on screen (no screenshot; it's two text links in an `HStack`, stacked if they don't
fit); no new simulator recording of A / C. The destination in Xcode is the iPhone 17 simulator again (it was set to
the T2 iPhone, where the test target can't sign).

**Next:** your device check. Then re-record recovery → Aha, and walk the remaining flows on screen.

---

## `1581c4e` · `1c3b8ac` · Build 5.9.2 default-size flow pass, part 1 · **local**

Findings: `5.9.2/main-flows/findings.md` (shots in `main-flows/iphone17/` are from the previous run, which stopped
before writing them up).

| Item | Change |
|---|---|
| `1581c4e` | Committed the previous session's docs: 6/6 accessibility deferred, default-size flow pass next (Tessa) |
| `1c3b8ac` **Aha fix** | Aha's text came in over a dark moon: after 1.8 s of searching the moon is past full, and the run to full went through new (1.49 s). Run-out now under the label; flare + Aha only at full. Up to 1.85 s later |
| Tests | **618 tests / 919 cases, all pass** (Xcode's runner); new `ahaWaitsForFull`, `ahaStep` updated |

**For you:** (A) known-reason messages take ~3.3 s, with a fast 2.6× month just before the stop. I'd skip the cycle
when the reason is known before 840 ms (message at ~1.55 s). (B) The ≥ 700 ms loader hold predates the entrance, so
a fix just past 400 ms shows a half-faded still moon; raise it to ~1.1 s? (C) OK with Aha being up to 1.85 s later,
or shorten the 1.8 s search instead?

**Next:** re-record recovery → Aha; walk permission / Settings / search-from-message on screen.

---

## `44e1eb4` + `f580df9` · Build 5.9.2 (5/6): small screens and large text · **local**

| Item | Change |
|---|---|
| Fit decision | Measures the current message's natural height at the current Dynamic Type size; the default layout is unchanged when it fits |
| Compact | 140 → 96 pt moon, lifted 28 pt; headline/body base sizes step together to 0.8× while continuing to scale with Dynamic Type |
| AX fallback | Only the message region scrolls if the compact form still does not fit; actions remain reachable |
| Button | Visual matrix found the primary grew at AX sizes; fixed by keeping this loader CTA at its default content size. It is exactly 56 pt high in all 30 cells; the full title remains available to VoiceOver |
| Validation | **30 / 30 visual cells pass** and **918 / 918 tests pass**; clean Xcode build. Five messages × iPhone 17 / SE 3 × default / AX1 / AX5. All copy is readable, actions have hit points, and every overflow case scrolls. Full findings + 8 lean screenshots: `5.9.2/5-ax/` |

The primary is `346 × 56` on iPhone 17 and `319 × 56` on SE 3 at every tested size. iPhone 17 default / AX1 fit;
all AX5 states scroll. SE 3 AX1 and AX5 overflow states scroll; AX5 First ask takes two swipes. Secondary text
actions still scale and wrap. No truncation or overlap found.

**6/6 note:** the invisible outgoing “Finding your location…” label remains in the accessibility hierarchy behind
a settled message; address with the VoiceOver focus/exposure work.

**Next:** §10.6 Reduce Motion / VoiceOver (6/6), including focus moving to the message headline.

---

## `1cdae86` · Build 5.9.2 (4/6 follow-up): hold phase is a waxing gibbous · **local**

| Item | Change |
|---|---|
| **Hold phase** | `PhaseCycle.holdElapsed` now solved in the waxing half: ~83% lit, lit right, dark sliver on the **left** (was the handoff's waning one). The loader appears on it, the month grows toward full from it, messages freeze on it |
| **Onboarding moon** | `OnboardingMoon.geometry` matches (waxing, 83%); the test that keeps the two in step still holds |
| **Aha** | Run to full from the hold is now ~0.2 s (a new test checks it is under a quarter of the run-out month) |
| Docs | LOADER.md §10.2 (hold phase), DECISIONS 2026-10-06 |
| Tests | **617 / 918, all pass** (Xcode's runner); hold-phase, entrance and run-out tests rewritten for the waxing side |
| Shot | `5.9.2/aha/4-hold-waxing.png`: App permission off, moon frozen at the new hold phase |

**Not re-shot:** the Aha / fly frames are from before this change (they show the old waning run-up before full; the
Aha frame itself is at full either way).

**Next:** §10.5 small screens / large text (5/6), §10.6 Reduce Motion / VoiceOver (6/6). Stopped here as asked.

---

## `4c6aea9` · Build 5.9.2 (4 of 6): "Aha" after a recovery, restricted copy · **local**

Spec LOADER.md §10.4 (as-built note added). Shots `5.9.2/aha/` (iPhone 17, default size): `1-aha.png`,
`2-fly-early.png`, `3-fly-late.png`, plus the source recording `recoveryAha.mov` (DEBUG `-screenState recoveryAha`:
No fix, then a fix and Try again on their own).

| Item | Change |
|---|---|
| **Aha** | Only after Try again, Allow at First ask's prompt, back from Settings allowed, or the search row from a message. Label ≥ 1.8 s, then the moon runs to full at 2.6×, glow flares, line + city fade in and rise 10 pt, hold 2 s |
| **Lines** | "Aha, there you are!", "Hey, found you.", "There we are."; never the same twice in a row **within a session** |
| **Fly** | The loader stays over the screen; the moon flies 0.85 s into the card glyph's real frame (anchor preference), full → today's phase, glow → 0.35; Aha out 0.22 s, 3 pt up; screen fades in 0.6 s after 0.25 s (no stagger, no rise); the card's glyph shows as the moon lands |
| **VoiceOver** | One element, "Hey, found you. Irvine, CA", announced when it appears |
| **Restricted** | Body "Location access is limited on this iPhone. You can still search for a city."; button aligned with the other messages' (the link's room is kept, hidden) |
| **Clock** | The loader has its own clock (`loaderNow`, real time). Found while recording: DEBUG states pin `now` to Oct 2, so the flight read as finished and the moon jumped into the card. Fixing it also gives DEBUG shots the real 840 ms entrance hold |
| Tests | **617 tests / 918 cases, all pass** (Xcode's runner). +7: Aha after recovery / after the prompt / not on an ordinary launch, line rotation, VoiceOver label, flight endpoints, the loader's Aha step |

**Seen in the recording:** the recovering moon runs from the (waning) hold phase through a long dark new moon
before full, and Aha's text can be in before the moon is full. The hold-phase mirror (next) is meant to fix that.

**For you:** (1) Persist the last line across launches? That needs a small stored value; I didn't add it without
asking. (2) Onboarding's own location prompt doesn't get Aha (I read "the iOS prompt" as First ask's); say if it should.

**Next:** the hold phase mirrored to a waxing gibbous + onboarding moon (this run), then §10.5 small screens / large
text, §10.6 Reduce Motion / VoiceOver.

---

## `7861a24` · `fd777ad` · `c50d987` · `37361ab` · Build 5.9.2 (1–3 of 6): location flow, messages · **local**

Spec LOADER.md §10 (Tessa's handoff `design/1.4-location-flow/`). Progress log: `progress.log`. Report:
`5.9.2/5.9.2-messages.md`; shots `5.9.2/shots/` (the five messages + one mid-transition, iPhone 17, default size).

| Commit | Item |
|---|---|
| `7861a24` | (1/6) **Launch screen** is `bg` (#1B1519), not black |
| `fd777ad` | (2/6) **Hold phase + entrance** (§10.2): moon starts at the onboarding phase, fade + 8 pt rise, label at 320 ms, cycle at 840 ms; runs out at 2.6× to a target, never mid-cycle; glow breathe / pulse / flare |
| `c50d987` | (3/6) **Messages** (§10.1–10.3): no saved place and no fix → the loader stops on First ask / App permission off / Services off / Restricted (search is the button, no Settings) / No fix (timeout or offline). Searching ≥ 1.2 s, moon freezes at the hold phase, glow pulses, message fades in and rises 16 pt. Use my location, Don't Allow, Open Settings and back, Try again, Search for a city all handled; return = message gone at once, cycle back after 0.2 s. A saved place still opens directly. The no-place "Use my location" button is gone |
| `37361ab` | (3/6 follow-up) DEBUG `-screenState messageFirstAsk / messageDenied / messageServicesOff / messageRestricted / messageNoFix` for the shots; the 2 `PhaseCycleTests` warnings fixed (hold-phase test now `@MainActor`) |
| Tests | **610 tests / 911 cases, all pass** (Xcode's runner, re-run after `37361ab`). New `LoaderFlowTests` (+3 for the search sheet's Use my location row from a message, which used to leave the loader stuck on it) |

**The 2-hour test hang:** two launch tests (`onboardingResetsToWaiting`, `timeoutFallsBack(false)`) launched with no
saved place. Since 3/6 that stops on a message, whose 1.2 s wait sat on a manual sleeper the test never fired. Both
now use a saved place (the no-place case is `LoaderFlowTests`). The four suites that wait on gates have
`.timeLimit(.minutes(1))`; that's what caught them. CLAUDE.md rules 6–7 committed with 3/6.

**Next:** 4/6 onward: "Aha" after a recovery (§10.4), small screens / large text (§10.5), Reduce Motion / VoiceOver
(§10.6: focus to the headline isn't wired yet).

**For you (from the shots):** (1) Restricted uses the app-permission body ("Allow location access…"), as the
handoff says, but a restricted user can't allow it: keep, or a restricted line? (2) With no link under it, Restricted's
button sits lower than the others'. Fine?

**Blocked / not done:**
1. **`xcodebuild test` can't run from this session:** it can't open a pseudo-terminal (`openpty: Operation not
   permitted`, sandboxed or not). Tests run through Xcode's runner instead.
2. **Warnings left:** 11 in `Vendor/Astronomy/astronomy.c` (comma operator; untouched, `Vendor/` needs your OK), and
   2 deprecations that showed up in this build, outside 5.9.2: `MoonTableFormatter.swift:145` (`attributed`, iOS 18)
   and `BuildChannel.swift:41` (`appStoreReceiptURL`, iOS 18). Xcode's issue list still shows a stale
   `timeoutFallsBack(hasLastViewed:)` time-out from the 09:26 run; that test has no arguments now and passes.
3. Shots are iPhone 17 at default size only; SE 3 / AX sizes come with §10.5.

---

## `1862e32` · `cf6e3ee` · `3e8f1f3` · Build 5.9.1: launch stall, content load-in, crescent start · **local**

Per DECISIONS.md 2026-10-05 "Launch: content loads in" (LOADER.md §2.1, §9). Report: `5.9.1/5.9.1-launch-fix.md`;
recordings `5.9.1/recordings/` (fast + slow launch, iPhone 17 simulator), frame sheets `5.9.1/shots/`, device
timings `5.9.1/traces/`.

| Commit | Item |
|---|---|
| `1862e32` | **Stall:** not reproduced on the T2 iPhone (~10 cold launches incl. your home-screen taps, all `ready` in 0.25–0.45 s; with a fix held 3 s the moon showed at 579 ms). Fixed at the likely cause: `locationServicesEnabled()`, which Xcode flagged on this device as able to block the main thread, ran before the first frame and before the 400 ms wait; now read only for not determined / denied. **4.8 retry** could cancel the launch fetch (reproduced in a test: launch opened with no place); now skipped until `ready`. os_signposts kept |
| `cf6e3ee` | **Load-in:** no whole-screen fade; sentence → card → compass, opacity + 8 pt rise, 300 ms, 70 ms apart; Reduce Motion: no rise. After the phase cycle, same, as the loader fades out (200 ms). Runs once per arrival. DEBUG `-screenState launchFast` / `launchSlow` |
| `3e8f1f3` | **Crescent:** the loader's month starts 25% lit (60°), solved from the eased curve; first quarter 0.23 s later, full at 1.43 s |
| Tests | **562 tests / 857 cases, all pass** (was 552 / 843) |

**For you:** (1) Look at the final build on the phone: it's installed on the T2 iPhone; my question to you didn't go
through. (2) No Instruments trace: this session can't run `xctrace`; the signposts are there for your own trace.
(3) The system launch screen is **pure black**, and the `bg` backdrop then comes up over it. That could be the
"scrim" feel. Want a `bg` launch-screen colour? (Info.plist + colour asset.) (4) Is 25% the right start? It's on
the fast part of the ease.

---

## `5e2ba79` · Build 5.9: launch loader · **local**

Spec LOADER.md, all sections (as built §8), per DECISIONS.md 2026-10-03 "Launch loader simplified". Report:
`5.9/5.9-launch-loader.md`; 20 shots + 4 contact sheets in `5.9/shots/` (loader × iPhone 17 / SE 3 × default / AX1 / AX5,
a 0.15–5.2 s phase series, the fast fix, and the screen after the timeout).

| Item | Change |
|---|---|
| Under 400 ms | No loader; the screen fades in over 250 ms. Backdrop only until then |
| Over 400 ms | Centred 140 pt phase-cycle moon, forward, 4.8 s month, eased at new / full, glow brightest at full; "Finding your location…"; held ≥ 700 ms, then a cross-fade |
| While loading | Nothing else is built: no sentence / "a city", card, compass, pinned bar, DEBUG readout or Show onboarding |
| A11y | Reduce Motion: still full moon, glow only fades. VoiceOver: announced once per launch, then focus to the sentence. Text wraps at AX sizes, moon stays 140 pt |
| State | `LocationViewModel.launchStage` (`LaunchStage`), waits through an injected `sleep`; after onboarding it waits again |
| Docs in this commit | Your uncommitted DECISIONS (2026-10-03), LOADER.md rewrite, STATUS, DESIGN-REVIEW Dynamic Type note, `CURRENT_PROJECT_VERSION` 7 and `design/1.1/loader-1a-phase-cycle.mov`; plus LOADER.md §8, LOCATION.md §3 note, DECISIONS 2026-10-05, STATUS, DESIGN-REVIEW, CLAUDE.md count |
| Tests | **552 tests / 843 cases, all pass** (Xcode's runner); new `LaunchLoaderTests`, `PhaseCycleTests` (21 cases; the old total was 822, not 823) |

**For you:** (1) a launch timeout falls back **quietly**, with no failed-fetch note. LOADER.md §2 mentions a note but
defers to LOCATION.md §3, which has none. Confirm, or I add it. (2) The month starts at new, as the mock does, so a
fix at ~450 ms shows mostly glow; starting at a quarter would show more moon. (3) Text 17 pt `body` (mock 16).
Not checked: a real slow fix on device, and Reduce Motion / VoiceOver on screen.

---

## `305080b` · TestFlight prep: build 5 · **local**

> **Correction (Tessa, 2026-10-03):** uploaded twice, as **1.0 (6)** and **1.0 (7)**. `CURRENT_PROJECT_VERSION` is now 7 (next upload 8); STATUS.md item 10 updated. Committed as `c695c94`; Release build re-checked: CFBundleVersion 6.

1.0 (5): `CURRENT_PROJECT_VERSION` 4 → 5 (app target, Debug + Release). Everything since build 4 (`2be3270`): the
Compass 1.1 spike (5.4.1–5.4.8) and 5.6. Tester notes, Release checks and known issues: STATUS.md item 10.
Release build (generic iOS, unsigned) checked: version 5, fonts, OFL texts, privacy manifest, dark, name, iOS 26.0,
export compliance, location strings, icon renditions; DEBUG code compiled out (0 `DebugScreenState` / debug-readout
symbols). **536 tests / 823 cases, all pass.** Not archived or uploaded. Xcode's destination is back on "Any iOS Device
(arm64)". Your DESIGN-REVIEW.md note (Dynamic Type) is still uncommitted.

---

## `f0e9140` · Build 5.6 [spike]: pinned compass bar while the dial's centre is below the fold · **local**

Spec COMPASS-1.1.md §9.6, DESIGN-1.1.md §4.1 (as built §9.18). Report: `5.6/5.6-pinned-bar.md`; 54 screenshots +
contact sheets `5.6/shots/` (9 states × iPhone 17 / SE 3 × default / AX1 / AX5), scroll check `5.6/shots/5.6-scroll-*`,
centre / fold numbers `5.6/probe/summary.txt`.

| Item | Change |
|---|---|
| Rule | `showsPinnedBar`: compass shown and the dial's centre below the fold (home indicator, or a bottom note's top) |
| Sensors | Also run while the bar shows, so its heading is live with the compass off screen (COMPASS.md §1) |
| Bar | 64 pt glass capsule: live readout + **Compass ↓** (scrolls the compass to the top); amber with the lock text on lock; on top of a bottom note |
| AX | "↓" button when "Compass ↓" doesn't fit (first try truncated the lock text); text capped at AX1 |
| Fixed before commit | The fold counted the bottom inset twice, so the bar showed too early on the SE 3 with a note |
| Tests | **536 tests / 823 cases, all pass** (Xcode's runner); 6 new pinned-bar tests in `CompassViewModelTests` |

| Default size | Dial centre | Fold (no note / Precise) | Bar |
|---|---|---|---|
| iPhone 17 | 638.3 | 840 / 758.7 | never |
| SE 3 | 582.5 | 667 / 585.5 | never (3 pt clear) |

**For you:** at the default size the bar **never shows**, even on the SE 3, with the 5.4.7 / 5.4.8 card. It shows at
xxxLarge (SE 3 always; iPhone 17 with a note) and at every AX size. AX breakages for 5.5 are in the report: the "↓"
fallback, the bar repeating a visible readout, bar + note taking ~40% of the SE 3 at AX1, and the wrapped lock pill.
"Compass ↓" was checked by running its scroll from a temporary trigger, not a real tap.

---

## `86dc152` · Build 5.4.8 [spike]: "After midnight" 13 pt on one line, no-rise card no longer grows · **local**

Spec COMPASS-1.1.md §9.16 item 1 (as built §9.17). Report: `5.4.8/5.4.8-after-midnight.md`; 12 screenshots
`5.4.8/shots/` (no-rise day and Oct 2 × iPhone 17 / SE 3 × default / AX1 / AX5).

| Item | Change |
|---|---|
| "After midnight" / "Not today" | Own font, `Theme.Fonts.missingEvent` 13 pt Young Serif; out of the shared scale; held in a time's slot so "Sun 12:20 AM" stays on the directions' line |
| Card | No-rise day = normal day height (iPhone 17 181.3, SE 3 181.5); other columns at 100% |
| Docs in this commit | Your uncommitted §9.16, build order, DECISIONS entries, DESIGN-REVIEW ‹ › bug, `design/bugs/`; §9.17 as built, STATUS, CLAUDE.md count |
| Tests | **530 tests / 812 cases, all pass**; new `MoonCardHeightTests.noRiseDayKeepsHeight` (real engine, both widths) |

**For you: 13 pt, not 15–20 pt.** On the SE 3, beside Up now and Moonset, Moonrise has 100.5 pt of text width;
"After midnight" needs 113.4 pt at 15 pt (13.3 pt is the most that fits; 16.8 pt on the iPhone 17). I kept "one line,
others at 100%, same height" over the range. Pick: 13 everywhere (built), or 16 on 402 pt phones and 13 on the SE 3.
These card heights are ~46 pt more than 5.4.7's report gives (135.7 / 140); both days here were measured the same way,
so compare like with like.

---

## `4552635` · Build 5.4.7 [spike]: Up now between Moonrise and Moonset, card 46 pt shorter · **local**

Spec COMPASS-1.1.md §9.14 (as built §9.15), mocks `design/1.3-upnow/` 7a–7c. Report: `5.4.7/5.4.7-upnow.md`;
36 screenshots + contact sheets: `5.4.7/shots/` (6 states × iPhone 17 / SE 3 × default / AX1 / AX5); AX5 card
previews `5.4.7/previews/`.

| Item | Change |
|---|---|
| Moon up | ↑ Moonrise · Up now · ↓ Moonset; glyph on a connector (solid rise → now, dotted now → set); "Up now" 20 pt + live bearing; locked on the Moon → middle cell outlined |
| Moon down / other dates | Rise and set at the card's ends, one dim dotted line; pill row and "● Rises …" gone |
| Height | Same up and down at every size (hidden twin of the other state) |
| AX sizes | Three columns don't fit at AX1 / AX5 → rise / set halves + the 5.4.6a pill, VoiceOver order kept |
| Fixed | AX5 cut the Moonrise direction to "57° E…" (also without 5.4.7's changes; likely since 5.4.6c) |
| Docs in this commit | Your uncommitted §9.14 + DECISIONS entry, `design/1.3-upnow/`; §9.15 as built, DECISIONS as built, STATUS, CLAUDE.md count |
| Tests | **528 tests / 809 cases, all pass** (Xcode's runner); new `RiseSetLayoutTests`, `MoonCardHeightTests` (rendered up = down) |

| Default size, moon up | Card | Saved | Dial face bottom | Fit step |
|---|---|---|---|---|
| iPhone 17 | 181.7 → 135.7 | **46** | 814 → 768 (**106 above the fold**) | connector, 100% |
| SE 3 | 186.0 → 140.0 | **46** | 745 → 699 (32 past); centre 582.5, now above every bottom bar | no connector, 100% |

**For you:** 46 pt, not ~34 (the pill's 10 pt spacing goes too). On the no-rise day all three columns drop to 80% and
"After midnight" wraps (both phones; one line on the iPhone 17 in 5.4.6c). The SE 3's gaps (15.75 pt) are too small
for the connector. With the moon down, VoiceOver no longer says when it rises next. Lock outlines now hug their cell.
Watch item as specified: tonight's rise sits left of "Up now" in the morning (01, 02).

---

## `efb52c1` · Build 5.4.6c [spike]: notes in a bottom bar, 24 pt readout, 28 pt needle · **local**

Spec COMPASS-1.1.md §9.4, §9.12 (as built §9.13). Report: `5.4.6/5.4.6c-bar.md`; 84 screenshots + contact sheets:
`5.4.6/c/` (14 states × iPhone 17 / SE 3 × default / AX1 / AX5).

| Item | Change |
|---|---|
| Bottom bar | Precise off (Use Precise), low accuracy, Nearby, aha in one bar above the home indicator; dial dims in low accuracy |
| Bar fixes | Use Precise beside the text (was always under it, 127 → 82 pt); text capped at AX1; note held while sensors pause (no flicker) |
| §9.12 | Readout / pill 24 pt, 0.7× capitals, padding 10 / 18; missing-cell labels aligned, "After midnight" in the time font; needle 28 pt; phase line one line |
| Tests | 521 tests / 797 cases **all pass** (Xcode's runner); 3 stale 5.4.6b tests fixed; 2 new held-note tests |

| Default size | Dial centre | Face bottom | Bar tops (Precise / low / Nearby / aha) |
|---|---|---|---|
| iPhone 17 | 684 | 814 | 758 / 776 / 776 / 792 |
| SE 3 | 628.5 | 745 | 585 / 585 / 603 / 619 (covers the centre) |

**For you:** a bar covers the dial's bottom on load (centre on the SE 3); AX1 cap is my call; "After midnight" wraps
on the SE 3 at 0.8×.

---

## `ed294b1` · Build 5.4.6b [spike]: 260 pt dial, more space, short needle, "After midnight" · **local**

Spec COMPASS-1.1.md §9.1, §9.3, §9.7, §9.10 (as built §9.11). Fit report: `5.4.6/5.4.6b-fit.md`; 78 screenshots +
contact sheets: `5.4.6/b/` (13 states × iPhone 17 / SE 3 × default / AX1 / AX5, real app via DEBUG `-screenState`).

| Item | Change |
|---|---|
| Dial | Face **260 pt** on the iPhone 17 (was 196), 233 on the SE 3: sized by width so the side labels stay on screen. Ticks, distances, letters, crosshair scale |
| Needle / lock | 43 pt, 6 above the arc to the heavy ticks; Moon at 12 o'clock over it when locked; travelled arc solid only while locked |
| Labels | 10 pt from their mark at every angle |
| Gaps | Sentence → card **28** (was 20), card → readout **32** (24), readout → needle **~35** (~12); sentence 1.2× |
| Readout / pill | 20 pt, direction letters small like AM/PM |
| Card | Phase line to 0.85× before wrapping; label → time 2 pt; "After midnight" + "Sun 12:20 AM" / "Not today" (FR2 updated) |
| Docs in this commit | The uncommitted §9.10 / DECISIONS device-check notes; PRODUCT FR2, ASTRONOMY, DESIGN-1.1, DESIGN-REVIEW |

| Fit (default size) | Face bottom | Arc bottom | Labels (worst case) |
|---|---|---|---|
| iPhone 17 (874), moon up = moon down | 808 (66 above) | 824 (50 above) | 862 (12 above; 22 into the home-indicator band) |
| SE 3 (667), moon up = moon down | 739 (+72 past) | 755 (+88) | 793 (+126); dial **centre on screen** (44.5 above) |

**For you:** the ~300 pt dial doesn't fit across a 402 pt screen with labels outside the arc, so it's 260 (the mock's
size). A bottom label can sit in the home-indicator band (face 238 would clear it). On the SE 3 the dial's centre
is on screen at the default size, so §9.6's pinned bar wouldn't show there except in low accuracy and AX sizes.
On the SE 3, "Waning Crescent · 42% lit" still wraps at 0.85× (+25 pt card). The needle is 43 pt, not §9.10's ~28.
**Tests not run:** builds, but the test runner can't launch here; run `xcodebuild test` locally.

---

## `ed8700e` · Build 5.4.6a [spike]: compact card header, Up now pill · **local**

Spec COMPASS-1.1.md §9.2. Findings + screenshots: `5.4.6/5.4.6a-card.md`, `5.4.6/a1–a7-*.png` (Xcode previews).

| Item | Change |
|---|---|
| Header | One row: glyph · "Today · Fri, Oct 2" over "Last Quarter · 53% lit" · ‹ ›. VoiceOver keeps "at midnight" |
| Rise / set | Card padding 12 (was 16 / 18), row gap 10 (was 14), cells hug content (no 76 pt min); AM / PM still small |
| Up now | Pill "● Up now · 266° W" (36 pt, `#251C22`), `accent` outline when locked on the Moon; down: "● Rises 11:10 PM". Bar gone |
| Docs in this commit | The uncommitted 5.4.6 layout-pass docs (COMPASS-1.1 §9, DECISIONS, STATUS, DESIGN-REVIEW, LOCATION, LOADER.md), `design/1.2-layout/`, and `design/1.1/Moon Signal Loader.dc.html` |

**For you:** long phase names ("Waning Crescent · 21% lit") fall back to two lines at the default size (a5); the AX
header layout (text under glyph and ‹ ›) is my call; "Moonris / e" at AX5 is from before this build.
**Tests not run:** the build and test target compile, but the test runner can't launch here (pseudo-terminal error).
Run `xcodebuild test` locally.

---

## Fit on load · Compass 1.1 spike, default size

Report and screenshots: `5.4-fit/5.4-fit.md`. Real app, both simulators located in Irvine (Here), moon up.

| Phone | Good heading: face / arc / view bottom vs screen bottom | Low accuracy (simulator; note adds 46 pt) |
|---|---|---|
| iPhone 17, 402 × 874 | face **6 pt above**, arc +10 past, view +26 past (home indicator covers the face's lower 28 pt) | +40 / +56 / +72 past |
| iPhone SE 3, 375 × 667 (smallest supported) | +160 / +176 / +192 past: only the needle and the top of the arc show | +206 / +222 / +238 past: needle only |

**For you:** the dial doesn't fit on load on either phone; the 180 pt fallback wouldn't fix it either (iPhone 17
face would end 12 pt into the home indicator). That's the input for the pinned-bar rule (§6).

---

## `9a2a27c` · STATUS: Compass 1.1 spike built, fit on load, test count · **local**

STATUS.md items for the fix, 5.4.2–5.4.5 and the fit; CLAUDE.md test count (**504 tests / 750 cases / 38 suites**).

---

## `b8179f7` · Build 5.4.5 [spike]: sentence "Where can I find / the moon today / in …?" · **local**

| Item | Change |
|---|---|
| Copy | Lines "Where can I find" / "the moon" + date / "in" + place + "?"; date token **"today"** (was "tonight"), "on Sat, Oct 3" otherwise. VoiceOver "Where can I find the moon today in Irvine, CA?", "Date, today, button" |
| Fit rule | Unchanged. In the fit screenshots, Irvine, CA sits on three lines with no wrap or ellipsis on both phones |
| Tests | Formatter and view-model expectations updated |

---

## `878c922` · Build 5.4.4 [spike]: target labels outside the arc, Moon pulse · **local**

| Item | Change |
|---|---|
| Labels | "↑ Rise", "↓ Set", "Now", 12 pt fixed, 138 pt out with a `bg` halo; the ↑ / ↓ inside the rim are gone. Locked drops its label; within 15° "Now" wins (`CompassTargetLabels`) |
| Pulse | Ring 10 → 24 pt, 1.8 s, until the first lock this launch (`showsMoonPulse`, `hasLockedThisLaunch`); still ring under Reduce Motion |
| Tests | `CompassTargetLabelsTests` (lock, collision, across north), pulse tests in `CompassViewModelTests` |

**For you:** rise vs set collisions (polar only) aren't in the spec; moonrise keeps its label. "Now" at 3 / 9 o'clock
almost touches the Moon's disc (the HTML's 24 pt gap). Pulse and Reduce Motion not seen animating (previews are stills).

---

## `b67c3d9` · Build 5.4.3 [spike]: accuracy notes under the readout · **local**

Status line + Use Precise Location between the readout and the dial (10 pt under the readout), dial moves down
while they show; Nearby stays under the dial. No spacing values changed. Placement is checked in previews only.

---

## `a4c1230` · Build 5.4.2 [spike]: dial needle, ticks, numbers, serif cardinals, crosshair · **local**

| Item | Change |
|---|---|
| Needle | 3 pt round-capped, from the old capsule's 17 pt lead to 12 pt inside the rim; amber on lock |
| Ticks | 2° / 10° / 30° lines (7 / 11 / 15 pt), N tick amber, four paths |
| Numbers | Every 30° off the cardinals, Nunito 600 11 pt fixed, `dialNumber` `#A8939C` (5.1:1), hidden from VoiceOver |
| Cardinals | Young Serif, 58 pt out, E/S/W `textPrimary` |
| Crosshair | ±28 pt, 1 pt `faint`, 2 pt dot |
| Readout | Already 24 pt locked and unlocked |

**For you:** tick shimmer while turning is a device check (fallback 5° minors).

---

## `694ad2d` · Compass sensors start when any part of it is visible · **local**

`onScrollVisibilityChange(threshold: 0.1)` (was the default 0.5); `onDisappear` kept. DECISIONS.md 2026-10-02 and
COMPASS.md §1 ("on screen" = any part visible).

---

## `6044e4c` · Fix shared scheme's test target reference · **local**

Xcode's repair of the scheme's test-target ID (your call). `xcodebuild test` from my shell couldn't launch the
runner ("Pseudo Terminal Setup Error", no terminal), so it's unconfirmed from the CLI; Xcode's runner passes.

---

## `bb6e4d2` · Build 5.4.1 [spike]: lock highlight on the moon card · **local**

Findings and screenshots: `5.4.1/5.4.1-up-now.md`.

| Item | Change |
|---|---|
| Highlight | On lock, the matching cell (Moonrise, Moonset, Up now for the Moon) gets a 1 pt amber border, amber 10% fill and amber label. `MoonCardCell(lockedOn:)`, `LocationViewModel.highlightedCardCell` |
| Cells | Every cell is a padded box (8 / 10, radius 14) with a clear border, so nothing shifts on lock. **Moonrise/Moonset are boxes 6 pt apart; 5.2's hairline divider is gone** (as in the HTML) |
| Previews | Locked on moon / moonset / moonrise |
| Docs | DECISIONS.md as built, DESIGN-1.1.md §3.2 note, STATUS.md, CLAUDE.md test count |
| Tests | `MoonCardCellTests`. **495 tests / 736 cases across 37 suites, all pass** (iPhone 17 sim, via Xcode). No new warnings |

**For you:**
- **Divider:** say if you want the hairline back between the two boxes (finding 4).

---

## `1fa2bed` · Build 5.4.1 [spike]: Up now row on the moon card · **local**

Includes your pending Compass 1.1 docs: COMPASS-1.1.md, the design source, DECISIONS.md 2026-10-02,
DESIGN-1.1.md, DESIGN-REVIEW.md, STATUS.md.

| Item | Change |
|---|---|
| Row | "● Up now · 266° W" and a bar from the last rise to the next set, with the phase glyph as its thumb; down: "Below the horizon · Rises in 34 min / at … / tomorrow …", same height; hidden on other dates. AX sizes stack |
| Source | `CompassViewModel.upNow`, from the Moon target's position, pass and tick |
| Service | `MoonService.nextMoonrise(for:after:)` (Astronomy Engine forward search; fake scriptable) |
| Formatting | `UpNow`, `UpNowFormatter` (place's zone, VoiceOver sentences per §3) |
| Theme | `surfaceInset` `#251C22`, `faint` `#5E4D57`, `Fonts.caption` 11 pt |
| Tests | `UpNowFormatterTests`, `NextMoonriseTests` (§5 reference day), Up now in `CompassViewModelTests` (up, down, other dates, no compass, tick both ways, rise cached), contrast in `ThemeTests` |

**For you:**
- **Decide:** should the row show for any place, not just where the compass shows (finding 1)? Today it's hidden
  with location off, in Far, and before a searched city is matched to a detection. It also stops updating while
  the compass is off screen (finding 2).
- **The two rise times:** see screenshots 1, 5 and 6 for whether to drop the bar's end times (finding 3).
- **Not checked:** 375 pt phone, device.

---

## `2be3270` · TestFlight prep: build 4 · **local**

| Item | Change |
|---|---|
| Build number | `CURRENT_PROJECT_VERSION` 3 → 4 on the app target, Debug and Release. `MARKETING_VERSION` stays 1.0; test target untouched (1) |
| STATUS.md | Item 9: what's in build 4 since build 3 (5.8 moon arc, new icon, tap animation, onboarding Settings fix, TestFlight-only Show onboarding; sentence tokens have no pressed state yet; launch arguments not in it), the checks, and a tester checklist |

**Checked** (Release, generic iOS device, unsigned, clean derived data in `/tmp`):

| Check | Result |
|---|---|
| `CFBundleVersion` / `CFBundleShortVersionString` | **4** / 1.0 |
| Fonts | The four `.ttf` in the bundle and in `UIAppFonts`; both OFL texts |
| `PrivacyInfo.xcprivacy` | In the bundle: tracking false, no collected data, UserDefaults `CA92.1` |
| Also | Forced dark (`UIUserInterfaceStyle` Dark), display name "Moon Signal", minimum iOS 26.0, `ITSAppUsesNonExemptEncryption` false |
| App icon | `Assets.car` has AppIcon in **any**, **dark** and **tintable** (1024 × 1024 each); the 120 pt fallback PNG is the new art |
| Launch arguments | `strings`: 0 `-forceOnboarding`, 0 `-onboardingPage`, 0 `-resetOnboarding` (control `onboardingCompleted`: 1). `nm`: 0 launch-argument symbols; `forceShow` / `BuildChannel` present, as intended |
| Build | Succeeded. Warnings: `.attributed` (known), `appStoreReceiptURL` deprecated (new, item 2), `-Wcomma` in vendored `astronomy.c` |
| Tests | 473 tests / 706 cases across 34 suites, all pass (iPhone 17, via Xcode) |

**For you:**
- **Archive and upload are yours;** I didn't archive, sign or upload.
- **`strings` can't see the button text.** Swift stores strings of 15 bytes or fewer inline in the code, so
  "Show onboarding" shows 0 hits even though it's in. The same goes for `-onboardingPage`, so the symbol check
  is what proves the launch arguments are out (also true of build 3).

---

## `0d0f1c6` · Show onboarding button in TestFlight builds · **local**

Findings: `testflight-onboarding-button/testflight-onboarding-button.md`.

| Item | Change |
|---|---|
| `BuildChannel` | `isTestFlight` (receipt is `sandboxReceipt`), `showsOnboardingButton` (DEBUG or TestFlight). Testable forms |
| Forced flow | `debugShow` → `forceShow`, now in Release; the app passes the button's action only when `showsOnboardingButton`. Launch-argument parsing stays `#if DEBUG` |
| Tests | `BuildChannelTests` (sandbox / App Store / no receipt; button in Release and DEBUG) and a non-DEBUG forced-run-writes-nothing test |

**For you:**
- **One new warning:** `Bundle.appStoreReceiptURL` is deprecated (StoreKit's `AppTransaction` replaces it). I kept
  it as decided, since it's temporary.
- **Untested on a real TestFlight install:** check the button shows in build 4.

---

## `5dc68d5` · Onboarding: Use my location opens Settings when no prompt can show · **local**

Findings and screenshots: `onboarding-services-off/onboarding-services-off.md`. Includes your pending doc changes
(this decision, the TestFlight button decision, DESIGN-1.1.md §5).

| Item | Change |
|---|---|
| Logic | `useMyLocation()` reads the state first. Already Never or services off: no request; Settings opens (`settingsRequestCount` → the view opens the URL) and the upsell stays. Services off after the request: the same. Back authorized after that trip → main screen, completed. Real Don't Allow and restricted → "That's okay", unchanged |
| Tests | 7 new in `OnboardingViewModelTests` |
| Simulator | Never and services off: "That's okay" never appeared; still off → upsell; allowed → main screen. Location Services and permission restored afterwards |

**For you:**
- **Settings didn't open on Moon Signal's page in the simulator.** It showed its last page, or its home screen.
  It's the same URL "Enable location" already uses, so it's probably a simulator quirk. Check on device (it's
  in the build 4 tester checklist).

---

## `5f01158` · Tap animation on buttons · **local**

Findings and screenshots: `tap-animation/tap-animation.md`.

| Item | Change |
|---|---|
| Look | While pressed: scale 0.96, opacity 0.8, then `.spring(duration: 0.15)` back. Reduce Motion: opacity only |
| Where | One `PressFeedback` modifier, applied by `PrimaryButtonStyle`, `SecondaryButtonStyle`, `TextLinkButtonStyle` and the card's ‹ › style (the circle shrinks, not its 44 pt target). Replaces each style's own pressed opacity (0.75 / 0.6), so the dip is lighter |
| Checked | Preview of all three styles in each state; simulator taps fire exactly once (incl. a 1 s long press on ›), no layout jump |
| Tests | `PressFeedbackTests` (rest, pressed, Reduce Motion). **461 tests / 687 cases across 33 suites, all pass** |
| Docs | DECISIONS.md as-built; DESIGN-REVIEW.md item ticked; STATUS.md; CLAUDE.md counts |

**For you:**
- **Sentence tokens not done:** they're inline links in one `Text`, with no per-token pressed state. Leave
  them, dim the whole sentence on press, or rebuild them as buttons (a layout rework)? Open in DECISIONS.md.
- Values are "proposed, tune on device": the feel needs a phone.

---

## `5213b6b` · DEBUG onboarding trigger · **local**

Findings and screenshots: `debug-onboarding/debug-onboarding.md`. Includes your pending DECISIONS.md entry.

| Item | Change |
|---|---|
| Launch arguments | `-forceOnboarding` (shows it whatever the place, permission, flag); `-onboardingPage landing\|upsell\|declined` (unknown → landing; alone, picks the page of a natural first run without forcing it) |
| Button | DEBUG-only Show onboarding at the bottom of the main screen, text-link style (44 pt) |
| No stored state | A forced run skips the completed-flag write on every exit. Simulator: preferences untouched since 11:58 (flag still true, saved place still Los Angeles) |
| (new) | A forced "That's okay" while location is allowed stays up, instead of closing itself on the Settings-return rule. A real Settings return still works |
| Release | `strings` on an unsigned Release build: 0 hits for `-forceOnboarding`, `-onboardingPage`, "Show onboarding", the DEBUG method names; control `onboardingCompleted` present; the Debug binary has all three |
| Tests | `OnboardingDebugTriggerTests` (DEBUG-only, 10 tests / 14 cases): each argument, every forced exit writes nothing, the button, the declined hold, the Settings return |

**For you:**
- **Temporary:** remove before the 1.0 App Store build (DECISIONS.md, STATUS.md).
- Irvine vs Los Angeles in the screenshots is the location fix vs the saved place, not a state change.

**Both items:** Xcode went to iPhone 17 for tests and is back on **T2 iPhone**.

---

## `b3f0ed8` · App icon: Moon Signal variants · **local**

| Item | Change |
|---|---|
| Icon set | Placeholder (`any` / `dark` / `tinted-1024`) → `MoonSignal-AppIcon-Dark-1024` in the default and dark slots, `MoonSignal-AppIcon-Tinted-1024` for tinted. All 1024 × 1024, no alpha |
| Checked | Asset catalog compiles, no warnings. Tinted is grayscale on black, as iOS expects |
| STATUS.md | Item noted, with a device check (home screen in default, dark, tinted) |

**For you:** the default slot's `MoonSignal-AppIcon-Dark-1024 1.png` is a byte-identical copy of the dark file
(Xcode's " 1" naming). That's fine for a dark-only app; swap in a light design there if one comes. Not in
TestFlight build 3; it ships with the next build.

---

## `10bf1d4` · Step 5.8: Design 1.1 moon arc · **local**

Built ahead of the DEBUG onboarding trigger and the tap animation, which are still next (STATUS.md).
Findings and screenshots: `5.8-moon-arc/moon-arc.md`.

**What changed** (one commit, with your pending doc changes and `design/1.1/moon-arc-mockups.html`):

| Item | Change |
|---|---|
| Dial | 196 pt (was 220). Rim: ticks, letters, ↑/↓ only. Arc at radius 114: 1.5 pt `accent` 30% hairline for the travelled part, 3 pt dots 6.6 pt apart at 95% for the rest. Moon down / other day: all dots at 30%, end dots 30%, no glyph |
| Moon | 24 pt `PhaseGlyph` on a 4 pt `bg` disc, `moonLit` 16% glow, hairline edge; locked 28 pt with ring and glow |
| Indicator | 6 × 17 capsule at radius 130–147, beyond the arc. Dial view is 260 × 277 pt (5.4: 220 × 230) |
| Data | New `MoonPass` model + `MoonService.moonPass(for:containing:)` (engine + fake), sampled every 15 min, unwrapped. `CompassArc` / `CompassViewModel.arc`: the pass under way if the moon is up, else the pass from the day's moonrise; the 30 s tick moves the Moon along it |
| A11y | VoiceOver unchanged (the arc isn't exposed). Nothing on the arc animates; the lock is still animation-free with Reduce Motion |
| Tests | `MoonPassTests` (unwrapping, nearest sample, engine vs the §5 table, clockwise LA / anticlockwise Sydney, 15 min sampling, high latitude, fake) and 9 arc tests in `CompassViewModelTests`. **448 tests / 669 cases across 31 suites, all pass** (iPhone 17, via Xcode) |
| Docs | DECISIONS.md "5.8 moon arc: as built"; DESIGN-1.1.md §3.3a as-built + §7; ARCHITECTURE.md; STATUS.md; CLAUDE.md counts |

**For you:**
- **Open:** on passes that cross midnight, the day's rise/set dot can be a few degrees off the arc's end
  (the dots are the lock targets). Keep that, or snap the dots to the arc?
- **Today after moonset** shows today's finished pass dimmed (the spec's wording), not tomorrow's. OK?
- **Taller than planned:** ~47 pt, not 25–30. Check on your smallest phone; the spec's fallback is a 180 pt dial.
- **Halo vs arc:** looks fine to me (`4-locked-on-moonrise.png`); left as is.
- Xcode's run destination went to iPhone 17 for the tests and is back on **T2 iPhone**. In the iPhone 17
  simulator: Reduce Motion was turned on for screenshot 5 and back off; its location is now Irvine, CA.

---

## `64a99bc` · TestFlight prep: build 3 · **local**

**What changed** (one commit):

| Item | Change |
|---|---|
| Build number | `CURRENT_PROJECT_VERSION` 2 → 3 on the app target, Debug and Release. `MARKETING_VERSION` stays 1.0; test target untouched (still 1) |
| Included | Your `docs/DESIGN-REVIEW.md` "Motion and feedback" note; `xcshareddata/xcodecloud/manifest.json` (was untracked) |
| STATUS.md | Next item 8: what's in build 3 (everything since build 2 `55b64b3`: 5.1–5.4, 5.7, follow-ups, Step 2.2 fix 4; **not** 5.5/5.6) and a tester checklist |

**Checked** (Release, generic iOS device, unsigned, separate derived data so Xcode's isn't touched):

| Check | Result |
|---|---|
| `CFBundleVersion` / `CFBundleShortVersionString` | **3** / 1.0 |
| Fonts | `YoungSerif-Regular`, `NunitoSans-Regular` / `-SemiBold` / `-Bold` `.ttf` in the bundle and in `UIAppFonts`; both OFL texts |
| `PrivacyInfo.xcprivacy` | In the bundle: tracking false, no collected data, UserDefaults `CA92.1` |
| `-resetOnboarding` | **Not in the Release binary** (`strings`: 0 hits; control `onboardingCompleted`: present). The Debug binary has it |
| Also | `ITSAppUsesNonExemptEncryption` false, forced dark, display name "Moon Signal", minimum iOS 26.0, the 4.12 location text |
| Build | Succeeded. Warnings: the intentional `.attributed` one, plus `-Wcomma` in `Vendor/Astronomy/astronomy.c` (vendored, not touched) |
| Tests | 427 tests / 648 cases across 30 suites, all pass (iPhone 17 simulator, via Xcode) |

**For you:**
- **Archive and upload are yours;** I didn't archive, sign or upload.
- **Testers on build 2 won't see onboarding** after updating (they have a saved place or a location answer), by design.
  The STATUS.md checklist asks them to delete and reinstall to test it, and separately to check an upgrade.
- Xcode's run destination went to iPhone 17 for the tests and is back on **T2 iPhone**.

---

## `d6c2587` · Step 5.7: Design 1.1 onboarding · **local**

Built ahead of 5.5 / 5.6, which are deferred until after it (STATUS.md).

**What changed** (one commit, docs included):

| Item | Change |
|---|---|
| Flow | Landing → Location upsell → iOS prompt → "That’s okay" (only after Don't Allow). The prompt comes only from the upsell's **Use my location** tap, never at launch |
| Allow | Allow and Allow Once → main screen, normal launch flow (`start()`), detected city |
| Don't Allow | "That’s okay". **Got it** → main screen "a city" empty state. **Enable location** → app Settings; stays on "That’s okay", and back in the foreground authorized → main screen as for Allow (new rule) |
| Search instead | Main screen with the search sheet open, no prompt. Cancel leaves the empty state |
| When it shows | No saved place **and** permission not determined **and** onboarding not completed (new rule). Any exit sets the flag (`OnboardingStore`, `UserDefaults` key `onboardingCompleted`) |
| Code | `Features/Onboarding/` (`OnboardingViewModel`, `OnboardingView`, Landing / Location / Declined screens, `OnboardingPage`, `OnboardingMoon`, `OnboardingCopy`), `Services/Onboarding/` (store protocol + UserDefaults + in-memory). App root swaps onboarding for `LocationScreen`; `LocationViewModel.onboardingDidFinish(_:)` |
| Theme | `PrimaryButtonStyle` (56 pt amber capsule + glow), `TextLinkButtonStyle` (≥ 44 pt), `Theme.Fonts.infoNote` (15 pt, the HTML's info box), `Metrics.onboardingMargin` 28. `PhaseGlyph` takes an optional disc colour and glow size (card and compass unchanged) |
| A11y | Titles are headers; VoiceOver is told the screen changed on each step; buttons 56 / 52 / 44 pt and grow with text; pages scroll at AX sizes with the buttons after the content |
| Copy | The mockup's, as-is (placeholder), all in `OnboardingCopy.swift` |
| Tests | `OnboardingViewModelTests` (show/skip per condition incl. the flag; no prompt before the tap; Allow, Don't Allow, Got it, unanswered prompt, Search instead, relaunch after Search instead, Settings return authorized / still denied), `LocationViewModelOnboardingTests` (main screen after each outcome, cancel → empty), `OnboardingStoreTests` (persists; DEBUG reset). All on `FakeLocationService`: no test touches the system alert |
| Docs | DECISIONS.md "5.7 onboarding"; DESIGN-1.1.md §5 (two new rules + as-built), §7, §8; STATUS.md (5.5/5.6 deferred); ARCHITECTURE.md; CLAUDE.md counts |

**Checked:**
- **Build:** succeeds; the only warning is the existing, intentional `.attributed` one. **Tests:** 427 tests / 648 cases
  across 30 suites, all pass (iPhone 17 simulator, via Xcode), run again after the layout fix below.
- **Simulator (iPhone 17, fresh install):** `5.7-onboarding/` holds `1-landing`, `2-upsell`, `3-prompt`, `4-thats-okay`
  at default and AX5 (`-ax5-bottom` = scrolled to the buttons), plus `5-main-after-got-it` (default, AX5) and
  `6-search-instead` / `7-search-cancelled` (default). At default every screen's buttons are on screen without
  scrolling; at AX5 screens 1–4 scroll and every button was reached and tapped.
- **Found and fixed before commit:** the upsell title was cut to one line ("Find the moon from…") at default size;
  the page's min-height frame squeezed it. Content and buttons now always get their full height.

**Re-running onboarding:**
- It needs all three: no saved place, permission not determined, flag clear. Simplest: delete the app and reinstall.
- **Flag only (DEBUG builds):** launch with the argument `-resetOnboarding` (Xcode: Product › Scheme › Edit Scheme ›
  Run › Arguments, or `xcrun simctl launch booted com.t-alien.moonbeam-app -resetOnboarding`).
- **Location permission in the simulator:** `xcrun simctl privacy booted reset location com.t-alien.moonbeam-app`
  (or `xcrun simctl privacy booted reset all com.t-alien.moonbeam-app`). On a device: Settings › General › Transfer or
  Reset iPhone › Reset › Reset Location & Privacy, or delete and reinstall.
- **Saved place:** there's no reset for it; delete the app if one is saved.

**Review notes:**
- **The moon on the onboarding screens is fixed** (a waning gibbous, ~83% lit, as the HTML draws it), not tonight's
  phase. Want it live?
- **Allow runs a launch fix,** like any launch, so the detected city isn't saved as last-viewed (same as relaunching
  with location on today). The main screen's own Use my location does save it.
- **"That’s okay" body has no final period;** that's the mockup's copy, kept as-is.
- **AX5, not fixed (outside 5.7):** onboarding text scrolls under the clock with no edge effect (the main screen has
  one); the main screen's "a city" token is ~23 pt tall at default size, under 44 pt (5.3). Fix either?
- The system prompt's own button list scrolls at AX5 (iOS's alert, not ours).
- Xcode's run destination went to iPhone 17 for the build, tests and screenshots and is back on **T2 iPhone**.

---

## `3436f52` · Step 5.2 follow-up: smaller day period in rise/set times · **local**

**What changed** (one commit):

| Item | Change |
|---|---|
| Look | "PM" in Young Serif at 60% of the time (`Theme.Fonts.dayPeriod`, relative to `.title2`), same colour, on the baseline |
| How | `TimeText` (new) splits `Date.FormatStyle`'s attributed output at the `.amPM` field; no string matching |
| Locales | Last (en_US, ar_EG), first (ko_KR "오후 9:10"), none (en_GB, de_DE, ja_JP, zh_CN: nothing shrinks) |
| Unchanged | Digits, the zone abbreviation, VoiceOver labels, `time(_:in:)` |
| AX | Day period wraps under the digits (was cut off mid-build; fixed before commit) |
| Tests | Day-period runs per locale; card detail now carries `TimeText` |
| Docs | DECISIONS.md "Rise/set times: smaller day period"; DESIGN-1.1.md §3.2 as-built; STATUS.md; CLAUDE.md counts |

**Checked:**
- **Build:** succeeds with **one warning, on purpose**: `.attributed` is deprecated in iOS 18 (see review notes).
  **Tests:** 404 tests / 619 cases across 27 suites, all pass (iPhone 17 simulator, via Xcode).
- **Screenshots:** `5.2-ampm/`: Irvine and Sydney in the app at default and AX3. Findings: `ampm.md`.

**Review notes:**
- **The warning:** the replacement (`.attributedStyle`) tags runs with `DateFormatFieldAttribute`, which has no
  usable key from Swift here (no dynamic member, and subscripting by the type crashes the Swift 6.4 compiler).
  `.attributed` is the API that exposes the `.amPM` field you asked for. Keep it, or should I find another route?
- **Side effect:** Sydney's "GMT+10" now fits beside "8:53 AM" at default size (it used to wrap under it).
- Xcode's run destination went to iPhone 17 for the build and tests and is back on **T2 iPhone**.

---

## `dccda70` · Step 5.4 follow-up: live Moon marker is a mini phase glyph · **local**

**What changed** (one commit):

| Item | Change |
|---|---|
| Marker | The live Moon is the card's `PhaseGlyph` at 20 pt (was an 18 pt `moonLit` dot): same lit fraction, terminator, `moonLit` fill and glow |
| Phase | From the selected day's `MoonDay`, as on the card (`CompassViewModel.moonGlyph`) |
| Upright | Placed at azimuth − heading, never rotated; no arrow |
| Locked | Like the other targets: 22 pt, 4 pt `accent` ring, strong glow; pill stays "Moon · 275° W" |
| VoiceOver | Dial reads the Moon as "Moon now, west, 275 degrees"; rise/set unchanged |
| Tests | Spoken Moon entry; glyph follows the day's table (and clears with none) |
| Docs | DECISIONS.md "§11 Q4 revised"; DESIGN-1.1.md §3.3 + as-built + §11 Q4; STATUS.md; CLAUDE.md counts |

**Checked:**
- **Build:** clean, no warnings. **Tests:** 403 tests / 615 cases across 27 suites, all pass (iPhone 17 simulator, via Xcode).
- **Screenshots:** `5.4-moon-marker/`: moon up unlocked and locked on the Moon (previews with a fake heading;
  waning gibbous at 275°). Findings: `moon-marker.md`.

**Review notes:**
- **The lock's VoiceOver label is unchanged:** "Pointing at moon, 275 degrees west". Should it become
  "Pointing at the Moon now, west, 275 degrees" to match the dial?
- The marker shows **tonight's midnight phase** (the card's value), not this minute's; a few percent apart at most.
- Xcode's run destination went to iPhone 17 for the build and tests and is back on **T2 iPhone**.

---

## `5a9ce3c` · Madlib sentence: "Where will the moon be…", new breaks, default-size fit · **local**

**What changed** (one commit):

| Item | Change |
|---|---|
| Copy | "Where will the moon be [date] in [city]?" (was "Where can I find the moon…"); VoiceOver header to match |
| Lines | "Where will the moon" / "be 📅 [date]" / "in 📍 [city]?", forced; three lines' height still reserved |
| Fit, default size | `.large` only: all three lines share one scale, minimum **0.7×** (~19 pt); below that the line wraps at 0.7 |
| Fit, other sizes | No shrinking; text scales as before and long lines wrap, tokens between words |
| Attached | Icon to its token's first word (NBSP); "?" to the city (no space; no word joiner, see review notes) |
| VoiceOver | Order unchanged: sentence (header), then Date and Place buttons |
| Tests | `MadlibScaleTests` (clamp at 0.7, `.large` only across all sizes), formatter / view-model copy |
| Docs | DECISIONS.md new entry (old copy entry marked superseded); DESIGN-1.1.md §3.1a revision note + as-built; STATUS.md; CLAUDE.md counts |

**Checked:**
- **Build:** clean, no warnings. **Tests:** 401 tests / 613 cases across 27 suites, all pass (iPhone 17 simulator, via Xcode).
- **Screenshots:** `5.3-sentence-breaks/`: Irvine and Rancho Santa Margarita in the app at default and AX3; the
  2027 date as previews at default and AX3 (the date can only be picked in the calendar). Findings: `sentence-breaks.md`.

**Review notes:**
- **The rule now clamps instead of excluding:** a line that can't fit at 0.7 holds all three at 0.7 and wraps
  (5.3 fix 1 left it out of the scale). That follows "all three lines stay the same size"; say if you meant otherwise.
- **Token breaks off the default size:** at any size but `.large` a city can wrap between its words (was AX only),
  so with no shrinking it never breaks inside a word.
- **A word joiner before "?" hung the layout** of any line that had to shrink; removed. "?" can't wrap away from the
  city anyway.
- Xcode's run destination was your **T2 iPhone**; I switched to iPhone 17 for the build and tests and switched back.

---

## `e6aeffd` · Step 5.4: Design 1.1 compass restyle · **local**

**What changed** (one commit):

| Item | Change |
|---|---|
| Readout | "72° ENE", Young Serif 24, in a 40 pt slot (scales with `.title2`) |
| Dial | 220 pt; `dialTop` → `dialBottom` radial face, inner top highlight, drop shadow; 6 × 18 indicator at 12 o'clock |
| Marks | Tick dots every 15° (5 pt at N/E/S/W) in `tick` `#807075`; upright N/E/S/W, **N in accent**; ↑ / ↓ inside the rise / set dots |
| Live Moon | 18 pt `moonLit` dot, no arrow, "Moon" only in the lock pill (§11 Q4 as proposed) |
| Locked | Amber pill "Moonrise · 58° ENE" + glow; dot 22 pt with 4 pt ring + strong glow; dial halo. Dial doesn't move |
| Notes | `CompassNote`: amber-tint pill, "!" circle, footnote, ≤ 330 pt, for low accuracy, Precise, Nearby, location off, Far, aha line. Use Precise Location / Turn On Location are secondary buttons |
| Motion | Lock change eases 0.2 s; **Reduce Motion: no animation**. Marks still don't animate (no 359° → 0° spin) |
| Unchanged | Haptic per lock, sensors on/off, Far hides the dial, all copy and VoiceOver labels |
| Tests | `ThemeTests`: ticks ≥ 3:1 on `dialTop` too |
| Docs | DESIGN-1.1.md §3.3 as-built note; DECISIONS.md "5.4 compass restyle"; STATUS.md; DESIGN-REVIEW.md; ARCHITECTURE.md; COMPASS.md; CLAUDE.md counts |

**Checked:**
- **Build:** clean, no warnings. **Tests:** 398 tests / 604 cases across 27 suites, all pass (via Xcode).
- **Screenshots:** `5.4-compass/` (unlocked, locked, low accuracy, Precise off, Nearby, Far, location off;
  previews with a fake heading, since the simulator has no compass; plus the app with location off).
  Findings: `5.4-compass/5.4-compass.md`.

**Review notes:**
- **Uncommitted 5.4 work was already in the tree** (7:43–7:45 AM). I finished it rather than starting over.
  Fixed on top: the dial dropped ~11 pt on every lock (the pill grew its slot), the 260 pt AX dial was
  removed (5.5), and the "!" is now bold.
- **Low-accuracy heading is dimmed** (as since 4.x); the HTML shows it full strength. Change it?
- **Buttons are wider than short notes** (330 pt cap vs a one-line note). Accept, or match the note?
- **§11 Q4** (live Moon dot) is still "proposed". Built as proposed.
- **Check on device:** lock pill + haptic, marks moving smoothly as you turn, VoiceOver, Reduce Motion.

## `9eccab9` · Step 2.2 fix 4: recents narrow to the full query before type-ahead · **local**
## `54acb8f` · Step 5.3 fix 1: madlib lines share one scale · **local**
_Not written up in this report; see the commit messages._

---

## `01a6650` · Step 5.3: Design 1.1 madlib sentence (with §3.1a) · **local**

**What changed** (one commit; your §3.1a and DECISIONS.md 2026-10-01 edits are in it):

| Item | Change |
|---|---|
| Sentence | `Features/Location/MadlibSentence.swift`: "Where can I find the moon / 📅 tonight in / 📍 Los Angeles, CA?", always three lines |
| Lines | Each line: one line at full size → one line scaled to as little as 0.8 → wrap. Each keeps a full line's height (27 × 1.5, scaled), so the card doesn't move |
| Tokens | Date: "tonight" / "on Sat, Oct 3" / "…, 2027" → calendar. Place: `nameWithRegion` → search. Amber, underlined, icon held to the first word by a non-breaking space |
| Icons | `token.calendar` / `token.pin` custom symbols: the HTML's 1.7-stroke SVGs outlined (CoreGraphics), sized to its px beside 27 pt text |
| VoiceOver | Sentence (header), then "Date, tonight" and "Place, Los Angeles, C A" as **buttons**, in that order (synthetic children over the link text). Checked in the accessibility tree |
| No place | "tonight in" plain words, "📍 a city" token, **Use my location** as a secondary button (`Theme/SecondaryButtonStyle`). The last-viewed city stands in while the launch fix runs |
| Removed | The prompt, the search-field button, `DateControl` |
| Text | `Formatting/MadlibFormatter` (+ `DayLabelFormatter.spokenLabel`); spacing metrics in `Theme.Metrics` |
| Tests | `MadlibFormatterTests` (new suite), spoken token date, view-model token routing, no-place and stand-in |
| Docs | DESIGN-1.1.md as-built note under §3.1a; DECISIONS.md "5.3 madlib sentence"; ARCHITECTURE.md; DATE.md; STATUS.md; CLAUDE.md counts |

**Checked:**
- **Build:** clean, no warnings. **Tests:** 388 tests / 594 cases across 26 suites, all pass (iPhone 17 simulator, via Xcode).
- **Simulator:** screenshots in `design-1.1/5.3-*.png` (today, Oct 3, Sydney, London, long city, no place, AX3).
  Findings: `design-1.1/5.3-madlib.md`.

**Time zone (your report):** **present after 5.3.** Sydney shows GMT+10 (under the time), London GMT+1, Sydney River
ADT (both beside the time); 5.3 doesn't touch the card. A place in the phone's own zone shows none, by design
(§11 Q3). If you saw it missing for a far-away city, send me the city.

**Review notes:**
- **Search bug (not 5.3, not fixed):** the recent "Sydney, Australia" loaded **Sydney River, Nova Scotia**
  (`5.3-sydney-river-misresolve.png`). "Sydney NSW" → "Sydney, NSW" works. Step 2.2 resolve path; want a fix?
- **Line 1 shrinks to ~95%** at default size on the 402 pt iPhone 17 ("Where can I find the moon" is slightly too wide
  at 27 pt), so it reads a touch smaller than line 2. Accept, or drop the sentence to 26 pt?
- **No 📅 with no place:** "tonight" is plain words there (no place's calendar to pick in; §3.1's example has none).
- Underline is the system's; SwiftUI can't set 1.5 pt thickness or the 7 pt offset.
- `xcshareddata/xcodecloud/` is still untracked; left alone.

**Next:** 5.4 compass restyle.

---

## `cfd274a` · Step 5.2 fix 2: degrees in the rise/set VoiceOver labels · **local**

"Moonrise at 9:10 PM, east-northeast, 58 degrees"; with a zone: "… Sydney time, GMT+10, east-northeast, 56 degrees".
Same rounding as the visible "58° ENE" (`CompassFormatter.spokenDegrees`). Tests updated + `spokenDegrees` cases.
Checked in the accessibility tree.

---

## `b94ff8a` · Step 5.2 fix 1: rise/set times round to the nearest minute · **local**

**Yes, it truncated.** The engine gives LA 21:09:52 (Sep 30 rise) and 14:26:33 (Oct 3 set), and `Date.FormatStyle`
drops the seconds, so the card showed 9:09 / 2:26. `MoonTableFormatter.time` now rounds to the nearest minute, half
up (USNO's convention), giving 9:10 / 2:27. The spike table truncated too, so this predates 5.2. Engine values
and test tolerances unchanged. One test had a truncating expected string; it now goes through the formatter.
Your `DESIGN-REVIEW.md` status-bar edit is in this commit.

---

## `e948ea2` · Step 5.2: Design 1.1 moon card · **local**

**What changed** (one commit):

| Item | Change |
|---|---|
| Card | `Features/MoonTable/MoonCard.swift`: header (date label + ‹ › 32 pt raised circles in 44 pt hit areas), phase row, one hairline, rise/set columns with a centred divider. Values from the HTML |
| Header | "Today · Wed, Sep 30" on today, "Sat, Oct 3" otherwise (`DayLabelFormatter.cardLabel`). ‹ › and VoiceOver's adjustable stepping + announcements moved here from `DateControl` |
| Glyph | `PhaseGlyph` + `PhaseGlyphGeometry`: real lit fraction, elliptical terminator (`1 − 2k`), waxing lit right, waning left |
| Zone | Beside each time when the place's zone differs from the phone's (§11 Q3), sampled at that event; wraps under the time when it doesn't fit. The "Sydney · AEST" line and `timeZoneLabel` are gone |
| Model | `MoonTableViewModel` (replaces the spike VM), text from `Formatting/MoonTableFormatter` |
| Removed | `ContentView`, `SpikeMoonTableViewModel`, `SpikeMoonTableViewModelTests`. Previews use `Place.marVista` |
| Interim | `DateControl` only opens the calendar, until 5.3's date token |
| Theme | `Theme.Metrics` (hairline, 44 pt target, card radius/padding/gap, ‹ › size) |
| Tests | `MoonTableFormatterTests`, `MoonTableViewModelTests`, `PhaseGlyphGeometryTests` (lit area at 0/25/50/75/100%, waxing and waning), card label cases, per-event zone tests (incl. LA's fall-back day) |
| Docs | DECISIONS.md "5.2 moon card"; DESIGN-1.1.md §3.2 as-built note, `tick` → `#807075` in §2 table and §7 5.4; ARCHITECTURE.md; DATE.md; STATUS.md; CLAUDE.md counts |

**Checked:**
- **Build:** clean, no warnings. **Tests:** 371 tests / 568 cases across 25 suites, all pass (iPhone 17 simulator, via Xcode).
- **Simulator:** screenshots in `design-1.1/` (LA today, LA Oct 3 with no moonrise, Sydney with the zone shown).
  Findings: `design-1.1/5.2-moon-card.md`.

**Review notes:**
- **Zone wraps under the time** at default size (column ~145 pt; "11:13 PM GMT+10" ~165 pt). That's the §3.2
  fallback, but it'll be the norm. Accept, or adjust?
- **One hairline**, as the HTML, not the two that §3.2's wording implies.
- **VoiceOver** keeps the spike's wording without degrees (§3.2 rule vs its example). Easy to add.
- **For 5.4:** `tick` → `#807075` (3.15:1 on `dialTop`, 3.64:1 on `dialBottom`). §2 table updated and marked
  "Set in 5.4"; code unchanged until then.
- `docs/DESIGN-REVIEW.md` (your status-bar edit) is still uncommitted; I left it out as it isn't mine.
  `xcshareddata/xcodecloud/` is still untracked.
- The `design-1.1/` folder (created this time) holds 5.2's findings and screenshots; 5.1's screenshot stays in `step-5/`.

**Next:** 5.3 madlib sentence.

---

## `c203caa` · Step 5.1: Design 1.1 theme · **local**

**What changed** (one commit; the uncommitted doc changes and `design/1.1/` are in it, as asked):

| Item | Change |
|---|---|
| Tokens | `Theme/Theme.swift`: `Theme.Colors` (all §2 colors, spec names), `Theme.Fonts` (the §2 type scale, every size `relativeTo:` a text style; dial letters capped at 17, ↑/↓ fixed 14), `Theme.FontName` (PostScript names). `nonisolated`, since the app defaults to main-actor isolation |
| Fonts | `Resources/Fonts/`: Young Serif (google/fonts) and Nunito Sans Regular / SemiBold / Bold (static TTFs from googlefonts/NunitoSans), plus both OFL texts. Listed in `UIAppFonts` |
| Background | `Theme/ScreenBackground.swift`: `bg` plus the top glow (`accent` 8% → 0, 520 × 420 ellipse, top −120, CSS `closest-side`), read from the HTML. Behind `LocationScreen` |
| Status bar | iOS 26: solid `bg` backing, replacing 4.15's `.bar` material. iOS 27: the soft edge effect is unchanged (§2) |
| Forced dark | `UIUserInterfaceStyle` = `Dark` in Info.plist (also covers sheets and launch) |
| Accent | `AccentColor` asset = `#F2C27B`, so system controls are amber |
| App defaults | App root: `.font(Theme.Fonts.body)` + `.foregroundStyle(textPrimary)`, so unstyled text and sheets pick up the theme (§6) |
| Tests | `ThemeTests` (3 tests / 12 cases): each font registers (`UIFont(name:)`), and the §2 contrast table matches the hex values to 0.1 and passes AA |
| Docs | ARCHITECTURE.md §2 tree + §8 fonts row; CLAUDE.md test counts; DECISIONS.md "5.1 theme"; DESIGN-1.1.md `tick` contrast note; STATUS.md |

**Checked:**
- **Tests:** 351 tests / 516 cases, all pass, on the iPhone 17 simulator (via Xcode). `xcodebuild test` from the
  agent shell compiled but couldn't launch the test runner (sandbox: "Pseudo Terminal Setup Error"), so the run
  went through Xcode's test action. Xcode's run destination had been set to a device, so its first runs used a stale
  test bundle; switching it to iPhone 17 fixed that.
- **Simulator (iOS 27):** `step-5/5.1-simulator.png`. Nunito Sans renders, the background and glow are faint, as
  designed, and everything is dark. (SwiftUI previews skip the app root, so they still show SF.)
- **Not checked:** the iOS 26 solid status bar backing on a device (the simulator here is iOS 27).

**Review notes:**
- **Findings folder missing:** `.agent-reports/design-1.1/` (findings + screenshots) doesn't exist on this Mac.
  I built from DESIGN-1.1.md and the HTML. If it's somewhere else, point me to it and I'll check 5.1 against it.
- **`tick` contrast:** 3.46:1 on `dialBottom` (the rim) but **2.997:1 on `dialTop`**, just under 3:1. I didn't
  change the token. It's fine as long as ticks stay near the rim; noted in DESIGN-1.1.md for 5.4 and the a11y pass.
- **Visible side effect:** the ‹ › chevrons and other plain-style buttons are now cream (`textPrimary`), not
  system tint, because of the root foreground style. That matches the spec's ‹ › glyph color; drop the root
  `.foregroundStyle` if you'd rather keep tint until each step styles them.
- **Glow vs solid status bar (iOS 26):** the design draws a solid 54 pt `bg` bar over the glow too, so the glow is cut
  at the status bar edge. At 8% it should be invisible, but check it on device.
- **Not done in 5.1 (on purpose):** spacing/radius tokens (each step adds the ones it uses), restyling any view.
- `moonbeam-app.xcodeproj/xcshareddata/xcodecloud/` is still untracked. It isn't mine, so I left it out.

**Next:** 5.2 moon card.
