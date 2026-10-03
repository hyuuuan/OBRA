"""Start the recognition backend for the game -- or write down exactly why it cannot.

The game starts this, not uvicorn directly:

    <python> backend/serve.py --host 127.0.0.1 --port 8000 --log <file>
    <python> backend/serve.py --check          # load everything, report, exit

Started straight as `python -m uvicorn`, a backend that could not start said so to a console
nobody could see. On Windows that was every first run without the packages, and every run
with the venv missing: the game waited, and the player waited with it, with no way to know
the wait would never end. This checks what it needs first, in plain words, writes everything
to --log (which the game reads back when the process stops), and only then serves.

Stdlib only until the checks pass, so a missing package is reported rather than crashed on.
"""

from __future__ import annotations

import argparse
import importlib.util
import os
import sys
import time
import traceback
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent
REPO_ROOT = BACKEND_DIR.parent

# The line the game looks for in the log. Everything after the colon is shown to the player.
FAILED = "OBRA_BACKEND_FAILED:"
READY = "OBRA_BACKEND_READY"

# Import name -> what `pip install` calls it, for the message.
REQUIRED = {
    "numpy": "numpy",
    "onnxruntime": "onnxruntime",
    "fastapi": "fastapi",
    "uvicorn": "uvicorn[standard]",
    "PIL": "pillow",
}


def setup_hint() -> str:
    """How to install the packages, on this platform."""
    if os.name == "nt":
        return "Run play_windows.bat once -- it sets up .venv with what the recogniser needs."
    return "Run ./play.sh once -- it sets up .venv with what the recogniser needs."


def missing_packages() -> list[str]:
    return [pip for module, pip in REQUIRED.items() if importlib.util.find_spec(module) is None]


def problems() -> list[str]:
    """Every reason this Python cannot serve, as a sentence each. Empty when it can."""
    found: list[str] = []
    if sys.version_info < (3, 10):
        found.append(
            f"Python 3.10 or newer is needed and this is {sys.version.split()[0]} "
            f"({sys.executable}). Install a newer Python, then: {setup_hint()}"
        )
        return found
    missing = missing_packages()
    if missing:
        in_venv = sys.prefix != getattr(sys, "base_prefix", sys.prefix)
        where = "the .venv" if in_venv else f"this Python ({sys.executable}), which is not the project's .venv"
        found.append(f"{where} is missing {', '.join(missing)}. {setup_hint()}")
    return found


def _log_to(path: str | None) -> None:
    if not path:
        return
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    stream = open(path, "w", encoding="utf-8", buffering=1)  # noqa: SIM115 -- lives as long as we do
    sys.stdout = stream
    sys.stderr = stream


def fail(message: str) -> int:
    print(f"{FAILED} {message}", flush=True)
    return 3


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8000)
    parser.add_argument("--log", default=None, help="write everything here instead of the console")
    parser.add_argument("--check", action="store_true", help="load the model, report, and exit")
    args = parser.parse_args(argv)
    _log_to(args.log)

    started = time.perf_counter()
    print(f"O.B.R.A. backend: Python {sys.version.split()[0]} at {sys.executable}", flush=True)
    for problem in problems():
        return fail(problem)

    sys.path.insert(0, str(BACKEND_DIR))
    sys.path.insert(0, str(REPO_ROOT))
    try:
        import main as app_module  # the model, the labels and the entity table load here
    except SystemExit as stop:  # main.py says what is missing this way: the model, the labels
        return fail(str(stop.code) if stop.code not in (None, 0) else "the backend stopped while loading")
    except Exception as error:  # noqa: BLE001 -- anything here is a reason to report, not a crash
        traceback.print_exc()
        return fail(f"loading the recogniser failed: {type(error).__name__}: {error}")
    print(f"Loaded in {time.perf_counter() - started:.1f} s", flush=True)

    if args.check:
        print(READY, flush=True)
        return 0

    import uvicorn

    try:
        uvicorn.run(app_module.app, host=args.host, port=args.port, log_level="warning")
    except SystemExit as stop:  # uvicorn exits this way when it cannot bind
        return fail(f"could not listen on {args.host}:{args.port} (exit {stop.code})")
    except OSError as error:
        return fail(f"could not listen on {args.host}:{args.port}: {error}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
