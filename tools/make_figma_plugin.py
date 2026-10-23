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
  await figma.setCurrentPageAsync(page);

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


BRIDGE_TEMPLATE = r"""// Gerado por tools/make_figma_plugin.py. Ponte local; não editar à mão.
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

async function makeTextStyles(warnings, tokens) {
  let made = 0;
  for (const entry of tokens.typography) {
    try {
      await figma.loadFontAsync(entry.fontName);
      const style = figma.createTextStyle();
      style.name = entry.name;
      style.fontName = entry.fontName;
      style.fontSize = entry.fontSize;
      style.lineHeight = { unit: "PERCENT", value: entry.lineHeight };
      made += 1;
    } catch (error) {
      warnings.push(entry.name + ": " + error.message);
    }
  }
  return made;
}

async function loadData() {
  try {
    const tokens = await (await fetch("http://127.0.0.1:8765/tokens")).json();
    const frames = await (await fetch("http://127.0.0.1:8765/frames")).json();
    return { tokens, frames: frames.frames };
  } catch (error) {
    return { tokens: TOKENS, frames: FRAMES };
  }
}

async function buildKit() {
  const warnings = [];
  const data = await loadData();
  const tokens = data.tokens;
  const frames = data.frames;
  await figma.loadAllPagesAsync();
  for (const [name, hex] of Object.entries(tokens.palette)) {
    paintStyle("ScanDig/palette/" + name, hex);
  }
  for (const [name, hex] of Object.entries(tokens.semantic)) {
    paintStyle("ScanDig/semantic/" + name, hex);
  }
  const styles = await makeTextStyles(warnings, tokens);

  const existing = figma.root.children.map((page) => page.name);
  let pageName = "ScanDig Kit";
  let suffix = 2;
  while (existing.includes(pageName)) {
    pageName = "ScanDig Kit " + suffix;
    suffix += 1;
  }
  const page = figma.createPage();
  page.name = pageName;
  await figma.setCurrentPageAsync(page);

  const spots = [
    { x: 0, y: 0 }, { x: 1000, y: 0 }, { x: 0, y: 820 },
    { x: 1000, y: 820 }, { x: 2260, y: 0 },
  ];
  const created = [];
  for (let index = 0; index < frames.length; index += 1) {
    const frame = figma.createNodeFromSvg(frames[index].svg);
    frame.name = frames[index].name;
    const spot = spots[index % spots.length];
    frame.x = spot.x;
    frame.y = spot.y;
    page.appendChild(frame);
    created.push(frame);
  }
  figma.viewport.scrollAndZoomIntoView(created.slice(0, 2));
  return "página " + pageName + ": " + created.length + " frames, " +
    Object.keys(tokens.palette).length + " cores, " + styles + " estilos" +
    (warnings.length ? " | avisos: " + warnings.join("; ") : "");
}

async function exportFrame(name) {
  await figma.loadAllPagesAsync();
  let node = figma.currentPage.findOne((candidate) => candidate.name === name);
  if (!node) {
    for (const page of figma.root.children) {
      if (page === figma.currentPage) continue;
      node = page.findOne((candidate) => candidate.name === name);
      if (node) break;
    }
  }
  if (!node) {
    const needle = String(name).toLowerCase();
    for (const page of [figma.currentPage, ...figma.root.children]) {
      node = page.findOne((candidate) => candidate.name.toLowerCase().includes(needle));
      if (node) break;
    }
  }
  if (!node) throw new Error("frame não encontrado: " + name);
  const bytes = await node.exportAsync({ format: "PNG", constraint: { type: "SCALE", value: 1 } });
  return { name: node.name, png: figma.base64Encode(bytes) };
}

figma.showUI(__html__, { width: 360, height: 250 });

figma.ui.onmessage = async (message) => {
  if (!message || message.type === "ui-ready") return;
  const id = message.id;
  try {
    if (message.type === "build") {
      const text = await buildKit();
      figma.ui.postMessage({ type: "result", id, ok: true, text });
    } else if (message.type === "export") {
      const data = await exportFrame(message.name);
      figma.ui.postMessage({ type: "result", id, ok: true, kind: "export", name: data.name, png: data.png });
    } else if (message.type === "ping") {
      figma.ui.postMessage({ type: "result", id, ok: true, text: "pong", page: figma.currentPage.name });
    } else {
      throw new Error("comando desconhecido: " + message.type);
    }
  } catch (error) {
    figma.ui.postMessage({ type: "result", id, ok: false, error: String((error && error.message) || error) });
  }
};
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


def render() -> dict[Path, str]:
    tokens = build_tokens()
    frames = build_frames()
    data = (json.dumps(tokens, ensure_ascii=False), json.dumps(frames, ensure_ascii=False))
    return {
        OUT / "code.js": TEMPLATE.replace("__TOKENS__", data[0]).replace("__FRAMES__", data[1]),
        OUT.parent / "figma_bridge/code.js": BRIDGE_TEMPLATE.replace("__TOKENS__", data[0]).replace(
            "__FRAMES__", data[1]
        ),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Gera o plugin local do Figma")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)

    outputs = render()
    if args.check:
        stale = [
            str(path.relative_to(REPO))
            for path, code in outputs.items()
            if not path.exists() or path.read_text(encoding="utf-8") != code
        ]
        if stale:
            print("desatualizados: " + ", ".join(stale) + "; corre sem --check", file=sys.stderr)
            return 1
        print("code.js do plugin e da ponte atualizados")
        return 0

    for path, code in outputs.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(code, encoding="utf-8", newline="\n")
        print(f"ok {path.relative_to(REPO)} ({len(code) // 1024} KB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
