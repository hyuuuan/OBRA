#!/usr/bin/env python3
"""Aggregate O.B.R.A. telemetry logs into recognition-performance metrics.

Reads the JSONL telemetry written by the game (user://telemetry/session_*.jsonl)
and/or the backend (telemetry/backend_*.jsonl) and reports the figures the thesis
asks for: redraw rate, end-to-end and inference latency, class diversity, and — for
drawings whose intended class is known — per-class precision/recall with a confusion
matrix. Per the thesis (§4.2) recognition performance is reported per class, never as
a single aggregate accuracy. Drawings with no known ground truth (ordinary free play)
are counted for redraw/latency but excluded from the confusion matrix.

Usage:
    python tools/aggregate_telemetry.py <file-or-dir> [<file-or-dir> ...] [--out report.json]
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from collections import Counter
from pathlib import Path
from typing import Iterable, Iterator


def _expand(paths: Iterable[str]) -> Iterator[Path]:
    for raw in paths:
        path = Path(raw)
        if path.is_dir():
            yield from sorted(path.rglob("*.jsonl"))
        elif path.exists():
            yield path
        else:
            print(f"no such path: {path}", file=sys.stderr)


def iter_records(paths: Iterable[str]) -> Iterator[dict]:
    for path in _expand(paths):
        try:
            with open(path, encoding="utf-8") as handle:
                for line_no, line in enumerate(handle, 1):
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        yield json.loads(line)
                    except json.JSONDecodeError:
                        print(f"skip malformed line {path}:{line_no}", file=sys.stderr)
        except OSError as error:
            print(f"skip {path}: {error}", file=sys.stderr)


def _percentile(values: list[float], q: float) -> float | None:
    if not values:
        return None
    ordered = sorted(values)
    index = min(len(ordered) - 1, max(0, int(math.ceil(q / 100.0 * len(ordered))) - 1))
    return ordered[index]


def summarize(records: Iterable[dict]) -> dict:
    recognitions: list[dict] = []
    backend_infer_ms: list[float] = []
    # Paint press to the first frame drawn with the entity in the world: the thesis's
    # end-to-end figure (Eq. 12, §4.10.3), which runs "to the appearance of the spawned
    # entity". latency_ms on a recognition stops at the recogniser's answer, short of it.
    spawn_latencies: list[float] = []
    # Thesis Table 14: the game's once-a-second frame rate and memory ("perf"), and the
    # recogniser's once-a-second CPU and memory for both processes ("cpu").
    perf: list[dict] = []
    cpu: list[dict] = []
    # Every accepted drawing judged at an obstacle, with whether it met the obstacle's tag.
    attempts: list[dict] = []
    for record in records:
        kind = record.get("type")
        if kind == "recognition":
            recognitions.append(record)
        elif kind == "spawn" and isinstance(record.get("latency_ms"), (int, float)):
            spawn_latencies.append(float(record["latency_ms"]))
        elif kind == "perf":
            perf.append(record)
        elif kind == "cpu":
            cpu.append(record)
        elif kind == "obstacle_attempt":
            attempts.append(record)
        elif isinstance(record.get("timing_ms"), dict):
            infer = record["timing_ms"].get("infer_ms")
            if isinstance(infer, (int, float)):
                backend_infer_ms.append(float(infer))

    total = len(recognitions)
    declines = sum(1 for r in recognitions if r.get("outcome") == "decline")
    # A decline only a level's raised bar refused (the new brush asking more, thesis
    # §4.5.4.2) is a drawing the fixed floor would have taken. The paper reports recognition
    # against the floor, so it gets a redraw rate that leaves those out.
    floor_declines = sum(
        1 for r in recognitions if r.get("outcome") == "decline" and not r.get("floor_accepted")
    )
    latencies = [
        float(r["latency_ms"]) for r in recognitions if isinstance(r.get("latency_ms"), (int, float))
    ]
    accepted_classes = {
        r.get("entity") for r in recognitions if r.get("outcome") == "accept" and r.get("entity")
    }

    # Ground-truth subset drives the confusion matrix and per-class scores.
    labeled = [r for r in recognitions if r.get("intended_class")]
    confusion: Counter = Counter()
    truth_totals: Counter = Counter()
    pred_totals: Counter = Counter()
    for record in labeled:
        truth = record.get("intended_class")
        predicted = record.get("entity")
        confusion[(truth, predicted)] += 1
        truth_totals[truth] += 1
        pred_totals[predicted] += 1

    # AT THE GATE, which is what the player meets: a drawing counts only if it was accepted
    # AS the intended class, so a decline is a miss. The model's own top-1 is per_class above.
    gate_hits: Counter = Counter()
    for record in labeled:
        if record.get("outcome") == "accept" and record.get("entity") == record.get("intended_class"):
            gate_hits[record.get("intended_class")] += 1
    per_class_at_gate = {
        cls: {"support": n, "accepted_as_intended": gate_hits[cls], "recall": gate_hits[cls] / n}
        for cls, n in sorted(truth_totals.items())
    }

    # AT OBSTACLES, where an intended label exists only after a hint names a class, every
    # drawing still has a measurable outcome: did it meet the tag the obstacle asked for. A
    # declined drawing at an obstacle met nothing.
    declines_at_obstacles = sum(
        1 for r in recognitions if r.get("obstacle_id") and r.get("outcome") == "decline"
    )
    met = sum(1 for a in attempts if a.get("tag_match"))
    at_obstacles = len(attempts) + declines_at_obstacles
    obstacles = {
        "submissions": at_obstacles,
        "accepted": len(attempts),
        "declined": declines_at_obstacles,
        "met_tag": met,
        "met_tag_rate": (met / at_obstacles) if at_obstacles else None,
        "attempts_with_named_class": sum(1 for a in attempts if a.get("named_class")),
    }

    def spread(values: list[float]) -> dict:
        return {
            "count": len(values),
            "p5": _percentile(values, 5),
            "p50": _percentile(values, 50),
            "p95": _percentile(values, 95),
            "min": min(values) if values else None,
            "max": max(values) if values else None,
        }

    def numbers(rows: list[dict], key: str) -> list[float]:
        return [float(r[key]) for r in rows if isinstance(r.get(key), (int, float))]

    submit_fps = numbers(recognitions, "fps_during_submit")
    table_14 = {
        "fps_during_submit": {**spread(submit_fps),
                              "share_below_55": (sum(1 for f in submit_fps if f < 55.0) / len(submit_fps))
                              if submit_fps else None},
        "fps_session": spread(numbers(perf, "fps")),
        "game_static_mb": spread(numbers(perf, "static_mb")),
        "game_video_mb": spread(numbers(perf, "video_mb")),
        "game_cpu_percent": spread(numbers(cpu, "game_cpu_percent")),
        "backend_cpu_percent": spread(numbers(cpu, "backend_cpu_percent")),
        "game_rss_mb": spread(numbers(cpu, "game_rss_mb")),
        "backend_rss_mb": spread(numbers(cpu, "backend_rss_mb")),
    }

    per_class: dict[str, dict] = {}
    for cls in sorted(set(truth_totals) | set(pred_totals)):
        tp = confusion[(cls, cls)]
        fp = pred_totals[cls] - tp
        fn = truth_totals[cls] - tp
        precision = tp / (tp + fp) if (tp + fp) else 0.0
        recall = tp / (tp + fn) if (tp + fn) else 0.0
        f1 = 2 * precision * recall / (precision + recall) if (precision + recall) else 0.0
        per_class[cls] = {
            "support": truth_totals[cls],
            "tp": tp,
            "fp": fp,
            "fn": fn,
            "precision": precision,
            "recall": recall,
            "f1": f1,
        }

    return {
        "submissions": total,
        "accepts": total - declines,
        "declines": declines,
        "redraw_rate": (declines / total) if total else 0.0,
        "redraw_rate_at_floor": (floor_declines / total) if total else 0.0,
        "class_diversity": len(accepted_classes),
        "latency_ms": {
            "count": len(latencies),
            "mean": (sum(latencies) / len(latencies)) if latencies else None,
            "p50": _percentile(latencies, 50),
            "p95": _percentile(latencies, 95),
            "max": max(latencies) if latencies else None,
        },
        "spawn_latency_ms": {
            "count": len(spawn_latencies),
            "p50": _percentile(spawn_latencies, 50),
            "p95": _percentile(spawn_latencies, 95),
            "max": max(spawn_latencies) if spawn_latencies else None,
        },
        "backend_infer_ms": {
            "count": len(backend_infer_ms),
            "mean": (sum(backend_infer_ms) / len(backend_infer_ms)) if backend_infer_ms else None,
        },
        "labeled_submissions": len(labeled),
        "per_class": per_class,
        "confusion": {f"{t}->{p}": n for (t, p), n in sorted(confusion.items())},
        "per_class_at_gate": per_class_at_gate,
        "obstacles": obstacles,
        "table_14": table_14,
    }


def _print_report(report: dict) -> None:
    print("O.B.R.A. telemetry summary")
    print(f"  submissions:      {report['submissions']}")
    print(f"  accepts:          {report['accepts']}")
    print(f"  declines:         {report['declines']}")
    print(f"  redraw rate:      {report['redraw_rate']:.3f}")
    print(f"  ...at the floor:  {report['redraw_rate_at_floor']:.3f}")
    print(f"  class diversity:  {report['class_diversity']}")
    latency = report["latency_ms"]
    if latency["count"]:
        print(
            "  to answer ms:     mean={mean:.1f} p50={p50:.1f} p95={p95:.1f} max={max:.1f} (n={count})".format(
                **latency
            )
        )
    spawn = report["spawn_latency_ms"]
    if spawn["count"]:
        print(
            "  to appearance ms: p50={p50:.1f} p95={p95:.1f} max={max:.1f} (n={count})".format(**spawn)
        )
    backend = report["backend_infer_ms"]
    if backend["count"]:
        print(f"  backend infer ms: mean={backend['mean']:.1f} (n={backend['count']})")
    if report["per_class"]:
        print(f"\n  Per-class (from {report['labeled_submissions']} labeled submissions):")
        print(f"    {'class':<16}{'support':>8}{'prec':>8}{'recall':>8}{'f1':>8}")
        for cls, metrics in report["per_class"].items():
            print(
                f"    {cls:<16}{metrics['support']:>8}{metrics['precision']:>8.2f}"
                f"{metrics['recall']:>8.2f}{metrics['f1']:>8.2f}"
            )
    else:
        print("\n  No ground-truth (intended_class) records — confusion matrix omitted.")
    obstacles = report["obstacles"]
    if obstacles["submissions"]:
        print(f"\n  At obstacles: {obstacles['submissions']} drawings, {obstacles['met_tag']} met the "
              f"tag asked for ({obstacles['met_tag_rate']:.3f}); {obstacles['declined']} declined; "
              f"{obstacles['attempts_with_named_class']} after a hint named a class")
    table = report["table_14"]
    fps = table["fps_during_submit"]
    if fps["count"]:
        print(f"  fps during submit: p50={fps['p50']:.1f} min={fps['min']:.1f} "
              f"below 55: {fps['share_below_55']:.3f} (n={fps['count']})")
    for key, label in (("fps_session", "fps (session)"), ("game_static_mb", "game memory MB"),
                       ("game_cpu_percent", "game CPU %"), ("backend_cpu_percent", "recogniser CPU %")):
        row = table[key]
        if row["count"]:
            print(f"  {label + ':':<19}p50={row['p50']:.1f} p95={row['p95']:.1f} max={row['max']:.1f} "
                  f"(n={row['count']})")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Aggregate O.B.R.A. telemetry logs.")
    parser.add_argument("paths", nargs="+", help="JSONL files or directories to scan")
    parser.add_argument("--out", type=Path, help="write the full report as JSON here")
    args = parser.parse_args(argv)

    report = summarize(iter_records(args.paths))
    _print_report(report)
    if args.out:
        args.out.write_text(json.dumps(report, indent=2))
        print(f"\nWrote {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
