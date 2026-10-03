#!/usr/bin/env python3
"""A live progress bar for a tools/run_suites.sh run: how far through it is, how many passed and
failed, what is running now, how long it has taken and about how long is left.

Kent: "i cant see or know how many is done and how many failed", and then: "can i have a
tracker or progress bar for the running suites and also for the future". The suite takes the
best part of an hour and said nothing until the end. This reads the run's own log as it is
written, so it can watch a run already going, one started by somebody else, or one in another
terminal; and run_suites.sh starts it by itself whenever it is run in a terminal.

    tools/suite_watch.py                  watch the default log (/tmp/obra_suites.log)
    tools/suite_watch.py LOG              watch another (OBRA_SUITE_LOG)
    tools/suite_watch.py LOG --once       print where it is, once, and exit

THE BAR IS TIME, NOT COUNT. run_tests alone is a quarter of the whole run, so "1 of 62 done"
after twelve minutes read as nothing happening. Every suite's duration is kept in a history
file (OBRA_SUITE_TIMES, default ~/.cache/obra/suite_times.tsv) -- run_suites.sh writes it, and
this writes what it timed itself for a log from before the runner did -- and the bar fills by
the time the finished suites usually take, with an estimate of what is left. With no history
yet it falls back to the count, and says it does not know how long.

A suite counts as FAILED if it exits non-zero, or if its output holds a GDScript "SCRIPT ERROR"
or "Parse Error": a script that does not parse still exits 0, and run_suites.sh trusts the code.
Exits 0 when the run finished with nothing failed, 1 otherwise.
"""
from __future__ import annotations

import argparse
import os
import re
import shutil
import statistics
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RUNNER = ROOT / "tools" / "run_suites.sh"
DEFAULT_LOG = os.environ.get("OBRA_SUITE_LOG", "/tmp/obra_suites.log")
DEFAULT_TIMES = os.environ.get("OBRA_SUITE_TIMES",
                               str(Path.home() / ".cache" / "obra" / "suite_times.tsv"))
HEADER = re.compile(r"^########## (\S+)\s*$")
START = re.compile(r"^\[start (\d+)\]\s*$")
EXIT = re.compile(r"^\[exit (-?\d+)(?: in (\d+)s)?\]\s*$")
STARTED = re.compile(r"^started (\d+)$")
# The runner's own list of what this run makes -- all of it, `quick`, or `only` a few.
PLAN = re.compile(r"^plan (.*)$")
BROKEN = ("SCRIPT ERROR", "Parse Error")
BAR = 24
# How many of a suite's past runs its estimate is the median of.
RECENT = 3


def planned(runner: Path = RUNNER) -> list[str]:
    """Every run the runner makes, in order, read off its own lists, and python last."""
    text = runner.read_text()
    names: list[str] = []
    for group in ("HEADLESS", "WINDOW"):
        match = re.search(rf"^{group}=\((.*?)\)", text, re.S | re.M)
        if match:
            names += match.group(1).split()
    return names + ["python"]


def parse(text: str) -> dict:
    """What a log says so far: finished runs with their verdict, and the one in progress.

    Each run is {name, code, broken, start, secs}; `start` and `secs` are None in a log from a
    runner that did not write them.
    """
    runs: list[dict] = []
    current = None
    plan: list[str] = []
    for line in text.splitlines():
        if not runs and not plan:
            listed = PLAN.match(line)
            if listed:
                plan = listed.group(1).split()
                continue
        header = HEADER.match(line)
        if header:
            current = {"name": header.group(1), "code": None, "broken": False,
                       "start": None, "secs": None}
            runs.append(current)
            continue
        if current is None:
            continue
        began = START.match(line)
        if began:
            current["start"] = float(began.group(1))
            continue
        ended = EXIT.match(line)
        if ended:
            current["code"] = int(ended.group(1))
            if ended.group(2) is not None:
                current["secs"] = float(ended.group(2))
            current = None
        elif any(mark in line for mark in BROKEN):
            current["broken"] = True
    finished = [run for run in runs if run["code"] is not None]
    running = runs[-1] if runs and runs[-1]["code"] is None else None
    return {"runs": finished, "current": running, "plan": plan}


def read(log: Path) -> dict:
    try:
        return parse(log.read_text(errors="replace"))
    except FileNotFoundError:
        return {"runs": [], "current": None, "plan": []}


def failed(run: dict) -> bool:
    return run["code"] != 0 or run["broken"]


def plan_for(state: dict, plan: list[str]) -> list[str]:
    """What this run makes: the plan the runner wrote into the log, or -- for a log from before
    it did -- the runner's lists, without run_tests if the run did not start with it."""
    if state.get("plan"):
        return state["plan"]
    seen = [run["name"] for run in state["runs"]]
    if state["current"]:
        seen.append(state["current"]["name"])
    # `run_suites.sh quick` skips run_tests, which is always first.
    if seen and seen[0] != plan[0] and plan[0] not in seen:
        return plan[1:]
    return plan


def load_history(path: Path) -> dict[str, list[float]]:
    """name -> its recorded durations, oldest first. Unreadable lines are skipped."""
    history: dict[str, list[float]] = {}
    try:
        lines = path.read_text(errors="replace").splitlines()
    except FileNotFoundError:
        return history
    for line in lines:
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        try:
            secs = float(parts[1])
        except ValueError:
            continue
        if secs > 0:
            history.setdefault(parts[0], []).append(secs)
    return history


def record(path: Path, name: str, secs: float, code: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a") as handle:
        handle.write(f"{name}\t{int(round(secs))}\t{code}\t{int(time.time())}\n")


def expected(name: str, history: dict[str, list[float]]) -> float | None:
    """How long a suite usually takes: the median of its last few runs. A suite never timed
    is guessed at the median of every suite that has been; with no history at all, None."""
    if history.get(name):
        return statistics.median(history[name][-RECENT:])
    known = [statistics.median(times[-RECENT:]) for times in history.values() if times]
    return statistics.median(known) if known else None


def estimate(state: dict, plan: list[str], history: dict[str, list[float]],
             now: float, running_since: float | None) -> dict:
    """How far through the run is, by time where the history allows and by count where not.

    Returns {fraction, left} -- `left` in seconds, or None when there is no history to guess
    from. A finished suite counts for the time it actually took when the log says, and for
    its usual time otherwise; the running one for as long as it has been running, up to its
    usual time; the rest for their usual times.
    """
    done_names = [run["name"] for run in state["runs"]]
    current = state["current"]
    rest = [name for name in plan if name not in done_names
            and (current is None or name != current["name"])]
    if not history:
        total = len(plan) or 1
        return {"fraction": min(1.0, len(done_names) / total), "left": None}
    done_time = 0.0
    for run in state["runs"]:
        done_time += run["secs"] if run["secs"] else (expected(run["name"], history) or 0.0)
    current_elapsed = 0.0
    current_expected = 0.0
    if current is not None:
        current_expected = expected(current["name"], history) or 0.0
        if running_since is not None:
            current_elapsed = max(0.0, now - running_since)
    rest_time = sum(expected(name, history) or 0.0 for name in rest)
    total = done_time + max(current_expected, current_elapsed) + rest_time
    progress = done_time + min(current_elapsed, current_expected)
    left = max(0.0, current_expected - current_elapsed) + rest_time
    return {"fraction": min(1.0, progress / total) if total > 0 else 0.0, "left": left}


def started_at(log: Path) -> float:
    """When the run began: the stamp run_suites.sh writes as the log's first line.

    NOT the file's birth time, which is what this read first. run_suites.sh empties the log
    rather than making a new one, so the file kept the birth time of the first run ever made
    with it, and a run four minutes old read 96:39:08. A log from before the stamp falls back
    to the birth time, which is right only when the file was new.
    """
    try:
        with log.open(errors="replace") as handle:
            stamped = STARTED.match(handle.readline().strip())
    except FileNotFoundError:
        return time.time()
    if stamped:
        return float(stamped.group(1))
    stat = log.stat()
    return getattr(stat, "st_birthtime", stat.st_mtime)


def clock(seconds: float) -> str:
    hours, rest = divmod(int(seconds), 3600)
    minutes, secs = divmod(rest, 60)
    return f"{hours}:{minutes:02d}:{secs:02d}" if hours else f"{minutes}:{secs:02d}"


def render(state: dict, total: int, elapsed: float, guess: dict,
           running_for: float | None, current_expected: float | None,
           width: int = BAR, columns: int = 160) -> str:
    done = len(state["runs"])
    bad = [run for run in state["runs"] if failed(run)]
    filled = round(width * guess["fraction"])
    bar = "#" * filled + "-" * (width - filled)
    # No guess with no history: said by leaving it out, not with a sentence the bar cannot spare.
    left = f", ~{clock(guess['left'])} left" if guess["left"] is not None else ""
    if state["current"] is not None:
        now = state["current"]["name"]
        if running_for is not None:
            now += f" {clock(running_for)}"
            if current_expected:
                now += f"/~{clock(current_expected)}"
    else:
        now = "finished" if done >= total else "starting"
    # Wall time: a Mac asleep with its lid shut pauses the run and the clock goes on.
    line = (f"[{bar}] {round(100 * guess['fraction']):>3}% {done}/{total}  "
            f"ok {done - len(bad)} failed {len(bad)}  {clock(elapsed)}{left}  > {now}")
    # One line, redrawn in place: a line longer than the terminal wraps and the redraw then
    # stacks copies down the screen instead of replacing itself.
    return line if len(line) <= columns else line[:max(10, columns - 1)]


def _seen_start(name: str, first_seen: dict[str, float], watching_from: float) -> float | None:
    """When this watcher saw a suite begin -- or None for one already running when it started,
    which it saw only part of."""
    began = first_seen.get(name)
    return began if began is not None and began > watching_from + 0.5 else None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("log", nargs="?", default=DEFAULT_LOG)
    parser.add_argument("--once", action="store_true")
    parser.add_argument("--times", default=DEFAULT_TIMES, help="the duration history file")
    args = parser.parse_args()
    log = Path(args.log)
    times = Path(args.times)
    live = sys.stdout.isatty() and not args.once
    reported: set[str] = set()
    # For a log whose runner does not stamp its suites: when THIS saw each one start and end.
    first_seen: dict[str, float] = {}
    recorded: set[str] = set()
    watching_from = time.time()
    last_line = ""
    while True:
        state = read(log)
        plan = plan_for(state, planned())
        total = len(plan)
        finished = len(state["runs"]) >= total
        now = time.time()
        current = state["current"]
        if current is not None and current["name"] not in first_seen:
            first_seen[current["name"]] = now
        # Times this watched from start to end, for a runner that did not write its own: a
        # suite already running when this started is not timed, it is only part of one.
        for run in state["runs"]:
            name = run["name"]
            if name in recorded or args.once:
                continue
            recorded.add(name)
            began = _seen_start(name, first_seen, watching_from)
            if run["secs"] is None and began is not None:
                record(times, name, now - began, run["code"])
        history = load_history(times)
        running_since = None
        if current is not None:
            running_since = current["start"] if current["start"] is not None \
                else _seen_start(current["name"], first_seen, watching_from)
        guess = estimate(state, plan, history, now, running_since)
        # A finished run's time is how long it took, not how long ago it began.
        end = log.stat().st_mtime if finished and log.exists() else now
        elapsed = end - started_at(log) if log.exists() else 0.0
        if finished:
            guess = {"fraction": 1.0, "left": 0.0}
        # Each failure on a line of its own, above the bar, as soon as it happens.
        for run in state["runs"]:
            if failed(run) and run["name"] not in reported:
                reported.add(run["name"])
                why = "script error" if run["broken"] else f"exit {run['code']}"
                print(("\r\033[K" if live else "") + f"  FAILED  {run['name']}  ({why})")
        columns = shutil.get_terminal_size((160, 24)).columns
        line = render(state, total, elapsed, guess,
                      (now - running_since) if running_since is not None else None,
                      expected(current["name"], history) if current is not None else None,
                      columns=columns if live else 400)
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
                print(f"ALL PASSED in {clock(elapsed)}" if not bad
                      else f"FAILED ({len(bad)}): " + " ".join(bad))
            return 0 if finished and not bad else 1
        time.sleep(2.0)


if __name__ == "__main__":
    raise SystemExit(main())
