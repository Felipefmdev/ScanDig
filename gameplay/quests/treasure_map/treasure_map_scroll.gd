class_name TreasureMapScroll
extends Control

## Pergaminho do Mapa do Tesouro (#112): grelha de 4 x 2 peças (GameState.MAP_FRAGMENTS[*].piece).
## Cada fragmento encontrado mostra o seu pedaço do caminho — dos 5 sítios até à Ilha do Tesouro,
## com o X no fim; as peças em falta ficam em silhueta escura com "?". Só desenho (Control),
## para o painel da base e para quem mais quiser mostrar o mapa.

const COLS: int = 4
const ROWS: int = 2
const PARCHMENT: Color = Color("#e8d6a8")
const PARCHMENT_DARK: Color = Color("#c9b07a")
const INK: Color = Color("#4a3320")
const ROUTE: Color = Color("#9e3b2b")
const SEA: Color = Color("#7fb0c0")
const MISSING: Color = Color(0.17, 0.13, 0.1, 0.85)
const MISSING_EDGE: Color = Color(0.55, 0.45, 0.3, 0.9)
const GAP: float = 3.0

## Pontos do caminho em coordenadas do pergaminho (0..1): Praia -> Campo -> Ruínas -> Geleira ->
## Cratera -> Ilha do Tesouro. O caminho atravessa as 8 peças.
const ROUTE_POINTS: Array[Vector2] = [
	Vector2(0.06, 0.82), Vector2(0.2, 0.62), Vector2(0.33, 0.78), Vector2(0.4, 0.4),
	Vector2(0.22, 0.22), Vector2(0.48, 0.15), Vector2(0.62, 0.3), Vector2(0.58, 0.72),
	Vector2(0.78, 0.8), Vector2(0.86, 0.45), Vector2(0.93, 0.2),
]
## Marcas dos sítios ao longo do caminho (índice em ROUTE_POINTS) e o X da ilha.
const LANDMARKS: Array[int] = [0, 2, 4, 7, 9]

## Ids dos fragmentos já encontrados.
var found: Array[String] = []:
	set(value):
		found = value
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(400.0, 150.0)


## Retângulo (em pixels deste Control) da peça na coluna/linha `cell`.
func piece_rect(cell: Vector2i) -> Rect2:
	var w: float = size.x / float(COLS)
	var h: float = size.y / float(ROWS)
	return Rect2(Vector2(cell.x * w, cell.y * h) + Vector2(GAP, GAP) * 0.5, Vector2(w, h) - Vector2(GAP, GAP))


func is_cell_found(cell: Vector2i) -> bool:
	for id: String in found:
		var entry: Dictionary = GameState.MAP_FRAGMENTS.get(id, {})
		if not entry.is_empty() and entry["piece"] == cell:
			return true
	return false


func _draw() -> void:
	var to_px: Callable = func(p: Vector2) -> Vector2: return p * size
	for row: int in ROWS:
		for col: int in COLS:
			var cell: Vector2i = Vector2i(col, row)
			var r: Rect2 = piece_rect(cell)
			if is_cell_found(cell):
				draw_rect(r, PARCHMENT)
				draw_rect(r.grow(-4.0), PARCHMENT_DARK.lerp(PARCHMENT, 0.6), false, 1.0)
			else:
				draw_rect(r, MISSING)
				draw_rect(r, MISSING_EDGE, false, 2.0)
				var font: Font = get_theme_default_font()
				var fs: int = int(minf(r.size.y * 0.45, 48.0))
				draw_string(font, r.get_center() + Vector2(-fs * 0.25, fs * 0.35), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, MISSING_EDGE)
	# mar no canto da ilha, só se essa peça estiver à vista
	var island: Vector2 = to_px.call(ROUTE_POINTS[ROUTE_POINTS.size() - 1])
	if _visible_at(island):
		draw_circle(island + Vector2(6.0, 10.0), size.y * 0.13, SEA)
		draw_circle(island, size.y * 0.06, PARCHMENT_DARK)
	# caminho a tracejado: cada traço só aparece se a peça onde está tiver sido encontrada
	for i: int in ROUTE_POINTS.size() - 1:
		var a: Vector2 = to_px.call(ROUTE_POINTS[i])
		var b: Vector2 = to_px.call(ROUTE_POINTS[i + 1])
		var steps: int = maxi(int(a.distance_to(b) / 9.0), 1)
		for k: int in steps:
			if k % 2 == 1:
				continue
			var p0: Vector2 = a.lerp(b, float(k) / float(steps))
			var p1: Vector2 = a.lerp(b, float(k + 1) / float(steps))
			if _visible_at(p0.lerp(p1, 0.5)):
				draw_line(p0, p1, ROUTE, 2.5)
	for idx: int in LANDMARKS:
		var p: Vector2 = to_px.call(ROUTE_POINTS[idx])
		if _visible_at(p):
			draw_circle(p, 5.0, INK)
	if _visible_at(island):
		var s: float = 9.0
		draw_line(island + Vector2(-s, -s), island + Vector2(s, s), ROUTE, 4.0)
		draw_line(island + Vector2(-s, s), island + Vector2(s, -s), ROUTE, 4.0)


func _visible_at(px: Vector2) -> bool:
	var col: int = clampi(int(px.x / (size.x / float(COLS))), 0, COLS - 1)
	var row: int = clampi(int(px.y / (size.y / float(ROWS))), 0, ROWS - 1)
	return is_cell_found(Vector2i(col, row))
