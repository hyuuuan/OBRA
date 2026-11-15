"""tools/build_music.py: the fence around rendering, and the catalogue it writes."""

from __future__ import annotations

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import build_music as bm  # noqa: E402


class SandboxTest(unittest.TestCase):
    def test_a_render_that_can_write_outside_the_fence_stops(self) -> None:
        # Inside the real sandbox this write is refused. Pointed somewhere it is allowed, the
        # self-check must notice, stop, and leave nothing behind.
        with tempfile.TemporaryDirectory() as folder:
            (Path(folder) / "tools").mkdir()
            with mock.patch.object(bm, "ROOT", Path(folder)):
                with self.assertRaisesRegex(SystemExit, "NOT in effect"):
                    bm._prove_sandboxed()
            self.assertEqual(list((Path(folder) / "tools").iterdir()), [])

    def test_no_sandbox_means_no_render(self) -> None:
        with mock.patch.dict(os.environ, {bm.SANDBOXED_ENV: ""}), \
                mock.patch.object(bm.sys, "platform", "linux"), \
                mock.patch.object(bm.os, "execve") as relaunch:
            with self.assertRaisesRegex(SystemExit, "refusing"):
                bm._enter_sandbox([])
            relaunch.assert_not_called()

    def test_on_a_mac_it_relaunches_inside_the_profile(self) -> None:
        with mock.patch.dict(os.environ, {bm.SANDBOXED_ENV: ""}), \
                mock.patch.object(bm.sys, "platform", "darwin"), \
                mock.patch.object(bm.Path, "mkdir"), \
                mock.patch.object(bm.os, "execve") as relaunch:
            bm._enter_sandbox(["menu"])
        command = relaunch.call_args.args[1]
        self.assertEqual(command[:3], [bm.SANDBOX_EXEC, "-f", str(bm.PROFILE)])
        self.assertIn(f"CATALOG={bm.CATALOG}", command)
        self.assertEqual(command[-1], "menu")
        self.assertEqual(relaunch.call_args.args[2][bm.SANDBOXED_ENV], "1")


class CatalogTest(unittest.TestCase):
    def test_a_module_for_an_id_nothing_plays_is_refused(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "music").mkdir()
            (root / "music" / "nobody.txt").write_text("")
            catalog = root / "audio.json"
            catalog.write_text(json.dumps({"music": {"menu": ""}, "sfx": {}}))
            with mock.patch.object(bm, "MODULES", root), mock.patch.object(bm, "CATALOG", catalog), \
                    mock.patch.object(bm, "_enter_sandbox"):
                with self.assertRaisesRegex(SystemExit, "music.nobody is not in audio.json"):
                    bm.main([])

    def test_the_catalogue_keeps_its_layout(self) -> None:
        # build_music rewrites audio.json with json.dumps(indent=2); the committed file must be
        # in that layout already, or every render would reformat it.
        text = bm.CATALOG.read_text()
        self.assertEqual(json.dumps(json.loads(text), indent=2, ensure_ascii=False) + "\n", text)


if __name__ == "__main__":
    unittest.main()
