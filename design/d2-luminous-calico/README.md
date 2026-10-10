# D2 luminous calico

Five transparent still SVGs and fifteen motion studies for Moon Signal.

## Stills

- `stills/d2-searching.svg`
- `stills/d2-location-not-found.svg`
- `stills/d2-permission-off.svg`
- `stills/d2-services-off.svg`
- `stills/d2-restricted.svg`

Each has a 400 × 520 viewBox, no labels or background rectangle, no embedded bitmap, external font, animation, filter, or external dependency. The moon halo uses a radial gradient. Designed for the app's warm dark background (#1D171B).

These are **vector reconstructions**, not pixel-identical exports: the approved generated D2 board was raster. Cat colors are simplified into traced paths; moon, telescope, map, and lock geometry are rebuilt. The approved raster remains in `reference/d2-approved.png` for comparison. Review the included stills preview before treating the redraw as final visual approval.

## iOS handoff

`D2Illustrations.xcassets` contains all five images, with Preserve Vector Representation enabled. Copy its image sets into the app's asset catalog, or add this catalog to the app target. Example name: `Image("d2-searching")`. The app has not been modified or wired to these assets.

The catalog was compiled successfully using the installed Xcode `actool` for iPhone Simulator, minimum iOS 26.0. The output was `Assets.car`; simulator-service warnings occurred under the sandbox, but asset compilation completed with exit 0. This checks asset acceptance, not final on-device rendering. The SVGs were also rendered on a dark background and checked as XML for embedded images, scripts, and filters.

## Motion studies

Open `motion-preview.html`; choose a state and compare its three options. Every preview runs for six seconds and stops. Pause, Resume, and Replay are available. Reduce Motion starts with still artwork and requires an explicit replay to animate.

| State | Option 1 | Option 2 | Option 3 |
| --- | --- | --- | --- |
| Searching | Halo breath, about 4 s | Tail sway, ±3° | Look/pause/look, +3° then −2° |
| Location not found | One 3.5° head tilt | Question fades and settles 4 units | One 3° tail settle |
| Permission off | Telescope lifts 2.5° once | One halo glimmer | Foreground settles 4 units |
| Services off | Route dims to 72% | One halo glimmer | Map rocks 1.4° and settles |
| Restricted | Closed lock fades in | Closed lock scales up 4.5% once | One halo glimmer |

Recommendation: search uses a slow halo breath with an occasional look; not-found uses one curious tilt; permission-off uses one telescope lift; services-off uses route dimming; restricted uses lock arrival. Avoid running all options together. Error-state motion should settle rather than suggest an active retry, and the restricted lock should never open.

The searching reference recording shows a small look-and-pause cycle, not a continuous bounce. These studies approximate that timing with a slight head/paw rotation; a true perspective head turn needs additional drawn poses.

Named groups make motion exploration possible (`moon`, `moon-halo`, `foreground`, `tail`, `look`, `tube`, `map`, `route`, `lock`, where applicable). Importing a still into an asset catalog does not expose these as SwiftUI layers; later native animation should split the selected moving groups into separate assets or draw them as paths. The current preview is a design prototype, not production iOS animation code.

Validation: browser preview exercised all five state selections and playback controls without script errors, fits a 375 px viewport, and opens still under Reduce Motion. Source assets contain no raster `<image>` nodes.
