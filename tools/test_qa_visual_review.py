"""Black-box CLI tests with isolated temporary screenshots, including fresh checkouts."""
import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from html.parser import HTMLParser
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parents[1]
TOOL = REPO / "tools/qa_visual_review.py"


class Images(HTMLParser):
    def __init__(self):
        super().__init__()
        self.sources = []

    def handle_starttag(self, tag, attrs):
        if tag == "img":
            self.sources.extend(value for key, value in attrs if key == "src")


class VisualReviewTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="ops176_visual_test_")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.before = self.root / "before"
        self.after = self.root / "after"
        self.output = self.root / "report"
        self.before.mkdir()
        self.after.mkdir()

    def png(self, side, name, color, size=(4, 2)):
        path = side / name
        path.parent.mkdir(parents=True, exist_ok=True)
        Image.new("RGB", size, color).save(path)
        return path

    def run_report(self, output=None, expected=0):
        self.assertTrue(TOOL.is_file(), "RED: qa_visual_review.py absent")
        process = subprocess.run(
            [sys.executable, str(TOOL), "--before", str(self.before), "--after", str(self.after),
             "--output", str(output or self.output)], capture_output=True, text=True, timeout=30)
        self.assertEqual(process.returncode, expected, process.stdout + process.stderr)
        if expected:
            return process
        for name in ["index.html", "manifest.json", "contact_sheet.png"]:
            self.assertTrue((self.output / name).is_file(), name)
        return json.loads((self.output / "manifest.json").read_text(encoding="utf-8"))

    def test_missing_images_are_explicit_in_both_directions(self):
        self.png(self.before, "before_only.png", "red")
        self.png(self.after, "after_only.png", "blue")
        data = self.run_report()
        pairs = {row["name"]: row for row in data["pairs"]}
        self.assertEqual(pairs["before_only.png"]["status"], "missing_after")
        self.assertEqual(pairs["after_only.png"]["status"], "missing_before")
        self.assertIsNone(pairs["before_only.png"]["difference"])
        self.assertIsNone(pairs["after_only.png"]["before"])

    def test_resize_is_reported_without_making_up_comparable_metrics(self):
        self.png(self.before, "view.png", "red", (4, 2))
        self.png(self.after, "view.png", "red", (8, 4))
        row = self.run_report()["pairs"][0]
        self.assertEqual(row["status"], "dimensions_differ")
        self.assertEqual(row["before"]["size"], [4, 2])
        self.assertEqual(row["after"]["size"], [8, 4])
        self.assertIsNone(row["difference"])

    def test_black_candidate_threshold_does_not_mark_regular_dark_frames(self):
        self.png(self.before, "frame.png", (8, 8, 8))
        self.png(self.after, "frame.png", (9, 9, 9))
        row = self.run_report()["pairs"][0]
        self.assertTrue(row["before"]["black_candidate"])
        self.assertFalse(row["after"]["black_candidate"])
        self.assertEqual(row["before"]["black_fraction"], 1.0)

    def test_known_difference_and_identical_images_have_hand_calculated_metrics(self):
        self.png(self.before, "same.png", "red")
        self.png(self.after, "same.png", "red")
        self.png(self.before, "half.png", "black", (2, 1))
        changed = Image.new("RGB", (2, 1), "black")
        changed.putpixel((1, 0), (255, 255, 255))
        changed.save(self.after / "half.png")
        rows = {row["name"]: row for row in self.run_report()["pairs"]}
        self.assertEqual(rows["same.png"]["difference"]["mae_rgb"], 0.0)
        diff = rows["half.png"]["difference"]
        self.assertEqual(diff["mae_rgb"], 127.5)
        self.assertAlmostEqual(diff["rmse_rgb"], 180.312229, places=5)
        self.assertEqual(diff["changed_pixel_fraction"], 0.5)
        self.assertEqual(diff["max_channel_difference"], 255)

    def test_escaped_names_self_contained_images_and_unknown_conditions(self):
        name = "nested & set/01 ' camera #.png"
        original = self.png(self.before, name, "red")
        self.png(self.after, name, "blue")
        digest = hashlib.sha256(original.read_bytes()).hexdigest()
        data = self.run_report()
        page = (self.output / "index.html").read_text(encoding="utf-8")
        self.assertIn("nested &amp; set", page)
        self.assertIn("&#x27;", page)
        parser = Images()
        parser.feed(page)
        self.assertGreaterEqual(len(parser.sources), 2)
        for source in parser.sources:
            self.assertFalse(source.startswith(("http:", "https:", "file:")))
            self.assertTrue((self.output / source).is_file(), source)
        self.assertEqual(data["conditions"]["camera"], "unknown")
        self.assertEqual(data["conditions"]["weather"], "unknown")
        self.assertTrue(data["limitations"])
        self.assertEqual(hashlib.sha256(original.read_bytes()).hexdigest(), digest)
        with Image.open(self.output / "contact_sheet.png") as sheet:
            self.assertGreater(sheet.width, 0)
            self.assertGreater(sheet.height, 0)

    def test_corrupt_png_is_diagnosed_without_hiding_other_pairs(self):
        (self.before / "bad.png").write_bytes(b"not an image")
        self.png(self.after, "bad.png", "red")
        self.png(self.before, "valid.png", "green")
        self.png(self.after, "valid.png", "green")
        rows = {row["name"]: row for row in self.run_report()["pairs"]}
        self.assertEqual(rows["bad.png"]["status"], "unreadable")
        self.assertTrue(rows["bad.png"]["before"]["error"])
        self.assertIsNone(rows["bad.png"]["difference"])
        self.assertEqual(rows["valid.png"]["difference"]["mae_rgb"], 0)

    def test_nonexistent_input_rejected_with_nonzero_exit(self):
        self.before = self.root / "absent"
        process = self.run_report(expected=2)
        self.assertTrue(process.stderr.strip())
        self.assertFalse(self.output.exists())

    def test_output_inside_input_rejected_before_writing_sources(self):
        path = self.png(self.before, "keep.png", "red")
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        self.run_report(output=self.before / "report", expected=2)
        self.assertFalse((self.before / "report").exists())
        self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), digest)

    def test_empty_sets_are_reported_without_claiming_visual_acceptance(self):
        data = self.run_report()
        self.assertEqual(data["pairs"], [])
        self.assertEqual(data["summary"]["pairs"], 0)
        self.assertTrue(data["limitations"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
