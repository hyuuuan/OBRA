"""Backend-side recognition telemetry writer.

Thesis §4.7 asks for "optional end-to-end timing logs on both the game and the
recognition backend" so the end-to-end figure can be decomposed. This appends one
anonymous JSON record per prediction to a local JSONL file. Nothing is sent over
the network (the whole system is local); no image data or identifying attribute is
stored. It is opt-in via the OBRA_TELEMETRY environment variable and best-effort:
a logging failure must never break a prediction.

Enable with:
    OBRA_TELEMETRY=1            # 1/true/yes/on
    OBRA_TELEMETRY_DIR=/path    # optional; defaults to <repo>/telemetry
"""

from __future__ import annotations

import json
import os
import threading
import time
from datetime import datetime, timezone
from pathlib import Path


def _truthy(value: str) -> bool:
    return str(value).strip().lower() in {"1", "true", "yes", "on"}


class TelemetryWriter:
    def __init__(self, directory: Path, enabled: bool) -> None:
        self.enabled = enabled
        self.directory = Path(directory)
        self._lock = threading.Lock()

    @classmethod
    def from_env(cls, default_dir: Path) -> "TelemetryWriter":
        enabled = _truthy(os.environ.get("OBRA_TELEMETRY", ""))
        directory = Path(os.environ.get("OBRA_TELEMETRY_DIR", str(default_dir)))
        return cls(directory, enabled)

    def _path_for_today(self) -> Path:
        day = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        return self.directory / f"backend_{day}.jsonl"

    def record_cpu_sample(self, record: dict) -> None:
        """Append one resource sample (see start_resource_sampler). Same file, same rules."""
        self.record_prediction({"type": "cpu", **record})

    def record_prediction(self, record: dict) -> None:
        """Append one prediction record. No-op when disabled; never raises."""
        if not self.enabled:
            return
        try:
            record.setdefault("ts", datetime.now(timezone.utc).isoformat())
            line = json.dumps(record, separators=(",", ":"))
            self.directory.mkdir(parents=True, exist_ok=True)
            with self._lock:
                with open(self._path_for_today(), "a", encoding="utf-8") as handle:
                    handle.write(line + "\n")
        except Exception:
            # Telemetry is best-effort; a prediction must never fail over logging.
            pass


def start_resource_sampler(
    writer: TelemetryWriter, game_pid: int | None, every: float = 1.0
) -> threading.Thread | None:
    """Sample CPU and resident memory of the recogniser and the game, once a second.

    Thesis Table 14 measures "combined utilisation of the game process and the recognition
    process, as a percentage of one core-equivalent", sampled at 1 Hz for the session. Godot
    cannot see another process's CPU, and the recogniser is the one process that knows both
    pids (the game passes its own in OBRA_GAME_PID), so it samples both. psutil's
    cpu_percent is already per one core (it can exceed 100 on several cores).

    Returns None, and samples nothing, when telemetry is off or psutil is missing -- a
    measurement must never stop the recogniser from starting.
    """
    if not writer.enabled:
        return None
    try:
        import psutil
    except ImportError:
        print("telemetry: psutil is not installed; CPU and memory are not sampled")
        return None
    me = psutil.Process(os.getpid())
    game = None
    if game_pid:
        try:
            game = psutil.Process(game_pid)
        except psutil.Error:
            game = None
    # The first cpu_percent of a Process is always 0.0; prime both so the first sample is real.
    for process in (me, game):
        if process is not None:
            process.cpu_percent(None)

    def sample() -> None:
        while True:
            time.sleep(every)
            record = {
                "backend_cpu_percent": me.cpu_percent(None),
                "backend_rss_mb": me.memory_info().rss / 1048576.0,
            }
            if game is not None:
                try:
                    record["game_cpu_percent"] = game.cpu_percent(None)
                    record["game_rss_mb"] = game.memory_info().rss / 1048576.0
                except psutil.Error:
                    pass
            writer.record_cpu_sample(record)

    thread = threading.Thread(target=sample, name="resource-sampler", daemon=True)
    thread.start()
    return thread
