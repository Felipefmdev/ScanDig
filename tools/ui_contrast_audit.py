#!/usr/bin/env python3
"""Contraste WCAG dos pares de cor reais da UI do ScanDig.

Lê `ui/theme/ui_palette.gd` e mede os pares usados pelo tema (texto/fundo, foco,
desativado). Não substitui a captura: mede a cor declarada, não a cor final depois de
transparência, sombra ou textura de papel.

Uso:
    python tools/ui_contrast_audit.py
    python tools/ui_contrast_audit.py --strict   # falha se algum par mínimo falhar
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DEFAULT_PALETTE = REPO / "ui/theme/ui_palette.gd"

COLOR_RE = re.compile(
    r'const\s+([A-Z_]+)\s*:\s*Color\s*=\s*Color\(\s*"#([0-9A-Fa-f]{6,8})"\s*\)'
)

# (frente, fundo, uso, mínimo). 4.5 = texto normal; 3.0 = texto grande ou não-texto.
PAIRS = (
    ("INK", "PAPER", "texto de painel", 4.5),
    ("INK", "PAPER_LIGHT", "texto de botão comum", 4.5),
    ("INK", "PAPER_DARK", "texto em aba inativa", 4.5),
    ("WOOD", "PAPER", "dica (HintLabel)", 4.5),
    ("WOOD", "PAPER_LIGHT", "placeholder de campo", 4.5),
    ("WOOD", "PAPER_DARK", "texto desativado", 3.0),
    ("RED_BURNT", "PAPER", "aviso/estado (WarningLabel)", 4.5),
    ("INK", "ORANGE", "texto do botão primário", 4.5),
    ("PAPER", "RED_BURNT", "texto do botão de perigo", 4.5),
    ("PAPER_LIGHT", "GREEN_BOTTLE", "texto do toast", 4.5),
    ("GOLD", "INK", "código da sala (CodeLabel)", 4.5),
    ("INK", "PAPER_LIGHT", "anel de foco", 3.0),
    ("INK", "ORANGE", "anel de foco no botão primário", 3.0),
    ("METAL", "PAPER_DARK", "borda desativada", 3.0),
)


def parse_palette(path: Path) -> dict[str, tuple[float, float, float]]:
    text = path.read_text(encoding="utf-8")
    colors: dict[str, tuple[float, float, float]] = {}
    for name, hex_value in COLOR_RE.findall(text):
        # Alfa (#RRGGBBAA) é ignorado: o contraste mede-se sobre a cor opaca.
        rgb = hex_value[:6]
        colors[name] = tuple(int(rgb[i : i + 2], 16) / 255.0 for i in (0, 2, 4))
    if not colors:
        raise ValueError(f"{path}: nenhuma cor encontrada")
    return colors


def _linear(channel: float) -> float:
    return channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4


def luminance(color: tuple[float, float, float]) -> float:
    r, g, b = (_linear(channel) for channel in color)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(first: tuple[float, float, float], second: tuple[float, float, float]) -> float:
    high, low = sorted((luminance(first), luminance(second)), reverse=True)
    return (high + 0.05) / (low + 0.05)


def audit(colors: dict[str, tuple[float, float, float]]) -> list[dict]:
    results = []
    for foreground, background, use, minimum in PAIRS:
        if foreground not in colors or background not in colors:
            continue
        ratio = contrast(colors[foreground], colors[background])
        results.append(
            {
                "foreground": foreground,
                "background": background,
                "use": use,
                "ratio": round(ratio, 2),
                "minimum": minimum,
                "pass": ratio >= minimum,
            }
        )
    return results


def render(results: list[dict]) -> str:
    lines = ["par (frente/fundo)              uso                          rácio  mínimo  estado"]
    for item in results:
        pair = f"{item['foreground']}/{item['background']}"
        state = "ok" if item["pass"] else "FALHA"
        lines.append(
            f"{pair:<30} {item['use']:<28} {item['ratio']:>5.2f}  {item['minimum']:>5.1f}  {state}"
        )
    failures = [item for item in results if not item["pass"]]
    lines.append("")
    lines.append(f"{len(results)} pares medidos; {len(failures)} abaixo do mínimo.")
    if failures:
        lines.append("Falhas: " + ", ".join(f"{i['foreground']}/{i['background']}" for i in failures))
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Audita contraste WCAG da paleta da UI")
    parser.add_argument("--palette", type=Path, default=DEFAULT_PALETTE)
    parser.add_argument("--strict", action="store_true", help="exit 1 se houver falha")
    args = parser.parse_args(argv)

    try:
        results = audit(parse_palette(args.palette))
    except (OSError, ValueError) as error:
        print(f"erro: {error}", file=sys.stderr)
        return 2

    print(render(results))
    if args.strict and any(not item["pass"] for item in results):
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
