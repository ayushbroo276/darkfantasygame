import ast
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
ZONE_SOURCE = ROOT / "src" / "dark_fantasy" / "game_zones.py"


def load_zone_configs():
    tree = ast.parse(ZONE_SOURCE.read_text(encoding="utf-8"))
    for node in tree.body:
        if isinstance(node, ast.Assign) and any(
            isinstance(target, ast.Name) and target.id == "ZONE_CONFIGS"
            for target in node.targets
        ):
            return ast.literal_eval(node.value)
    raise AssertionError("ZONE_CONFIGS was not found in game_zones.py")


class GameAssetTests(unittest.TestCase):
    def test_all_six_zones_have_their_configured_textures(self):
        zones = load_zone_configs()
        self.assertEqual(len(zones), 6)
        for zone in zones:
            with self.subTest(zone=zone["name"]):
                folder = ASSETS / zone["folder"]
                for key in ("wall", "floor", "platform", "ceiling"):
                    self.assertTrue(
                        (folder / f'{zone[key]}.png').is_file(),
                        f'Missing {key} texture for {zone["name"]}',
                    )

    def test_shared_textures_and_audio_are_in_assets(self):
        for name in (
            "sky.png",
            "wall.png",
            "floor.png",
            "menu_bg.png",
            "logo.png",
        ):
            with self.subTest(asset=name):
                self.assertTrue((ASSETS / name).is_file())

        self.assertTrue((ASSETS / "audio" / "sfx" / "game_sfx.wav").is_file())
        for zone_number in range(1, 7):
            with self.subTest(ambient=zone_number):
                self.assertTrue(
                    (
                        ASSETS
                        / "audio"
                        / "ambient"
                        / f"zone{zone_number}_ambient.wav"
                    ).is_file()
                )


if __name__ == "__main__":
    unittest.main()
