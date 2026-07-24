"""Entity manifest loading and validation for O.B.R.A.

The game, backend, and model scripts all read game/config/entities.json. Keeping
the mapping here avoids the easy-to-miss bug where the trained model outputs one
order of labels while Godot expects another.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_MANIFEST_PATH = REPO_ROOT / "game" / "config" / "entities.json"
DEFAULT_ABILITIES_PATH = REPO_ROOT / "game" / "config" / "abilities.json"
ALLOWED_SPAWN_MODES = {"playable", "pickup", "obstacle", "static"}
ALLOWED_RIG_TYPES = {"walker", "biped", "flier", "swimmer", "hopper", "none"}
ALLOWED_RUNTIME_ROLES = {"active_ragdoll_morph", "physics_morph", "utility"}
ALLOWED_MEDIA = {"any", "water"}
# ConceptNet ability provenance relations. Creatures resolve from CapableOf, objects
# from UsedFor; the three geometric primitives have no commonsense relation and are
# hand-authored. Resolution is offline (tools/build_abilities.py) and committed.
ALLOWED_ABILITY_RELATIONS = {"CapableOf", "UsedFor", "hand_authored"}
# The three geometric primitives that must carry hand-authored abilities.
PRIMITIVE_IDS = {"circle", "square", "triangle"}
# All 27 roster objects are provisionally placeable utilities (per team decision to
# expand the utility set); the six-slot inventory still holds instances, not types.
ALLOWED_UTILITY_BEHAVIORS = {
    "axe",
    "sword",
    "cannon",
    "boomerang",
    "flashlight",
    "campfire",
    "cloud",
    "sun",
    "fan",
    "ladder",
    "stairs",
    "parachute",
    "hot_air_balloon",
    "bridge",
    "sailboat",
    "submarine",
    "key",
    "door",
    "rake",
    "scissors",
    "clock",
    "anvil",
    "bucket",
    "umbrella",
    "tree",
    "mushroom",
    "wheel",
}
# Older manifests used deform_strategy; map those onto the rig types.
LEGACY_STRATEGY_TO_RIG_TYPE = {
    "spline": "swimmer",
    "squash": "hopper",
    "flap": "flier",
    "limb_template": "walker",
    "none": "none",
}


@dataclass(frozen=True)
class EntityDefinition:
    id: str
    display_name: str
    kind: str
    quickdraw_label: str
    spawn_mode: str
    movement_type: str
    scene_path: str
    evaluation_labels: tuple[str, ...]
    rig_profile: str | None = None
    rig_type: str | None = None
    runtime_role: str = "active_ragdoll_morph"
    utility_behavior: str | None = None
    required_medium: str = "any"
    enabled: bool = True

    @classmethod
    def from_dict(cls, raw: dict[str, Any]) -> "EntityDefinition":
        missing = [
            key
            for key in (
                "id",
                "display_name",
                "kind",
                "quickdraw_label",
                "spawn_mode",
                "movement_type",
                "scene_path",
            )
            if key not in raw
        ]
        if missing:
            raise ValueError(f"entity entry is missing required keys: {', '.join(missing)}")

        return cls(
            id=_non_empty_string(raw, "id"),
            display_name=_non_empty_string(raw, "display_name"),
            kind=_non_empty_string(raw, "kind"),
            quickdraw_label=_non_empty_string(raw, "quickdraw_label"),
            spawn_mode=_non_empty_string(raw, "spawn_mode"),
            movement_type=_non_empty_string(raw, "movement_type"),
            scene_path=_non_empty_string(raw, "scene_path"),
            evaluation_labels=tuple(str(label) for label in raw.get("evaluation_labels", [])),
            rig_profile=_optional_non_empty_string(raw, "rig_profile"),
            rig_type=_resolve_rig_type(raw),
            runtime_role=_non_empty_string(raw, "runtime_role"),
            utility_behavior=_optional_non_empty_string(raw, "utility_behavior"),
            required_medium=str(raw.get("required_medium", "any")).strip() or "any",
            enabled=bool(raw.get("enabled", True)),
        )

    @property
    def source_label(self) -> str:
        return self.quickdraw_label

    def to_public_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "display_name": self.display_name,
            "kind": self.kind,
            "source_label": self.quickdraw_label,
            "spawn_mode": self.spawn_mode,
            "movement_type": self.movement_type,
            "scene_path": self.scene_path,
            "rig_profile": self.rig_profile,
            "rig_type": self.rig_type,
            "runtime_role": self.runtime_role,
            "utility_behavior": self.utility_behavior,
            "required_medium": self.required_medium,
            "enabled": self.enabled,
        }


def load_entities(
    manifest_path: str | Path | None = None,
    *,
    include_disabled: bool = False,
    validate_scene_paths: bool = False,
) -> list[EntityDefinition]:
    """Load entity definitions in model-output order."""
    path = Path(manifest_path) if manifest_path is not None else DEFAULT_MANIFEST_PATH
    doc = json.loads(path.read_text())
    raw_entities = doc.get("entities")
    if not isinstance(raw_entities, list):
        raise ValueError(f"{path} must contain an 'entities' list")

    entities = [EntityDefinition.from_dict(raw) for raw in raw_entities]
    _validate_entities(entities, validate_scene_paths=validate_scene_paths)
    if include_disabled:
        return entities
    return [entity for entity in entities if entity.enabled]


def source_labels(entities: list[EntityDefinition]) -> list[str]:
    return [entity.quickdraw_label for entity in entities]


def entity_ids(entities: list[EntityDefinition]) -> list[str]:
    return [entity.id for entity in entities]


def entities_by_source_label(
    entities: list[EntityDefinition],
) -> dict[str, EntityDefinition]:
    return {entity.quickdraw_label: entity for entity in entities}


def entities_by_id(entities: list[EntityDefinition]) -> dict[str, EntityDefinition]:
    return {entity.id: entity for entity in entities}


def validate_model_labels(
    labels: list[str],
    entities: list[EntityDefinition],
    *,
    source: str = "labels.json",
) -> None:
    expected = source_labels(entities)
    if labels != expected:
        raise ValueError(
            f"{source} does not match the enabled entity manifest.\n"
            f"Expected source labels in order: {expected}\n"
            f"Found: {labels}\n"
            "Retrain/export the model after editing game/config/entities.json."
        )


@dataclass(frozen=True)
class AbilityDefinition:
    entity_id: str
    ability: str
    ability_relation: str
    ability_assertion: str
    ability_weight: float | None = None

    def to_public_dict(self) -> dict[str, Any]:
        return {
            "ability": self.ability,
            "ability_relation": self.ability_relation,
            "ability_assertion": self.ability_assertion,
            "ability_weight": self.ability_weight,
        }


def load_abilities(
    abilities_path: str | Path | None = None,
    *,
    entities: list[EntityDefinition] | None = None,
) -> dict[str, AbilityDefinition]:
    """Load the committed ConceptNet ability table, keyed by entity id.

    The table is resolved offline (see tools/build_abilities.py) and committed; the
    game and backend only ever read it -- never query ConceptNet at runtime. When
    ``entities`` is provided, every enabled entity is required to carry a valid entry
    and the geometric primitives must be hand-authored.
    """
    path = Path(abilities_path) if abilities_path is not None else DEFAULT_ABILITIES_PATH
    doc = json.loads(path.read_text())
    raw = doc.get("abilities", doc) if isinstance(doc, dict) else doc
    if not isinstance(raw, dict):
        raise ValueError(f"{path} must contain an 'abilities' object keyed by entity id")

    abilities: dict[str, AbilityDefinition] = {}
    for entity_id, entry in raw.items():
        if not isinstance(entry, dict):
            raise ValueError(f"ability entry for {entity_id!r} must be an object")
        relation = _non_empty_string(entry, "ability_relation")
        if relation not in ALLOWED_ABILITY_RELATIONS:
            raise ValueError(
                f"{entity_id} has invalid ability_relation {relation!r}; "
                f"expected one of {sorted(ALLOWED_ABILITY_RELATIONS)}"
            )
        weight = entry.get("ability_weight")
        if relation == "hand_authored":
            weight_value = None if weight is None else float(weight)
        elif isinstance(weight, (int, float)) and float(weight) > 0.0:
            weight_value = float(weight)
        else:
            raise ValueError(
                f"{entity_id} ability_weight must be a positive number for a "
                f"{relation} assertion"
            )
        abilities[entity_id] = AbilityDefinition(
            entity_id=entity_id,
            ability=_non_empty_string(entry, "ability"),
            ability_relation=relation,
            ability_assertion=_non_empty_string(entry, "ability_assertion"),
            ability_weight=weight_value,
        )

    if entities is not None:
        _validate_abilities(abilities, entities, source=str(path))
    return abilities


def _validate_abilities(
    abilities: dict[str, AbilityDefinition],
    entities: list[EntityDefinition],
    *,
    source: str,
) -> None:
    for entity in entities:
        if not entity.enabled:
            continue
        ability = abilities.get(entity.id)
        if ability is None:
            raise ValueError(
                f"{source} is missing an ability for enabled entity {entity.id!r}"
            )
        if entity.id in PRIMITIVE_IDS and ability.ability_relation != "hand_authored":
            raise ValueError(
                f"{entity.id} is a geometric primitive and must use a hand_authored "
                f"ability, got {ability.ability_relation!r}"
            )


def res_path_to_filesystem(res_path: str) -> Path:
    if not res_path.startswith("res://"):
        raise ValueError(f"Godot scene path must start with res://, got {res_path!r}")
    return REPO_ROOT / "game" / res_path.removeprefix("res://")


def _validate_entities(
    entities: list[EntityDefinition],
    *,
    validate_scene_paths: bool,
) -> None:
    seen_ids: set[str] = set()
    seen_source_labels: set[str] = set()
    for entity in entities:
        if entity.id in seen_ids:
            raise ValueError(f"duplicate entity id: {entity.id}")
        seen_ids.add(entity.id)

        if entity.spawn_mode not in ALLOWED_SPAWN_MODES:
            raise ValueError(
                f"{entity.id} has invalid spawn_mode {entity.spawn_mode!r}; "
                f"expected one of {sorted(ALLOWED_SPAWN_MODES)}"
            )

        if entity.rig_type is not None and entity.rig_type not in ALLOWED_RIG_TYPES:
            raise ValueError(
                f"{entity.id} has invalid rig_type {entity.rig_type!r}; "
                f"expected one of {sorted(ALLOWED_RIG_TYPES)}"
            )

        if entity.runtime_role not in ALLOWED_RUNTIME_ROLES:
            raise ValueError(
                f"{entity.id} has invalid runtime_role {entity.runtime_role!r}; "
                f"expected one of {sorted(ALLOWED_RUNTIME_ROLES)}"
            )

        if entity.required_medium not in ALLOWED_MEDIA:
            raise ValueError(
                f"{entity.id} has invalid required_medium {entity.required_medium!r}; "
                f"expected one of {sorted(ALLOWED_MEDIA)}"
            )

        if entity.runtime_role == "utility":
            if entity.utility_behavior not in ALLOWED_UTILITY_BEHAVIORS:
                raise ValueError(
                    f"{entity.id} utility_behavior must be one of "
                    f"{sorted(ALLOWED_UTILITY_BEHAVIORS)}"
                )
        elif entity.utility_behavior is not None:
            raise ValueError(
                f"{entity.id} defines utility_behavior but is not a utility"
            )

        if entity.enabled:
            if entity.quickdraw_label in seen_source_labels:
                raise ValueError(
                    f"duplicate enabled quickdraw_label: {entity.quickdraw_label}"
                )
            seen_source_labels.add(entity.quickdraw_label)

            if validate_scene_paths:
                scene_path = res_path_to_filesystem(entity.scene_path)
                if not scene_path.exists():
                    raise ValueError(
                        f"{entity.id} points to missing scene {entity.scene_path}"
                    )
                if entity.rig_profile is not None:
                    rig_profile_path = res_path_to_filesystem(entity.rig_profile)
                    if not rig_profile_path.exists():
                        raise ValueError(
                            f"{entity.id} points to missing rig profile "
                            f"{entity.rig_profile}"
                        )


def _non_empty_string(raw: dict[str, Any], key: str) -> str:
    value = raw[key]
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{key} must be a non-empty string")
    return value.strip()


def _resolve_rig_type(raw: dict[str, Any]) -> str | None:
    rig_type = _optional_non_empty_string(raw, "rig_type")
    if rig_type is not None:
        return rig_type
    legacy = _optional_non_empty_string(raw, "deform_strategy")
    if legacy is None:
        return None
    return LEGACY_STRATEGY_TO_RIG_TYPE.get(legacy, legacy)


def _optional_non_empty_string(raw: dict[str, Any], key: str) -> str | None:
    value = raw.get(key)
    if value is None:
        return None
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{key} must be omitted or a non-empty string")
    return value.strip()
