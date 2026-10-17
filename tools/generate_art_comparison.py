import os
import subprocess
import sys
from PIL import Image, ImageDraw, ImageFont

GODOT = "C:/Users/felip/Downloads/Godot_v4.3-stable_win64.exe/Godot_v4.3-stable_win64_console.exe"
TEMP_DIR = os.path.join(os.environ.get("TEMP", "C:/Temp"), "art_compare")
os.makedirs(TEMP_DIR, exist_ok=True)

MUSEUM_ITEMS = [
    "adaga_cerimonial", "bussola_congelada", "crampon_enferrujado", "cristal_eco",
    "cronometro_explorador", "escaravelho_jade", "geodo_estrelar", "idolo_jade",
    "lanterna_expedicao", "ligaduras_mumia", "mascara_ouro", "medalha_polar",
    "nucleo_adormecido", "nucleo_guardiao"
]

FOOD_ITEMS = [
    "minhoca", "tatuira", "marisco", "batata_esquecida",
    "cogumelo_cripta", "liquen_gelado", "larva_termica"
]

all_items = [(x, f"item:{x}") for x in MUSEUM_ITEMS] + [(x, f"res://gameplay/foods/{x}_world.tscn") for x in FOOD_ITEMS]

cards = []

for item_id, subject in all_items:
    out_prefix = os.path.join(TEMP_DIR, item_id)
    cmd = [
        GODOT,
        "--path", ".",
        "--windowed",
        "--resolution", "512x512",
        "res://gameplay/debug/art_audit.tscn",
        "--",
        f"--subject={subject}",
        f"--out={out_prefix}"
    ]
    subprocess.run(cmd, capture_output=True, check=True)
    
    render_path = f"{out_prefix}_1.png"
    ref_path = f"docs/art/reference/{item_id}.jpg"
    
    ref_img = Image.open(ref_path).convert("RGB")
    rend_img = Image.open(render_path).convert("RGB")
    
    # Resize both to 400x400
    ref_img = ref_img.resize((400, 400), Image.Resampling.LANCZOS)
    rend_img = rend_img.resize((400, 400), Image.Resampling.LANCZOS)
    
    # Create card 820 x 440 (with title)
    card = Image.new("RGB", (820, 450), (225, 220, 205))
    draw = ImageDraw.Draw(card)
    card.paste(ref_img, (10, 40))
    card.paste(rend_img, (410, 40))
    
    draw.text((15, 12), f"{item_id} (Referencia)", fill=(40, 30, 20))
    draw.text((415, 12), f"{item_id} (Modelo 3D Godot)", fill=(40, 30, 20))
    
    cards.append((item_id, card))
    print(f"Rendered and paired {item_id}")

# Now build master sheet: 3 columns x 7 rows
card_w = 820
card_h = 450
cols = 3
rows = (len(cards) + cols - 1) // cols
sheet = Image.new("RGB", (cols * card_w, rows * card_h), (200, 195, 185))

for i, (item_id, card) in enumerate(cards):
    c = i % cols
    r = i // cols
    sheet.paste(card, (c * card_w, r * card_h))

sheet_out = "docs/art/art_comparison_21_models.png"
sheet.save(sheet_out, quality=90)
print(f"Saved master comparison sheet to {sheet_out} ({sheet.width}x{sheet.height})")
