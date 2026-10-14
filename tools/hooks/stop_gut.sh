#!/usr/bin/env bash
# Hook "Stop" do Claude Code: quando um agente acaba a vez com alterações em
# .gd/.tscn/.tres por commitar, corre os testes GUT. Se falharem, devolve
# decision=block para o agente continuar e corrigir antes de dar a tarefa por feita.
# Godot: variável GODOT ou o caminho por omissão abaixo.
set -uo pipefail

input="$(cat)"
# Evita ciclos: se já estamos a continuar por causa deste hook, não bloquear outra vez.
if printf '%s' "$input" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
	exit 0
fi

root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$root" || exit 0
[[ -f project.godot && -d addons/gut ]] || exit 0

changes="$(git status --porcelain -- '*.gd' '*.tscn' '*.tres' 2>/dev/null)"
[[ -n "$changes" ]] || exit 0

# Não repetir para o mesmo estado que já passou.
stamp_file=".godot/.stop_gut_ok"
state="$( { git diff HEAD -- '*.gd' '*.tscn' '*.tres'; printf '%s' "$changes"; } | git hash-object --stdin)"
[[ -f "$stamp_file" && "$(cat "$stamp_file")" == "$state" ]] && exit 0

GODOT="${GODOT:-/c/Users/felip/Downloads/Godot_v4.3-stable_win64.exe/Godot_v4.3-stable_win64_console.exe}"
[[ -x "$GODOT" ]] || exit 0

out="$(timeout 180 "$GODOT" --headless --path . -s addons/gut/gut_cmdln.gd 2>&1)"
code=$?
if [[ $code -eq 0 ]] && grep -q "All tests passed" <<<"$out"; then
	mkdir -p .godot && printf '%s' "$state" >"$stamp_file"
	exit 0
fi

summary="$(sed 's/\x1b\[[0-9;]*m//g' <<<"$out" | grep -E '\[Failed\]|FAILED|SCRIPT ERROR|Parse Error|ERROR: .*\.gd|Passing|Failing|Tests ' | head -40)"
python -c 'import json,sys; print(json.dumps({"decision":"block","reason":"Testes GUT falharam (tools/hooks/stop_gut.sh, exit "+sys.argv[1]+"). Corrige antes de dar a tarefa por concluida:\n"+sys.stdin.read()}))' "$code" <<<"$summary"
exit 0
