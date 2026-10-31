"""Simulated players of different skill, playing a session through the real gate.

The correction experiment (docs/CORRECTION_EXPERIMENT.md) used TU-Berlin as its "player",
which is a crowd of drawers, not one person. A real player has a PERSONAL STYLE -- a slant,
a squash, a heavy or light hand -- that every one of their drawings shares, plus noise that
depends on their skill. A per-player memory can only learn the first, so this simulates both.

A PLAYER is
  * a style, fixed for the whole session: rotation, shear, aspect and stroke weight, drawn
    once at random within their skill level's range;
  * per-drawing noise from their skill: wobble (an elastic warp), unfinished strokes
    (erased patches), and stray marks;
  * a chance of answering "which did you mean?" wrongly.

Skill levels (and what each means on the page):
  expert    a light, steady style; clean drawings
  average   a noticeable style; some wobble, sometimes an unfinished stroke
  beginner  a strong style; heavy wobble, unfinished strokes, stray marks
  careless  an average style, but rushed: often unfinished, often stray marks, and more
            likely to pick the wrong answer when asked

A SESSION is 300 drawings, 6 of each of the 50 classes in a random order. Each is attempted
up to 3 times. Every attempt goes through the real gate (confidence >= 0.60, margin >= 0.15):
  * accepted and right      -- success, the next drawing
  * accepted and wrong      -- the worst outcome: the wrong thing appears
  * declined                -- with the memory on, if the right class is among the model's top
                               two, the player is asked "which did you mean?" and answers
                               (possibly wrongly); the answer teaches the memory but NEVER
                               passes the drawing -- they still redraw. Then the next attempt.
All conditions see the identical drawings:
  FROZEN   the shipped model.
  MEMORY   the prototype memory from the correction experiment, lambda 0.5, T 0.1 -- fixed
           before this was run, not tuned here.
  GATED    the same memory with a way to say "I don't know this one" (see read()). Added
           after MEMORY's first run, because MEMORY broke the gate; its one new setting is
           chosen on separate dev players, never on the players reported.

The base drawings are 200 per class that training never read (Quick, Draw! rows from 40,000,
fetched into model/data/quickdraw_unseen/ by fetch_unseen_quickdraw.py), so all 50 classes are
in play. A drawing is
rendered at 112 px, styled and noised there, and framed exactly as training framed it.

    python model/player_simulation.py --out model/player_simulation.json
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy.ndimage import gaussian_filter, map_coordinates

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent / "backend"))
from correction_experiment import Frozen, log_softmax  # noqa: E402
from preprocess import EmptyCanvasError, canonicalize_ink  # noqa: E402

GATE_CONFIDENCE, GATE_MARGIN = 0.60, 0.15
MEMORY_LAMBDA, MEMORY_TEMPERATURE = 0.5, 0.1  # from the correction experiment, not re-tuned
PER_CLASS, ATTEMPTS, PLAYERS_PER_SKILL = 6, 3, 20
RENDER = 112
DEV_PLAYERS = 10
OUTLET_GRID = (0.6, 0.7, 0.8, 0.85, 0.9, 0.95)
GATE_SWEEP = (0.5, 0.6, 0.65, 0.7, 0.75, 0.8, 0.9)
T_95_19DF = 2.093


@dataclass(frozen=True)
class Skill:
    name: str
    rotation: float      # degrees, the style's range
    shear: float
    aspect: float        # +/- around 1
    weights: tuple       # stroke weight steps a style may take
    wobble: float        # elastic warp strength, px at 112
    unfinished: float    # chance a drawing loses a patch of ink
    stray: float         # chance of a stray mark
    miscorrect: float    # chance of answering "which did you mean?" wrongly
    consistent: bool = True  # False: the style is re-drawn for every drawing (no personal style)


SKILLS = (
    Skill("expert", 8, 0.10, 0.10, (0,), 0.0, 0.0, 0.0, 0.0),
    Skill("average", 15, 0.20, 0.20, (-1, 0, 1), 3.0, 0.30, 0.10, 0.02),
    Skill("beginner", 25, 0.30, 0.30, (-1, 0, 1, 2), 6.0, 0.50, 0.30, 0.05),
    Skill("careless", 15, 0.20, 0.20, (-1, 0, 1), 3.0, 0.70, 0.40, 0.15),
)
# The control: average noise with NO personal style -- the style changes every drawing. If the
# memory's gain comes from learning a player's style, it should mostly vanish here.
CONTROL = Skill("average_no_style", 15, 0.20, 0.20, (-1, 0, 1), 3.0, 0.30, 0.10, 0.02, consistent=False)


@dataclass(frozen=True)
class Style:
    rotation: float
    shear: float
    aspect: float
    weight: int


def draw_style(skill: Skill, rng: np.random.Generator) -> Style:
    return Style(
        rotation=float(rng.uniform(-skill.rotation, skill.rotation)),
        shear=float(rng.uniform(-skill.shear, skill.shear)),
        aspect=float(1.0 + rng.uniform(-skill.aspect, skill.aspect)),
        weight=int(rng.choice(skill.weights)),
    )


def render(bitmap: np.ndarray, style: Style, skill: Skill, rng: np.random.Generator) -> np.ndarray:
    """A Quick, Draw! bitmap (white on black) as this player would draw it, framed like
    training's: (1, 28, 28) float32 in [0, 1]. Raises EmptyCanvasError if nothing is left."""
    image = Image.fromarray(bitmap.reshape(28, 28)).resize((RENDER, RENDER), Image.Resampling.BILINEAR)
    # Style: one affine about the centre, then a heavier or lighter hand.
    angle = math.radians(style.rotation)
    cos, sin = math.cos(angle), math.sin(angle)
    a, b = cos / style.aspect, -sin + style.shear
    d, e = sin / style.aspect, cos
    cx = cy = RENDER / 2
    image = image.transform((RENDER, RENDER), Image.Transform.AFFINE,
                            (a, b, cx - a * cx - b * cy, d, e, cy - d * cx - e * cy),
                            resample=Image.Resampling.BILINEAR)
    for _ in range(abs(style.weight)):
        image = image.filter(ImageFilter.MaxFilter(3) if style.weight > 0 else ImageFilter.MinFilter(3))
    arr = np.asarray(image, dtype=np.float32)
    # Skill: wobble, then unfinished strokes, then a stray mark.
    if skill.wobble > 0:
        dx = gaussian_filter(rng.uniform(-1, 1, arr.shape), 8) * skill.wobble * 8
        dy = gaussian_filter(rng.uniform(-1, 1, arr.shape), 8) * skill.wobble * 8
        y, x = np.mgrid[0:RENDER, 0:RENDER]
        arr = map_coordinates(arr, [y + dy, x + dx], order=1, mode="constant")
    if rng.random() < skill.unfinished:
        ys, xs = np.nonzero(arr > 32)
        if len(ys):
            i = rng.integers(len(ys))
            yy, xx = np.ogrid[0:RENDER, 0:RENDER]
            radius = rng.uniform(10, 20)
            arr[(yy - ys[i]) ** 2 + (xx - xs[i]) ** 2 < radius ** 2] = 0.0
    if rng.random() < skill.stray:
        canvas = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
        p = rng.uniform(10, RENDER - 10, 4)
        ImageDraw.Draw(canvas).line([(p[0], p[1]), (p[2], p[3])], fill=255, width=4)
        arr = np.asarray(canvas, dtype=np.float32)
    framed = canonicalize_ink(np.clip(arr, 0, 255))  # raises EmptyCanvasError on a blank page
    # Quantised as training's canonicalize_batch did before QuickDrawDataset's /255.
    return ((framed * 255.0).astype(np.uint8).astype(np.float32) / 255.0).reshape(1, 28, 28)


# --- the session --------------------------------------------------------------------------
def read(model: Frozen, emb: np.ndarray, memory: dict | None, outlet: float | None = None) -> np.ndarray:
    """Final probabilities for one drawing: the model's, blended with the memory if any.

    ⚠ THE PLAIN BLEND BREAKS THE GATE (MEMORY). Its share goes only to classes the player has
    corrected, so a drawing of any other class can reach at most ~(1 - lambda) of confidence --
    under the 0.60 gate at lambda 0.5 -- and is declined, which yields another correction, which
    pulls harder. Offline, scoring only the top answer, this never showed.

    GATED gives the memory an outlet: an "other" option scored as a cosine of `outlet`. A
    drawing that resembles no correction better than that puts the memory's share on "other",
    which is handed back to the uncorrected classes in the model's own proportions -- so the
    gate sees the model's own confidence wherever the memory has nothing to say."""
    p = np.exp(log_softmax((emb @ model.W.T + model.b)[None]))[0]
    if not memory:
        return p
    classes = sorted(memory)
    protos = np.stack([memory[c] / max(np.linalg.norm(memory[c]), 1e-9) for c in classes])
    unit = emb / max(np.linalg.norm(emb), 1e-9)
    sims = protos @ unit / MEMORY_TEMPERATURE
    if outlet is not None:
        sims = np.append(sims, outlet / MEMORY_TEMPERATURE)
    weights = np.exp(sims - sims.max())
    weights /= weights.sum()
    p_mem = np.zeros_like(p)
    p_mem[classes] = weights[:len(classes)]
    if outlet is not None:
        others = np.ones_like(p, dtype=bool)
        others[classes] = False
        if others.any() and p[others].sum() > 0:
            p_mem[others] += weights[-1] * p[others] / p[others].sum()
        else:
            p_mem[classes] += weights[-1] * p[classes] / max(p[classes].sum(), 1e-12)
    return (1.0 - MEMORY_LAMBDA) * p + MEMORY_LAMBDA * p_mem


def play(model: Frozen, intents: list, embeddings: dict, skill: Skill, use_memory: bool,
         rng: np.random.Generator, outlet: float | None = None,
         gate_confidence: float = GATE_CONFIDENCE) -> dict:
    """One session. `intents` is [(true class, [attempt keys])]; `embeddings` maps a key to
    its embedding (None if the drawing came out blank)."""
    memory: dict[int, np.ndarray] = {}  # class -> sum of unit embeddings (its prototype's direction)
    log = []
    for true_class, keys in intents:
        outcome = {"attempts": 0, "success": False, "wrong_accepts": 0, "corrections": 0,
                   "miscorrections": 0}
        for key in keys:
            emb = embeddings[key]
            outcome["attempts"] += 1
            if emb is None:
                continue  # a blank page: the game asks for a drawing; nothing learned
            p = read(model, emb, memory if use_memory else None, outlet)
            order = np.argsort(p)[::-1]
            confidence, margin = p[order[0]], p[order[0]] - p[order[1]]
            if confidence >= gate_confidence and margin >= GATE_MARGIN:
                if order[0] == true_class:
                    outcome["success"] = True
                    break
                outcome["wrong_accepts"] += 1
                continue
            # Declined. "Which did you mean?" -- only with the memory on, and only if the
            # right answer is one of the two offered. The answer teaches; it never passes.
            if use_memory and true_class in order[:2]:
                answer = true_class
                if rng.random() < skill.miscorrect:
                    answer = int(order[1] if order[0] == true_class else order[0])
                    outcome["miscorrections"] += 1
                unit = emb / max(np.linalg.norm(emb), 1e-9)
                memory[answer] = memory.get(answer, np.zeros_like(unit)) + unit
                outcome["corrections"] += 1
        log.append(outcome)
    return summarize_session(log)


def summarize_session(log: list) -> dict:
    n = len(log)
    attempts = sum(o["attempts"] for o in log)
    first_try = [o["success"] and o["attempts"] == 1 for o in log]
    third = n // 3
    return {
        "first_try_success": float(np.mean(first_try)),
        "success_within_3": float(np.mean([o["success"] for o in log])),
        "mean_attempts": attempts / n,
        "wrong_accepts_per_attempt": sum(o["wrong_accepts"] for o in log) / attempts,
        "corrections": int(sum(o["corrections"] for o in log)),
        "miscorrections": int(sum(o["miscorrections"] for o in log)),
        "first_try_success_first_third": float(np.mean(first_try[:third])),
        "first_try_success_last_third": float(np.mean(first_try[-third:])),
    }


def build_player(model: Frozen, bases: dict, skill: Skill, seed: int):
    """The player's whole session, drawn and embedded once so both conditions see the same
    drawings."""
    rng = np.random.default_rng(seed)
    style = draw_style(skill, rng)
    intents, tensors, keys = [], [], []
    plan = [(c, i) for c in range(len(bases)) for i in rng.choice(len(bases[c]), PER_CLASS, replace=False)]
    rng.shuffle(plan)
    for n, (c, i) in enumerate(plan):
        attempt_keys = []
        for attempt in range(ATTEMPTS):
            drawing_style = style if skill.consistent else draw_style(skill, rng)
            key = (n, attempt)
            attempt_keys.append(key)
            try:
                tensors.append(render(bases[c][i], drawing_style, skill, rng))
                keys.append(key)
            except EmptyCanvasError:
                pass
        intents.append((c, attempt_keys))
    embedded = model.embed(np.stack(tensors))
    embeddings = {key: None for _, ks in intents for key in ks}
    embeddings.update(dict(zip(keys, embedded)))
    return intents, embeddings, style


def ci(values) -> dict:
    arr = np.array(values, dtype=float)
    return {"mean": float(arr.mean()), "ci95": float(T_95_19DF * arr.std(ddof=1) / math.sqrt(len(arr)))}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", type=Path, default=HERE / "model.onnx")
    parser.add_argument("--bases", type=Path, default=HERE / "data" / "quickdraw_unseen")
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()

    model = Frozen(args.model)
    labels = json.loads((HERE / "labels.json").read_text())
    bases = {c: np.load(args.bases / f"{label}.npy") for c, label in enumerate(labels)}

    # GATED's one setting, chosen on DEV players (their own seeds, average skill) by first-try
    # success. The players reported below never take part in the choice.
    dev = [build_player(model, bases, SKILLS[1], 900_000 + p) for p in range(DEV_PLAYERS)]

    def dev_score(outlet):
        return float(np.mean([play(model, intents, emb, SKILLS[1], True,
                                   np.random.default_rng(900_000 + p + 1), outlet)["first_try_success"]
                              for p, (intents, emb, _) in enumerate(dev)]))

    dev_scores = {o: dev_score(o) for o in OUTLET_GRID}
    outlet = max(dev_scores, key=dev_scores.get)
    print("dev first-try success by outlet:", {k: round(v, 3) for k, v in dev_scores.items()},
          "-> chose", outlet)

    report = {"protocol": {"per_class": PER_CLASS, "classes": len(labels), "attempts": ATTEMPTS,
                           "players_per_skill": PLAYERS_PER_SKILL, "gate": [GATE_CONFIDENCE, GATE_MARGIN],
                           "memory": {"lambda": MEMORY_LAMBDA, "temperature": MEMORY_TEMPERATURE},
                           "gated_outlet": outlet,
                           "gated_outlet_dev_scores": {str(k): v for k, v in dev_scores.items()},
                           "dev_players": DEV_PLAYERS},
              "skills": {}}
    for skill in SKILLS + (CONTROL,):
        rows = {"frozen": [], "memory": [], "gated": []}
        players = []
        for p in range(PLAYERS_PER_SKILL):
            seed = 10_000 * (SKILLS + (CONTROL,)).index(skill) + p
            intents, embeddings, _ = build_player(model, bases, skill, seed)
            players.append((intents, embeddings, seed))
            for condition in rows:
                rows[condition].append(play(model, intents, embeddings, skill, condition != "frozen",
                                            np.random.default_rng(seed + 1),
                                            outlet if condition == "gated" else None))
        summary = {cond: {k: ci([r[k] for r in rs]) for k in rs[0]} for cond, rs in rows.items()}
        for condition in ("memory", "gated"):
            summary[f"paired_gain_first_try_{condition}"] = ci(
                [m["first_try_success"] - f["first_try_success"] for f, m in zip(rows["frozen"], rows[condition])])
            summary[f"paired_gain_wrong_accepts_{condition}"] = ci(
                [m["wrong_accepts_per_attempt"] - f["wrong_accepts_per_attempt"]
                 for f, m in zip(rows["frozen"], rows[condition])])
        report["skills"][skill.name] = summary
        f, m, g = summary["frozen"], summary["memory"], summary["gated"]

        def v(row, key):
            return row[key]["mean"]

        print(f"{skill.name:<17} first try {v(f, 'first_try_success'):.3f} | memory {v(m, 'first_try_success'):.3f} "
              f"| gated {v(g, 'first_try_success'):.3f} (gain {summary['paired_gain_first_try_gated']['mean']:+.3f} "
              f"+- {summary['paired_gain_first_try_gated']['ci95']:.3f}) || within 3 {v(f, 'success_within_3'):.3f} -> "
              f"{v(g, 'success_within_3'):.3f} | attempts {v(f, 'mean_attempts'):.2f} -> {v(g, 'mean_attempts'):.2f} "
              f"| wrong/attempt {v(f, 'wrong_accepts_per_attempt'):.3f} -> {v(g, 'wrong_accepts_per_attempt'):.3f} "
              f"| corrections {v(g, 'corrections'):.0f} | last third {v(f, 'first_try_success_last_third'):.3f} -> "
              f"{v(g, 'first_try_success_last_third'):.3f}")
        # THE GATE ITSELF, for the frozen model: what each confidence bar trades, per skill,
        # between a right answer first time and the wrong thing appearing. Evaluates the
        # shipped design (0.60, and the per-level bars 0.65-0.75); chooses nothing.
        sweep = {}
        for bar in GATE_SWEEP:
            runs = [play(model, intents, embeddings, skill, False, np.random.default_rng(seed + 1),
                         gate_confidence=bar) for intents, embeddings, seed in players]
            sweep[str(bar)] = {k: ci([r[k] for r in runs])
                               for k in ("first_try_success", "success_within_3", "wrong_accepts_per_attempt")}
        report["skills"][skill.name]["frozen_gate_sweep"] = sweep
        print("   gate sweep (bar: first try / wrong per attempt): " + "  ".join(
            f"{b}: {sweep[b]['first_try_success']['mean']:.3f}/{sweep[b]['wrong_accepts_per_attempt']['mean']:.3f}"
            for b in sweep))
    if args.out:
        args.out.write_text(json.dumps(report, indent=2))
        print("saved", args.out)


if __name__ == "__main__":
    main()
