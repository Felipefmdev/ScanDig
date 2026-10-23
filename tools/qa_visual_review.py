"""Offline paired screenshot review. Requires Python 3.11+ and Pillow; never rates visual aesthetics.

Usage: python tools/qa_visual_review.py --before DIR --after DIR --output DIR
Exit 0: reports generated, including diagnosed image issues. Exit 2: invalid input/I/O.
Pairs use exact relative filenames (recursive), not guessed camera/name similarity.
"""
from __future__ import annotations

import argparse
import hashlib
import html
import json
import math
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import quote

from PIL import Image, ImageChops, ImageDraw, ImageFont, ImageOps, ImageStat

EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tif", ".tiff"}
BLACK_CHANNEL_MAX = 8
BLACK_FRACTION_MIN = 0.995
LIMITATIONS = [
    "Technical diagnostics only: no aesthetic approval, gameplay, corridor or coop coverage is inferred.",
    "Camera, scene version, seed, FOV, renderer, time and weather are unknown; verify capture conditions manually.",
    "Exact relative filenames determine pairing. Renamed captures appear as missing, not automatically matched.",
    "Pixel differences are unregistered RGB values, not perceptual quality or evidence of a regression.",
    "EXIF orientation is applied; alpha is composited on white. ICC profiles are not color-managed.",
    "Metrics are omitted for different dimensions or unreadable/missing images; images are never resized for metrics.",
    "Black candidates use the documented threshold and may be legitimate dark scenes; inspect them manually.",
    "Contact sheet thumbnails are resized for navigation only; open the gallery images for detail.",
    "Only the first image/page is inspected for multi-page input. Symlink files are not included.",
]


def discover(directory: Path) -> dict[str, Path]:
    return {p.relative_to(directory).as_posix(): p for p in sorted(directory.rglob("*"))
            if p.is_file() and not p.is_symlink() and p.suffix.lower() in EXTENSIONS}


def max_channel(image: Image.Image) -> Image.Image:
    red, green, blue = image.split()
    return ImageChops.lighter(ImageChops.lighter(red, green), blue)


def inspect_image(path: Path, target: Path, output: Path) -> tuple[dict, Image.Image | None]:
    info = {"source": str(path), "size": None, "error": None, "asset": None,
            "black_candidate": None, "black_fraction": None}
    try:
        with path.open("rb") as stream:
            info["sha256"] = hashlib.file_digest(stream, "sha256").hexdigest()
        with Image.open(path) as source:
            info["raw_size"] = list(source.size)
            info["source_mode"] = source.mode
            info["pages"] = getattr(source, "n_frames", 1)
            oriented = ImageOps.exif_transpose(source)
            rgba = oriented.convert("RGBA")
            canvas = Image.new("RGBA", rgba.size, "white")
            canvas.alpha_composite(rgba)
            rgb = canvas.convert("RGB")
        pixels = rgb.width * rgb.height
        dark = sum(max_channel(rgb).histogram()[:BLACK_CHANNEL_MAX + 1])
        info.update(size=list(rgb.size), black_fraction=dark / pixels,
                    black_candidate=dark / pixels >= BLACK_FRACTION_MIN,
                    mean_luma=ImageStat.Stat(rgb.convert("L")).mean[0])
        rgb.save(target, format="PNG")
        info["asset"] = target.relative_to(output).as_posix()
        return info, rgb
    except (OSError, ValueError, Image.DecompressionBombError) as error:
        info["error"] = f"{type(error).__name__}: {error}"
        return info, None


def difference(before: Image.Image, after: Image.Image) -> dict:
    diff = ImageChops.difference(before, after)
    stats = ImageStat.Stat(diff)
    pixels = before.width * before.height
    mae = sum(stats.mean) / 3
    return {"mae_rgb": mae, "mae_percent": mae / 255 * 100,
            "rmse_rgb": math.sqrt(sum(value * value for value in stats.rms) / 3),
            "changed_pixel_fraction": 1 - max_channel(diff).histogram()[0] / pixels,
            "max_channel_difference": max(high for _low, high in diff.getextrema())}


def make_sheet(rows: list[dict], output: Path) -> None:
    width, row_height = 1000, 290
    sheet = Image.new("RGB", (width, 60 + row_height * max(1, len(rows))), "#20242b")
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    draw.text((14, 12), "BEFORE / AFTER - technical navigation only; no aesthetic approval", fill="white", font=font)
    if not rows:
        draw.text((14, 75), "No supported images found.", fill="white", font=font)
    for index, row in enumerate(rows):
        y = 55 + index * row_height
        # HTML/manifest retain the full Unicode name; compact sheet is only navigation.
        label = f"{index + 1}. {row['name']} | {row['status']}".encode("ascii", "replace").decode()[:140]
        draw.text((14, y), label, fill="white", font=font)
        for side, x in [("before", 14), ("after", 510)]:
            data = row[side]
            draw.text((x, y + 18), side.upper(), fill="#b8c5dd", font=font)
            if data and data.get("asset"):
                with Image.open(output / data["asset"]) as image:
                    thumb = ImageOps.contain(image, (476, 240), Image.Resampling.LANCZOS)
                    sheet.paste(thumb, (x + (476 - thumb.width) // 2, y + 36))
            else:
                draw.text((x, y + 80), "MISSING / UNREADABLE", fill="#ffbc7e", font=font)
    sheet.save(output / "contact_sheet.png")


def make_html(manifest: dict, output: Path) -> None:
    esc = html.escape
    parts = ["<!doctype html><html lang='en'><meta charset='utf-8'>",
             "<meta name='viewport' content='width=device-width,initial-scale=1'>",
             "<title>Paired screenshot review</title><style>",
             "body{background:#181c22;color:#eee;font:16px system-ui;max-width:1500px;margin:2em auto;padding:0 1em}",
             "a{color:#9dd0ff}.pair{display:grid;grid-template-columns:1fr 1fr;gap:1em}img{max-width:100%;height:auto}",
             "article{border-top:1px solid #59616e;margin-top:2em;padding-top:1em}figure{margin:0}pre{white-space:pre-wrap;overflow-wrap:anywhere}",
             "h2{overflow-wrap:anywhere}@media(max-width:650px){.pair{grid-template-columns:1fr}}</style>",
             "<h1>Paired screenshot review</h1><p>Technical diagnostics. No aesthetic acceptance.</p>",
             "<p><a href='manifest.json'>Manifest JSON</a> · <a href='contact_sheet.png'>Contact sheet</a></p>",
             f"<p>Before: {esc(manifest['before'])}<br>After: {esc(manifest['after'])}</p>",
             "<h2>Conditions and limits</h2><ul>"]
    parts.extend(f"<li>{esc(text)}</li>" for text in manifest["limitations"])
    parts.append("</ul><pre>" + esc(json.dumps(manifest["conditions"], indent=2)) + "</pre>")
    parts.append("<h2>Summary</h2><pre>" + esc(json.dumps(manifest["summary"], indent=2)) + "</pre>")
    for row in manifest["pairs"]:
        parts.append(f"<article><h2>{esc(row['name'])}</h2><p>{esc(row['status'])}</p><div class='pair'>")
        for side in ["before", "after"]:
            data = row[side]
            parts.append(f"<figure><figcaption>{side.upper()}</figcaption>")
            if data and data.get("asset"):
                url = esc(quote(data["asset"], safe="/"), quote=True)
                parts.append(f"<a href='{url}'><img loading='lazy' src='{url}' alt='{esc(side + ': ' + row['name'], quote=True)}'></a>")
                parts.append(f"<p>Size: {esc(str(data['size']))}; black candidate: {data['black_candidate']}</p>")
            else:
                parts.append("<p>" + esc(data["error"] if data else "Missing image") + "</p>")
            parts.append("</figure>")
        parts.append("</div><pre>" + esc(json.dumps(row["difference"], indent=2)) + "</pre></article>")
    if not manifest["pairs"]:
        parts.append("<p>No supported images found. No visual acceptance inferred.</p>")
    parts.append("</html>")
    (output / "index.html").write_text("\n".join(parts), encoding="utf-8", newline="\n")


def generate(before: Path, after: Path, output: Path) -> dict:
    for directory in [before, after]:
        if not directory.is_dir():
            raise ValueError(f"Input directory does not exist: {directory}")
        if output == directory or directory in output.parents or output in directory.parents:
            raise ValueError("Output must be separate from both input directory trees")
    sources = {"before": discover(before), "after": discover(after)}
    names = sorted(sources["before"].keys() | sources["after"].keys())
    output.mkdir(parents=True, exist_ok=True)
    assets = output / "assets"
    assets.mkdir(exist_ok=True)
    rows = []
    for index, name in enumerate(names):
        row = {"name": name, "before": None, "after": None, "difference": None}
        images = {}
        for side in ["before", "after"]:
            if name in sources[side]:
                target = assets / f"{index:05d}_{side}.png"
                row[side], images[side] = inspect_image(sources[side][name], target, output)
        if row["before"] is None:
            row["status"] = "missing_before"
        elif row["after"] is None:
            row["status"] = "missing_after"
        elif row["before"]["error"] or row["after"]["error"]:
            row["status"] = "unreadable"
        elif row["before"]["size"] != row["after"]["size"]:
            row["status"] = "dimensions_differ"
        else:
            row["status"] = "comparable"
            row["difference"] = difference(images["before"], images["after"])
        rows.append(row)
    manifest = {"schema_version": 1, "generated_utc": datetime.now(timezone.utc).isoformat(),
                "before": str(before), "after": str(after),
                "conditions": {name: "unknown" for name in
                               ["camera", "fov", "weather", "time_of_day", "seed", "renderer", "scene_version"]},
                "method": {"pairing": "exact relative filename", "black_channel_max": BLACK_CHANNEL_MAX,
                           "black_fraction_min": BLACK_FRACTION_MIN, "metrics_resized": False},
                "limitations": LIMITATIONS,
                "summary": {"pairs": len(rows), "statuses": dict(Counter(row["status"] for row in rows)),
                            "black_candidates": sum(bool(row[side] and row[side]["black_candidate"])
                                                    for row in rows for side in ["before", "after"])},
                "pairs": rows}
    make_sheet(rows, output)
    make_html(manifest, output)
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False),
                                         encoding="utf-8", newline="\n")
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    for name in ["before", "after", "output"]:
        parser.add_argument("--" + name, type=Path, required=True)
    args = parser.parse_args()
    try:
        manifest = generate(args.before.resolve(), args.after.resolve(), args.output.resolve())
    except (OSError, ValueError) as error:
        print(f"qa_visual_review: {error}", file=sys.stderr)
        return 2
    print(json.dumps(manifest["summary"]))
    print(f"Report: {args.output.resolve() / 'index.html'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
