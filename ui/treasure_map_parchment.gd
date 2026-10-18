class_name TreasureMapParchment
extends TreasureMapScroll

## Pergaminho desenhado do Mapa do Tesouro (#117). Mesmo modelo do TreasureMapScroll (#112: found,
## piece_rect, is_cell_found, ROUTE_POINTS), outro desenho:
##   - a arte (mar e costa, sítios, caminho tracejado, rosa dos ventos, Ilha) é montada uma vez em
##     coordenadas do pergaminho e recortada por peça com Geometry2D, por isso continua entre peças
##     vizinhas e o mapa completo fica coerente;
##   - traço "à mão" com RandomNumberGenerator de seed fixa: não treme a cada redraw;
##   - peça por descobrir: papel rasgado e chamuscado (borda irregular, seed por peça) e "?" discreto;
##   - a Ilha do Tesouro fica na peça ISLAND_CELL (3, 0), o cratera_frag_2 (a última peça, do chefe
##     da Cratera) e o fim do ROUTE_POINTS: o caminho sai da Cratera e cruza o mar até ela. O X
##     vermelho só aparece com o mapa completo (has_treasure_x).
## Só visual: não recebe foco nem input.

const ISLAND_CELL: Vector2i = Vector2i(3, 0)
const COMPASS_CELL: Vector2i = Vector2i(0, 0)
const ART_SEED: int = 117
const SEA_COLOR: Color = Color(0.58, 0.66, 0.66)
const SAND_COLOR: Color = Color(0.86, 0.76, 0.52)
const SNOW_COLOR: Color = Color(0.97, 0.95, 0.9)
## Pontos do caminho que viram marca de sítio, com o nome e onde fica o nome (em alturas do
## pergaminho, a partir da marca).
const SITE_LABELS: Array = [
	[0, "Praia", Vector2(0.12, 0.13)],
	[2, "Campo", Vector2(0.06, 0.15)],
	[4, "Ruínas", Vector2(-0.12, -0.06)],
	[7, "Geleira", Vector2(-0.05, 0.17)],
	[9, "Cratera", Vector2(0.0, 0.3)],
]
## Nome da Ilha, a partir do fim do ROUTE_POINTS (à esquerda, sobre o mar).
const ISLAND_LABEL_OFFSET: Vector2 = Vector2(-0.3, 0.02)
## Mais alto que o TreasureMapScroll (150): a Base tem folga e o desenho fica legível.
const MIN_HEIGHT: float = 180.0

## Por peça desenhada no último _draw: {"state": "found"|"missing", "polygons": n, "lines": n,
## "tags": [...]}. Para os testes.
var debug_ops: Dictionary = {}

var _art: Array[Dictionary] = []
var _art_size: Vector2 = Vector2.ZERO


func _init() -> void:
	super._init()
	custom_minimum_size.y = MIN_HEIGHT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE


## "found" ou "missing".
func piece_state(cell: Vector2i) -> String:
	return "found" if is_cell_found(cell) else "missing"


## Mapa completo: as 8 peças, a Ilha e o X.
func has_treasure_x() -> bool:
	for id: String in GameState.MAP_FRAGMENT_IDS:
		if not found.has(id):
			return false
	return true


func _draw() -> void:
	debug_ops.clear()
	if size.x < 8.0 or size.y < 8.0:
		return
	if size != _art_size:
		_build_art()
	for row: int in ROWS:
		for col: int in COLS:
			var cell: Vector2i = Vector2i(col, row)
			if is_cell_found(cell):
				_draw_found(cell)
			else:
				_draw_missing(cell)
	if has_treasure_x():
		_draw_treasure_x()


# --- Peças ---------------------------------------------------------------------

func _draw_found(cell: Vector2i) -> void:
	var ops: Dictionary = {"state": "found", "polygons": 0, "lines": 0, "tags": []}
	debug_ops[cell] = ops
	var rect: Rect2 = piece_rect(cell)
	var rng: RandomNumberGenerator = _cell_rng(cell, 1)
	var poly: PackedVector2Array = _torn_rect(rect, 1.6, rng)
	draw_colored_polygon(poly, UiPalette.PAPER)
	# Manchas de papel velho.
	for i: int in 2:
		var c: Vector2 = rect.position + Vector2(rng.randf_range(0.25, 0.75), rng.randf_range(0.25, 0.75)) * rect.size
		var r: float = minf(rect.size.x, rect.size.y) * rng.randf_range(0.12, 0.2)
		draw_colored_polygon(_ellipse(c, Vector2(r * 1.4, r), 14), Color(UiPalette.PAPER_DARK, 0.35))
	var bounds: Rect2 = rect.grow(2.0)
	for item: Dictionary in _art:
		if not (item["aabb"] as Rect2).intersects(bounds):
			continue
		var drawn: bool = false
		if item["fill"]:
			for part: PackedVector2Array in Geometry2D.intersect_polygons(item["points"], poly):
				if part.size() >= 3:
					draw_colored_polygon(part, item["color"])
					ops["polygons"] += 1
					drawn = true
		else:
			for part: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(item["points"], poly):
				if part.size() >= 2:
					draw_polyline(part, item["color"], item["width"], true)
					ops["lines"] += 1
					drawn = true
		if drawn and not (ops["tags"] as Array).has(item["tag"]):
			(ops["tags"] as Array).append(item["tag"])
	_draw_labels(cell, rect)
	var edge: PackedVector2Array = poly.duplicate()
	edge.append(poly[0])
	draw_polyline(edge, Color(UiPalette.WOOD, 0.55), 1.2, true)


func _draw_missing(cell: Vector2i) -> void:
	var rect: Rect2 = piece_rect(cell)
	var rng: RandomNumberGenerator = _cell_rng(cell, 2)
	var amp: float = clampf(minf(rect.size.x, rect.size.y) * 0.08, 3.0, 9.0)
	var outer: PackedVector2Array = _torn_rect(rect, amp, rng)
	var inner: PackedVector2Array = _torn_rect(rect.grow(-amp * 0.9), amp * 0.6, rng)
	# Orla chamuscada por fora, papel escuro por dentro, borda queimada e manchas de queimado.
	draw_colored_polygon(outer, UiPalette.PAPER_DARK.darkened(0.45))
	draw_colored_polygon(inner, UiPalette.PAPER_DARK.darkened(0.12))
	for i: int in 2:
		var spot: Vector2 = rect.position + Vector2(rng.randf_range(0.15, 0.85), rng.randf_range(0.2, 0.8)) * rect.size
		var r: float = minf(rect.size.x, rect.size.y) * rng.randf_range(0.08, 0.14)
		draw_colored_polygon(_ellipse(spot, Vector2(r * 1.3, r), 12), Color(UiPalette.WOOD_DARK, 0.18))
	var edge: PackedVector2Array = outer.duplicate()
	edge.append(outer[0])
	draw_polyline(edge, Color(UiPalette.WOOD_DARK, 0.9), 2.0, true)
	var font: Font = get_theme_default_font()
	var fs: int = int(clampf(rect.size.y * 0.32, 12.0, 36.0))
	var text_size: Vector2 = font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(font, rect.get_center() + Vector2(-text_size.x * 0.5, fs * 0.35), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UiPalette.WOOD_DARK, 0.55))
	debug_ops[cell] = {"state": "missing", "polygons": 4, "lines": 1, "tags": ["torn"]}


func _draw_labels(cell: Vector2i, rect: Rect2) -> void:
	var font: Font = get_theme_default_font()
	var fs: int = int(clampf(size.y * 0.085, 11.0, 16.0))
	var labels: Array = SITE_LABELS.duplicate()
	labels.append([ROUTE_POINTS.size() - 1, "Ilha", ISLAND_LABEL_OFFSET])
	for entry: Array in labels:
		var anchor: Vector2 = ROUTE_POINTS[entry[0]] * size + (entry[2] as Vector2) * size.y
		var text: String = entry[1]
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var box: Rect2 = Rect2(anchor + Vector2(-w * 0.5, -fs), Vector2(w, fs * 1.2))
		if rect.grow(-2.0).encloses(box):
			draw_string(font, box.position + Vector2(0.0, fs), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiPalette.WOOD_DARK)
			(debug_ops[cell]["tags"] as Array).append("label:" + text)


func _draw_treasure_x() -> void:
	var c: Vector2 = ROUTE_POINTS[ROUTE_POINTS.size() - 1] * size
	var s: float = size.y * 0.065
	draw_polyline(_circle_points(c, s * 2.0, 28, true), Color(UiPalette.RED_BURNT, 0.7), 2.0, true)
	draw_line(c + Vector2(-s, -s), c + Vector2(s, s), UiPalette.RED_BURNT, 4.0, true)
	draw_line(c + Vector2(-s, s), c + Vector2(s, -s), UiPalette.RED_BURNT, 4.0, true)
	if debug_ops.has(ISLAND_CELL):
		(debug_ops[ISLAND_CELL]["tags"] as Array).append("x")


# --- Arte em coordenadas do pergaminho ----------------------------------------

func _build_art() -> void:
	_art.clear()
	_art_size = size
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = ART_SEED
	var h: float = size.y
	var wobble: float = h * 0.008
	# Mar da Praia (canto de baixo à esquerda) e mar da Ilha (canto de cima à direita).
	var coast_a: PackedVector2Array = _hand(_norm([Vector2(0.0, 0.56), Vector2(0.018, 0.63), Vector2(0.032, 0.72),
		Vector2(0.026, 0.8), Vector2(0.036, 0.88), Vector2(0.07, 0.925), Vector2(0.12, 0.915),
		Vector2(0.17, 0.945), Vector2(0.21, 0.98), Vector2(0.235, 1.0)]), wobble, rng)
	var coast_b: PackedVector2Array = _hand(_norm([Vector2(0.755, 0.0), Vector2(0.775, 0.08), Vector2(0.81, 0.15),
		Vector2(0.805, 0.24), Vector2(0.84, 0.31), Vector2(0.9, 0.335), Vector2(0.95, 0.3), Vector2(1.0, 0.34)]), wobble, rng)
	var sea_a: PackedVector2Array = coast_a.duplicate()
	sea_a.append_array(_norm([Vector2(0.235, 1.05), Vector2(-0.05, 1.05), Vector2(-0.05, 0.56)]))
	var sea_b: PackedVector2Array = coast_b.duplicate()
	sea_b.append_array(_norm([Vector2(1.05, 0.34), Vector2(1.05, -0.05), Vector2(0.755, -0.05)]))
	_fill("sea", sea_a, SEA_COLOR)
	_fill("sea", sea_b, SEA_COLOR)
	for p: Vector2 in [Vector2(0.012, 0.66), Vector2(0.014, 0.9), Vector2(0.09, 0.975), Vector2(0.8, 0.05),
			Vector2(0.97, 0.07), Vector2(0.86, 0.26), Vector2(0.99, 0.24)]:
		_line("wave", _wave(p * size, h * 0.035), Color(UiPalette.METAL, 0.8), 1.2)
	_line("coast", coast_a, UiPalette.INK, 1.6)
	_line("coast", coast_b, UiPalette.INK, 1.6)
	_build_praia(rng, h)
	_build_campo(rng, h)
	_build_ruinas(rng, h)
	_build_geleira(rng, h)
	_build_cratera(rng, h)
	_build_island(rng, h)
	_build_route(h)
	_build_compass(h)


func _build_praia(rng: RandomNumberGenerator, h: float) -> void:
	# Coqueiro e duas dunas.
	var base: Vector2 = Vector2(0.15, 0.9) * size
	var top: Vector2 = base + Vector2(h * 0.05, -h * 0.2)
	_line("praia", _hand(PackedVector2Array([base, base.lerp(top, 0.5) + Vector2(h * 0.03, 0.0), top]), h * 0.004, rng), UiPalette.WOOD, 2.0)
	for a: float in [-2.6, -1.9, -1.2, -0.5]:
		var tip: Vector2 = top + Vector2(cos(a), sin(a) * 0.6 + 0.5) * h * 0.08
		_line("praia", PackedVector2Array([top, top.lerp(tip, 0.5) + Vector2(0.0, -h * 0.02), tip]), UiPalette.GREEN_BOTTLE, 1.8)
	for p: Vector2 in [Vector2(0.1, 0.72), Vector2(0.21, 0.86)]:
		_line("praia", _arc(p * size, h * 0.05, PI + 0.5, TAU - 0.5, 8), UiPalette.WOOD, 1.2)


func _build_campo(rng: RandomNumberGenerator, h: float) -> void:
	# Lavoura (paralelogramo com sulcos) e árvores.
	var o: Vector2 = Vector2(0.4, 0.66) * size
	var u: Vector2 = Vector2(h * 0.26, h * 0.03)
	var v: Vector2 = Vector2(-h * 0.04, h * 0.2)
	_line("campo", _closed(PackedVector2Array([o, o + u, o + u + v, o + v])), UiPalette.WOOD, 1.4)
	for i: int in range(1, 5):
		var t: float = float(i) / 5.0
		_line("campo", _hand(PackedVector2Array([o + v * t, o + v * t + u]), h * 0.003, rng), Color(UiPalette.GREEN_BOTTLE, 0.85), 1.2)
	for p: Vector2 in [Vector2(0.28, 0.93), Vector2(0.47, 0.93), Vector2(0.29, 0.56)]:
		_tree(p * size, h * 0.045)


func _build_ruinas(rng: RandomNumberGenerator, h: float) -> void:
	# Colunas (uma partida) e um templo em degraus.
	var heights: Array[float] = [0.17, 0.12, 0.07]
	for i: int in 3:
		var x: float = 0.12 + 0.035 * float(i)
		var foot: Vector2 = Vector2(x, 0.46) * size
		var col_h: float = h * heights[i]
		var w: float = h * 0.035
		_line("ruinas", _hand(_closed(PackedVector2Array([foot + Vector2(-w * 0.5, 0.0), foot + Vector2(-w * 0.5, -col_h),
			foot + Vector2(w * 0.5, -col_h), foot + Vector2(w * 0.5, 0.0)])), h * 0.003, rng), UiPalette.INK, 1.3)
		_line("ruinas", PackedVector2Array([foot + Vector2(-w * 0.8, -col_h), foot + Vector2(w * 0.8, -col_h)]), UiPalette.INK, 2.0)
	var base: Vector2 = Vector2(0.455, 0.47) * size
	for i: int in 3:
		var half: float = h * (0.13 - 0.035 * float(i))
		var y0: float = base.y - h * 0.045 * float(i)
		_line("ruinas", _closed(PackedVector2Array([Vector2(base.x - half, y0), Vector2(base.x - half, y0 - h * 0.045),
			Vector2(base.x + half, y0 - h * 0.045), Vector2(base.x + half, y0)])), UiPalette.INK, 1.3)


func _build_geleira(rng: RandomNumberGenerator, h: float) -> void:
	# Cordilheira: o pico do meio atravessa a linha entre (2, 0) e (2, 1). Lago gelado embaixo.
	for peak: Array in [[Vector2(0.69, 0.1), 0.42, 0.13], [Vector2(0.725, 0.36), 0.64, 0.16], [Vector2(0.535, 0.3), 0.45, 0.1]]:
		var tip: Vector2 = (peak[0] as Vector2) * size
		var foot_y: float = float(peak[1]) * size.y
		var half: float = float(peak[2]) * h * 1.6
		var left: Vector2 = Vector2(tip.x - half, foot_y)
		var right: Vector2 = Vector2(tip.x + half, foot_y)
		var body: PackedVector2Array = _hand(PackedVector2Array([left, tip, right]), h * 0.006, rng)
		_fill("geleira", body, UiPalette.PAPER_DARK)
		var cap: float = 0.32
		_fill("geleira", PackedVector2Array([tip.lerp(left, cap), tip, tip.lerp(right, cap),
			tip.lerp(right, cap * 0.6) + Vector2(0.0, h * 0.02), tip.lerp(left, cap * 0.6) + Vector2(0.0, h * 0.025)]), SNOW_COLOR)
		_line("geleira", body, UiPalette.INK, 1.5)
	var lake: Vector2 = Vector2(0.665, 0.88) * size
	var lake_poly: PackedVector2Array = _ellipse(lake, Vector2(h * 0.16, h * 0.055), 20)
	_fill("geleira", lake_poly, Color(UiPalette.PAPER_LIGHT, 0.9))
	_line("geleira", _closed(lake_poly), UiPalette.METAL, 1.2)
	_line("geleira", PackedVector2Array([lake + Vector2(-h * 0.06, -h * 0.01), lake + Vector2(0.0, h * 0.01), lake + Vector2(h * 0.05, -h * 0.015)]), UiPalette.METAL, 1.0)


func _build_cratera(rng: RandomNumberGenerator, h: float) -> void:
	# Cone que atravessa a linha entre (3, 0) e (3, 1), com a boca escura; meteoritos embaixo.
	var top: Vector2 = Vector2(0.875, 0.42) * size
	var foot_y: float = 0.64 * size.y
	var cone: PackedVector2Array = _hand(PackedVector2Array([Vector2(top.x - h * 0.28, foot_y), top + Vector2(-h * 0.1, 0.0),
		top + Vector2(h * 0.1, 0.0), Vector2(top.x + h * 0.28, foot_y)]), h * 0.006, rng)
	_fill("cratera", cone, UiPalette.PAPER_DARK)
	_line("cratera", cone, UiPalette.INK, 1.5)
	var mouth: PackedVector2Array = _ellipse(top, Vector2(h * 0.1, h * 0.03), 16)
	_fill("cratera", mouth, Color(UiPalette.WOOD_DARK, 0.85))
	_line("cratera", _closed(mouth), UiPalette.INK, 1.2)
	for p: Vector2 in [Vector2(0.93, 0.8), Vector2(0.83, 0.93), Vector2(0.97, 0.62)]:
		var rock: PackedVector2Array = _hand(_ellipse(p * size, Vector2(h * 0.035, h * 0.025), 7), h * 0.006, rng)
		_fill("cratera", rock, UiPalette.METAL)
		_line("cratera", _closed(rock), UiPalette.INK, 1.0)


func _build_island(rng: RandomNumberGenerator, h: float) -> void:
	var c: Vector2 = ROUTE_POINTS[ROUTE_POINTS.size() - 1] * size
	var island: PackedVector2Array = _hand(_ellipse(c, Vector2(h * 0.13, h * 0.085), 18), h * 0.008, rng)
	_fill("island", island, SAND_COLOR)
	_line("island", _closed(island), UiPalette.INK, 1.6)
	var base: Vector2 = c + Vector2(h * 0.07, h * 0.02)
	var top: Vector2 = base + Vector2(h * 0.02, -h * 0.11)
	_line("island", PackedVector2Array([base, top]), UiPalette.WOOD, 1.6)
	for a: float in [-2.5, -1.6, -0.6]:
		_line("island", PackedVector2Array([top, top + Vector2(cos(a), sin(a) * 0.5 + 0.45) * h * 0.05]), UiPalette.GREEN_BOTTLE, 1.5)


## Caminho tracejado (curva suave pelos ROUTE_POINTS) e as marcas dos sítios.
func _build_route(h: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in ROUTE_POINTS:
		pts.append(p * size)
	var smooth: PackedVector2Array = _catmull(pts, 10)
	var dash: float = maxf(h * 0.045, 5.0)
	var gap: float = dash * 0.7
	var current: PackedVector2Array = PackedVector2Array([smooth[0]])
	var left: float = dash
	var drawing: bool = true
	for i: int in range(1, smooth.size()):
		var a: Vector2 = smooth[i - 1]
		var b: Vector2 = smooth[i]
		var seg: float = a.distance_to(b)
		while seg > left:
			var cut: Vector2 = a.lerp(b, left / seg)
			if drawing:
				current.append(cut)
				_line("route", current, UiPalette.RED_BURNT, 2.2)
			current = PackedVector2Array([cut])
			seg -= left
			a = cut
			drawing = not drawing
			left = dash if drawing else gap
		left -= seg
		if drawing:
			current.append(b)
	if drawing and current.size() >= 2:
		_line("route", current, UiPalette.RED_BURNT, 2.2)
	for entry: Array in SITE_LABELS:
		_fill("site", _ellipse(ROUTE_POINTS[entry[0]] * size, Vector2.ONE * h * 0.028, 12), UiPalette.INK)


func _build_compass(h: float) -> void:
	var c: Vector2 = Vector2(0.06, 0.24) * size
	var r: float = h * 0.13
	_line("compass", _circle_points(c, r * 0.72, 24, true), Color(UiPalette.WOOD_DARK, 0.8), 1.2)
	for i: int in 4:
		var dir: Vector2 = Vector2.UP.rotated(float(i) * PI * 0.5)
		var side: Vector2 = dir.orthogonal() * r * 0.16
		var length: float = r if i % 2 == 0 else r * 0.7
		var color: Color = UiPalette.RED_BURNT if i == 0 else UiPalette.WOOD_DARK
		_fill("compass", PackedVector2Array([c + side, c + dir * length, c - side]), color)
	_line("compass", PackedVector2Array([c + Vector2(-r * 0.12, -r * 1.12), c + Vector2(-r * 0.12, -r * 1.4),
		c + Vector2(r * 0.12, -r * 1.12), c + Vector2(r * 0.12, -r * 1.4)]), UiPalette.WOOD_DARK, 1.4)


# --- Ajudantes -----------------------------------------------------------------

func _fill(tag: String, points: PackedVector2Array, color: Color) -> void:
	_art.append({"tag": tag, "fill": true, "points": points, "color": color, "width": 0.0, "aabb": _aabb(points)})


func _line(tag: String, points: PackedVector2Array, color: Color, width: float) -> void:
	_art.append({"tag": tag, "fill": false, "points": points, "color": color, "width": width, "aabb": _aabb(points).grow(width)})


func _tree(foot: Vector2, r: float) -> void:
	_line("campo", PackedVector2Array([foot, foot + Vector2(0.0, -r)]), UiPalette.WOOD, 1.6)
	var crown: PackedVector2Array = _ellipse(foot + Vector2(0.0, -r * 1.6), Vector2(r * 0.8, r * 0.75), 10)
	_fill("campo", crown, Color(UiPalette.GREEN_BOTTLE, 0.75))
	_line("campo", _closed(crown), UiPalette.INK, 1.0)


func _norm(points: Array[Vector2]) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in points:
		out.append(p * size)
	return out


## Subdivide e desloca cada ponto um pouco na normal: traço de mão (seed fixa).
func _hand(points: PackedVector2Array, amp: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array([points[0]])
	for i: int in range(1, points.size()):
		var a: Vector2 = points[i - 1]
		var b: Vector2 = points[i]
		var steps: int = maxi(int(a.distance_to(b) / 7.0), 1)
		var normal: Vector2 = (b - a).normalized().orthogonal()
		for k: int in range(1, steps + 1):
			var p: Vector2 = a.lerp(b, float(k) / float(steps))
			if k < steps:
				p += normal * rng.randf_range(-amp, amp)
			out.append(p)
	return out


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = points.duplicate()
	out.append(points[0])
	return out


func _ellipse(c: Vector2, radius: Vector2, n: int) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in n:
		var a: float = TAU * float(i) / float(n)
		out.append(c + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	return out


func _circle_points(c: Vector2, r: float, n: int, closed: bool) -> PackedVector2Array:
	var out: PackedVector2Array = _ellipse(c, Vector2(r, r), n)
	return _closed(out) if closed else out


func _arc(c: Vector2, r: float, from: float, to: float, n: int) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in n + 1:
		var a: float = lerpf(from, to, float(i) / float(n))
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out


func _wave(c: Vector2, w: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in 7:
		var t: float = float(i) / 6.0
		out.append(c + Vector2((t - 0.5) * w, sin(t * TAU) * w * 0.12))
	return out


func _catmull(points: PackedVector2Array, per_segment: int) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array([points[0]])
	for i: int in points.size() - 1:
		var p0: Vector2 = points[maxi(i - 1, 0)]
		var p1: Vector2 = points[i]
		var p2: Vector2 = points[i + 1]
		var p3: Vector2 = points[mini(i + 2, points.size() - 1)]
		for k: int in range(1, per_segment + 1):
			var t: float = float(k) / float(per_segment)
			var t2: float = t * t
			var t3: float = t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	return out


func _aabb(points: PackedVector2Array) -> Rect2:
	var r: Rect2 = Rect2(points[0], Vector2.ZERO)
	for p: Vector2 in points:
		r = r.expand(p)
	return r


## Retângulo com a borda rasgada (só para dentro, peças vizinhas não se sobrepõem).
func _torn_rect(rect: Rect2, amp: float, rng: RandomNumberGenerator) -> PackedVector2Array:
	var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	var out: PackedVector2Array = PackedVector2Array()
	for i: int in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var inward: Vector2 = -(b - a).normalized().orthogonal()
		var steps: int = maxi(int(a.distance_to(b) / 9.0), 2)
		for k: int in steps:
			var p: Vector2 = a.lerp(b, float(k) / float(steps))
			var depth: float = rng.randf_range(0.0, amp) if k > 0 else amp * 0.5
			out.append(p + inward * depth)
	return out


func _cell_rng(cell: Vector2i, salt: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = ART_SEED * 1000 + cell.y * 100 + cell.x * 10 + salt
	return rng
