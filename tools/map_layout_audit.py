#!/usr/bin/env python3
"""Auditor de layout dos mapas: nós, transforms e distâncias entre âncoras.

Lê os `.tscn` em texto (sem abrir o Godot), resolve a cadeia de pais e reporta:
  * total de nós e de nós com transform (a regra da casa manda conferir antes/depois);
  * âncoras de gameplay (spawn, chefe, loja, NPC, segredo) com posição global;
  * distâncias entre âncoras em metros e tempo estimado a andar/sprint.

Limite conhecido: só vê nós declarados no `.tscn`; sub-cenas instanciadas não são
abertas. Para posições exatas de nós dentro de instâncias, confirmar no editor/MCP.

Uso:
    python tools/map_layout_audit.py world/map_praia.tscn
    python tools/map_layout_audit.py --all
    python tools/map_layout_audit.py --all --json > relatorio.json
"""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

WALK_SPEED = 4.5
SPRINT_SPEED = 6.75

NODE_RE = re.compile(r'^\[node name="([^"]+)"([^\]]*)\]', re.MULTILINE)
ATTR_RE = re.compile(r'([A-Za-z_]+)=(?:"([^"]*)"|\[([^\]]*)\])')
TRANSFORM_RE = re.compile(r"transform\s*=\s*Transform3D\(([^)]*)\)", re.DOTALL)
POSITION_RE = re.compile(r"position\s*=\s*Vector3\(([^)]*)\)", re.DOTALL)
ROTATION_RE = re.compile(r"rotation\s*=\s*Vector3\(([^)]*)\)", re.DOTALL)
SCALE_RE = re.compile(r"scale\s*=\s*Vector3\(([^)]*)\)", re.DOTALL)

ANCHOR_KINDS = (
    ("spawn", re.compile(r"(?i)^playerspawner$|^spawn(point)?$")),
    ("boss", re.compile(r"(?i)altar|^boss$")),
    ("base", re.compile(r"(?i)baseentrega")),
    ("shop", re.compile(r"(?i)banca|sellpoint|^shop$")),
    ("npc", re.compile(r"(?i)(^npc|pescador|lurdes|ines|bjorn|vega|_ze)")),
    ("secret", re.compile(r"(?i)secrets?$")),
)
# Spawners, ofertas e props de spawn não são âncoras de layout.
ANCHOR_EXCLUDE = re.compile(r"(?i)spotspawner|enemyspawner|detectorspawn|offer\d*")

IDENTITY = ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0))


@dataclass
class Transform:
    basis: tuple = IDENTITY
    origin: tuple = (0.0, 0.0, 0.0)


@dataclass
class Node:
    name: str
    type: str
    parent: str
    path: str
    local: Transform
    groups: list = field(default_factory=list)
    global_: Transform | None = None


def _floats(raw: str) -> list[float]:
    return [float(part) for part in raw.replace("\n", " ").split(",") if part.strip()]


def _matmul(a: tuple, b: tuple) -> tuple:
    return tuple(
        tuple(sum(a[row][k] * b[k][col] for k in range(3)) for col in range(3))
        for row in range(3)
    )


def _matvec(m: tuple, v: tuple) -> tuple:
    return tuple(sum(m[row][k] * v[k] for k in range(3)) for row in range(3))


def _compose(parent: Transform, child: Transform) -> Transform:
    rotated = _matvec(parent.basis, child.origin)
    origin = tuple(parent.origin[i] + rotated[i] for i in range(3))
    return Transform(_matmul(parent.basis, child.basis), origin)


def _euler_yxz(rotation: tuple) -> tuple:
    rx, ry, rz = rotation
    cx, sx = math.cos(rx), math.sin(rx)
    cy, sy = math.cos(ry), math.sin(ry)
    cz, sz = math.cos(rz), math.sin(rz)
    # Godot usa YXZ por predefinição: R = Ry * Rx * Rz.
    ry_m = ((cy, 0.0, sy), (0.0, 1.0, 0.0), (-sy, 0.0, cy))
    rx_m = ((1.0, 0.0, 0.0), (0.0, cx, -sx), (0.0, sx, cx))
    rz_m = ((cz, -sz, 0.0), (sz, cz, 0.0), (0.0, 0.0, 1.0))
    return _matmul(_matmul(ry_m, rx_m), rz_m)


def _scaled(basis: tuple, scale: tuple) -> tuple:
    return tuple(
        tuple(basis[row][col] * scale[col] for col in range(3)) for row in range(3)
    )


def _parse_transform(block: str) -> Transform:
    match = TRANSFORM_RE.search(block)
    if match:
        values = _floats(match.group(1))
        if len(values) == 12:
            # No .tscn os 9 primeiros valores são as colunas da base (eixos x, y, z).
            xx, xy, xz, yx, yy, yz, zx, zy, zz, ox, oy, oz = values
            basis = ((xx, yx, zx), (xy, yy, zy), (xz, yz, zz))
            return Transform(basis, (ox, oy, oz))

    basis = IDENTITY
    origin = (0.0, 0.0, 0.0)
    rot = ROTATION_RE.search(block)
    if rot:
        basis = _euler_yxz(tuple(_floats(rot.group(1))[:3]))
    scale = SCALE_RE.search(block)
    if scale:
        basis = _scaled(basis, tuple(_floats(scale.group(1))[:3]))
    pos = POSITION_RE.search(block)
    if pos:
        origin = tuple(_floats(pos.group(1))[:3])
    return Transform(basis, origin)


def parse_scene(path: Path) -> list[Node]:
    text = path.read_text(encoding="utf-8")
    matches = list(NODE_RE.finditer(text))
    nodes: list[Node] = []
    paths: set[str] = set()
    for index, match in enumerate(matches):
        name = match.group(1)
        attrs = {
            key: (quoted if quoted is not None else bracket)
            for key, quoted, bracket in ATTR_RE.findall(match.group(2))
        }
        parent = attrs.get("parent", ".")
        parent_path = "" if parent == "." else parent
        node_path = f"{parent_path}/{name}" if parent_path else name
        start = match.end()
        end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        block = text[start:end]
        groups = [
            item.strip().strip('"')
            for item in attrs.get("groups", "").split(",")
            if item.strip()
        ]
        nodes.append(
            Node(
                name=name,
                type=attrs.get("type", "Instance"),
                parent=parent,
                path=node_path,
                local=_parse_transform(block),
                groups=groups,
            )
        )
        paths.add(node_path)
    if not nodes:
        raise ValueError(f"{path}: nenhum nó encontrado (ficheiro inválido?)")
    return nodes


def global_transforms(nodes: list[Node]) -> dict[str, Transform]:
    by_path = {node.path: node for node in nodes}

    def resolve(node: Node, seen: frozenset[str]) -> Transform:
        if node.global_ is not None:
            return node.global_
        if node.path in seen:
            raise ValueError(f"ciclo de pais em {node.path}")
        if node.parent == ".":
            node.global_ = node.local
            return node.global_
        parent = by_path.get(node.parent)
        if parent is None:
            node.global_ = node.local
            return node.global_
        parent_global = resolve(parent, seen | {node.path})
        node.global_ = _compose(parent_global, node.local)
        return node.global_

    return {node.path: resolve(node, frozenset()) for node in nodes}


def classify(node: Node) -> str | None:
    if ANCHOR_EXCLUDE.search(node.name):
        return None
    for kind, pattern in ANCHOR_KINDS:
        if pattern.search(node.name):
            return kind
    if "map_marker" in node.groups:
        return "marker"
    return None


def audit(path: Path) -> dict:
    nodes = parse_scene(path)
    globals_ = global_transforms(nodes)
    anchors = []
    for node in nodes:
        kind = classify(node)
        if kind is None:
            continue
        origin = globals_[node.path].origin
        anchors.append(
            {
                "kind": kind,
                "name": node.name,
                "type": node.type,
                "instanced": node.type == "Instance",
                "path": node.path,
                "position": [round(value, 3) for value in origin],
            }
        )

    # Uma âncora por tipo/ponto: remove duplicados exatos de posição.
    unique: list[dict] = []
    seen = set()
    for anchor in anchors:
        key = (anchor["kind"], tuple(anchor["position"]))
        if key in seen:
            continue
        seen.add(key)
        unique.append(anchor)

    distances = []
    placed = [anchor for anchor in unique if not anchor["instanced"]]
    for i, first in enumerate(placed):
        for second in placed[i + 1 :]:
            meters = math.dist(first["position"], second["position"])
            distances.append(
                {
                    "from": first["name"],
                    "to": second["name"],
                    "meters": round(meters, 2),
                    "seconds_walk": round(meters / WALK_SPEED, 1),
                    "seconds_sprint": round(meters / SPRINT_SPEED, 1),
                }
            )
    distances.sort(key=lambda item: item["meters"])

    return {
        "file": str(path).replace("\\", "/"),
        "nodes": len(nodes),
        "nodes_with_transform": sum(
            1
            for node in nodes
            if node.local.basis != IDENTITY or node.local.origin != (0.0, 0.0, 0.0)
        ),
        "anchors": unique,
        "distances": distances,
    }


def render(report: dict) -> str:
    lines = [
        f"Mapa: {report['file']}",
        f"  nós: {report['nodes']}  |  com transform: {report['nodes_with_transform']}",
    ]
    if not report["anchors"]:
        lines.append("  âncoras: nenhuma (nomes sem spawn/boss/shop/npc/secret)")
        return "\n".join(lines)
    lines.append("  âncoras:")
    for anchor in report["anchors"]:
        x, y, z = anchor["position"]
        note = "  (raiz de instância; posição interna não visível)" if anchor["instanced"] else ""
        lines.append(
            f"    {anchor['kind']:<6} {anchor['name']:<24} ({x:7.2f}, {y:6.2f}, {z:7.2f})"
            f"  [{anchor['path']}]{note}"
        )
    lines.append("  distâncias:")
    for item in report["distances"]:
        lines.append(
            f"    {item['from']} -> {item['to']}: {item['meters']:.1f} m"
            f"  ({item['seconds_walk']:.1f}s a andar, {item['seconds_sprint']:.1f}s a sprint)"
        )
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Audita nós, transforms e âncoras de mapas .tscn")
    parser.add_argument("scenes", nargs="*", type=Path)
    parser.add_argument("--all", action="store_true", help="todos os world/map_*.tscn")
    parser.add_argument("--json", action="store_true", help="saída JSON")
    args = parser.parse_args(argv)

    root = Path(__file__).resolve().parent.parent
    scenes = list(args.scenes)
    if args.all or not scenes:
        scenes = sorted((root / "world").glob("map_*.tscn"))
    if not scenes:
        print("nenhuma cena encontrada", file=sys.stderr)
        return 2

    reports = []
    for scene in scenes:
        try:
            reports.append(audit(scene))
        except (OSError, ValueError) as error:
            print(f"erro: {error}", file=sys.stderr)
            return 2

    if args.json:
        print(json.dumps(reports if len(reports) > 1 else reports[0], ensure_ascii=False, indent=2))
    else:
        for index, report in enumerate(reports):
            if index:
                print()
            print(render(report))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
