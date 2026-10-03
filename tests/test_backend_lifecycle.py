"""A backend the game started must not outlive the game.

Run from the repo root:
    python -m unittest tests.test_backend_lifecycle -v

A server left running on port 8000 after the game had gone served the old preprocessing for
eighteen days, and the game used it because it answered. These tests stand in for the game
with a short-lived process, start a server that names it in OBRA_GAME_PID, end the "game",
and require the server to be gone a few seconds later -- first the watcher on its own, then
the real uvicorn server the game launches, so the watcher is proven to run in the process
that holds the port. The last test is skipped when the ML stack or the model is missing.
"""

from __future__ import annotations

import os
import socket
import subprocess
import sys
import textwrap
import time
import unittest
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
BACKEND_DIR = REPO_ROOT / "backend"
MODEL_PATH = REPO_ROOT / "model" / "model.onnx"

try:
    import fastapi  # noqa: F401
    import onnxruntime  # noqa: F401
    import uvicorn  # noqa: F401

    _BACKEND_READY = MODEL_PATH.exists()
except Exception:
    _BACKEND_READY = False


def _fake_game() -> subprocess.Popen:
    """A process that stays up until it is told to stop, like a game until it is closed."""
    return subprocess.Popen(
        [sys.executable, "-c", "import time; time.sleep(120)"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def _env_naming(game: subprocess.Popen | None) -> dict[str, str]:
    env = dict(os.environ)
    env.pop("OBRA_GAME_PID", None)
    if game is not None:
        env["OBRA_GAME_PID"] = str(game.pid)
    return env


def _ended_within(process: subprocess.Popen, seconds: float) -> bool:
    try:
        process.wait(timeout=seconds)
        return True
    except subprocess.TimeoutExpired:
        return False


def _stop(*processes: subprocess.Popen) -> None:
    for process in processes:
        if process.poll() is None:
            process.kill()
            process.wait()


class WatcherTests(unittest.TestCase):
    SERVER = textwrap.dedent(
        f"""
        import sys, time
        sys.path.insert(0, {str(BACKEND_DIR)!r})
        from lifecycle import exit_with_the_game
        exit_with_the_game(every=0.1)
        time.sleep(60)
        """
    )

    def test_a_server_the_game_started_ends_when_the_game_does(self) -> None:
        game = _fake_game()
        server = subprocess.Popen([sys.executable, "-c", self.SERVER], env=_env_naming(game))
        try:
            time.sleep(0.5)
            self.assertIsNone(server.poll(), "the server exited while the game was still up")
            game.kill()
            game.wait()
            self.assertTrue(_ended_within(server, 5.0), "the server outlived the game")
            self.assertEqual(server.returncode, 0)
        finally:
            _stop(server, game)

    def test_a_server_started_by_hand_is_left_alone(self) -> None:
        # The control: with no game named, the same script must still be running after
        # the "game" has gone. Without this the first test would pass for a server that
        # simply exits on its own.
        game = _fake_game()
        server = subprocess.Popen([sys.executable, "-c", self.SERVER], env=_env_naming(None))
        try:
            game.kill()
            game.wait()
            self.assertFalse(_ended_within(server, 1.5), "a server nobody named a game for exited")
        finally:
            _stop(server, game)


def _free_port() -> int:
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


@unittest.skipUnless(_BACKEND_READY, "backend ML dependencies or the trained model are missing")
class RealServerTests(unittest.TestCase):
    def test_the_real_backend_exits_when_the_game_does(self) -> None:
        port = _free_port()
        game = _fake_game()
        # Launched the way the game launches it: backend/serve.py, not uvicorn directly.
        server = subprocess.Popen(
            [sys.executable, str(BACKEND_DIR / "serve.py"), "--host", "127.0.0.1", "--port", str(port)],
            env=_env_naming(game),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        try:
            deadline = time.monotonic() + 60.0
            answered = False
            while time.monotonic() < deadline and server.poll() is None:
                try:
                    with urllib.request.urlopen(f"http://127.0.0.1:{port}/", timeout=1.0) as reply:
                        answered = reply.status == 200
                        break
                except OSError:
                    time.sleep(0.25)
            self.assertTrue(answered, "the backend never came up")
            game.kill()
            game.wait()
            self.assertTrue(_ended_within(server, 8.0), "the backend outlived the game")
        finally:
            _stop(server, game)


class _FakeKernel32:
    """Stands in for Windows' kernel32 so the Windows probe can be tested anywhere."""

    def __init__(self, handle: int, error: int = 0, wait: int = 0x102) -> None:
        self.handle, self.error, self.wait = handle, error, wait
        self.closed: list[int] = []

    def OpenProcess(self, _access: int, _inherit: bool, _pid: int) -> int:  # noqa: N802
        return self.handle

    def GetLastError(self) -> int:  # noqa: N802
        return self.error

    def WaitForSingleObject(self, _handle: int, _ms: int) -> int:  # noqa: N802
        return self.wait

    def CloseHandle(self, handle: int) -> None:  # noqa: N802
        self.closed.append(handle)


class WindowsProbeTests(unittest.TestCase):
    """os.kill(pid, 0) sends Ctrl+C on Windows, so there the game is looked for through the
    Win32 process API instead. Run here against a stand-in, because the CI is not Windows."""

    def setUp(self) -> None:
        sys.path.insert(0, str(BACKEND_DIR))
        import lifecycle

        self.lifecycle = lifecycle

    def test_a_running_game_is_running(self) -> None:
        kernel = _FakeKernel32(handle=42, wait=0x102)  # WAIT_TIMEOUT: not finished
        self.assertTrue(self.lifecycle._exists_on_windows(1234, kernel))
        self.assertEqual(kernel.closed, [42], "the handle was not closed")

    def test_a_finished_game_is_gone(self) -> None:
        kernel = _FakeKernel32(handle=42, wait=0)  # WAIT_OBJECT_0: it has exited
        self.assertFalse(self.lifecycle._exists_on_windows(1234, kernel))
        self.assertEqual(kernel.closed, [42])

    def test_a_game_that_cannot_be_opened_is_gone(self) -> None:
        kernel = _FakeKernel32(handle=0, error=87)  # ERROR_INVALID_PARAMETER: no such process
        self.assertFalse(self.lifecycle._exists_on_windows(1234, kernel))

    def test_a_game_owned_by_someone_else_is_still_there(self) -> None:
        kernel = _FakeKernel32(handle=0, error=5)  # ERROR_ACCESS_DENIED: it exists
        self.assertTrue(self.lifecycle._exists_on_windows(1234, kernel))


if __name__ == "__main__":
    unittest.main()
