"""The player simulation's pieces do what its write-up says they do.

Synthetic heads and drawings only, so these check the mechanics, not the results.

    python -m unittest -v tests.test_player_simulation

Skipped where onnx, onnxruntime or scipy is missing (the simulation imports them).
"""

import importlib.util
import sys
import unittest
from pathlib import Path

import numpy as np

REPO_ROOT = Path(__file__).resolve().parent.parent
HAVE_DEPS = all(importlib.util.find_spec(n) is not None for n in ("onnx", "onnxruntime", "scipy", "PIL"))


class _Head:
    def __init__(self, W, b):
        self.W, self.b = W, b


@unittest.skipUnless(HAVE_DEPS, "onnx, onnxruntime and scipy are needed to import the simulation")
class PlayerSimulationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        sys.path.insert(0, str(REPO_ROOT / "model"))
        import player_simulation  # noqa: PLC0415 -- needs the path above

        cls.sim = player_simulation

    def setUp(self):
        rng = np.random.default_rng(0)
        self.model = _Head(rng.normal(size=(6, 8)) * 3, np.zeros(6))
        self.emb = np.abs(rng.normal(size=8))
        # A plain bar: a vertical stroke on a 28 x 28 bitmap.
        bitmap = np.zeros((28, 28), dtype=np.uint8)
        bitmap[4:24, 13:15] = 255
        self.bitmap = bitmap.reshape(784)

    def test_an_expert_draws_the_same_thing_twice(self):
        expert = self.sim.SKILLS[0]
        style = self.sim.draw_style(expert, np.random.default_rng(1))
        a = self.sim.render(self.bitmap, style, expert, np.random.default_rng(2))
        b = self.sim.render(self.bitmap, style, expert, np.random.default_rng(3))
        self.assertEqual(a.shape, (1, 28, 28))
        np.testing.assert_array_equal(a, b)

    def test_a_beginner_does_not(self):
        beginner = self.sim.SKILLS[2]
        style = self.sim.draw_style(beginner, np.random.default_rng(1))
        a = self.sim.render(self.bitmap, style, beginner, np.random.default_rng(2))
        b = self.sim.render(self.bitmap, style, beginner, np.random.default_rng(3))
        self.assertFalse(np.array_equal(a, b))

    def test_no_memory_reads_as_the_model(self):
        p = self.sim.read(self.model, self.emb, None)
        logits = self.emb @ self.model.W.T + self.model.b
        expected = np.exp(logits - logits.max()) / np.exp(logits - logits.max()).sum()
        np.testing.assert_allclose(p, expected, rtol=1e-9)

    def test_the_plain_blend_caps_an_uncorrected_class_under_the_gate(self):
        # The memory knows only class 5; the model is sure of class 0.
        model = _Head(np.zeros((6, 8)), np.array([20.0, 0, 0, 0, 0, 0]))
        p = self.sim.read(model, self.emb, {5: self.emb.copy()})
        self.assertLess(p[0], self.sim.GATE_CONFIDENCE)

    def test_the_outlet_hands_an_unfamiliar_drawing_back_to_the_model(self):
        model = _Head(np.zeros((6, 8)), np.array([20.0, 0, 0, 0, 0, 0]))
        stranger = np.zeros(8)
        stranger[0] = 1.0
        known = np.zeros(8)
        known[7] = 1.0  # cosine 0 with the stranger
        p = self.sim.read(model, stranger, {5: known}, outlet=0.9)
        self.assertGreater(p[0], self.sim.GATE_CONFIDENCE)

    def test_a_confident_wrong_answer_is_a_wrong_accept_not_a_success(self):
        # The model is sure of class 1; the player meant class 0.
        model = _Head(np.zeros((6, 8)), np.array([0, 20.0, 0, 0, 0, 0]))
        intents = [(0, [(0, 0)])]
        result = self.sim.play(model, intents, {(0, 0): self.emb}, self.sim.SKILLS[0], False,
                               np.random.default_rng(0))
        self.assertEqual(result["success_within_3"], 0.0)
        self.assertEqual(result["wrong_accepts_per_attempt"], 1.0)

    def test_a_correction_teaches_but_never_passes(self):
        # A model that never clears the gate on its own, and ONE attempt: it is declined, the
        # right answer is in the top two, so it is corrected -- and that drawing still fails.
        # (A later attempt may pass on what the memory learned; that is the point of it.)
        model = _Head(np.zeros((6, 8)), np.array([1.0, 1.0, 0, 0, 0, 0]))
        intents = [(0, [(0, 0)])]
        result = self.sim.play(model, intents, {(0, 0): self.emb}, self.sim.SKILLS[0], True,
                               np.random.default_rng(0), outlet=None)
        self.assertEqual(result["corrections"], 1)
        self.assertEqual(result["success_within_3"], 0.0)


if __name__ == "__main__":
    unittest.main()
