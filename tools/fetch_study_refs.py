#!/usr/bin/env python3
"""Descarrega as referências livres de docs/learning/references.json para _refs/.

Guarda cada ficheiro, calcula SHA256 e escreve `MANIFEST.local.json`. O destino é
ignorado pelo Git: são cópias de estudo, não fazem parte do build.

Uso:
    python tools/fetch_study_refs.py --list
    python tools/fetch_study_refs.py
    python tools/fetch_study_refs.py --only cyclops_level_builder --force
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sys
import urllib.error
import urllib.request
import zipfile
from datetime import datetime, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
MANIFEST = REPO / "docs/learning/references.json"
DESTINATION = REPO / "docs/learning/_refs"
USER_AGENT = "ScanDig-study/1.0 (+docs/learning)"


def load_manifest() -> dict:
    return json.loads(MANIFEST.read_text(encoding="utf-8"))


def _download(url: str, target: Path) -> tuple[int, str]:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    digest = hashlib.sha256()
    size = 0
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_suffix(target.suffix + ".part")
    with urllib.request.urlopen(request, timeout=90) as response, temporary.open("wb") as handle:
        while chunk := response.read(65536):
            handle.write(chunk)
            digest.update(chunk)
            size += len(chunk)
    temporary.replace(target)
    return size, digest.hexdigest()


def _safe_extract(archive: Path, destination: Path) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive) as bundle:
        for member in bundle.infolist():
            resolved = (destination / member.filename).resolve()
            if not str(resolved).startswith(str(destination.resolve())):
                raise ValueError(f"zip inseguro: {member.filename}")
        bundle.extractall(destination)


def fetch(item: dict, force: bool) -> dict:
    target = DESTINATION / item["file"]
    if target.exists() and not force:
        size = target.stat().st_size
        digest = hashlib.sha256(target.read_bytes()).hexdigest()
        status = "reutilizado"
    else:
        size, digest = _download(item["url"], target)
        status = "descarregado"

    record = {
        "id": item["id"],
        "title": item.get("title", item["id"]),
        "url": item["url"],
        "license": item.get("license", "desconhecida"),
        "file": str(target.relative_to(REPO)).replace("\\", "/"),
        "bytes": size,
        "sha256": digest,
        "status": status,
        "fetched_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    }

    if item.get("extract"):
        folder = DESTINATION / item["extract"]
        if force and folder.exists():
            shutil.rmtree(folder)
        if not folder.exists():
            _safe_extract(target, folder)
        record["extracted_to"] = str(folder.relative_to(REPO)).replace("\\", "/")
    return record


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Descarrega referências de estudo livres")
    parser.add_argument("--list", action="store_true", help="só listar")
    parser.add_argument("--only", action="append", default=[], help="id a descarregar")
    parser.add_argument("--force", action="store_true", help="voltar a descarregar")
    args = parser.parse_args(argv)

    manifest = load_manifest()
    items = [item for item in manifest["items"] if not args.only or item["id"] in args.only]
    if not items:
        print("nenhum item corresponde a --only", file=sys.stderr)
        return 2

    if args.list:
        for item in items:
            print(f"{item['id']:<24} {item.get('license', '?'):<28} {item['url']}")
        return 0

    DESTINATION.mkdir(parents=True, exist_ok=True)
    records = []
    failures = 0
    for item in items:
        try:
            record = fetch(item, args.force)
            records.append(record)
            print(f"ok  {item['id']:<24} {record['bytes'] / 1024:8.1f} KB  {record['status']}")
        except (urllib.error.URLError, OSError, ValueError, zipfile.BadZipFile) as error:
            failures += 1
            print(f"erro {item['id']}: {error}", file=sys.stderr)

    local_manifest = DESTINATION / "MANIFEST.local.json"
    local_manifest.write_text(
        json.dumps({"items": records}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"\n{len(records)} ficheiros em {DESTINATION.relative_to(REPO)}; manifesto em {local_manifest.name}")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
