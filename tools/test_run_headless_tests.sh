#!/usr/bin/env bash
# Regressão do runner sem Godot real, rede ou saves do jogador.
# Uso opcional para um caso: tools/test_run_headless_tests.sh script[:papel] modo success|failure
set -euo pipefail
RUNNER="$(cd "$(dirname "$0")" && pwd)/run_headless_tests.sh"
SANDBOX="$(mktemp -d)"
trap 'rm -rf -- "$SANDBOX"' EXIT
mkdir -p "$SANDBOX/project/"{tools,core/tests,ui/tests} "$SANDBOX/bin" "$SANDBOX/data" "$SANDBOX/logs"
cp "$RUNNER" "$SANDBOX/project/tools/"
touch "$SANDBOX/project/core/tests/probe_test.gd" "$SANDBOX/project/ui/tests/probe_ui_test.gd"
export APPDATA="$SANDBOX/data" HOME="$SANDBOX/data" XDG_DATA_HOME="$SANDBOX/data"
export TMPDIR="$SANDBOX/logs"
export FAKE_TARGET FAKE_MODE
REAL_TIMEOUT="$(command -v timeout)"
export REAL_TIMEOUT
cat > "$SANDBOX/bin/timeout" <<'SH'
#!/usr/bin/env bash
shift # Apenas encurta o limite; executa o timeout real e preserva seu status.
exec "$REAL_TIMEOUT" 0.3 "$@"
SH
cat > "$SANDBOX/bin/sleep" <<'SH'
#!/usr/bin/env bash
# Os processos falsos não precisam aguardar conexões.
exit 0
SH
cat > "$SANDBOX/bin/godot-fake" <<'SH'
#!/usr/bin/env bash
script="" role=""
while [ "$#" -gt 0 ]; do
 if [ "$1" = -- ]; then role="${2:-}"; break; fi
 if [ "$1" = --script ]; then script="$2"; shift; fi
 shift
done
name="${script##*/}"
targeted=false
if [ "$name" = "$FAKE_TARGET" ] || [ "$name${role:+:$role}" = "$FAKE_TARGET" ]; then targeted=true; fi
if "$targeted"; then
 case "$FAKE_MODE" in
  empty) exit 0 ;;
  incomplete) echo 'Godot Engine v4.3.stable'; exit 0 ;;
  malformed) echo 'RESULT fails=01'; exit 0 ;;
  wrong_scene) echo 'CLIENT host_lost=true scene=MapPraia in_exp=false'; exit 0 ;;
 esac
fi
case "$name" in
 net_host.gd) echo 'HOST day=2 money=500' ;;
 net_host_drop.gd) echo 'HOST players=2' ;;
 net_client_drop.gd) echo 'CLIENT host_lost=true scene=LobbyBase in_exp=false' ;;
 net_*host*.gd) echo 'HOST RESULT fails=0' ;;
 *) echo 'RESULT fails=0' ;;
esac
if "$targeted"; then
 case "$FAKE_MODE" in
  exit) exit 7 ;;
  timeout) /usr/bin/sleep 2 ;;
  script) echo 'SCRIPT ERROR: fake failure' ;;
  parse) echo 'Parse Error: fake failure' ;;
  fails) echo 'RESULT fails=12' ;;
  leading_fails) echo 'RESULT fails=01' ;;
 esac
fi
SH
chmod +x "$SANDBOX/bin/"*
export PATH="$SANDBOX/bin:$PATH"
FAILURES=0
check_case() {
 local target="$1" mode="$2" expected="$3" status=0 process expected_exit=0 other_process="" role_ok=true
 FAKE_TARGET="$target" FAKE_MODE="$mode" bash "$SANDBOX/project/tools/run_headless_tests.sh" godot-fake > "$SANDBOX/last.log" 2>&1 || status=$?
 process="${target%%:*}"
 process="${process%.gd}"
 if [ "$target" != "${target%%:*}" ]; then
  case "${target#*:}" in A) other_process="${process}_B" ;; B) other_process="${process}_A" ;; esac
  process+="_${target#*:}"
 fi
 if [ -n "$other_process" ] && ! grep -q "^ok     $other_process (exit=0)$" "$SANDBOX/last.log"; then role_ok=false; fi
 case "$mode" in exit) expected_exit=7 ;; timeout) expected_exit=124 ;; esac
 if { [ "$expected" = success ] && [ "$status" -eq 0 ] && grep -q '^HEADLESS OK$' "$SANDBOX/last.log"; } \
  || { [ "$expected" = failure ] && [ "$status" -ne 0 ] && "$role_ok" && grep -q "^FALHOU $process (exit=$expected_exit, log=" "$SANDBOX/last.log" && ! grep -q '^HEADLESS OK$' "$SANDBOX/last.log"; }; then
  echo "PASS $target $mode (runner exit=$status)"
 else
  echo "FAIL $target $mode: esperado $expected, runner exit=$status"
  cat "$SANDBOX/last.log"
  FAILURES=$((FAILURES + 1))
 fi
}
if [ "$#" -eq 3 ]; then
 check_case "$@"
else
check_case none valid success
# Cada caminho de coleta de status: avulso, host, cliente e cliente com papel A/B.
for target in probe_test.gd net_host.gd net_host_drop.gd net_host_multi.gd net_names_host.gd net_save_host.gd net_client.gd net_client_drop.gd net_client_multi.gd:A net_client_multi.gd:B; do
 for mode in empty incomplete exit timeout script parse fails leading_fails; do
  check_case "$target" "$mode" failure
 done
done
check_case probe_test.gd malformed failure
check_case net_client_drop.gd wrong_scene failure
fi

# Logs ausentes e contrato vazio: testa o mesmo verificador sem iniciar o runner.
eval "$(sed -n '/^check_log() {/,/^}/p' "$RUNNER")"
for kind in missing empty no_contract; do
 FAILED=()
 log="$SANDBOX/$kind.log"
 need='RESULT fails=0'
 case "$kind" in
  empty) : > "$log" ;;
  no_contract) echo 'RESULT fails=0' > "$log"; need='' ;;
 esac
 check_log "probe_$kind" "$log" "$need" 0 > "$SANDBOX/check.log" 2>&1 || true
 if [ "${#FAILED[@]}" -eq 1 ] && grep -q "FALHOU probe_$kind" "$SANDBOX/check.log"; then
  echo "PASS check_log $kind"
 else
  echo "FAIL check_log $kind"; cat "$SANDBOX/check.log"
  FAILURES=$((FAILURES + 1))
 fi
done
echo "REGRESSION failures=$FAILURES"
[ "$FAILURES" -eq 0 ]
