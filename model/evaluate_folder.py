"""Cross-dataset evaluation for the thesis: test the trained model on sketches it
never saw during training (e.g. TU-Berlin or Sketchy).

Arrange the test images as one folder per class, named exactly like labels.json:

    tu_berlin/
        frog/    *.png
        fish/    *.png
        spider/  *.png

Then run (from the repo root, with the backend's venv active so onnxruntime,
pillow and numpy are available):

    python model/evaluate_folder.py --dir tu_berlin

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
sys.path.insert(0, str(HERE.parent / "backend"))
from preprocess import EmptyCanvasError, preprocess_image  # noqa: E402

IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".bmp", ".gif"}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dir", required=True, help="folder with one subfolder per class")
    parser.add_argument("--model", default=HERE / "model.onnx")
    parser.add_argument("--labels", default=HERE / "labels.json")
    args = parser.parse_args()

    labels: list[str] = json.loads(Path(args.labels).read_text())
    session = onnxruntime.InferenceSession(str(args.model))
    test_dir = Path(args.dir)

    matrix = np.zeros((len(labels), len(labels)), dtype=int)  # [actual, predicted]
    skipped = 0
    for actual_index, name in enumerate(labels):
        class_dir = test_dir / name
        if not class_dir.is_dir():
            print(f"WARNING: missing folder {class_dir}, skipping class '{name}'")
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
            matrix[actual_index, int(logits.argmax())] += 1

    total = matrix.sum()
    if total == 0:
        raise SystemExit("No images evaluated — check --dir layout (one subfolder per class).")

    print(f"\nCross-dataset results on {test_dir} ({total} images, {skipped} skipped)\n")
    print(f"{'class':<10} {'n':>5} {'accuracy':>9}")
    for i, name in enumerate(labels):
        n = matrix[i].sum()
        acc = matrix[i, i] / n if n else float("nan")
        print(f"{name:<10} {n:>5} {acc:>9.4f}")
    print(f"\noverall accuracy: {np.trace(matrix) / total:.4f}")
    print("\nconfusion matrix [rows = actual, cols = predicted]:")
    print("           " + " ".join(f"{n:>8}" for n in labels))
    for i, name in enumerate(labels):
        print(f"{name:<10} " + " ".join(f"{v:>8}" for v in matrix[i]))


if __name__ == "__main__":
    main()
