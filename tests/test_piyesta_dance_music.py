"""audio/music/dance.txt: Piyesta's dance music strikes where the minigame's cues are.

The minigame scores a stroke against its cues (level_2.gd `dance_track`, seconds on the overlay's
clock), and that clock starts at -LEAD_IN (dance_overlay.gd), the moment the overlay starts this
music. So each cue is due LEAD_IN + cue seconds into the music, and the music's big strike -- the
brass hit on the tambol and agong -- must be there. Both numbers are read from the game's own
code: change the dance and this fails until the music is written onto it again.
"""

from __future__ import annotations

import re
import sys
import unittest
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import famirender as fr  # noqa: E402

# Within this, a strike is on the beat. The minigame's "perfect" window is 0.18 s either side.
TOLERANCE_S = 0.04
BRASS_CHANNEL = 5          # fm1, which plays the cue strikes
SPEED_CHANNEL = 4          # dpcm, whose effect columns carry the speed and the loop


def cues() -> list[float]:
    source = (ROOT / "game/scripts/level_2.gd").read_text()
    track = re.search(r"var dance_track := PackedFloat32Array\(\[([^\]]*)\]\)", source)
    return [float(v) for v in track.group(1).split(",")]


def lead_in() -> float:
    source = (ROOT / "game/scripts/dance_overlay.gd").read_text()
    return float(re.search(r"const LEAD_IN := ([0-9.]+)", source).group(1))


def strikes() -> list[float]:
    lines = []
    for line in (ROOT / "audio/music/dance.txt").read_text().splitlines():
        if line.startswith("ROW "):
            head, *cells = line.split(" : ")
            empty = "... .. . ..."
            line = " : ".join([head] + [c if i in (BRASS_CHANNEL, SPEED_CHANNEL) else empty
                                        for i, c in enumerate(cells)])
        lines.append(line)
    result = fr.render(fr.parse_module("\n".join(lines)))
    x = np.abs(result.samples[: result.loop_start])        # the first pass: what an attempt hears
    window = int(0.002 * result.rate)
    env = x[: len(x) // window * window].reshape(-1, window).max(axis=1)
    found, armed = [], True
    for index, level in enumerate(env):
        if armed and level > env.max() * 0.3:
            found.append(index * window / result.rate)
            armed = False
        elif level < env.max() * 0.05:
            armed = True
    return found


class DanceMusicTest(unittest.TestCase):
    def test_every_cue_has_a_strike_on_it(self) -> None:
        due = [lead_in() + cue for cue in cues()]
        heard = strikes()
        self.assertGreaterEqual(len(heard), len(due), f"strikes at {heard}")
        for cue, strike in zip(due, heard):
            self.assertAlmostEqual(strike, cue, delta=TOLERANCE_S,
                                   msg=f"a strike at {strike:.3f} s for the cue due at {cue:.3f} s")


if __name__ == "__main__":
    unittest.main()
