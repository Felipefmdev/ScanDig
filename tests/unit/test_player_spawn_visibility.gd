extends GutTest

## Production only. Missing HostSpawnSync is a RED failure, never a fallback.
const PLAYER: PackedScene = preload("res://gameplay/player/player.tscn")
const OWNER_FIELDS: Array[NodePath] = [NodePath(".:position"),NodePath(".:rotation"),NodePath("Head:rotation"),NodePath(".:held_tool_id"),NodePath(".:carrying_loot"),NodePath(".:is_downed")]


func after_each() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _check_pre_enter(owner: int) -> void:
	var player: Player = PLAYER.instantiate() as Player
	player.name = str(owner)
	var seen: Dictionary = {}
	player.child_entered_tree.connect(func(child: Node) -> void:
		if child is MultiplayerSynchronizer:
			var sync: MultiplayerSynchronizer = child as MultiplayerSynchronizer
			seen[String(child.name)] = {"authority":sync.get_multiplayer_authority(),"root":sync.root_path,
				"config":sync.replication_config,"parent_ready":player.is_node_ready()})
	add_child_autoqfree(player)
	player.set_physics_process(false)
	player.set_process(false)
	assert_true(seen.has("HostSpawnSync"),"RED: host-owned gate must enter with production Player, before parent ready")
	if not seen.has("HostSpawnSync"): return
	var gate: Dictionary = seen["HostSpawnSync"]
	assert_false(bool(gate["parent_ready"]),"Gate configuration cannot wait until Player._ready")
	assert_eq(int(gate["authority"]),1,"HostSpawnSync authority restored after recursive setowner")
	assert_eq(gate["root"],NodePath(".."))
	var config: SceneReplicationConfig = gate["config"] as SceneReplicationConfig
	assert_not_null(config,"Explicit empty config is required for engine spawn registration")
	if config != null: assert_eq(config.get_properties().size(),0,"Gate never replicates owner properties")
	var gates: int = 0
	for child: Node in player.get_children():
		if child.name == &"HostSpawnSync": gates += 1
	assert_eq(gates,1,"Exactly one gate")
	assert_true(seen.has("NetSync"))
	if not seen.has("NetSync"): return
	var owner_sync: Dictionary = seen["NetSync"]
	assert_false(bool(owner_sync["parent_ready"]))
	assert_eq(int(owner_sync["authority"]),owner,"Owner NetSync authority must not change")
	assert_eq(owner_sync["root"],NodePath(".."))
	var owner_config: SceneReplicationConfig = owner_sync["config"] as SceneReplicationConfig
	assert_not_null(owner_config)
	if owner_config == null: return
	assert_eq(owner_config.get_properties().size(),OWNER_FIELDS.size(),"No extra owner fields introduced")
	for field: NodePath in OWNER_FIELDS:
		assert_true(owner_config.has_property(field),"Keep existing owner field "+String(field))
		if owner_config.has_property(field): assert_true(owner_config.property_get_spawn(field))


func test_host_player_gate_is_configured_before_children_enter() -> void:
	_check_pre_enter(1)


func test_guest_player_keeps_owner_sync_and_host_spawn_authority_before_enter() -> void:
	_check_pre_enter(17317)
