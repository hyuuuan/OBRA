#!/usr/bin/env python3
"""Draw Dilim's creatures as pixel strips: every one of them, every animation.

WHY CODE-DRAWN
--------------
The Makiling delivery has no creature art, and Kent's call was code-drawn now, replaceable by
drawn art later without a code change -- each creature loads `<kind>_<anim>.png` from
game/assets/Level4/creatures/, so a delivered strip of the same name simply wins.

HOW THEY ARE DRAWN
------------------
In the delivered art's idiom (the apo, Lolo, the bakunawa): one art px to one screen px, five or
six tones a material lit from the upper left, and selective coloured outlines -- see
tools/creature_sculpt.py. The creatures themselves are in dilim_beasts.py (the aswang, the sigbin),
dilim_giants.py (the tikbalang, the bungisngis), dilim_kapre.py (the kapre, sat in its
tree, its smoke and its cigar), dilim_fliers.py (the manananggal, the wakwak, the tik-tik) and dilim_small.py (the tiyanak,
the santelmo, the nuno's mound, the lower half, the kapre's balete).

THE STRIP CONTRACT
------------------
A strip is a row of square frames, as wide as it is tall times the frame count; a strip whose
width is not a whole number of its height is one picture (the nuno's mound). Ground creatures
stand on the bottom row, centred across the frame; fliers are centred both ways -- the frame's
centre is the creature's position in the game.

USAGE
    python3 tools/build_dilim_creatures.py            # write game/assets/Level4/creatures/
    python3 tools/build_dilim_creatures.py --check    # verify the committed strips are current
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from PIL import Image  # noqa: E402

import dilim_beasts as beasts  # noqa: E402
import dilim_fliers as fliers  # noqa: E402
import dilim_giants as giants  # noqa: E402
import dilim_kapre as kapre  # noqa: E402
import dilim_small as small  # noqa: E402
import pixelart  # noqa: E402
from creature_sculpt import strip as row  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "game" / "assets" / "Level4" / "creatures"

# Which way each stands: on its feet at the bottom row, or centred (a flier).
GROUND = ["aswang_dog", "aswang_pig", "sigbin", "tikbalang", "bungisngis", "kapre", "kapre_tree", "tiyanak", "manananggal_lower", "nuno_mound"]
FLYING = ["manananggal_upper", "wakwak", "tiktik", "santelmo"]


def _beast(b):
    return {anim: [beasts.draw(b, p).render() for p in poses] for anim, poses in beasts.ANIMS.items()}


def _sheets() -> dict[str, dict[str, list[Image.Image]]]:
    return {
        "aswang_dog": _beast(beasts.DOG),
        "aswang_pig": _beast(beasts.PIG),
        "sigbin": _beast(beasts.SIGBIN),
        "tikbalang": {a: [giants.draw(giants.TIKBALANG, st).render() for st in poses] for a, poses in giants.TIKBALANG_ANIMS.items()},
        "bungisngis": {a: [giants.draw_bungisngis(st).render() for st in poses] for a, poses in giants.BUNGISNGIS_ANIMS.items()},
        "kapre": {a: kapre.frames(a) for a in kapre.ANIMS},
        "kapre_smoke": {"idle": kapre.smoke()},
        "kapre_cigar": {"idle": [kapre.cigar()]},
        "manananggal_upper": {a: [fliers.manananggal_upper(l, r).render() for l, r in poses] for a, poses in fliers.MANANANGGAL_ANIMS.items()},
        "wakwak": {a: [fliers.wakwak(l, d).render() for l, d in poses] for a, poses in fliers.WAKWAK_ANIMS.items()},
        "tiktik": {a: [fliers.tiktik(l).render() for l in poses] for a, poses in fliers.TIKTIK_ANIMS.items()},
        "tiyanak": {
            "idle": [small.tiyanak_bundle(0.0).render(), small.tiyanak_bundle(1.0, 1).render()],
            "true": [small.tiyanak_true(0.0).render(), small.tiyanak_true(0.5).render()],
            "run": [small.tiyanak_true(k / 4, run=True).render() for k in range(4)],
        },
        "manananggal_lower": {
            "idle": [small.manananggal_lower().render()],
            "death": [small.manananggal_lower(k / 3).render() for k in (1, 2, 3)],
        },
        "santelmo": {
            "idle": [small.santelmo(k / 4).render() for k in range(4)],
            "hot": [small.santelmo(k / 4, hot=1.0).render() for k in range(4)],
        },
        "kapre_tree": {
            "idle": [small.balete().render()],
            "felled": [small.balete(True).render()],
        },
        "nuno_mound": {
            "idle": [small.nuno_mound(0.0).render()],
            "peek": [small.nuno_mound(1.0).render()],
        },
    }


def strips() -> dict[str, Image.Image]:
    out = {}
    for kind, anims in _sheets().items():
        for anim, frames in anims.items():
            w, h = frames[0].size
            if w != h and len(frames) == 1:
                out[f"{kind}_{anim}"] = frames[0]
                continue
            size = max(w, h)
            fitted = []
            for f in frames:
                canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
                x = (size - w) // 2
                y = size - h if kind in GROUND else (size - h) // 2
                canvas.paste(f, (x, y))
                fitted.append(canvas)
            out[f"{kind}_{anim}"] = row(fitted)
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true", help="compare, do not write")
    args = ap.parse_args()
    pictures = pixelart.Pictures(args.check, ROOT)
    made = strips()
    for name, image in made.items():
        pictures.put(image, OUT / f"{name}.png")
    if args.check:
        if pictures.stale:
            print("stale or missing:\n  " + "\n  ".join(pictures.stale))
            return 1
        print(f"OK: {len(made)} creature strips are current")
        return 0
    print(f"wrote {len(made)} strips to {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
