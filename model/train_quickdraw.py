"""Train the O.B.R.A. sketch classifier on Quick, Draw! bitmaps.

Designed to run in Google Colab (free GPU, PyTorch preinstalled) or locally with:
    pip install -r model/requirements.txt

Inputs :  data/<quickdraw_label>.npy  (from download_data.py)
Outputs:  model.onnx                  (the trained classifier, for the backend)
          labels.json                 (Quick Draw source labels in prediction order)
          model_metadata.json         (source label -> game entity mapping)
          metrics.json                (accuracy/report/confusion matrix data)
          confusion_matrix.png        (evaluation figure for the thesis)

Usage:
    python3 model/train_quickdraw.py
"""

import argparse
import json
import sys
from datetime import UTC, datetime
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
from sklearn.metrics import classification_report, confusion_matrix
from torch.utils.data import DataLoader, Dataset
from torchvision.transforms import RandomAffine

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parent
sys.path.insert(0, str(REPO_ROOT))

from shared.entities import (  # noqa: E402
    DEFAULT_MANIFEST_PATH,
    entity_ids,
    load_entities,
    source_labels,
)

DEFAULT_SAMPLES_PER_CLASS = 40_000  # each Quick Draw category has 100k+; this is plenty
DEFAULT_EPOCHS = 8
DEFAULT_BATCH_SIZE = 256
DEFAULT_LEARNING_RATE = 1e-3
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"


class QuickDrawDataset(Dataset):
    def __init__(self, images: np.ndarray, labels: np.ndarray, augment: bool):
        self.images = torch.from_numpy(images).float().reshape(-1, 1, 28, 28) / 255.0
        self.labels = torch.from_numpy(labels).long()
        # Mild geometric augmentation so the model tolerates how differently people
        # draw on the live game canvas (rotation, size, position all vary).
        self.augment = (
            RandomAffine(degrees=12, translate=(0.08, 0.08), scale=(0.85, 1.15))
            if augment
            else None
        )

    def __len__(self) -> int:
        return len(self.labels)

    def __getitem__(self, idx: int):
        image = self.images[idx]
        if self.augment is not None:
            image = self.augment(image)
        return image, self.labels[idx]


class SketchCNN(nn.Module):
    """Small CNN: 3 conv blocks -> dense -> softmax logits. Trains in minutes."""

    def __init__(self, num_classes: int):
        super().__init__()
        self.features = nn.Sequential(
            nn.Conv2d(1, 32, 3, padding=1), nn.ReLU(), nn.MaxPool2d(2),   # 28 -> 14
            nn.Conv2d(32, 64, 3, padding=1), nn.ReLU(), nn.MaxPool2d(2),  # 14 -> 7
            nn.Conv2d(64, 128, 3, padding=1), nn.ReLU(),                  # 7 -> 7
        )
        self.classifier = nn.Sequential(
            nn.Flatten(),
            nn.Dropout(0.3),
            nn.Linear(128 * 7 * 7, 128),
            nn.ReLU(),
            nn.Linear(128, num_classes),
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.classifier(self.features(x))


def load_splits(source_names: list[str], samples_per_class: int):
    """80/10/10 train/val/test split, shuffled with a fixed seed."""
    images, labels = [], []
    data_dir = HERE / "data"
    for class_index, name in enumerate(source_names):
        data_path = data_dir / f"{name}.npy"
        if not data_path.exists():
            raise SystemExit(
                f"Missing {data_path}. Run: python3 model/download_data.py"
            )
        arr = np.load(data_path)[:samples_per_class]
        images.append(arr)
        labels.append(np.full(len(arr), class_index))
        print(f"loaded {name}: {len(arr)} drawings")
    images = np.concatenate(images)
    labels = np.concatenate(labels)

    rng = np.random.default_rng(seed=42)
    order = rng.permutation(len(labels))
    images, labels = images[order], labels[order]

    n = len(labels)
    train_end, val_end = int(n * 0.8), int(n * 0.9)
    return (
        QuickDrawDataset(images[:train_end], labels[:train_end], augment=True),
        QuickDrawDataset(images[train_end:val_end], labels[train_end:val_end], augment=False),
        QuickDrawDataset(images[val_end:], labels[val_end:], augment=False),
    )


@torch.no_grad()
def evaluate(model: nn.Module, loader: DataLoader):
    model.eval()
    all_preds, all_targets = [], []
    for batch, targets in loader:
        preds = model(batch.to(DEVICE)).argmax(dim=1).cpu()
        all_preds.append(preds)
        all_targets.append(targets)
    preds = torch.cat(all_preds).numpy()
    targets = torch.cat(all_targets).numpy()
    return (preds == targets).mean(), preds, targets


def save_confusion_matrix(
    targets: np.ndarray,
    preds: np.ndarray,
    names: list[str],
    output_path: Path,
) -> None:
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    matrix = confusion_matrix(targets, preds)
    fig, ax = plt.subplots(figsize=(6, 5))
    im = ax.imshow(matrix, cmap="Blues")
    ax.set_xticks(range(len(names)), names)
    ax.set_yticks(range(len(names)), names)
    ax.set_xlabel("Predicted")
    ax.set_ylabel("Actual")
    for i in range(len(names)):
        for j in range(len(names)):
            ax.text(j, i, str(matrix[i, j]), ha="center", va="center",
                    color="white" if matrix[i, j] > matrix.max() / 2 else "black")
    fig.colorbar(im)
    fig.tight_layout()
    fig.savefig(output_path, dpi=150)
    print("saved", output_path)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST_PATH)
    parser.add_argument("--samples-per-class", type=int, default=DEFAULT_SAMPLES_PER_CLASS)
    parser.add_argument("--epochs", type=int, default=DEFAULT_EPOCHS)
    parser.add_argument("--batch-size", type=int, default=DEFAULT_BATCH_SIZE)
    parser.add_argument("--learning-rate", type=float, default=DEFAULT_LEARNING_RATE)
    args = parser.parse_args()

    entities = load_entities(args.manifest, validate_scene_paths=True)
    source_names = source_labels(entities)
    output_names = entity_ids(entities)

    print(f"training on: {DEVICE}")
    print("entities:", ", ".join(output_names))
    print("source labels:", ", ".join(source_names))
    train_set, val_set, test_set = load_splits(source_names, args.samples_per_class)
    train_loader = DataLoader(train_set, batch_size=args.batch_size, shuffle=True)
    val_loader = DataLoader(val_set, batch_size=args.batch_size)
    test_loader = DataLoader(test_set, batch_size=args.batch_size)

    model = SketchCNN(len(source_names)).to(DEVICE)
    optimizer = torch.optim.Adam(model.parameters(), lr=args.learning_rate)
    loss_fn = nn.CrossEntropyLoss()
    validation_history: list[float] = []

    for epoch in range(1, args.epochs + 1):
        model.train()
        running_loss = 0.0
        for batch, targets in train_loader:
            batch, targets = batch.to(DEVICE), targets.to(DEVICE)
            optimizer.zero_grad()
            loss = loss_fn(model(batch), targets)
            loss.backward()
            optimizer.step()
            running_loss += loss.item() * len(targets)
        val_accuracy, _, _ = evaluate(model, val_loader)
        validation_history.append(float(val_accuracy))
        print(f"epoch {epoch}/{args.epochs}  "
              f"loss {running_loss / len(train_set):.4f}  val acc {val_accuracy:.4f}")

    test_accuracy, preds, targets = evaluate(model, test_loader)
    print(f"\nheld-out TEST accuracy: {test_accuracy:.4f}\n")
    report_text = classification_report(
        targets,
        preds,
        target_names=output_names,
        digits=4,
        zero_division=0,
    )
    report = classification_report(
        targets,
        preds,
        target_names=output_names,
        output_dict=True,
        zero_division=0,
    )
    print(report_text)
    matrix = confusion_matrix(targets, preds)
    save_confusion_matrix(targets, preds, output_names, HERE / "confusion_matrix.png")

    # Export for the backend (onnxruntime), with a dynamic batch dimension.
    model.eval().cpu()
    torch.onnx.export(
        model,
        torch.zeros(1, 1, 28, 28),
        HERE / "model.onnx",
        input_names=["input"],
        output_names=["logits"],
        dynamic_axes={"input": {0: "batch"}, "logits": {0: "batch"}},
        opset_version=17,
    )
    (HERE / "labels.json").write_text(json.dumps(source_names, indent=2))
    try:
        manifest_path_for_metadata = str(args.manifest.relative_to(REPO_ROOT))
    except ValueError:
        manifest_path_for_metadata = str(args.manifest)

    (HERE / "model_metadata.json").write_text(json.dumps({
        "format_version": 1,
        "created_at": datetime.now(UTC).isoformat(),
        "manifest_path": manifest_path_for_metadata,
        "entity_ids": output_names,
        "source_labels": source_names,
        "input_shape": [1, 1, 28, 28],
        "samples_per_class": args.samples_per_class,
        "epochs": args.epochs,
        "batch_size": args.batch_size,
        "learning_rate": args.learning_rate,
        "preprocess": "backend/preprocess.py",
    }, indent=2))
    (HERE / "metrics.json").write_text(json.dumps({
        "format_version": 1,
        "entity_ids": output_names,
        "source_labels": source_names,
        "train_size": len(train_set),
        "validation_size": len(val_set),
        "test_size": len(test_set),
        "validation_accuracy_by_epoch": validation_history,
        "test_accuracy": float(test_accuracy),
        "classification_report": report,
        "confusion_matrix": matrix.tolist(),
    }, indent=2))
    print(
        "saved",
        HERE / "model.onnx",
        HERE / "labels.json",
        HERE / "model_metadata.json",
        HERE / "metrics.json",
    )


if __name__ == "__main__":
    main()
