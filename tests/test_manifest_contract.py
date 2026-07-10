from __future__ import annotations

import json
import unittest
from pathlib import Path

from shared.entities import load_entities, validate_model_labels


ROOT = Path(__file__).resolve().parents[1]


class ManifestContractTests(unittest.TestCase):
    def setUp(self) -> None:
        self.manifest = json.loads(
            (ROOT / "game/config/entities.json").read_text()
        )
        self.entities = load_entities(validate_scene_paths=True)

    def test_version_and_runtime_roles(self) -> None:
        self.assertEqual(self.manifest["version"], 2)
        counts: dict[str, int] = {}
        for entity in self.entities:
            counts[entity.runtime_role] = counts.get(entity.runtime_role, 0) + 1
        self.assertEqual(
            counts,
            {
                "active_ragdoll_morph": 10,
                "physics_morph": 3,
                "utility": 6,
            },
        )

    def test_model_label_order_matches_manifest(self) -> None:
        labels = json.loads((ROOT / "model/labels.json").read_text())
        validate_model_labels(labels, self.entities)
        metadata = json.loads((ROOT / "model/model_metadata.json").read_text())
        self.assertEqual(metadata["source_labels"], labels)
        self.assertEqual(
            metadata["entity_ids"], [entity.id for entity in self.entities]
        )

    def test_onnx_output_has_nineteen_classes(self) -> None:
        import onnx

        model = onnx.load(ROOT / "model/model.onnx", load_external_data=False)
        output = model.graph.output[0].type.tensor_type.shape.dim
        self.assertEqual(output[-1].dim_value, 19)

    def test_utilities_have_unique_behaviors(self) -> None:
        utilities = [
            entity for entity in self.entities if entity.runtime_role == "utility"
        ]
        self.assertEqual(
            {entity.utility_behavior for entity in utilities},
            {"axe", "ladder", "key", "umbrella", "flashlight", "sailboat"},
        )
        public = utilities[0].to_public_dict()
        self.assertEqual(public["runtime_role"], "utility")
        self.assertIn("utility_behavior", public)
        self.assertIn("required_medium", public)


if __name__ == "__main__":
    unittest.main()
