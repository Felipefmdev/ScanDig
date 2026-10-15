@tool
class_name FieldTreeModel
extends Node3D

## Árvore de campo low-poly (carvalho/oliveira velha): tronco facetado e afunilado com uma
## ligeira torção e copa feita de "bolhas" irregulares em dois tons. Gerada por SurfaceTool,
## normais por face, cores por vértice. Base do tronco na origem; +Y = cima.

const BARK: Color = Color(0.36, 0.26, 0.18)
const BARK_DARK: Color = Color(0.25, 0.18, 0.12)

@export var height: float = 3.2:
	set(v):
		height = v
		_queue()
@export var canopy_radius: float = 1.9:
	set(v):
		canopy_radius = v
		_queue()
@export var blobs: int = 5:
	set(v):
		blobs = v
		_queue()
@export var leaf_dark: Color = Color(0.17, 0.33, 0.1):
	set(v):
		leaf_dark = v
		_queue()
@export var leaf_light: Color = Color(0.36, 0.52, 0.16):
	set(v):
		leaf_light = v
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
	# #47: só os filhos gerados (sem owner); os que estão gravados na cena ficam.
	for c: Node in get_children():
		if c.owner == null:
			c.free()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Tronco: anéis hexagonais a afunilar, com um desvio lateral suave.
	var sides: int = 6
	var segs: int = 4
	var lean: Vector3 = Vector3(rng.randf_range(-0.35, 0.35), 0.0, rng.randf_range(-0.35, 0.35))
	var rings: Array[PackedVector3Array] = []
	for s: int in segs + 1:
		var t: float = float(s) / float(segs)
		var center: Vector3 = Vector3.UP * height * t + lean * t * t
		var r: float = lerpf(0.26, 0.11, t) * (1.25 if s == 0 else 1.0)
		var ring: PackedVector3Array = PackedVector3Array()
		for k: int in sides:
			var a: float = TAU * float(k) / float(sides) + t * 0.4
			ring.append(center + Vector3(cos(a), 0.0, sin(a)) * r * rng.randf_range(0.9, 1.1))
		rings.append(ring)
	for s: int in segs:
		for k: int in sides:
			var a: Vector3 = rings[s][k]
			var b: Vector3 = rings[s][(k + 1) % sides]
			var c: Vector3 = rings[s + 1][(k + 1) % sides]
			var d: Vector3 = rings[s + 1][k]
			var col: Color = BARK if (k + s) % 2 == 0 else BARK_DARK
			var axis: Vector3 = (rings[s][0] + rings[s][3] + rings[s + 1][0] + rings[s + 1][3]) * 0.25
			_tri(st, a, d, c, col, axis)
			_tri(st, a, c, b, col, axis)

	# Copa: bolhas à volta do topo do tronco, a maior ao centro.
	var top: Vector3 = Vector3.UP * height + lean
	for i: int in blobs:
		var center: Vector3 = top + Vector3(0.0, canopy_radius * 0.35, 0.0)
		var r: float = canopy_radius
		if i > 0:
			var a: float = TAU * float(i) / float(blobs - 1) + rng.randf_range(-0.4, 0.4)
			center += Vector3(cos(a), rng.randf_range(-0.45, 0.2), sin(a)) * canopy_radius * 0.7
			r = canopy_radius * rng.randf_range(0.55, 0.75)
		_blob(st, center, r, rng)

	# Toon + contorno preto (#36)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = ToonKit.commit(st)
	mi.material_override = ToonKit.vertex_material()
	add_child(mi)


## Esfera low-poly (lat/long 7x4) com vértices perturbados e um tom por face.
func _blob(st: SurfaceTool, center: Vector3, r: float, rng: RandomNumberGenerator) -> void:
	var lon: int = 7
	var lat: int = 4
	var grid: Array[PackedVector3Array] = []
	for y: int in lat + 1:
		var phi: float = PI * float(y) / float(lat)
		var row: PackedVector3Array = PackedVector3Array()
		for x: int in lon:
			var theta: float = TAU * float(x) / float(lon)
			var dir: Vector3 = Vector3(sin(phi) * cos(theta), cos(phi) * 0.8, sin(phi) * sin(theta))
			var jitter: float = 1.0 if y == 0 or y == lat else rng.randf_range(0.82, 1.12)
			row.append(center + dir * r * jitter)
		grid.append(row)
	for y: int in lat:
		for x: int in lon:
			var a: Vector3 = grid[y][x]
			var b: Vector3 = grid[y][(x + 1) % lon]
			var c: Vector3 = grid[y + 1][(x + 1) % lon]
			var d: Vector3 = grid[y + 1][x]
			# por cima mais claro (luz do sol), por baixo mais escuro
			var up: float = 1.0 - float(y) / float(lat)
			var col: Color = leaf_dark.lerp(leaf_light, clampf(up + rng.randf_range(-0.2, 0.2), 0.0, 1.0))
			_tri(st, a, b, c, col, center)
			_tri(st, a, c, d, col, center)


## Triângulo com normal por face, virada para fora de `inside`.
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color, inside: Vector3) -> void:
	var n: Vector3 = (b - a).cross(c - a)
	if n.length_squared() < 1e-10:
		return
	n = n.normalized()
	if n.dot((a + b + c) / 3.0 - inside) < 0.0:
		var tmp: Vector3 = b
		b = c
		c = tmp
		n = -n
	# Godot usa ordem horária para a face da frente: com n para fora, inverte.
	for v: Vector3 in [a, c, b]:
		st.set_color(col)
		st.set_normal(n)
		st.add_vertex(v)
