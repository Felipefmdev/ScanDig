#!/usr/bin/env python3
"""Gera frames SVG de referência para o Figma a partir de docs/ui/tokens.json.

Cada frame usa apenas cores e tamanhos dos tokens. São protótipos de layout e
hierarquia, não arte final: a textura de papel, os ícones e o toque ficam para o jogo.

Uso:
    python tools/make_ui_frames.py
    python tools/make_ui_frames.py --check   # falha se os SVG estiverem desatualizados
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from xml.sax.saxutils import escape

REPO = Path(__file__).resolve().parent.parent
TOKENS = REPO / "docs/ui/tokens.json"
OUT = REPO / "docs/ui/kit"
SIZE = (1152, 648)

FONT = "Patrick Hand, Segoe Print, Comic Sans MS, cursive"
CODE_FONT = "Kalam, Segoe Print, cursive"


def load_tokens() -> dict:
    data = json.loads(TOKENS.read_text(encoding="utf-8"))
    colors = {name: item["value"] for name, item in data["color"].items()}
    for name, item in data["semantic"].items():
        reference = item["value"].strip("{}").split(".")[-1]
        colors[name] = colors[reference]
    sizes = {name: int(item["value"]) for name, item in data["fontSizes"].items()}
    return {"colors": colors, "sizes": sizes, "spacing": data["spacing"]}


def text(x: float, y: float, value: str, size: int = 18, color: str = "text",
         anchor: str = "start", font: str = FONT, weight: str = "normal") -> str:
    return (
        f'<text x="{x}" y="{y}" font-family="{font}" font-size="{size}" '
        f'font-weight="{weight}" fill="{{{color}}}" text-anchor="{anchor}">'
        f"{escape(value)}</text>"
    )


def box(x: float, y: float, w: float, h: float, fill: str, stroke: str | None = "border",
        width: int = 2, radius: int = 3, shadow: bool = True) -> str:
    parts = []
    if shadow:
        parts.append(
            f'<rect x="{x + 3}" y="{y + 4}" width="{w}" height="{h}" rx="{radius}" fill="{{shadow}}"/>'
        )
    stroke_attr = f' stroke="{{{stroke}}}" stroke-width="{width}"' if stroke else ""
    parts.append(
        f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{radius}" '
        f'fill="{{{fill}}}"{stroke_attr}/>'
    )
    return "".join(parts)


def button(x: float, y: float, w: float, label: str, size: int = 18,
           fill: str = "surface-raised", text_color: str = "text",
           focus: bool = False, disabled: bool = False) -> str:
    parts = []
    if focus:
        parts.append(
            f'<rect x="{x - 4}" y="{y - 4}" width="{w + 8}" height="52" rx="5" '
            f'fill="none" stroke="{{text}}" stroke-width="3"/>'
        )
    parts.append(box(x, y, w, 44, "surface-sunken" if disabled else fill))
    parts.append(
        text(x + w / 2, y + 28, label, size, "text-muted" if disabled else text_color, "middle")
    )
    return "".join(parts)


def chip(x: float, y: float, label: str, value: str, w: int = 176, fill: str = "surface-raised") -> str:
    return "".join(
        [
            box(x, y, w, 44, fill, shadow=False),
            f'<rect x="{x + 6}" y="{y + 8}" width="28" height="28" rx="3" fill="{{surface-sunken}}" stroke="{{border-soft}}" stroke-width="2"/>',
            text(x + 42, y + 20, label, 15, "text-muted"),
            text(x + 42, y + 37, value, 18, "text"),
        ]
    )


def frame(body: str, width: int = SIZE[0], height: int = SIZE[1]) -> str:
    head = (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
        f'viewBox="0 0 {width} {height}">'
        f'<rect width="{width}" height="{height}" fill="{{surface}}"/>'
    )
    return head + body + "</svg>"


def resolve(svg: str, colors: dict) -> str:
    for name, value in colors.items():
        svg = svg.replace("{" + name + "}", value)
    return svg


def hud() -> str:
    parts = [chip(58, 58, "SALDO", "R$ 1.240"), chip(242, 58, "DETETOR", "Nv.3 · 13 m"),
             chip(426, 58, "MUSEU", "12/48")]
    parts.append(box(1152 - 58 - 208, 58, 208, 44, "surface-raised", shadow=False))
    parts.append(text(1152 - 58 - 194, 86, "CHUVA · 18:40", 18, "text"))
    parts.append(box(414, 116, 324, 48, "success", "border", shadow=True))
    parts.append(text(576, 147, "Relíquia: Ídolo de Jade", 18, "text-inverse", "middle"))

    parts.append(
        f'<circle cx="576" cy="324" r="3" fill="{{text}}"/>'
        f'<circle cx="576" cy="324" r="14" fill="none" stroke="{{text}}" stroke-width="1.5" opacity="0.6"/>'
    )

    parts.append(box(396, 534, 360, 56, "surface-raised"))
    parts.append(text(414, 558, "[E] Escavar", 21, "text"))
    parts.append(text(414, 579, "segure para escavação cuidadosa", 15, "text-muted"))
    parts.append(text(58, 580, "WASD mover · Shift sprint · Tab detetor", 15, "text-muted"))
    parts.append(text(58, 602, "Q soltar · F lanterna", 15, "text-muted"))
    return frame("".join(parts))


def loja() -> str:
    parts = [box(96, 56, 960, 536, "surface-raised")]
    parts.append(text(124, 108, "BANCA · PRAIA", 26, "text", font=FONT, weight="bold"))
    parts.append(text(1028, 108, "R$ 1.240", 26, "text", "end", weight="bold"))
    parts.append(chip(124, 126, "TROCA", "3 itens novos", 220))

    tabs = [("ARMAS", 124, "text"), ("ITENS", 248, "text-muted"), ("MUSEU", 372, "text-muted")]
    for label, x, color in tabs:
        parts.append(text(x, 190, label, 18, color, weight="bold" if color == "text" else "normal"))
    parts.append('<rect x="124" y="198" width="72" height="4" fill="{action}"/>')

    for index, (name, price) in enumerate((("Estilingue", "R$ 120"), ("Armadilha de Rede", "R$ 90"),
                                           ("Kit Médico", "R$ 60"))):
        y = 232 + index * 84
        parts.append(box(124, y, 392, 68, "surface" if index else "surface-raised"))
        parts.append(
            f'<rect x="140" y="{y + 12}" width="44" height="44" rx="3" fill="{{surface-sunken}}" '
            f'stroke="{{border-soft}}" stroke-width="2"/>'
        )
        parts.append(text(198, y + 32, name, 18, "text"))
        parts.append(text(198, y + 53, "arma exclusiva" if index == 0 else "consumível", 15, "text-muted"))
        parts.append(text(500, y + 42, price, 18, "text", "end"))

    parts.append(box(540, 232, 488, 268, "surface"))
    parts.append(
        f'<rect x="564" y="256" width="96" height="96" rx="3" fill="{{surface-sunken}}" '
        f'stroke="{{border-soft}}" stroke-width="2"/>'
    )
    parts.append(text(680, 286, "ESTILINGUE", 21, "text", weight="bold"))
    parts.append(text(680, 312, "Dano 20 · alcance 22 m", 15, "text-muted"))
    parts.append(text(564, 386, "Dispara pedras. Recarrega em 0,8 s.", 18, "text"))
    parts.append(text(564, 414, "Bom contra caranguejos à distância.", 18, "text"))
    parts.append(text(564, 466, "R$ 120", 26, "text", weight="bold"))
    parts.append(button(836, 440, 168, "Comprar", 18, "action", "text", focus=True))
    parts.append(text(564, 490, "Saldo depois: R$ 1.120", 15, "text-muted"))
    parts.append(button(124, 528, 150, "Voltar"))
    parts.append(text(540, 560, "Enter compra · Esc volta", 15, "text-muted"))
    return frame("".join(parts))


def pausa() -> str:
    parts = ['<rect width="1152" height="648" fill="{shadow}"/>']
    parts.append(box(366, 134, 420, 388, "surface-raised"))
    parts.append(text(576, 184, "PAUSA", 26, "text", "middle", weight="bold"))
    parts.append(button(406, 216, 340, "Retomar", 18, "action", "text", focus=True))
    parts.append(button(406, 276, 340, "Definições"))
    parts.append(button(406, 336, 340, "Sair para o título", 18, "surface-raised", "danger"))
    parts.append(text(406, 410, "ESC volta ao jogo", 15, "text-muted"))
    parts.append(text(406, 436, "Sessão 00:42:18 · Praia", 15, "text-muted"))
    parts.append(text(406, 480, "Reduzir movimento: desligado", 15, "text-muted"))
    return frame("".join(parts))


def componentes() -> str:
    width, height = 760, 700
    parts = [box(24, 24, width - 48, height - 48, "surface-raised", shadow=False)]
    parts.append(text(48, 68, "COMPONENTES", 26, "text", weight="bold"))
    parts.append(text(48, 96, "5 estados por tipo · foco 3 px · alvo 44 px", 15, "text-muted"))

    labels = ("normal", "hover", "pressed", "foco", "desativado")
    for row, (title, fill, text_color) in enumerate(
        (("PRIMARY", "action", "text"), ("SECONDARY", "surface-raised", "text"),
         ("DANGER", "danger", "text-inverse"))
    ):
        y = 128 + row * 104
        parts.append(text(48, y - 8, title, 15, "text-muted"))
        for index, label in enumerate(labels):
            x = 48 + index * 136
            focused = label == "foco"
            disabled = label == "desativado"
            parts.append(button(x, y, 120, "Comprar" if row == 0 else "Ação", 15,
                                fill, text_color, focus=focused, disabled=disabled))
            parts.append(text(x, y + 62, label, 15, "text-muted"))

    parts.append(text(48, 468, "CHIPS / TOAST / TABS", 15, "text-muted"))
    parts.append(chip(48, 480, "SALDO", "R$ 1.240", 176))
    parts.append(box(240, 480, 232, 44, "success"))
    parts.append(text(256, 508, "Relíquia encontrada", 18, "text-inverse"))
    parts.append(box(488, 480, 224, 44, "action"))
    parts.append(text(504, 508, "Aviso: tempestade", 18, "text"))

    parts.append(text(48, 564, "TABS", 15, "text-muted"))
    parts.append(text(48, 592, "ARMAS", 18, "text", weight="bold"))
    parts.append('<rect x="48" y="600" width="70" height="4" fill="{action}"/>')
    parts.append(text(160, 592, "ITENS", 18, "text-muted"))
    parts.append(text(248, 592, "MUSEU", 18, "text-muted"))

    parts.append(text(400, 564, "CAMPO", 15, "text-muted"))
    parts.append(box(400, 576, 312, 44, "surface"))
    parts.append(text(414, 604, "Nome do jogador", 18, "text-muted"))
    parts.append(text(400, 640, "foco e erro usam borda + ícone, não só cor", 15, "text-muted"))
    return frame("".join(parts), width, height)


def tabuleiro(tokens: dict) -> str:
    width, height = 900, 700
    colors = tokens["colors"]
    parts = [box(24, 24, width - 48, height - 48, "surface-raised", shadow=False)]
    parts.append(text(48, 68, "TOKENS · SCANDIG", 26, "text", weight="bold"))
    swatches = [name for name in colors if name not in {"shadow", "surface", "text", "disabled",
                                                       "border", "border-soft", "action",
                                                       "danger", "success", "accent",
                                                       "surface-raised", "surface-sunken",
                                                       "text-muted", "text-inverse"}]
    for index, name in enumerate(swatches):
        x = 48 + (index % 4) * 204
        y = 100 + (index // 4) * 96
        value = colors[name]
        parts.append(f'<rect x="{x}" y="{y}" width="56" height="56" rx="3" fill="{{{name}}}" stroke="{{border}}" stroke-width="2"/>')
        parts.append(text(x + 68, y + 24, name, 18, "text"))
        parts.append(text(x + 68, y + 44, value, 15, "text-muted"))

    parts.append(text(48, 400, "TIPOGRAFIA", 15, "text-muted"))
    samples = (("hint 15", 15), ("body 18", 18), ("subtitle 21", 21), ("title 26", 26),
               ("display 30", 30))
    y = 436
    for label, size in samples:
        parts.append(text(48, y, f"{label} — Escavar, vender, descobrir", size, "text"))
        y += size + 18

    parts.append(text(520, 400, "ESPAÇAMENTO", 15, "text-muted"))
    for index, name in enumerate(("xs", "sm", "md", "lg", "xl", "xxl")):
        value = int(tokens["spacing"][name]["value"])
        y = 436 + index * 28
        parts.append(f'<rect x="520" y="{y - 12}" width="{value * 4}" height="12" fill="{{action}}"/>')
        parts.append(text(700, y, f"{name} {value}", 15, "text-muted"))
    return frame("".join(parts), width, height)


def build() -> dict[str, str]:
    tokens = load_tokens()
    scenes = {
        "01_hud_1152x648.svg": hud(),
        "02_loja_1152x648.svg": loja(),
        "03_pausa_1152x648.svg": pausa(),
        "04_componentes.svg": componentes(),
        "00_tokens.svg": tabuleiro(tokens),
    }
    return {name: resolve(svg, tokens["colors"]) for name, svg in scenes.items()}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Gera frames SVG para o Figma")
    parser.add_argument("--check", action="store_true", help="só compara, não escreve")
    args = parser.parse_args(argv)

    frames = build()
    stale = []
    OUT.mkdir(parents=True, exist_ok=True)
    for name, content in frames.items():
        target = OUT / name
        if args.check:
            if not target.exists() or target.read_text(encoding="utf-8") != content:
                stale.append(name)
            continue
        target.write_text(content, encoding="utf-8")
        print(f"ok {name} ({len(content) // 1024} KB)")
    if args.check:
        if stale:
            print("desatualizados: " + ", ".join(stale), file=sys.stderr)
            return 1
        print(f"{len(frames)} frames atualizados")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
