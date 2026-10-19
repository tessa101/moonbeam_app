# D2 sleeping calico — still SVG handoff

Use `d2-sleeping-layered.svg` as the editable master. It is a transparent 1254 × 1254 vector reconstruction of the approved muted-tan sleeping illustration. Fine raster fur texture is simplified into paths. It contains no embedded bitmap, external dependency, or animation.

## Layers

1. Moon glow
2. Moon disc
3. Ground shadow
4. Concealed belly behind tail
5. Body and markings
6. Front paws
7. Head, ears and face
8. Tail

## iOS

Copy `d2-sleeping.imageset` from the included catalog into the app asset catalog, or add `D2SleepingStill.xcassets` to the app target. Preserve Vector Representation is enabled. Display with `Image("d2-sleeping").resizable().scaledToFit()`. The artwork is intended for the existing warm dark background (#1D171B); it has no opaque background rectangle. Keep aspect ratio intact.

The composite is a still. SVG groups remain editable in the source; importing the image into the asset catalog does not expose those groups as SwiftUI animation layers. Tail motion is deferred and is not included in this package.

The SVG passed XML/vector-content checks. Asset compilation passed during preparation; check the final appearance in the app at its intended display size. This handoff does not change app code.
