#!/usr/bin/env bash
# Coop com 2 instâncias (host + convidado) a correr roteiros do DebugBridge.
# Uso: tools/bot/run_coop.sh "<godot console exe>" [host.json] [client.json] [--headless]
# Por omissão: tools/bot/coop_host.json e tools/bot/coop_client.json. Com janela, as duas
# ficam lado a lado (960x540). Cada uma escreve o seu run em .bot_runs/.
set -euo pipefail
GODOT="${1:?uso: $0 \"<godot console exe>\" [host.json] [client.json] [--headless]}"
cd "$(dirname "$0")/../.."
HOST_JSON="${2:-tools/bot/coop_host.json}"
CLIENT_JSON="${3:-tools/bot/coop_client.json}"
abs() {
	local p
	p="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
	if command -v cygpath >/dev/null 2>&1; then cygpath -m "$p"; else echo "$p"; fi
}
mkdir -p .bot_runs
COMMON=(--path .)
if [ "${4:-}" = "--headless" ]; then
	HOST_WIN=(--headless)
	CLIENT_WIN=(--headless)
else
	HOST_WIN=(--windowed --resolution 960x540 --position 0,60)
	CLIENT_WIN=(--windowed --resolution 960x540 --position 970,60)
fi
"$GODOT" "${COMMON[@]}" "${HOST_WIN[@]}" -- "--bot=$(abs "$HOST_JSON")" > .bot_runs/coop_host.log 2>&1 &
HOST_PID=$!
sleep 1
"$GODOT" "${COMMON[@]}" "${CLIENT_WIN[@]}" -- "--bot=$(abs "$CLIENT_JSON")" > .bot_runs/coop_client.log 2>&1 &
CLIENT_PID=$!
HOST_RC=0
CLIENT_RC=0
wait "$HOST_PID" || HOST_RC=$?
wait "$CLIENT_PID" || CLIENT_RC=$?
echo "host exit=$HOST_RC client exit=$CLIENT_RC (logs: .bot_runs/coop_host.log, .bot_runs/coop_client.log)"
exit $(( HOST_RC != 0 || CLIENT_RC != 0 ))
