"""Cross-dataset evaluation for the thesis: test the trained model on sketches it
never saw during training (e.g. TU-Berlin or Sketchy).

Arrange the test images as one folder per external label. Each entity's
`evaluation_labels` in game/config/entities.json is folded into that entity:

    tu_berlin/
        frog/    *.png
        fish/    *.png
        spider/  *.png
        flying bird/    *.png
        standing bird/  *.png

Then run (from the repo root, with the backend's venv active so onnxruntime,
pillow and numpy are available):

    python3 model/evaluate_folder.py --dir tu_berlin

It reuses backend/preprocess.py, so the evaluation sees EXACTLY the same
preprocessing as the live game.

⚠ THAT PREPROCESSING ERASES TU-BERLIN'S STROKES. Its sketches are 1111 px with pen lines a
few pixels wide; cropped and shrunk about forty times by an averaging resize, a line comes
out at 0.2-0.3 of full ink, where a Quick, Draw! stroke is 1.0 -- the model is shown a
near-blank page and calls a third of the set "bread". So --stroke-preserving shrinks by
taking each block's MAXIMUM instead, which keeps a stroke as a full-strength line about a
pixel wide, and then frames it exactly as the game does. It was fixed before its result was
seen, to keep the test set out of the choice. Report both: the default run is the
manuscript's protocol (identical preprocessing), the other measures the model rather than
the resize.
"""

import argparse
import io
import json
import math
import sys
from pathlib import Path

import numpy as np
import onnxruntime
from PIL import Image

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parent
sys.path.insert(0, str(REPO_ROOT))
sys.path.insert(0, str(REPO_ROOT / "backend"))
from preprocess import (  # noqa: E402
    INK_THRESHOLD,
    TARGET_INK_SIZE,
    EmptyCanvasError,
    canonicalize_ink,
    preprocess_image,
)
from shared.entities import (  # noqa: E402
    DEFAULT_MANIFEST_PATH,
    entities_by_source_label,
    load_entities,
    validate_model_labels,
)

IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".bmp", ".gif"}


def preprocess_stroke_preserving(image_bytes: bytes) -> np.ndarray:
    """preprocess_image, except the drawing is shrunk to the target size by block-max
    rather than by averaging, so thin strokes survive. Same inversion, same background
    zeroing, same framing (canonicalize_ink) as the game."""
    arr = np.asarray(Image.open(io.BytesIO(image_bytes)).convert("L"), dtype=np.float32)
    if arr.mean() > 127:
        arr = 255.0 - arr
    arr = np.where(arr > INK_THRESHOLD, arr, 0.0)
    ink_rows, ink_cols = np.where(arr > INK_THRESHOLD)
    if ink_rows.size == 0:
        raise EmptyCanvasError("no ink found in the image")
    arr = arr[ink_rows.min():ink_rows.max() + 1, ink_cols.min():ink_cols.max() + 1]
    factor = max(1, math.ceil(max(arr.shape) / TARGET_INK_SIZE))
    height = math.ceil(arr.shape[0] / factor) * factor
    width = math.ceil(arr.shape[1] / factor) * factor
    arr = np.pad(arr, ((0, height - arr.shape[0]), (0, width - arr.shape[1])))
    arr = arr.reshape(height // factor, factor, width // factor, factor).max(axis=(1, 3))
    return canonicalize_ink(arr).reshape(1, 1, 28, 28)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dir", required=True, help="folder with one subfolder per class")
    parser.add_argument("--model", default=HERE / "model.onnx")
    parser.add_argument("--labels", default=HERE / "labels.json")
    parser.add_argument("--manifest", default=DEFAULT_MANIFEST_PATH)
    parser.add_argument(
        "--out",
        type=Path,
        help="also write the results as JSON (per-class precision/recall/support, the "
        "classes with no test folder, and the confusion matrix), like model/metrics.json",
    )
    parser.add_argument(
        "--stroke-preserving",
        action="store_true",
        help="shrink by block-max instead of averaging (see the module docstring); NOT "
        "the game's preprocessing, so report it beside the default run, never instead",
    )
    args = parser.parse_args()
    prepare = preprocess_stroke_preserving if args.stroke_preserving else preprocess_image

    labels: list[str] = json.loads(Path(args.labels).read_text())
    entities = load_entities(args.manifest)
    validate_model_labels(labels, entities, source=str(args.labels))
    source_to_entity = entities_by_source_label(entities)
    session = onnxruntime.InferenceSession(str(args.model))
    test_dir = Path(args.dir)

    matrix = np.zeros((len(entities), len(entities)), dtype=int)  # [actual, predicted]
    skipped = 0
    skipped_entities = []
    for actual_index, entity in enumerate(entities):
        if not entity.evaluation_labels:
            skipped_entities.append(entity.id)
            continue
        for external_label in entity.evaluation_labels:
            class_dir = test_dir / external_label
            if not class_dir.is_dir():
                print(
                    f"WARNING: missing folder {class_dir}, skipping label "
                    f"'{external_label}' for entity '{entity.id}'"
                )
                continue
            for path in sorted(class_dir.iterdir()):
                if path.suffix.lower() not in IMAGE_EXTENSIONS:
                    continue
                try:
                    tensor = prepare(path.read_bytes())
                except (EmptyCanvasError, OSError):
                    skipped += 1
                    continue
                logits = session.run(["logits"], {"input": tensor})[0][0]
                predicted_source = labels[int(logits.argmax())]
                predicted_entity = source_to_entity[predicted_source]
                predicted_index = entities.index(predicted_entity)
                matrix[actual_index, predicted_index] += 1

    total = matrix.sum()
    if total == 0:
        raise SystemExit("No images evaluated — check --dir layout (one subfolder per class).")

    print(f"\nCross-dataset results on {test_dir} ({total} images, {skipped} skipped)\n")
    if skipped_entities:
        print("Skipped entities with no cross-dataset labels:", ", ".join(skipped_entities))
        print()
    print(f"{'class':<10} {'n':>5} {'accuracy':>9}")
    for i, entity in enumerate(entities):
        n = matrix[i].sum()
        acc = matrix[i, i] / n if n else float("nan")
        print(f"{entity.id:<10} {n:>5} {acc:>9.4f}")
    print(f"\noverall accuracy: {np.trace(matrix) / total:.4f}")
    print("\nconfusion matrix [rows = actual, cols = predicted]:")
    print("           " + " ".join(f"{entity.id:>8}" for entity in entities))
    for i, entity in enumerate(entities):
        print(f"{entity.id:<10} " + " ".join(f"{v:>8}" for v in matrix[i]))

    if args.out:
        # Recall is only defined for a class that had test images, so the classes with none
        # are listed by name rather than averaged in as zeros -- the thesis reports TU-Berlin
        # against its covered subset and never as a fifty-class figure. Precision is over
        # this set's predictions, so a class with no test images still has a precision of
        # zero whenever the model predicts it here.
        covered = [entity.id for i, entity in enumerate(entities) if matrix[i].sum() > 0]
        per_class = {}
        for i, entity in enumerate(entities):
            support = int(matrix[i].sum())
            predicted = int(matrix[:, i].sum())
            per_class[entity.id] = {
                "support": support,
                "predicted": predicted,
                "recall": float(matrix[i, i] / support) if support else None,
                "precision": float(matrix[i, i] / predicted) if predicted else None,
            }
        recalls = [per_class[eid]["recall"] for eid in covered]
        args.out.write_text(json.dumps({
            "format_version": 1,
            "dataset_dir": str(test_dir),
            "model": str(args.model),
            "preprocessing": "stroke_preserving" if args.stroke_preserving else "game",
            "images_evaluated": int(total),
            "images_skipped": skipped,
            "covered_entities": covered,
            "uncovered_entities": [e.id for e in entities if e.id not in covered],
            "accuracy": float(np.trace(matrix) / total),
            "macro_recall_covered": float(np.mean(recalls)),
            "per_class": per_class,
            "entity_ids": [entity.id for entity in entities],
            "confusion_matrix": matrix.tolist(),
        }, indent=2))
        print("saved", args.out)


if __name__ == "__main__":
    main()
