class_name ItemPickup
extends RigidBody3D

## Item físico no chão. Surge quando um BuriedSpot é revelado e quando um jogador morre
## e larga a mochila. Apanha-se com a ação "interact" (E) — ver Player.

const GROUP: StringName = &"pickups"
## Coop: a física só corre no host; os clientes recebem posição/rotação a ~10 Hz.
const NET_INTERVAL: float = 0.1
## Rapidez da interpolação nos clientes (maior = segue mais colado à posição do host).
const NET_SMOOTHING: float = 14.0

var carried: CarriedItem = null
## Criado pelo PickupsRoot (MultiplayerSpawner): o host simula, os clientes interpolam.
var networked: bool = false
## Replicados (NetSync) — escritos pelo host, lidos pelos clientes.
var net_position: Vector3 = Vector3.ZERO
var net_rotation: Vector3 = Vector3.ZERO
var _pending_impulse: Vector3 = Vector3.ZERO
var _mesh: MeshInstance3D = null
var _model: Node3D = null
var _label: Label3D = null


## Cria o item no chão na posição global `pos`, com um impulso opcional.
## Se a cena tiver um PickupsRoot (mapas), o item nasce em rede por ele: no host cria-o
## e devolve-o; num cliente pede ao host (request_drop) e devolve null. Sem PickupsRoot
## (sandbox, testes) fica filho de `parent`, só local, como antes.
static func spawn(parent: Node, p_carried: CarriedItem, pos: Vector3, impulse: Vector3 = Vector3.ZERO) -> ItemPickup:
	var root: PickupsRoot = PickupsRoot.find(parent.get_tree()) if parent != null and parent.is_inside_tree() else null
	if root != null:
		return root.drop(p_carried, pos, impulse)
	var pickup: ItemPickup = create(p_carried)
	parent.add_child(pickup)
	pickup.global_position = pos
	pickup.launch(impulse)
	return pickup


static func create(p_carried: CarriedItem) -> ItemPickup:
	var pickup: ItemPickup = ItemPickup.new()
	pickup.carried = p_carried
	return pickup


func launch(impulse: Vector3) -> void:
	if impulse == Vector3.ZERO:
		return
	apply_central_impulse(impulse)
	var spin: float = clampf(impulse.length() * 0.06, 0.05, 0.35)
	apply_torque_impulse(Vector3(randf_range(-spin, spin), randf_range(-spin, spin) * 2.0, randf_range(-spin, spin)))


## Empurrão de um golpe (estilo How to Fish: tudo é físico). Em coop a física é do host:
## o cliente pede e o host aplica, com teto para um peer não arremessar itens pelo mapa.
const MAX_PUSH: float = 6.0


func push(impulse: Vector3) -> void:
	impulse = impulse.limit_length(MAX_PUSH)
	if networked and not multiplayer.is_server():
		_request_push.rpc_id(1, impulse)
		return
	sleeping = false
	launch(impulse)


@rpc("any_peer", "call_remote", "reliable")
func _request_push(impulse: Vector3) -> void:
	if not multiplayer.is_server():
		return
	sleeping = false
	launch(impulse.limit_length(MAX_PUSH))


## PickupsRoot: prepara o nó para a rede antes de entrar na árvore (host e clientes).
func setup_network(local_pos: Vector3, impulse: Vector3) -> void:
	networked = true
	position = local_pos
	net_position = local_pos
	_pending_impulse = impulse
	var config: SceneReplicationConfig = SceneReplicationConfig.new()
	for prop: String in [".:net_position", ".:net_rotation"]:
		config.add_property(NodePath(prop))
		config.property_set_spawn(NodePath(prop), false)
		config.property_set_replication_mode(NodePath(prop), SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	var sync: MultiplayerSynchronizer = MultiplayerSynchronizer.new()
	sync.name = "NetSync"
	sync.replication_config = config
	sync.replication_interval = NET_INTERVAL
	sync.root_path = NodePath("..")
	add_child(sync)
	NetVisibility.watch(sync)


## Comida viva (minhoca, tatuíra...) se debate no chão como peixe fora d'água.
const WRIGGLE_INTERVAL: Vector2 = Vector2(0.7, 1.6)
const WRIGGLE_UP: float = 1.6
const WRIGGLE_SIDE: float = 0.9
var _wriggle_left: float = 1.0


func is_wriggling_food() -> bool:
	return carried != null and carried.tool_data != null 		and carried.tool_data.category == ToolData.Category.FOOD and carried.tool_data.wriggles


func _wriggle(delta: float) -> void:
	_wriggle_left -= delta
	if _wriggle_left > 0.0:
		return
	_wriggle_left = randf_range(WRIGGLE_INTERVAL.x, WRIGGLE_INTERVAL.y)
	if linear_velocity.length() > 0.8:
		return  # ainda no ar: espera assentar
	sleeping = false
	var side: Vector3 = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized() * WRIGGLE_SIDE
	apply_central_impulse((Vector3.UP * WRIGGLE_UP + side) * mass)
	apply_torque_impulse(Vector3(randf_range(-0.15, 0.15), randf_range(-0.3, 0.3), randf_range(-0.15, 0.15)) * mass)


var _spoil_left: float = -1.0

## Estudo How to Fish (peixe arremessado fere entre 8 e 20 m/s): item rápido acerta
## inimigos. Vale para o [Q] carregado, para itens atirados pela dinamite, pela pá...
const IMPACT_MIN_SPEED: float = 7.0
const IMPACT_MAX_SPEED: float = 14.0
const IMPACT_DAMAGE: Vector2 = Vector2(8.0, 30.0)
const IMPACT_RADIUS: float = 0.9
## Mesmo inimigo só leva um impacto por arremesso.
var _impact_hit: Dictionary = {}


## Dano de impacto à velocidade `speed` (0 abaixo do mínimo). Achados maiores batem mais.
func impact_damage(speed: float) -> float:
	if speed < IMPACT_MIN_SPEED:
		return 0.0
	var t: float = clampf((speed - IMPACT_MIN_SPEED) / (IMPACT_MAX_SPEED - IMPACT_MIN_SPEED), 0.0, 1.0)
	var size_mult: float = 1.0
	if carried != null and carried.item != null:
		size_mult = 1.0 + 0.35 * float(carried.item.size_category)
	return lerpf(IMPACT_DAMAGE.x, IMPACT_DAMAGE.y, t) * size_mult


func _check_impacts() -> void:
	var speed: float = linear_velocity.length()
	if speed < IMPACT_MIN_SPEED:
		if not _impact_hit.is_empty() and speed < 1.0:
			_impact_hit.clear()  # assentou: o próximo arremesso volta a acertar
		return
	for n: Node in get_tree().get_nodes_in_group(&"enemies"):
		var e: Node3D = n as Node3D
		if e == null or not is_instance_valid(e) or _impact_hit.has(e.get_instance_id()):
			continue
		var center: Vector3 = e.global_position + Vector3.UP * 0.4
		if center.distance_to(global_position) > IMPACT_RADIUS:
			continue
		if e.has_method("is_alive") and not bool(e.call("is_alive")):
			continue
		_impact_hit[e.get_instance_id()] = true
		var dmg: float = impact_damage(speed)
		e.call("take_damage", dmg, global_position - linear_velocity.normalized())
		SFX.play_at(SFX.STONE_IMPACT, global_position, 2.0, 0.15)
		# Ricochete: o item perde força e quica para cima.
		linear_velocity = -linear_velocity * 0.25 + Vector3.UP * 2.0
		impacted.emit(e, dmg)
		break


signal impacted(enemy: Node3D, damage: float)

## How to Fish (WaterManager / FloatInfos): itens leves/orgânicos boiam na água e as ondas
## trazem-nos de volta até à beira da praia (x < 19.5); metais e rochas pesadas afundam com
## arrasto mas ficam no fundo raso visível (y >= -0.45, x <= 23.0).
const WATER_START_X: float = 20.0
const WATER_SHORE_EXIT_X: float = 19.5
const WATER_SURFACE_MAX_Y: float = 0.05
const WATER_FLOAT_MIN_Y: float = -0.02
const WATER_FLOAT_MAX_Y: float = 0.04
const WATER_SHALLOW_FLOOR_Y: float = -0.45
const WATER_HEAVY_MAX_X: float = 23.0
const WATER_DRIFT_SPEED: float = 1.6
const WATER_HEAVY_PULL_SPEED: float = 2.0
const WATER_BUOYANT_DAMP: float = 2.5
const WATER_SINK_DAMP: float = 3.5

var _in_water: bool = false
var _water_time: float = 0.0


## Devolve true se o item flutua na água (madeira, orgânico, comida, ferramentas leves,
## garrafas, conchas, latas/alumínio); false para metais pesados (ferro/prata/ouro) e rochas grandes.
func is_buoyant() -> bool:
	if carried == null:
		return true
	if carried.tool_data != null:
		if carried.tool_data.category == ToolData.Category.FOOD:
			return true
		var tid: String = String(carried.tool_data.id).to_lower()
		if tid in ["forcado", "arpao_corda", "pulso_magnetico"]:
			return false
		return true
	if carried.is_tool():
		var raw_tid: String = String(carried.tool_id).to_lower()
		if raw_tid in ["detector", "forcado", "arpao_corda", "pulso_magnetico"]:
			return false
		return true
	if carried.item != null:
		var item_id: String = carried.item.id.to_lower()
		for buoyant_kw: String in ["garrafa", "concha", "madeira", "chocolate", "lata", "osso", "ambar", "olho", "bussola", "mapa"]:
			if buoyant_kw in item_id:
				return true
		for heavy_kw: String in ["pedra", "rocha", "ancora", "canhao", "bigorna", "estatua", "idolo", "meteorito", "coroa", "sino", "ferradura", "chave", "lanca", "moeda", "alianca", "anel", "colher", "medalha"]:
			if heavy_kw in item_id:
				return false
		match carried.item.material_type:
			ItemData.MaterialType.ALUMINIO:
				return int(carried.item.size_category) <= ItemData.SizeCategory.MEDIO
			ItemData.MaterialType.DESCONHECIDO:
				return int(carried.item.size_category) <= ItemData.SizeCategory.MEDIO
			_:
				return false
	return true


## Verifica se o ItemPickup está na água (volume do grupo water/agua ou mar da Praia).
func is_in_water() -> bool:
	if _is_in_water_group():
		return true
	if not _is_sea_active_in_scene():
		return false
	var x_threshold: float = WATER_SHORE_EXIT_X if _in_water else WATER_START_X
	var y_threshold: float = WATER_SURFACE_MAX_Y + (0.04 if _in_water else 0.0)
	return global_position.x >= x_threshold and global_position.y <= y_threshold


func _is_in_water_group() -> bool:
	if not is_inside_tree():
		return false
	for n: Node in get_tree().get_nodes_in_group(&"water") + get_tree().get_nodes_in_group(&"agua"):
		var area: Area3D = n as Area3D
		if area != null and is_instance_valid(area) and area.overlaps_body(self):
			return true
		var node3d: Node3D = n as Node3D
		if node3d != null and is_instance_valid(node3d) and node3d.global_position.distance_to(global_position) < 2.5 and global_position.y <= WATER_SURFACE_MAX_Y:
			return true
	return false


func _is_sea_active_in_scene() -> bool:
	if not is_inside_tree():
		return true
	var tree: SceneTree = get_tree()
	if tree != null and tree.current_scene != null:
		var sname: String = tree.current_scene.name.to_lower()
		for non_sea: String in ["campo", "ruinas", "geleira", "cratera"]:
			if non_sea in sname:
				return false
	return true


## Aplica empuxo/ondulação e deriva para a areia (itens flutuantes) ou arrasto e limite de
## fundo raso (itens pesados). Pode ser chamado diretamente em testes unitários.
func _apply_water_physics(delta: float) -> void:
	if not is_in_water():
		if _in_water:
			_in_water = false
			linear_damp = 0.0
			angular_damp = 0.0
			linear_velocity.x *= 0.35
		return

	_in_water = true
	_water_time += delta
	sleeping = false

	if is_buoyant():
		linear_damp = WATER_BUOYANT_DAMP
		angular_damp = 3.0
		var wave_y: float = 0.01 + sin(_water_time * 2.8 + global_position.x * 0.65 + global_position.z * 0.45) * 0.022
		wave_y = clampf(wave_y, WATER_FLOAT_MIN_Y, WATER_FLOAT_MAX_Y)
		if global_position.y < wave_y:
			var depth: float = wave_y - global_position.y
			linear_velocity.y = move_toward(linear_velocity.y, clampf(depth * 5.0, 0.15, 2.2), delta * 15.0)
			global_position.y = move_toward(global_position.y, wave_y, maxf(0.8, depth * 4.5) * delta)
		else:
			global_position.y = move_toward(global_position.y, wave_y, 0.5 * delta)
			linear_velocity.y = move_toward(linear_velocity.y, 0.0, delta * 8.0)
		global_position.y = clampf(global_position.y, WATER_FLOAT_MIN_Y, WATER_FLOAT_MAX_Y)

		# Deriva suave com as ondas de volta para a areia (-X) até sair em x < 19.5
		if global_position.x >= WATER_SHORE_EXIT_X:
			linear_velocity.x = lerpf(linear_velocity.x, -WATER_DRIFT_SPEED, clampf(delta * 4.5, 0.0, 1.0))
			global_position.x = move_toward(global_position.x, WATER_SHORE_EXIT_X - 0.15, WATER_DRIFT_SPEED * delta)
			if global_position.x < WATER_SHORE_EXIT_X:
				_in_water = false
				linear_damp = 0.0
				angular_damp = 0.0
				linear_velocity = Vector3(0.0, 0.0, linear_velocity.z * 0.3)
	else:
		linear_damp = WATER_SINK_DAMP
		angular_damp = 3.5
		# Afunda com drag de água mas pousa no fundo raso visível (y >= -0.45, x <= 23.0)
		if global_position.y > -0.32:
			linear_velocity.y = minf(linear_velocity.y, -0.6)
			global_position.y = move_toward(global_position.y, -0.35, 0.9 * delta)
		if global_position.y < WATER_SHALLOW_FLOOR_Y:
			global_position.y = WATER_SHALLOW_FLOOR_Y
			if linear_velocity.y < 0.0:
				linear_velocity.y = 0.0
		if global_position.x > WATER_HEAVY_MAX_X:
			linear_velocity.x = minf(linear_velocity.x, -WATER_HEAVY_PULL_SPEED)
			global_position.x = move_toward(global_position.x, WATER_HEAVY_MAX_X - 0.2, WATER_HEAVY_PULL_SPEED * delta)
		else:
			linear_velocity.x = move_toward(linear_velocity.x, 0.0, delta * 5.0)


func _physics_process(delta: float) -> void:
	var authority: bool = not networked or multiplayer.is_server()
	if authority:
		_check_impacts()
		_apply_water_physics(delta)
	if is_wriggling_food() and authority:
		_wriggle(delta)
	if authority and carried != null and carried.tool_data != null and carried.tool_data.spoil_seconds > 0.0:
		if _spoil_left < 0.0:
			_spoil_left = carried.tool_data.spoil_seconds
		_spoil_left -= delta
		if _spoil_left <= 0.0:
			queue_free()  # estragou (em rede o PickupsRoot propaga o despawn)
			return
	if not networked:
		return
	if multiplayer.is_server():
		net_position = position
		net_rotation = rotation
	else:
		var t: float = 1.0 - exp(-NET_SMOOTHING * delta)
		position = position.lerp(net_position, t)
		basis = basis.orthonormalized().slerp(Basis.from_euler(net_rotation), t)



func _ready() -> void:
	add_to_group(GROUP)
	if networked:
		if multiplayer.is_server():
			launch.call_deferred(_pending_impulse)
		else:
			freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
			freeze = true
			net_rotation = rotation
	mass = 0.6
	collision_layer = 1 << 4  # layer 5: objetos apanháveis (layer 4 = inimigos)
	collision_mask = 1        # colide com o chão/mundo
	continuous_cd = true
	max_contacts_reported = 3
	contact_monitor = true
	body_entered.connect(_on_body_entered)

	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.24, 0.24, 0.24)
	shape.shape = box
	add_child(shape)

	if carried != null and carried.world_scene != null:
		# Ferramentas (ex.: detector) usam o próprio modelo; a colisão continua a caixa.
		var visual: Node = carried.world_scene.instantiate()
		add_child(visual)
		box.size = Vector3(0.35, 0.25, 0.9)
	elif _item_model() != null:
		add_child(_item_model())
	else:
		_mesh = MeshInstance3D.new()
		var cube: BoxMesh = BoxMesh.new()
		cube.size = box.size
		_mesh.mesh = cube
		_mesh.material_override = make_material(carried.item if carried != null else null, carried != null and carried.is_rare_variant)
		if carried != null and carried.tool_data != null:
			(_mesh.material_override as StandardMaterial3D).albedo_color = carried.tool_data.color
		add_child(_mesh)

	_label = Label3D.new()
	_label.text = carried.get_display_name() if carried != null else "?"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = 0.35
	_label.font_size = 28
	_label.pixel_size = 0.004
	_label.no_depth_test = true
	_label.visible = false
	add_child(_label)


## Mostra/esconde o nome quando o jogador está a olhar para o item.
func set_highlighted(on: bool) -> void:
	if _label != null:
		_label.visible = on


var _last_impact_time: float = -1.0


func _on_body_entered(_body: Node) -> void:
	var speed: float = linear_velocity.length()
	if speed < 0.9:
		return
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	if _last_impact_time > 0.0 and (now - _last_impact_time) < 0.12:
		return
	_last_impact_time = now

	var sound: Array[String] = SFX.ITEM_IMPACT_STONE
	if carried != null:
		if carried.item != null:
			sound = SFX.item_impact_sound(carried.item.material_type)
		elif carried.tool_data != null:
			if carried.tool_data.category == ToolData.Category.FOOD:
				sound = SFX.ITEM_IMPACT_WOOD
			elif carried.tool_data.id in ["estilingue", "vara_pesca"]:
				sound = SFX.ITEM_IMPACT_WOOD
			else:
				sound = SFX.ITEM_IMPACT_METAL

	var vol_db: float = clampf(-12.0 + (speed - 1.0) * 1.5, -14.0, 2.0)
	SFX.play_at(sound, global_position, vol_db, 0.1)


## Retira o item do mundo e devolve-o para a mochila.
func take() -> CarriedItem:
	var c: CarriedItem = carried
	carried = null
	queue_free()
	return c


## Modelo low-poly do item (#61), construído uma vez; null se o item não tiver modelo.
func _item_model() -> Node3D:
	if _model == null and carried != null and carried.item != null:
		_model = ItemModels.build(carried.item.id, carried.is_rare_variant)
	return _model


static func make_material(item: ItemData, is_rare: bool) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.55, 0.45)
	if item != null:
		match item.material_type:
			ItemData.MaterialType.FERRO:
				mat.albedo_color = Color(0.35, 0.35, 0.35)
				mat.metallic = 0.8
				mat.roughness = 0.4
			ItemData.MaterialType.ALUMINIO:
				mat.albedo_color = Color(0.75, 0.78, 0.82)
				mat.metallic = 0.7
				mat.roughness = 0.3
			ItemData.MaterialType.PRATA:
				mat.albedo_color = Color(0.92, 0.93, 0.96)
				mat.metallic = 0.95
				mat.roughness = 0.15
			ItemData.MaterialType.OURO:
				mat.albedo_color = Color(1.0, 0.82, 0.12)
				mat.metallic = 0.95
				mat.roughness = 0.1
			ItemData.MaterialType.DESCONHECIDO:
				mat.albedo_color = Color(0.2, 0.95, 0.85)
				mat.emission_enabled = true
				mat.emission = Color(0.2, 0.95, 0.85)
				mat.emission_energy_multiplier = 2.5
	if is_rare:
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.85, 0.3)
		mat.emission_energy_multiplier = 1.2
	return mat
