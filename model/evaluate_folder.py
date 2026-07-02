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
"""

import argparse
import json
import sys
from pathlib import Path

import numpy as np
import onnxruntime

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parent
sys.path.insert(0, str(REPO_ROOT))
sys.path.insert(0, str(REPO_ROOT / "backend"))
from preprocess import EmptyCanvasError, preprocess_image  # noqa: E402
from shared.entities import (  # noqa: E402
    DEFAULT_MANIFEST_PATH,
    entities_by_source_label,
    load_entities,
    validate_model_labels,
)

IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".bmp", ".gif"}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dir", required=True, help="folder with one subfolder per class")
    parser.add_argument("--model", default=HERE / "model.onnx")
    parser.add_argument("--labels", default=HERE / "labels.json")
    parser.add_argument("--manifest", default=DEFAULT_MANIFEST_PATH)
    args = parser.parse_args()

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
                    tensor = preprocess_image(path.read_bytes())
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


if __name__ == "__main__":
    main()
