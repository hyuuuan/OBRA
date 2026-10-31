"""The correction experiment's methods do what its write-up says they do.

Synthetic embeddings only -- no model, no dataset -- so these check the methods, not
the results.

    python -m unittest -v tests.test_correction_experiment

Skipped where onnx or onnxruntime is not installed (the experiment imports both).
"""

import importlib.util
import sys
import unittest
from pathlib import Path

import numpy as np

REPO_ROOT = Path(__file__).resolve().parent.parent
HAVE_DEPS = all(importlib.util.find_spec(n) is not None for n in ("onnx", "onnxruntime", "PIL"))


class _Head:
    """Stands in for the frozen model: just its last layer."""

    def __init__(self, W, b):
        self.W, self.b = W, b


@unittest.skipUnless(HAVE_DEPS, "onnx and onnxruntime are needed to import the experiment")
class CorrectionMethodTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        sys.path.insert(0, str(REPO_ROOT / "model"))
        import correction_experiment  # noqa: PLC0415 -- needs the path above

        cls.x = correction_experiment

    def setUp(self):
        rng = np.random.default_rng(0)
        self.model = _Head(rng.normal(size=(6, 8)), rng.normal(size=6))
        self.emb = np.abs(rng.normal(size=(40, 8)))
        # Classes 0 and 1 are never corrected -- the FIRST columns, so a memory written into
        # the wrong columns cannot pass by luck.
        self.labels = np.repeat(np.arange(2, 6), 10)

    def test_no_blend_is_the_frozen_model(self):
        protos = self.x.prototypes(self.emb, self.labels, 6)
        blended = self.x.predict_prototype(self.model, self.emb, protos, 0.0, 0.1)
        np.testing.assert_array_equal(blended, self.x.predict_frozen(self.model, self.emb))

    def test_the_memory_only_adds_weight_to_corrected_classes(self):
        protos = self.x.prototypes(self.emb, self.labels, 6)
        self.assertTrue(np.isnan(protos[:2]).all())
        memory_only = self.x.predict_prototype(self.model, self.emb, protos, 1.0, 0.1)
        self.assertTrue(set(memory_only) <= {2, 3, 4, 5})

    def test_a_heavy_anchor_keeps_the_shipped_head(self):
        W, b = self.x.finetune_head(self.model, self.emb, self.labels, anchor=1e6, lr=1e-7)
        np.testing.assert_allclose(W, self.model.W, atol=1e-6)
        np.testing.assert_allclose(b, self.model.b, atol=1e-6)

    def test_wrong_corrections_carry_wrong_labels(self):
        rng = np.random.default_rng(1)
        pool = {c: np.flatnonzero(self.labels == c) for c in range(2, 6)}
        _, honest, _ = self.x.corrections(pool, 3, rng, self.labels, wrong=0.0)
        np.testing.assert_array_equal(honest, np.repeat(np.arange(2, 6), 3))
        _, lying, _ = self.x.corrections(pool, 3, rng, self.labels, wrong=1.0)
        self.assertTrue((lying != np.repeat(np.arange(2, 6), 3)).all())

    def test_test_and_pool_never_share_a_drawing(self):
        test, pool = self.x.split(self.labels, np.random.default_rng(2))
        pooled = np.concatenate(list(pool.values()))
        self.assertFalse(set(test) & set(pooled))
        self.assertEqual(len(test) + len(pooled), len(self.labels))


if __name__ == "__main__":
    unittest.main()
