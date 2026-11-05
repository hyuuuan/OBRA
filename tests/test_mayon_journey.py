"""The reused art pipeline must not reintroduce paper margins or detached picture rectangles."""
import importlib.util
import json
from pathlib import Path
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


class MayonJourneyArtTests(unittest.TestCase):
    def test_generated_cuts_are_fresh(self):
        spec = importlib.util.spec_from_file_location("mayon_journey", ROOT/"tools/build_mayon_journey.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        for name, expected in module.build().items():
            with self.subTest(name=name), Image.open(module.OUT/name) as actual:
                self.assertEqual(actual.convert("RGBA").tobytes(),expected.tobytes())

    def test_scenery_backdrops_have_no_transparent_padding(self):
        for path in (ROOT/"game/assets/Level5/journey").glob("*_sky.png"):
            with self.subTest(name=path.name), Image.open(path) as image:
                self.assertEqual(image.getchannel("A").getextrema(),(255,255))

    def test_landmark_feet_are_registered_to_their_canvas(self):
        for path in (ROOT/"game/assets/Level5/journey").glob("*_landmark.png"):
            with self.subTest(name=path.name), Image.open(path) as image:
                bounds=image.getchannel("A").getbbox()
                self.assertEqual(bounds,(0,0,image.width,image.height))

    def test_waterfall_has_a_scenery_silhouette(self):
        with Image.open(ROOT/"game/assets/Level5/journey/waterfall.png") as image:
            self.assertEqual(image.getpixel((0,0))[3],0)
            self.assertEqual(image.getpixel((image.width-1,0))[3],0)
            self.assertEqual(image.getpixel((image.width//2,image.height//2))[3],255)

    def test_itinerary_and_preservation_ids_are_stable(self):
        data=json.loads((ROOT/"game/config/level_05.json").read_text())
        scenes=data["journey"]["vignettes"]
        self.assertEqual(len(scenes),13)
        self.assertEqual(scenes[-1]["id"],"summit")
        self.assertEqual({m["id"] for m in data["memories"]},
                         {"kubo","terraces","dancers","church","bandaritas","storm",
                          "bangka","coral","bakunawa","forest","waterfall","flower"})
        for before,after in zip(scenes,scenes[1:]):
            self.assertEqual(before["start"]+before["length"],after["start"])
        for scene in scenes:
            self.assertTrue((ROOT/"game"/scene["scene"].removeprefix("res://")).is_file())
        for memory in data["memories"]:
            self.assertIn(memory["vignette"],{scene["id"] for scene in scenes})

    def test_each_memory_fits_one_screen_in_both_window_shapes(self):
        data=json.loads((ROOT/"game/config/level_05.json").read_text())
        for scene in data["journey"]["vignettes"][:-1]:
            with self.subTest(scene=scene["id"]):
                self.assertGreaterEqual(scene["length"],1200)
                # The taller window's fitted camera sees 1440 world units across.
                self.assertLessEqual(scene["length"],1440)
                self.assertEqual(scene["profile"][-1][0],scene["length"])

    def test_the_terraces_target_is_payyos_own_painting(self):
        # Kent, 2026-11-05: the first memory lane "has full of grass which looks weird". Its target
        # was rice_beds.png, three slabs of stalks drawn by code and wider than the steps under them,
        # where every other place's target is cut from delivered art. It is Payyo's terraces now.
        data=json.loads((ROOT/"game/config/level_05.json").read_text())
        terraces=next(m for m in data["memories"] if m["id"]=="terraces")
        self.assertTrue(terraces["landmark_art"].endswith("/journey/terraces_landmark.png"))
        for memory in data["memories"]:
            with self.subTest(memory=memory["id"]):
                self.assertNotIn("rice_beds", memory["landmark_art"])

    def test_grounded_preservation_landmarks_match_the_collision_surface(self):
        data=json.loads((ROOT/"game/config/level_05.json").read_text())
        scenes={s["id"]:s for s in data["journey"]["vignettes"]}
        for memory in data["memories"]:
            if memory["id"] not in {"kubo","church","dancers","bangka","coral","forest","waterfall"}:
                continue
            x,y=memory["landmark_position"]
            profile=scenes[memory["vignette"]]["profile"]
            floor=next(a[1] for a,b in zip(profile,profile[1:]) if a[0]<=x<b[0])
            with self.subTest(memory=memory["id"]):
                self.assertEqual(y,floor)


if __name__ == "__main__":
    unittest.main()
