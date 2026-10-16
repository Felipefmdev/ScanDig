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


func _physics_process(delta: float) -> void:
	var authority: bool = not networked or multiplayer.is_server()
	if authority:
		_check_impacts()
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
