#!/usr/bin/env python3
"""Cut LEVEL3_Dagat/ into game/assets/Level3/ -- Dagat's art pipeline.

WHY THIS EXISTS
---------------
The delivered art arrives as 1672x941 parallax plates, 1254x1254 prop canvases and two
dozen creature frames with names like "ChatGPT Image Sep 20, 2026, 10_35_02 AM.png". None
of that is what a scene should reference: a level built against those filenames breaks the
first time somebody re-exports, and a Sprite2D pointed at a 1254x1254 canvas holding a
120px coral is mostly empty texture.

So this is the same shape as tools/build_plaza.py and tools/build_tiles.py: one script that
turns delivered art into named, trimmed, engine-facing files, plus a manifest the game reads
instead of hard-coding frame lists.

THREE RULES IT ENFORCES, EACH BECAUSE THE ALTERNATIVE IS A BUG YOU SEE RATHER THAN READ
---------------------------------------------------------------------------------------
1. PARALLAX PLATES ARE NEVER TRIMMED. Sky, ocean, sand, ruins and terraces are all drawn on
   the same 1672x941 canvas and are registered to each other by their margins. Trim them
   independently and every layer slides by a different amount -- the horizon leaves the
   waterline, the sand floats off the ruins. They are copied whole.

2. AN ANIMATION IS TRIMMED TO ITS GROUP'S UNION, NEVER PER FRAME. The three kelp frames have
   different bounding boxes because the kelp leans; trimming each to its own box re-centres
   every frame and the plant twitches sideways instead of swaying. One box for the group.

3. EVERY DELIVERED FILE IS CONSUMED. --check fails if anything under LEVEL3_Dagat/ is not
   claimed by a rule below, so art that arrives and is quietly never used is a build error
   rather than something nobody notices until the level ships without it.

USAGE
    python3 tools/build_dagat.py            # write game/assets/Level3/
    python3 tools/build_dagat.py --check    # verify the committed output is current
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image

# Lossless, and worth the seconds it costs: this level ships more texture than the first two
# put together, and every byte of it is also VRAM at runtime. The art has gradients and
# antialiasing rather than a clean pixel grid, so there is no honest downsample available --
# re-encoding is the only saving that does not change a pixel.
SAVE = {"optimize": True}

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "LEVEL3_Dagat" / "environments"
OUT = ROOT / "game" / "assets" / "Level3"
MANIFEST = OUT / "dagat.json"

# The plate every parallax layer is drawn on. Anything this size is registered art.
PLATE = (1672, 941)


# --- The delivered art, named -----------------------------------------------------------
#
# PLATES keep their canvas. GROUPS are trimmed together and numbered from zero.

PLATES: dict[str, str] = {
    "shore/sky.png": "shoreline/BG_sky.png",
    "shore/mountains.png": "shoreline/BG_mountain.png",
    "shore/ocean.png": "shoreline/MG_Ocean_Base.png",
    "shore/sand.png": "shoreline/FG_Sand.png",
    "shore/palms_left.png": "shoreline/FG_tree1.png",
    "shore/palms_right.png": "shoreline/FG_tree2.png",
    "shore/completed_look.png": "shoreline/BG_CompletedLook_shoreline.png",

    "storm/clouds.png": "stormy_seas/ChatGPT Image Sep 16, 2026, 06_49_10 PM (1).png",
    "storm/islands.png": "stormy_seas/ChatGPT Image Sep 16, 2026, 06_49_11 PM (2).png",
    # ⚠ NAMED FOR WHAT IS IN THEM, NOT FOR THE ORDER THEY WERE EXPORTED IN. These were
    # "shore_left" and "shore_right", which described neither: (3) holds BOTH shores -- the
    # headland with its jetty at the left and the island with the ink buoy at the right --
    # and (4) is no shore at all but the sea's underside, rocks and weed and the bakunawa's
    # silhouette. The backdrop tiled both across the whole crossing on the strength of those
    # names, so a jetty and a palm island turned up every screen and the creature's shadow
    # was painted twice at once.
    "storm/shores.png": "stormy_seas/ChatGPT Image Sep 16, 2026, 06_49_11 PM (3).png",
    "storm/undersea.png": "stormy_seas/ChatGPT Image Sep 16, 2026, 06_49_11 PM (4).png",
    "storm/completed_look.png": "stormy_seas/full.png",

    "deep/water.png": "underwater/OCEAN_BG.png",
    "deep/ridges.png": "underwater/BG.png",
    "deep/ruins.png": "underwater/MG.png",
    "deep/terraces.png": "underwater/FG.png",
    "deep/completed_look.png": "underwater/CompletedLook.png",

    # ⚠ REFERENCE, NOT GAMEPLAY ART. Two sheets came with the delivery showing how the
    # layers stack and which frames belong to which animation. They are the art bible for
    # this level and they are kept for that, not drawn anywhere.
    "reference/shore_sheet.png": "shoreline/tileset.png",
    "reference/storm_sheet.png": "stormy_seas/ChatGPT Image Sep 16, 2026, 06_54_29 PM.png",
}

GROUPS: dict[str, list[str]] = {
    # Three frames of foam over a still ocean -- the surf, not the water.
    "shore/surf": [
        "shoreline/MG_Ocean_Animation1.png",
        "shoreline/MG_Ocean_Animation2.png",
        "shoreline/MG_Ocean_Animation3.png",
    ],
    "storm/waves": [
        "stormy_seas/ChatGPT Image Sep 16, 2026, 06_49_12 PM (5).png",
        "stormy_seas/ChatGPT Image Sep 16, 2026, 06_49_13 PM (6).png",
        "stormy_seas/ChatGPT Image Sep 16, 2026, 06_49_13 PM (7).png",
    ],
    "storm/rain": [
        "stormy_seas/ChatGPT Image Sep 16, 2026, 06_49_14 PM (8).png",
        "stormy_seas/ChatGPT Image Sep 16, 2026, 06_49_14 PM (9).png",
        "stormy_seas/ChatGPT Image Sep 16, 2026, 06_49_15 PM (10).png",
    ],

    "props/kelp_long": [f"underwater/Corals & kelp/Longkelp_{n}.png" for n in (1, 2, 3)],
    "props/kelp_short": [f"underwater/Corals & kelp/Shortkelp_{n}.png" for n in (1, 2, 3)],
    "props/coral_red": [f"underwater/Corals & kelp/Pcoral_{n}.png" for n in (1, 2, 3)],
    "props/coral_orange": [f"underwater/Corals & kelp/Ycoral_{n}.png" for n in (1, 2, 3)],
    "props/coral_blue": ["underwater/Corals & kelp/Bcoral.png"],
    "props/coral_violet": ["underwater/Corals & kelp/Vcoral.png"],

    "ambience/school": [f"underwater/Bubbles & fishes/fish{n}.png" for n in (1, 2, 3, 4)],
    "ambience/bubbles_long": [
        f"underwater/Bubbles & fishes/longbubbles_{n}.png" for n in (1, 2, 3)],
    "ambience/bubbles_short": [
        f"underwater/Bubbles & fishes/shortbubbles_{n}.png" for n in (1, 2, 3)],

    # THE SILHOUETTE, which is what crosses under the boat before the creature is ever seen.
    "bakunawa/shadow": [f"underwater/bakunawa/BGbakunawa_{n}.png" for n in (1, 2, 3, 4)],
}

_BAK = "underwater/bakunawa/ChatGPT Image Sep 20, 2026, %s.png"

# ⚠ SORTED BY WHERE THE EYE IS, NOT BY FILENAME. The delivery is twenty-three poses with
# timestamps for names, and nothing in a timestamp says which way the creature is facing or
# whether its head is reared. The eye is the brightest cluster on the body, so its position
# inside the body's own bounding box answers both -- measured, then written down here:
#
#   eye at ~0.05 of the way across  ->  head low and forward, facing left   (searching)
#   eye at 0.14 .. 0.31             ->  head reared back over the coils     (thrashing)
#   eye past 0.5                    ->  facing right                        (turned)
#
# Regenerate the reading with the snippet in LEVEL_3.md before re-sorting these by hand.
GROUPS["bakunawa/searching"] = [_BAK % t for t in [
    "10_26_02 AM", "10_34_50 AM", "10_35_02 AM", "10_35_05 AM", "10_35_13 AM",
    "10_35_20 AM", "10_35_23 AM", "11_15_45 AM (1)", "11_15_45 AM (2)",
    "11_15_46 AM (3)", "11_15_46 AM (4)", "11_15_46 AM (5)", "11_15_47 AM (6)",
]]
GROUPS["bakunawa/thrashing"] = [_BAK % t for t in [
    "10_34_53 AM", "10_34_56 AM", "10_35_09 AM", "10_35_16 AM", "10_35_28 AM",
]]
GROUPS["bakunawa/turned"] = [_BAK % t for t in [
    "10_34_59 AM", "10_45_19 AM (1)", "10_45_20 AM (2)", "10_45_20 AM (3)",
    "10_45_20 AM (4)",
]]


def _load(rel: str) -> Image.Image:
    path = SRC / rel
    if not path.exists():
        raise SystemExit(f"missing delivered art: {path}")
    return Image.open(path).convert("RGBA")


def _union_bbox(images: list[Image.Image]) -> tuple[int, int, int, int]:
    boxes = [im.getbbox() for im in images if im.getbbox()]
    if not boxes:
        raise SystemExit("an animation group is entirely transparent")
    return (min(b[0] for b in boxes), min(b[1] for b in boxes),
            max(b[2] for b in boxes), max(b[3] for b in boxes))


OWNED = ("shore", "storm", "deep", "props", "ambience", "bakunawa", "reference")


def _sweep_orphaned_imports() -> None:
    """An .import whose picture this run did not write belongs to art that has gone."""
    for owned in OWNED:
        directory = OUT / owned
        if not directory.exists():
            continue
        for stale in directory.glob("*.png.import"):
            if not stale.with_suffix("").exists():
                stale.unlink()


def build() -> dict:
    # ⚠ ONLY WHAT THIS TOOL OWNS. A blanket rmtree of Level3/ took out the authored ink jar
    # that tools/build_dagat_props.py writes, and did it silently on --check. The generated
    # directories are listed; anything else under Level3/ belongs to somebody else.
    #
    # ⚠ AND ONLY THE PICTURES, NOT GODOT'S .import FILES BESIDE THEM. Those are committed and
    # carry each texture's uid; an rmtree deleted all ninety of them on every run, so a
    # rebuild that changed nothing still showed as ninety deletions and re-imported the lot
    # under new uids. The pictures are rewritten; an .import survives while its picture does,
    # and is swept in _sweep_orphaned_imports once the new set is known.
    for owned in OWNED:
        directory = OUT / owned
        if directory.exists():
            for picture in directory.glob("*.png"):
                picture.unlink()
    manifest: dict = {
        "$comment": [
            "Generated by tools/build_dagat.py. Do not hand-edit -- regenerate.",
            "Plates keep the 1672x941 canvas they were drawn on, because the parallax",
            "layers are registered to each other by their margins. Groups are trimmed to",
            "the union of their frames so an animation cannot twitch sideways.",
        ],
        "generated_by": "tools/build_dagat.py",
        "plate_size": list(PLATE),
        "plates": {},
        "groups": {},
    }
    used: set[str] = set()

    for name, rel in PLATES.items():
        im = _load(rel)
        used.add(rel)
        dest = OUT / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        im.save(dest, **SAVE)
        bbox = im.getbbox() or (0, 0, im.width, im.height)
        manifest["plates"][name[:-4]] = {
            "file": f"res://assets/Level3/{name}",
            "size": [im.width, im.height],
            "content": list(bbox),
            "is_plate": [im.width, im.height] == list(PLATE),
        }

    for name, rels in GROUPS.items():
        images = []
        for rel in rels:
            images.append(_load(rel))
            used.add(rel)
        box = _union_bbox(images)
        files = []
        for index, im in enumerate(images):
            dest = OUT / f"{name}_{index}.png"
            dest.parent.mkdir(parents=True, exist_ok=True)
            im.crop(box).save(dest, **SAVE)
            files.append(f"res://assets/Level3/{name}_{index}.png")
        manifest["groups"][name] = {
            "frames": files,
            "size": [box[2] - box[0], box[3] - box[1]],
            # Where the trimmed art sat on its original canvas, so a prop can be placed by
            # its own anchor rather than by eye.
            "origin": [box[0], box[1]],
            "source_canvas": [images[0].width, images[0].height],
        }

    # RULE 3. Anything delivered and not claimed above is a build error.
    delivered = {
        str(p.relative_to(SRC)) for p in SRC.rglob("*.png")
        if not p.name.startswith(".")
    }
    orphans = sorted(delivered - used)
    if orphans:
        print("ERROR: delivered art nothing uses:", file=sys.stderr)
        for o in orphans:
            print(f"  {o}", file=sys.stderr)
        raise SystemExit(1)
    manifest["sources_consumed"] = len(used)
    _sweep_orphaned_imports()
    return manifest


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true",
                    help="fail if the committed output differs from a fresh build")
    args = ap.parse_args()

    if args.check:
        if not MANIFEST.exists():
            print(f"{MANIFEST} does not exist -- run tools/build_dagat.py", file=sys.stderr)
            return 1
        before = MANIFEST.read_text()
        manifest = build()
        text = json.dumps(manifest, indent=2) + "\n"
        MANIFEST.write_text(text)
        if before != text:
            print(f"{MANIFEST} was stale -- it has been rebuilt", file=sys.stderr)
            return 1
        print(f"{MANIFEST} is up to date ({manifest['sources_consumed']} sources consumed)")
        return 0

    manifest = build()
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Wrote {OUT}")
    print(f"  {len(manifest['plates'])} plates, {len(manifest['groups'])} animation groups, "
          f"{manifest['sources_consumed']} delivered files consumed")
    for name, group in manifest["groups"].items():
        print(f"    {name:24} {len(group['frames'])} frames  {group['size'][0]}x{group['size'][1]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
