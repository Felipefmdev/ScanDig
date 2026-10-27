"""Testes do auditor de layout (tools/map_layout_audit.py)."""

from __future__ import annotations

import contextlib
import io
import json
import math
from pathlib import Path
import unittest
from pathlib import Path

from tools import map_layout_audit as audit_mod

REPO = Path(__file__).resolve().parents[1]
TMP_ROOT = REPO / ".bot_runs"

FIXTURE = """[gd_scene format=3]

[node name="Root" type="Node3D"]

[node name="A" type="Node3D" parent="."]
position = Vector3(1, 0, 0)

[node name="B" type="Node3D" parent="A"]
position = Vector3(0, 2, 0)

[node name="C" type="Node3D" parent="A/B"]
position = Vector3(0, 0, 1)

[node name="Pivot" type="Node3D" parent="."]
transform = Transform3D(0, 0, -1, 0, 1, 0, 1, 0, 0, 2, 0, 0)

[node name="Tip" type="Node3D" parent="Pivot"]
position = Vector3(0, 0, 1)

[node name="Players" type="Node3D" parent="."]

[node name="PlayerSpawner" type="MultiplayerSpawner" parent="Players"]
position = Vector3(0, 0.1, 0)

[node name="BossAltar" type="Area3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -22, 0, -22)

[node name="Banca" type="Node3D" parent="."]
position = Vector3(7, 0, 0.5)

[node name="Offer1" type="Node3D" parent="Banca"]
position = Vector3(0, 0.5, 0)

[node name="PraiaSecrets" parent="." instance=ExtResource("9")]
position = Vector3(5, 0, 5)
"""


class LayoutAuditTest(unittest.TestCase):
    def setUp(self) -> None:
        self.dir = TMP_ROOT / "layout_audit_test"
        self.dir.mkdir(parents=True, exist_ok=True)
        self.scene = self.dir / "map_teste.tscn"
        self.scene.write_text(FIXTURE, encoding="utf-8")

    def tearDown(self) -> None:
        self.scene.unlink(missing_ok=True)

    def test_nested_translation_composes(self) -> None:
        nodes = audit_mod.parse_scene(self.scene)
        globals_ = audit_mod.global_transforms(nodes)
        self.assertEqual(globals_["A/B/C"].origin, (1.0, 2.0, 1.0))

    def test_rotated_parent_rotates_child_origin(self) -> None:
        nodes = audit_mod.parse_scene(self.scene)
        globals_ = audit_mod.global_transforms(nodes)
        self.assertAlmostEqual(globals_["Pivot/Tip"].origin[0], 3.0)
        self.assertAlmostEqual(globals_["Pivot/Tip"].origin[1], 0.0)
        self.assertAlmostEqual(globals_["Pivot/Tip"].origin[2], 0.0)

    def test_anchor_classification_ignores_offers_and_spawners(self) -> None:
        report = audit_mod.audit(self.scene)
        kinds = {anchor["name"]: anchor["kind"] for anchor in report["anchors"]}
        self.assertEqual(kinds["PlayerSpawner"], "spawn")
        self.assertEqual(kinds["BossAltar"], "boss")
        self.assertEqual(kinds["Banca"], "shop")
        self.assertNotIn("Offer1", kinds)
        self.assertNotIn("Players", kinds)

    def test_instanced_secret_is_not_used_for_distance(self) -> None:
        report = audit_mod.audit(self.scene)
        secret = next(a for a in report["anchors"] if a["name"] == "PraiaSecrets")
        self.assertTrue(secret["instanced"])
        names = {item["from"] for item in report["distances"]} | {
            item["to"] for item in report["distances"]
        }
        self.assertNotIn("PraiaSecrets", names)

    def test_counts_nodes_and_transforms(self) -> None:
        report = audit_mod.audit(self.scene)
        self.assertEqual(report["nodes"], 12)
        # Root e Players não têm transform explícito.
        self.assertEqual(report["nodes_with_transform"], 10)

    def test_json_cli_returns_single_report(self) -> None:
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            code = audit_mod.main([str(self.scene), "--json"])
        self.assertEqual(code, 0)
        payload = json.loads(output.getvalue())
        self.assertEqual(payload["file"].replace("\\", "/"), str(self.scene).replace("\\", "/"))
        self.assertIn("anchors", payload)

    def test_missing_file_returns_2(self) -> None:
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(audit_mod.main([str(self.scene) + ".missing"]), 2)

    def test_distance_math_uses_walk_and_sprint_speeds(self) -> None:
        report = audit_mod.audit(self.scene)
        pair = next(
            item
            for item in report["distances"]
            if {item["from"], item["to"]} == {"BossAltar", "Banca"}
        )
        expected = math.dist((-22, 0, -22), (7, 0, 0.5))
        self.assertAlmostEqual(pair["meters"], expected, places=1)
        self.assertAlmostEqual(pair["seconds_walk"], expected / 4.5, places=1)
        self.assertAlmostEqual(pair["seconds_sprint"], expected / 6.75, places=1)


if __name__ == "__main__":
    unittest.main()
