@tool
class_name FieldTerrain
extends StaticBody3D

## Chão do Campo Antigo: malha low-poly facetada (normais e cor por face), prado ondulado
## com um caminho de terra batida, uma lavoura antiga em sulcos e colinas que sobem para
## lá das paredes (fecham o horizonte). A colisão é a mesma malha (layer 1), para o
## raycast do SpotSpawner e dos jogadores. `height_at()` é estático: a relva (GrassField)
## e o GroundSnap usam-no com `terrain = Campo`.

const SIZE: Vector2 = Vector2(-46.0, 46.0)
const CELL: float = 1.0
## Até aqui o chão é jogável (paredes em ±30.5); depois sobe em colinas.
const PLAY_HALF: float = 31.0

const MEADOW: Color = Color(0.4, 0.53, 0.2)
const MEADOW_DRY: Color = Color(0.6, 0.6, 0.27)
const DIRT: Color = Color(0.5, 0.37, 0.22)
const SOIL: Color = Color(0.34, 0.23, 0.14)
const SOIL_RIDGE: Color = Color(0.44, 0.31, 0.19)
const HILL: Color = Color(0.36, 0.5, 0.24)

## Zonas planas (x, z, raio): spawn, base de entrega, círculo de pedras.
const FLAT_ZONES: Array[Vector3] = [
	Vector3(0.0, 0.0, 3.5), Vector3(3.5, 3.5, 4.0), Vector3(-18.0, -18.0, 8.0),
]
## Caminho de terra (polilinha x, z) da base até ao círculo de pedras e à saída norte.
const PATH: Array[Vector2] = [
	Vector2(3.5, 3.5), Vector2(-2.0, -3.0), Vector2(-8.0, -8.5), Vector2(-14.0, -14.0),
	Vector2(-18.0, -18.0), Vector2(-14.0, -24.0), Vector2(-9.0, -31.0),
]
const PATH_WIDTH: float = 1.3
## Lavoura antiga: retângulo (x0, z0, x1, z1) com sulcos ao longo de X.
const FIELD_RECT: Rect2 = Rect2(10.0, -25.0, 15.0, 16.0)
const FURROW_PERIOD: float = 2.0
const FURROW_DEPTH: float = 0.09
const NOISE_AMP: float = 0.22
const HILL_AMP: float = 0.9

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
		_noise.seed = 1717
		_noise.frequency = 0.08
		_noise.fractal_octaves = 3
	return _noise


static func _get_broad() -> FastNoiseLite:
	if _broad == null:
		_broad = FastNoiseLite.new()
		_broad.seed = 909
		_broad.frequency = 0.025
		_broad.fractal_octaves = 2
	return _broad


## Distância de (x, z) ao caminho de terra.
static func path_distance(x: float, z: float) -> float:
	var p: Vector2 = Vector2(x, z)
	var best: float = INF
	for i: int in PATH.size() - 1:
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(p, PATH[i], PATH[i + 1])
		best = minf(best, p.distance_to(closest))
	return best


static func _field_weight(x: float, z: float) -> float:
	# 1 dentro da lavoura, a cair para 0 numa margem de 1 m
	var inside_x: float = minf(x - FIELD_RECT.position.x, FIELD_RECT.end.x - x)
	var inside_z: float = minf(z - FIELD_RECT.position.y, FIELD_RECT.end.y - z)
	return clampf(minf(inside_x, inside_z), 0.0, 1.0)


## Altura do chão em (x, z) — determinística.
static func height_at(x: float, z: float) -> float:
	var h: float = _get_noise().get_noise_2d(x, z) * NOISE_AMP
	h += (_get_broad().get_noise_2d(x, z) + 0.3) * HILL_AMP
	var fw: float = _field_weight(x, z)
	if fw > 0.0:
		# lavoura: chão quase plano com sulcos (onda triangular suave)
		var phase: float = fposmod(z, FURROW_PERIOD) / FURROW_PERIOD
		var furrow: float = (absf(phase - 0.5) * 2.0 - 0.5) * FURROW_DEPTH * 2.0
		h = lerpf(h, h * 0.3 + furrow, fw)
	var pd: float = path_distance(x, z)
	h -= smoothstep(PATH_WIDTH * 1.6, PATH_WIDTH * 0.5, pd) * 0.06
	for f: Vector3 in FLAT_ZONES:
		var dist: float = Vector2(x - f.x, z - f.y).length()
		var k: float = smoothstep(f.z, f.z * 0.6, dist)  # 1 no centro, 0 fora
		h = lerpf(h, 0.0, k)
	# colinas para lá das paredes: o vale fecha-se à volta do jogador
	var edge: float = maxf(absf(x), absf(z))
	var rise: float = smoothstep(PLAY_HALF - 1.0, SIZE.y, edge)
	h += rise * rise * (5.5 + _get_broad().get_noise_2d(x * 2.0, z * 2.0) * 3.0)
	return h


static func color_at(x: float, z: float, h: float) -> Color:
	var n: float = _get_noise().get_noise_2d(z * 1.6 + 40.0, x * 1.6)
	var c: Color = MEADOW.lerp(MEADOW_DRY, clampf(0.45 + n * 1.4, 0.0, 1.0))
	var fw: float = _field_weight(x, z)
	if fw > 0.0:
		var ridge: bool = fposmod(z, FURROW_PERIOD) / FURROW_PERIOD > 0.5
		c = c.lerp(SOIL_RIDGE if ridge else SOIL, fw)
	var pd: float = path_distance(x, z)
	c = c.lerp(DIRT, smoothstep(PATH_WIDTH * 1.2, PATH_WIDTH * 0.4, pd + n * 0.5))
	var edge: float = maxf(absf(x), absf(z))
	if edge > PLAY_HALF:
		c = c.lerp(HILL, clampf((edge - PLAY_HALF) / 6.0, 0.0, 1.0))
	return c.darkened(clampf(-h * 0.15, 0.0, 0.15))


func rebuild() -> void:
	for child: Node in get_children():
		child.free()
	collision_layer = 1
	collision_mask = 0

	var cells: int = int((SIZE.y - SIZE.x) / CELL)
	var pts: Array[PackedVector3Array] = []
	for i: int in cells + 1:
		var row: PackedVector3Array = PackedVector3Array()
		for j: int in cells + 1:
			var x: float = SIZE.x + i * CELL
			var z: float = SIZE.x + j * CELL
			# pequena irregularidade na grelha para não parecer quadriculado
			if i > 0 and i < cells and j > 0 and j < cells:
				x += _get_noise().get_noise_2d(i * 13.0, j * 7.0) * 0.3
				z += _get_noise().get_noise_2d(j * 11.0, i * 5.0) * 0.3
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

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.95
	mat.metallic_specular = 0.12
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)

	var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.name = "Collision"
	cs.shape = shape
	add_child(cs)


## Emite a face com a frente para cima e devolve os vértices na ordem emitida.
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
