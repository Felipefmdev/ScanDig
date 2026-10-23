#!/usr/bin/env python3
"""Gera o plugin local do Figma (code.js) a partir dos tokens e dos frames SVG.

O plugin cria, numa página nova, os estilos de cor e de texto e os frames do kit.
Não altera páginas existentes e não precisa de rede nem de MCP.

Uso:
    python tools/make_figma_plugin.py
    python tools/make_figma_plugin.py --check
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
TOKENS = REPO / "docs/ui/tokens.json"
KIT = REPO / "docs/ui/kit"
OUT = REPO / "tools/figma_plugin"

TEMPLATE = r"""// Gerado por tools/make_figma_plugin.py. Não editar à mão.
const TOKENS = __TOKENS__;
const FRAMES = __FRAMES__;

function rgb(hex) {
  const clean = hex.replace("#", "");
  const value = (start) => parseInt(clean.slice(start, start + 2), 16) / 255;
  return {
    color: { r: value(0), g: value(2), b: value(4) },
    opacity: clean.length >= 8 ? value(6) : 1,
  };
}

function paintStyle(name, hex) {
  const { color, opacity } = rgb(hex);
  const style = figma.createPaintStyle();
  style.name = name;
  style.paints = [{ type: "SOLID", color, opacity }];
  return style;
}

async function textStyles(styles, warnings) {
  const made = [];
  for (const entry of styles) {
    try {
      await figma.loadFontAsync(entry.fontName);
      const style = figma.createTextStyle();
      style.name = entry.name;
      style.fontName = entry.fontName;
      style.fontSize = entry.fontSize;
      style.lineHeight = { unit: "PERCENT", value: entry.lineHeight };
      made.push(style);
    } catch (error) {
      warnings.push(entry.name + ": " + error.message);
    }
  }
  return made;
}

(async () => {
  const warnings = [];
  await figma.loadAllPagesAsync();

  for (const [name, hex] of Object.entries(TOKENS.palette)) {
    paintStyle("ScanDig/palette/" + name, hex);
  }
  for (const [name, hex] of Object.entries(TOKENS.semantic)) {
    paintStyle("ScanDig/semantic/" + name, hex);
  }
  const styles = await textStyles(TOKENS.typography, warnings);

  const existing = figma.root.children.map((page) => page.name);
  let pageName = "ScanDig Kit";
  let suffix = 2;
  while (existing.includes(pageName)) {
    pageName = "ScanDig Kit " + suffix;
    suffix += 1;
  }
  const page = figma.createPage();
  page.name = pageName;
  figma.currentPage = page;

  const positions = [
    { x: 0, y: 0 },
    { x: 1000, y: 0 },
    { x: 0, y: 820 },
    { x: 1000, y: 820 },
    { x: 2260, y: 0 },
  ];
  const created = [];
  for (let index = 0; index < FRAMES.length; index += 1) {
    const frame = figma.createNodeFromSvg(FRAMES[index].svg);
    frame.name = FRAMES[index].name;
    const spot = positions[index % positions.length];
    frame.x = spot.x;
    frame.y = spot.y;
    page.appendChild(frame);
    created.push(frame);
  }

  figma.viewport.scrollAndZoomIntoView(created.slice(0, 2));
  const message =
    "ScanDig Kit: " + created.length + " frames, " +
    Object.keys(TOKENS.palette).length + " cores, " + styles.length + " estilos de texto." +
    (warnings.length ? " Avisos: " + warnings.join(" | ") : "");
  figma.notify(message, { timeout: 8000 });
  figma.closePlugin(message);
})();
"""


def deref(value, groups: dict):
    if isinstance(value, str) and value.startswith("{") and value.endswith("}"):
        group, key = value[1:-1].split(".")
        return groups[group][key]["value"]
    return value


def build_tokens() -> dict:
    data = json.loads(TOKENS.read_text(encoding="utf-8"))
    palette = {name: item["value"] for name, item in data["color"].items()}
    semantic = {name: palette[item["value"].strip("{}").split(".")[-1]]
                for name, item in data["semantic"].items()}
    groups = {
        "fontFamilies": data["fontFamilies"],
        "fontSizes": data["fontSizes"],
        "lineHeights": data["lineHeights"],
        "fontWeights": data["fontWeights"],
    }
    typography = []
    for name, item in data["typography"].items():
        value = item["value"]
        family = deref(value["fontFamily"], groups)
        size = int(deref(value["fontSize"], groups))
        line = float(deref(value["lineHeight"], groups))
        style = "Bold" if family == "Kalam" else "Regular"
        typography.append(
            {
                "name": "ScanDig/type/" + name,
                "fontName": {"family": family, "style": style},
                "fontSize": size,
                "lineHeight": round(line * 100),
            }
        )
    return {"palette": palette, "semantic": semantic, "typography": typography}


def build_frames() -> list[dict]:
    chunks = []
    for path in sorted(KIT.glob("*.svg")):
        svg = path.read_text(encoding="utf-8")
        match = re.search(r'width="(\d+)" height="(\d+)"', svg)
        if not match:
            raise ValueError(f"{path}: sem width/height")
        chunks.append(
            {
                "name": path.stem.replace("_", " "),
                "width": int(match.group(1)),
                "height": int(match.group(2)),
                "svg": svg,
            }
        )
    return chunks


def render() -> str:
    tokens = build_tokens()
    frames = build_frames()
    code = TEMPLATE.replace("__TOKENS__", json.dumps(tokens, ensure_ascii=False))
    return code.replace("__FRAMES__", json.dumps(frames, ensure_ascii=False))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Gera o plugin local do Figma")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)

    code = render()
    target = OUT / "code.js"
    if args.check:
        if not target.exists() or target.read_text(encoding="utf-8") != code:
            print("code.js desatualizado; corre sem --check", file=sys.stderr)
            return 1
        print("code.js atualizado")
        return 0

    OUT.mkdir(parents=True, exist_ok=True)
    target.write_text(code, encoding="utf-8")
    print(f"ok {target.relative_to(REPO)} ({len(code) // 1024} KB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
