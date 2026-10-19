#!/usr/bin/env bash
# Corre um roteiro do DebugBridge. Uso:
#   tools/run_bot.sh "<godot console exe>" <roteiro.json> [--headless]
# Saida em .bot_runs/<roteiro>_<timestamp>/ (ver tools/bot/README.md).
# BOT_RESOLUTION=1920x1080 muda a janela (padrao 1280x720). Roteiro com
# "scene": "res://world/title_screen.tscn" mantem a tela inicial (--bot-keep-title).
set -euo pipefail
if [ $# -lt 2 ]; then
	echo "uso: $0 \"<godot console exe>\" <roteiro.json> [--headless]" >&2
	exit 2
fi
GODOT="$1"
SCRIPT="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
cd "$(dirname "$0")/.."
# Godot no Windows prefere caminhos C:/...
if command -v cygpath >/dev/null 2>&1; then
	SCRIPT="$(cygpath -m "$SCRIPT")"
fi
SCENE="$(sed -n 's/.*"scene"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$SCRIPT" | head -n 1)"
ARGS=(--path .)
if [ "${3:-}" = "--headless" ]; then
	ARGS+=(--headless)
else
	ARGS+=(--resolution "${BOT_RESOLUTION:-1280x720}" --windowed)
fi
if [ -n "$SCENE" ]; then
	ARGS+=("$SCENE")
fi
USER_ARGS=("--bot=$SCRIPT")
if [ "$SCENE" = "res://world/title_screen.tscn" ]; then
	USER_ARGS+=(--bot-keep-title)
fi
"$GODOT" "${ARGS[@]}" -- "${USER_ARGS[@]}"
