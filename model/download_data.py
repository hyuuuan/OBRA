"""Download the Quick, Draw! numpy bitmaps for O.B.R.A.'s classes.

Uses only the Python standard library, so it runs before you install anything.
Each file is a numpy array of shape (num_drawings, 784) — 28x28 grayscale doodles,
white ink on a black background.

Usage:
    python download_data.py
"""

import urllib.request
from pathlib import Path

CLASSES = ["frog", "fish", "spider"]
BASE_URL = "https://storage.googleapis.com/quickdraw_dataset/full/numpy_bitmap"
DATA_DIR = Path(__file__).resolve().parent / "data"


def download(category: str) -> None:
    dest = DATA_DIR / f"{category}.npy"
    if dest.exists():
        print(f"[skip] {dest.name} already exists ({dest.stat().st_size / 1e6:.1f} MB)")
        return
    url = f"{BASE_URL}/{urllib.request.quote(category)}.npy"
    print(f"[down] {url}")

    def progress(blocks: int, block_size: int, total: int) -> None:
        done = blocks * block_size
        pct = min(100.0, done * 100.0 / total) if total > 0 else 0.0
        print(f"\r       {done / 1e6:6.1f} MB ({pct:5.1f}%)", end="", flush=True)

    urllib.request.urlretrieve(url, dest, reporthook=progress)
    print(f"\n[done] {dest}")


if __name__ == "__main__":
    DATA_DIR.mkdir(exist_ok=True)
    for category in CLASSES:
        download(category)
    print("\nAll categories downloaded into", DATA_DIR)
