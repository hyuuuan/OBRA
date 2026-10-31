"""Training is seeded end to end, and the model's metadata says what produced it.

The thesis (§4.7.5) says training "uses a fixed random seed"; for a long time only the
80/10/10 split was. These check the seeding without training anything: the same seed
draws the same weights, shuffle and augmentation, a different one does not, and the
version record names every framework the manuscript's Table 10 lists.

    python -m unittest -v tests.test_train_seed

Skipped where PyTorch is not installed (the game and backend never need it).
"""

import importlib.util
import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
HAVE_TORCH = all(
    importlib.util.find_spec(name) is not None for name in ("torch", "torchvision", "sklearn")
)


@unittest.skipUnless(HAVE_TORCH, "PyTorch, torchvision and scikit-learn are training-only")
class TrainSeedTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        sys.path.insert(0, str(REPO_ROOT))
        sys.path.insert(0, str(REPO_ROOT / "model"))
        import train_quickdraw  # noqa: PLC0415 -- needs the path above

        cls.train = train_quickdraw

    def _draw(self, seed: int):
        import numpy as np
        import torch

        self.train.seed_everything(seed)
        weights = self.train.SketchCNN(50).classifier[-1].weight.detach().clone()
        images = np.random.default_rng(0).integers(0, 255, (64, 784), dtype=np.uint8)
        dataset = self.train.QuickDrawDataset(images, np.zeros(64, dtype=np.int64), augment=True)
        augmented = torch.stack([dataset[i][0] for i in range(8)])
        order = list(torch.utils.data.DataLoader(
            range(64), batch_size=64, shuffle=True,
            generator=torch.Generator().manual_seed(seed),
        ))[0]
        return weights, augmented, order

    def test_the_same_seed_draws_the_same_training(self):
        import torch

        first, second = self._draw(7), self._draw(7)
        for a, b in zip(first, second):
            self.assertTrue(torch.equal(a, b))

    def test_a_different_seed_draws_differently(self):
        import torch

        first, other = self._draw(7), self._draw(8)
        self.assertFalse(torch.equal(first[0], other[0]))
        self.assertFalse(torch.equal(first[1], other[1]))

    def test_the_versions_are_recorded(self):
        versions = self.train.framework_versions()
        for name in ("python", "torch", "torchvision", "numpy", "scikit-learn", "onnx"):
            self.assertIn(name, versions)
        self.assertTrue(versions["torch"])


if __name__ == "__main__":
    unittest.main()
