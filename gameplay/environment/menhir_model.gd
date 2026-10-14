@tool
class_name MenhirModel
extends Node3D

## Pedra de pé antiga (menir) low-poly: prisma irregular de 5 lados que afunila para o topo,
## cinzento com manchas de musgo em baixo. Base na origem; +Y = cima.

const STONE: Color = Color(0.56, 0.55, 0.5)
const STONE_DARK: Color = Color(0.42, 0.41, 0.38)
const MOSS: Color = Color(0.33, 0.42, 0.18)

@export var height: float = 2.2:
	set(v):
		height = v
		_queue()
@export var width: float = 0.55:
	set(v):
		width = v
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
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides: int = 5
	var levels: Array[float] = [-0.25, 0.35, 0.75, 1.0]
	var rings: Array[PackedVector3Array] = []
	for li: int in levels.size():
		var t: float = maxf(levels[li], 0.0)
		var r: float = width * lerpf(1.0, 0.55, t)
		var ring: PackedVector3Array = PackedVector3Array()
		for k: int in sides:
			var a: float = TAU * float(k) / float(sides) + rng.randf_range(-0.2, 0.2)
			# achatado em Z: lajes de pedra mais largas do que fundas
			ring.append(Vector3(cos(a) * r * rng.randf_range(0.85, 1.15), levels[li] * height, sin(a) * r * 0.6))
		rings.append(ring)
	var center: Vector3 = Vector3.UP * height * 0.4
	for li: int in levels.size() - 1:
		for k: int in sides:
			var a: Vector3 = rings[li][k]
			var b: Vector3 = rings[li][(k + 1) % sides]
			var c: Vector3 = rings[li + 1][(k + 1) % sides]
			var d: Vector3 = rings[li + 1][k]
			var col: Color = STONE if (k + li) % 2 == 0 else STONE_DARK
			if li == 0 and rng.randf() < 0.6:
				col = col.lerp(MOSS, 0.6)
			_tri(st, a, d, c, col, center)
			_tri(st, a, c, b, col, center)
	# topo: leque
	var top: PackedVector3Array = rings[levels.size() - 1]
	var tip: Vector3 = Vector3(rng.randf_range(-0.05, 0.05), height * 1.04, 0.0)
	for k: int in sides:
		_tri(st, top[k], top[(k + 1) % sides], tip, STONE, center)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)


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
