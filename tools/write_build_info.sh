#!/usr/bin/env bash
# Grava res://build_info.json com o hash curto do commit (#138). Rode antes do export; o CI
# roda sozinho. O arquivo fica fora do git: sem ele, o jogo mostra "dev" no build de debug.
# Uso: tools/write_build_info.sh [hash]   (padrão: git rev-parse --short HEAD)
set -euo pipefail
cd "$(dirname "$0")/.."
COMMIT="${1:-$(git rev-parse --short=7 HEAD)}"
COMMIT="${COMMIT:0:7}"
printf '{"commit": "%s"}\n' "$COMMIT" > build_info.json
cat build_info.json
