#!/usr/bin/env python3
"""Build a self-contained macOS playtest package with local telemetry collection."""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
BUILD = REPO / "build" / "macos"
PACKAGE = BUILD / "OBRA"
MODEL_FILES = ("model.onnx", "labels.json", "model_metadata.json")

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


def build_venv() -> None:
    python = os.environ.get("PYTHON")
    if not python and (REPO / ".venv" / "bin" / "python").exists():
        python = str(REPO / ".venv" / "bin" / "python")
    if not python:
        python = shutil.which("python3")
    if not python:
        raise SystemExit("Python 3 is required to build the macOS package.")
    target = PACKAGE / ".venv"
    run([python, "-m", "venv", str(target)])
    run([str(target / "bin" / "python"), "-m", "pip", "install",
         "--disable-pip-version-check", "--no-cache-dir",
         "-r", str(REPO / "backend" / "requirements.txt")])
    shutil.copy2(REPO / "backend" / "requirements.txt",
                 target / "obra-requirements.txt")


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
