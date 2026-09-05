#!/usr/bin/env python3
"""Does every class actually DO its ability, in the world, where the player is standing?

WHY THIS EXISTS
---------------
Three tables describe what a drawing can do and none of them is the game.

    abilities.json   one ConceptNet verb per class -- ladder "climb", crab "pinch"
    tags.json        the design's ability groups; obstacles declare a TAG, never a class
    entities.json    the runtime role and, for objects, the utility_behavior

An obstacle declaring Climb is solved by anything in the Climb tag. That is the whole
point of the indirection -- but it means the tag layer can agree with the player and the
world can then do nothing, which is the single worst failure this project can ship. It has
happened twice already: Strike resolved to a blade that swings inside 96px against a bird
in the air, and Climb resolves to a monkey that has no wall-climb drive at all.

So this reads the three tables AND the two scripts that implement behaviour, and reports
every class whose declared ability or tag membership has nothing behind it.

    utility_object.gd     HELD_TOOLS, the _perform_use match, the prop effects, and the
                          interact() special cases (ladder, sailboat, submarine)
    playable_entity.gd    the rig_type drive branches, and any entity_id hard-coded past
                          them -- an entity_id branch is exactly how a capability ends up
                          belonging to one animal instead of to a profile flag

⚠ THE CLASS -> MECHANISM HALF IS PARSED, NOT DECLARED. That is the half that drifts: a
behaviour deleted from the match statement, a rig_type changed in a profile. The TAG ->
MECHANISM half below is hand-written, because "what would satisfy Climb" is a design
judgement and cannot be read off anything.

    python3 tools/audit_abilities.py            # the report
    python3 tools/audit_abilities.py --check    # non-zero if anything is UNIMPLEMENTED
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG = ROOT / "game" / "config"
SCRIPTS = ROOT / "game" / "scripts"

## What a class must be able to DO for a tag membership to be honest. A tag whose verb is
## satisfied by the drawing merely existing (a square spans a gap because it is a solid
## body) needs no mechanism; those are listed as None and never reported.
##
## ⚠ HAND-WRITTEN, AND THE ONLY HAND-WRITTEN THING HERE. Adding a tag without adding a row
## raises, rather than defaulting to "satisfied" -- a silent default is how a tag with no
## mechanism would pass this audit.
TAG_NEEDS: dict[str, str | None] = {
    "span": None,        # a placed solid body is a span
    "roll": None,        # a round body rolls because it is round
    "climb": "climb",    # a wall-climb drive, a ladder interaction, or flight
    "leap": "leap",      # a jump impulse that clears more than a walk
    "cut": "cut",        # a swing that damages what it meets
    "forage": "forage",
    "carry": "carry",
    "weather": "weather",
    "unlock": "unlock",
    "burrow": "burrow",
    "feed": "feed",
    "startle": "startle",
    "strike": "strike",
    "fly": "fly",
    "swim": "swim",
    "crush": "crush",
    "light": "light",
    "shield": "shield",
}


def read(name: str) -> dict:
    return json.loads((CONFIG / name).read_text())


def parsed_utility_behaviours() -> dict[str, set[str]]:
    """What `utility_object.gd` actually implements, per utility_behavior name."""
    text = (SCRIPTS / "utility_object.gd").read_text()
    found: dict[str, set[str]] = {}

    def note(name: str, mechanism: str) -> None:
        found.setdefault(name, set()).add(mechanism)

    # ⚠ FOLLOW THE CONSTANTS. The behaviours moved out of literal lists and into named
    # arrays (`CLIMBABLE_PROPS`), and a parser that only reads string literals reported the
    # ladder as having no interact case the moment it stopped being spelled out there. A
    # static audit that goes red on a refactor teaches people to ignore it.
    consts = {name: re.findall(r'"([a-z_]+)"', body)
              for name, body in re.findall(r"const ([A-Z_]+) := \[(.*?)\]", text, re.S)}
    for name in consts.get("HELD_TOOLS", []):
        note(name, "held_tool")

    # The F switch. Everything before the props catch-all is a real action; the props
    # branch returns a sentence and is explicitly NOT an implementation of anything.
    body = text.split("func _perform_use")[1].split("\nfunc ")[0]
    for arms, block in re.findall(r'\n\t\t((?:"[a-z_]+",?\s*)+):\n(.*?)(?=\n\t\t"|\Z)',
                                  body, re.S):
        names = re.findall(r'"([a-z_]+)"', arms)
        is_prop_sentence = "works where it stands" in block
        for name in names:
            note(name, "prop_sentence" if is_prop_sentence else "use_f")

    for func, mechanism in [("_apply_prop_effects", "prop_effect"),
                            ("_apply_held_effects", "held_effect")]:
        chunk = text.split("func %s" % func)[1].split("\nfunc ")[0]
        for name in re.findall(r'\n\t\t"([a-z_]+)":', chunk):
            note(name, mechanism)

    # interact()'s hand-written special cases -- the ladder's climb and the two hulls.
    interact = text.split("func interact")[1].split("\nfunc ")[0]
    for name in re.findall(r'"([a-z_]+)"', interact):
        note(name, "interact")
    for const_name in re.findall(r"utility_behavior in ([A-Z_]+)", interact):
        for name in consts.get(const_name, []):
            note(name, "interact")
    return found


def parsed_creature_drives() -> tuple[dict[str, str], set[str]]:
    """rig_type -> drive, plus every entity_id hard-coded in the dispatch."""
    text = (SCRIPTS / "playable_entity.gd").read_text()
    chunk = text.split("func _physics_process")[1].split("\nfunc ")[0]
    drives = dict(re.findall(r'rig_type == "([a-z_]+)":\n\s*state = (_drive_[a-z_]+)', chunk))
    hard = set(re.findall(r'entity_id == "([a-z_]+)"', chunk))
    return drives, hard


def climb_capable(cid: str, entity: dict, profile: dict, hard_coded: set[str],
                  utility: dict[str, set[str]]) -> bool:
    """Can this class get itself UP a wall, a ladder or the air?"""
    if entity["kind"] == "object":
        behaviour = entity.get("utility_behavior", "")
        # A prop is climbable only if interact() names it. Standing there is not climbing.
        return "interact" in utility.get(behaviour, set())
    if cid in hard_coded:
        return True                       # a bespoke controller, e.g. the spider's stance
    if profile.get("can_climb_walls", False):
        return True
    return profile.get("rig_type") == "flier"


def main(check: bool) -> int:
    entities = {e["id"]: e for e in read("entities.json")["entities"]}
    abilities = read("abilities.json")["abilities"]
    tags = read("tags.json")["tags"]
    utility = parsed_utility_behaviours()
    drives, hard_coded = parsed_creature_drives()

    profiles = {}
    for cid in entities:
        path = CONFIG / "rigs" / ("%s.json" % cid)
        profiles[cid] = json.loads(path.read_text()) if path.exists() else {}

    missing_row = sorted(set(tags) - set(TAG_NEEDS))
    if missing_row:
        raise SystemExit("  PROBLEM  no TAG_NEEDS row for %s -- add one rather than "
                         "letting it default to satisfied" % ", ".join(missing_row))

    problems: list[tuple[str, str, str]] = []

    print("=" * 78)
    print("TAG MEMBERSHIPS THAT THE WORLD CANNOT HONOUR")
    print("=" * 78)
    for tag, entry in sorted(tags.items()):
        need = TAG_NEEDS[tag]
        members = list(entry.get("classes", {}))
        if need is None or not members:
            continue
        for cid in members:
            entity, profile = entities[cid], profiles[cid]
            if need == "climb" and not climb_capable(cid, entity, profile, hard_coded, utility):
                how = ("prop with no interact() case" if entity["kind"] == "object"
                       else "rig_type %s, no wall-climb" % (profile.get("rig_type") or "?"))
                print("  UNIMPLEMENTED  %-8s %-12s %s" % (tag, cid, how))
                problems.append((tag, cid, how))
    if not problems:
        print("  (none)")

    print()
    print("=" * 78)
    print("CLASSES WHOSE OWN ABILITY HAS NO MECHANISM")
    print("=" * 78)
    inert: list[str] = []
    for cid in sorted(entities):
        entity = entities[cid]
        verb = abilities[cid]["ability"]
        if entity["kind"] == "animal":
            profile = profiles[cid]
            rig = profile.get("rig_type", "")
            drive = "bespoke" if cid in hard_coded else drives.get(rig, "_drive_grounded")
            swims = rig == "swimmer"
            flies = rig == "flier"
            wrong = ((verb == "swim" and not swims) or (verb == "fly" and not flies)
                     or (verb == "climb" and not climb_capable(cid, entity, profile,
                                                               hard_coded, utility)))
            if wrong:
                print("  MISMATCH       %-12s ability %-9s but rig_type %-8s -> %s"
                      % (cid, verb, rig or "?", drive))
                inert.append(cid)
            continue
        behaviour = entity.get("utility_behavior", "")
        if not behaviour:
            continue                       # the three primitives are pure physics
        how = utility.get(behaviour, set())
        real = how - {"prop_sentence"}
        if not real:
            print("  INERT          %-12s ability %-9s utility_behavior %-10s has no "
                  "case anywhere" % (cid, verb, behaviour))
            inert.append(cid)
    if not inert:
        print("  (none)")

    print()
    print("=" * 78)
    print("SUMMARY")
    print("=" * 78)
    print("  %d classes  %d tag memberships the world cannot honour  %d inert or mismatched"
          % (len(entities), len(problems), len(inert)))
    empty = [t for t, e in tags.items() if not e.get("classes")]
    print("  %d tags declared with no members (locked in the Ability Book): %s"
          % (len(empty), ", ".join(sorted(empty))))
    print("  entity_id hard-coded past the rig dispatch: %s"
          % (", ".join(sorted(hard_coded)) or "none"))
    if check and (problems or inert):
        return 1
    return 0


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    sys.exit(main(ap.parse_args().check))
