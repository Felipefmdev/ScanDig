#!/usr/bin/env bash
# Teste de resistência por bot (R5, #142). Uso:
#   tools/bot/run_soak.sh "<godot console exe>" [--headless]
# Corre tools/bot/soak_20.json (gerado por soak_gen.py) em janela 1920x1080 (BOT_RESOLUTION muda)
# ou headless, grava o log do Godot em .bot_runs/soak_logs/soak_20_<janela|headless>.log e no fim corre
# tools/bot/soak_report.py. Guarda o user:// antes e repõe-no no fim, como o run_qa.sh.
set -uo pipefail
if [ $# -lt 1 ]; then
	echo "uso: $0 \"<godot console exe>\" [--headless]" >&2
	exit 2
fi
GODOT="$1"
MODE="${2:-}"
cd "$(dirname "$0")/../.."
ROOT="$(pwd)"
USER_DIR="${APPDATA:-$HOME/.local/share}/Godot/app_userdata/ScanDig"
BACKUP="${SOAK_BACKUP_DIR:-$ROOT/.bot_runs/soak_user_backup}"
LOGS="$ROOT/.bot_runs/soak_logs"
mkdir -p "$LOGS"
export BOT_RESOLUTION="${BOT_RESOLUTION:-1920x1080}"

rm -rf "$BACKUP"
if [ -d "$USER_DIR" ]; then
	cp -a "$USER_DIR" "$BACKUP"
fi
restore() {
	if [ -d "$BACKUP" ]; then
		rm -rf "$USER_DIR"
		cp -a "$BACKUP" "$USER_DIR"
		echo "user:// reposto de $BACKUP"
	fi
}
trap restore EXIT

LABEL="janela"
if [ "$MODE" = "--headless" ]; then
	LABEL="headless"
fi
LOG="$LOGS/soak_20_$LABEL.log"
echo "== soak_20 ${MODE:-janela $BOT_RESOLUTION}"
bash tools/run_bot.sh "$GODOT" tools/bot/soak_20.json $MODE >"$LOG" 2>&1
echo "   exit $?"
RUN="$(ls -td .bot_runs/soak_20_*/ | head -n 1)"
python tools/bot/soak_report.py "$RUN" --label "$LABEL"
