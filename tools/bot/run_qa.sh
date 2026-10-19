#!/usr/bin/env bash
# Varredura de QA por bot (#126). Uso:
#   tools/bot/run_qa.sh "<godot console exe>" [roteiro ...]   (sem roteiros = todos os qa_*.json)
# Corre cada roteiro em janela 1920x1080 (BOT_RESOLUTION muda), grava o log do Godot em
# .bot_runs/qa_logs/<roteiro>.log e no fim corre tools/bot/qa_report.py.
# Guarda uma cópia do user:// antes (QA_BACKUP_DIR, padrão .bot_runs/qa_user_backup) e repõe-na
# no fim, mesmo se falhar: os roteiros gravam saves (e o do título começa com os slots vazios).
set -uo pipefail
if [ $# -lt 1 ]; then
	echo "uso: $0 \"<godot console exe>\" [roteiro ...]" >&2
	exit 2
fi
GODOT="$1"
shift
cd "$(dirname "$0")/../.."
ROOT="$(pwd)"
USER_DIR="${APPDATA:-$HOME/.local/share}/Godot/app_userdata/ScanDig"
BACKUP="${QA_BACKUP_DIR:-$ROOT/.bot_runs/qa_user_backup}"
LOGS="$ROOT/.bot_runs/qa_logs"
mkdir -p "$LOGS"
export BOT_RESOLUTION="${BOT_RESOLUTION:-1920x1080}"

SCRIPTS=("$@")
if [ ${#SCRIPTS[@]} -eq 0 ]; then
	SCRIPTS=(tools/bot/qa_*.json)
fi

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

for script in "${SCRIPTS[@]}"; do
	name="$(basename "$script" .json)"
	if [ "$name" = "qa_title_slots" ]; then
		rm -f "$USER_DIR"/scandig_save*.json
	fi
	echo "== $name"
	bash tools/run_bot.sh "$GODOT" "$script" >"$LOGS/$name.log" 2>&1
	echo "   exit $?"
done
python tools/bot/qa_report.py
