@tool
class_name FenceLine
extends Node3D

## Cerca de madeira velha ao longo de uma polilinha (x, z em coordenadas do mundo), assente
## no chão do Campo (FieldTerrain.height_at). Postes facetados e duas travessas; alguns
## postes tortos e travessas em falta para parecer abandonada. Só visual: a colisão dos
## limites do mapa é feita pelas paredes de Bounds.

const WOOD: Color = Color(0.45, 0.34, 0.22)
const WOOD_DARK: Color = Color(0.32, 0.24, 0.16)
const POST_HEIGHT: float = 1.05
const POST_HALF: float = 0.07
const RAIL_HALF: float = 0.035

@export var points: PackedVector2Array = PackedVector2Array():
	set(v):
		points = v
		_queue()
@export var closed: bool = true:
	set(v):
		closed = v
		_queue()
@export var spacing: float = 2.6:
	set(v):
		spacing = v
		_queue()
## Fração de travessas que faltam (cerca degradada).
@export_range(0.0, 1.0) var missing_rails: float = 0.15:
	set(v):
		missing_rails = v
		_queue()
@export var seed_value: int = 3:
	set(v):
		seed_value = v
		_queue()

var _queued: bool = false


func _ready() -> void:
	rebuild()


func _queue() -> void:
	if is_inside_tree() and not _queued:
		_queued = true
		rebuild.call_deferred()


func rebuild() -> void:
	_queued = false
	for c: Node in get_children():
		c.free()
	if points.size() < 2:
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var posts: Array[Vector3] = []
	var tops: Array[Vector3] = []
	var count: int = points.size() if closed else points.size() - 1
	for i: int in count:
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % points.size()]
		var n: int = maxi(1, int(round(a.distance_to(b) / spacing)))
		for k: int in n:
			var p: Vector2 = a.lerp(b, float(k) / float(n))
			var base: Vector3 = Vector3(p.x, FieldTerrain.height_at(p.x, p.y) - 0.05, p.y)
			var tilt: Vector3 = Vector3(rng.randf_range(-0.12, 0.12), 0.0, rng.randf_range(-0.12, 0.12))
			if rng.randf() < 0.12:
				tilt *= 2.5
			var top: Vector3 = base + Vector3.UP * POST_HEIGHT * rng.randf_range(0.9, 1.08) + tilt
			posts.append(base)
			tops.append(top)
			_beam(st, base, top, POST_HALF, WOOD_DARK if rng.randf() < 0.4 else WOOD)
	for i: int in posts.size():
		if not closed and i == posts.size() - 1:
			break
		var j: int = (i + 1) % posts.size()
		for h: float in [0.45, 0.85]:
			if rng.randf() < missing_rails:
				continue
			var a: Vector3 = posts[i].lerp(tops[i], h)
			var b: Vector3 = posts[j].lerp(tops[j], h) + Vector3.UP * rng.randf_range(-0.06, 0.06)
			_beam(st, a, b, RAIL_HALF, WOOD)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.95
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)


## Prisma quadrado de `from` a `to` (secção 2*half).
func _beam(st: SurfaceTool, from: Vector3, to: Vector3, half: float, col: Color) -> void:
	var axis: Vector3 = (to - from).normalized()
	var ref: Vector3 = Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT
	var u: Vector3 = axis.cross(ref).normalized() * half
	var v: Vector3 = axis.cross(u).normalized() * half
	var corners: Array[Vector3] = [u + v, u - v, -u - v, -u + v]
	var mid: Vector3 = (from + to) * 0.5
	for k: int in 4:
		var c0: Vector3 = corners[k]
		var c1: Vector3 = corners[(k + 1) % 4]
		var shade: Color = col.darkened(0.12 * float(k % 2))
		_tri(st, from + c0, to + c0, to + c1, shade, mid)
		_tri(st, from + c0, to + c1, from + c1, shade, mid)
	_tri(st, to + corners[0], to + corners[1], to + corners[2], col, mid)
	_tri(st, to + corners[0], to + corners[2], to + corners[3], col, mid)


## Triângulo com normal por face, virada para fora de `inside`.
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color, inside: Vector3) -> void:
	var n: Vector3 = (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	if n.dot((a + b + c) / 3.0 - inside) < 0.0:
		var tmp: Vector3 = b
		b = c
		c = tmp
		n = -n
	# Godot usa ordem horária para a face da frente: com n para fora, inverte.
	for p: Vector3 in [a, c, b]:
		st.set_color(col)
		st.set_normal(n)
		st.add_vertex(p)
