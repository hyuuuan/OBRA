"""Scaffolding: the button click, remade (Kent, 2026-11-15: "i dont like how the sound effect for
clicking buttons for everything"). Take 1 was a 25% pulse on B5 over a glint of short-mode noise:
a thin high pulse and bright noise, the two things his ear has turned down every time.

Candidates, all short, soft, and low enough not to cut:
  A  pop   -- a 50% pulse on E4 dropping a fourth in four ticks, no noise
  B  bell  -- the VRC7 soft bell (the game's kulintang) tapped on D5 and damped at once
  C  tok   -- the VRC7 piano struck on E4 and cut after two ticks: a small wooden knock
  D  felt  -- A's pop over two ticks of dark long-mode noise, a fingertip on felt
Take 2 of the candidates (Kent, 2026-11-15, on C: "the clicking sound sounds like a fart"): a low
note cut short buzzes, and a pitch that drops blats. So high, clean and still -- no low end, no
drop:
  E  tink  -- the VRC7 soft bell (the game's kulintang) on A5, damped after two ticks
  F  glass -- the VRC7 vibraphone on E6, damped after two ticks
  G  tick  -- a 50% pulse on C6 for three ticks, no noise

E ships (Kent, 2026-11-15: "i think this one is better, yeah we go with this"): its output
ui_click_E.txt is audio/sfx/ui_click.txt.

    compose_ui_click.py TOOLS_DIR OUT_DIR [A|B|C|D|E|F|G ...]
"""
import sys
from pathlib import Path

sys.path.insert(0, sys.argv[1])
from famitext import Song  # noqa: E402

OUT = Path(sys.argv[2])
WANT = sys.argv[3:] or ["A", "B", "C", "D", "E", "F", "G"]


def click(variant: str) -> str:
    s = Song("ui_click", frames=1, rows=12, speed=1, loop_to=None, comments=(
        f"The button click, variant {variant}: short, soft, low; no thin pulse, no bright noise.",
    ))
    if variant in "AD":
        pop = s.inst_2a03("pop", volume=[4, 3, 2, 1, 1, 0], arpeggio=[0, -1, -3, -5], duty=[2])
        s.put("pulse1", 0, 0, "E4", pop, 15, "V02")
    if variant == "D":
        felt = s.inst_2a03("felt", volume=[2, 1, 1, 0], duty=[0])
        s.put("noise", 0, 0, "4-#", felt, 15)
    if variant == "B":
        bell = s.inst_vrc7("tap", patch=9)
        s.put("fm1", 0, 0, "D5", bell, 12)
        s.put("fm1", 0, 3, "===")
    if variant == "C":
        tok = s.inst_vrc7("tok", patch=3)
        s.put("fm1", 0, 0, "E4", tok, 12)
        s.put("fm1", 0, 2, "===")
    if variant == "E":
        tink = s.inst_vrc7("tink", patch=9)
        s.put("fm1", 0, 0, "A5", tink, 12)
        s.put("fm1", 0, 2, "===")
    if variant == "F":
        glass = s.inst_vrc7("glass", patch=11)
        s.put("fm1", 0, 0, "E6", glass, 10)
        s.put("fm1", 0, 2, "===")
    if variant == "G":
        tick = s.inst_2a03("tick", volume=[4, 3, 1, 0], duty=[2])
        s.put("pulse1", 0, 0, "C6", tick, 15, "V02")
    s._set(0, 11, "dpcm", 3, "C00")
    return s.text()


for variant in WANT:
    (OUT / f"ui_click_{variant}.txt").write_text(click(variant))
print("wrote", ", ".join(WANT))
