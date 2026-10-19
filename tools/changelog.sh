#!/usr/bin/env bash
# CHANGELOG em Markdown dos commits convencionais entre a tag v* anterior e REF (#138),
# agrupado por feat/fix/perf/docs/test/chore (o resto vai em "Outros"; merges ficam fora).
# Uso: tools/changelog.sh [REF] [TAG_ANTERIOR]
#   REF padrão HEAD; TAG_ANTERIOR padrão a última tag v* antes de REF (sem tag: desde o início).
set -euo pipefail
cd "$(dirname "$0")/.."
REF="${1:-HEAD}"
PREV="${2:-}"
if [ -z "$PREV" ]; then
	# Numa tag, a anterior é a última v* do pai; fora dela, a última v* alcançável.
	if git rev-parse -q --verify "$REF^" >/dev/null; then
		PREV="$(git describe --tags --abbrev=0 --match 'v*' "$REF^" 2>/dev/null || true)"
	fi
fi
RANGE="$REF"
[ -n "$PREV" ] && RANGE="$PREV..$REF"

LOG="$(git log --no-merges --format='%h%x09%s' "$RANGE")"
declare -A TITLES=([feat]="Novidades" [fix]="Correções" [perf]="Desempenho" [docs]="Documentação"
	[test]="Testes" [chore]="Manutenção" [other]="Outros")
declare -A LINES=()
while IFS=$'\t' read -r hash subject; do
	[ -z "$hash" ] && continue
	type="other"
	text="$subject"
	if [[ "$subject" =~ ^(feat|fix|perf|docs|test|chore)(\(([^\)]*)\))?!?:\ (.*)$ ]]; then
		type="${BASH_REMATCH[1]}"
		text="${BASH_REMATCH[4]}"
		[ -n "${BASH_REMATCH[3]}" ] && text="**${BASH_REMATCH[3]}:** $text"
	fi
	LINES[$type]+="- $text ($hash)"$'\n'
done <<<"$LOG"

echo "## Mudanças${PREV:+ desde $PREV}"
echo
for type in feat fix perf docs test chore other; do
	[ -z "${LINES[$type]:-}" ] && continue
	echo "### ${TITLES[$type]}"
	echo
	printf '%s\n' "${LINES[$type]}"
done
