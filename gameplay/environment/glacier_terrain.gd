@tool
class_name GlacierTerrain
extends StaticBody3D

## Chão da Geleira Eterna (#43): planalto ártico de gelo milenar e neve compacta.
## Malha low-poly facetada (normais e cor por face, toon) com:
##   - lago gelado afundado a este (FROZEN_LAKE), onde repousa o gelo fino e a Morsa Anciã;
##   - planalto da cabana do Velho Björn a oeste (BJORN_CAMP);
##   - fendas e cumes glaciais esculpidos por ruído procedural;
##   - paredões de gelo e icebergs nas margens (perímetro intransponível).
## A colisão é a própria malha (layer 1). height_at() é estático (GroundSnap terrain = Geleira).

const SIZE: Vector2 = Vector2(-46.0, 46.0)
const CELL: float = 1.0
const PLAY_HALF: float = 31.0

# Cores da Geleira Eterna
const SNOW_WHITE: Color = Color(0.93, 0.96, 0.99)
const SNOW_SHADE: Color = Color(0.82, 0.88, 0.94)
const ICE_GLACIAL: Color = Color(0.52, 0.76, 0.88)
const ICE_DEEP: Color = Color(0.36, 0.62, 0.78)
const ICE_LAKE: Color = Color(0.42, 0.72, 0.86)
const MORAINE_ROCK: Color = Color(0.46, 0.48, 0.52)
const FROST_RIM: Color = Color(0.75, 0.86, 0.95)

## Lago gelado (x, z, raio) e profundidade afundada
const LAKE_CENTER: Vector2 = Vector2(14.0, -8.0)
const LAKE_RADIUS: float = 8.5
const LAKE_DEPTH: float = 0.65

## Zona do acampamento e cabana do Velho Björn (x, z, raio)
const BJORN_CAMP: Vector3 = Vector3(-14.0, 8.0, 6.0)

## Zonas planas: spawn do jogador e base de entrega
const FLAT_ZONES: Array[Vector3] = [
	Vector3(0.0, 0.0, 3.5),
	Vector3(3.5, 3.5, 4.0),
	Vector3(-14.0, 8.0, 5.0),
	# Banca (balcão e ofertas a y fixo) e altar do chefe com a arena à volta
	Vector3(8.5, 6.0, 8.0),
	Vector3(18.0, 18.0, 8.0)
]

const NOISE_AMP: float = 0.28
## Relevo (estudo How to Fish): amplitude da ondulação larga (m), raio de acalmia à volta das
## zonas planas (m) e semente do ruído.
const RELIEF_AMP: float = 1.6
const RELIEF_CALM: float = 6.0
const RELIEF_SEED: int = 4343

static var _noise: FastNoiseLite = null
static var _broad: FastNoiseLite = null
static var _relief: FastNoiseLite = null

@export var rebuild_now: bool = false:
	set(value):
		rebuild_now = false
		if is_inside_tree():
			rebuild()


func _ready() -> void:
	rebuild()


static func _get_noise() -> FastNoiseLite:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = 9021
		_noise.frequency = 0.07
		_noise.fractal_octaves = 3
	return _noise


static func _get_broad() -> FastNoiseLite:
	if _broad == null:
		_broad = FastNoiseLite.new()
		_broad.seed = 1337
		_broad.frequency = 0.025
		_broad.fractal_octaves = 2
	return _broad


static func lake_weight(x: float, z: float) -> float:
	var d: float = Vector2(x, z).distance_to(LAKE_CENTER)
	return smoothstep(LAKE_RADIUS, LAKE_RADIUS - 2.0, d)


## Altura do solo na posição (x, z) — determinística para colisão e assentamento.
## Ondulação larga do chão (estudo How to Fish: ilhas com colinas), ±~1 m. Acalma-se até zero
## nas FLAT_ZONES e RELIEF_CALM m à volta delas (spawn, base, Banca, acampamentos, altares),
## para nada do que lá está assente ficar a flutuar ou enterrado.
static func relief_at(x: float, z: float) -> float:
	var r: float = _get_relief().get_noise_2d(x, z) * RELIEF_AMP
	for f: Vector3 in FLAT_ZONES:
		var dist: float = Vector2(x - f.x, z - f.y).length()
		r *= smoothstep(f.z, f.z + RELIEF_CALM, dist)
	return r


static func _get_relief() -> FastNoiseLite:
	if _relief == null:
		_relief = FastNoiseLite.new()
		_relief.seed = RELIEF_SEED
		_relief.frequency = 0.035
		_relief.fractal_octaves = 2
	return _relief


static func height_at(x: float, z: float) -> float:
	var lw: float = lake_weight(x, z)
	var h: float = _get_noise().get_noise_2d(x, z) * NOISE_AMP * (1.0 - lw * 0.9)
	h += (_get_broad().get_noise_2d(x, z) + 0.15) * 0.7 * (1.0 - lw * 0.8)
	# vai a zero até à margem do lago (sem degrau à volta do gelo)
	h += relief_at(x, z) * smoothstep(LAKE_RADIUS, LAKE_RADIUS + RELIEF_CALM, Vector2(x, z).distance_to(LAKE_CENTER))

	# Bacia do lago congelado (superfície plana e ligeiramente côncava)
	if lw > 0.0:
		h = lerpf(h, -LAKE_DEPTH, lw)

	# Zonas planas (spawn, entrega, acampamento)
	for f: Vector3 in FLAT_ZONES:
		var dist: float = Vector2(x - f.x, z - f.y).length()
		h = lerpf(h, 0.0, smoothstep(f.z, f.z * 0.5, dist))

	# Paredões de gelo towering / encostas das margens
	var edge: float = maxf(absf(x), absf(z))
	var rise: float = smoothstep(PLAY_HALF - 1.0, SIZE.y, edge)
	h += rise * rise * (7.5 + _get_broad().get_noise_2d(x * 1.8, z * 1.8) * 3.5)
	return h


static func color_at(x: float, z: float, h: float) -> Color:
	var n: float = _get_noise().get_noise_2d(z * 2.0 + 40.0, x * 2.0)
	var c: Color = SNOW_WHITE.lerp(SNOW_SHADE, clampf(0.5 + n * 1.2, 0.0, 1.0))

	# Gelo profundo do lago
	var lw: float = lake_weight(x, z)
	if lw > 0.0:
		var lake_c: Color = ICE_LAKE.lerp(ICE_DEEP, clampf((1.0 - lw) * 0.8, 0.0, 1.0))
		c = c.lerp(lake_c, lw)

	# Manchas de morena/rocha congelada
	if n > 0.32 and lw < 0.2:
		c = c.lerp(MORAINE_ROCK, clampf((n - 0.32) * 2.5, 0.0, 0.85))

	# Paredões externos de gelo azul
	var edge: float = maxf(absf(x), absf(z))
	if edge > PLAY_HALF - 2.0:
		var edge_k: float = clampf((edge - (PLAY_HALF - 2.0)) / 8.0, 0.0, 1.0)
		c = c.lerp(ICE_GLACIAL, edge_k * 0.75)

	return c.darkened(clampf(-h * 0.08, 0.0, 0.2))


func rebuild() -> void:
	for child: Node in get_children():
		if child.owner == null:
			child.free()
	if not Engine.is_editor_hint():
		collision_layer = 1
		collision_mask = 0

	var cells: int = int((SIZE.y - SIZE.x) / CELL)
	var pts: Array[PackedVector3Array] = []
	for i: int in cells + 1:
		var row: PackedVector3Array = PackedVector3Array()
		for j: int in cells + 1:
			var x: float = SIZE.x + i * CELL
			var z: float = SIZE.x + j * CELL
			row.append(Vector3(x, height_at(x, z), z))
		pts.append(row)

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces: PackedVector3Array = PackedVector3Array()
	for i: int in cells:
		for j: int in cells:
			var a: Vector3 = pts[i][j]
			var b: Vector3 = pts[i + 1][j]
			var c: Vector3 = pts[i + 1][j + 1]
			var d: Vector3 = pts[i][j + 1]
			var tris: Array = [[a, d, c], [a, c, b]] if (i + j) % 2 == 0 else [[a, d, b], [b, d, c]]
			for t: Array in tris:
				faces.append_array(_face(st, t[0], t[1], t[2]))

	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = st.commit()
	mi.material_override = ToonKit.material(&"terrain")
	add_child(mi)

	var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.name = "Collision"
	cs.shape = shape
	add_child(cs)


func _face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> PackedVector3Array:
	var n: Vector3 = (b - a).cross(c - a).normalized()
	if n.y < 0.0:
		var tmp: Vector3 = b
		b = c
		c = tmp
		n = -n
	var center: Vector3 = (a + b + c) / 3.0
	var col: Color = color_at(center.x, center.z, center.y)
	for v: Vector3 in [a, c, b]:
		st.set_color(col)
		st.set_normal(n)
		st.add_vertex(v)
	return PackedVector3Array([a, c, b])
