"""Fetch Quick, Draw! drawings the model never saw, for every roster class, without
downloading the full files.

Training read only rows [:40,000] of each class (train_quickdraw.DEFAULT_SAMPLES_PER_CLASS),
so rows from 40,000 on are unseen. Each class's .npy is ~100 MB; this reads its header and
then just the 200 rows wanted, by HTTP byte range: about 160 KB a class, 8 MB for all 50.
player_simulation.py draws its players' drawings from these.

    python model/fetch_unseen_quickdraw.py             # into model/data/quickdraw_unseen/
"""

import argparse
import ast
import json
import urllib.parse
import urllib.request
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
BASE_URL = "https://storage.googleapis.com/quickdraw_dataset/full/numpy_bitmap/"
ROW = 784  # 28 x 28 uint8


def _range(url: str, first: int, last: int) -> bytes:
    request = urllib.request.Request(url, headers={"Range": f"bytes={first}-{last}"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read()


def fetch(label: str, start: int, count: int) -> np.ndarray:
    url = BASE_URL + urllib.parse.quote(label) + ".npy"
    head = _range(url, 0, 255)
    if head[:6] != b"\x93NUMPY":
        raise SystemExit(f"{label}: not a .npy file")
    header_len = int.from_bytes(head[8:10], "little")  # format version 1.0
    header = ast.literal_eval(head[10:10 + header_len].decode("latin1"))
    if header["descr"] != "|u1" or header["shape"][1] != ROW:
        raise SystemExit(f"{label}: unexpected layout {header}")
    if header["shape"][0] < start + count:
        raise SystemExit(f"{label}: only {header['shape'][0]} drawings")
    offset = 10 + header_len + start * ROW
    data = _range(url, offset, offset + count * ROW - 1)
    if len(data) != count * ROW:
        raise SystemExit(f"{label}: short read")
    return np.frombuffer(data, dtype=np.uint8).reshape(count, ROW)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=HERE / "data" / "quickdraw_unseen")
    parser.add_argument("--start", type=int, default=40_000)
    parser.add_argument("--count", type=int, default=200)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    for label in json.loads((HERE / "labels.json").read_text()):
        dest = args.out / f"{label}.npy"
        if dest.exists():
            continue
        np.save(dest, fetch(label, args.start, args.count))
        print("fetched", label)


if __name__ == "__main__":
    main()
