#!/usr/bin/env bash
# Executa um ou todos os roteiros de pacing em headless com --fixed-fps 60 (15 min de jogo em ~45s reais).
# Uso:
#   tools/bot/run_pacing.sh ["<godot_console_exe>"] [praia|campo|ruinas|geleira|cratera|all]
set -euo pipefail
GODOT="${1:-C:/Users/felip/Downloads/Godot_v4.3-stable_win64.exe/Godot_v4.3-stable_win64_console.exe}"
MAP="${2:-praia}"
cd "$(dirname "$0")/../.."

run_one() {
	local m="$1"
	echo "=== Executando pacing_${m}.json ==="
	"$GODOT" --headless --fixed-fps 60 --path . -- "--bot=tools/bot/pacing_${m}.json"
}

if [ "$MAP" = "all" ]; then
	for m in praia campo ruinas geleira cratera; do
		run_one "$m"
	done
else
	run_one "$MAP"
fi
