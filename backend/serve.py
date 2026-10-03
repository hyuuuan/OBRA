"""Start the recognition backend for the game -- setting it up first if it has to.

The game starts this, not uvicorn directly:

    <python> backend/serve.py --host 127.0.0.1 --port 8000 --log <file>
    <python> backend/serve.py --check          # set up and load everything, report, exit

IT SETS ITSELF UP. Kent: "i want it to be automatic". Started with any Python 3.10 or newer --
the project's .venv, or whatever Python the computer has -- this makes the project's .venv if
there is none, installs the recogniser's packages into it when they are missing or
backend/requirements.txt has changed (stamped in .venv/obra-requirements.txt, the same stamp
the launchers use), and then runs itself again inside it. Pulling the game and pressing Play
is enough; play_windows.bat and play.sh still work and do the same, earlier.

IT SAYS WHAT IT IS DOING, AND WHY IT CANNOT. Everything goes to --log, which the game reads
while it waits: a line `OBRA_BACKEND_STATUS: <what is happening>` for each step it can show
the player, and on failure one `OBRA_BACKEND_FAILED: <reason>` with what to do about it.

Stdlib only until the packages are there, so a missing one is set up or reported, not crashed on.
"""

from __future__ import annotations

import argparse
import importlib.util
import os
import shutil
import subprocess
import sys
import time
import traceback
import venv
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent
REPO_ROOT = BACKEND_DIR.parent
# Overridable so the tests can set up an environment somewhere that is not the project's own.
VENV_DIR = Path(os.environ.get("OBRA_VENV", REPO_ROOT / ".venv"))
REQUIREMENTS = Path(os.environ.get("OBRA_REQUIREMENTS", BACKEND_DIR / "requirements.txt"))

# The lines the game looks for in the log. Everything after the colon is shown to the player.
FAILED = "OBRA_BACKEND_FAILED:"
STATUS = "OBRA_BACKEND_STATUS:"
READY = "OBRA_BACKEND_READY"

# Import name -> what `pip install` calls it, for the message.
REQUIRED = {
    "numpy": "numpy",
    "onnxruntime": "onnxruntime",
    "fastapi": "fastapi",
    "uvicorn": "uvicorn[standard]",
    "PIL": "pillow",
}


def venv_python(venv_dir: Path = VENV_DIR) -> Path:
    if os.name == "nt":
        return venv_dir / "Scripts" / "python.exe"
    return venv_dir / "bin" / "python"


def running_in(venv_dir: Path = VENV_DIR) -> bool:
    try:
        return Path(sys.prefix).resolve() == venv_dir.resolve()
    except OSError:
        return False


def requirements_current(venv_dir: Path = VENV_DIR, requirements: Path = REQUIREMENTS) -> bool:
    stamp = venv_dir / "obra-requirements.txt"
    return stamp.exists() and stamp.read_bytes() == requirements.read_bytes()


def missing_packages() -> list[str]:
    return [pip for module, pip in REQUIRED.items() if importlib.util.find_spec(module) is None]


def too_old() -> str:
    """Why this Python cannot be used at all, or "" when it can."""
    if sys.version_info >= (3, 10):
        return ""
    where = "python.org (on Windows, tick \"Add python.exe to PATH\")"
    return (
        f"Python 3.10 or newer is needed and this is {sys.version.split()[0]} "
        f"({sys.executable}). Install it from {where}, then start the game again."
    )


def problems() -> list[str]:
    """Every reason this Python cannot serve, as a sentence each. Empty when it can."""
    old = too_old()
    if old:
        return [old]
    missing = missing_packages()
    if missing:
        return [f"{sys.executable} is missing {', '.join(missing)}, and setting them up did not "
                f"put them there."]
    return []


def status(message: str) -> None:
    print(f"{STATUS} {message}", flush=True)


def fail(message: str) -> int:
    print(f"{FAILED} {message}", flush=True)
    return 3


def ensure_environment(venv_dir: Path = VENV_DIR,
                       requirements: Path = REQUIREMENTS) -> tuple[str, bool]:
    """Make the venv and install its packages, if either is needed.

    Returns (why it could not, whether anything was installed); the reason is "" on success.
    """
    python = venv_python(venv_dir)
    changed = False
    if not python.exists():
        status("Making a Python environment for the drawing recogniser -- first time on this "
               "computer")
        try:
            venv.EnvBuilder(with_pip=True).create(str(venv_dir))
        except Exception as error:  # noqa: BLE001 -- a reason to report
            return f"could not make the Python environment at {venv_dir}: {error}", False
        if not python.exists():
            return f"made {venv_dir}, but it has no Python at {python}", False
        changed = True
    if not requirements_current(venv_dir, requirements):
        status("Installing the drawing recogniser's packages -- the first time on a computer "
               "takes a few minutes")
        done = subprocess.run(
            [str(python), "-m", "pip", "install", "--disable-pip-version-check",
             "-r", str(requirements)],
            stdout=sys.stdout, stderr=sys.stdout,
        )
        if done.returncode != 0:
            return ("installing the recogniser's packages failed (pip exited "
                    f"{done.returncode}). Is this computer online? The lines above say what "
                    "pip said."), False
        shutil.copyfile(requirements, venv_dir / "obra-requirements.txt")
        changed = True
    return "", changed


def _log_to(path: str | None, append: bool = False) -> None:
    if not path:
        return
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    stream = open(path, "a" if append else "w", encoding="utf-8", buffering=1)  # noqa: SIM115
    sys.stdout = stream
    sys.stderr = stream


def main(argv: list[str] | None = None) -> int:
    raw = list(sys.argv[1:] if argv is None else argv)
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8000)
    parser.add_argument("--log", default=None, help="write everything here instead of the console")
    parser.add_argument("--append-log", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--check", action="store_true", help="set up, load the model, report, exit")
    parser.add_argument("--no-setup", action="store_true",
                        help="do not make or update .venv; serve with this Python as it is")
    args = parser.parse_args(raw)
    _log_to(args.log, args.append_log)

    started = time.perf_counter()
    print(f"O.B.R.A. backend: Python {sys.version.split()[0]} at {sys.executable}", flush=True)
    old = too_old()
    if old:
        return fail(old)

    if not args.no_setup:
        reason, changed = ensure_environment()
        if reason:
            return fail(reason)
        # In the project's environment, as it now is: run again there. Also after installing
        # into the one this is already running in, so nothing is imported half-installed.
        if changed or not running_in():
            again = [str(venv_python()), str(Path(__file__).resolve()), *raw, "--no-setup"]
            if args.log:
                again.append("--append-log")
            sys.stdout.flush()
            return subprocess.run(again).returncode

    status("Starting the drawing recogniser")
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
