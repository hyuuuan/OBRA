"""The backend the game starts says why when it cannot start.

Run from the repo root:
    python -m unittest tests.test_backend_serve -v

A friend on Windows pulled the game and waited minutes for a drawing to be recognised. The game
started the server as `python -m uvicorn`, so a server that could not start -- no packages, the
wrong Python, no model -- said so to a console nobody saw, and the game could only keep
waiting. backend/serve.py checks first and writes one line the game reads back and shows.
"""

from __future__ import annotations

import io
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

REPO_ROOT = Path(__file__).resolve().parent.parent
BACKEND_DIR = REPO_ROOT / "backend"
sys.path.insert(0, str(BACKEND_DIR))

import serve  # noqa: E402

try:
    import fastapi  # noqa: F401
    import onnxruntime  # noqa: F401
    import uvicorn  # noqa: F401

    _BACKEND_READY = (REPO_ROOT / "model" / "model.onnx").exists()
except Exception:
    _BACKEND_READY = False


def _run(*args: str, env: dict[str, str] | None = None) -> tuple[int, str]:
    with tempfile.TemporaryDirectory() as folder:
        log = Path(folder) / "backend.log"
        done = subprocess.run(
            [sys.executable, str(BACKEND_DIR / "serve.py"), "--log", str(log), *args],
            env=env, timeout=120, capture_output=True, text=True,
        )
        return done.returncode, log.read_text(encoding="utf-8") if log.exists() else ""


class ProblemTests(unittest.TestCase):
    def test_missing_packages_are_named_with_the_way_to_install_them(self) -> None:
        with mock.patch.object(serve.importlib.util, "find_spec", lambda name: None):
            found = serve.problems()
        self.assertEqual(len(found), 1)
        for package in ("numpy", "onnxruntime", "fastapi", "uvicorn", "pillow"):
            self.assertIn(package, found[0])
        self.assertIn("play_windows.bat" if os.name == "nt" else "play.sh", found[0])

    def test_an_old_python_is_named(self) -> None:
        with mock.patch.object(serve.sys, "version_info", (3, 9, 0)):
            found = serve.problems()
        self.assertEqual(len(found), 1)
        self.assertIn("3.10 or newer", found[0])

    def test_a_failure_is_one_line_the_game_can_find(self) -> None:
        out = io.StringIO()
        with mock.patch.object(serve.sys, "stdout", out):
            code = serve.fail("the reason")
        self.assertEqual(code, 3)
        self.assertEqual(out.getvalue().strip(), f"{serve.FAILED} the reason")


@unittest.skipUnless(_BACKEND_READY, "backend ML dependencies or the trained model are missing")
class LaunchTests(unittest.TestCase):
    def test_check_loads_everything_and_says_ready(self) -> None:
        code, log = _run("--check")
        self.assertEqual(code, 0, log)
        self.assertIn(serve.READY, log)

    def test_a_missing_model_is_reported_not_crashed_on(self) -> None:
        env = dict(os.environ, OBRA_MODEL=str(REPO_ROOT / "model" / "no_such_model.onnx"))
        code, log = _run("--check", env=env)
        self.assertEqual(code, 3, log)
        failed = [line for line in log.splitlines() if line.startswith(serve.FAILED)]
        self.assertEqual(len(failed), 1, log)
        self.assertIn("Model not found", failed[0])


if __name__ == "__main__":
    unittest.main()
