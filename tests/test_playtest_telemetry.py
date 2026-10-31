"""What the playtest logs can be turned into: thesis Table 14 and live-play recall.

    python -m unittest -v tests.test_playtest_telemetry

The resource-sampler test is skipped where psutil is not installed (the recogniser's
requirements install it; it is optional so a missing package never stops the recogniser).
"""

import importlib.util
import json
import sys
import tempfile
import time
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "tools"))
sys.path.insert(0, str(REPO_ROOT / "backend"))

import aggregate_telemetry  # noqa: E402
from telemetry import TelemetryWriter, start_resource_sampler  # noqa: E402

HAVE_PSUTIL = importlib.util.find_spec("psutil") is not None

SESSION = [
    # After a hint named "ladder": one accepted as a ladder, one declined -- recall 1/2.
    {"type": "recognition", "outcome": "accept", "entity": "ladder", "intended_class": "ladder",
     "obstacle_id": "O1", "fps_during_submit": 58.0},
    {"type": "recognition", "outcome": "decline", "entity": "fish", "intended_class": "ladder",
     "obstacle_id": "O1", "fps_during_submit": 50.0},
    # No hint named a class here: it counts toward the tag outcome only.
    {"type": "recognition", "outcome": "accept", "entity": "bridge", "obstacle_id": "O2",
     "fps_during_submit": 60.0},
    {"type": "obstacle_attempt", "obstacle_id": "O1", "tag_match": True, "named_class": "ladder"},
    {"type": "obstacle_attempt", "obstacle_id": "O2", "tag_match": False, "named_class": ""},
    {"type": "perf", "fps": 60, "static_mb": 300, "video_mb": 120},
    {"type": "cpu", "backend_cpu_percent": 12.0, "game_cpu_percent": 40.0},
]


class AggregateTests(unittest.TestCase):
    def setUp(self):
        self.report = aggregate_telemetry.summarize(iter(SESSION))

    def test_a_decline_after_a_named_hint_is_a_miss_at_the_gate(self):
        self.assertEqual(self.report["per_class_at_gate"]["ladder"],
                         {"support": 2, "accepted_as_intended": 1, "recall": 0.5})

    def test_every_drawing_at_an_obstacle_has_a_tag_outcome(self):
        obstacles = self.report["obstacles"]
        self.assertEqual((obstacles["submissions"], obstacles["met_tag"], obstacles["declined"]),
                         (3, 1, 1))
        self.assertAlmostEqual(obstacles["met_tag_rate"], 1 / 3)

    def test_table_14_reads_the_frame_rate_floor_and_both_processes(self):
        table = self.report["table_14"]
        self.assertAlmostEqual(table["fps_during_submit"]["share_below_55"], 1 / 3)
        self.assertEqual(table["game_cpu_percent"]["p50"], 40.0)
        self.assertEqual(table["backend_cpu_percent"]["p50"], 12.0)
        self.assertEqual(table["fps_session"]["count"], 1)


@unittest.skipUnless(HAVE_PSUTIL, "psutil is not installed")
class ResourceSamplerTests(unittest.TestCase):
    def test_it_samples_both_processes_into_the_backend_log(self):
        import os

        with tempfile.TemporaryDirectory() as folder:
            writer = TelemetryWriter(Path(folder), enabled=True)
            # This process stands in for the game.
            self.assertIsNotNone(start_resource_sampler(writer, os.getpid(), every=0.05))
            time.sleep(0.4)
            lines = [json.loads(line) for log in Path(folder).glob("backend_*.jsonl")
                     for line in log.read_text().splitlines()]
        samples = [r for r in lines if r.get("type") == "cpu"]
        self.assertTrue(samples)
        for key in ("backend_cpu_percent", "backend_rss_mb", "game_cpu_percent", "game_rss_mb"):
            self.assertIn(key, samples[-1])

    def test_nothing_is_sampled_when_telemetry_is_off(self):
        self.assertIsNone(start_resource_sampler(TelemetryWriter(Path("."), enabled=False), None))


if __name__ == "__main__":
    unittest.main()
