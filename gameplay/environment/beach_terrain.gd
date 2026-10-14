@tool
class_name BeachTerrain
extends StaticBody3D

## Chão da Praia: malha low-poly facetada gerada por script (normais e cor por face),
## com relevo suave, dunas e a praia a descer para o mar (+X). A colisão é a mesma malha
## (ConcavePolygonShape3D, layer 1) para o raycast do SpotSpawner e dos jogadores.
## `height_at()` é estático: a relva (GrassField) e outros scripts usam-no para assentar
## no chão sem raycasts.

const SIZE_X: Vector2 = Vector2(-31.0, 38.0)  # vai para lá da parede leste (x=30.5), sob o mar
const SIZE_Z: Vector2 = Vector2(-31.0, 31.0)
const CELL: float = 1.0

const SAND_DRY: Color = Color(0.86, 0.74, 0.55)
const SAND_DRY_ALT: Color = Color(0.78, 0.66, 0.48)
const SAND_WET: Color = Color(0.58, 0.47, 0.33)
const SAND_UNDERWATER: Color = Color(0.42, 0.4, 0.32)

## Zonas planas (x, z, raio): spawn, base de entrega, banca e arena do chefe.
const FLAT_ZONES: Array[Vector3] = [
	Vector3(0.0, 0.0, 3.5), Vector3(3.5, 3.5, 4.0), Vector3(7.0, 0.5, 3.5), Vector3(-22.0, -22.0, 9.0),
]
## Dunas (x, z, raio_maior, raio_menor, ângulo°, altura) — as mesmas posições das antigas CSG.
const DUNES: Array = [
	[-14.0, -12.0, 6.5, 3.8, 30.0, 0.75], [-18.0, 10.0, 5.5, 4.2, -50.0, 0.7], [6.0, 18.0, 7.5, 3.2, 80.0, 0.65],
	[-26.0, 2.0, 4.0, 6.0, 10.0, 0.9], [16.0, -22.0, 5.0, 3.0, 25.0, 0.55],
]
const SHORE_START_X: float = 25.0
const NOISE_AMP: float = 0.2

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
		_noise.seed = 4242
		_noise.frequency = 0.07
		_noise.fractal_octaves = 3
	return _noise


## Altura do chão em (x, z) — determinística.
static func height_at(x: float, z: float) -> float:
	var h: float = _get_noise().get_noise_2d(x, z) * NOISE_AMP
	for d: Array in DUNES:
		var a: float = deg_to_rad(d[4])
		var dx: float = x - d[0]
		var dz: float = z - d[1]
		var u: float = (dx * cos(a) + dz * sin(a)) / d[2]
		var v: float = (-dx * sin(a) + dz * cos(a)) / d[3]
		h += d[5] * exp(-(u * u + v * v) * 1.6)
	for f: Vector3 in FLAT_ZONES:
		var dist: float = Vector2(x - f.x, z - f.y).length()
		var k: float = smoothstep(f.z, f.z * 0.6, dist)  # 1 no centro, 0 fora
		h = lerpf(h, 0.0, k)
	if x > SHORE_START_X:
		# praia a mergulhar no mar: ~-0.6 em x=30, ~-1.6 em x=36
		var s: float = x - SHORE_START_X
		h -= s * s * 0.024 + s * 0.0
		h = maxf(h, -1.8)
	return h


static func color_at(x: float, z: float, h: float) -> Color:
	var n: float = _get_noise().get_noise_2d(z * 1.7 + 30.0, x * 1.7)
	var c: Color = SAND_DRY.lerp(SAND_DRY_ALT, clampf(0.5 + n, 0.0, 1.0))
	# areia molhada junto ao mar e por baixo de água
	var wet: float = smoothstep(SHORE_START_X - 1.0, SHORE_START_X + 2.5, x)
	c = c.lerp(SAND_WET, wet)
	if h < -0.15:
		c = c.lerp(SAND_UNDERWATER, clampf((-0.15 - h) * 1.5, 0.0, 1.0))
	return c


func rebuild() -> void:
	for child: Node in get_children():
		child.free()
	collision_layer = 1
	collision_mask = 0

	var nx: int = int((SIZE_X.y - SIZE_X.x) / CELL)
	var nz: int = int((SIZE_Z.y - SIZE_Z.x) / CELL)
	var pts: Array[PackedVector3Array] = []
	for i: int in nx + 1:
		var row: PackedVector3Array = PackedVector3Array()
		for j: int in nz + 1:
			var x: float = SIZE_X.x + i * CELL
			var z: float = SIZE_Z.x + j * CELL
			# pequena irregularidade na grelha para não parecer quadriculado
			if i > 0 and i < nx and j > 0 and j < nz:
				x += _get_noise().get_noise_2d(i * 13.0, j * 7.0) * 0.3
				z += _get_noise().get_noise_2d(j * 11.0, i * 5.0) * 0.3
			row.append(Vector3(x, height_at(x, z), z))
		pts.append(row)

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces: PackedVector3Array = PackedVector3Array()
	for i: int in nx:
		for j: int in nz:
			var a: Vector3 = pts[i][j]
			var b: Vector3 = pts[i + 1][j]
			var c: Vector3 = pts[i + 1][j + 1]
			var d: Vector3 = pts[i][j + 1]
			# alterna a diagonal para facetas mais orgânicas
			var tris: Array = [[a, d, c], [a, c, b]] if (i + j) % 2 == 0 else [[a, d, b], [b, d, c]]
			for t: Array in tris:
				# a mesma ordem (frente para cima) serve a malha e a colisão
				faces.append_array(_face(st, t[0], t[1], t[2]))

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.95
	mat.metallic_specular = 0.15
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
	# Godot usa ordem horária para a face da frente: com n para cima, inverte.
	for v: Vector3 in [a, c, b]:
		st.set_color(col)
		st.set_normal(n)
		st.add_vertex(v)
	return PackedVector3Array([a, c, b])
