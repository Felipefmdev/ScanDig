class_name CampoLife
extends Node3D

## Vida que reage no Campo Antigo (Issue #98 — inspiração How to Fish com identidade ScanDig):
##   1. Pequenos animais pacíficos (coelhos e ovelhas low-poly) que pastam/saltitam e fogem
##      quando o jogador corre, escava ou faz barulho perto (<= flee_radius m). Na corrida,
##      o host às vezes faz o animal revolver a terra e deixar comida (batata_esquecida/minhoca)
##      ou um achado raso (ferradura_velha/colher_prata).
##   2. Árvores que reagem ao golpe da pá (ou interação): sacodem a copa, largam folhas e o
##      host faz cair um fruto/ninho (comida ou pequena relíquia) com cooldown e limite por árvore.
##   3. Vento na seara: rajadas periódicas inclinam os feixes de trigo da lavoura e revelam
##      por breves instantes um brilho/sinal metálico escondido entre as espigas.

signal animal_fled(index: int, origin: Vector3, dropped_pickup: ItemPickup)
signal tree_shaken(index: int, dropped_pickup: ItemPickup)
signal wind_gust_started(direction: Vector3, glint_position: Vector3)

const BURIED_SPOT_SCENE: PackedScene = preload("res://items/buried_spot.tscn")

const FUR_BROWN: Color = Color(0.62, 0.44, 0.28)
const FUR_LIGHT: Color = Color(0.92, 0.88, 0.80)
const EAR_PINK: Color = Color(0.90, 0.62, 0.64)
const WOOL_WHITE: Color = Color(0.95, 0.94, 0.88)
const SHEEP_DARK: Color = Color(0.20, 0.18, 0.17)
const WHEAT_GOLD: Color = Color(0.92, 0.78, 0.30)
const WHEAT_STEM: Color = Color(0.76, 0.63, 0.22)
const APPLE_RED: Color = Color(0.86, 0.22, 0.18)
const NEST_BROWN: Color = Color(0.48, 0.33, 0.18)
const GLINT_GOLD: Color = Color(1.0, 0.88, 0.32)

@export var flee_radius: float = 6.0
@export var flee_distance: float = 7.0
@export var flee_duration: float = 2.4
@export_range(0.0, 1.0) var flee_drop_chance: float = 0.55
@export var tree_hit_range: float = 3.2
@export var tree_cooldown: float = 18.0
@export var max_drops_per_tree: int = 3
@export var gust_interval: Vector2 = Vector2(9.0, 14.0)
@export var gust_duration: float = 3.5

var animals: Array[Dictionary] = []
var trees: Array[Dictionary] = []
var wheat_stalks: Array[Node3D] = []

var _mat: ShaderMaterial = null
var _unshaded_mat: StandardMaterial3D = null
var _meter: DisturbanceMeter = null
var _prev_noise: float = 0.0
var _player_attack_Check: Dictionary = {}
var _gust_timer: float = 5.0
var _gust_left: float = 0.0
var _gust_dir: Vector3 = Vector3(1.0, 0.0, 0.3).normalized()
var _glint_pos: Vector3 = Vector3(15.5, 0.0, -14.0)
var _glint_node: Node3D = null
var _glint_light: OmniLight3D = null
var _wheat_spot: BuriedSpot = null
var _wheat_spawner: MultiplayerSpawner = null
var _wheat_spawn_counter: int = 0
var _time: float = 0.0


func _ready() -> void:
	add_to_group(&"campo_life")
	_wheat_spawner = MultiplayerSpawner.new()
	_wheat_spawner.name = "WheatSpotSpawner"
	_wheat_spawner.spawn_path = NodePath("..")
	_wheat_spawner.spawn_function = _create_wheat_spot
	add_child(_wheat_spawner)
	_mat = ToonKit.vertex_material(true, true)
	_unshaded_mat = StandardMaterial3D.new()
	_unshaded_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_unshaded_mat.albedo_color = GLINT_GOLD
	_build_animals()
	_build_trees()
	_build_wheat_field()
	_gust_timer = randf_range(gust_interval.x, gust_interval.y)


func _process(delta: float) -> void:
	_time += delta
	_update_animals(delta)
	_update_trees(delta)
	_update_wheat_wind(delta)
	if not HostSync.is_host(self):
		return
	_check_players_and_noise()


# ---------------------------------------------------------------------------
# 1. Pequenos animais pacíficos (coelhos e ovelhas)
# ---------------------------------------------------------------------------

func _build_animals() -> void:
	var specs: Array[Dictionary] = [
		{"kind": "rabbit", "pos": Vector3(6.5, 0.0, -3.5), "yaw": 0.4},
		{"kind": "rabbit", "pos": Vector3(-5.5, 0.0, 4.2), "yaw": -1.1},
		{"kind": "sheep", "pos": Vector3(11.2, 0.0, 6.0), "yaw": 1.8},
		{"kind": " rabbit", "pos": Vector3(-10.5, 0.0, -7.5), "yaw": 0.9},
	]
	for i: int in specs.size():
		var sp: Dictionary = specs[i]
		var kind: String = str(sp["kind"]).strip_edges()
		var p: Vector3 = sp["pos"]
		p.y = FieldTerrain.height_at(p.x, p.z)
		var root_node: Node3D = Node3D.new()
		root_node.name = "Animal_%d_%s" % [i, kind]
		add_child(root_node)
		root_node.global_position = p
		root_node.rotation.y = float(sp["yaw"])

		var visual: MeshInstance3D = MeshInstance3D.new()
		visual.name = "Visual"
		visual.mesh = _make_rabbit_mesh() if kind == "rabbit" else _make_lamb_mesh()
		visual.material_override = _mat
		root_node.add_child(visual)

		animals.append({
			"index": i,
			"kind": kind,
			"node": root_node,
			"visual": visual,
			"home": p,
			"flee_left": 0.0,
			"flee_from": p,
			"flee_to": p,
			"cooldown": 0.0,
			"flee_count": 0,
		})


func _make_rabbit_mesh() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Corpo roliço, cabeça, orelhas compridas e rabinho branco
	LowPolyMesh.box(st, Vector3(0.0, 0.16, 0.02), Vector3(0.22, 0.20, 0.32), Basis.IDENTITY, FUR_BROWN)
	LowPolyMesh.box(st, Vector3(0.0, 0.25, -0.16), Vector3(0.17, 0.16, 0.18), Basis.IDENTITY, FUR_BROWN)
	LowPolyMesh.box(st, Vector3(0.0, 0.18, 0.20), Vector3(0.10, 0.10, 0.09), Basis.IDENTITY, FUR_LIGHT)
	for sx: float in [-1.0, 1.0]:
		LowPolyMesh.box(st, Vector3(sx * 0.05, 0.42, -0.14), Vector3(0.045, 0.22, 0.04), Basis(Vector3.RIGHT, -0.15), FUR_BROWN)
		LowPolyMesh.box(st, Vector3(sx * 0.05, 0.42, -0.155), Vector3(0.025, 0.16, 0.015), Basis(Vector3.RIGHT, -0.15), EAR_PINK)
		LowPolyMesh.box(st, Vector3(sx * 0.06, 0.27, -0.25), Vector3(0.025, 0.025, 0.02), Basis.IDENTITY, SHEEP_DARK)
		LowPolyMesh.box(st, Vector3(sx * 0.08, 0.05, -0.10), Vector3(0.05, 0.10, 0.06), Basis.IDENTITY, FUR_LIGHT)
		LowPolyMesh.box(st, Vector3(sx * 0.09, 0.06, 0.10), Vector3(0.06, 0.12, 0.10), Basis.IDENTITY, FUR_BROWN)
	return ToonKit.commit(st)


func _make_lamb_mesh() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyMesh.box(st, Vector3(0.0, 0.34, 0.0), Vector3(0.38, 0.32, 0.48), Basis.IDENTITY, WOOL_WHITE)
	LowPolyMesh.box(st, Vector3(0.0, 0.42, -0.28), Vector3(0.20, 0.20, 0.22), Basis.IDENTITY, SHEEP_DARK)
	LowPolyMesh.box(st, Vector3(0.0, 0.52, -0.26), Vector3(0.16, 0.08, 0.14), Basis.IDENTITY, WOOL_WHITE)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-0.15, 0.16]:
			LowPolyMesh.prism(st, Vector3(sx * 0.12, 0.24, sz), Vector3(sx * 0.12, 0.0, sz), 0.038, 0.032, 5, SHEEP_DARK)
	return ToonKit.commit(st)


func _update_animals(delta: float) -> void:
	for a: Dictionary in animals:
		a["cooldown"] = maxf(float(a["cooldown"]) - delta, 0.0)
		var node: Node3D = a["node"] as Node3D
		var visual: Node3D = a["visual"] as Node3D
		if node == null or not is_instance_valid(node):
			continue
		var left: float = float(a["flee_left"])
		if left > 0.0:
			left = maxf(left - delta, 0.0)
			a["flee_left"] = left
			var t: float = 1.0 - (left / maxf(flee_duration, 0.01))
			var from_p: Vector3 = a["flee_from"]
			var to_p: Vector3 = a["flee_to"]
			var flat: Vector3 = from_p.lerp(to_p, clampf(t, 0.0, 1.0))
			flat.y = FieldTerrain.height_at(flat.x, flat.z)
			node.global_position = flat
			if visual != null:
				visual.position.y = absf(sin(t * PI * 6.0)) * 0.28
				visual.rotation.x = sin(t * PI * 6.0) * 0.22
		else:
			if visual != null:
				var phase: float = _time * 2.2 + float(a["index"]) * 1.7
				visual.position.y = maxf(0.0, sin(phase)) * 0.04
				visual.rotation.x = sin(phase) * 0.05


## Assusta os animais dentro de `flee_radius` de `origin`. Devolve quantos fugiram.
func spook_animals_near(origin: Vector3, force_drop: bool = false) -> int:
	var count: int = 0
	for i: int in animals.size():
		var a: Dictionary = animals[i]
		var node: Node3D = a["node"] as Node3D
		if node == null or float(a["flee_left"]) > 0.0 or float(a["cooldown"]) > 0.0:
			continue
		var d: float = Vector2(node.global_position.x - origin.x, node.global_position.z - origin.z).length()
		if d <= flee_radius:
			if spook_animal(i, origin, 0.0 if force_drop else -1.0) != null or float(animals[i]["flee_left"]) > 0.0:
				count += 1
	return count


## Assusta o animal `index` para longe de `away_from`. Devolve o ItemPickup largado (ou null).
func spook_animal(index: int, away_from: Vector3, roll: float = -1.0) -> ItemPickup:
	if index < 0 or index >= animals.size():
		return null
	var a: Dictionary = animals[index]
	var node: Node3D = a["node"] as Node3D
	if node == null:
		return null
	var start_pos: Vector3 = node.global_position
	var dir: Vector3 = Vector3(start_pos.x - away_from.x, 0.0, start_pos.z - away_from.z)
	if dir.length_squared() < 0.01:
		dir = Vector3(1.0, 0.0, 0.0).rotated(Vector3.UP, float(index) * 1.4)
	dir = dir.normalized()
	var dest: Vector3 = start_pos + dir * flee_distance
	dest.x = clampf(dest.x, -26.0, 26.0)
	dest.z = clampf(dest.z, -26.0, 26.0)
	dest.y = FieldTerrain.height_at(dest.x, dest.z)

	var drop_kind: String = ""
	if HostSync.is_host(self):
		var r: float = randf() if roll < 0.0 else roll
		if r < flee_drop_chance:
			var pool: Array[String] = ["tool:batata_esquecida", "tool:minhoca", "item:ferradura_velha"]
			drop_kind = pool[int(a["flee_count"]) % pool.size()]

	_apply_animal_flee(index, start_pos, dest)
	if HostSync.is_host(self):
		HostSync.broadcast(self, &"_rpc_animal_flee", [index, start_pos, dest])

	var dropped: ItemPickup = null
	if not drop_kind.is_empty() and HostSync.is_host(self):
		dropped = _spawn_life_drop(start_pos + Vector3.UP * 0.25, drop_kind, -dir * 1.2 + Vector3.UP * 2.2)
	animal_fled.emit(index, start_pos, dropped)
	return dropped


@rpc("authority", "call_remote", "reliable")
func _rpc_animal_flee(index: int, start_pos: Vector3, dest: Vector3) -> void:
	_apply_animal_flee(index, start_pos, dest)


func _apply_animal_flee(index: int, start_pos: Vector3, dest: Vector3) -> void:
	if index < 0 or index >= animals.size():
		return
	var a: Dictionary = animals[index]
	var node: Node3D = a["node"] as Node3D
	if node == null:
		return
	a["flee_from"] = start_pos
	a["flee_to"] = dest
	a["flee_left"] = flee_duration
	a["cooldown"] = flee_duration + 3.0
	a["flee_count"] = int(a["flee_count"]) + 1
	var dir: Vector3 = dest - start_pos
	if Vector2(dir.x, dir.z).length() > 0.05:
		node.rotation.y = atan2(-dir.x, -dir.z)
	SFX.play_at(SFX.EMERGE_SAND, start_pos, -4.0, 0.18)


# ---------------------------------------------------------------------------
# 2. Árvores que reagem ao golpe da pá e largam frutos / ninhos
# ---------------------------------------------------------------------------

func _build_trees() -> void:
	var tree_positions: Array[Vector3] = [
		Vector3(2.2765, 0.0, -8.5059),
		Vector3(3.2866, 0.0, 11.971),
		Vector3(-7.8818, 0.0, 7.9862),
		Vector3(9.9226, 0.0, -5.5696),
	]
	for i: int in tree_positions.size():
		var p: Vector3 = tree_positions[i]
		p.y = FieldTerrain.height_at(p.x, p.z)
		var holder: Node3D = Node3D.new()
		holder.name = "OrchardTree_%d" % i
		holder.add_to_group(&"tree_shake")
		add_child(holder)
		holder.global_position = p

		# Frutos visíveis e pequeno ninho pendurados na copa para o jogador notar
		var crown: Node3D = Node3D.new()
		crown.name = "Crown"
		holder.add_child(crown)
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for f_idx: int in 3:
			var ang: float = TAU * float(f_idx) / 3.0 + float(i) * 0.5
			var fp: Vector3 = Vector3(cos(ang) * 0.85, 2.05 + (f_idx % 2) * 0.2, sin(ang) * 0.85)
			LowPolyMesh.box(st, fp, Vector3(0.16, 0.16, 0.16), Basis.IDENTITY, APPLE_RED)
		LowPolyMesh.prism(st, Vector3(0.35, 2.15, -0.35), Vector3(0.35, 2.26, -0.35), 0.22, 0.26, 7, NEST_BROWN)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "FruitNestMesh"
		mi.mesh = ToonKit.commit(st)
		mi.material_override = _mat
		crown.add_child(mi)

		trees.append({
			"index": i,
			"pos": p,
			"node": holder,
			"crown": crown,
			"cooldown": 0.0,
			"drops": 0,
		})


func _update_trees(delta: float) -> void:
	for t: Dictionary in trees:
		t["cooldown"] = maxf(float(t["cooldown"]) - delta, 0.0)


## Verifica se um golpe em `origin` na direção `forward` acerta alguma árvore; devolve o índice (-1 se nenhuma).
func hit_tree_at(origin: Vector3, forward: Vector3) -> int:
	var flat_fwd: Vector3 = Vector3(forward.x, 0.0, forward.z).normalized()
	for i: int in trees.size():
		var t: Dictionary = trees[i]
		var p: Vector3 = t["pos"]
		var to_tree: Vector3 = Vector3(p.x - origin.x, 0.0, p.z - origin.z)
		var dist: float = to_tree.length()
		if dist > tree_hit_range:
			continue
		if dist > 0.2 and not flat_fwd.is_zero_approx() and flat_fwd.dot(to_tree / dist) < 0.25:
			continue
		shake_tree(i)
		return i
	return -1


## Sacode a árvore `index` e (no host, se não estiver em cooldown nem esgotada) larga fruto/ninho.
func shake_tree(index: int, drop_override: String = "") -> ItemPickup:
	if index < 0 or index >= trees.size():
		return null
	var t: Dictionary = trees[index]
	if float(t["cooldown"]) > 0.0 or int(t["drops"]) >= max_drops_per_tree:
		return null

	_apply_tree_shake_visual(index)
	if HostSync.is_host(self):
		HostSync.broadcast(self, &"_rpc_tree_shake", [index])

	var dropped: ItemPickup = null
	if HostSync.is_host(self):
		t["cooldown"] = tree_cooldown
		var drop_num: int = int(t["drops"])
		t["drops"] = drop_num + 1
		var pool: Array[String] = ["tool:batata_esquecida", "tool:minhoca", "item:moeda_celta"]
		var kind: String = drop_override if not drop_override.is_empty() else pool[drop_num % pool.size()]
		var p: Vector3 = t["pos"]
		var angle: float = float(index) * 1.3 + float(drop_num) * 2.1
		var offset: Vector3 = Vector3(cos(angle) * 0.9, 1.9, sin(angle) * 0.9)
		var impulse: Vector3 = Vector3(cos(angle) * 1.4, 1.8, sin(angle) * 1.4)
		dropped = _spawn_life_drop(p + offset, kind, impulse)
	tree_shaken.emit(index, dropped)
	return dropped


@rpc("authority", "call_remote", "reliable")
func _rpc_tree_shake(index: int) -> void:
	_apply_tree_shake_visual(index)


func _apply_tree_shake_visual(index: int) -> void:
	if index < 0 or index >= trees.size():
		return
	var t: Dictionary = trees[index]
	var crown: Node3D = t["crown"] as Node3D
	var p: Vector3 = t["pos"]
	SFX.play_at(SFX.ITEM_IMPACT_WOOD, p + Vector3.UP * 1.5, 1.0, 0.12)
	if crown != null and is_inside_tree():
		var tw: Tween = create_tween()
		tw.tween_property(crown, "rotation", Vector3(0.14, 0.0, -0.14), 0.07)
		tw.tween_property(crown, "rotation", Vector3(-0.12, 0.0, 0.12), 0.08)
		tw.tween_property(crown, "rotation", Vector3(0.08, 0.0, -0.06), 0.08)
		tw.tween_property(crown, "rotation", Vector3.ZERO, 0.10)
	# Se existir a árvore correspondente em Decor/Trees do mapa, sacode-a também
	var scene: Node = get_tree().current_scene if is_inside_tree() else null
	var map_trees: Node = scene.get_node_or_null(^"Decor/Trees") if scene != null else null
	if map_trees != null:
		for child: Node in map_trees.get_children():
			var tn: Node3D = child as Node3D
			if tn != null and Vector2(tn.global_position.x - p.x, tn.global_position.z - p.z).length() < 1.5:
				var model: Node3D = tn.get_node_or_null(^"Model") as Node3D
				if model != null:
					var mtw: Tween = create_tween()
					mtw.tween_property(model, "rotation", Vector3(0.09, 0.0, -0.09), 0.07)
					mtw.tween_property(model, "rotation", Vector3(-0.07, 0.0, 0.07), 0.08)
					mtw.tween_property(model, "rotation", Vector3.ZERO, 0.10)


# ---------------------------------------------------------------------------
# 3. Vento na seara (rajadas que inclinam o trigo e revelam sinal metálico)
# ---------------------------------------------------------------------------

func _build_wheat_field() -> void:
	var stalk_mesh: ArrayMesh = _make_wheat_tuft_mesh()
	var xs: Array[float] = [12.0, 14.2, 16.4, 18.6, 20.8, 22.8]
	var zs: Array[float] = [-22.0, -19.5, -16.8, -14.2, -11.8]
	for x: float in xs:
		for z: float in zs:
			# Deixa folga no centro exato do círculo na seara (17.5, -17.0)
			if Vector2(x - 17.5, z - (-17.0)).length() < 2.2:
				continue
			var pos: Vector3 = Vector3(x, FieldTerrain.height_at(x, z), z)
			var tuft: MeshInstance3D = MeshInstance3D.new()
			tuft.name = "WheatTuft_%d" % wheat_stalks.size()
			tuft.mesh = stalk_mesh
			tuft.material_override = _mat
			add_child(tuft)
			tuft.global_position = pos
			wheat_stalks.append(tuft)

	# Brilho/sinal metálico escondido entre os feixes de trigo (revelado durante a rajada)
	_glint_node = Node3D.new()
	_glint_node.name = "WheatGlint"
	_glint_node.visible = false
	add_child(_glint_node)

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyMesh.box(st, Vector3(0.0, 0.22, 0.0), Vector3(0.28, 0.08, 0.28), Basis(Vector3.UP, PI * 0.25), GLINT_GOLD)
	LowPolyMesh.box(st, Vector3(0.0, 0.22, 0.0), Vector3(0.28, 0.08, 0.28), Basis.IDENTITY, GLINT_GOLD)
	var glint_mi: MeshInstance3D = MeshInstance3D.new()
	glint_mi.mesh = st.commit()
	glint_mi.material_override = _unshaded_mat
	_glint_node.add_child(glint_mi)

	_glint_light = OmniLight3D.new()
	_glint_light.light_color = GLINT_GOLD
	_glint_light.light_energy = 2.4
	_glint_light.omni_range = 3.2
	_glint_light.position = Vector3(0.0, 0.35, 0.0)
	_glint_node.add_child(_glint_light)


func _make_wheat_tuft_mesh() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var offsets: Array[Vector3] = [
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.18, 0.0, 0.12),
		Vector3(-0.16, 0.0, 0.15),
		Vector3(0.14, 0.0, -0.16),
		Vector3(-0.18, 0.0, -0.12),
	]
	for off: Vector3 in offsets:
		LowPolyMesh.prism(st, off, off + Vector3(0.0, 0.68, 0.0), 0.022, 0.016, 4, WHEAT_STEM)
		LowPolyMesh.box(st, off + Vector3(0.0, 0.78, 0.0), Vector3(0.06, 0.22, 0.06), Basis.IDENTITY, WHEAT_GOLD)
	return ToonKit.commit(st)


func is_wind_gust_active() -> bool:
	return _gust_left > 0.0


func get_glint_position() -> Vector3:
	return _glint_pos


## Dispara uma rajada de vento na seara e revela o brilho/sinal metálico escondido.
func trigger_wind_gust(custom_pos: Vector3 = Vector3.INF) -> Vector3:
	if not HostSync.is_host(self):
		return Vector3.INF
	var target_pos: Vector3 = custom_pos
	if target_pos == Vector3.INF:
		var candidates: Array[Vector3] = [
			Vector3(14.2, 0.0, -14.2),
			Vector3(20.8, 0.0, -19.5),
			Vector3(16.4, 0.0, -11.8),
		]
		target_pos = candidates[randi() % candidates.size()]
	target_pos.y = FieldTerrain.height_at(target_pos.x, target_pos.z)
	_ensure_wheat_spot(target_pos)
	if is_instance_valid(_wheat_spot) and not _wheat_spot.is_queued_for_deletion():
		# Never move a live target under a digging player or away from its spawn data.
		target_pos = _wheat_spot.global_position
	var dir: Vector3 = Vector3(1.0, 0.0, 0.25).normalized()

	_apply_wind_gust(dir, target_pos)
	if HostSync.is_host(self):
		HostSync.broadcast(self, &"_rpc_wind_gust", [dir, target_pos])
	wind_gust_started.emit(dir, target_pos)
	return target_pos


@rpc("authority", "call_remote", "reliable")
func _rpc_wind_gust(dir: Vector3, target_pos: Vector3) -> void:
	_apply_wind_gust(dir, target_pos)


func _apply_wind_gust(dir: Vector3, target_pos: Vector3) -> void:
	_gust_dir = dir.normalized() if not dir.is_zero_approx() else Vector3.RIGHT
	_glint_pos = target_pos
	_gust_left = gust_duration
	if _glint_node != null:
		_glint_node.global_position = target_pos
		_glint_node.visible = true
	for stalk: Node3D in wheat_stalks:
		if stalk != null and is_instance_valid(stalk):
			stalk.rotation.z = -_gust_dir.x * 0.48
			stalk.rotation.x = _gust_dir.z * 0.48


func _ensure_wheat_spot(pos: Vector3) -> void:
	if not is_inside_tree() or not HostSync.is_host(self) or _wheat_spawner == null:
		return
	if _wheat_spot != null and is_instance_valid(_wheat_spot) and not _wheat_spot.is_queued_for_deletion():
		return
	_wheat_spawn_counter += 1
	_wheat_spawner.spawn({"n": _wheat_spawn_counter, "pos": to_local(pos)})


## Runs on host and every receiving peer, including late join. BuriedSpot owns dig/sync.
func _create_wheat_spot(data: Variant) -> Node:
	var spec: Dictionary = data as Dictionary
	var spot: BuriedSpot = BURIED_SPOT_SCENE.instantiate() as BuriedSpot
	spot.name = "WheatSpot%d" % int(spec["n"])
	spot.networked = true
	spot.item = load("res://items/catalog/medalha_militar.tres") as ItemData
	spot.rare_decided = true
	spot.position = spec["pos"]
	_wheat_spot = spot
	return spot


func _update_wheat_wind(delta: float) -> void:
	if _gust_left > 0.0:
		_gust_left = maxf(_gust_left - delta, 0.0)
		var gust_strength: float = sin(clampf(_gust_left / maxf(gust_duration, 0.01), 0.0, 1.0) * PI)
		var lean: float = 0.25 + 0.30 * gust_strength
		for i: int in wheat_stalks.size():
			var stalk: Node3D = wheat_stalks[i]
			if stalk == null or not is_instance_valid(stalk):
				continue
			var ripple: float = sin(_time * 7.0 + stalk.position.x * 0.5 + stalk.position.z * 0.4) * 0.08
			stalk.rotation.z = -_gust_dir.x * (lean + ripple)
			stalk.rotation.x = _gust_dir.z * (lean + ripple)
		if _glint_node != null:
			_glint_node.visible = _gust_left > 0.0 and is_instance_valid(_wheat_spot) and _wheat_spot.dirt_layers > 0
			_glint_node.rotation.y += delta * 2.8
	else:
		if _glint_node != null and _glint_node.visible:
			_glint_node.visible = false
		for i: int in wheat_stalks.size():
			var stalk: Node3D = wheat_stalks[i]
			if stalk == null or not is_instance_valid(stalk):
				continue
			var gentle: float = sin(_time * 1.8 + float(i) * 0.35) * 0.06
			stalk.rotation.z = gentle
			stalk.rotation.x = gentle * 0.5
		if HostSync.is_host(self):
			_gust_timer -= delta
			if _gust_timer <= 0.0:
				_gust_timer = randf_range(gust_interval.x, gust_interval.y)
				trigger_wind_gust()


# ---------------------------------------------------------------------------
# Deteção de jogadores, corrida, escavação, golpes de pá e drops do host
# ---------------------------------------------------------------------------

func _check_players_and_noise() -> void:
	if not is_inside_tree():
		return
	if _meter == null or not is_instance_valid(_meter):
		_meter = DisturbanceMeter.instance
		if _meter != null:
			_prev_noise = _meter.current_noise
	if _meter != null:
		var current: float = _meter.current_noise
		var added: float = current - _prev_noise
		_prev_noise = current
		if added > 0.5:
			var origin: Variant = _meter.get(&"_last_origin")
			if origin is Vector3:
				spook_animals_near(origin as Vector3)

	var players: Array[Node] = get_tree().get_nodes_in_group(&"players")
	for p: Node in get_tree().get_nodes_in_group(&"player"):
		if not players.has(p):
			players.append(p)

	for n: Node in players:
		var p: Node3D = n as Node3D
		if p == null or not is_instance_valid(p):
			continue
		var vel: Vector3 = p.get(&"velocity") if &"velocity" in p else Vector3.ZERO
		var horiz_speed: float = Vector2(vel.x, vel.z).length()
		if horiz_speed >= 3.6:
			spook_animals_near(p.global_position)

		var cooldown_now: float = float(p.get(&"_attack_cooldown")) if &"_attack_cooldown" in p else 0.0
		var id: int = p.get_instance_id()
		var prev_cd: float = float(_player_attack_Check.get(id, 0.0))
		_player_attack_Check[id] = cooldown_now
		if cooldown_now > prev_cd + 0.05:
			var fwd: Vector3 = -p.global_basis.z
			hit_tree_at(p.global_position, fwd)


func _spawn_life_drop(pos: Vector3, spec: String, impulse: Vector3) -> ItemPickup:
	if not is_inside_tree():
		return null
	var carried: CarriedItem = null
	if spec.begins_with("tool:"):
		var tid: String = spec.trim_prefix("tool:")
		var path: String = "res://items/tools/%s.tres" % tid
		if ResourceLoader.exists(path):
			var td: ToolData = load(path) as ToolData
			if td != null:
				carried = CarriedItem.create_from_tool_data(td)
	elif spec.begins_with("item:"):
		var iid: String = spec.trim_prefix("item:")
		var ipath: String = "res://items/catalog/%s.tres" % iid
		if ResourceLoader.exists(ipath):
			var idata: ItemData = load(ipath) as ItemData
			if idata != null:
				carried = CarriedItem.create(idata, idata.base_value, 1.0, false)
	if carried == null:
		return null
	var parent: Node = get_tree().current_scene if get_tree().current_scene != null else get_parent()
	if parent == null:
		parent = self
	return ItemPickup.spawn(parent, carried, pos, impulse)
