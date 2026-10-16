@tool
class_name CraterTerrain
extends StaticBody3D

## Chão da Cratera (#44): bacia de impacto de meteorito em terreno extraterrestre/vulcânico.
## Malha low-poly facetada (normais e cor por face, toon) com:
##   - depressão de impacto central em (0, 0) com cumes concêntricos;
##   - planalto da estação de pesquisa da Dra. Vega a noroeste (VEGA_CAMP);
##   - crista elevada do Altar do Dorminhoco a sudeste (SLEEPER_CREST);
##   - fendas e veios de energia cósmica esculpidos por ruído procedural;
##   - crista anelar towering nas margens da cratera (perímetro intransponível).
## A colisão é a própria malha (layer 1). height_at() é estático (GroundSnap terrain = Cratera).

const SIZE: Vector2 = Vector2(-46.0, 46.0)
const CELL: float = 1.0
const PLAY_HALF: float = 31.0

# Cores da Cratera alienígena / meteorítica
const BASALT_DARK: Color = Color(0.18, 0.16, 0.22)
const BASALT_PURPLE: Color = Color(0.28, 0.22, 0.34)
const CRATER_DUST: Color = Color(0.38, 0.32, 0.45)
const VIOLET_FISSURE: Color = Color(0.56, 0.30, 0.68)
const METEOR_RUST: Color = Color(0.48, 0.28, 0.20)
const IMPACT_GLASS: Color = Color(0.35, 0.65, 0.72)

## Epicentro da cratera (x, z, raio) e profundidade afundada
const IMPACT_CENTER: Vector2 = Vector2(0.0, 0.0)
const IMPACT_RADIUS: float = 16.0
const IMPACT_DEPTH: float = 1.4

## Zona da estação de pesquisa da Dra. Vega (x, z, raio)
const VEGA_CAMP: Vector3 = Vector3(-14.0, 10.0, 6.0)

## Zonas planas: spawn, base de entrega, estação e altar
const FLAT_ZONES: Array[Vector3] = [
	Vector3(0.0, 0.0, 3.5),
	Vector3(4.0, 4.0, 4.5),
	Vector3(-14.0, 10.0, 5.5),
	Vector3(16.0, -14.0, 6.0)
]

const NOISE_AMP: float = 0.35

static var _noise: FastNoiseLite = null
static var _broad: FastNoiseLite = null

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
		_noise.seed = 4405
		_noise.frequency = 0.065
		_noise.fractal_octaves = 3
	return _noise


static func _get_broad() -> FastNoiseLite:
	if _broad == null:
		_broad = FastNoiseLite.new()
		_broad.seed = 8844
		_broad.frequency = 0.022
		_broad.fractal_octaves = 2
	return _broad


static func crater_weight(x: float, z: float) -> float:
	var d: float = Vector2(x, z).distance_to(IMPACT_CENTER)
	return smoothstep(IMPACT_RADIUS, IMPACT_RADIUS * 0.4, d)


## Altura do solo na posição (x, z) — determinística para colisão e assentamento.
static func height_at(x: float, z: float) -> float:
	var cw: float = crater_weight(x, z)
	var h: float = _get_noise().get_noise_2d(x, z) * NOISE_AMP
	h += (_get_broad().get_noise_2d(x, z) + 0.1) * 0.8

	# Bacia de impacto afundada no centro
	if cw > 0.0:
		h = lerpf(h, -IMPACT_DEPTH, cw * 0.85)

	# Zonas planas (spawn, entrega, acampamento, altar)
	for f: Vector3 in FLAT_ZONES:
		var dist: float = Vector2(x - f.x, z - f.y).length()
		h = lerpf(h, 0.0, smoothstep(f.z, f.z * 0.45, dist))

	# Crista perimétrica towering da cratera (borda de impacto intransponível)
	var edge: float = maxf(absf(x), absf(z))
	var rise: float = smoothstep(PLAY_HALF - 1.0, PLAY_HALF + 10.0, edge)
	h += rise * rise * (8.0 + _get_broad().get_noise_2d(x * 1.6, z * 1.6) * 3.5)
	return h


static func color_at(x: float, z: float, h: float) -> Color:
	var n: float = _get_noise().get_noise_2d(z * 1.8 + 20.0, x * 1.8)
	var c: Color = BASALT_DARK.lerp(BASALT_PURPLE, clampf(0.5 + n * 1.1, 0.0, 1.0))

	# Fissuras violetas e poeira extraterrestre
	if h > 0.3:
		c = c.lerp(CRATER_DUST, clampf((h - 0.3) * 0.6, 0.0, 0.7))
	elif h < -0.4:
		c = c.lerp(VIOLET_FISSURE, clampf((-h - 0.4) * 0.8, 0.0, 0.85))

	var cw: float = crater_weight(x, z)
	if cw > 0.3:
		c = c.lerp(METEOR_RUST, cw * 0.4)

	return c


func rebuild() -> void:
	for c: Node in get_children():
		if c.owner == null:
			c.free()

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var xs: int = int((SIZE.y - SIZE.x) / CELL)
	var zs: int = int((SIZE.y - SIZE.x) / CELL)

	for ix: int in xs:
		var x0: float = SIZE.x + float(ix) * CELL
		var x1: float = x0 + CELL
		for iz: int in zs:
			var z0: float = SIZE.x + float(iz) * CELL
			var z1: float = z0 + CELL

			var y00: float = height_at(x0, z0)
			var y10: float = height_at(x1, z0)
			var y01: float = height_at(x0, z1)
			var y11: float = height_at(x1, z1)

			var v00: Vector3 = Vector3(x0, y00, z0)
			var v10: Vector3 = Vector3(x1, y10, z0)
			var v01: Vector3 = Vector3(x0, y01, z1)
			var v11: Vector3 = Vector3(x1, y11, z1)

			var c1: Color = color_at((x0 + x1 + x0) / 3.0, (z0 + z0 + z1) / 3.0, (y00 + y10 + y01) / 3.0)
			var inside1: Vector3 = (v00 + v10 + v01) / 3.0 + Vector3.DOWN
			LowPolyMesh.tri(st, v00, v10, v01, inside1, c1)

			var c2: Color = color_at((x1 + x1 + x0) / 3.0, (z0 + z1 + z1) / 3.0, (y10 + y11 + y01) / 3.0)
			var inside2: Vector3 = (v10 + v11 + v01) / 3.0 + Vector3.DOWN
			LowPolyMesh.tri(st, v10, v11, v01, inside2, c2)

	var mesh: ArrayMesh = ToonKit.commit(st)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	mi.material_override = ToonKit.vertex_material(true, true)
	add_child(mi)

	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "Collision"
	col.shape = mesh.create_trimesh_shape()
	add_child(col)
