#!/usr/bin/env bash
# Textos visíveis sem inglês (#131). Uso: tools/i18n/missing.sh "<godot>" [trecho do caminho...]
GODOT="$1"
shift
cd "$(dirname "$0")/../.."
"$GODOT" --headless --path . --script res://tools/i18n/missing_keys.gd -- "$@" 2>&1 | grep -E $'\t|^MISSING'
