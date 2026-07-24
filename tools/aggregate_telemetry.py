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
    for record in records:
        if record.get("type") == "recognition":
            recognitions.append(record)
        elif isinstance(record.get("timing_ms"), dict):
            infer = record["timing_ms"].get("infer_ms")
            if isinstance(infer, (int, float)):
                backend_infer_ms.append(float(infer))

    total = len(recognitions)
    declines = sum(1 for r in recognitions if r.get("outcome") == "decline")
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
        "class_diversity": len(accepted_classes),
        "latency_ms": {
            "count": len(latencies),
            "mean": (sum(latencies) / len(latencies)) if latencies else None,
            "p50": _percentile(latencies, 50),
            "p95": _percentile(latencies, 95),
            "max": max(latencies) if latencies else None,
        },
        "backend_infer_ms": {
            "count": len(backend_infer_ms),
            "mean": (sum(backend_infer_ms) / len(backend_infer_ms)) if backend_infer_ms else None,
        },
        "labeled_submissions": len(labeled),
        "per_class": per_class,
        "confusion": {f"{t}->{p}": n for (t, p), n in sorted(confusion.items())},
    }


def _print_report(report: dict) -> None:
    print("O.B.R.A. telemetry summary")
    print(f"  submissions:      {report['submissions']}")
    print(f"  accepts:          {report['accepts']}")
    print(f"  declines:         {report['declines']}")
    print(f"  redraw rate:      {report['redraw_rate']:.3f}")
    print(f"  class diversity:  {report['class_diversity']}")
    latency = report["latency_ms"]
    if latency["count"]:
        print(
            "  end-to-end ms:    mean={mean:.1f} p50={p50:.1f} p95={p95:.1f} max={max:.1f} (n={count})".format(
                **latency
            )
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
