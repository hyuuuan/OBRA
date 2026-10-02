#!/usr/bin/env python3
"""A live progress bar for a tools/run_suites.sh run: how many are done, how many failed, what
is running now, and how long it has taken.

Kent: "i cant see or know how many is done and how many failed". The suite takes the best part
of an hour and said nothing until the end -- and when it was run in the background, not even
that. This reads the run's own log as it is written, so it can watch a run already going, one
started by somebody else, or one in another terminal.

    tools/suite_watch.py                  watch the default log (/tmp/obra_suites.log)
    tools/suite_watch.py LOG              watch another (OBRA_SUITE_LOG)
    tools/suite_watch.py LOG --once       print where it is, once, and exit

A suite counts as FAILED if it exits non-zero, or if its output holds a GDScript "SCRIPT ERROR"
or "Parse Error": a script that does not parse still exits 0, and run_suites.sh trusts the code.
Exits 0 when the run finished with nothing failed, 1 otherwise.
"""
from __future__ import annotations

import argparse
import os
import re
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RUNNER = ROOT / "tools" / "run_suites.sh"
DEFAULT_LOG = os.environ.get("OBRA_SUITE_LOG", "/tmp/obra_suites.log")
HEADER = re.compile(r"^########## (\S+)\s*$")
EXIT = re.compile(r"^\[exit (-?\d+)\]\s*$")
BROKEN = ("SCRIPT ERROR", "Parse Error")
BAR = 28


def planned() -> list[str]:
    """Every run the runner makes, in order, read off its own lists, and python last."""
    text = RUNNER.read_text()
    names: list[str] = []
    for group in ("HEADLESS", "WINDOW"):
        match = re.search(rf"^{group}=\((.*?)\)", text, re.S | re.M)
        if match:
            names += match.group(1).split()
    return names + ["python"]


def read(log: Path) -> dict:
    """What the log says so far: finished runs with their verdict, and the one in progress."""
    runs: list[dict] = []
    current = None
    try:
        lines = log.read_text(errors="replace").splitlines()
    except FileNotFoundError:
        return {"runs": [], "current": None}
    for line in lines:
        header = HEADER.match(line)
        if header:
            current = {"name": header.group(1), "code": None, "broken": False}
            runs.append(current)
            continue
        if current is None:
            continue
        ended = EXIT.match(line)
        if ended:
            current["code"] = int(ended.group(1))
            current = None
        elif any(mark in line for mark in BROKEN):
            current["broken"] = True
    finished = [run for run in runs if run["code"] is not None]
    running = runs[-1]["name"] if runs and runs[-1]["code"] is None else None
    return {"runs": finished, "current": running}


def failed(run: dict) -> bool:
    return run["code"] != 0 or run["broken"]


def total_for(state: dict) -> int:
    plan = planned()
    seen = [run["name"] for run in state["runs"]] + ([state["current"]] if state["current"] else [])
    # `run_suites.sh quick` skips run_tests, which is always first.
    if seen and seen[0] != plan[0] and plan[0] not in seen:
        plan = plan[1:]
    return len(plan)


def started_at(log: Path) -> float:
    stat = log.stat()
    return getattr(stat, "st_birthtime", stat.st_mtime)


def render(state: dict, total: int, elapsed: float, width: int = BAR) -> str:
    done = len(state["runs"])
    bad = [run for run in state["runs"] if failed(run)]
    filled = round(width * done / total) if total else 0
    bar = "#" * filled + "-" * (width - filled)
    hours, rest = divmod(int(elapsed), 3600)
    minutes, seconds = divmod(rest, 60)
    # Wall time: a Mac asleep with its lid shut pauses the run and the clock goes on.
    clock = f"{hours}:{minutes:02d}:{seconds:02d}" if hours else f"{minutes:>2}:{seconds:02d}"
    now = state["current"] or ("finished" if done >= total else "starting")
    return (f"[{bar}] {done:>2}/{total}  ok {done - len(bad):>2}  failed {len(bad):>2}  "
            f"{clock}  > {now}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("log", nargs="?", default=DEFAULT_LOG)
    parser.add_argument("--once", action="store_true")
    args = parser.parse_args()
    log = Path(args.log)
    live = sys.stdout.isatty() and not args.once
    reported: set[str] = set()
    last_line = ""
    while True:
        state = read(log)
        total = total_for(state)
        finished = len(state["runs"]) >= total
        # A finished run's time is how long it took, not how long ago it began.
        end = log.stat().st_mtime if finished and log.exists() else time.time()
        elapsed = end - started_at(log) if log.exists() else 0.0
        # Each failure on a line of its own, above the bar, as soon as it happens.
        for run in state["runs"]:
            if failed(run) and run["name"] not in reported:
                reported.add(run["name"])
                why = "script error" if run["code"] == 0 else f"exit {run['code']}"
                print(("\r\033[K" if live else "") + f"  FAILED  {run['name']}  ({why})")
        line = render(state, total, elapsed)
        if live:
            print("\r\033[K" + line, end="", flush=True)
        elif line != last_line or finished:
            print(line, flush=True)
        last_line = line
        if args.once or finished:
            if live:
                print()
            bad = [run["name"] for run in state["runs"] if failed(run)]
            if finished:
                print("ALL PASSED" if not bad else "FAILED: " + " ".join(bad))
            return 0 if finished and not bad else 1
        time.sleep(2.0)


if __name__ == "__main__":
    raise SystemExit(main())
