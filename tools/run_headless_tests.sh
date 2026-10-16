#!/usr/bin/env bash
# Testes headless do Dev B (core/tests e ui/tests, que não são GUT). Uso:
#   tools/run_headless_tests.sh [caminho-do-godot]
# Roda cada *_test.gd (SceneTree que imprime "RESULT fails=N") e os pares de rede pela porta
# local (net_host + net_client etc.). Falha se algum teste não imprimir "RESULT fails=0", se
# aparecer "RESULT fails=N" com N > 0, "SCRIPT ERROR" ou "Parse Error".
# Fora daqui: ui/tests/theme_snapshots.gd (captura com janela) e o par net_room_* (precisa do
# noray: use tools/test_online.sh). Os testes gravam o save: o do jogador é copiado e restaurado.
set -uo pipefail
GODOT="${1:-${GODOT:-godot}}"
cd "$(dirname "$0")/.."
LOG_DIR="$(mktemp -d)"
FAILED=()

SAVE=""
if [ -n "${APPDATA:-}" ]; then
	SAVE="$(cygpath -u "$APPDATA" 2>/dev/null || echo "$APPDATA")/Godot/app_userdata/ScanDig/scandig_save.json"
elif [ -n "${HOME:-}" ]; then
	SAVE="$HOME/.local/share/godot/app_userdata/ScanDig/scandig_save.json"
fi
SAVE_BACKED_UP=0
if [ -n "$SAVE" ] && [ -f "$SAVE" ]; then
	cp "$SAVE" "$SAVE.headless.bak" && SAVE_BACKED_UP=1
fi
restore_save() {
	if [ "$SAVE_BACKED_UP" = 1 ]; then mv "$SAVE.headless.bak" "$SAVE"; fi
}
trap restore_save EXIT

# $1 = nome, $2 = log, $3 = padrão que precisa aparecer (vazio: nenhum)
check_log() {
	local name="$1" log="$2" need="$3"
	if grep -qE "SCRIPT ERROR|Parse Error" "$log" || grep -qE "RESULT fails=[1-9]" "$log" \
		|| { [ -n "$need" ] && ! grep -qE "$need" "$log"; }; then
		FAILED+=("$name")
		echo "FALHOU $name"
		grep -E "SCRIPT ERROR|Parse Error|^FAIL|FAIL |RESULT" "$log" | head -20 | sed 's/^/    /'
	else
		echo "ok     $name"
	fi
}

run_single() {
	local script="$1" name log
	name="$(basename "$script" .gd)"
	log="$LOG_DIR/$name.log"
	timeout 180 "$GODOT" --headless --path . --script "res://$script" > "$log" 2>&1
	check_log "$name" "$log" "RESULT fails=0"
}

# $1 = host, $2 = padrão do cliente; depois os clientes como "script[:papel]"
run_pair() {
	local host="$1" need="$2" hname hlog pid entry script role cname clog
	shift 2
	hname="$(basename "$host" .gd)"
	hlog="$LOG_DIR/$hname.log"
	timeout 120 "$GODOT" --headless --path . --script "res://$host" > "$hlog" 2>&1 &
	pid=$!
	sleep 3
	local cpids=() clogs=() cnames=()
	for entry in "$@"; do
		script="${entry%%:*}"
		role=""
		if [ "$entry" != "$script" ]; then role="${entry#*:}"; fi
		cname="$(basename "$script" .gd)${role:+_$role}"
		clog="$LOG_DIR/$cname.log"
		if [ -n "$role" ]; then
			timeout 120 "$GODOT" --headless --path . --script "res://$script" -- "$role" > "$clog" 2>&1 &
		else
			timeout 120 "$GODOT" --headless --path . --script "res://$script" > "$clog" 2>&1 &
		fi
		cpids+=($!)
		clogs+=("$clog")
		cnames+=("$cname")
		sleep 2
	done
	local i
	for i in "${!cpids[@]}"; do
		wait "${cpids[$i]}"
		check_log "${cnames[$i]}" "${clogs[$i]}" "$need"
	done
	wait "$pid"
	check_log "$hname" "$hlog" ""
}

echo "== testes avulsos"
for script in core/tests/*_test.gd ui/tests/*_test.gd; do
	run_single "$script"
done

echo "== pares de rede"
run_pair core/tests/net_host.gd "RESULT fails=0" core/tests/net_client.gd
run_pair core/tests/net_host_drop.gd "host_lost=true" core/tests/net_client_drop.gd
run_pair core/tests/net_host_multi.gd "RESULT fails=0" core/tests/net_client_multi.gd:A core/tests/net_client_multi.gd:B
run_pair core/tests/net_names_host.gd "RESULT fails=0" core/tests/net_names_client.gd:A core/tests/net_names_client.gd:B
run_pair core/tests/net_save_host.gd "RESULT fails=0" core/tests/net_save_client.gd

echo "logs em $LOG_DIR"
if [ "${#FAILED[@]}" -gt 0 ]; then
	echo "HEADLESS FALHOU: ${FAILED[*]}"
	exit 1
fi
echo "HEADLESS OK"
