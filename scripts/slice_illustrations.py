#!/usr/bin/env python3
"""Slice the location-failure illustrations into stackable layers.

STEP-5.10a-LOCATION-FAILURE.md, Chunk 4. For each failure state's layered
SVG in design/1.6-location-error-illustrations/assets/anim/, emit one SVG per
animated part and one per static run between them,
in the original z-order. Every slice keeps the full document: the same root
(400 x 520 viewBox), the shared <defs> (gradients), and every group and
transform, including the art's translate(dx -130). Only the slice's own shapes
are kept, so stacking the slices with no offsets redraws the original art.

The <metadata> (c2pa) block is stripped. Nothing is redrawn.

A shape belongs to its nearest animated ancestor (or itself, if it is an
animated part). Animated parts nested in other animated parts (route and lock
inside map) get their own slices; the slice list records the chain of parts
each one moves with, for the motion chunk.

Usage:
    scripts/slice_illustrations.py [--out DIR] [--catalog PATH]

With --catalog, the slices are also written into an asset catalog, one folder
per state, as single-scale vector image sets rendered as Original.
"""

import argparse
import copy
import json
import pathlib
import tempfile
import xml.etree.ElementTree as ET

SVG_NS = "http://www.w3.org/2000/svg"
NS = "{%s}" % SVG_NS
ET.register_namespace("", SVG_NS)

REPO = pathlib.Path(__file__).resolve().parent.parent
SOURCE = REPO / "design/1.6-location-error-illustrations/assets/anim"

# The art's canvas: every slice is drawn at this size.
CANVAS_WIDTH = "400"
CANVAS_HEIGHT = "520"

# Drawable elements: the leaves a slice keeps or drops.
SHAPES = {"path", "circle", "ellipse", "rect", "line", "polyline", "polygon", "text", "use", "image"}

# Per state: the file, the asset-name prefix, and the animated parts
# (ILLUSTRATIONS_MOTION.md "Assets" table, plus the shared moon breathing).
STATES = [
    ("searching.svg", "searching", ["moon-halo", "moon-disc", "tail", "look"]),
    ("location-not-found.svg", "locNotFound", ["moon-disc", "moon-ring", "head", "tail", "question"]),
    ("permission-off.svg", "permissionOff", ["moon-halo", "moon-disc", "tube"]),
    ("services-off.svg", "servicesOff", ["moon-halo", "moon-disc", "map", "route"]),
    ("restricted.svg", "restricted", ["moon-halo", "moon-disc", "map", "route", "lock"]),
]


def camel(part):
    """moon-halo -> moonHalo."""
    head, *rest = part.split("-")
    return head + "".join(word.capitalize() for word in rest)


def tag(element):
    return element.tag.replace(NS, "")


def leaves_in_order(root, animated):
    """Every drawable shape in document order, with the chain of animated
    parts it sits in (outermost first) and the nearest data-part of any kind
    (for naming static runs).

    The route's waypoint circles each glow on their own (Chunk 5), so each
    is its own part: waypoint-1, waypoint-2, waypoint-3 in document order."""
    result = []
    waypoints = [0]

    def walk(element, chain, named):
        name = element.get("data-part")
        if name in animated:
            chain = chain + [name]
        if name:
            named = name
        if tag(element) in SHAPES:
            if tag(element) == "circle" and chain and chain[-1] == "route":
                waypoints[0] += 1
                chain = chain[:-1] + [f"waypoint-{waypoints[0]}"]
            result.append((element, tuple(chain), named))
            return
        if tag(element) in ("defs", "metadata", "title", "desc"):
            return
        for child in element:
            walk(child, chain, named)

    walk(root, [], None)
    return result


def runs(leaves):
    """Consecutive shapes with the same animated chain form one layer."""
    grouped = []
    for element, chain, named in leaves:
        if grouped and grouped[-1]["chain"] == chain:
            grouped[-1]["elements"].append(element)
            grouped[-1]["named"].append(named)
        else:
            grouped.append({"chain": chain, "elements": [element], "named": [named]})
    return grouped


def slice_document(root, keep):
    """A copy of the whole document with only the shapes in `keep`, and
    empty groups pruned. Groups, transforms and defs stay as they are."""
    mapping = {}
    clone = copy.deepcopy(root)
    for original, copied in zip(root.iter(), clone.iter()):
        mapping[copied] = original

    def prune(element):
        for child in list(element):
            if tag(child) in ("defs", "title", "desc"):
                continue
            if tag(child) == "metadata":
                element.remove(child)
            elif tag(child) in SHAPES:
                if mapping[child] not in keep:
                    element.remove(child)
            else:
                prune(child)
                if tag(child) == "g" and len(child) == 0:
                    element.remove(child)

    prune(clone)
    clone.set("width", CANVAS_WIDTH)
    clone.set("height", CANVAS_HEIGHT)
    for attribute in ("role", "aria-labelledby"):
        clone.attrib.pop(attribute, None)
    return clone


def layer_name(run, used):
    """Animated: the innermost part (head). Static: the data-part the run
    sits in (stand, body), numbered if it repeats."""
    if run["chain"]:
        base = camel(run["chain"][-1])
    else:
        named = next((n for n in run["named"] if n and n not in ("foreground", "moon")), None)
        base = camel(named) if named else "static"
    name = base
    index = 2
    while name in used:
        name = f"{base}{index}"
        index += 1
    used.add(name)
    return name


def write_imageset(catalog, folder, asset, svg_path):
    """One single-scale, vector-preserving image set, rendered as Original."""
    imageset = catalog / folder / f"{asset}.imageset"
    imageset.mkdir(parents=True, exist_ok=True)
    (imageset / f"{asset}.svg").write_bytes(svg_path.read_bytes())
    contents = {
        "images": [{"filename": f"{asset}.svg", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
        "properties": {
            "preserves-vector-representation": True,
            "template-rendering-intent": "original",
        },
    }
    (imageset / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")


def write_folder(catalog, folder):
    (catalog / folder).mkdir(parents=True, exist_ok=True)
    (catalog / folder / "Contents.json").write_text(
        json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n"
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", type=pathlib.Path, help="slice folder (default: a temp folder)")
    parser.add_argument("--catalog", type=pathlib.Path, help="asset catalog to write image sets into")
    args = parser.parse_args()

    out = args.out or pathlib.Path(tempfile.mkdtemp(prefix="illustration-slices-"))
    out.mkdir(parents=True, exist_ok=True)
    if args.catalog:
        args.catalog.mkdir(parents=True, exist_ok=True)
        (args.catalog / "Contents.json").write_text(
            json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n"
        )

    manifest = {}
    for filename, prefix, animated in STATES:
        root = ET.parse(SOURCE / filename).getroot()
        used = set()
        layers = []
        for run in runs(leaves_in_order(root, set(animated))):
            name = layer_name(run, used)
            asset = f"{prefix}_{name}"
            document = slice_document(root, set(run["elements"]))
            path = out / prefix / f"{asset}.svg"
            path.parent.mkdir(parents=True, exist_ok=True)
            ET.ElementTree(document).write(path, encoding="utf-8", xml_declaration=False)
            layers.append({"asset": asset, "parts": list(run["chain"]), "shapes": len(run["elements"])})
            if args.catalog:
                write_folder(args.catalog, prefix)
                write_imageset(args.catalog, prefix, asset, path)
        manifest[prefix] = layers

    (out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"slices in {out}")
    for prefix, layers in manifest.items():
        print(prefix)
        for layer in layers:
            moves = " > ".join(layer["parts"]) or "static"
            print(f"  {layer['asset']:<28} {layer['shapes']:>3} shapes  moves with: {moves}")


if __name__ == "__main__":
    main()
