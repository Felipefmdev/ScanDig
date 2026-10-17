extends Node3D

## Decoração espalhada pelo chão (estudo How to Fish: DecorationManager). Só cosmética: sem
## colisão, em MultiMesh (um por tipo). A semente é fixa por mapa, por isso todos os peers
## veem o mesmo chão. Perto das paredes (Bounds) põe rochas maiores que escondem a borda reta.
## Tudo é criado em runtime sem owner (#47): o editor nunca grava estas malhas no .tscn.

## Conjunto de props: praia, campo, ruinas, geleira, cratera.
@export var theme: String = "praia"
@export var count: int = 700
## Os props foram modelados a ~10 cm; no chão, a 1,7 m de altura, isso some. Aumenta tudo.
@export var size_boost: float = 1.8
## Rochas de borda a cada `border_step` m ao longo das paredes.
@export var border_step: float = 2.6
## Raio livre à volta do ponto de partida (0,0) e da base (banca/entrega).
@export var clear_radius: float = 7.0
@export var seed_value: int = 1234
## Lados sem rochas de borda (0 = -Z, 1 = +Z, 2 = -X, 3 = +X): ex. o mar da Praia.
@export var open_sides: PackedInt32Array = PackedInt32Array()

const GROUND_MASK: int = 1
const DEFAULT_HALF: float = 28.0

var _kinds: Dictionary = {}  # nome -> {mesh, transforms}


func _ready() -> void:
	# Espera a física do chão estar pronta para os raios.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	build()


func build() -> int:
	for c: Node in get_children():
		if c.owner == null:
			c.queue_free()
	_kinds.clear()
	var half: Vector2 = _arena_half()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var palette: Array = _palette()
	if palette.is_empty():
		return 0
	var placed: int = 0
	for i: int in count:
		var spec: Array = palette[rng.randi() % palette.size()]
		var p: Vector3 = Vector3(rng.randf_range(-half.x, half.x), 0.0, rng.randf_range(-half.y, half.y))
		if Vector2(p.x, p.z).length() < clear_radius:
			continue
		var hit: Variant = _ground_at(p)
		if hit == null:
			continue
		var s: float = rng.randf_range(spec[2], spec[3]) * size_boost
		_add(spec[0], spec[1], Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), hit))
		placed += 1
	placed += _border(half, rng)
	for kind: String in _kinds:
		var entry: Dictionary = _kinds[kind]
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = entry["mesh"]
		var xs: Array = entry["xforms"]
		mm.instance_count = xs.size()
		for k: int in xs.size():
			mm.set_instance_transform(k, xs[k])
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.name = "Deco_" + kind
		mmi.multimesh = mm
		mmi.material_override = ToonKit.vertex_material()
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if kind.begins_with("tiny") else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(mmi)
	return placed


func _add(kind: String, builder: Callable, xform: Transform3D) -> void:
	if not _kinds.has(kind):
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		builder.call(st)
		_kinds[kind] = {"mesh": ToonKit.commit(st), "xforms": []}
	(_kinds[kind]["xforms"] as Array).append(xform)


## Rochas grandes ao longo das 4 paredes: escondem o retângulo do mapa.
func _border(half: Vector2, rng: RandomNumberGenerator) -> int:
	var n: int = 0
	var builders: Array[Callable] = [_border_builder(1.0), _border_builder(0.82)]
	for row: int in 2:
		n += _border_row(half, rng, builders, float(row) * 2.4, 1.0 + 0.45 * float(row))
	return n


func _border_row(half: Vector2, rng: RandomNumberGenerator, builders: Array[Callable], out: float, grow: float) -> int:
	var n: int = 0
	for side: int in 4:
		if open_sides.has(side):
			continue
		var along: float = half.x if side < 2 else half.y
		var t: float = -along
		while t <= along:
			var p: Vector3
			match side:
				0: p = Vector3(t, 0.0, -half.y - 1.0 - out)
				1: p = Vector3(t, 0.0, half.y + 1.0 + out)
				2: p = Vector3(-half.x - 1.0 - out, 0.0, t)
				_: p = Vector3(half.x + 1.0 + out, 0.0, t)
			var hit: Variant = _ground_at(p)
			var y: float = (hit as Vector3).y if hit != null else 0.0
			var s: float = rng.randf_range(1.3, 3.0) * grow
			var b: Basis = Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s * rng.randf_range(0.8, 1.3), s * rng.randf_range(0.6, 2.0), s))
			var k: int = rng.randi() % 2
			_add("border_%d" % k, builders[k], Transform3D(b, Vector3(p.x, y - 0.3, p.z)))
			n += 1
			t += border_step * rng.randf_range(0.7, 1.3)
	return n


func _ground_at(p: Vector3) -> Variant:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p + Vector3.UP * 30.0, p + Vector3.DOWN * 30.0, GROUND_MASK)
	var hit: Dictionary = space.intersect_ray(q)
	return hit["position"] if not hit.is_empty() else null


func _arena_half() -> Vector2:
	var scene: Node = get_tree().current_scene
	var bounds: Node = scene.get_node_or_null(^"Bounds") if scene != null else null
	var half: Vector2 = Vector2(INF, INF)
	if bounds != null:
		for c: Node in bounds.get_children():
			var w: Node3D = c as Node3D
			if w == null:
				continue
			if absf(w.position.x) > absf(w.position.z):
				half.x = minf(half.x, absf(w.position.x) - 1.5)
			else:
				half.y = minf(half.y, absf(w.position.z) - 1.5)
	if half.x == INF:
		half.x = DEFAULT_HALF
	if half.y == INF:
		half.y = DEFAULT_HALF
	return half


# --- Paletas por mapa: [nome, construtor, escala mín, escala máx] ---------------

func _palette() -> Array:
	match theme:
		"praia":
			return [["tiny_shell", _shell.bind(Color("#f0d8c8"), Color("#e8a890")), 0.8, 1.4],
				["tiny_pebble", _pebble.bind(Color("#c8bca8")), 0.6, 1.3],
				["seaweed", _tuft.bind(Color("#5a8a3a"), 5, 0.18), 0.8, 1.3],
				["starfish", _star.bind(Color("#e8784a")), 0.8, 1.2],
				["driftwood", _stick.bind(Color("#a08060")), 0.8, 1.5]]
		"campo":
			return [["tiny_flower", _flower.bind(Color("#f0e060")), 0.8, 1.3],
				["tiny_flower_w", _flower.bind(Color("#f4f0ec")), 0.8, 1.3],
				["tiny_pebble", _pebble.bind(Color("#9a9488")), 0.6, 1.2],
				["tuft", _tuft.bind(Color("#6a9a3a"), 6, 0.22), 0.8, 1.5],
				["mushroom", _mushroom.bind(Color("#c84a3a")), 0.7, 1.1]]
		"ruinas":
			return [["rubble", _pebble.bind(Color("#c8b898")), 1.2, 2.6],
				["tiny_pebble", _pebble.bind(Color("#a89c84")), 0.6, 1.2],
				["column_chunk", _column.bind(Color("#d8ccb0")), 0.8, 1.4],
				["moss", _tuft.bind(Color("#6a8a4a"), 5, 0.12), 1.0, 1.8],
				["bone", _stick.bind(Color("#ece4d0")), 0.6, 1.0]]
		"geleira":
			return [["snow_clump", _pebble.bind(Color("#f4f8fc")), 1.0, 2.4],
				["ice_shard", _shard.bind(Color("#b8e0f0")), 0.7, 1.6],
				["tiny_pebble", _pebble.bind(Color("#7a8a98")), 0.6, 1.2],
				["twig", _stick.bind(Color("#6a5848")), 0.6, 1.0]]
		"cratera":
			return [["crystal", _shard.bind(Color("#c070ff")), 0.6, 1.5],
				["crystal_c", _shard.bind(Color("#50e0e0")), 0.6, 1.3],
				["basalt", _pebble.bind(Color("#3a3444")), 1.0, 2.4],
				["tiny_pebble", _pebble.bind(Color("#5a5068")), 0.6, 1.2],
				["fungus", _mushroom.bind(Color("#60e0b0")), 0.6, 1.0]]
	return []


func _border_builder(shade: float) -> Callable:
	var c: Color = {"praia": Color("#e0c890"), "campo": Color("#7a7468"), "ruinas": Color("#c0b090"),
		"geleira": Color("#dce8f0"), "cratera": Color("#3a3444")}.get(theme, Color("#808080"))
	return _boulder.bind(Color(c.r * shade, c.g * shade, c.b * shade))


# --- Construtores (origem na base, ~10-30 cm) ----------------------------------

func _pebble(st: SurfaceTool, c: Color) -> void:
	LowPolyMesh.prism(st, Vector3(0, -0.01, 0), Vector3(0, 0.05, 0), 0.07, 0.04, 5, c)


func _boulder(st: SurfaceTool, c: Color) -> void:
	LowPolyMesh.prism(st, Vector3(0, -0.2, 0), Vector3(0, 0.5, 0), 0.6, 0.35, 6, c)
	LowPolyMesh.prism(st, Vector3(0, 0.5, 0), Vector3(0.05, 0.75, 0.0), 0.35, 0.12, 6, c.darkened(0.12))


func _shell(st: SurfaceTool, c: Color, rim: Color) -> void:
	LowPolyMesh.prism(st, Vector3(0, 0.0, 0.03), Vector3(0, 0.018, -0.03), 0.04, 0.012, 7, c)
	LowPolyMesh.prism(st, Vector3(0, 0.0, 0.03), Vector3(0, 0.005, 0.035), 0.042, 0.04, 7, rim)


func _star(st: SurfaceTool, c: Color) -> void:
	for k: int in 5:
		var a: float = TAU * float(k) / 5.0
		LowPolyMesh.prism(st, Vector3(0, 0.01, 0), Vector3(cos(a) * 0.07, 0.008, sin(a) * 0.07), 0.016, 0.004, 4, c)


func _tuft(st: SurfaceTool, c: Color, blades: int, h: float) -> void:
	for k: int in blades:
		var a: float = TAU * float(k) / float(blades)
		var base: Vector3 = Vector3(cos(a) * 0.03, 0.0, sin(a) * 0.03)
		LowPolyMesh.prism(st, base, base + Vector3(cos(a) * 0.05, h * (0.7 + 0.3 * float(k % 2)), sin(a) * 0.05), 0.014, 0.0, 3, c if k % 2 == 0 else c.darkened(0.15))


func _flower(st: SurfaceTool, c: Color) -> void:
	LowPolyMesh.prism(st, Vector3.ZERO, Vector3(0, 0.16, 0), 0.006, 0.005, 4, Color("#4a7a2a"))
	LowPolyMesh.prism(st, Vector3(0, 0.16, 0), Vector3(0, 0.18, 0), 0.04, 0.03, 6, c)
	LowPolyMesh.prism(st, Vector3(0, 0.175, 0), Vector3(0, 0.19, 0), 0.014, 0.01, 5, Color("#d89030"))


func _mushroom(st: SurfaceTool, c: Color) -> void:
	LowPolyMesh.prism(st, Vector3.ZERO, Vector3(0, 0.07, 0), 0.012, 0.01, 5, Color("#ece0c8"))
	LowPolyMesh.prism(st, Vector3(0, 0.065, 0), Vector3(0, 0.095, 0), 0.045, 0.0, 7, c)


func _stick(st: SurfaceTool, c: Color) -> void:
	LowPolyMesh.prism(st, Vector3(-0.12, 0.012, 0.0), Vector3(0.12, 0.016, 0.02), 0.014, 0.01, 5, c)
	LowPolyMesh.prism(st, Vector3(0.02, 0.014, 0.01), Vector3(0.07, 0.02, 0.07), 0.008, 0.005, 4, c.darkened(0.1))


func _column(st: SurfaceTool, c: Color) -> void:
	LowPolyMesh.prism(st, Vector3(0, 0, 0), Vector3(0, 0.25, 0), 0.16, 0.15, 8, c)
	LowPolyMesh.prism(st, Vector3(0, 0.25, 0), Vector3(0.04, 0.32, 0), 0.15, 0.08, 6, c.darkened(0.1))


func _shard(st: SurfaceTool, c: Color) -> void:
	LowPolyMesh.prism(st, Vector3(0, -0.01, 0), Vector3(0.02, 0.22, 0.01), 0.04, 0.0, 5, c)
	LowPolyMesh.prism(st, Vector3(0.04, -0.01, 0.02), Vector3(0.07, 0.12, 0.03), 0.025, 0.0, 5, c.lightened(0.15))
