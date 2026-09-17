"""Turn an arbitrary sketch image into the tensor format the CNN was trained on.

The Quick, Draw! training bitmaps are 28x28 grayscale with WHITE ink on a BLACK
background, and the drawing roughly fills the frame. A live Godot canvas (or a
TU-Berlin test image) is typically dark ink on a white background at some other
resolution — so we invert, crop to the ink, and rescale to match.

Used by both the FastAPI backend and model/evaluate_folder.py. Keeping this in one
place guarantees the game and the thesis evaluation see identical preprocessing.
"""

import io

import numpy as np
from PIL import Image

INK_THRESHOLD = 32  # pixels brighter than this (after inversion) count as ink
TARGET_INK_SIZE = 26  # longest side of the drawing inside the 28x28 frame


class EmptyCanvasError(ValueError):
    """Raised when the image contains no visible ink."""


def canonicalize_ink(arr: np.ndarray) -> np.ndarray:
    """Crop a WHITE-on-BLACK grayscale array to its ink, rescale so the longest side
    is TARGET_INK_SIZE, and center it in a 28x28 frame. Returns float32 (28, 28) in
    [0, 1].

    This is the single canonical framing used by BOTH inference (via
    ``preprocess_image``) and training (``model/train_quickdraw.py``). Training on the
    same framing the backend produces is what keeps the live game in-distribution.
    """
    arr = np.asarray(arr, dtype=np.float32)
    ink_rows, ink_cols = np.where(arr > INK_THRESHOLD)
    if ink_rows.size == 0:
        raise EmptyCanvasError("no ink found in the image")

    arr = arr[ink_rows.min():ink_rows.max() + 1, ink_cols.min():ink_cols.max() + 1]

    height, width = arr.shape
    scale = TARGET_INK_SIZE / max(height, width)
    resized = Image.fromarray(arr.astype(np.uint8)).resize(
        (max(1, round(width * scale)), max(1, round(height * scale))),
        Image.Resampling.BILINEAR,
    )

    canvas = Image.new("L", (28, 28), color=0)
    canvas.paste(resized, ((28 - resized.width) // 2, (28 - resized.height) // 2))
    return np.asarray(canvas, dtype=np.float32) / 255.0


def preprocess_image(image_bytes: bytes) -> np.ndarray:
    """PNG/JPEG bytes -> float32 array of shape (1, 1, 28, 28), values in [0, 1]."""
    img = Image.open(io.BytesIO(image_bytes)).convert("L")
    arr = np.asarray(img, dtype=np.float32)

    # Quick Draw is white-on-black; a drawing canvas is usually black-on-white.
    if arr.mean() > 127:
        arr = 255.0 - arr

    # THE PAPER IS NOT INK. Quick, Draw! bitmaps are white strokes on exactly zero, and the
    # model has never seen anything else behind a drawing. The game's drawing panel is cream
    # rather than white, so after inversion its paper is a faint grey (about 14 of 255) --
    # below INK_THRESHOLD, so the crop was right, but it stayed in the frame and filled the
    # whole 26x26 square the drawing is pasted into. An empty ring on a faint disc reads to
    # this model as a clock face: every circle drawn in the game came back "clock" at 85-99%,
    # which made Payyo's first puzzle (draw something that can roll) fail for the most natural
    # answer. The same haze pushed squares toward "door".
    #
    # Anything below the ink threshold is background, and background is zero -- the same
    # threshold the crop already uses to decide what ink is. Measured on 2,000 held-back Quick,
    # Draw! drawings put on the game's cream paper: 82.9% top-1 with the haze, 87.1% without,
    # against 87.0% for the same drawings on pure white. Circles 0/40 -> 37/40, squares 19/40
    # -> 40/40. On white paper, and on TU-Berlin's white PNGs, the background is already zero
    # and this changes nothing but the faintest anti-aliased edge pixels.
    #
    # Training calls canonicalize_ink on bitmaps that are already zero behind the strokes, so
    # it is untouched; serving and evaluate_folder.py both come through here, so the game and
    # the thesis evaluation still see identical preprocessing (NFR-4).
    arr = np.where(arr > INK_THRESHOLD, arr, 0.0)

    return canonicalize_ink(arr).reshape(1, 1, 28, 28)
