"""Tests for backend recognition telemetry.

Run from the repo root:
    python -m unittest tests.test_backend_telemetry -v

The TelemetryWriter tests are dependency-free. The /predict integration test is
skipped automatically when the backend ML dependencies or the trained model are
unavailable, so this module always runs cleanly.
"""

from __future__ import annotations

import base64
import io
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
BACKEND_DIR = REPO_ROOT / "backend"
sys.path.insert(0, str(BACKEND_DIR))
sys.path.insert(0, str(REPO_ROOT))

from telemetry import TelemetryWriter  # noqa: E402  (backend/telemetry.py, stdlib only)

MODEL_PATH = REPO_ROOT / "model" / "model.onnx"

try:
    import fastapi  # noqa: F401
    import numpy  # noqa: F401
    import onnxruntime  # noqa: F401
    from PIL import Image  # noqa: F401

    _BACKEND_READY = True
except Exception:
    _BACKEND_READY = False


def _sample_record() -> dict:
    return {
        "source_label": "frog",
        "entity": "frog",
        "confidence": 0.91,
        "margin": 0.4,
        "runner_up": {"entity": "bird", "confidence": 0.2},
        "timing_ms": {"infer_ms": 8.0, "total_ms": 40.0},
    }


class TelemetryWriterTest(unittest.TestCase):
    def test_disabled_writes_nothing(self):
        with tempfile.TemporaryDirectory() as directory:
            TelemetryWriter(Path(directory), enabled=False).record_prediction(_sample_record())
            self.assertEqual(list(Path(directory).glob("*.jsonl")), [])

    def test_enabled_appends_anonymous_records(self):
        with tempfile.TemporaryDirectory() as directory:
            writer = TelemetryWriter(Path(directory), enabled=True)
            writer.record_prediction(_sample_record())
            writer.record_prediction(_sample_record())
            logs = list(Path(directory).glob("backend_*.jsonl"))
            self.assertEqual(len(logs), 1)
            lines = logs[0].read_text().strip().splitlines()
            self.assertEqual(len(lines), 2)
            record = json.loads(lines[0])
            self.assertEqual(record["entity"], "frog")
            self.assertIn("ts", record)  # timestamp auto-stamped
            self.assertIn("timing_ms", record)
            for identifying in ("ip", "user", "user_id", "session_id", "image_data"):
                self.assertNotIn(identifying, record)

    def test_best_effort_never_raises(self):
        with tempfile.TemporaryDirectory() as directory:
            writer = TelemetryWriter(Path(directory), enabled=True)
            # A non-serialisable value must be swallowed, not propagated.
            writer.record_prediction({"bad": {1, 2, 3}})
            logs = list(Path(directory).glob("backend_*.jsonl"))
            if logs:
                self.assertEqual(logs[0].read_text().strip(), "")

    def test_from_env(self):
        with tempfile.TemporaryDirectory() as directory:
            os.environ["OBRA_TELEMETRY"] = "1"
            os.environ["OBRA_TELEMETRY_DIR"] = directory
            try:
                writer = TelemetryWriter.from_env(REPO_ROOT / "telemetry")
                self.assertTrue(writer.enabled)
                self.assertEqual(writer.directory, Path(directory))
            finally:
                os.environ.pop("OBRA_TELEMETRY", None)
                os.environ.pop("OBRA_TELEMETRY_DIR", None)


@unittest.skipUnless(
    _BACKEND_READY and MODEL_PATH.exists(),
    "backend ML dependencies or trained model unavailable",
)
class PredictTelemetryTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls._tmp = tempfile.TemporaryDirectory()
        os.environ["OBRA_TELEMETRY"] = "1"
        os.environ["OBRA_TELEMETRY_DIR"] = cls._tmp.name
        import importlib

        cls.main = importlib.import_module("main")

    @classmethod
    def tearDownClass(cls):
        os.environ.pop("OBRA_TELEMETRY", None)
        os.environ.pop("OBRA_TELEMETRY_DIR", None)
        cls._tmp.cleanup()

    @staticmethod
    def _sample_png_b64() -> str:
        from PIL import Image, ImageDraw

        image = Image.new("RGB", (280, 280), "white")
        draw = ImageDraw.Draw(image)
        draw.rectangle([70, 70, 210, 210], fill="black")
        draw.line([70, 70, 210, 210], fill="black", width=8)
        buffer = io.BytesIO()
        image.save(buffer, format="PNG")
        return base64.b64encode(buffer.getvalue()).decode("ascii")

    def test_predict_writes_telemetry_and_returns_timing(self):
        main = self.main
        response = main.predict(main.DrawingPayload(image_data=self._sample_png_b64()))
        for key in ("entity", "confidence", "margin", "timing"):
            self.assertIn(key, response)
        for key in ("decode_ms", "preprocess_ms", "infer_ms", "total_ms"):
            self.assertIn(key, response["timing"])
        self.assertGreaterEqual(response["confidence"], 0.0)
        self.assertLessEqual(response["confidence"], 1.0)

        logs = list(Path(self._tmp.name).glob("backend_*.jsonl"))
        self.assertEqual(len(logs), 1)
        record = json.loads(logs[0].read_text().strip().splitlines()[-1])
        for key in ("source_label", "entity", "confidence", "margin", "timing_ms", "ts"):
            self.assertIn(key, record)


if __name__ == "__main__":
    unittest.main()
