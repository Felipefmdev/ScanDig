#!/usr/bin/env bash
# Copia application/config/version do project.godot (fonte única, #138) para o
# file_version/product_version do export_presets.cfg ("0.1.0" -> "0.1.0.0").
# Uso: tools/sync_version.sh [--check]   (--check só confere e sai com 1 se divergir)
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)"
if ! [[ "$VERSION" =~ ^[0-9]+(\.[0-9]+){0,3}$ ]]; then
	echo "config/version inválida: '$VERSION' (use a.b.c)" >&2
	exit 1
fi
WIN="$VERSION"
while [ "$(tr -cd . <<<"$WIN" | wc -c)" -lt 3 ]; do WIN="$WIN.0"; done
if [ "${1:-}" = "--check" ]; then
	for key in file_version product_version; do
		got="$(sed -n "s/^application\/$key=\"\(.*\)\"/\1/p" export_presets.cfg)"
		if [ "$got" != "$WIN" ]; then
			echo "export_presets.cfg: $key=\"$got\", esperado \"$WIN\" (rode tools/sync_version.sh)" >&2
			exit 1
		fi
	done
	echo "$VERSION ($WIN) ok"
	exit 0
fi
sed -i -E "s/^(application\/(file|product)_version=)\".*\"/\1\"$WIN\"/" export_presets.cfg
grep -E '^application/(file|product)_version=' export_presets.cfg
