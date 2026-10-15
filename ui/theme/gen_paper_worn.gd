# Gera ui/theme/paper_worn.png (determinístico, seed fixa):
# "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://ui/theme/gen_paper_worn.gd
# Papel com grão, pintas, contorno INK de 3 px com falhas, cantos lascados, degrau escuro
# embaixo/à direita e sombra dura deslocada (3, 3). Usado em 9-patch (margens TEX_MARGIN).
extends SceneTree

const OUT_PATH: String = "res://ui/theme/paper_worn.png"
const SIZE: int = 128
const SEED: int = 51051
const BORDER: int = 3
const SHADOW_OFFSET: int = 3
## Tamanho do chanfro (canto lascado) de cada canto: sup. esq., sup. dir., inf. dir., inf. esq.
const CHIPS: Array[int] = [4, 6, 3, 5]
## Margem do 9-patch usada em build_theme.gd; nada de pinta forte fora dela.
const TEX_MARGIN: int = 14
const STEP_BAND: int = 3

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _body: int = SIZE - SHADOW_OFFSET


func _initialize() -> void:
	_rng.seed = SEED
	var img: Image = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Entalhes pequenos nas bordas (desgaste), fora dos cantos.
	var notches: Array[Vector3i] = []
	for i in range(6):
		notches.append(Vector3i(_rng.randi_range(0, 3), _rng.randi_range(TEX_MARGIN + 4, _body - TEX_MARGIN - 8), _rng.randi_range(3, 6)))
	for y in range(SIZE):
		for x in range(SIZE):
			if _inside(x, y, notches):
				img.set_pixel(x, y, _body_color(x, y, notches))
			elif _inside(x - SHADOW_OFFSET, y - SHADOW_OFFSET, notches):
				img.set_pixel(x, y, UiPalette.SHADOW)
	_speckle(img, notches)
	var err: Error = img.save_png(OUT_PATH)
	print("paper_worn: %s (%d)" % [OUT_PATH, err])
	quit(err)


## Forma do papel: retângulo do corpo menos os chanfros dos cantos e os entalhes.
func _inside(x: int, y: int, notches: Array[Vector3i]) -> bool:
	var last: int = _body - 1
	if x < 0 or y < 0 or x > last or y > last:
		return false
	if x + y < CHIPS[0] or (last - x) + y < CHIPS[1] or (last - x) + (last - y) < CHIPS[2] or x + (last - y) < CHIPS[3]:
		return false
	for n: Vector3i in notches:
		# n.x = lado (0 cima, 1 direita, 2 baixo, 3 esquerda), n.y = posição, n.z = largura; 1 px de fundo.
		var along: int = x if n.x == 0 or n.x == 2 else y
		var depth: int = y
		match n.x:
			1: depth = last - x
			2: depth = last - y
			3: depth = x
		if depth == 0 and along >= n.y and along < n.y + n.z:
			return false
	return true


func _body_color(x: int, y: int, notches: Array[Vector3i]) -> Color:
	var edge: int = _edge_distance(x, y, notches)
	if edge < BORDER:
		# Contorno desenhado à mão: às vezes 1 px mais claro (falha de tinta).
		if edge == BORDER - 1 and _rng.randf() < 0.08:
			return UiPalette.INK.lerp(UiPalette.WOOD, 0.6)
		return UiPalette.INK
	var c: Color = UiPalette.PAPER
	var last: int = _body - 1
	# Sombreado em degrau embaixo e à direita, dentro da margem do 9-patch.
	if last - y < BORDER + STEP_BAND or last - x < BORDER + STEP_BAND:
		c = UiPalette.PAPER.lerp(UiPalette.PAPER_DARK, 0.55)
	# Grão: variação de ±2% em degraus de 1%, sem gradiente.
	var grain: float = float(_rng.randi_range(-2, 2)) * 0.01
	return Color(clampf(c.r + grain, 0, 1), clampf(c.g + grain, 0, 1), clampf(c.b + grain * 1.3, 0, 1), 1)


## Distância (Chebyshev, até BORDER) até um pixel fora da forma.
func _edge_distance(x: int, y: int, notches: Array[Vector3i]) -> int:
	for d in range(BORDER):
		for oy in range(-d - 1, d + 2):
			for ox in range(-d - 1, d + 2):
				if absi(ox) != d + 1 and absi(oy) != d + 1:
					continue
				if not _inside(x + ox, y + oy, notches):
					return d
	return BORDER


## Pintas e salpicos sutis: pontos de 1–2 px em madeira/papel escuro com alfa baixo.
func _speckle(img: Image, notches: Array[Vector3i]) -> void:
	for i in range(90):
		var x: int = _rng.randi_range(BORDER + 1, _body - BORDER - 3)
		var y: int = _rng.randi_range(BORDER + 1, _body - BORDER - 3)
		var tint: Color = UiPalette.WOOD if _rng.randf() < 0.35 else UiPalette.PAPER_DARK
		var alpha: float = _rng.randf_range(0.12, 0.22) if tint == UiPalette.WOOD else _rng.randf_range(0.35, 0.6)
		var r: int = 1 if _rng.randf() < 0.75 else 2
		for oy in range(r):
			for ox in range(r):
				if _edge_distance(x + ox, y + oy, notches) < BORDER:
					continue
				var base: Color = img.get_pixel(x + ox, y + oy)
				img.set_pixel(x + ox, y + oy, base.lerp(tint, alpha))
	# Ferrugem leve perto dos cantos (como as quinas do kit médico).
	var corners: Array[Vector2i] = [Vector2i(5, 5), Vector2i(_body - 8, 5), Vector2i(_body - 8, _body - 8), Vector2i(5, _body - 8)]
	for corner: Vector2i in corners:
		for i in range(7):
			var p: Vector2i = corner + Vector2i(_rng.randi_range(-2, 4), _rng.randi_range(-2, 4))
			if _edge_distance(p.x, p.y, notches) < BORDER:
				continue
			img.set_pixel(p.x, p.y, img.get_pixel(p.x, p.y).lerp(UiPalette.ORANGE.lerp(UiPalette.WOOD, 0.4), 0.3))
