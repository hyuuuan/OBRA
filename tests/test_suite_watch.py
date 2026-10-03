"""The suite progress bar says how far through a run is, by time, and what failed.

Run from the repo root:
    python -m unittest tests.test_suite_watch -v

Kent: "can i have a tracker or progress bar for the running suites and also for the future".
tools/suite_watch.py reads a run's log as it is written. These hold what it reads off a log --
in the runner's old format and its new one, which stamps each suite's start and duration --
and the estimate it makes from the duration history: a bar that fills by time, because
run_tests alone is a quarter of the run and "1 of 62" after twelve minutes said nothing.
"""

from __future__ import annotations

import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "tools"))

import suite_watch as watch  # noqa: E402


OLD_LOG = """started 1000
########## run_tests
lots of output
[exit 0]
########## run_level_ready
SCRIPT ERROR: Parse Error: something
[exit 0]
########## run_walk_level1
still going
"""

NEW_LOG = """started 1000
########## run_tests
[start 1000]
[exit 0 in 700s]
########## run_level_ready
[start 1700]
[exit 1 in 20s]
########## run_walk_level1
[start 1720]
"""


class ReadsTheLog(unittest.TestCase):
    def test_old_format_finished_and_running(self) -> None:
        state = watch.parse(OLD_LOG)
        self.assertEqual([run["name"] for run in state["runs"]], ["run_tests", "run_level_ready"])
        self.assertEqual(state["current"]["name"], "run_walk_level1")
        self.assertIsNone(state["runs"][0]["secs"])
        self.assertIsNone(state["current"]["start"])

    def test_a_script_error_is_a_failure_even_at_exit_zero(self) -> None:
        state = watch.parse(OLD_LOG)
        self.assertFalse(watch.failed(state["runs"][0]))
        self.assertTrue(watch.failed(state["runs"][1]))

    def test_new_format_carries_start_and_duration(self) -> None:
        state = watch.parse(NEW_LOG)
        self.assertEqual(state["runs"][0]["secs"], 700.0)
        self.assertEqual(state["runs"][1]["code"], 1)
        self.assertTrue(watch.failed(state["runs"][1]))
        self.assertEqual(state["current"]["start"], 1720.0)

    def test_quick_run_plans_without_run_tests(self) -> None:
        plan = ["run_tests", "run_level_ready", "python"]
        quick = watch.parse("########## run_level_ready\n[exit 0]\n")
        self.assertEqual(watch.plan_for(quick, plan), ["run_level_ready", "python"])
        self.assertEqual(watch.plan_for(watch.parse(OLD_LOG), plan), plan)

    def test_a_run_of_a_few_suites_is_a_bar_of_a_few(self) -> None:
        log = "started 1\nplan run_tutorial_audit python\n########## run_tutorial_audit\n[exit 0]\n"
        state = watch.parse(log)
        self.assertEqual(watch.plan_for(state, ["run_tests", "run_tutorial_audit", "python"]),
                         ["run_tutorial_audit", "python"])

    def test_the_plan_is_read_off_the_runner(self) -> None:
        plan = watch.planned()
        self.assertEqual(plan[0], "run_tests")
        self.assertEqual(plan[-1], "python")
        self.assertIn("run_tutorial_popup_probe", plan)


class EstimatesByTime(unittest.TestCase):
    PLAN = ["slow", "quick", "other"]
    HISTORY = {"slow": [90.0, 100.0, 110.0], "quick": [10.0], "other": [10.0]}

    def test_no_history_falls_back_to_the_count_and_does_not_guess(self) -> None:
        state = watch.parse("########## slow\n[exit 0]\n")
        guess = watch.estimate(state, self.PLAN, {}, now=0.0, running_since=None)
        self.assertAlmostEqual(guess["fraction"], 1 / 3)
        self.assertIsNone(guess["left"])

    def test_the_slow_one_done_is_most_of_the_bar(self) -> None:
        state = watch.parse("########## slow\n[exit 0 in 100s]\n")
        guess = watch.estimate(state, self.PLAN, self.HISTORY, now=0.0, running_since=None)
        self.assertAlmostEqual(guess["fraction"], 100 / 120)
        self.assertAlmostEqual(guess["left"], 20.0)

    def test_the_running_one_counts_for_how_long_it_has_run(self) -> None:
        state = watch.parse("########## slow\n[exit 0 in 100s]\n########## quick\n[start 50]\n")
        guess = watch.estimate(state, self.PLAN, self.HISTORY, now=55.0, running_since=50.0)
        self.assertAlmostEqual(guess["fraction"], 105 / 120)
        self.assertAlmostEqual(guess["left"], 15.0)

    def test_a_suite_over_its_usual_time_does_not_run_the_bar_past_it(self) -> None:
        state = watch.parse("########## slow\n[start 0]\n")
        guess = watch.estimate(state, self.PLAN, self.HISTORY, now=300.0, running_since=0.0)
        self.assertLess(guess["fraction"], 1.0)
        self.assertAlmostEqual(guess["left"], 20.0)

    def test_a_suite_never_timed_is_guessed_from_the_others(self) -> None:
        history = {"slow": [100.0], "quick": [10.0]}
        self.assertEqual(watch.expected("other", history), 55.0)
        self.assertIsNone(watch.expected("other", {}))


class KeepsTheHistory(unittest.TestCase):
    def test_record_and_read_back_skipping_junk(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "nested" / "times.tsv"
            watch.record(path, "slow", 99.6, 0)
            watch.record(path, "slow", 120.0, 0)
            with path.open("a") as handle:
                handle.write("garbage\nslow\tnot-a-number\n")
            history = watch.load_history(path)
            self.assertEqual(history, {"slow": [100.0, 120.0]})
            self.assertEqual(watch.expected("slow", history), 110.0)


class Draws(unittest.TestCase):
    def test_one_line_never_wider_than_the_terminal(self) -> None:
        state = watch.parse(NEW_LOG)
        guess = {"fraction": 0.5, "left": 600.0}
        line = watch.render(state, 62, 1234.0, guess, 30.0, 180.0, columns=60)
        self.assertLessEqual(len(line), 60)
        full = watch.render(state, 62, 1234.0, guess, 30.0, 180.0, columns=400)
        self.assertIn("50%", full)
        self.assertIn(" 2/62 ", full)
        self.assertIn("failed 1", full)
        self.assertIn("~10:00 left", full)
        self.assertIn("run_walk_level1 0:30/~3:00", full)

    def test_once_on_a_finished_run_reports_and_exits_by_verdict(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            runner_names = watch.planned()
            passed = ["started %d" % int(time.time())]
            for name in runner_names:
                passed += [f"########## {name}", "[start 1]", "[exit 0 in 2s]"]
            log = Path(folder) / "log"
            log.write_text("\n".join(passed) + "\n")
            times = Path(folder) / "times.tsv"
            done = subprocess.run([sys.executable, str(REPO_ROOT / "tools" / "suite_watch.py"),
                                   str(log), "--once", "--times", str(times)],
                                  capture_output=True, text=True)
            self.assertEqual(done.returncode, 0, done.stdout + done.stderr)
            self.assertIn("ALL PASSED", done.stdout)
            log.write_text(log.read_text().replace("[exit 0 in 2s]", "[exit 1 in 2s]", 1))
            done = subprocess.run([sys.executable, str(REPO_ROOT / "tools" / "suite_watch.py"),
                                   str(log), "--once", "--times", str(times)],
                                  capture_output=True, text=True)
            self.assertEqual(done.returncode, 1)
            self.assertIn("FAILED (1): run_tests", done.stdout)


if __name__ == "__main__":
    unittest.main()
