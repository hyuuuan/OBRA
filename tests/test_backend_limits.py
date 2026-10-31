"""The recogniser refuses a request too large to be a drawing, and still takes a real one.

Thesis §4.10.2 verifies "request-size limits"; there was none. A 512 px canvas is a few
hundred kilobytes; the limit sits far above that and below anything that would tie the
recogniser up decoding it.

    python -m unittest -v tests.test_backend_limits
"""

import base64
import importlib
import importlib.util
import io
import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
BACKEND_DIR = REPO_ROOT / "backend"
MODEL_PATH = REPO_ROOT / "model" / "model.onnx"
_BACKEND_READY = all(
    importlib.util.find_spec(name) is not None
    for name in ("numpy", "onnxruntime", "fastapi", "PIL")
)


@unittest.skipUnless(
    _BACKEND_READY and MODEL_PATH.exists(),
    "backend ML dependencies or trained model unavailable",
)
class BackendLimitTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        sys.path.insert(0, str(BACKEND_DIR))
        cls.main = importlib.import_module("main")

    @classmethod
    def tearDownClass(cls):
        # ⚠ main reads OBRA_TELEMETRY once, at import. Left in sys.modules, this copy --
        # imported with telemetry off -- is the one test_backend_telemetry would get, and its
        # predict would write nothing.
        sys.modules.pop("main", None)

    def test_an_oversized_request_is_refused_before_decoding(self):
        from fastapi import HTTPException

        main = self.main
        payload = main.DrawingPayload(image_data="A" * (main.MAX_IMAGE_DATA_CHARS + 1))
        with self.assertRaises(HTTPException) as caught:
            main.predict(payload)
        self.assertEqual(caught.exception.status_code, 413)

    def test_a_full_canvas_is_well_inside_the_limit(self):
        from PIL import Image

        # The worst a player can send: the game's 512 px canvas filled with noise, which
        # PNG cannot compress.
        import numpy as np

        noise = np.random.default_rng(0).integers(0, 255, (512, 512, 4), dtype=np.uint8)
        buffer = io.BytesIO()
        Image.fromarray(noise, "RGBA").save(buffer, format="PNG")
        encoded = base64.b64encode(buffer.getvalue()).decode("ascii")
        self.assertLess(len(encoded), self.main.MAX_IMAGE_DATA_CHARS)
        response = self.main.predict(self.main.DrawingPayload(image_data=encoded))
        self.assertIn("entity", response)


if __name__ == "__main__":
    unittest.main()
