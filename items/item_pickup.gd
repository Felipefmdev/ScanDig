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
	apply_torque_impulse(Vector3(randf_range(-0.05, 0.05), randf_range(-0.1, 0.1), randf_range(-0.05, 0.05)))


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


func _physics_process(delta: float) -> void:
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
