"""The backend the game starts says why when it cannot start.

Run from the repo root:
    python -m unittest tests.test_backend_serve -v

A friend on Windows pulled the game and waited minutes for a drawing to be recognised. The game
started the server as `python -m uvicorn`, so a server that could not start -- no packages, the
wrong Python, no model -- said so to a console nobody saw, and the game could only keep
waiting. backend/serve.py checks first and writes one line the game reads back and shows.

And it sets itself up (Kent: "i want it to be automatic"): started with any Python 3.10+, it
makes the project's .venv and installs the packages, then runs itself again inside it. The
setup tests run that against a throwaway environment and a requirements file pip can satisfy
without a network, so they say nothing about the real packages -- only about the steps.
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
    def test_missing_packages_are_named(self) -> None:
        with mock.patch.object(serve.importlib.util, "find_spec", lambda name: None):
            found = serve.problems()
        self.assertEqual(len(found), 1)
        for package in ("numpy", "onnxruntime", "fastapi", "uvicorn", "pillow"):
            self.assertIn(package, found[0])

    def test_an_old_python_is_named_with_where_to_get_one(self) -> None:
        with mock.patch.object(serve.sys, "version_info", (3, 9, 0)):
            found = serve.problems()
        self.assertEqual(len(found), 1)
        self.assertIn("3.10 or newer", found[0])
        self.assertIn("python.org", found[0])

    def test_a_failure_is_one_line_the_game_can_find(self) -> None:
        out = io.StringIO()
        with mock.patch.object(serve.sys, "stdout", out):
            code = serve.fail("the reason")
        self.assertEqual(code, 3)
        self.assertEqual(out.getvalue().strip(), f"{serve.FAILED} the reason")


class _InAThrowawayFolder(unittest.TestCase):
    """A .venv and a requirements file in a folder of their own, never the project's."""

    def setUp(self) -> None:
        self.folder = tempfile.TemporaryDirectory()
        root = Path(self.folder.name)
        self.venv = root / ".venv"
        self.requirements = root / "requirements.txt"
        # pip is in every fresh venv, so this is satisfied without a network.
        self.requirements.write_text("pip\n", encoding="utf-8")
        self.env = dict(os.environ, OBRA_VENV=str(self.venv),
                        OBRA_REQUIREMENTS=str(self.requirements))
        self.env.pop("OBRA_GAME_PID", None)

    def tearDown(self) -> None:
        self.folder.cleanup()

    def _python(self) -> Path:
        return self.venv / ("Scripts/python.exe" if os.name == "nt" else "bin/python")


class SetupTests(_InAThrowawayFolder):
    """Pull the game, press Play: the environment is made and filled by the first start."""

    def test_the_first_start_makes_the_environment_and_runs_inside_it(self) -> None:
        code, log = _run("--check", env=self.env)
        self.assertTrue(self._python().exists(), log)
        self.assertEqual((self.venv / "obra-requirements.txt").read_text(encoding="utf-8"), "pip\n")
        self.assertIn(f"{serve.STATUS} Making a Python environment", log)
        self.assertIn(f"{serve.STATUS} Installing the drawing recogniser's packages", log)
        # Run again, inside it: the second header names the new environment's Python.
        headers = [line for line in log.splitlines() if line.startswith("O.B.R.A. backend:")]
        self.assertEqual(len(headers), 2, log)
        self.assertIn(str(self.venv), headers[1])
        # This throwaway one has none of the real packages, and says so rather than crashing.
        self.assertEqual(code, 3, log)
        self.assertIn("numpy", [line for line in log.splitlines() if line.startswith(serve.FAILED)][0])

    def test_an_environment_already_set_up_is_left_alone(self) -> None:
        _run("--check", env=self.env)
        _code, log = _run("--check", env=self.env)
        self.assertNotIn("Making a Python environment", log)
        self.assertNotIn("Installing the drawing recogniser's packages", log)

    def test_changed_requirements_are_installed_again(self) -> None:
        _run("--check", env=self.env)
        self.requirements.write_text("pip\n# changed upstream\n", encoding="utf-8")
        _code, log = _run("--check", env=self.env)
        self.assertNotIn("Making a Python environment", log)
        self.assertIn("Installing the drawing recogniser's packages", log)
        self.assertEqual((self.venv / "obra-requirements.txt").read_text(encoding="utf-8"),
                         "pip\n# changed upstream\n")


class StaleEnvironmentTests(_InAThrowawayFolder):
    """A .venv that is there but cannot serve is set aside and made again, not used forever.

    A teammate's .venv had been made with macOS's Python 3.9: every start failed with "3.10 or
    newer is needed" on a computer that had 3.12, because only "is there a python" was asked.
    """

    def _old_venv(self, python_body: str | None) -> Path:
        marker = self.venv / "made-by-an-old-python"
        marker.parent.mkdir(parents=True)
        marker.write_text("keep me\n", encoding="utf-8")
        if python_body is not None:
            python = self._python()
            python.parent.mkdir(parents=True)
            python.write_text(f"#!/bin/sh\n{python_body}\n", encoding="utf-8")
            python.chmod(0o755)
        return marker

    def _check_rebuilt(self, log: str) -> None:
        self.assertIn(f"{serve.STATUS} The Python environment here is too old or broken", log)
        self.assertIn(f"{serve.STATUS} Making a Python environment", log)
        self.assertTrue(serve.usable(self._python()), log)
        kept = list((Path(self.folder.name) / "venv").glob("previous.*/.venv/made-by-an-old-python"))
        self.assertEqual(len(kept), 1, log)
        self.assertEqual(kept[0].read_text(encoding="utf-8"), "keep me\n")

    @unittest.skipIf(os.name == "nt", "the stand-in Python is a shell script")
    def test_a_venv_whose_python_is_too_old_is_set_aside_and_made_again(self) -> None:
        # Exits 1 to the version question, as Python 3.9 does.
        self._old_venv("exit 1")
        self.assertFalse(serve.usable(self._python()))
        _code, log = _run("--check", env=self.env)
        self._check_rebuilt(log)

    def test_a_venv_with_no_python_left_in_it_is_set_aside_and_made_again(self) -> None:
        # What a Python removed or upgraded out from under its venv leaves behind.
        self._old_venv(None)
        _code, log = _run("--check", env=self.env)
        self._check_rebuilt(log)

    def test_a_venv_that_can_serve_is_not_touched(self) -> None:
        _run("--check", env=self.env)
        _code, log = _run("--check", env=self.env)
        self.assertNotIn("too old or broken", log)
        self.assertFalse((Path(self.folder.name) / "venv").exists())


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
