"""The drawing panel's paper colour must not change what the model is shown.

The game draws on cream paper, not white. Before the background was zeroed in
backend/preprocess.py, the inverted paper stayed in the 28x28 frame as a faint grey
disc and every circle drawn in the game was classified "clock". These tests pin the
fix: the tensor for a drawing on cream paper matches the tensor for the same drawing
on white, and a plain circle on cream paper is read as a circle.
"""

import io
import json
import math
import sys
import unittest
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "backend"))

from preprocess import preprocess_image  # noqa: E402

CREAM = (245, 241, 230)   # the drawing panel's paper
WHITE = (255, 255, 255)


def _circle_png(paper: tuple[int, int, int]) -> bytes:
    image = Image.new("RGB", (400, 400), paper)
    draw = ImageDraw.Draw(image)
    points = [
        (200 + 120 * math.cos(2 * math.pi * i / 60), 200 + 120 * math.sin(2 * math.pi * i / 60))
        for i in range(61)
    ]
    draw.line(points, fill=(0, 0, 0), width=8, joint="curve")
    buffer = io.BytesIO()
    image.save(buffer, "PNG")
    return buffer.getvalue()


class PaperColourTest(unittest.TestCase):
    def test_the_paper_is_zero_behind_the_drawing(self):
        # Inside the ring and in the corners there is only paper. (Next to the stroke,
        # resampling leaves soft edge values; those belong to the ink.)
        tensor = preprocess_image(_circle_png(CREAM))[0, 0]
        self.assertEqual(float(tensor[10:18, 10:18].max()), 0.0,
                         "the cream paper survives inside the circle as a grey haze")
        self.assertEqual(float(tensor[0, 0]), 0.0, "and in the corner")

    def test_cream_and_white_paper_give_the_same_tensor(self):
        cream = preprocess_image(_circle_png(CREAM))
        white = preprocess_image(_circle_png(WHITE))
        self.assertLess(float(np.abs(cream - white).max()), 0.05)

    def test_a_circle_on_the_game_paper_is_a_circle(self):
        # The model is loaded directly rather than through backend/main.py: importing main
        # configures its telemetry sink at import time, which would pre-empt the telemetry
        # test's own configuration when both run in one process.
        try:
            import onnxruntime  # noqa: E402
        except Exception as error:  # pragma: no cover - environment without onnxruntime
            self.skipTest("onnxruntime not available here: %s" % error)
        session = onnxruntime.InferenceSession(str(REPO_ROOT / "model" / "model.onnx"),
                                               providers=["CPUExecutionProvider"])
        labels = json.loads((REPO_ROOT / "model" / "labels.json").read_text())
        tensor = preprocess_image(_circle_png(CREAM)).astype(np.float32)
        logits = session.run(None, {session.get_inputs()[0].name: tensor})[0][0]
        self.assertEqual(labels[int(logits.argmax())], "circle")


if __name__ == "__main__":
    unittest.main()
