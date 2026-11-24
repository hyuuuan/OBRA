#!/usr/bin/env python3
"""Clean the OBRA_PLAYTEST telemetry export as Part C0 of docs/CHAPTER5_BRIEF.md says.

Usage:
    python tools/chapter5/clean_telemetry.py <unzipped OBRA_PLAYTEST folder> <out folder>

Writes <out>/main/P11..P43 and <out>/pilot/P01..P10, each with its profile.json and its
telemetry/, ready for tools/aggregate_telemetry.py, plus <out>/key.csv (code -> folder).

⚠ The output is as private as the input. key.csv maps codes to folder names, and one folder
is named with a student ID number. Keep <out> outside the repository.

The cleaning, so that a re-download (or one participant's logs replaced) re-runs unchanged:

- Thirty-two lab folders appear twice: inside R08/ (complete) and at the top level (partial
  or empty). The nested copy is used. A lab folder only at the top level (R1003) is kept.
- R08's own profile.json and telemetry/ are a pilot participant's, beside the lab folders.
- R03-1 and R03-2 are one pilot participant; R03-1 lacks the last session. R03-2 is used.
- R05 is a development machine with logs from July on. Only its pilot sitting is kept, the
  9 Nov 18:44-19:14 (Manila) session, which its profile agrees with.
- Backend logs are kept only for the samples inside the participant's own session logs, so
  CPU, memory and inference figures belong to the session (C0, "Definitions used").
- Main study = sessions on 16 Nov 2026 (Manila). Pilot = everything earlier.
- Codes run P01..P43 in order of first session start over all 43 (the pilot first).
"""
from __future__ import annotations

import csv
import json
import shutil
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

MANILA = timezone(timedelta(hours=8))
NESTED_LAB_PARENT = "R08"
DROP = {"R03-1"}                       # superseded by R03-2
DEV_MACHINE = "R05"
# R05's pilot sitting, in UTC as the logs write it (9 Nov 18:44-19:14 Manila).
DEV_WINDOW = (datetime(2026, 11, 9, 10, 40, tzinfo=timezone.utc),
              datetime(2026, 11, 9, 11, 20, tzinfo=timezone.utc))
MAIN_DAY = datetime(2026, 11, 16, tzinfo=MANILA).date()


def _utc(value) -> datetime | None:
    """A record's time. Session logs write an epoch `ts`; backend logs an ISO `ts`."""
    if isinstance(value, (int, float)):
        return datetime.fromtimestamp(value, tz=timezone.utc)
    if isinstance(value, str):
        stamp = datetime.fromisoformat(value)
        return stamp if stamp.tzinfo else stamp.replace(tzinfo=timezone.utc)
    return None


def _records(path: Path) -> list[dict]:
    out = []
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if line:
                out.append(json.loads(line))
    return out


def _span(path: Path) -> tuple[datetime, datetime] | None:
    times = [t for t in (_utc(r.get("ts")) for r in _records(path)) if t]
    return (min(times), max(times)) if times else None


def participants(root: Path) -> dict[str, Path]:
    """Folder name -> the folder that holds that participant's profile.json and telemetry/."""
    found: dict[str, Path] = {}
    nested = root / NESTED_LAB_PARENT
    for child in sorted(p for p in root.iterdir() if p.is_dir()):
        if child.name in DROP:
            continue
        found[child.name] = child
    if nested.is_dir():
        for child in sorted(p for p in nested.iterdir() if p.is_dir() and p.name != "telemetry"):
            found[child.name] = child  # the nested copy wins over a top-level duplicate
    return found


def _sessions(folder: Path, name: str) -> list[tuple[Path, tuple[datetime, datetime]]]:
    kept = []
    for path in sorted((folder / "telemetry").glob("session_*.jsonl")):
        span = _span(path)
        if not span:
            continue
        if name == DEV_MACHINE and not (DEV_WINDOW[0] <= span[0] <= DEV_WINDOW[1]):
            continue
        kept.append((path, span))
    return kept


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(__doc__)
        return 2
    root, out = Path(argv[1]), Path(argv[2])
    if (root / "OBRA_PLAYTEST").is_dir():
        root = root / "OBRA_PLAYTEST"
    people = []
    for name, folder in participants(root).items():
        sessions = _sessions(folder, name)
        if not sessions:
            print(f"skip {name}: no session logs", file=sys.stderr)
            continue
        start = min(span[0] for _, span in sessions)
        people.append((start, name, folder, sessions))
    people.sort()
    if out.exists():
        shutil.rmtree(out)
    rows = []
    for number, (start, name, folder, sessions) in enumerate(people, 1):
        code = f"P{number:02d}"
        group = "main" if start.astimezone(MANILA).date() == MAIN_DAY else "pilot"
        dest = out / group / code
        (dest / "telemetry").mkdir(parents=True)
        if (folder / "profile.json").exists():
            shutil.copy2(folder / "profile.json", dest / "profile.json")
        for path, _ in sessions:
            shutil.copy2(path, dest / "telemetry" / path.name)
        windows = [span for _, span in sessions]
        backend_kept = 0
        for path in sorted((folder / "telemetry").glob("backend_*.jsonl")):
            lines = []
            with open(path, encoding="utf-8") as handle:
                for line in handle:
                    if not line.strip():
                        continue
                    stamp = _utc(json.loads(line).get("ts"))
                    if stamp and any(a <= stamp <= b for a, b in windows):
                        lines.append(line if line.endswith("\n") else line + "\n")
            if lines:
                (dest / "telemetry" / path.name).write_text("".join(lines), encoding="utf-8")
                backend_kept += len(lines)
        rows.append({"code": code, "group": group, "folder": str(folder.relative_to(root)),
                     "first_session_manila": start.astimezone(MANILA).isoformat(timespec="minutes"),
                     "sessions": len(sessions), "backend_records": backend_kept})
    with open(out / "key.csv", "w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    main_n = sum(r["group"] == "main" for r in rows)
    print(f"{len(rows)} participants: {main_n} main study, {len(rows) - main_n} pilot -> {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
