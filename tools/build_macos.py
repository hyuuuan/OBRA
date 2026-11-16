#!/usr/bin/env python3
"""Build a self-contained macOS playtest package with local telemetry collection.

    .venv/bin/python tools/build_macos.py            # export, assemble, zip
    .venv/bin/python tools/build_macos.py --no-zip   # the folder only

Writes build/macos/OBRA/ and build/macos/OBRA-macos.zip; build/ is gitignored.

⚠ IT CARRIES ITS OWN PYTHON, as the Windows build does. The package's .venv used to be a venv made
from whatever Python built it -- on the development Mac, Homebrew's -- and a venv is only a pointer
to the Python it was made from, so on a Mac without that same Homebrew Python the drawing
recogniser could not start. It is now python-build-standalone's relocatable CPython for Apple
Silicon, unpacked as .venv: a whole Python that runs from any folder, at .venv/bin/python where
BackendSupervisor.python_in looks. serve.py sees it is already running in the project's .venv
(its sys.prefix is .venv) and serves without relaunching, and .venv/obra-requirements.txt is
stamped as serve.py stamps it, so it never runs pip on a player's Mac. Apple Silicon only, on
Kent's decision (2026-11-16): an Intel Mac would need a second Python and a second set of packages.
"""

from __future__ import annotations

import argparse
import hashlib
import shutil
import subprocess
import sys
import tarfile
import urllib.request
import zipfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
BUILD = REPO / "build" / "macos"
PACKAGE = BUILD / "OBRA"
CACHE = REPO / "build" / "macos-cache"
MODEL_FILES = ("model.onnx", "labels.json", "model_metadata.json")

## The Python the package carries: python-build-standalone (the relocatable builds uv uses),
## CPython 3.12 like the Windows build, from a release three weeks old when it was chosen.
PYTHON_VERSION = "3.12.16"
PYTHON_RELEASE = "20261026"
PYTHON_ARCHIVE = f"cpython-{PYTHON_VERSION}+{PYTHON_RELEASE}-aarch64-apple-darwin-install_only.tar.gz"
PYTHON_URL = ("https://github.com/astral-sh/python-build-standalone/releases/download/"
              f"{PYTHON_RELEASE}/{PYTHON_ARCHIVE.replace('+', '%2B')}")
## ⚠ PINNED: GitHub's own SHA-256 for that file. A download that does not match is refused, not used.
PYTHON_SHA256 = "fbf4afef53c2a6b72bb741bc06d5671a9dfaf87bd84e5aa73ac9b3d0d589f14e"
## Where a Mac-only Python or library lives. Nothing the package carries may point there.
FOREIGN_PREFIXES = ("/opt/homebrew", "/usr/local", "/Library/Frameworks/Python.framework")

sys.path.insert(0, str(REPO))
from shared.entities import load_entities, res_path_to_filesystem  # noqa: E402


def run(command: list[str]) -> None:
    print("+", " ".join(command), flush=True)
    subprocess.run(command, check=True)


def godot() -> str:
    found = shutil.which("godot") or "/Applications/Godot.app/Contents/MacOS/Godot"
    if not Path(found).is_file():
        raise SystemExit("Godot 4.7 is required; set GODOT to its executable.")
    return found


def export_game() -> None:
    (PACKAGE / "game").mkdir(parents=True, exist_ok=True)
    run([godot(), "--headless", "--path", str(REPO / "game"),
         "--export-release", "macOS", str(PACKAGE / "game" / "OBRA.app")])


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def fetch_python() -> Path:
    archive = CACHE / PYTHON_ARCHIVE
    if not archive.exists():
        CACHE.mkdir(parents=True, exist_ok=True)
        print(f"Downloading Python {PYTHON_VERSION} (python-build-standalone {PYTHON_RELEASE}) ...",
              flush=True)
        partial = archive.with_suffix(".part")
        with urllib.request.urlopen(PYTHON_URL) as response, open(partial, "wb") as out:
            shutil.copyfileobj(response, out)
        partial.rename(archive)
    digest = sha256(archive)
    if digest != PYTHON_SHA256:
        archive.unlink()
        raise SystemExit(f"{archive.name} is not the file recorded (sha256 {digest}); refusing it.")
    print(f"{archive.name} sha256 {digest}")
    return archive


def build_venv() -> None:
    target = PACKAGE / ".venv"
    unpacked = PACKAGE / "python"
    with tarfile.open(fetch_python()) as archive:
        archive.extractall(PACKAGE, filter="data")
    unpacked.rename(target)
    python = target / "bin" / "python"
    if not python.exists():
        python.symlink_to(f"python{PYTHON_VERSION.rsplit('.', 1)[0]}")
    run([str(python), "-m", "pip", "install",
         "--disable-pip-version-check", "--no-cache-dir",
         "-r", str(REPO / "backend" / "requirements.txt")])
    shutil.copy2(REPO / "backend" / "requirements.txt",
                 target / "obra-requirements.txt")
    check_self_contained(target)


## ⚠ NOTHING IT CARRIES POINTS BACK AT THIS MAC. A Python, or a compiled package, linked against a
## library under Homebrew or /usr/local runs here and fails on a player's Mac, which is the bug this
## build exists to end -- so the build stops instead of shipping it.
def check_self_contained(venv: Path) -> None:
    foreign: list[str] = []
    for path in venv.rglob("*"):
        if path.is_symlink() or not path.is_file() or path.suffix not in ("", ".so", ".dylib"):
            continue
        with open(path, "rb") as handle:
            if handle.read(4) not in (b"\xcf\xfa\xed\xfe", b"\xca\xfe\xba\xbe"):
                continue
        links = subprocess.run(["otool", "-L", str(path)], capture_output=True, text=True).stdout
        for line in links.splitlines()[1:]:
            library = line.strip().split(" ")[0]
            if library.startswith(FOREIGN_PREFIXES):
                foreign.append(f"{path.relative_to(venv)} -> {library}")
    if foreign:
        raise SystemExit("The bundled Python reaches outside the package:\n  " + "\n  ".join(foreign))
    print(f"The bundled Python is self-contained ({sum(1 for _ in venv.rglob('*'))} files).")


def copy_recogniser() -> None:
    for name in ("backend", "shared"):
        destination = PACKAGE / name
        destination.mkdir(parents=True, exist_ok=True)
        for source in (REPO / name).iterdir():
            if source.suffix == ".py" or source.name == "requirements.txt":
                shutil.copy2(source, destination / source.name)
    config = PACKAGE / "game" / "config"
    shutil.copytree(REPO / "game" / "config", config, dirs_exist_ok=True)
    for entity in load_entities(validate_scene_paths=True):
        for res_path in (entity.scene_path, entity.rig_profile):
            if res_path is None:
                continue
            source = res_path_to_filesystem(res_path)
            target = PACKAGE / source.relative_to(REPO)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)


def assemble() -> None:
    if PACKAGE.exists():
        shutil.rmtree(PACKAGE)
    (PACKAGE / "game").mkdir(parents=True)
    export_game()
    copy_recogniser()
    (PACKAGE / "model").mkdir()
    for filename in MODEL_FILES:
        source = REPO / "model" / filename
        if not source.exists():
            raise SystemExit(f"Missing model file: {source}")
        shutil.copy2(source, PACKAGE / "model" / filename)
    build_venv()
    for source in (REPO / "tools" / "macos").iterdir():
        target = PACKAGE / source.name
        shutil.copy2(source, target)
        if target.suffix == ".command":
            target.chmod(0o755)
    (PACKAGE / "README.txt").write_text(
        (REPO / "tools" / "macos" / "README.txt").read_text(), encoding="utf-8")


def make_zip() -> Path:
    archive = BUILD / "OBRA-macos.zip"
    if archive.exists():
        archive.unlink()
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as bundle:
        for path in PACKAGE.rglob("*"):
            if path.is_file():
                bundle.write(path, path.relative_to(BUILD))
    return archive


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--no-zip", action="store_true")
    args = parser.parse_args()
    BUILD.mkdir(parents=True, exist_ok=True)
    assemble()
    if not args.no_zip:
        print(f"Wrote {make_zip()}")


if __name__ == "__main__":
    main()
