@tool
class_name IslandTerrain
extends StaticBody3D

## Chão da Ilha do Tesouro (#113): ilha compacta e irregular cercada de mar. Areia clara na
## orla, a mergulhar no mar a partir de SHORE_RADIUS; selva verde no interior; o Monte do
## Tesouro (colina de terra escura com um planalto onde fica o tesouro principal, #114) a
## noroeste. Malha facetada com colisão igual (layer 1), como os outros mapas. `height_at()` é
## estático para a relva, o GroundSnap e o layout assentarem sem raycasts.

const HALF: float = 34.0
const CELL: float = 1.0
## Raio médio da linha de água e quanto varia com o ângulo (enseadas e pontas).
const SHORE_RADIUS: float = 22.0
const SHORE_WOBBLE: float = 3.0
const SEA_FLOOR: float = -1.8
const NOISE_AMP: float = 0.22
## Monte do Tesouro: centro, raio, altura e planalto (raio plano no topo).
const HILL: Vector3 = Vector3(-8.0, 0.0, -9.0)
const HILL_RADIUS: float = 9.5
const HILL_HEIGHT: float = 2.6
const HILL_PLATEAU: float = 3.2
## Zonas planas (x, z, raio): chegada, base de entrega, banca e cais.
const FLAT_ZONES: Array[Vector3] = [
	Vector3(0.0, 0.0, 3.5), Vector3(3.5, 3.5, 4.0), Vector3(8.5, 6.0, 3.5), Vector3(17.0, 2.0, 3.0),
]

const SAND: Color = Color(0.93, 0.82, 0.6)
const SAND_ALT: Color = Color(0.86, 0.74, 0.52)
const SAND_WET: Color = Color(0.62, 0.52, 0.36)
const SEABED: Color = Color(0.36, 0.52, 0.5)
const JUNGLE: Color = Color(0.34, 0.6, 0.28)
const JUNGLE_ALT: Color = Color(0.28, 0.5, 0.24)
const HILL_SOIL: Color = Color(0.5, 0.38, 0.26)

static var _noise: FastNoiseLite = null

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
		_noise.seed = 1130
		_noise.frequency = 0.08
		_noise.fractal_octaves = 3
	return _noise


## Raio da linha de água na direção de (x, z).
static func shore_radius_at(x: float, z: float) -> float:
	var a: float = atan2(z, x)
	return SHORE_RADIUS + _get_noise().get_noise_2d(cos(a) * 40.0, sin(a) * 40.0) * SHORE_WOBBLE * 2.0


## 0 no mar, 1 bem dentro da ilha.
static func land_weight(x: float, z: float) -> float:
	var r: float = Vector2(x, z).length()
	return smoothstep(shore_radius_at(x, z) + 1.5, shore_radius_at(x, z) - 3.0, r)


static func hill_weight(x: float, z: float) -> float:
	var d: float = Vector2(x - HILL.x, z - HILL.z).length()
	return smoothstep(HILL_RADIUS, HILL_PLATEAU, d)


## Altura do chão em (x, z) — determinística.
static func height_at(x: float, z: float) -> float:
	var r: float = Vector2(x, z).length()
	var edge: float = shore_radius_at(x, z)
	var h: float = _get_noise().get_noise_2d(x, z) * NOISE_AMP * land_weight(x, z)
	h += hill_weight(x, z) * HILL_HEIGHT
	for f: Vector3 in FLAT_ZONES:
		var k: float = smoothstep(f.z, f.z * 0.6, Vector2(x - f.x, z - f.y).length())
		h = lerpf(h, 0.0, k)
	if r > edge - 2.0:
		# orla a mergulhar no mar
		var s: float = r - (edge - 2.0)
		h -= s * s * 0.06
		h = maxf(h, SEA_FLOOR)
	return h


static func color_at(x: float, z: float, h: float) -> Color:
	var n: float = _get_noise().get_noise_2d(z * 1.9 + 50.0, x * 1.9)
	var sand: Color = SAND.lerp(SAND_ALT, clampf(0.5 + n, 0.0, 1.0))
	var jungle: Color = JUNGLE.lerp(JUNGLE_ALT, clampf(0.5 + n, 0.0, 1.0))
	var r: float = Vector2(x, z).length()
	var inland: float = smoothstep(shore_radius_at(x, z) - 4.0, shore_radius_at(x, z) - 9.0, r)
	var c: Color = sand.lerp(jungle, inland)
	c = c.lerp(HILL_SOIL, hill_weight(x, z) * 0.85)
	# a chegada e a base ficam em areia batida
	for f: Vector3 in FLAT_ZONES:
		c = c.lerp(sand, smoothstep(f.z + 1.0, f.z * 0.5, Vector2(x - f.x, z - f.y).length()) * 0.8)
	if h < 0.05:
		c = c.lerp(SAND_WET, clampf((0.05 - h) * 3.0, 0.0, 1.0))
	if h < -0.4:
		c = c.lerp(SEABED, clampf((-0.4 - h) * 1.2, 0.0, 1.0))
	return c


func rebuild() -> void:
	# #47: só os filhos gerados (sem owner); os que estão gravados na cena ficam.
	for child: Node in get_children():
		if child.owner == null:
			child.free()
	if not Engine.is_editor_hint():
		collision_layer = 1
		collision_mask = 0
	var n: int = int(HALF * 2.0 / CELL)
	var pts: Array[PackedVector3Array] = []
	for i: int in n + 1:
		var row: PackedVector3Array = PackedVector3Array()
		for j: int in n + 1:
			var x: float = -HALF + i * CELL
			var z: float = -HALF + j * CELL
			if i > 0 and i < n and j > 0 and j < n:
				x += _get_noise().get_noise_2d(i * 13.0, j * 7.0) * 0.3
				z += _get_noise().get_noise_2d(j * 11.0, i * 5.0) * 0.3
			row.append(Vector3(x, height_at(x, z), z))
		pts.append(row)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces: PackedVector3Array = PackedVector3Array()
	for i: int in n:
		for j: int in n:
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
	var nrm: Vector3 = (b - a).cross(c - a).normalized()
	if nrm.y < 0.0:
		var tmp: Vector3 = b
		b = c
		c = tmp
		nrm = -nrm
	var center: Vector3 = (a + b + c) / 3.0
	var col: Color = color_at(center.x, center.z, center.y)
	for v: Vector3 in [a, c, b]:
		st.set_color(col)
		st.set_normal(nrm)
		st.add_vertex(v)
	return PackedVector3Array([a, c, b])
