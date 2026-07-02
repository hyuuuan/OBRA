"""Download the Quick, Draw! numpy bitmaps for O.B.R.A.'s enabled entities.

Uses only the Python standard library, so it runs before you install anything.
Each file is a numpy array of shape (num_drawings, 784) — 28x28 grayscale doodles,
white ink on a black background.

Usage:
    python3 model/download_data.py
"""

import argparse
import sys
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT))

from shared.entities import DEFAULT_MANIFEST_PATH, load_entities  # noqa: E402

BASE_URL = "https://storage.googleapis.com/quickdraw_dataset/full/numpy_bitmap"
DATA_DIR = Path(__file__).resolve().parent / "data"


def download(category: str) -> None:
    dest = DATA_DIR / f"{category}.npy"
    if dest.exists():
        print(f"[skip] {dest.name} already exists ({dest.stat().st_size / 1e6:.1f} MB)")
        return
    temp_dest = dest.with_suffix(dest.suffix + ".part")
    if temp_dest.exists():
        temp_dest.unlink()
    url = f"{BASE_URL}/{urllib.request.quote(category)}.npy"
    print(f"[down] {url}")
    last_reported_mb = -5

    def progress(blocks: int, block_size: int, total: int) -> None:
        nonlocal last_reported_mb
        done = blocks * block_size
        pct = min(100.0, done * 100.0 / total) if total > 0 else 0.0
        done_mb = int(done / 1e6)
        if done_mb - last_reported_mb >= 5 or (total > 0 and done >= total):
            last_reported_mb = done_mb
            print(f"       {done / 1e6:6.1f} MB ({pct:5.1f}%)", flush=True)

    urllib.request.urlretrieve(url, temp_dest, reporthook=progress)
    temp_dest.replace(dest)
    print(f"\n[done] {dest}")


def labels_to_download(manifest: Path, only: list[str] | None) -> list[str]:
    entities = load_entities(manifest)
    requested = set(only or [])
    labels = [
        entity.quickdraw_label
        for entity in entities
        if not requested or entity.id in requested or entity.quickdraw_label in requested
    ]
    if requested and not labels:
        raise SystemExit(
            "No matching enabled entities or Quick Draw labels found for: "
            + ", ".join(sorted(requested))
        )
    return labels


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST_PATH)
    parser.add_argument(
        "--only",
        nargs="*",
        help="optional entity ids or Quick Draw labels to download",
    )
    args = parser.parse_args()

    DATA_DIR.mkdir(exist_ok=True)
    for category in labels_to_download(args.manifest, args.only):
        download(category)
    print("\nAll categories downloaded into", DATA_DIR)


if __name__ == "__main__":
    main()
