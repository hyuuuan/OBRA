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
