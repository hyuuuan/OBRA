from __future__ import annotations

import json
import unittest
from pathlib import Path

from shared.entities import load_abilities, load_entities, validate_model_labels


ROOT = Path(__file__).resolve().parents[1]

# The finalized 50-class roster: 20 creatures (active_ragdoll_morph), 3 primitives
# (physics_morph), and 27 objects (utility, per the decision to expand the utility set).
EXPECTED_ROLE_COUNTS = {
    "active_ragdoll_morph": 20,
    "physics_morph": 3,
    "utility": 27,
}
EXPECTED_UTILITY_BEHAVIORS = {
    "axe", "sword", "cannon", "boomerang", "flashlight", "campfire", "cloud", "sun",
    "fan", "ladder", "stairs", "parachute", "hot_air_balloon", "bridge", "sailboat",
    "submarine", "key", "door", "rake", "scissors", "clock", "anvil", "bucket",
    "umbrella", "tree", "mushroom", "wheel",
}
CLASS_COUNT = sum(EXPECTED_ROLE_COUNTS.values())  # 50


class ManifestContractTests(unittest.TestCase):
    def setUp(self) -> None:
        self.manifest = json.loads(
            (ROOT / "game/config/entities.json").read_text()
        )
        self.entities = load_entities(validate_scene_paths=True)

    def test_version_and_runtime_roles(self) -> None:
        self.assertEqual(self.manifest["version"], 2)
        self.assertEqual(len(self.entities), CLASS_COUNT)
        counts: dict[str, int] = {}
        for entity in self.entities:
            counts[entity.runtime_role] = counts.get(entity.runtime_role, 0) + 1
        # Count by runtime_role, not kind: primitives share kind "object" with the 27
        # objects, so a by-kind split would read 20/30 rather than 20/3/27.
        self.assertEqual(counts, EXPECTED_ROLE_COUNTS)

    def test_model_label_order_matches_manifest(self) -> None:
        labels = json.loads((ROOT / "model/labels.json").read_text())
        validate_model_labels(labels, self.entities)
        metadata = json.loads((ROOT / "model/model_metadata.json").read_text())
        self.assertEqual(metadata["source_labels"], labels)
        self.assertEqual(
            metadata["entity_ids"], [entity.id for entity in self.entities]
        )

    def test_onnx_output_has_fifty_classes(self) -> None:
        import onnx

        model = onnx.load(ROOT / "model/model.onnx", load_external_data=False)
        output = model.graph.output[0].type.tensor_type.shape.dim
        self.assertEqual(output[-1].dim_value, CLASS_COUNT)

    def test_utilities_have_unique_behaviors(self) -> None:
        utilities = [
            entity for entity in self.entities if entity.runtime_role == "utility"
        ]
        self.assertEqual(
            {entity.utility_behavior for entity in utilities},
            EXPECTED_UTILITY_BEHAVIORS,
        )
        public = utilities[0].to_public_dict()
        self.assertEqual(public["runtime_role"], "utility")
        self.assertIn("utility_behavior", public)
        self.assertIn("required_medium", public)

    def test_abilities_complete_and_valid(self) -> None:
        # load_abilities validates presence, relation, weight, and primitive flagging.
        abilities = load_abilities(entities=self.entities)
        self.assertEqual(len(abilities), len(self.entities))
        for primitive in ("circle", "square", "triangle"):
            self.assertEqual(abilities[primitive].ability_relation, "hand_authored")
        creatures = [e for e in self.entities if e.runtime_role == "active_ragdoll_morph"]
        objects = [e for e in self.entities if e.runtime_role == "utility"]
        self.assertTrue(all(abilities[e.id].ability_relation == "CapableOf" for e in creatures))
        self.assertTrue(all(abilities[e.id].ability_relation == "UsedFor" for e in objects))
        for ability in abilities.values():
            self.assertTrue(ability.ability)
            self.assertTrue(ability.ability_assertion)
            if ability.ability_relation != "hand_authored":
                self.assertIsNotNone(ability.ability_weight)
                self.assertGreater(ability.ability_weight, 0.0)


if __name__ == "__main__":
    unittest.main()
