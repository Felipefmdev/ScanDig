import os
import subprocess
import sys
from PIL import Image, ImageDraw

GODOT = "C:/Users/felip/Downloads/Godot_v4.3-stable_win64.exe/Godot_v4.3-stable_win64_console.exe"
TEMP_DIR = os.path.join(os.environ.get("TEMP", "C:/Temp"), "char_compare")
os.makedirs(TEMP_DIR, exist_ok=True)

CHARACTERS = [
    # Inimigos Comuns (13)
    ("crab", "res://gameplay/enemies/crab/crab.tscn", "caranguejo"),
    ("hermit_crab", "res://gameplay/enemies/crab/hermit_crab.tscn", "ermitao"),
    ("seagull", "res://gameplay/enemies/seagull/seagull.tscn", "gaivota"),
    ("snake", "res://gameplay/enemies/snake/snake.tscn", "cobra"),
    ("mole", "res://gameplay/enemies/mole/mole.tscn", "toupeira"),
    ("crow", "res://gameplay/enemies/crow/crow.tscn", "corvo"),
    ("stone_guardian", "res://gameplay/enemies/stone_guardian/stone_guardian.tscn", "guardiao_pedra"),
    ("bat", "res://gameplay/enemies/bat/bat.tscn", "morcego"),
    ("ice_wolf", "res://gameplay/enemies/ice_wolf/ice_wolf.tscn", "lobo_gelo"),
    ("penguin", "res://gameplay/enemies/penguin/penguin.tscn", "pinguim_ladrao"),
    ("walrus", "res://gameplay/enemies/walrus/walrus.tscn", "morsa"),
    ("crawler", "res://gameplay/enemies/crawler/crawler.tscn", "criatura_rastejante"),
    ("floater", "res://gameplay/enemies/floater/floater.tscn", "criatura_flutuante"),
    # NPCs (5)
    ("pescador_ze", "res://gameplay/debug/art_subjects/pescador_ze.tscn", "pescador_ze"),
    ("dona_lurdes", "res://gameplay/debug/art_subjects/dona_lurdes.tscn", "dona_lurdes"),
    ("arqueologa_ines", "res://gameplay/debug/art_subjects/arqueologa_ines.tscn", "arqueologa_ines"),
    ("velho_bjorn", "res://gameplay/debug/art_subjects/velho_bjorn.tscn", "velho_bjorn"),
    ("dra_vega", "res://gameplay/debug/art_subjects/dra_vega.tscn", "dra_vega"),
]

cards = []

for char_id, scene_path, ref_id in CHARACTERS:
    out_prefix = os.path.join(TEMP_DIR, char_id)
    cmd = [
        GODOT,
        "--path", ".",
        "--windowed",
        "--resolution", "512x512",
        "res://gameplay/debug/art_audit.tscn",
        "--",
        f"--subject={scene_path}",
        f"--out={out_prefix}"
    ]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        print(f"Error rendering {char_id}: {res.stderr}")
        continue
    
    render_path = f"{out_prefix}_1.png"
    if not os.path.exists(render_path):
        render_path = f"{out_prefix}_0.png"
        
    ref_path = f"docs/art/reference/{ref_id}.jpg"
    if not os.path.exists(ref_path):
        ref_path = f"C:/Users/felip/Pictures/scandig/{ref_id}.jpg"
        
    ref_img = Image.open(ref_path).convert("RGB")
    rend_img = Image.open(render_path).convert("RGB")
    
    # Center-crop reference to square before resizing to prevent distortion
    w, h = ref_img.size
    min_dim = min(w, h)
    left = (w - min_dim) // 2
    top = (h - min_dim) // 2
    ref_img = ref_img.crop((left, top, left + min_dim, top + min_dim))
    
    ref_img = ref_img.resize((400, 400), Image.Resampling.LANCZOS)
    rend_img = rend_img.resize((400, 400), Image.Resampling.LANCZOS)
    
    card = Image.new("RGB", (820, 450), (225, 220, 205))
    draw = ImageDraw.Draw(card)
    card.paste(ref_img, (10, 40))
    card.paste(rend_img, (410, 40))
    
    draw.text((15, 12), f"{char_id} (Ref: {ref_id}.jpg)", fill=(40, 30, 20))
    draw.text((415, 12), f"{char_id} (Modelo 3D Godot)", fill=(40, 30, 20))
    
    os.makedirs("docs/art/character_cards", exist_ok=True)
    card.save(f"docs/art/character_cards/{char_id}.png")
    
    cards.append((char_id, card))
    print(f"Rendered and paired {char_id}")

card_w = 820
card_h = 450
cols = 3
rows = (len(cards) + cols - 1) // cols
sheet = Image.new("RGB", (cols * card_w, rows * card_h), (200, 195, 185))

for i, (char_id, card) in enumerate(cards):
    c = i % cols
    r = i // cols
    sheet.paste(card, (c * card_w, r * card_h))

sheet_out = "docs/art/character_comparison_18_models.png"
os.makedirs("docs/art", exist_ok=True)
sheet.save(sheet_out, quality=90)
print(f"Saved master character comparison sheet to {sheet_out} ({sheet.width}x{sheet.height})")
