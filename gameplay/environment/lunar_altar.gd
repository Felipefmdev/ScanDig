extends BuriedSpot

## #120: host-authoritative lunar excavation. No actorless wake RPC or local boss fallback.
## Crystal/rock silhouette follows cristal_eco.jpg (viewed before modeling).
signal boss_spawned(boss: Node3D)

@export var boss_offset: Vector3 = Vector3.ZERO
var activation_state: StringName = &"BURIED":
	set(value):
		activation_state = value
		_refresh_marker()

var _ready_check: Callable = Callable()
var _defeated_check: Callable = Callable()
var _spawn_boss: Callable = Callable()
var _accepted_layers: int = 0
var _active_boss: EnemyBase = null
var _marker: Node3D = null


func configure_activation(ready_check: Callable, defeated_check: Callable, spawn_boss: Callable) -> void:
	_ready_check = ready_check
	_defeated_check = defeated_check
	_spawn_boss = spawn_boss
	_check_persisted_defeat()


func _ready() -> void:
	if not _has_ports():
		configure_activation(_default_peer_ready,_default_defeated,_default_spawn)
	networked = true
	item = null
	rare_decided = true
	rare_variant_chance = 0.0
	free_on_reveal = false
	collision_layer = 2
	collision_mask = 0
	super._ready()
	var selection: CollisionShape3D = CollisionShape3D.new()
	selection.name = &"Selection"
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 0.45
	selection.shape = sphere
	add_child(selection)
	var sync: MultiplayerSynchronizer = MultiplayerSynchronizer.new()
	sync.name = &"NetSync"
	var config: SceneReplicationConfig = SceneReplicationConfig.new()
	for path: NodePath in [NodePath(".:dirt_layers"),NodePath(".:integrity"),NodePath(".:activation_state")]:
		config.add_property(path)
		config.property_set_spawn(path,true)
		config.property_set_replication_mode(path,SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	sync.replication_config = config
	add_child(sync)
	NetVisibility.watch(sync)
	_check_persisted_defeat()
	_refresh_marker()


func get_activation_state() -> StringName:
	_check_persisted_defeat()
	return activation_state


func _default_peer_ready(peer_id: int) -> bool:
	var session: SessionManager = SessionManager.instance
	return session != null and session.get_current_map() != null \
		and session.get_current_map().id == "lua" and session.is_peer_scene_ready(peer_id)

func _default_defeated() -> bool:
	return GameState.instance != null and GameState.instance.is_boss_defeated("lunar_warden")

func _default_spawn(at: Vector3) -> EnemyBase:
	if not _host(): return null
	var spawner: EnemySpawner = EnemySpawner.find(get_tree())
	if spawner == null or not spawner.has_scene_for_kind(&"lunar_warden"): return null
	# No local fallback: a failed authoritative spawn must rearm the altar.
	return spawner.spawn_from_data({"kind":"lunar_warden","pos":at,"level":0,"rot_y":0.0}) as EnemyBase

func _has_ports() -> bool:
	return _ready_check.is_valid() and _defeated_check.is_valid() and _spawn_boss.is_valid()


func _host() -> bool:
	return is_inside_tree() and multiplayer.is_server()


func _check_persisted_defeat() -> void:
	if _host() and _defeated_check.is_valid() and bool(_defeated_check.call()):
		activation_state = &"DEFEATED"
		remove_from_group(&"buried_spots")


func _actor(digger: Node) -> Player:
	# Player._on_shovel_impact omits digger on the local host path.
	# Never choose an arbitrary closest actor for that trusted local call.
	var actor: Player = digger as Player
	if digger == null:
		actor = _player_of(1) as Player
	if actor == null or not actor.is_inside_tree() or not actor.is_in_group(&"players"):
		return null
	var peer_id: int = Player.peer_id_from_name(actor.name)
	if peer_id <= 0 or actor.get_multiplayer_authority() != peer_id:
		return null
	if not actor.is_alive() or not bool(_ready_check.call(peer_id)):
		return null
	if actor.global_position.distance_to(global_position) > MAX_REMOTE_DIG_DISTANCE:
		return null
	# A held optional weapon must not act as an altar shovel.
	if not [&"",&"detector"].has(actor.held_tool_id):
		return null
	return actor


func _refused() -> Dictionary:
	return {"dug":false,"revealed":false,"revealed_now":false,"dirt_layers":dirt_layers,
		"max_layers":MAX_DIRT_LAYERS,"integrity":integrity,"damaged":false,
		"item":null,"final_value":0,"is_rare_variant":false,"is_perfect":false,"is_clean":false}


func dig(is_careful: bool, damage_multiplier: float = 1.0, report_noise: bool = true, digger: Node = null) -> Dictionary:
	if not _host() or not _has_ports(): return _refused()
	_check_persisted_defeat()
	if activation_state != &"BURIED": return _refused()
	# Only the agreed centered spawn is enabled in this staged slice.
	if not boss_offset.is_finite() or boss_offset != Vector3.ZERO: return _refused()
	var actor: Player = _actor(digger)
	if actor == null: return _refused()
	# Replicated/externally assigned zero layers cannot manufacture accepted work.
	if dirt_layers != MAX_DIRT_LAYERS-_accepted_layers or dirt_layers <= 0:
		return _refused()
	var result: Dictionary = super.dig(is_careful,clampf(damage_multiplier,MIN_DAMAGE_MULTIPLIER,1.0),report_noise,actor)
	if not bool(result.get("dug",false)): return result
	_accepted_layers += 1
	if _accepted_layers == MAX_DIRT_LAYERS and bool(result.get("revealed_now",false)):
		# Reserve ACTIVE before calling external spawn: reentrant dig cannot duplicate.
		activation_state = &"ACTIVE"
		var spawned: EnemyBase = _spawn_boss.call(global_position) as EnemyBase
		if not is_instance_valid(spawned) or not spawned.is_inside_tree():
			_rearm()
			result["revealed"] = false
			result["revealed_now"] = false
			result["dirt_layers"] = dirt_layers
			return result
		_active_boss = spawned
		spawned.left_fight.connect(_on_boss_left.bind(spawned),CONNECT_ONE_SHOT)
		spawned.died.connect(_on_boss_died.bind(spawned),CONNECT_ONE_SHOT)
		boss_spawned.emit(spawned)
	return result


func _on_boss_left(boss: EnemyBase) -> void:
	if not _host() or boss != _active_boss or activation_state != &"ACTIVE": return
	_active_boss = null
	_check_persisted_defeat()
	if activation_state != &"DEFEATED": _rearm()


func _on_boss_died(boss: EnemyBase) -> void:
	if not _host() or boss != _active_boss: return
	_active_boss = null
	activation_state = &"DEFEATED"
	remove_from_group(&"buried_spots")


func _rearm() -> void:
	_accepted_layers = 0
	_is_revealed = false
	integrity = 1.0
	activation_state = &"BURIED"
	dirt_layers = MAX_DIRT_LAYERS
	if not is_in_group(&"buried_spots"): add_to_group(&"buried_spots")


func _update_mound() -> void:
	super._update_mound()
	# Restore client selection when authoritative layers reappear after flight.
	if is_inside_tree() and dirt_layers > 0 and activation_state != &"DEFEATED":
		_is_revealed = false
		if not is_in_group(&"buried_spots"): add_to_group(&"buried_spots")


func _refresh_marker() -> void:
	if not is_instance_valid(_marker): return
	_marker.visible = activation_state == &"BURIED"
	if is_inside_tree() and activation_state != &"BURIED":
		remove_from_group(&"buried_spots")


func _create_visuals() -> void:
	# Shallow stone/socket plus uneven violet crystal cluster, not a beach totem.
	_dirt_mound = Node3D.new()
	_dirt_mound.name = &"RegolithSocket"
	add_child(_dirt_mound)
	var ground: SurfaceTool = SurfaceTool.new()
	ground.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyMesh.prism(ground,Vector3(0,-0.04,0),Vector3(0,0.02,0),0.46,0.42,7,Color("#797985"))
	_dirt_mound.add_child(LowPolyMesh.commit(ground,"StoneSocket",ToonKit.vertex_material(true,true)))
	_marker = Node3D.new()
	_marker.name = &"ResonantCrystal"
	add_child(_marker)
	var crystal: SurfaceTool = SurfaceTool.new()
	crystal.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyMesh.prism(crystal,Vector3(0,0.02,0),Vector3(0.02,0.62,0),0.12,0.0,5,Color("#ac83d3"))
	LowPolyMesh.prism(crystal,Vector3(-0.14,0.02,0.02),Vector3(-0.24,0.38,0.04),0.085,0.0,5,Color("#825daf"))
	LowPolyMesh.prism(crystal,Vector3(0.14,0.02,-0.04),Vector3(0.23,0.44,-0.03),0.08,0.0,5,Color("#c4a2df"))
	_marker.add_child(LowPolyMesh.commit(crystal,"VioletCluster",ToonKit.vertex_material(true,true)))


func _create_particles() -> void:
	super._create_particles()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("#aaa9b1")
	material.roughness = 0.9
	var piece: BoxMesh = BoxMesh.new()
	piece.size = Vector3.ONE*0.04
	piece.material = material
	_dirt_particles.mesh = piece
