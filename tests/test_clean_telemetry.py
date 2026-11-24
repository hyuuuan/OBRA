"""tools/chapter5/clean_telemetry.py applies Part C0's cleaning to a made-up export."""
import importlib.util
import json
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path

_SPEC = importlib.util.spec_from_file_location(
    "clean_telemetry", Path(__file__).resolve().parents[1] / "tools" / "chapter5" / "clean_telemetry.py")
clean = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(clean)


def _epoch(*parts) -> float:
    return datetime(*parts, tzinfo=timezone.utc).timestamp()


def _session(folder: Path, name: str, start: float, submissions: int) -> None:
    (folder / "telemetry").mkdir(parents=True, exist_ok=True)
    rows = [{"type": "session_start", "ts": start}]
    rows += [{"type": "recognition", "outcome": "accept", "ts": start + 10 + i} for i in range(submissions)]
    rows.append({"type": "session_end", "ts": start + 600})
    (folder / "telemetry" / name).write_text("".join(json.dumps(r) + "\n" for r in rows), encoding="utf-8")


def _backend(folder: Path, stamps: list[str]) -> None:
    (folder / "telemetry").mkdir(parents=True, exist_ok=True)
    rows = [{"type": "cpu", "ts": s} for s in stamps]
    (folder / "telemetry" / "backend_x.jsonl").write_text(
        "".join(json.dumps(r) + "\n" for r in rows), encoding="utf-8")


class CleanTelemetryTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name) / "OBRA_PLAYTEST"
        lab = _epoch(2026, 11, 16, 1, 45)
        # A lab folder nested in R08 (complete) and its partial top-level copy.
        _session(root / "R08" / "L1", "session_a.jsonl", lab, 3)
        _session(root / "L1", "session_a.jsonl", lab, 1)
        # A lab folder only at the top level is kept.
        _session(root / "L2", "session_b.jsonl", lab + 60, 2)
        # The day is Manila's: 00:30 on 16 Nov there is still 15 Nov in UTC.
        _session(root / "L3", "session_e.jsonl", _epoch(2026, 11, 15, 16, 30), 1)
        # R08's own pilot sitting, beside the lab folders.
        _session(root / "R08", "session_c.jsonl", _epoch(2026, 11, 11, 10, 18), 1)
        # R03-1 is superseded by R03-2.
        _session(root / "R03-1", "session_d.jsonl", _epoch(2026, 11, 9, 7, 0), 1)
        _session(root / "R03-2", "session_d.jsonl", _epoch(2026, 11, 9, 7, 0), 1)
        # R05: only the 9 Nov 18:44 (Manila) sitting is a participant's.
        _session(root / "R05", "session_old.jsonl", _epoch(2026, 7, 25, 3, 0), 9)
        _session(root / "R05", "session_pilot.jsonl", _epoch(2026, 11, 9, 10, 44), 4)
        _backend(root / "R05", ["2026-07-25T03:00:20+00:00", "2026-11-09T10:45:00+00:00"])
        self.out = Path(self.tmp.name) / "clean"
        self.assertEqual(clean.main(["x", str(root.parent), str(self.out)]), 0)

    def tearDown(self):
        self.tmp.cleanup()

    def _key(self):
        import csv
        with open(self.out / "key.csv", encoding="utf-8") as handle:
            return {row["folder"].replace("\\", "/"): row for row in csv.DictReader(handle)}

    def _submissions(self, group, code):
        files = (self.out / group / code / "telemetry").glob("session_*.jsonl")
        return sum(line.count('"recognition"') for f in files for line in f.read_text().splitlines())

    def test_groups_and_codes(self):
        key = self._key()
        self.assertEqual(sorted(key), ["L2", "L3", "R03-2", "R05", "R08", "R08/L1"])
        self.assertEqual({k: v["group"] for k, v in key.items()},
                         {"L2": "main", "L3": "main", "R03-2": "pilot", "R05": "pilot", "R08": "pilot",
                          "R08/L1": "main"})
        # Codes follow first session start: the pilot first.
        self.assertEqual([key[k]["code"] for k in ("R03-2", "R05", "R08", "L3", "R08/L1", "L2")],
                         ["P01", "P02", "P03", "P04", "P05", "P06"])

    def test_nested_copy_wins(self):
        self.assertEqual(self._submissions("main", self._key()["R08/L1"]["code"]), 3)

    def test_dev_machine_keeps_only_its_pilot_sitting(self):
        code = self._key()["R05"]["code"]
        self.assertEqual(self._submissions("pilot", code), 4)
        backend = (self.out / "pilot" / code / "telemetry" / "backend_x.jsonl").read_text().splitlines()
        self.assertEqual(len(backend), 1)
        self.assertIn("2026-11-09", backend[0])


if __name__ == "__main__":
    unittest.main()
