"""Testes do auditor de contraste da paleta (tools/ui_contrast_audit.py)."""

from __future__ import annotations

import contextlib
import io
import unittest
from pathlib import Path

from tools import ui_contrast_audit as contrast_mod

REPO = Path(__file__).resolve().parents[1]
PALETTE = REPO / "ui/theme/ui_palette.gd"


class ContrastMathTest(unittest.TestCase):
    def test_black_on_white_is_21(self) -> None:
        black = (0.0, 0.0, 0.0)
        white = (1.0, 1.0, 1.0)
        self.assertAlmostEqual(contrast_mod.contrast(black, white), 21.0, places=2)

    def test_same_color_is_1(self) -> None:
        color = (0.5, 0.4, 0.3)
        self.assertAlmostEqual(contrast_mod.contrast(color, color), 1.0, places=2)

    def test_contrast_is_symmetric(self) -> None:
        first = (0.1, 0.2, 0.3)
        second = (0.9, 0.8, 0.7)
        self.assertEqual(contrast_mod.contrast(first, second), contrast_mod.contrast(second, first))


class PaletteTest(unittest.TestCase):
    def test_reads_project_palette(self) -> None:
        colors = contrast_mod.parse_palette(PALETTE)
        self.assertIn("INK", colors)
        self.assertIn("PAPER", colors)
        self.assertEqual(len(colors["INK"]), 3)

    def test_ink_on_paper_passes(self) -> None:
        colors = contrast_mod.parse_palette(PALETTE)
        self.assertGreaterEqual(contrast_mod.contrast(colors["INK"], colors["PAPER"]), 4.5)

    def test_every_declared_pair_is_measured(self) -> None:
        results = contrast_mod.audit(contrast_mod.parse_palette(PALETTE))
        self.assertGreaterEqual(len(results), 10)
        self.assertTrue(all("pass" in item for item in results))

    def test_strict_exit_code_reflects_failures(self) -> None:
        failing_palette = REPO / ".bot_runs" / "contrast_fail.gd"
        failing_palette.parent.mkdir(parents=True, exist_ok=True)
        failing_palette.write_text(
            'const INK: Color = Color("#777777")\n'
            'const PAPER: Color = Color("#FFFFFF")\n',
            encoding="utf-8",
        )
        with contextlib.redirect_stdout(io.StringIO()):
            code = contrast_mod.main(["--palette", str(failing_palette), "--strict"])
        failing_palette.unlink(missing_ok=True)
        self.assertEqual(code, 1)


if __name__ == "__main__":
    unittest.main()
