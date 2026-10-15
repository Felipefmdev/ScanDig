#!/usr/bin/env bash
# Testes das salas online (#30) com o noray local. Uso: tools/test_online.sh [caminho-do-godot]
# Usa o noray que já estiver em 127.0.0.1:8890 (e não o desliga); senão sobe o de
# NORAY_DIR (padrão ../_ext/noray) com o código de 6 caracteres e desliga no fim.
# Sem noray nem como subir: "SKIP" e código 0. Saída: "ONLINE OK" (0) ou "ONLINE FALHOU: ..." (1).
set -uo pipefail
GODOT="${1:-${GODOT:-/c/Godot/Godot_v4.3-stable_win64_console.exe}}"
cd "$(dirname "$0")/.."
NORAY_DIR="${NORAY_DIR:-../_ext/noray}"
NORAY_PORT=8890
OID_CHARSET="23456789ABCDEFGHJKLMNPQRSTUVWXYZ"
SAVE="$(cygpath -u "${APPDATA:-}" 2>/dev/null)/Godot/app_userdata/ScanDig/scandig_save.json"
LOG_DIR="$(mktemp -d)"
NORAY_PID=""       # PID do bash (só se fomos nós que subimos o noray)
NORAY_WINPID=""    # PID do node.exe no Windows
HOST_PID=""
SAVE_BACKED_UP=0

port_open() { (exec 3<>"/dev/tcp/127.0.0.1/$NORAY_PORT") 2>/dev/null; }
port_listening() { netstat -ano 2>/dev/null | grep -qE "[:.]$NORAY_PORT +[^ ]+ +LISTEN"; }

cleanup() {
	local code=$?
	if [ -n "$HOST_PID" ]; then kill "$HOST_PID" 2>/dev/null; fi
	if [ -n "$NORAY_PID" ]; then
		if [ -n "$NORAY_WINPID" ]; then taskkill //PID "$NORAY_WINPID" //T //F >/dev/null 2>&1; fi
		kill "$NORAY_PID" 2>/dev/null
		local i
		for i in 1 2 3 4 5 6 7 8 9 10; do port_listening || break; sleep 0.5; done
		if port_listening; then echo "AVISO: a porta $NORAY_PORT continua escutando (PID $NORAY_WINPID)"; else echo "noray desligado"; fi
	fi
	if [ "$SAVE_BACKED_UP" = 1 ]; then
		if cmp -s "$SAVE.online.bak" "$SAVE"; then
			rm -f "$SAVE.online.bak"
		else
			# Algo gravou o save durante os testes: guarda essa versão antes de restaurar.
			[ -f "$SAVE" ] && cp "$SAVE" "$SAVE.online.replaced-$(date +%s)" && echo "AVISO: o save mudou durante os testes; versão nova guardada em $SAVE.online.replaced-*"
			mv "$SAVE.online.bak" "$SAVE"
		fi
	fi
	exit "$code"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

if port_open; then
	echo "noray já no ar em 127.0.0.1:$NORAY_PORT (não será desligado)"
else
	NODE="$(command -v node 2>/dev/null || true)"
	[ -z "$NODE" ] && [ -x "/c/Program Files/nodejs/node" ] && NODE="/c/Program Files/nodejs/node"
	if [ ! -f "$NORAY_DIR/bin/noray.mjs" ] || [ -z "$NODE" ]; then
		echo "SKIP: noray não encontrado em $NORAY_DIR"
		exit 0
	fi
	# node direto (sem npm/pino-pretty) para ter um processo só. O ambiente vence o .env.
	(cd "$NORAY_DIR" && NORAY_OID_LENGTH=6 NORAY_OID_CHARSET="$OID_CHARSET" exec "$NODE" bin/noray.mjs) > "$LOG_DIR/noray.log" 2>&1 &
	NORAY_PID=$!
	for _ in $(seq 1 30); do port_open && break; sleep 0.5; done
	NORAY_WINPID="$(cat "/proc/$NORAY_PID/winpid" 2>/dev/null || true)"
	if ! port_open; then
		echo "noray não subiu em 15 s. Fim do log:"
		tail -n 20 "$LOG_DIR/noray.log"
		exit 2
	fi
	if [ -z "$NORAY_WINPID" ]; then
		NORAY_WINPID="$(netstat -ano | grep -E "[:.]$NORAY_PORT +[^ ]+ +LISTEN" | awk '{print $NF}' | head -n 1)"
	fi
	echo "noray iniciado (PID Windows $NORAY_WINPID), log em $LOG_DIR/noray.log"
fi

if [ -f "$SAVE" ] && [ ! -f "$SAVE.online.bak" ]; then
	cp "$SAVE" "$SAVE.online.bak" && SAVE_BACKED_UP=1
elif [ -f "$SAVE.online.bak" ]; then
	echo "AVISO: $SAVE.online.bak já existe (de uma rodada interrompida?); não foi tocado"
fi

timeout 60 "$GODOT" --headless --path . --script res://core/tests/room_code_test.gd > "$LOG_DIR/room_code_test.log" 2>&1
timeout 60 "$GODOT" --headless --path . --script res://core/tests/net_room_errors_test.gd > "$LOG_DIR/net_room_errors_test.log" 2>&1
timeout 90 "$GODOT" --headless --path . --script res://core/tests/net_room_host.gd > "$LOG_DIR/net_room_host.log" 2>&1 &
HOST_PID=$!
sleep 4
timeout 90 "$GODOT" --headless --path . --script res://core/tests/net_room_client.gd > "$LOG_DIR/net_room_client.log" 2>&1
wait "$HOST_PID" 2>/dev/null
HOST_PID=""

FAILED=()
check() { # check <teste> <prefixo da linha RESULT>
	local log="$LOG_DIR/$1.log"
	echo "== $1"
	grep -E "RESULT|SKIP|SCRIPT ERROR|HOST |CLIENT " "$log" | sed 's/^/   /'
	if grep -q "SCRIPT ERROR" "$log" || grep -q "SKIP" "$log" || ! grep -qE "^$2fails=0\$" <(tr -d '\r' < "$log"); then
		FAILED+=("$1")
	fi
}
check room_code_test "RESULT "
check net_room_errors_test "RESULT "
check net_room_host "HOST RESULT "
check net_room_client "CLIENT RESULT "
echo "logs: $LOG_DIR"

if [ ${#FAILED[@]} -eq 0 ]; then
	echo "ONLINE OK"
	exit 0
fi
echo "ONLINE FALHOU: ${FAILED[*]}"
exit 1
