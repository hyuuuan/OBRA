#!/usr/bin/env python3
"""Build game/config/tags.json -- the ability-tag layer Level 1's obstacles declare.

WHY THIS EXISTS, AND WHY IT IS GENERATED RATHER THAN HAND-WRITTEN
-----------------------------------------------------------------
Obstacles declare a *tag* ("Span", "Climb"), never a class, and the loader resolves the
satisfying classes at load time. That indirection is what lets a level ask for an ability
without naming a drawing, and it is what makes the anti-stuck fallback fall out of the
data model instead of being special-cased per obstacle.

The tags are NOT derivable from abilities.json. That table gives each class exactly one
ConceptNet verb -- bat is "fly", crab is "pinch", tree is "shade" -- while the design's
Climb tag wants all three of them alongside spider and ladder. So the grouping below is a
DESIGN artifact, authored by hand, and the thesis must not present it as ConceptNet output.

What this script does is make that boundary checkable rather than asserted. The design
table is the only hand-written thing here; for every (tag, class) pair it then looks up
what abilities.json actually says and records:

    conceptnet_aligned   the ConceptNet verb for that class IS this tag
    design_authored      it is not -- and `source_ability` names the verb it really is

So the generated file carries, per membership, whether the grounding is borrowed or
invented. NFR-27 asks for exactly this and warns against claiming one relation supplies
everything. Re-run after any edit to abilities.json and the provenance re-derives; it
cannot silently drift the way a hand-maintained table would.

USAGE
    python3 tools/build_tags.py            # write game/config/tags.json
    python3 tools/build_tags.py --check    # verify the committed file is up to date
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
ABILITIES = REPO_ROOT / "game" / "config" / "abilities.json"
ENTITIES = REPO_ROOT / "game" / "config" / "entities.json"
OUT = REPO_ROOT / "game" / "config" / "tags.json"

# ---------------------------------------------------------------------------
# THE DESIGN TABLE. The only hand-authored thing in this file.
#
# Source: level-1-design/files/OBRA_Level1_Payyo_BuildSpec.md section 3.1.
# Order within a tag is the spec's order and is preserved so the two can be diffed.
#
# A tag with an empty class list is declared but not yet populated -- it exists so the
# Ability Book can render it as a locked blind deboss rather than omitting it, which is
# how the player learns that abilities they do not have are a known, finite set.
# ---------------------------------------------------------------------------
LEVEL_1_TAGS: dict[str, list[str]] = {
    "span":    ["bridge", "ladder", "square", "triangle"],
    "roll":    ["circle", "wheel"],
    "climb":   ["spider", "bat", "monkey", "crab", "ladder", "stairs", "tree", "snake"],
    "leap":    ["frog", "horse", "penguin", "mushroom"],
    "cut":     ["axe", "sword", "scissors", "elephant"],
    "forage":  ["rake", "pig"],
    "carry":   ["ant", "horse", "elephant", "octopus", "bucket", "monkey"],
    "weather": ["fan", "butterfly", "cloud", "sun", "bucket"],
    "unlock":  ["key", "door"],
}

# Held for later levels (spec 3.1). Declared, deliberately empty -- see the note above.
HELD_TAGS: list[str] = ["fly", "swim", "crush", "strike", "light", "shield"]

DISPLAY = {
    "span": "Span", "roll": "Roll", "climb": "Climb", "leap": "Leap", "cut": "Cut",
    "forage": "Forage", "carry": "Carry", "weather": "Weather", "unlock": "Unlock",
    "fly": "Fly", "swim": "Swim", "crush": "Crush", "strike": "Strike",
    "light": "Light", "shield": "Shield",
}

# Which level first unlocks each tag. Level 1 unlocks 9 of 15 because a tutorial has to
# show the breadth of the system; later levels add classes under tags already known.
UNLOCK_LEVEL = {t: 1 for t in LEVEL_1_TAGS} | {
    "fly": 2, "swim": 3, "strike": 3, "crush": 4, "light": 4, "shield": 5,
}

# The floor from the spec: an obstacle must never resolve to a single drawing, or a
# player who cannot draw that one thing is stuck with no alternative.
MIN_CLASSES_PER_TAG = 2


def load_json(path: Path) -> dict:
    return json.loads(path.read_text())


def build() -> dict:
    abilities = load_json(ABILITIES)["abilities"]
    roster = {e["id"]: e for e in load_json(ENTITIES)["entities"]}

    errors: list[str] = []
    tags: dict[str, dict] = {}

    for tag, members in list(LEVEL_1_TAGS.items()) + [(t, []) for t in HELD_TAGS]:
        classes: dict[str, dict] = {}
        for class_id in members:
            if class_id not in roster:
                errors.append(f"tag {tag!r} names {class_id!r}, which is not in the roster")
                continue
            entry = abilities.get(class_id, {})
            verb = str(entry.get("ability", "")).strip()
            aligned = verb == tag
            record = {
                "provenance": "conceptnet_aligned" if aligned else "design_authored",
                "source_ability": verb,
            }
            if not aligned:
                # Kept so a reader can see exactly what was borrowed from and what was
                # not. Without it "design_authored" is an unfalsifiable label.
                record["note"] = (
                    f"ConceptNet grounds {class_id} as {verb!r}; membership in {tag!r} is a "
                    f"design grouping, not a ConceptNet assertion."
                )
            classes[class_id] = record

        if members and len(classes) < MIN_CLASSES_PER_TAG:
            errors.append(
                f"tag {tag!r} resolves {len(classes)} class(es); the floor is "
                f"{MIN_CLASSES_PER_TAG} or an obstacle needing it has one solution")

        tags[tag] = {
            "display_name": DISPLAY[tag],
            "unlocked_in_level": UNLOCK_LEVEL[tag],
            "declared_only": not members,
            "classes": classes,
        }

    if errors:
        for e in errors:
            print(f"ERROR: {e}", file=sys.stderr)
        raise SystemExit(1)

    total = sum(len(t["classes"]) for t in tags.values())
    aligned = sum(1 for t in tags.values() for c in t["classes"].values()
                  if c["provenance"] == "conceptnet_aligned")
    untagged = sorted(set(roster) - {c for t in tags.values() for c in t["classes"]})

    return {
        "version": 1,
        "generated_by": "tools/build_tags.py",
        "note": (
            "Ability tags. Obstacles declare a TAG and the loader resolves satisfying "
            "CLASSES at load time; no obstacle names a class. This grouping is a DESIGN "
            "artifact and is not ConceptNet output -- abilities.json gives each class one "
            "verb, and the tags deliberately cut across those verbs. Per-membership "
            "provenance below says which is which. Regenerate with tools/build_tags.py."
        ),
        "provenance_summary": {
            "memberships_total": total,
            "conceptnet_aligned": aligned,
            "design_authored": total - aligned,
            "statement": (
                f"{aligned} of {total} tag memberships reuse the class's own ConceptNet "
                f"verb; the remaining {total - aligned} are design groupings. Do not "
                f"describe the tag layer as ConceptNet-derived."
            ),
        },
        "unhintable_classes": {
            "classes": untagged,
            "note": (
                "In the roster and drawable, but carrying no tag yet, so no obstacle can "
                "ask for them. Most of these are waiting on the six tags declared here "
                "with no members (fly, swim, crush, strike, light, shield), which later "
                "levels populate -- a bird or a shark is unhintable today and will not be "
                "once Fly and Swim exist. Build spec 12.2 names clock and snail as the "
                "residue that no planned tag covers; that claim is about the END state, "
                "so re-read this list once the held tags are filled in."
            ),
            "held_tags_still_empty": sorted(
                t for t, v in tags.items() if v["declared_only"]),
        },
        "min_classes_per_tag": MIN_CLASSES_PER_TAG,
        "tags": tags,
    }


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true",
                    help="fail if the committed file differs from a fresh build")
    args = ap.parse_args()

    built = build()
    text = json.dumps(built, indent=2) + "\n"

    if args.check:
        if not OUT.exists():
            print(f"{OUT} does not exist", file=sys.stderr)
            return 1
        if OUT.read_text() != text:
            print(f"{OUT} is stale -- re-run tools/build_tags.py", file=sys.stderr)
            return 1
        print(f"{OUT} is up to date")
        return 0

    OUT.write_text(text)
    s = built["provenance_summary"]
    print(f"Wrote {OUT}")
    print(f"  {len(built['tags'])} tags, {s['memberships_total']} memberships "
          f"({s['conceptnet_aligned']} conceptnet-aligned, {s['design_authored']} design-authored)")
    if built["unhintable_classes"]["classes"]:
        print(f"  unhintable (no tag): {', '.join(built['unhintable_classes']['classes'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
