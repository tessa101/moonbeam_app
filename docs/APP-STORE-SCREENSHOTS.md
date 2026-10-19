# App Store screenshots (Hello Luna 1.0)

Status: planned 2026-10-17. Capture is an agent run (no code changes); framing and captions are done separately.

## Decisions

- Style B: device captures in a device frame, with a short caption above each. Captions about 5 words, in the app's witty voice.
- iPhone only for 1.0. No iPad sizes.
- One size: 6.9" (iPhone 17 Pro Max simulator). App Store Connect scales down for smaller phones. Confirm the exact pixel size in the upload screen, since Apple adjusts it with new devices.
- Dark mode only, default text size, Reduce Motion off.
- Showcase city: Los Angeles, CA.
- Compass is built and is the strongest screen, so it is in the set. The date picker stays in as shot 4.

## Shot list

| # | File | Screen | Draft caption |
|---|------|--------|---------------|
| 1 | `01-landing.png` | Onboarding landing: awake cat and halo | "Hello, Luna." |
| 2 | `02-main.png` | Main screen, Los Angeles, headline, phase card, rise/set | "Know when the moon shows up." |
| 3 | `03-compass.png` | Compass dial and arc centered, accuracy banner gone | "Point your phone, find the moon." |
| 4 | `04-date.png` | Date picker open on a chosen date | "Plan any night ahead." |
| 5 | `05-search.png` | "Search for a city" sheet with results | "No location? No problem." |
| 6 | `06-ready-to-look.png` | Ready-to-look cat, settled | "Ready when you are." |

Captions are drafts; the voice is Tessa's to edit.

## Capture rules

- Capture with the TestFlight-only tools available but never in frame: no debug tools, banners, keyboards, or mid-animation frames. These tools are removed in the strip run, so capture happens before it.
- Wait about 2 seconds after each transition so motion has settled.
- Status bar cleaned: `xcrun simctl status_bar booted override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3`
- Capture command: `xcrun simctl io booted screenshot <path>`
- Pick a date with an interesting phase (not a dull one) and record which date.
- Output: `output/app-store-screenshots/raw/`. Framed exports go in `output/app-store-screenshots/framed/`.

## Likely trouble spots

- Shot 3: the compass accuracy banner shows in the simulator. Wait for it to clear.
- Shot 6: the cat is in idle motion. Let it settle before capturing.
- Shot 2 at larger text sizes: the floating compass pill and banner cover the main card (open item, see STEP-5.15). Capture at default size only.

## Framing

- Device frames and captions are added after capture, in a consistent style on a dark background.
- Export at the exact pixel size App Store Connect lists for 6.9".
- No text inside the screenshot that contradicts the shipped copy.

## Checklist

- [ ] Capture run done, raw files reviewed (no debug UI, banners, or cropping issues)
- [ ] Retakes for any `-needs-review` files
- [ ] Captions finalized
- [ ] Framed exports at the correct size
- [ ] Uploaded to the Hello Luna record in App Store Connect
