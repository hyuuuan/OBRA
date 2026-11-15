"""Scaffolding: Piyesta's plaza and dance music, v4 -- tribal and upbeat: drums, trumpets, gongs.

Kent, 2026-11-15, on v3: "the actual sinulog song has a tribal and upbeat vibe (drums, trumpets,
gongs)". He chose original music over using the recording (it is copyrighted and the repo is
public). So this is original, written on what was measured from the recording he supplied --
rhythm, band balance and the beat-two hole only, no melody taken:

- 145 BPM; the big drum on beat one and three and the sixteenth before the bar, lighter drums
  on 5, 11 and 12; snare and hats on the off-sixteenths (v3 matched these 0.98 and 0.83).
- Nearly all the energy at 60-120 Hz: a drum corps, so the tambol is the loudest thing.
- Beat two is a hole: everything stops there, 16-18 dB under the bar's top.

New in v4, from his words: gongs (an agong that rings, a kulintang figure on the offbeats),
tribal tom rolls into every phrase, and the trumpets as a two-part fanfare.

    compose_piyesta.py TOOLS_DIR PLAZA.txt DANCE.txt
"""
import sys
from pathlib import Path

sys.path.insert(0, sys.argv[1])
from famitext import Song  # noqa: E402

BAR = 16
KICK = (0, 8, 15)
LOW_TOM = (5, 11, 12)
SNARE_ACCENT = (7, 11, 13, 15)
SNARE_GHOST = (2, 5, 9, 10)
HATS = (1, 3)
HOLE = 4                                # beat two: the recording stops here
# ⚠ The VRC7 has ONE custom patch, and it is the tambol: nothing else here may use one.
BOOM = (0x01, 0x01, 0x18, 0x04, 0xF8, 0xF5, 0xF8, 0x36)

NOTES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


def midi(note: str) -> int:
    return NOTES.index(note[:-1]) + 12 * (int(note[-1]) + 1)


def name(m: int) -> str:
    return f"{NOTES[m % 12]}{m // 12 - 1}"


def kit(song: Song) -> dict:
    return {
        "boom": song.inst_vrc7("tambol", patch=0, regs=BOOM),
        "snare": song.inst_2a03("snare", volume=[14, 11, 8, 6, 4, 2, 1, 0], duty=[0]),
        "ghost": song.inst_2a03("ghost", volume=[6, 4, 3, 2, 1, 0], duty=[0]),
        "hat": song.inst_2a03("hat", volume=[8, 3, 1, 0], duty=[0]),
        "bass": song.inst_vrc7("bass", patch=13),
        "trumpet": song.inst_vrc7("trumpet", patch=7),
        # The soft bell: of the bell patches the darkest (2.3 kHz at A4, against 4.8-6.4 kHz for
        # the bell, rattling bell and xylophone), and it rings like struck bronze.
        "kulintang": song.inst_vrc7("kulintang", patch=9),
        "agong": song.inst_vrc7("agong", patch=9),
        "crowd": song.inst_vrc7("crowd", patch=15),
    }


# --- the drums -----------------------------------------------------------------------------------

def snares(song: Song, k: dict, frame: int, row: int) -> None:
    for step in SNARE_ACCENT:
        song.put("noise", frame, row + step, "5-#", k["snare"], 11)
    for step in SNARE_GHOST:
        song.put("noise", frame, row + step, "6-#", k["ghost"], 11)
    for step in HATS:
        song.put("noise", frame, row + step, "A-#", k["hat"], 6)


def booms(song: Song, k: dict, frame: int, row: int, *, toms: bool = True) -> None:
    for step in KICK:
        # ⚠ The pickup is cut short (S03), or it is still ringing at beat one and swallows it.
        song.put("fm6", frame, row + step, "A2", k["boom"], 15, "S03" if step == 15 else None)
    if toms:
        for step in LOW_TOM:
            song.put("fm6", frame, row + step, "G2", k["boom"], 14)


def groove(song: Song, k: dict, frame: int, row: int) -> None:
    booms(song, k, frame, row)
    snares(song, k, frame, row)


# The drum corps' roll into the next phrase: the toms walking down in sixteenths from beat three,
# the snare climbing under them. It replaces the bar's second half.
FILL = ["D3", "D3", "C3", "C3", "A2", "A2", "G2", "E2"]


def fill(song: Song, k: dict, frame: int, row: int) -> None:
    for i, note in enumerate(FILL):
        song.put("fm6", frame, row + 8 + i, note, k["boom"], 12 + i // 3)
        song.put("noise", frame, row + 8 + i, "5-#", k["snare"], 6 + i // 2 * 2)


# "Pit Senyor!": the crowd shouts back at the trumpets' call, with the toms, three syllables.
SHOUT = {"Dm": ("D5", "D5", "F5"), "Am": ("C5", "C5", "E5"), "E": ("B4", "B4", "E5")}


def shout(song: Song, k: dict, frame: int, row: int, chord: str) -> None:
    for start in (5, 12):
        for i, note in enumerate(SHOUT[chord]):
            song.put("fm3", frame, row + start + i, note, k["crowd"], 11, "S03" if i == 2 else None)


# The tribal answer: the toms reply to a trumpet call, three strokes after each half's call.
def answer_toms(song: Song, k: dict, frame: int, row: int) -> None:
    for step, note in ((5, "D3"), (6, "C3"), (7, "A2"), (12, "D3"), (13, "C3"), (14, "A2")):
        song.put("fm6", frame, row + step, note, k["boom"], 13)


# A busier drum line for the tribal section: the toms talk in sixteenths, still silent on beat two.
TRIBAL = [(0, "A2", 15), (2, "D3", 12), (3, "D3", 12), (5, "G2", 14), (6, "G2", 12), (8, "A2", 15),
          (10, "D3", 12), (11, "C3", 13), (12, "C3", 13), (14, "G2", 12), (15, "A2", 15)]


def tribal(song: Song, k: dict, frame: int, row: int) -> None:
    for step, note, vol in TRIBAL:
        song.put("fm6", frame, row + step, note, k["boom"], vol, "S03" if step in (3, 15) else None)
    snares(song, k, frame, row)


# --- harmony: bass, gongs -----------------------------------------------------------------------

BASS = {"Am": [(0, "A2"), (5, "A3"), (8, "A2"), (11, "C3"), (12, "D3"), (15, "E3")],
        "G": [(0, "G2"), (5, "G3"), (8, "G2"), (11, "B2"), (12, "C3"), (15, "D3")],
        "Dm": [(0, "D3"), (5, "D4"), (8, "D3"), (11, "F3"), (12, "G3"), (15, "A2")],
        "E": [(0, "E2"), (5, "E3"), (8, "E2"), (11, "G#2"), (12, "A2"), (15, "B2")]}
BASS_VOL = 11


def bass(song: Song, k: dict, frame: int, row: int, chord: str) -> None:
    for step, note in BASS[chord]:
        song.put("fm5", frame, row + step, note, k["bass"], BASS_VOL)
    song.put("fm5", frame, row + 3, "===")                        # the bass leaves beat two, too


# The kulintang: small gongs in an interlocking figure on the offbeats. ⚠ DAMPED after two rows,
# so they never pile up -- the Terraces lesson: a held bell rang 3.9 s and everything overlapped.
KULINTANG = {"Am": [(1, "E5"), (3, "D5"), (6, "C5"), (9, "E5"), (11, "D5"), (14, "A4")],
             "G": [(1, "D5"), (3, "B4"), (6, "G4"), (9, "D5"), (11, "B4"), (14, "G4")],
             "Dm": [(1, "F5"), (3, "D5"), (6, "A4"), (9, "F5"), (11, "D5"), (14, "C5")],
             "E": [(1, "E5"), (3, "B4"), (6, "G#4"), (9, "E5"), (11, "B4"), (14, "G#4")]}


def kulintang(song: Song, k: dict, frame: int, row: int, chord: str, vol: int = 9) -> None:
    for step, note in KULINTANG[chord]:
        song.put("fm3", frame, row + step, note, k["kulintang"], vol)
        # ...and the one on step 3 after a single row, so beat two stays a hole.
        cut = HOLE if step < HOLE < step + 2 else step + 2
        if cut < BAR:
            song.put("fm3", frame, row + cut, "===")


# The agong: the big gong on the chord's root, low, struck with the big drum. ⚠ DAMPED ON BEAT
# TWO: left to ring (v4's first take) it filled the hole the recording leaves there -- the mids on
# step 4 came up from -19 dB to -8. A stroke on beat three rings to the pickup.
AGONG = {"Am": "A2", "G": "G2", "Dm": "D3", "E": "E2"}


def agong(song: Song, k: dict, frame: int, row: int, chord: str, vol: int = 11, ring: int = HOLE) -> None:
    song.put("fm4", frame, row, AGONG[chord], k["agong"], vol)
    song.put("fm4", frame, row + ring, "===")


# --- the trumpets: a two-part fanfare ------------------------------------------------------------

SCALE = {"Am": (9, 11, 0, 2, 4, 5, 7), "G": (9, 11, 0, 2, 4, 5, 7), "Dm": (9, 11, 0, 2, 4, 5, 7),
         "E": (9, 11, 0, 2, 4, 5, 8)}          # over E the G is sharpened: A harmonic minor


def third_below(note: str, chord: str) -> str:
    m, found = midi(note), 0
    while found < 2:
        m -= 1
        found += (m % 12) in SCALE[chord]
    return name(m)


def brass(song: Song, k: dict, frame: int, row: int, notes, chord: str, lead: int = 13,
          second: int = 12) -> None:
    """The fanfare: the lead on fm1, the second trumpet a third under it on fm2."""
    for item in notes:
        note, length = item[0], item[1]
        fx = item[2] if len(item) > 2 else None
        if note == "r":
            song.put("fm1", frame, row, "===")
            song.put("fm2", frame, row, "===")
        else:
            song.put("fm1", frame, row, note, k["trumpet"], lead, fx)
            song.put("fm2", frame, row, third_below(note, chord), k["trumpet"], second, fx)
        row += length


# ⚠ BEAT TWO IS A HOLE in every bar of the tune: a staccato hit on step 3 (S03: cut after three
# ticks, or its release rings into the hole), a rest on 4. The recording stops there.
FANFARE = [
    [("A5", 2), ("G5", 1), ("E5", 1, "S03"), ("r", 1), ("A5", 3), ("G5", 2), ("E5", 1), ("G5", 2), ("A5", 3)],
    [("A5", 3), ("G5", 1, "S03"), ("r", 1), ("E5", 3), ("D5", 2), ("E5", 2), ("r", 2), ("C5", 1), ("D5", 1)],
    [("E5", 2), ("G5", 1), ("A5", 1, "S03"), ("r", 1), ("C6", 3), ("A5", 2), ("G5", 1), ("A5", 2), ("E5", 3)],
    [("D5", 3), ("C5", 1, "S03"), ("r", 1), ("A4", 3), ("C5", 2), ("D5", 2), ("A4", 4)],
]
FANFARE_CHORDS = ["Am", "G", "Am", "Am"]
# The fiesta band's ending: the last bar climbs to a held A and shakes it (4A4, a wide fast
# vibrato, as a banda trumpet does), over the roll back to the top. ⚠ The vibrato stays on the
# channel until a 400 clears it: the fanfare's first note carries one.
FANFARE[0][0] = ("A5", 2, "400")
SHAKE_BAR = [("C5", 3), ("D5", 1, "S03"), ("r", 1), ("E5", 2), ("G5", 1), ("A5", 8, "4A4")]
PICKUP = [("r", 8), ("A4", 2), ("C5", 2), ("D5", 2), ("E5", 1), ("G5", 1)]
# The call and its answer: the trumpets cry out on beat one and three ("Pit Senyor!"), the toms
# and the gongs reply in the gaps.
CALLS = [
    [("D5", 1), ("D5", 1), ("A5", 1, "S03"), ("r", 5), ("F5", 1), ("F5", 1), ("D5", 2), ("r", 4)],
    [("E5", 1), ("E5", 1), ("A5", 1, "S03"), ("r", 5), ("C6", 1), ("C6", 1), ("A5", 2), ("r", 4)],
    [("F5", 1), ("F5", 1), ("D6", 1, "S03"), ("r", 5), ("A5", 1), ("A5", 1), ("F5", 2), ("r", 4)],
    [("B4", 2), ("E5", 1), ("G#5", 1, "S03"), ("r", 1), ("B5", 3), ("A5", 2), ("G#5", 2), ("E5", 3), ("r", 1)],
]
CALL_CHORDS = ["Dm", "Am", "Dm", "E"]
TRIBAL_CHORDS = ["Am", "Am", "Dm", "E"]
STABS = {"Am": "E5", "Dm": "F5", "E": "G#5", "G": "D5"}


for bars in (FANFARE, CALLS, [SHAKE_BAR]):
    assert all(sum(n[1] for n in bar) == BAR for bar in bars), "a bar of the tune is not 16 rows"

# --- the plaza: 144 BPM (25 ticks a beat, the nearest the engine's frames give to 145) ---------------
plaza = Song("Piyesta", frames=5, rows=64, speed=6, loop_to=1, comments=(
    "Piyesta's plaza: a Sinulog drum corps -- tambol, snares, toms -- with agong and kulintang",
    "gongs and two trumpets. On the Sinulog theme's groove; original tune. A minor, ~144 BPM.",
))
for frame in range(5):
    for row in range(64):
        plaza._set(frame, row, "dpcm", 3, "F07" if row % 4 == 3 else "F06")   # 6+6+6+7 = 25 a beat
P = kit(plaza)

# Frame 0, the gathering: the agong and the big drum alone, then the toms and the kulintang, then
# the whole corps, and a roll with the trumpets climbing into the fanfare.
agong(plaza, P, 0, 0, "Am", 13, ring=12)          # the opening stroke rings out
booms(plaza, P, 0, 0, toms=False)
booms(plaza, P, 0, BAR)
kulintang(plaza, P, 0, BAR, "Am", 9)
for bar in (2, 3):
    groove(plaza, P, 0, bar * BAR)
    kulintang(plaza, P, 0, bar * BAR, "Am")
    bass(plaza, P, 0, bar * BAR, "Am")
agong(plaza, P, 0, 2 * BAR, "Am")
fill(plaza, P, 0, 3 * BAR)
brass(plaza, P, 0, 3 * BAR, PICKUP, "Am")

# Frames 1 and 4: the fanfare over the full corps; frame 4 ends in a roll back to frame 1.
# Frame 4 is the lift: the same fanfare over the tribal drums, a gong every bar, the shake to end.
for frame in (1, 4):
    for bar, chord in enumerate(FANFARE_CHORDS):
        row = bar * BAR
        (tribal if frame == 4 else groove)(plaza, P, frame, row)
        bass(plaza, P, frame, row, chord)
        kulintang(plaza, P, frame, row, chord)
        if bar % 2 == 0 or frame == 4:
            agong(plaza, P, frame, row, chord)
        brass(plaza, P, frame, row, SHAKE_BAR if (frame, bar) == (4, 3) else FANFARE[bar], chord)
    if frame == 4:
        fill(plaza, P, frame, 3 * BAR)

# Frame 2: call and answer -- the trumpets cry, the crowd and the toms shout back, the gong rings.
for bar, chord in enumerate(CALL_CHORDS):
    row = bar * BAR
    groove(plaza, P, 2, row)
    answer_toms(plaza, P, 2, row)
    bass(plaza, P, 2, row, chord)
    shout(plaza, P, 2, row, chord)
    agong(plaza, P, 2, row, chord)
    brass(plaza, P, 2, row, CALLS[bar], chord)

# Frame 3: the tribal section -- drums and gongs carry it, the trumpets only stab the accents.
for bar, chord in enumerate(TRIBAL_CHORDS):
    row = bar * BAR
    tribal(plaza, P, 3, row)
    bass(plaza, P, 3, row, chord)
    kulintang(plaza, P, 3, row, chord, 12)
    agong(plaza, P, 3, row, chord, 13)
    for step in (7, 13):
        brass(plaza, P, 3, row + step, [(STABS[chord], 1, "S03")], chord, 12, 10)
fill(plaza, P, 3, 3 * BAR)
Path(sys.argv[2]).write_text(plaza.text())

# --- the dance: 120 BPM, so its cues (every 1.0 s) fall on the big drum's beats one and three -----
# ⚠ LOCKED TO THE DANCE'S CUES (see test_piyesta_dance_music): the cues are due 2.6 .. 7.6 s into
# this music. A 0.6 s pickup (four rows of nine ticks) and 30-tick beats put each on a beat-one or
# beat-three boom, with the trumpets and the agong struck on it.
dance = Song("Sayaw", frames=1, rows=4 + 5 * BAR, speed=8, loop_to=0, comments=(
    "Piyesta's dance: the plaza's drum corps and gongs, its booms on the minigame's cues. Original.",
    "120 BPM.",
))
D = kit(dance)
for row in range(4):
    dance._set(0, row, "dpcm", 3, "F09")
for row in range(4, 4 + 5 * BAR):
    dance._set(0, row, "dpcm", 3, "F08" if (row - 4) % 2 == 0 else "F07")
for step, vol in zip((0, 1, 2, 3), (7, 9, 11, 13)):
    dance.put("noise", 0, step, "6-#", D["ghost"], vol - 2)
CUE_HITS = ("A4", "C5", "D5", "C5", "E5", "A5")
DANCE_CHORDS = ["Am", "Dm", "Am", "Dm", "E"]


# ⚠ THE DANCE'S DRUMS POINT AT THE CUES. Each cue is the big drum on beat one or three, and three
# tom strokes run up into it (steps 5-7 and 13-15), so a player hears it coming. The plaza's toms
# on 11 and 12 would land between the cues and blur them, so the dance has none.
def run_up(song: Song, k: dict, frame: int, row: int, starts=(5, 13)) -> None:
    for start in starts:
        for i, note in enumerate(("D3", "C3", "A2")):
            song.put("fm6", frame, row + start + i, note, k["boom"], 11 + i, "S03" if i == 2 else None)


for bar, chord in enumerate(DANCE_CHORDS):
    row = 4 + bar * BAR
    kulintang(dance, D, 0, row, chord, 10)
    snares(dance, D, 0, row)
    if bar == 0:
        # The count-in: the corps' four beats, the gong, and the run-up into the first cue.
        for step in (0, 4, 8):
            dance.put("fm6", 0, row + step, "A2", D["boom"], 14)
        agong(dance, D, 0, row, chord, 11)
        run_up(dance, D, 0, row, (13,))
        continue
    bass(dance, D, 0, row, chord)
    if bar <= 3:                                  # the cues: the big drum, trumpets and the agong
        for half in (0, 1):
            step = 8 * half
            fx = "400" if (bar, half) == (1, 0) else None          # clears the last pass's shake
            dance.put("fm6", 0, row + step, "A2", D["boom"], 15)
            brass(dance, D, 0, row + step, [(CUE_HITS[2 * (bar - 1) + half], 3, fx), ("r", 1)], chord, 14, 10)
            agong(dance, D, 0, row + step, chord, 10, HOLE if half == 0 else 7)   # under 0 dBFS: all of it lands on a cue
        # After the last cue there is nothing to run up into: the minigame is over.
        run_up(dance, D, 0, row, (5, 13) if bar < 3 else (5,))
    else:
        # The ending: the band climbs and shakes its top note over the roll.
        booms(dance, D, 0, row, toms=False)
        brass(dance, D, 0, row, [("E5", 2), ("G#5", 2), ("B5", 8, "4A4"), ("r", 4)], chord, 13, 11)
        fill(dance, D, 0, row)
Path(sys.argv[3]).write_text(dance.text())
print("wrote", sys.argv[2], "and", sys.argv[3])
