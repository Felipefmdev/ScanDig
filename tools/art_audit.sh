#!/usr/bin/env bash
# Auditoria de arte (#61): referência | jogo (frente, 3/4, lado) numa só imagem.
# Uso: tools/art_audit.sh "<godot console exe>" <ref_nome> <res://cena.tscn> [saida_dir]
# Ex.: tools/art_audit.sh "$GODOT" morcego res://gameplay/enemies/bat/bat.tscn
# Saída: <saida_dir>/<ref_nome>_ref_vs_jogo.png (por omissão .bot_runs/art_compare).
set -euo pipefail
GODOT="$1"; NAME="$2"; SCENE="$3"
cd "$(dirname "$0")/.."
OUT_DIR="${4:-.bot_runs/art_compare}"
mkdir -p "$OUT_DIR"
OUT="$(cd "$OUT_DIR" && pwd)/$NAME"
REF="/c/Users/felip/Pictures/scandig/$NAME.jpg"
if command -v cygpath >/dev/null 2>&1; then
	OUT="$(cygpath -m "$OUT")"; REF="$(cygpath -m "$REF")"
fi
"$GODOT" --path . --resolution 640x640 --windowed res://gameplay/debug/art_audit.tscn \
	-- "--subject=$SCENE" "--out=$OUT" > /dev/null 2>&1
python - "$REF" "$OUT" <<'EOF'
import sys
from PIL import Image
ref, out = sys.argv[1], sys.argv[2]
h = 640
tiles = [Image.open(ref).convert("RGB")]
tiles += [Image.open(f"{out}_{i}.png").convert("RGB") for i in range(3)]
tiles = [t.resize((round(t.width * h / t.height), h)) for t in tiles]
sheet = Image.new("RGB", (sum(t.width for t in tiles), h), (255, 255, 255))
x = 0
for t in tiles:
	sheet.paste(t, (x, 0)); x += t.width
sheet.save(f"{out}_ref_vs_jogo.png")
print(f"{out}_ref_vs_jogo.png")
EOF
