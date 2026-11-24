# Telemetry: the repo's tool against Part C (24 Nov 2026)

Section 2, item 17 of `docs/CHAPTER5_BRIEF.md`, and the to-do's "Run `tools/aggregate_telemetry.py`".
The export is the shared Drive folder OBRA_PLAYTEST, downloaded 24 Nov, cleaned as Part C0 says by
`tools/chapter5/clean_telemetry.py`. Aggregate figures only; the cleaned folders and their key stay private.

**Provisional.** One participant's telemetry is to be replaced. When the new folder arrives, re-run the
three commands below and redo this comparison.

```
python tools/chapter5/clean_telemetry.py <unzipped OBRA_PLAYTEST> <private out>
python tools/aggregate_telemetry.py <private out>/main  --out <private out>/agg_main.json
python tools/aggregate_telemetry.py <private out>/pilot --out <private out>/agg_pilot.json
```

## The sample after cleaning

43 participants: 33 main study (P11–P43, 16 Nov, 18 starting 09:40–10:02 and 15 starting 10:16–10:28)
and 10 pilot (P01–P10, 6–12 Nov). This matches C0.

## Self-checks (C0, "Three self-checks")

- Each participant's `profile.json` submission and decline counts equal their logs: **43 of 43**.
- A second count straight from the logs gives Table 23 and the Started and Completed columns of
  Table 30 exactly, for both groups.

## Figures that agree

| Figure | Part C | Tool |
|---|---|---|
| Main: submissions, accepted, declined | 770, 523, 247 | 770, 523, 247 |
| Main: declined at the floor / by the bar | 30.6% / 1.4% | 30.6% / 11 submissions |
| Main: classes accepted at least once | 37 | 37 |
| Main: end to end, median / 95th percentile (ms) | 333 / 438 | 333.3 / 437.9 |
| Main: round trip, median / 95th percentile (ms) | 84 / 129 | 83.5 / 128.9 |
| Main: recogniser requests served | 24,124 | 24,124 |
| Main: submission windows below 55 fps | 4 of 770 | 0.5% of 770, lowest 42.7 |
| Main: 1 Hz frame-rate samples | 60,573 | 60,573 |
| Main: recogniser CPU, median / peak (% of one core) | 0.0 / 125.0 | 0.0 / 125.0 |
| Main: game CPU peak (% of one core) | 143.8 | 143.8 |
| Main: `static_mb` | zero in the exported build | 0.0 throughout |
| Main: submissions at an obstacle, declined there | 487, 146 | 146 declined |
| Main: drawings whose third hint named a class | 10 | 10 |
| Pilot: submissions, accepted, floor declines | 332, 262 (78.9%), 17.5% | 332, 262, 17.5% |
| Pilot: end to end, median / 95th percentile (ms) | 267 / 425 | 266.6 / 425.3 |

The tool takes the 95th percentile by nearest rank, Part C by linear interpolation. Every figure above
rounds to the same value either way.

## The one figure that differs: meeting the obstacle's tag

| | Part C2 | Tool |
|---|---|---|
| Drawings counted at obstacles | 487 | 528 |
| Met the tag | 190 (39.0%) | 249 (47.2%) |

**This is a difference of definition, not a miscount.** Both agree that 487 drawings were submitted at an
obstacle, 341 accepted and 146 declined. Part C counts each accepted drawing once, by its first use on the
obstacle it was drawn at, before the next submission. The tool counts every `obstacle_attempt` event: 382
of them, because one drawing can be tried more than once or on another obstacle. Its denominator is those
382 attempts plus the 146 declines.

The brief gives two rules here. Part C says the tool's definition governs, and section 0 says to flag a
difference of method and not pick one. It is flagged for Kaina. Part C's figure answers "what share of the
drawings made at an obstacle met its tag", which is what §5.2.2C says.

## Not checked by the tool

The tool doesn't compute Table 27's components by machine, Table 28's per-session medians, Table 30's
times and redraw rates by level, Table 31, or Figures 28–30. The counts in Tables 23 and 30 were checked by
the second count above.
