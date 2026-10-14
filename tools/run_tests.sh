#!/usr/bin/env bash
# Corre os testes GUT em headless. Uso: tools/run_tests.sh [caminho-do-godot]
set -euo pipefail
GODOT="${1:-${GODOT:-godot}}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --editor --quit >/dev/null 2>&1 || true
"$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd
