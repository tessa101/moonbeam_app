# TestFlight 1.1 (12)

Prepared November 25–26, 2026. App display name: **Hello Luna**, bundle ID `com.t-alien.moonbeam-app`. Previous build:
1.0 (11). Version: `MARKETING_VERSION` **1.1** (1.0 is live in the App Store, so App Store Connect won't take more 1.0
builds, and the map is a new feature), `CURRENT_PROJECT_VERSION` 12 (app target, Debug and Release; the test target is
unchanged). Build numbers keep counting up across versions.

## Release scope

The map (MAP.md, steps 6.1–6.3): tapping Moonrise or Moonset on the card opens a satellite map with the rise and set
lines from a "stand here" pin. It opens following you and turning with the phone; a line locks amber with a haptic
when you face it, with "Turn 23° right" hints. Drag or tap to stand elsewhere and keep turning there. Satellite /
Explore / 3D; 3D opens looking along the selected line from about 300 ft up, and dragging moves where you stand.

No new permission, Info.plist key, privacy-manifest entry or dependency: MapKit was already linked, and location
(When In Use) was already asked for. The map is the one feature besides city search that needs the network
(PRODUCT NFR3).

Not in this build: the moon's path at times other than rise and set; true eye-level views (MAP.md §8).

## Verification (on the Mac, before archiving)

Not run from the cloud session (no Xcode there). Tessa to run and fill in:

- [ ] Map suites: `BearingLineTests`, `MoonMapViewModelTests`, `LocationViewModelMapTests` pass.
- [ ] Full suite (iPhone 17 simulator): only the known failures (SentenceTokenTests command-line-only, the
      PlaceChangeLayout timing flake that passes alone). Watch `MoonCardAccessibilityTests`: the rise/set cells are
      now buttons for VoiceOver.
- [ ] `ButtonStyleDriftTests` passes (the map's legend and round buttons use the shared row and inline styles).
- [ ] Release build succeeds; no new warnings versus build 11 (the `MoonTableFormatter` `attributed` deprecation is
      known).
- [ ] On the phone, after closing the map: the main compass comes back and locks as before.

Archive: Xcode → Product → Archive (Any iOS Device, Release), then Organizer → Distribute App → App Store Connect.
App Store Connect: if version 1.1 doesn't exist yet, the upload creates it for TestFlight. For the App Store release,
add version 1.1 on the app's page (the "+" next to iOS App), pick build 12 or later, and paste "What's New" below.

## What to Test (paste into TestFlight)

```
Hello Luna 1.1 (12)

New: a map that shows where to stand to catch the moonrise or moonset.

HOW TO OPEN IT
Tap "Moonrise" or "Moonset" on the moon card.

WHAT'S NEW
• A satellite map with lines showing the moonrise and moonset directions from where you stand.
• It follows you and turns with your phone. Point your phone along a line and it locks on: you'll feel a tap and the line turns amber. The card at the bottom tells you which way to turn.
• Drag the map or tap anywhere to stand somewhere else (a beach, a hill, a parking lot). It keeps turning and locking there.
• Tap the Moonrise or Moonset box at the bottom (or a line's label) to switch lines.
• Satellite, Explore (the normal map) and 3D at the top. 3D shows the view along the line from above; drag to move where you stand.

PLEASE TRY
1. Open the map from Moonrise, then from Moonset.
2. Turn slowly in a full circle. Does each line lock when you face it, and let go cleanly?
3. Drag to a spot you'd actually watch from and turn again.
4. Try 3D, then the binoculars button on the left to switch between the overview and the line view.
5. Close the map with Done. Does the compass on the main screen still work?

TELL ME ABOUT
• The map freezing, stuttering, or fighting your finger.
• Lines or labels that are confusing or hard to read on the satellite view.
• Whether 3D helps you judge if hills or buildings are in the way.
• Anything that felt slow, janky, or confusing.

Thank you!
```

## What's New in 1.1 (App Store, draft)

```
New: a map that shows where to stand to catch the moonrise or moonset.

Tap Moonrise or Moonset on the moon card to see the directions as lines on a satellite map. The map turns with your phone, and when you face a line it locks on with a gentle tap. Drag the map or tap anywhere to try another spot, like a beach or a hilltop. Switch to 3D to see the view along the line.
```
