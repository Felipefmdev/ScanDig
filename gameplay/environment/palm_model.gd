@tool
class_name PalmModel
extends Node3D

## Palmeira low-poly "cheia" (estilo How to Fish): tronco em anéis facetados com curva suave
## e copa com muitas folhas compridas e caídas, cada uma com folíolos em dentes de serra
## (dois tons de verde). Gerada por SurfaceTool, normais por face, cores por vértice.
## A base do tronco fica na origem; +Y = cima; a curva inclina o tronco para +X local.

const TRUNK: Color = Color(0.45, 0.24, 0.16)
const TRUNK_RING: Color = Color(0.32, 0.17, 0.11)
const LEAF_DARK: Color = Color(0.13, 0.36, 0.07)
const LEAF_LIGHT: Color = Color(0.36, 0.6, 0.12)

@export var height: float = 5.5:
	set(v):
		height = v
		_queue()
@export_range(0.0, 2.5) var bend: float = 0.9:
	set(v):
		bend = v
		_queue()
@export var fronds: int = 14:
	set(v):
		fronds = v
		_queue()
@export var frond_length: float = 2.6:
	set(v):
		frond_length = v
		_queue()
@export var seed_value: int = 1:
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
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	# Tronco (peça fechada, contorno normal) e folhas (cartões de dupla face, contorno de cartão)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fst: SurfaceTool = SurfaceTool.new()
	fst.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Tronco: segmentos (anéis) ao longo de uma curva quadrática.
	var segs: int = 9
	var top: Vector3 = Vector3.ZERO
	for i: int in segs:
		var t0: float = float(i) / segs
		var t1: float = float(i + 1) / segs
		var p0: Vector3 = _trunk_point(t0)
		var p1: Vector3 = _trunk_point(t1)
		var r0: float = lerpf(0.34, 0.2, t0)
		var r1: float = lerpf(0.34, 0.2, t1)
		_prism(st, p0, p1 - (p1 - p0) * 0.12, r0 * 1.08, r1, 7, TRUNK)
		_prism(st, p1 - (p1 - p0) * 0.12, p1, r1, r1 * 1.12, 7, TRUNK_RING)
		top = p1

	# Copa: folhas a sair do topo, arqueadas e a cair.
	for f: int in fronds:
		var yaw: float = TAU * float(f) / float(fronds) + rng.randf_range(-0.2, 0.2)
		var up_tilt: float = rng.randf_range(0.15, 0.55)
		var length: float = frond_length * rng.randf_range(0.8, 1.1)
		_frond(fst, top, yaw, up_tilt, length, rng)
	# coco/centro da copa
	_prism(st, top + Vector3(0, -0.1, 0), top + Vector3(0, 0.15, 0), 0.2, 0.08, 6, LEAF_DARK)

	# Toon + contorno preto (#36)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = ToonKit.commit(st)
	mi.material_override = ToonKit.vertex_material()
	add_child(mi)
	var fronds_mi: MeshInstance3D = MeshInstance3D.new()
	fronds_mi.name = "Fronds"
	fronds_mi.mesh = ToonKit.commit(fst, true)
	fronds_mi.material_override = ToonKit.material(&"foliage")
	add_child(fronds_mi)


func _trunk_point(t: float) -> Vector3:
	return Vector3(bend * t * t, height * t, 0.0)


## Folha: espinha curva (sobe e cai) com folíolos triangulares dos dois lados.
func _frond(st: SurfaceTool, origin: Vector3, yaw: float, up_tilt: float, length: float, rng: RandomNumberGenerator) -> void:
	var dir: Vector3 = Vector3(cos(yaw), 0.0, sin(yaw))
	var side: Vector3 = Vector3(-dir.z, 0.0, dir.x)
	var steps: int = 7
	var prev: Vector3 = origin
	for s: int in steps:
		var t: float = float(s + 1) / steps
		# arco: sobe no início e cai no fim
		var p: Vector3 = origin + dir * length * t + Vector3.UP * (up_tilt * length * t - length * 0.75 * t * t)
		var w: float = length * 0.36 * sin(PI * clampf(t * 0.9 + 0.1, 0.0, 1.0))
		var droop: Vector3 = Vector3.DOWN * w * 0.45
		var col: Color = LEAF_DARK.lerp(LEAF_LIGHT, rng.randf_range(0.3, 1.0))
		var col2: Color = LEAF_DARK.lerp(LEAF_LIGHT, rng.randf_range(0.0, 0.6))
		# folíolo esquerdo e direito (dente de serra a apontar para a ponta)
		_tri(st, prev, p, p - dir * length * 0.06 + side * w + droop, col)
		_tri(st, prev, p, p - dir * length * 0.06 - side * w + droop, col2)
		prev = p


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var n: Vector3 = (b - a).cross(c - a).normalized()
	if n.y < 0.0:
		n = -n
	for v: Vector3 in [a, b, c]:
		st.set_color(color)
		st.set_normal(n)
		st.add_vertex(v)


func _prism(st: SurfaceTool, p0: Vector3, p1: Vector3, r0: float, r1: float, sides: int, color: Color) -> void:
	var axis: Vector3 = p1 - p0
	if axis.length_squared() < 1e-10:
		return
	var n: Vector3 = axis.normalized()
	var ref: Vector3 = Vector3.FORWARD if absf(n.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var u: Vector3 = n.cross(ref).normalized()
	var v: Vector3 = n.cross(u).normalized()
	var mid: Vector3 = (p0 + p1) * 0.5
	for i: int in sides:
		var a0: float = TAU * float(i) / sides
		var a1: float = TAU * float(i + 1) / sides
		var o0: Vector3 = u * cos(a0) + v * sin(a0)
		var o1: Vector3 = u * cos(a1) + v * sin(a1)
		var q: Array[Vector3] = [p0 + o0 * r0, p0 + o1 * r0, p1 + o1 * r1, p1 + o0 * r1]
		_side_tri(st, q[0], q[1], q[2], mid, color)
		_side_tri(st, q[0], q[2], q[3], mid, color)
		_side_tri(st, p1, p1 + o0 * r1, p1 + o1 * r1, mid, color)


func _side_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, inside: Vector3, color: Color) -> void:
	var n: Vector3 = (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	if n.dot((a + b + c) / 3.0 - inside) < 0.0:
		var tmp: Vector3 = b
		b = c
		c = tmp
		n = -n
	# Godot usa ordem horária para a face da frente: com n para fora, inverte (o material toon
	# corta as faces de trás e o contorno desenha-as; antes o cull estava desligado).
	for v: Vector3 in [a, c, b]:
		st.set_color(color)
		st.set_normal(n)
		st.add_vertex(v)
