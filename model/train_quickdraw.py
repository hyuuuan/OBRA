"""Train the O.B.R.A. sketch classifier on Quick, Draw! bitmaps.

Designed to run in Google Colab (free GPU, PyTorch preinstalled) or locally with:
    pip install torch torchvision numpy scikit-learn matplotlib

Inputs :  data/<class>.npy            (from download_data.py)
Outputs:  model.onnx                  (the trained classifier, for the backend)
          labels.json                 (class names in prediction order)
          confusion_matrix.png        (evaluation figure for the thesis)

Usage:
    python train_quickdraw.py
"""

import json
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
from sklearn.metrics import classification_report, confusion_matrix
from torch.utils.data import DataLoader, Dataset
from torchvision.transforms import RandomAffine

CLASSES = ["frog", "fish", "spider"]
SAMPLES_PER_CLASS = 40_000  # each Quick Draw category has 100k+; this is plenty
EPOCHS = 8
BATCH_SIZE = 256
LEARNING_RATE = 1e-3
HERE = Path(__file__).resolve().parent
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


def load_splits():
    """80/10/10 train/val/test split, shuffled with a fixed seed."""
    images, labels = [], []
    for class_index, name in enumerate(CLASSES):
        arr = np.load(HERE / "data" / f"{name}.npy")[:SAMPLES_PER_CLASS]
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


def save_confusion_matrix(targets: np.ndarray, preds: np.ndarray) -> None:
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    matrix = confusion_matrix(targets, preds)
    fig, ax = plt.subplots(figsize=(5, 4))
    im = ax.imshow(matrix, cmap="Blues")
    ax.set_xticks(range(len(CLASSES)), CLASSES)
    ax.set_yticks(range(len(CLASSES)), CLASSES)
    ax.set_xlabel("Predicted")
    ax.set_ylabel("Actual")
    for i in range(len(CLASSES)):
        for j in range(len(CLASSES)):
            ax.text(j, i, str(matrix[i, j]), ha="center", va="center",
                    color="white" if matrix[i, j] > matrix.max() / 2 else "black")
    fig.colorbar(im)
    fig.tight_layout()
    fig.savefig(HERE / "confusion_matrix.png", dpi=150)
    print("saved", HERE / "confusion_matrix.png")


def main() -> None:
    print(f"training on: {DEVICE}")
    train_set, val_set, test_set = load_splits()
    train_loader = DataLoader(train_set, batch_size=BATCH_SIZE, shuffle=True)
    val_loader = DataLoader(val_set, batch_size=BATCH_SIZE)
    test_loader = DataLoader(test_set, batch_size=BATCH_SIZE)

    model = SketchCNN(len(CLASSES)).to(DEVICE)
    optimizer = torch.optim.Adam(model.parameters(), lr=LEARNING_RATE)
    loss_fn = nn.CrossEntropyLoss()

    for epoch in range(1, EPOCHS + 1):
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
        print(f"epoch {epoch}/{EPOCHS}  "
              f"loss {running_loss / len(train_set):.4f}  val acc {val_accuracy:.4f}")

    test_accuracy, preds, targets = evaluate(model, test_loader)
    print(f"\nheld-out TEST accuracy: {test_accuracy:.4f}\n")
    print(classification_report(targets, preds, target_names=CLASSES, digits=4))
    save_confusion_matrix(targets, preds)

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
    (HERE / "labels.json").write_text(json.dumps(CLASSES))
    print("saved", HERE / "model.onnx", "and", HERE / "labels.json")


if __name__ == "__main__":
    main()
