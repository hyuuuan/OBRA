#!/usr/bin/env python3
"""Build O.B.R.A. for a Windows playtest: the game, its drawing recogniser, and a Python to run
the recogniser, in one folder that needs nothing installed, no admin rights and no internet.

    .venv/bin/python tools/build_windows.py --fetch      # once, online: Python and the wheels
    .venv/bin/python tools/build_windows.py              # export, assemble, zip
    .venv/bin/python tools/build_windows.py --pck-only   # no export templates: the .pck only

Writes build/windows/OBRA/ and build/windows/OBRA-windows.zip; build/ is gitignored. The
playtest-day guide, and where the telemetry ends up on the PCs, is docs/PLAYTEST_WINDOWS.md.

WHY THE FOLDER IS LAID OUT LIKE THE REPOSITORY. Nothing in the game or the recogniser knows it
has been exported, so the package gives each the folders it already looks in:

- BackendSupervisor finds the recogniser through `_repo_root()`, the folder above res://. In an
  export res:// is inside the .pck and globalizes to "", so that root is `..` from the working
  directory. ⚠ So OBRA.exe sits in game/, where res:// is in a checkout, and has to be STARTED
  FROM game/: a double-click does that, and so does `Play OBRA.bat`.
- The recogniser checks that every class's scene and rig profile exists under game/
  (shared/entities.py, validate_scene_paths), so those files and game/config are copied beside
  the .exe. The game itself reads them from its .pck.
- Python is python.org's NuGet build of CPython, a complete Python that runs from any folder,
  at .venv/Scripts/python.exe, where `python_in` looks. ⚠ Not the "embeddable" zip: it leaves
  out the venv module, and serve.py imports venv before it does anything else. A ._pth file
  beside python.exe keeps it from seeing any Python already on the PC (no PYTHONPATH, no user
  site-packages). The wheels are installed into it for win_amd64 from here, and
  .venv/obra-requirements.txt is stamped as serve.py stamps it, so it never runs pip.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import re
import shutil
import subprocess
import sys
import urllib.request
import zipfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO))

from shared.entities import load_entities, res_path_to_filesystem  # noqa: E402

PRESET = "Windows Desktop"
BUILD = REPO / "build" / "windows"
CACHE = REPO / "build" / "windows-cache"
HELPERS = REPO / "tools" / "windows"

# The last 3.12 python.org built binaries for. 3.12 because BackendSupervisor asks for it first:
# every package the recogniser needs has Windows wheels for it.
PYTHON_VERSION = "3.12.10"
PYTHON_TAG = "312"
PYTHON_URL = f"https://www.nuget.org/api/v2/package/python/{PYTHON_VERSION}"
PYTHON_PACKAGE = CACHE / f"python.{PYTHON_VERSION}.nupkg"
# Recorded on the first --fetch (whose SHA-512 matched nuget.org's own, publisher Python Software
# Foundation), so a later download that differs is refused.
PYTHON_SHA256 = "0eb85c2dfccccf1b17352de4c397f69194035b7d37149eacc16f1147d93de3b8"

# ⚠ onnxruntime imports MSVCP140.dll and MSVCP140_1.dll, Microsoft's C++ runtime, which Python
# does not ship. A PC without the Visual C++ Redistributable could not load the recogniser, and
# installing it needs admin rights, so the zip carries them beside python.exe (app-local, as
# Microsoft allows for these files), with the vcruntime140 of the same release, so the runtime
# in the process is one version. Taken from Microsoft's own redistributable by 7-Zip at --fetch.
VC_REDIST_URL = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
VC_REDIST = CACHE / "vc_redist.x64.exe"
VC_RUNTIME = CACHE / "vcruntime"
VC_DLLS = ["msvcp140.dll", "msvcp140_1.dll", "vcruntime140.dll", "vcruntime140_1.dll"]

# backend/requirements.txt as it resolves on Windows. ⚠ SPELLED OUT, NOT READ FROM THE FILE: pip
# judges environment markers by the machine it runs on, not by --platform, so `uvicorn[standard]`
# asked for from a Mac wants uvloop, which has no Windows build, and leaves out colorama, which
# only Windows gets. `_check_requirements` fails the build when the file gains a package this
# list does not have; `_windows_only_missing` when a wheel needs a Windows-only one it lacks.
WINDOWS_PACKAGES = [
    "fastapi",
    "uvicorn", "httptools", "websockets", "watchfiles", "python-dotenv", "pyyaml", "colorama",
    "onnxruntime",
    "pillow",
    "numpy",
    "psutil",
]
PIP_TARGET = [
    "--platform", "win_amd64",
    "--python-version", PYTHON_VERSION.rsplit(".", 1)[0],
    "--implementation", "cp",
    "--only-binary=:all:",
]

MODEL_FILES = ["model.onnx", "labels.json", "model_metadata.json"]
# Beyond this, a folder unzipped onto a Desktop starts to meet Windows' 260-character path limit.
LONGEST_PATH = 150


def godot() -> str:
    found = os.environ.get("GODOT") or shutil.which("godot")
    if not found:
        raise SystemExit("Godot 4.7 is not on PATH; set GODOT=/path/to/godot.")
    return found


def run(command: list[str], **kwargs) -> subprocess.CompletedProcess:
    print("+", " ".join(command), flush=True)
    return subprocess.run(command, check=True, **kwargs)


# --- fetch -------------------------------------------------------------------------------

def fetch() -> None:
    """Download python.org's NuGet Python and the recogniser's Windows wheels into the cache."""
    CACHE.mkdir(parents=True, exist_ok=True)
    if not PYTHON_PACKAGE.exists():
        print(f"Downloading Python {PYTHON_VERSION} (NuGet, python.org's build) ...", flush=True)
        partial = PYTHON_PACKAGE.with_suffix(".part")
        with urllib.request.urlopen(PYTHON_URL) as response, open(partial, "wb") as out:
            shutil.copyfileobj(response, out)
        partial.rename(PYTHON_PACKAGE)
    digest = sha256(PYTHON_PACKAGE)
    if PYTHON_SHA256 and digest != PYTHON_SHA256:
        raise SystemExit(f"{PYTHON_PACKAGE.name} is not the file recorded (sha256 {digest}); "
                         "delete it and fetch again.")
    print(f"{PYTHON_PACKAGE.name} sha256 {digest}")
    _check_requirements()
    run([sys.executable, "-m", "pip", "download", "--disable-pip-version-check",
         "--dest", str(CACHE / "wheels"), *PIP_TARGET, *WINDOWS_PACKAGES])
    fetch_vc_runtime()


def fetch_vc_runtime() -> None:
    """Microsoft's redistributable, and the C++ runtime DLLs out of it."""
    seven = shutil.which("7zz") or shutil.which("7z")
    if not seven:
        raise SystemExit("7-Zip is needed to unpack Microsoft's C++ runtime: brew install sevenzip")
    if not VC_REDIST.exists():
        print("Downloading Microsoft's Visual C++ Redistributable (x64) ...", flush=True)
        partial = VC_REDIST.with_suffix(".part")
        with urllib.request.urlopen(VC_REDIST_URL) as response, open(partial, "wb") as out:
            final_url = response.geturl()
            shutil.copyfileobj(response, out)
        # aka.ms moves to each new release, so nothing can be pinned here; but the download
        # server names every file by its SHA-256, which the file has to match.
        named = re.search(r"/([0-9A-Fa-f]{64})/[^/]+$", final_url)
        if not final_url.startswith("https://download.visualstudio.microsoft.com/") or not named \
                or named.group(1).lower() != sha256(partial):
            partial.unlink()
            raise SystemExit(f"The redistributable from {final_url} is not the file it names.")
        partial.rename(VC_REDIST)
    print(f"{VC_REDIST.name} sha256 {sha256(VC_REDIST)}")
    # A WiX bundle: its attached cabinet holds more cabinets, one of which holds the x64 DLLs
    # as <name>_amd64.
    work = CACHE / "vc_redist.unpacked"
    shutil.rmtree(work, ignore_errors=True)
    shutil.rmtree(VC_RUNTIME, ignore_errors=True)
    VC_RUNTIME.mkdir(parents=True)
    quiet = {"stdout": subprocess.DEVNULL, "stderr": subprocess.DEVNULL}
    subprocess.run([seven, "e", "-t#", "-y", f"-o{work / 'outer'}", str(VC_REDIST), "*.cab"],
                   check=True, **quiet)
    for container in (work / "outer").glob("*.cab"):
        subprocess.run([seven, "x", "-y", f"-o{work / 'inner'}", str(container)], **quiet)
    for cabinet in sorted((work / "inner").iterdir()):
        subprocess.run([seven, "e", "-y", f"-o{VC_RUNTIME}", str(cabinet),
                        *[f"{name}_amd64" for name in VC_DLLS]], **quiet)
    for name in VC_DLLS:
        found = VC_RUNTIME / f"{name}_amd64"
        if not found.exists():
            raise SystemExit(f"{VC_REDIST.name} had no x64 {name}.")
        found.rename(VC_RUNTIME / name)
    shutil.rmtree(work)
    for name in VC_DLLS:
        print(f"  {name} {pe_version(VC_RUNTIME / name)}")


def pe_version(path: Path) -> tuple[int, ...]:
    """A Windows DLL's file version, from its VS_FIXEDFILEINFO; () when it has none."""
    data = path.read_bytes()
    at = data.find(b"\xbd\x04\xef\xfe")
    if at < 0:
        return ()
    high, low = int.from_bytes(data[at + 8:at + 12], "little"), \
        int.from_bytes(data[at + 12:at + 16], "little")
    return (high >> 16, high & 0xFFFF, low >> 16, low & 0xFFFF)


def sha256(path: Path) -> str:
    hasher = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            hasher.update(block)
    return hasher.hexdigest()


def _check_requirements() -> None:
    wanted = {re.split(r"[\[<>=;\s]", line.strip(), maxsplit=1)[0].lower()
              for line in (REPO / "backend" / "requirements.txt").read_text().splitlines()
              if line.strip() and not line.startswith("#")}
    missing = sorted(wanted - set(WINDOWS_PACKAGES))
    if missing:
        raise SystemExit(f"backend/requirements.txt has {missing}, which WINDOWS_PACKAGES in "
                         f"{Path(__file__).name} does not. Add them (and their Windows extras).")


# --- assemble ------------------------------------------------------------------------------

def export_game(out: Path, pck_only: bool) -> None:
    game = out / "game"
    game.mkdir(parents=True, exist_ok=True)
    log = BUILD / "export.log"
    if pck_only:
        command = [godot(), "--headless", "--path", str(REPO / "game"),
                   "--export-pack", PRESET, str(game / "OBRA.pck")]
    else:
        command = [godot(), "--headless", "--path", str(REPO / "game"),
                   "--export-release", PRESET, str(game / "OBRA.exe")]
    print("+", " ".join(command), flush=True)
    with open(log, "w", encoding="utf-8") as handle:
        done = subprocess.run(command, stdout=handle, stderr=subprocess.STDOUT)
    text = log.read_text(encoding="utf-8", errors="replace")
    errors = [line for line in text.splitlines()
              if re.search(r"SCRIPT ERROR|Parse Error|^ERROR|Error calling", line)]
    if done.returncode != 0 or errors:
        print("\n".join(errors[-20:] or text.splitlines()[-20:]))
        if "No export template found" in text or "export template" in text.lower():
            print("\nThe Windows export templates for Godot 4.7.stable are not installed. "
                  "See docs/PLAYTEST_WINDOWS.md, 'Building it'.")
        raise SystemExit(f"The export failed (exit {done.returncode}); the log is {log}.")
    wanted = game / "OBRA.pck"
    if not wanted.exists() or (not pck_only and not (game / "OBRA.exe").exists()):
        raise SystemExit(f"The export finished but left no {wanted.name}; the log is {log}.")


def copy_recogniser(out: Path) -> None:
    for name in ("backend", "shared"):
        (out / name).mkdir(parents=True, exist_ok=True)
        for source in (REPO / name).iterdir():
            if source.suffix == ".py" or source.name == "requirements.txt":
                shutil.copy2(source, out / name / source.name)
    (out / "model").mkdir(exist_ok=True)
    for name in MODEL_FILES:
        shutil.copy2(REPO / "model" / name, out / "model" / name)
    shutil.copytree(REPO / "game" / "config", out / "game" / "config", dirs_exist_ok=True)
    # The files the recogniser checks are there, as res_path_to_filesystem finds them.
    for entity in load_entities(validate_scene_paths=True):
        for res_path in (entity.scene_path, entity.rig_profile):
            if res_path is None:
                continue
            source = res_path_to_filesystem(res_path)
            target = out / source.relative_to(REPO)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)


def install_python(out: Path) -> None:
    if not PYTHON_PACKAGE.exists() or not (CACHE / "wheels").is_dir():
        raise SystemExit("No Python or wheels in build/windows-cache; run with --fetch first.")
    _check_requirements()
    venv = out / ".venv"
    scripts = venv / "Scripts"
    if venv.exists():
        shutil.rmtree(venv)
    scripts.mkdir(parents=True)
    # Laid out as a venv is: the interpreter and its DLLs in Scripts, the standard library in
    # Lib and DLLs beside it. Python finds its prefix by looking up from python.exe for
    # Lib\os.py, so sys.prefix is .venv itself and serve.py's `running_in()` holds -- it serves
    # at once instead of starting itself a second time (which would also work, one process
    # deeper).
    with zipfile.ZipFile(PYTHON_PACKAGE) as package:
        for member in package.infolist():
            if not member.filename.startswith("tools/") or member.is_dir():
                continue
            relative = member.filename.removeprefix("tools/")
            # Its own pip and the C headers and import libraries are for building, not running.
            if relative.startswith(("include/", "libs/", "Lib/site-packages/")):
                continue
            inside = relative.startswith(("Lib/", "DLLs/"))
            target = (venv if inside else scripts) / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            with package.open(member) as source, open(target, "wb") as handle:
                shutil.copyfileobj(source, handle)
    if not (scripts / "python.exe").exists():
        raise SystemExit(f"{PYTHON_PACKAGE.name} had no tools/python.exe.")
    # Beside python.exe, the first place Windows looks for a DLL the process needs. Never older
    # than the vcruntime Python came with, which it was built against.
    for name in VC_DLLS:
        source, target = VC_RUNTIME / name, scripts / name
        if not source.exists():
            raise SystemExit(f"No {name} in {VC_RUNTIME}; run with --fetch first.")
        if target.exists() and pe_version(target) > pe_version(source):
            raise SystemExit(f"{name} from the redistributable is older than Python's own.")
        shutil.copy2(source, target)
    # Only these folders, relative to python.exe: the PC's own Python, PYTHONPATH and the
    # user's site-packages are never looked at. `import site` keeps site-packages' .pth files.
    (scripts / f"python{PYTHON_TAG}._pth").write_text(
        "..\\Lib\n..\\DLLs\n..\\Lib\\site-packages\nimport site\n", encoding="ascii")
    site_packages = venv / "Lib" / "site-packages"
    run([sys.executable, "-m", "pip", "install", "--disable-pip-version-check", "--no-index",
         "--find-links", str(CACHE / "wheels"), "--target", str(site_packages), "--no-compile",
         *PIP_TARGET, *WINDOWS_PACKAGES], stdout=subprocess.DEVNULL)
    # Console-script launchers pip wrote for this Mac; a Windows Python has no use for them.
    shutil.rmtree(site_packages / "bin", ignore_errors=True)
    missing = _windows_only_missing(site_packages)
    if missing:
        raise SystemExit(f"These are needed on Windows and were not installed: {missing}. "
                         "Add them to WINDOWS_PACKAGES, then --fetch again.")
    # The stamp serve.py compares against: the same file, so it never reaches for pip.
    shutil.copyfile(REPO / "backend" / "requirements.txt", venv / "obra-requirements.txt")
    frozen = sorted(path.name.removesuffix(".dist-info")
                    for path in site_packages.glob("*.dist-info"))
    (venv / "obra-packages.txt").write_text(
        f"python {PYTHON_VERSION}\n" + "\n".join(frozen) + "\n", encoding="utf-8")


def _windows_only_missing(site_packages: Path) -> list[str]:
    """Requirements that only Windows asks for (pip, on a Mac, skipped them), not installed."""
    installed = {_normal(path.name.split("-")[0]) for path in site_packages.glob("*.dist-info")}
    missing = set()
    for metadata in site_packages.glob("*.dist-info/METADATA"):
        for line in metadata.read_text(encoding="utf-8", errors="replace").splitlines():
            if not line.startswith("Requires-Dist:") or ";" not in line:
                continue
            requirement, marker = line.removeprefix("Requires-Dist:").split(";", 1)
            if "extra" in marker:
                continue
            windows = re.search(r"(sys_platform|platform_system|os_name)\s*==\s*['\"]"
                                r"(win32|Windows|nt)['\"]", marker)
            if windows and " or " not in marker:
                name = _normal(re.split(r"[\[<>=!~(\s]", requirement.strip(), maxsplit=1)[0])
                if name not in installed:
                    missing.add(name)
    return sorted(missing)


def _normal(name: str) -> str:
    return re.sub(r"[-_.]+", "-", name).lower()


def copy_helpers(out: Path) -> None:
    for helper in HELPERS.iterdir():
        if helper.is_file():
            # cmd.exe misreads a .bat with Unix line endings, so they all get Windows ones.
            data = helper.read_bytes().replace(b"\r\n", b"\n").replace(b"\n", b"\r\n")
            (out / helper.name).write_bytes(data)


def check_package(out: Path, pck_only: bool, with_python: bool) -> None:
    must = ["game/OBRA.pck", "backend/serve.py", "backend/main.py", "shared/entities.py",
            "game/config/entities.json", "game/config/abilities.json",
            *[f"model/{name}" for name in MODEL_FILES]]
    if not pck_only:
        must.append("game/OBRA.exe")
    if with_python:
        must += [".venv/Scripts/python.exe", f".venv/Scripts/python{PYTHON_TAG}.dll",
                 *[f".venv/Scripts/{name}" for name in VC_DLLS],
                 f".venv/Scripts/python{PYTHON_TAG}._pth", ".venv/Lib/os.py",
                 ".venv/Lib/venv/__init__.py", ".venv/Lib/site-packages/onnxruntime",
                 ".venv/obra-requirements.txt"]
    absent = [path for path in must if not (out / path).exists()]
    if absent:
        raise SystemExit(f"The package is missing {absent}.")
    longest = max((len(str(path.relative_to(out.parent))) for path in out.rglob("*")), default=0)
    if longest > LONGEST_PATH:
        print(f"⚠ The longest path in the package is {longest} characters; unzip it close to a "
              "drive's root if Windows refuses some files.")


def make_zip(out: Path) -> Path:
    archive = BUILD / "OBRA-windows.zip"
    archive.unlink(missing_ok=True)
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as bundle:
        for path in sorted(out.rglob("*")):
            if path.is_file() and path.name != ".DS_Store":
                bundle.write(path, path.relative_to(out.parent))
    return archive


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--fetch", action="store_true",
                        help="download Python and the wheels into build/windows-cache, then stop")
    parser.add_argument("--pck-only", action="store_true",
                        help="export only the .pck (no templates needed); no .exe, no zip")
    parser.add_argument("--no-python", action="store_true", help="leave out the bundled Python")
    parser.add_argument("--out", type=Path, default=BUILD / "OBRA",
                        help="where to assemble the folder (default build/windows/OBRA)")
    args = parser.parse_args(argv)

    if args.fetch:
        fetch()
        return 0
    out = args.out.resolve()
    BUILD.mkdir(parents=True, exist_ok=True)
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    export_game(out, args.pck_only)
    copy_recogniser(out)
    if not args.no_python:
        install_python(out)
    copy_helpers(out)
    check_package(out, args.pck_only, not args.no_python)
    print(f"Assembled {out}")
    if not args.pck_only and not args.no_python:
        archive = make_zip(out)
        print(f"Zipped {archive} ({archive.stat().st_size / 1048576:.0f} MB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
