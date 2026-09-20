#!/usr/bin/env python3
"""Author the one Dagat prop the delivery does not contain: the ink jar on the seabed.

WHY THIS EXISTS
---------------
The refills are the only thing keeping a long crossing payable, and they had no art -- they
were purple diamonds. The delivered underwater CompletedLook DOES have them in it: pale jars
with a dark cap and a blue drop on the front, standing on the terraces. They are painted into
that plate rather than shipped as a sprite, so this draws one, in the same idiom the rest of
the project's authored art uses (tools/pixelart.py: a logical pixel grid, short ramps, ordered
dither, light from the upper left).

THREE FRAMES, AND THE ONLY THING THAT MOVES IS THE GLOW. A pickup that animates its shape
reads as alive and asks to be looked at; this one has to read as a thing left on the seabed
that happens to still have something in it.

USAGE
    python3 tools/build_dagat_props.py            # write game/assets/Level3/props/
    python3 tools/build_dagat_props.py --check    # verify the committed files are current
"""

from __future__ import annotations

import argparse
import hashlib
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import pixelart
from pixelart import Canvas, ramp

ROOT = Path(__file__).resolve().parent.parent
# ⚠ ITS OWN DIRECTORY, AND THE REASON IS OWNERSHIP. build_dagat.py rmtree's everything it
# generates before it rebuilds -- correct for a pipeline, and fatal if a second tool writes
# into the same folders. It wrote the jar into props/ once and the next --check deleted it.
# A directory nothing else touches makes that impossible rather than merely unlikely.
OUT = ROOT / "game" / "assets" / "Level3" / "authored"

# Read off the delivered plate so the jar belongs to the picture it stands in.
GLASS = ramp(["#6f7f86", "#93a4a8", "#b9c6c4", "#dbe3dc", "#f1f4ea"])
CAP = ramp(["#2a1d16", "#3d2b20", "#55392a", "#6d4a36"])
DROP = ramp(["#0e3f66", "#1667a4", "#2b95d6", "#71c8ef"])
GLOW = ramp(["#1667a4", "#2b95d6", "#71c8ef", "#bdeaff"])

W, H = 20, 30
FRAMES = 3


def draw(frame: int) -> Canvas:
    # PX=3 rather than the library default of 2: this sits in a scene drawn at a much finer
    # grain than Piyesta's interiors, and at 2 the jar reads as a different game's prop.
    pixelart.PX = 3
    c = Canvas(W, H, seed=1703 + frame)

    # The glow behind it, which is the only thing that changes between frames.
    reach = [3, 4, 5][frame]
    for step in range(reach):
        tone = GLOW[max(0, 1 - step // 2)].copy()
        tone[3] = 30 - step * 5
        c.fill(4 - step, 9 - step, 12 + step * 2, 17 + step * 2, tone)

    # The jar: a straight-sided vessel, lit from the upper left.
    c.fill(5, 10, 10, 16, GLASS[2])
    # ⚠ A GRADIENT AMOUNT, NOT A CONSTANT. A flat 0.45 dithers the whole face at one rate,
    # which is a checkerboard rather than a curved surface -- the ordered dither only reads
    # as a cylinder when the mix varies across it, bright on the lit side and dark on the
    # shaded one.
    import numpy as np
    across = np.linspace(0.92, 0.08, 10)[None, :].repeat(16, axis=0)
    c.dither(5, 10, 10, 16, GLASS[1], GLASS[3], across)
    c.vline(5, 10, 16, GLASS[4])          # lit edge
    c.hline(5, 10, 10, GLASS[4])
    c.vline(14, 10, 16, GLASS[0])         # shaded edge
    c.hline(5, 25, 10, GLASS[0])

    # The cap, and the neck under it.
    c.fill(6, 6, 8, 4, CAP[2])
    c.hline(6, 6, 8, CAP[3])
    c.hline(6, 9, 8, CAP[0])
    c.fill(7, 4, 6, 2, CAP[1])

    # The drop on the front, brighter as the glow swells.
    lit = DROP[min(3, 2 + frame // 2)]
    c.fill(9, 15, 2, 5, lit)
    c.fill(8, 17, 4, 3, lit)
    c.px(8, 16, DROP[1])
    c.px(11, 16, DROP[1])
    c.px(9, 14, DROP[3])

    # A few motes rising off it, so a still prop still has something happening.
    c.speckle(6, 2 + frame, 8, 4, GLOW[3], 0.07)
    return c


def build() -> list[Path]:
    OUT.mkdir(parents=True, exist_ok=True)
    written = []
    for frame in range(FRAMES):
        path = OUT / f"ink_jar_{frame}.png"
        draw(frame).save(path)
        written.append(path)
    return written


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    before = {}
    if args.check:
        for frame in range(FRAMES):
            path = OUT / f"ink_jar_{frame}.png"
            if not path.exists():
                print(f"{path} does not exist -- run tools/build_dagat_props.py", file=sys.stderr)
                return 1
            before[path] = hashlib.sha256(path.read_bytes()).hexdigest()

    written = build()
    if args.check:
        stale = [p for p in written
                 if hashlib.sha256(p.read_bytes()).hexdigest() != before.get(p)]
        if stale:
            print("stale, rebuilt: " + ", ".join(p.name for p in stale), file=sys.stderr)
            return 1
        print(f"{len(written)} authored props are up to date")
        return 0
    print(f"Wrote {len(written)} frames to {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
