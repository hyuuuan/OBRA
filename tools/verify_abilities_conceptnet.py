#!/usr/bin/env python3
"""Check every ConceptNet-sourced ability against the ConceptNet 5.7.0 assertions dump.

WHY. The ability table (game/config/abilities.json) was built while api.conceptnet.io was
down, so all 47 ConceptNet entries are `conceptnet_curated`: documented assertions with
APPROXIMATE weights, none of them read from ConceptNet itself. The thesis (Table 7) says
attribution is resolved against the 5.7.0 dump, and the appeal letter promises the curated
weights are verified before the final defense. This is that check.

For each entry it streams the dump once and reports:
  * whether the curated assertion (start concept, relation, end concept) is in 5.7.0, and
    its real weight there;
  * where it ranks among all of that concept's English edges on the same relation;
  * the top-weighted edge on that relation, for comparison.
Parts of speech are ignored (/c/en/climb/v is /c/en/climb). An end that is only a
different form of the same word (climb / climbing) is reported as a near match, never
counted as found.

    python tools/verify_abilities_conceptnet.py \
        --dump model/data/conceptnet/conceptnet-assertions-5.7.0.csv.gz \
        --out docs/conceptnet_verification.json

The dump (~500 MB) is
https://s3.amazonaws.com/conceptnet/downloads/2019/edges/conceptnet-assertions-5.7.0.csv.gz
"""

from __future__ import annotations

import argparse
import gzip
import json
import re
from collections import defaultdict
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
ABILITIES = REPO_ROOT / "game" / "config" / "abilities.json"
URI = re.compile(r"/a/\[/r/(\w+)/,(/c/en/[^/,\]]+)/?,(/c/en/[^/,\]]+)/?\]")


def base(concept: str) -> str:
    """/c/en/climb/v/wn/... -> /c/en/climb"""
    parts = concept.split("/")
    return "/".join(parts[:4])


def near(a: str, b: str) -> bool:
    """climb ~ climbing ~ climbs: the same word in another form."""
    x, y = a.rsplit("/", 1)[-1], b.rsplit("/", 1)[-1]
    stem = lambda w: re.sub(r"(ing|ed|es|s)$", "", w)  # noqa: E731
    return x != y and (stem(x) == stem(y) or x.startswith(y) or y.startswith(x))


def wanted_entries() -> dict:
    table = json.loads(ABILITIES.read_text(encoding="utf-8"))["abilities"]
    out = {}
    for entity, entry in table.items():
        if entry.get("provenance") == "hand_authored":
            continue
        match = URI.fullmatch(entry["assertion_uri"])
        if not match:
            raise SystemExit(f"{entity}: cannot read assertion_uri {entry['assertion_uri']!r}")
        relation, start, end = match.groups()
        out[entity] = {"relation": relation, "start": start, "end": end,
                       "curated_weight": entry["ability_weight"], "ability": entry["ability"]}
    return out


def scan(dump: Path, entries: dict) -> dict:
    keys = {(e["relation"], e["start"]) for e in entries.values()}
    found = defaultdict(list)  # (relation, start) -> [(end, weight, surface)]
    with gzip.open(dump, "rt", encoding="utf-8") as handle:
        for line in handle:
            parts = line.split("\t")
            if len(parts) < 5 or not parts[2].startswith("/c/en/") or not parts[3].startswith("/c/en/"):
                continue
            relation = parts[1][3:]
            if relation not in ("CapableOf", "UsedFor"):
                continue
            key = (relation, base(parts[2]))
            if key not in keys:
                continue
            info = json.loads(parts[4])
            found[key].append((base(parts[3]), float(info.get("weight", 0.0)),
                               info.get("surfaceText") or ""))
    return found


def verify(entries: dict, found: dict) -> dict:
    report = {}
    for entity, e in entries.items():
        edges = {}
        for end, weight, surface in found.get((e["relation"], e["start"]), []):
            # The same (start, relation, end) can appear with several parts of speech or
            # sources; ConceptNet's own assertion is the strongest of them.
            if end not in edges or weight > edges[end][0]:
                edges[end] = (weight, surface)
        ranked = sorted(edges.items(), key=lambda kv: -kv[1][0])
        exact = edges.get(e["end"])
        near_hits = [(end, w) for end, (w, _) in ranked if near(end, e["end"])]
        rank = [end for end, _ in ranked].index(e["end"]) + 1 if exact else None
        report[entity] = {
            "assertion": f"{e['start']} {e['relation']} {e['end']}",
            "ability": e["ability"],
            "curated_weight": e["curated_weight"],
            "in_conceptnet_5_7": exact is not None,
            "weight_5_7": exact[0] if exact else None,
            "surface_text": exact[1] if exact else None,
            "rank_on_relation": rank,
            "edges_on_relation": len(ranked),
            "top_edge": {"end": ranked[0][0], "weight": ranked[0][1][0]} if ranked else None,
            "near_matches": [{"end": end, "weight": w} for end, w in near_hits[:3]],
        }
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dump", type=Path, required=True)
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()
    entries = wanted_entries()
    report = verify(entries, scan(args.dump, entries))
    found = sum(r["in_conceptnet_5_7"] for r in report.values())
    print(f"{found} of {len(report)} curated assertions are in ConceptNet 5.7.0\n")
    for entity, r in report.items():
        status = (f"FOUND  w={r['weight_5_7']:.3f} (curated {r['curated_weight']}) "
                  f"rank {r['rank_on_relation']}/{r['edges_on_relation']}" if r["in_conceptnet_5_7"]
                  else f"MISSING (curated {r['curated_weight']}); near: "
                  + (", ".join(f"{n['end']} {n['weight']:.2f}" for n in r["near_matches"]) or "none"))
        top = r["top_edge"]
        print(f"  {entity:<16} {r['assertion']:<48} {status}"
              + (f" | top: {top['end']} {top['weight']:.2f}" if top else " | no edges"))
    if args.out:
        args.out.write_text(json.dumps({"dump": "conceptnet-assertions-5.7.0.csv.gz",
                                        "found": found, "checked": len(report),
                                        "entries": report}, indent=2))
        print("\nsaved", args.out)


if __name__ == "__main__":
    main()
