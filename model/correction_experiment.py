"""Does a handful of player corrections make recognition better for that player?

An offline experiment, run before any game change. The CNN stays frozen -- the thesis
holds it fixed at export (§3.2.10) -- and a small per-player memory learns from drawings
the player has labelled ("corrections"). Three ways of using that memory are compared:

  frozen     the shipped model, as it is
  prototype  each corrected class keeps the mean of its corrections' penultimate-layer
             embeddings; a drawing's model probabilities are blended with a softmax over
             its cosine similarity to those prototypes (no training, reversible, ms-cheap)
  finetune   only the final 50x128 layer is retrained on the corrections, pulled back
             toward the shipped weights by an L2 anchor so it cannot wander far

THE STAND-IN FOR "A PLAYER" IS TU-BERLIN: sketches drawn by other people, under another
protocol, that the model never saw (the stroke-preserving baseline is 0.677 on its 40
covered classes, model/metrics_tu_berlin_stroke_preserving.json). It is a population, not
one person, so a gain here is adaptation to a drawing style, which is what a player's
corrections would carry -- it is not a user study, and the write-up says so.

PROTOCOL, fixed before any result was seen:
  * Each covered class is split in half, at random per trial: a TEST half that is only
    ever scored, and a POOL that corrections are drawn from.
  * k corrections per class come from the pool, k in {0, 1, 3, 5, 10}.
  * Each method's hyperparameters are chosen ONCE, on separate dev trials (their own
    seeds, scored on the pool left over after the corrections), as one setting for every
    k -- a game would ship one setting. The test halves are never used to choose anything.
  * 10 test trials; mean and a 95% interval (t, 9 d.f.).
  * Regression: corrections from TU-Berlin must not cost ordinary drawings. 200 Quick,
    Draw! drawings per class from the 15 roster classes on disk, taken from past index
    40,000 -- training read only the first 40,000 of each class, so these are unseen --
    framed exactly as training framed them.
  * Wrong corrections: at k = 5, a fraction of the corrections carry a wrong label.

Run from the repo root, in an environment with onnx, onnxruntime, numpy and pillow
(TU-Berlin unpacked to model/data/tu_berlin, as for evaluate_folder.py):

    python model/correction_experiment.py --out model/correction_experiment.json
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path

import numpy as np
import onnx
import onnxruntime

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parent
sys.path.insert(0, str(REPO_ROOT))
sys.path.insert(0, str(REPO_ROOT / "backend"))
sys.path.insert(0, str(HERE))
from evaluate_folder import IMAGE_EXTENSIONS, preprocess_stroke_preserving  # noqa: E402
from preprocess import EmptyCanvasError, canonicalize_ink, preprocess_image  # noqa: E402
from shared.entities import (  # noqa: E402
    DEFAULT_MANIFEST_PATH,
    entities_by_source_label,
    load_entities,
)

EMBEDDING_OUTPUT = "/classifier/classifier.3/Relu_output_0"  # the 128-d layer before logits
LAST_WEIGHT, LAST_BIAS = "classifier.4.weight", "classifier.4.bias"
KS = (0, 1, 3, 5, 10)
TEST_SEEDS = range(10)
DEV_SEEDS = range(1000, 1005)
QD_UNSEEN_FROM = 40_000  # training read [:40_000] of each class
QD_PER_CLASS = 200
NOISE_LEVELS = (0.0, 0.2, 0.4)
T_95_9DF = 2.262

PROTOTYPE_GRID = [(lam, temp) for lam in (0.1, 0.2, 0.3, 0.5, 0.7) for temp in (0.05, 0.1, 0.2)]
FINETUNE_GRID = [(anchor, lr) for anchor in (0.01, 0.1, 1.0) for lr in (0.01, 0.05)]
FINETUNE_STEPS = 100


# --- the frozen model, opened at its penultimate layer -----------------------------------
class Frozen:
    def __init__(self, model_path: Path):
        model = onnx.load(str(model_path))
        model.graph.output.append(onnx.helper.make_tensor_value_info(
            EMBEDDING_OUTPUT, onnx.TensorProto.FLOAT, None))
        weights = {t.name: onnx.numpy_helper.to_array(t) for t in model.graph.initializer}
        self.W = weights[LAST_WEIGHT].astype(np.float64)   # (50, 128)
        self.b = weights[LAST_BIAS].astype(np.float64)     # (50,)
        self.session = onnxruntime.InferenceSession(model.SerializeToString())

    def embed(self, tensors: np.ndarray) -> np.ndarray:
        out = []
        for start in range(0, len(tensors), 256):
            batch = tensors[start:start + 256].astype(np.float32)
            logits, emb = self.session.run(["logits", EMBEDDING_OUTPUT], {"input": batch})
            # The head recomputed from the embedding must be the model's own logits, or the
            # adapters below would be adapting a different model.
            assert np.allclose(emb @ self.W.T + self.b, logits, atol=1e-3)
            out.append(emb.astype(np.float64))
        return np.concatenate(out)


# --- the three ways of reading a drawing --------------------------------------------------
def log_softmax(z: np.ndarray) -> np.ndarray:
    z = z - z.max(axis=1, keepdims=True)
    return z - np.log(np.exp(z).sum(axis=1, keepdims=True))


def predict_frozen(model: Frozen, emb: np.ndarray) -> np.ndarray:
    return (emb @ model.W.T + model.b).argmax(axis=1)


def prototypes(emb: np.ndarray, labels: np.ndarray, num_classes: int) -> np.ndarray:
    """Unit-length mean of each corrected class's unit-length embeddings; NaN rows for a
    class nobody corrected."""
    unit = emb / np.maximum(np.linalg.norm(emb, axis=1, keepdims=True), 1e-9)
    protos = np.full((num_classes, emb.shape[1]), np.nan)
    for c in np.unique(labels):
        mean = unit[labels == c].mean(axis=0)
        protos[c] = mean / max(np.linalg.norm(mean), 1e-9)
    return protos


def predict_prototype(model: Frozen, emb: np.ndarray, protos: np.ndarray, lam: float, temp: float):
    """(1 - lam) * model probabilities + lam * a softmax over corrected classes' cosine
    similarity. A class nobody corrected gets nothing from the memory, so the memory can
    only ever add weight to what the player taught it."""
    p_model = np.exp(log_softmax(emb @ model.W.T + model.b))
    known = ~np.isnan(protos[:, 0])
    if not known.any() or lam == 0.0:
        return p_model.argmax(axis=1)
    unit = emb / np.maximum(np.linalg.norm(emb, axis=1, keepdims=True), 1e-9)
    sims = unit @ protos[known].T / temp
    p_mem = np.zeros_like(p_model)
    p_mem[:, known] = np.exp(log_softmax(sims))
    return ((1.0 - lam) * p_model + lam * p_mem).argmax(axis=1)


def finetune_head(model: Frozen, emb: np.ndarray, labels: np.ndarray, anchor: float, lr: float):
    """Retrain the last layer on the corrections: cross-entropy + anchor/2 * ||theta - theta0||^2,
    plain gradient descent from the shipped weights."""
    W, b = model.W.copy(), model.b.copy()
    onehot = np.eye(len(b))[labels]
    for _ in range(FINETUNE_STEPS):
        p = np.exp(log_softmax(emb @ W.T + b))
        grad_z = (p - onehot) / len(labels)
        W -= lr * (grad_z.T @ emb + anchor * (W - model.W))
        b -= lr * (grad_z.sum(axis=0) + anchor * (b - model.b))
    return W, b


def predict_head(emb: np.ndarray, head) -> np.ndarray:
    W, b = head
    return (emb @ W.T + b).argmax(axis=1)


# --- data -------------------------------------------------------------------------------
def load_tu_berlin(model: Frozen, tu_dir: Path, entities, prepare) -> tuple[np.ndarray, np.ndarray]:
    tensors, labels = [], []
    for index, entity in enumerate(entities):
        for folder in entity.evaluation_labels:
            path = tu_dir / folder
            if not path.is_dir():
                continue
            for image in sorted(path.iterdir()):
                if image.suffix.lower() not in IMAGE_EXTENSIONS:
                    continue
                try:
                    tensors.append(prepare(image.read_bytes())[0])
                except EmptyCanvasError:
                    continue
                labels.append(index)
    return model.embed(np.stack(tensors)), np.array(labels)


def load_quickdraw_unseen(model: Frozen, entities) -> tuple[np.ndarray, np.ndarray, list[str]]:
    tensors, labels, used = [], [], []
    for index, entity in enumerate(entities):
        path = HERE / "data" / f"{entity.quickdraw_label}.npy"
        if not path.exists():
            continue
        rows = np.load(path, mmap_mode="r")[QD_UNSEEN_FROM:QD_UNSEEN_FROM + QD_PER_CLASS]
        if len(rows) < QD_PER_CLASS:
            continue
        used.append(entity.id)
        for row in rows:
            # Exactly train_quickdraw.canonicalize_batch, then QuickDrawDataset's /255.
            framed = (canonicalize_ink(np.asarray(row, dtype=np.float32).reshape(28, 28)) * 255.0)
            tensors.append(framed.astype(np.uint8).astype(np.float32).reshape(1, 28, 28) / 255.0)
            labels.append(index)
    return model.embed(np.stack(tensors)), np.array(labels), used


# --- one trial ------------------------------------------------------------------------------
def split(labels: np.ndarray, rng: np.random.Generator):
    test, pool = [], {}
    for c in np.unique(labels):
        idx = rng.permutation(np.flatnonzero(labels == c))
        half = len(idx) // 2
        test.extend(idx[:half])
        pool[c] = idx[half:]
    return np.array(test), pool


def corrections(pool: dict, k: int, rng: np.random.Generator, labels: np.ndarray,
                wrong: float = 0.0):
    support, support_labels, rest = [], [], []
    classes = sorted(pool)
    for c in classes:
        chosen = pool[c][:k]
        support.extend(chosen)
        rest.extend(pool[c][k:])
        given = np.full(len(chosen), c)
        flip = rng.random(len(chosen)) < wrong
        for i in np.flatnonzero(flip):
            given[i] = rng.choice([o for o in classes if o != c])
        support_labels.extend(given)
    return np.array(support, dtype=int), np.array(support_labels, dtype=int), np.array(rest, dtype=int)


def run_trial(model, emb, labels, seed, k, settings, qd=None, wrong=0.0):
    rng = np.random.default_rng(seed)
    test, pool = split(labels, rng)
    pool = {c: rng.permutation(v) for c, v in pool.items()}
    support, given, rest = corrections(pool, k, rng, labels, wrong)
    truth = labels[test]
    result = {"frozen": float((predict_frozen(model, emb[test]) == truth).mean())}
    if qd is not None:
        result["qd_frozen"] = float((predict_frozen(model, qd[0]) == qd[1]).mean())
    if k == 0:
        result["prototype"] = result["finetune"] = result["frozen"]
        if qd is not None:
            result["qd_prototype"] = result["qd_finetune"] = result["qd_frozen"]
        return result, rest
    protos = prototypes(emb[support], given, len(model.b))
    lam, temp = settings["prototype"]
    result["prototype"] = float((predict_prototype(model, emb[test], protos, lam, temp) == truth).mean())
    head = finetune_head(model, emb[support], given, *settings["finetune"])
    result["finetune"] = float((predict_head(emb[test], head) == truth).mean())
    if qd is not None:
        result["qd_prototype"] = float((predict_prototype(model, qd[0], protos, lam, temp) == qd[1]).mean())
        result["qd_finetune"] = float((predict_head(qd[0], head) == qd[1]).mean())
    return result, rest


def choose_settings(model, emb, labels) -> dict:
    """One setting per method for every k, by mean accuracy on dev trials' leftover pool."""
    def dev_score(method, setting):
        scores = []
        for seed in DEV_SEEDS:
            for k in KS[1:]:
                rng = np.random.default_rng(seed)
                _, pool = split(labels, rng)
                pool = {c: rng.permutation(v) for c, v in pool.items()}
                support, given, rest = corrections(pool, k, rng, labels)
                if method == "prototype":
                    protos = prototypes(emb[support], given, len(model.b))
                    pred = predict_prototype(model, emb[rest], protos, *setting)
                else:
                    pred = predict_head(emb[rest], finetune_head(model, emb[support], given, *setting))
                scores.append((pred == labels[rest]).mean())
        return float(np.mean(scores))

    return {
        "prototype": max(PROTOTYPE_GRID, key=lambda s: dev_score("prototype", s)),
        "finetune": max(FINETUNE_GRID, key=lambda s: dev_score("finetune", s)),
    }


def summarize(values: list[float]) -> dict:
    arr = np.array(values)
    half = T_95_9DF * arr.std(ddof=1) / math.sqrt(len(arr)) if len(arr) > 1 else 0.0
    return {"mean": float(arr.mean()), "ci95": float(half), "n": len(arr)}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tu-dir", type=Path, default=HERE / "data" / "tu_berlin")
    parser.add_argument("--model", type=Path, default=HERE / "model.onnx")
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST_PATH)
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()

    entities = load_entities(args.manifest)
    assert list(entities_by_source_label(entities))  # the manifest loads and maps
    model = Frozen(args.model)
    qd = load_quickdraw_unseen(model, entities)
    print(f"Quick, Draw! unseen regression set: {len(qd[1])} drawings, classes {', '.join(qd[2])}")

    report = {"protocol": {"ks": list(KS), "test_trials": len(TEST_SEEDS), "dev_trials": len(DEV_SEEDS),
                           "finetune_steps": FINETUNE_STEPS, "quickdraw_unseen_from": QD_UNSEEN_FROM,
                           "quickdraw_per_class": QD_PER_CLASS, "quickdraw_classes": qd[2]},
              "conditions": {}}
    for condition, prepare in (("stroke_preserving", preprocess_stroke_preserving),
                               ("game_preprocessing", preprocess_image)):
        emb, labels = load_tu_berlin(model, args.tu_dir, entities, prepare)
        settings = choose_settings(model, emb, labels)
        print(f"\n[{condition}] {len(labels)} sketches, {len(np.unique(labels))} classes; "
              f"prototype (lambda, T) = {settings['prototype']}, finetune (anchor, lr) = {settings['finetune']}")
        by_k = {}
        for k in KS:
            trials = [run_trial(model, emb, labels, seed, k, settings, qd)[0] for seed in TEST_SEEDS]
            by_k[k] = {key: summarize([t[key] for t in trials]) for key in trials[0]}
            row = by_k[k]
            print(f"  k={k:>2}  frozen {row['frozen']['mean']:.3f}  "
                  f"prototype {row['prototype']['mean']:.3f}±{row['prototype']['ci95']:.3f}  "
                  f"finetune {row['finetune']['mean']:.3f}±{row['finetune']['ci95']:.3f}  |  "
                  f"QD frozen {row['qd_frozen']['mean']:.3f} proto {row['qd_prototype']['mean']:.3f} "
                  f"ft {row['qd_finetune']['mean']:.3f}")
        noise = {}
        for wrong in NOISE_LEVELS:
            trials = [run_trial(model, emb, labels, seed, 5, settings, wrong=wrong)[0] for seed in TEST_SEEDS]
            noise[str(wrong)] = {key: summarize([t[key] for t in trials]) for key in trials[0]}
            print(f"  k=5, {int(wrong * 100):>2}% wrong corrections: prototype "
                  f"{noise[str(wrong)]['prototype']['mean']:.3f}  finetune {noise[str(wrong)]['finetune']['mean']:.3f}")
        # POST HOC, AND LABELLED SO: the prototype setting above was chosen for TU-Berlin
        # accuracy alone, and landed on the grid's largest blend. This traces what each
        # blend weight buys on TU-Berlin against what it costs ordinary drawings, at k = 5.
        # It chooses nothing; it is the curve a game would pick its setting from.
        tradeoff = []
        for lam in (0.0, 0.05, 0.1, 0.2, 0.3, 0.5, 0.7, 0.9):
            temp = settings["prototype"][1]
            tu_scores, qd_scores = [], []
            for seed in TEST_SEEDS:
                rng = np.random.default_rng(seed)
                test, pool = split(labels, rng)
                pool = {c: rng.permutation(v) for c, v in pool.items()}
                support, given, _ = corrections(pool, 5, rng, labels)
                protos = prototypes(emb[support], given, len(model.b))
                tu_scores.append((predict_prototype(model, emb[test], protos, lam, temp) == labels[test]).mean())
                qd_scores.append((predict_prototype(model, qd[0], protos, lam, temp) == qd[1]).mean())
            tradeoff.append({"lambda": lam, "tu_berlin": summarize(tu_scores), "quickdraw": summarize(qd_scores)})
            print(f"  post hoc, k=5, lambda {lam:.2f}: TU-Berlin {np.mean(tu_scores):.3f}  "
                  f"Quick, Draw! {np.mean(qd_scores):.3f}")
        report["conditions"][condition] = {
            "prototype_tradeoff_k5_post_hoc": tradeoff,
            "sketches": int(len(labels)),
            "classes": int(len(np.unique(labels))),
            "settings": {"prototype": {"lambda": settings["prototype"][0], "temperature": settings["prototype"][1]},
                         "finetune": {"anchor": settings["finetune"][0], "learning_rate": settings["finetune"][1]}},
            "by_k": {str(k): v for k, v in by_k.items()},
            "wrong_corrections_k5": noise,
        }
    if args.out:
        args.out.write_text(json.dumps(report, indent=2))
        print("\nsaved", args.out)


if __name__ == "__main__":
    main()
