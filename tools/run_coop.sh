#!/usr/bin/env bash
# Executa um par de roteiros de bot cooperativo (host e cliente).
# Uso: tools/run_coop.sh <mapa_id>
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/c/Users/felip/Downloads/Godot_v4.3-stable_win64.exe/Godot_v4.3-stable_win64_console.exe}"
MAP="${1:-geleira}"
HOST_SCRIPT="tools/bot/coop_${MAP}_host.json"
CLIENT_SCRIPT="tools/bot/coop_${MAP}_client.json"

mkdir -p .bot_runs
./tools/run_bot.sh "$GODOT" "$HOST_SCRIPT" > ".bot_runs/coop_${MAP}_host.log" 2>&1 &
HOST_PID=$!
sleep 0.8
./tools/run_bot.sh "$GODOT" "$CLIENT_SCRIPT" > ".bot_runs/coop_${MAP}_client.log" 2>&1 &
CLIENT_PID=$!

wait "$HOST_PID" || true
wait "$CLIENT_PID" || true
