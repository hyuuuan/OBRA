#!/usr/bin/env python3
"""Render the game's FamiTracker modules into the WAVs AudioDirector plays.

    audio/music/<id>.txt  ->  game/assets/audio/music/<id>.wav   loops    audio.json music.<id>
    audio/sfx/<id>.txt    ->  game/assets/audio/sfx/<id>.wav     one-shot audio.json sfx.<id>

A module is a FamiTracker text module (2A03 + VRC7; see audio/README.md); its first TRACK is
rendered by tools/famirender.py. The id must already be in game/config/audio.json: ids are
authored first, with their call sites, and a module for an id nothing plays is a sound nobody
hears.

⚠ ON macOS EVERY RENDER RUNS INSIDE tools/famirender.sb (Kent, 2026-11-14): no network, no
credential stores, and writes only to the rendered audio, audio.json, build/famirender and the
temp folder. Rendering compiles and loads native code, so it is fenced even though that code was
reviewed and sanitizer-tested. The script re-launches itself under sandbox-exec and then proves
the fence is up (a write outside it must fail) before it renders anything. Elsewhere it refuses
unless --unsandboxed is given on purpose.

    tools/build_music.py               render every module, point audio.json at the files
    tools/build_music.py menu          only those ids
    tools/build_music.py --check       render in memory; exit 1 if a committed WAV or path differs
"""

from __future__ import annotations

import json
import os
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MODULES = ROOT / "audio"
OUT = ROOT / "game" / "assets" / "audio"
CATALOG = ROOT / "game" / "config" / "audio.json"
BUILD = ROOT / "build" / "famirender"
PROFILE = ROOT / "tools" / "famirender.sb"
SANDBOX_EXEC = "/usr/bin/sandbox-exec"
SANDBOXED_ENV = "OBRA_FAMIRENDER_SANDBOXED"
SECTIONS = {"music": True, "sfx": False}  # section -> loops


def _enter_sandbox(argv: list[str]) -> None:
    """Re-launch this script inside tools/famirender.sb. Returns only when already inside."""
    if os.environ.get(SANDBOXED_ENV) == "1":
        _prove_sandboxed()
        return
    if "--unsandboxed" in argv:
        print("build_music: rendering WITHOUT the sandbox, as asked", file=sys.stderr)
        return
    if sys.platform != "darwin" or not Path(SANDBOX_EXEC).exists():
        raise SystemExit("build_music: no macOS sandbox here; refusing to compile and run native "
                         "code unfenced. Pass --unsandboxed to do it anyway, knowingly.")
    # The fence makes these read-only once it is up, so they are made first.
    BUILD.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    temp = os.path.realpath(tempfile.gettempdir())
    params = {"HOME": str(Path.home()), "AUDIO_OUT": str(OUT), "CATALOG": str(CATALOG),
              "BUILD": str(BUILD), "TMP": temp, "SCRATCH": temp}
    command = [SANDBOX_EXEC, "-f", str(PROFILE)]
    for key, value in params.items():
        command += ["-D", f"{key}={value}"]
    command += [sys.executable, str(Path(__file__).resolve()), *argv]
    env = dict(os.environ, **{SANDBOXED_ENV: "1", "PYTHONDONTWRITEBYTECODE": "1"})
    os.execve(SANDBOX_EXEC, command, env)


def _prove_sandboxed() -> None:
    """A write outside the fence must fail. If it succeeds, the sandbox is not what it claims."""
    probe = ROOT / "tools" / ".famirender_sandbox_probe"
    try:
        probe.write_text("this write should have been refused")
    except PermissionError:
        return
    probe.unlink(missing_ok=True)
    raise SystemExit("build_music: the sandbox is NOT in effect (a write outside it succeeded); "
                     "refusing to render")


def modules(only: set[str]) -> list[tuple[str, str, Path]]:
    found = []
    for section in SECTIONS:
        for path in sorted((MODULES / section).glob("*.txt")):
            if not only or path.stem in only:
                found.append((section, path.stem, path))
    missing = only - {stem for _, stem, _ in found}
    if missing:
        raise SystemExit(f"build_music: no module for {', '.join(sorted(missing))}")
    return found


def res_path(section: str, sound_id: str) -> str:
    return f"res://assets/audio/{section}/{sound_id}.wav"


def main(argv: list[str]) -> int:
    _enter_sandbox(argv)
    sys.path.insert(0, str(ROOT / "tools"))
    import famirender

    check = "--check" in argv
    only = {a for a in argv if not a.startswith("--")}
    catalog = json.loads(CATALOG.read_text())
    stale: list[str] = []
    for section, sound_id, path in modules(only):
        if sound_id not in catalog.get(section, {}):
            raise SystemExit(f"build_music: {section}.{sound_id} is not in audio.json; author "
                             "the id (and what plays it) first")
        try:
            result = famirender.render(famirender.parse_module(path.read_text()),
                                       loop=SECTIONS[section])
            data = famirender.wav_bytes(result)
        except famirender.ModuleError as error:
            raise SystemExit(f"build_music: {path.relative_to(ROOT)}: {error}") from None
        target = OUT / section / f"{sound_id}.wav"
        summary = (f"{section}.{sound_id}: {len(result.samples) / result.rate:.1f} s, "
                   f"peak {result.peak:.2f}")
        if result.loop_start is not None:
            summary += f", loops {result.loop_start / result.rate:.1f}-" \
                       f"{len(result.samples) / result.rate:.1f} s"
        if check:
            same = target.exists() and target.read_bytes() == data
            listed = catalog[section][sound_id] == res_path(section, sound_id)
            if not (same and listed):
                stale.append(f"{section}.{sound_id}")
            print(("ok     " if same and listed else "STALE  ") + summary)
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        catalog[section][sound_id] = res_path(section, sound_id)
        print("wrote  " + summary)
    if check:
        if stale:
            print(f"build_music: out of date: {', '.join(stale)}; run tools/build_music.py")
            return 1
        return 0
    # Written in place (not via a temp file and rename), because the sandbox lets this script
    # write audio.json itself and nothing else in game/config.
    CATALOG.write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
