"""Build O.B.R.A.'s ConceptNet-grounded ability table, offline and committed.

The thesis (Sections 3.2.5 / 4.2.7) attributes one commonsense ability to every class
and records its provenance so the grounding is inspectable:

  * Creatures (active_ragdoll_morph) -> highest-weight **CapableOf** assertion.
  * Objects   (utility)              -> highest-weight **UsedFor** assertion.
  * Primitives (physics_morph)       -> **hand_authored** (roll / weight / wedge), since
    no commonsense relation supplies them.

Resolution is *offline and static*: this script builds the table once and writes
game/config/abilities.json, which the game and backend read. The game never queries
ConceptNet at runtime.

It queries the ConceptNet REST API (api.conceptnet.io) when reachable and records the
live term / assertion / edge weight / assertion URI. When the API is unreachable (it is
frequently down), it falls back to a committed curated table of documented ConceptNet
assertions with approximate weights, flagging each such entry as "conceptnet_curated".
Re-running against a healthy API upgrades those entries to "conceptnet_api" provenance.

Usage:
    python3 tools/build_abilities.py            # build/refresh game/config/abilities.json
    python3 tools/build_abilities.py --offline  # skip the API, curated table only
"""

from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT))

from shared.entities import (  # noqa: E402
    DEFAULT_ABILITIES_PATH,
    PRIMITIVE_IDS,
    load_entities,
)

API_BASE = "https://api.conceptnet.io/query"
RELATION_FOR_ROLE = {
    "active_ragdoll_morph": "CapableOf",
    "utility": "UsedFor",
}

# Curated fallback: documented ConceptNet assertions chosen to match the design-doc
# In-Game Function, with approximate edge weights. (term, relation, assertion, weight).
# The three primitives are hand_authored (weight = None). Used only when the live API
# does not return an edge; each such entry is flagged provenance="conceptnet_curated".
CURATED: dict[str, tuple[str, str, str, float | None]] = {
    # Primitives -- hand authored (no commonsense relation).
    "circle": ("roll", "hand_authored",
               "Hand-authored: a circle rolls as a heavy boulder/bumper (geometric primitive; no ConceptNet relation).", None),
    "square": ("weight", "hand_authored",
               "Hand-authored: a square acts as a static weight holding pressure plates (geometric primitive; no ConceptNet relation).", None),
    "triangle": ("wedge", "hand_authored",
                 "Hand-authored: a triangle acts as a wedge/ramp to launch or jam mechanisms (geometric primitive; no ConceptNet relation).", None),
    # Creatures -- CapableOf.
    "bird": ("fly", "CapableOf", "A bird can fly.", 6.0),
    "bat": ("fly", "CapableOf", "A bat can fly.", 2.83),
    "butterfly": ("fly", "CapableOf", "A butterfly can fly.", 3.46),
    "spider": ("climb", "CapableOf", "A spider can climb walls.", 2.83),
    "monkey": ("climb", "CapableOf", "A monkey can climb trees.", 3.46),
    "frog": ("jump", "CapableOf", "A frog can jump.", 3.46),
    "fish": ("swim", "CapableOf", "A fish can swim.", 6.32),
    "shark": ("swim", "CapableOf", "A shark can swim.", 2.83),
    "octopus": ("swim", "CapableOf", "An octopus can swim.", 2.0),
    "crab": ("pinch", "CapableOf", "A crab can pinch.", 2.0),
    "horse": ("gallop", "CapableOf", "A horse can gallop.", 2.83),
    "elephant": ("stomp", "CapableOf", "An elephant can stomp.", 2.0),
    "snake": ("slither", "CapableOf", "A snake can slither.", 2.83),
    "sea_turtle": ("swim", "CapableOf", "A sea turtle can swim.", 2.83),
    "snail": ("crawl", "CapableOf", "A snail can crawl slowly.", 2.0),
    "ant": ("carry", "CapableOf", "An ant can carry objects heavier than itself.", 2.83),
    "bee": ("pollinate", "CapableOf", "A bee can pollinate flowers.", 2.0),
    "pig": ("dig", "CapableOf", "A pig can dig for food.", 2.0),
    "penguin": ("slide", "CapableOf", "A penguin can slide on ice.", 2.0),
    "scorpion": ("sting", "CapableOf", "A scorpion can sting.", 2.83),
    # Objects -- UsedFor.
    "axe": ("chop", "UsedFor", "An axe is used to chop wood.", 4.0),
    "sword": ("cut", "UsedFor", "A sword is used to cut and fight.", 2.83),
    "cannon": ("shoot", "UsedFor", "A cannon is used to shoot projectiles.", 2.0),
    "boomerang": ("throw", "UsedFor", "A boomerang is used to throw and return.", 2.83),
    "flashlight": ("light", "UsedFor", "A flashlight is used to see in the dark.", 2.83),
    "campfire": ("warm", "UsedFor", "A campfire is used for warmth.", 2.0),
    "cloud": ("rain", "UsedFor", "A cloud is used to make rain.", 1.0),
    "sun": ("heat", "UsedFor", "The sun is used to give heat and light.", 1.0),
    "fan": ("cool", "UsedFor", "A fan is used to cool by blowing air.", 3.0),
    "ladder": ("climb", "UsedFor", "A ladder is used for climbing.", 5.29),
    "stairs": ("climb", "UsedFor", "Stairs are used to climb between floors.", 3.0),
    "parachute": ("glide", "UsedFor", "A parachute is used to slow a fall.", 2.0),
    "hot_air_balloon": ("float", "UsedFor", "A hot air balloon is used to float upward.", 1.0),
    "bridge": ("cross", "UsedFor", "A bridge is used to cross a gap.", 4.0),
    "sailboat": ("sail", "UsedFor", "A sailboat is used to sail on water.", 2.0),
    "submarine": ("dive", "UsedFor", "A submarine is used to dive underwater.", 2.0),
    "key": ("unlock", "UsedFor", "A key is used to unlock a door.", 5.29),
    "door": ("enter", "UsedFor", "A door is used to enter a room.", 3.0),
    "rake": ("gather", "UsedFor", "A rake is used to gather leaves.", 3.0),
    "scissors": ("cut", "UsedFor", "Scissors are used for cutting.", 5.29),
    "clock": ("tell time", "UsedFor", "A clock is used to tell time.", 4.0),
    "anvil": ("forge", "UsedFor", "An anvil is used to forge metal.", 2.0),
    "bucket": ("carry", "UsedFor", "A bucket is used to carry water.", 3.0),
    "umbrella": ("shelter", "UsedFor", "An umbrella is used to shelter from rain.", 3.46),
    "tree": ("shade", "UsedFor", "A tree is used to provide shade.", 2.0),
    "mushroom": ("eat", "UsedFor", "A mushroom is used for eating.", 2.0),
    "wheel": ("roll", "UsedFor", "A wheel is used to roll and move vehicles.", 2.83),
}


def _term_slug(term: str) -> str:
    return term.strip().lower().replace(" ", "_")


def _assertion_uri(concept: str, relation: str, term: str) -> str:
    return f"/a/[/r/{relation}/,/c/en/{concept}/,/c/en/{_term_slug(term)}/]"


def fetch_top_edge(concept: str, relation: str, *, retries: int = 3) -> dict | None:
    """Return the highest-weight ConceptNet edge for (concept subject, relation), or None."""
    url = f"{API_BASE}?" + urllib.parse.urlencode(
        {"start": f"/c/en/{concept}", "rel": f"/r/{relation}", "limit": 50}
    )
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "OBRA-ability-builder/1.0"})
            with urllib.request.urlopen(req, timeout=25) as resp:
                data = json.load(resp)
            break
        except Exception as exc:  # noqa: BLE001 - network is best-effort
            print(f"    [api] {concept}/{relation} attempt {attempt + 1}: {type(exc).__name__} {exc}")
            time.sleep(1.5 + attempt)
    else:
        return None

    edges = [e for e in data.get("edges", []) if e.get("end", {}).get("language") == "en"]
    edges = [e for e in edges if e.get("end", {}).get("term") != f"/c/en/{concept}"]
    if not edges:
        return None
    best = max(edges, key=lambda e: e.get("weight", 0.0))
    term = best.get("end", {}).get("label", "").strip()
    if not term:
        return None
    return {
        "ability": term,
        "ability_relation": relation,
        "ability_assertion": best.get("surfaceText") or f"{concept} {relation} {term}",
        "ability_weight": round(float(best.get("weight", 0.0)), 3),
        "assertion_uri": best.get("@id", _assertion_uri(concept, relation, term)),
        "concept": f"/c/en/{concept}",
        "provenance": "conceptnet_api",
    }


def curated_entry(entity_id: str) -> dict:
    term, relation, assertion, weight = CURATED[entity_id]
    provenance = "hand_authored" if relation == "hand_authored" else "conceptnet_curated"
    return {
        "ability": term,
        "ability_relation": relation,
        "ability_assertion": assertion,
        "ability_weight": weight,
        "assertion_uri": None if relation == "hand_authored" else _assertion_uri(entity_id, relation, term),
        "concept": None if relation == "hand_authored" else f"/c/en/{entity_id}",
        "provenance": provenance,
    }


def build(offline: bool) -> dict:
    entities = load_entities()
    abilities: dict[str, dict] = {}
    api_hits = curated_hits = 0
    for entity in entities:
        if entity.id in PRIMITIVE_IDS:
            abilities[entity.id] = curated_entry(entity.id)
            curated_hits += 1
            continue
        relation = RELATION_FOR_ROLE.get(entity.runtime_role)
        edge = None
        if relation is not None and not offline:
            print(f"  [query] {entity.id} ({relation})")
            edge = fetch_top_edge(entity.id, relation)
        if edge is not None:
            abilities[entity.id] = edge
            api_hits += 1
        else:
            if entity.id not in CURATED:
                raise SystemExit(f"no curated fallback for {entity.id!r}; add one to CURATED")
            abilities[entity.id] = curated_entry(entity.id)
            curated_hits += 1
    print(f"\nResolved {len(abilities)} abilities: {api_hits} from live API, {curated_hits} curated/hand-authored.")
    return {
        "version": 1,
        "note": (
            "ConceptNet-grounded ability provenance for the 50-class roster. Resolved offline "
            "by tools/build_abilities.py and committed; the game/backend only read this table. "
            "Entries flagged provenance=conceptnet_curated use documented assertions with "
            "approximate weights because api.conceptnet.io was unreachable at build time -- "
            "re-run the builder when the API is healthy to upgrade them to conceptnet_api."
        ),
        "abilities": abilities,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--offline", action="store_true", help="skip the API; use the curated table")
    parser.add_argument("--out", type=Path, default=DEFAULT_ABILITIES_PATH)
    args = parser.parse_args()

    doc = build(args.offline)
    args.out.write_text(json.dumps(doc, indent=2) + "\n")
    print(f"Wrote {args.out}")


if __name__ == "__main__":
    main()
