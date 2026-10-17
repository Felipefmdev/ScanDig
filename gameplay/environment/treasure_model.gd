@tool
class_name TreasureModel
extends Node3D

## Tesouros à vista da Ilha do Tesouro (#113): pilha de moedas, baú aberto a transbordar e ídolo
## de ouro. Ouro gasto com manchas verde-escuras/ferrugem e moedas de 12 lados como a referência
## (moeda_antiga.jpg); o ídolo tem olhos de rubi (idolo_ouro.jpg). Base na origem, +Y = cima.
## Com `solid`, uma colisão simples (layer 1) para não se atravessar. Gerado sem owner (#47).

enum Kind { GOLD_PILE, CHEST, IDOL }

const GOLD: Color = Color(0.86, 0.66, 0.24)
const GOLD_LIGHT: Color = Color(0.96, 0.8, 0.36)
const GOLD_WORN: Color = Color(0.6, 0.5, 0.22)
const PATINA: Color = Color(0.36, 0.42, 0.24)
const RUST: Color = Color(0.56, 0.32, 0.16)
const RUBY: Color = Color(0.82, 0.1, 0.22)
const WOOD: Color = Color(0.46, 0.3, 0.18)
const WOOD_DARK: Color = Color(0.32, 0.2, 0.12)
const IRON: Color = Color(0.32, 0.3, 0.3)

@export var kind: Kind = Kind.GOLD_PILE:
	set(v):
		kind = v
		_queue()
@export var size: float = 1.0:
	set(v):
		size = v
		_queue()
@export var seed_value: int = 1:
	set(v):
		seed_value = v
		_queue()
@export var solid: bool = true

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
		if c.owner == null:
			c.free()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shape_size: Vector3
	match kind:
		Kind.GOLD_PILE:
			_pile(st, rng)
			shape_size = Vector3(1.4, 0.7, 1.4) * size
		Kind.CHEST:
			_chest(st, rng)
			shape_size = Vector3(1.0, 0.7, 0.65) * size
		Kind.IDOL:
			_idol(st)
			shape_size = Vector3(0.6, 1.3, 0.6) * size
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = ToonKit.commit(st)
	mi.material_override = ToonKit.vertex_material(true, true)
	add_child(mi)
	if solid:
		var body: StaticBody3D = StaticBody3D.new()
		body.name = "Body"
		body.collision_layer = 1
		body.collision_mask = 0
		var cs: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = shape_size
		cs.shape = box
		cs.position.y = shape_size.y * 0.5
		body.add_child(cs)
		add_child(body)


## Moeda de 12 lados deitada (ou inclinada) em `p`.
static func coin(st: SurfaceTool, p: Vector3, r: float, tilt: Basis, c: Color) -> void:
	LowPolyMesh.prism(st, p, p + tilt * Vector3(0, r * 0.22, 0), r, r * 0.96, 12, c)


func _gold_tone(rng: RandomNumberGenerator) -> Color:
	var roll: float = rng.randf()
	if roll < 0.12:
		return PATINA
	if roll < 0.2:
		return RUST
	if roll < 0.45:
		return GOLD_WORN
	if roll < 0.75:
		return GOLD
	return GOLD_LIGHT


func _pile(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var s: float = size
	# monte de moedas (cone baixo e facetado) e moedas soltas por cima e à volta
	LowPolyMesh.prism(st, Vector3(0, -0.05, 0), Vector3(0.05 * s, 0.55 * s, 0), 0.75 * s, 0.12 * s, 7, GOLD_WORN)
	LowPolyMesh.prism(st, Vector3(0.25 * s, -0.05, 0.2 * s), Vector3(0.3 * s, 0.32 * s, 0.22 * s), 0.45 * s, 0.1 * s, 6, GOLD)
	for k: int in 26:
		var a: float = rng.randf() * TAU
		var r: float = rng.randf_range(0.1, 0.95) * s
		var y: float = maxf(0.55 * s * (1.0 - r / (0.8 * s)), 0.0) + 0.02
		var tilt: Basis = Basis.from_euler(Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5)))
		coin(st, Vector3(cos(a) * r, y, sin(a) * r), 0.09 * s, tilt, _gold_tone(rng))
	# um cálice e uma joia no topo
	LowPolyMesh.prism(st, Vector3(0.05 * s, 0.5 * s, 0), Vector3(0.05 * s, 0.72 * s, 0), 0.04 * s, 0.11 * s, 6, GOLD_LIGHT)
	LowPolyMesh.prism(st, Vector3(-0.3 * s, 0.32 * s, 0.1 * s), Vector3(-0.3 * s, 0.44 * s, 0.1 * s), 0.06 * s, 0.0, 4, RUBY)


func _chest(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var s: float = size
	LowPolyMesh.box(st, Vector3(0, 0.25 * s, 0), Vector3(0.9 * s, 0.5 * s, 0.55 * s), Basis.IDENTITY, WOOD)
	for x: float in [-0.36, 0.36]:
		LowPolyMesh.box(st, Vector3(x * s, 0.25 * s, 0), Vector3(0.07 * s, 0.52 * s, 0.57 * s), Basis.IDENTITY, IRON)
	# tampa aberta para trás
	var lid: Basis = Basis(Vector3.RIGHT, -1.15)
	LowPolyMesh.box(st, Vector3(0, 0.62 * s, -0.36 * s), Vector3(0.9 * s, 0.1 * s, 0.55 * s), lid, WOOD_DARK)
	LowPolyMesh.box(st, Vector3(0, 0.44 * s, 0.29 * s), Vector3(0.12 * s, 0.14 * s, 0.04 * s), Basis.IDENTITY, GOLD_LIGHT)
	# ouro a transbordar
	LowPolyMesh.prism(st, Vector3(0, 0.45 * s, 0), Vector3(0, 0.62 * s, 0), 0.4 * s, 0.15 * s, 6, GOLD)
	for k: int in 14:
		var p: Vector3 = Vector3(rng.randf_range(-0.38, 0.38) * s, rng.randf_range(0.5, 0.64) * s, rng.randf_range(-0.2, 0.22) * s)
		coin(st, p, 0.07 * s, Basis.from_euler(Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))), _gold_tone(rng))
	for k: int in 5:
		var a: float = rng.randf_range(0.2, PI - 0.2)
		coin(st, Vector3(cos(a) * 0.6 * s, 0.0, sin(a) * 0.5 * s), 0.07 * s, Basis.IDENTITY, _gold_tone(rng))


func _idol(st: SurfaceTool) -> void:
	var s: float = size
	LowPolyMesh.prism(st, Vector3(0, 0, 0), Vector3(0, 0.12 * s, 0), 0.32 * s, 0.3 * s, 8, GOLD_WORN)
	# corpo agachado, braços sobre os joelhos
	LowPolyMesh.box(st, Vector3(0, 0.42 * s, 0), Vector3(0.42 * s, 0.55 * s, 0.34 * s), Basis.IDENTITY, GOLD)
	for x: float in [-0.25, 0.25]:
		LowPolyMesh.box(st, Vector3(x * s, 0.45 * s, 0.08 * s), Vector3(0.12 * s, 0.32 * s, 0.14 * s), Basis.IDENTITY, GOLD_WORN)
		LowPolyMesh.box(st, Vector3(x * 0.6 * s, 0.22 * s, 0.14 * s), Vector3(0.14 * s, 0.2 * s, 0.14 * s), Basis.IDENTITY, PATINA.lerp(GOLD, 0.5))
	# cabeça grande com chapéu e olhos de rubi
	LowPolyMesh.box(st, Vector3(0, 0.92 * s, 0), Vector3(0.4 * s, 0.42 * s, 0.34 * s), Basis.IDENTITY, GOLD)
	LowPolyMesh.prism(st, Vector3(0, 1.12 * s, 0), Vector3(0, 1.22 * s, 0), 0.27 * s, 0.24 * s, 8, GOLD_WORN)
	LowPolyMesh.prism(st, Vector3(0, 1.22 * s, 0), Vector3(0, 1.32 * s, 0), 0.2 * s, 0.1 * s, 8, RUST.lerp(GOLD, 0.4))
	for x: float in [-0.09, 0.09]:
		LowPolyMesh.box(st, Vector3(x * s, 0.98 * s, 0.175 * s), Vector3(0.07 * s, 0.07 * s, 0.03 * s), Basis(Vector3.FORWARD, PI * 0.25), RUBY)
	LowPolyMesh.box(st, Vector3(0, 0.84 * s, 0.175 * s), Vector3(0.16 * s, 0.04 * s, 0.03 * s), Basis.IDENTITY, GOLD_WORN)
