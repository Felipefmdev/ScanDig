extends GutTest


func test_delivered_counter_geometry_allows_own_focus_and_keeps_external_los_guard() -> void:
	if not _fixture(): return
	_counter.free()
	_counter = (load("res://gameplay/environment/upgrade_counter.tscn") as PackedScene).instantiate() as Node3D
	_counter.set("map_id", "praia")
	_world.add_child(_counter)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_true(bool(_counter.call("host_can_purchase", 1)), "counter's own physical stand is a valid target")
	var wall: StaticBody3D = StaticBody3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(2, 3, .1)
	collision.shape = shape
	wall.add_child(collision)
	_world.add_child(wall)
	wall.position = Vector3(0, 1, .5)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_false(bool(_counter.call("host_can_purchase", 1)), "external obstacle still blocks commerce")

## #186 host-local commerce boundary. No ENet, UI clicks, ToolData or pickups.
const SOURCE: String = "res://gameplay/environment/upgrade_counter.gd"
const PLAYER: PackedScene = preload("res://gameplay/player/player.tscn")


class CounterFake extends Node3D:
	func host_can_purchase(_peer_id: int) -> bool:
		return true # Group + a permissive method must not impersonate production.


var _snapshot: Dictionary = {}
var _original_session: SessionManager = null
var _original_save: SaveManager = null
var _original_scene: Node = null
var _original_mouse: int = Input.MOUSE_MODE_VISIBLE
var _world: Node3D = null
var _session: SessionManager = null
var _save: SaveManager = null
var _actor: Player = null
var _counter: Node3D = null
var _dir: String = ""
var _replies: Array[Dictionary] = []
var _sequence: int = 0


func before_each() -> void:
	_snapshot = GameState.instance.get_snapshot().duplicate(true)
	_original_session = SessionManager.instance
	_original_save = SaveManager.instance
	_original_scene = get_tree().current_scene
	_original_mouse = Input.mouse_mode
	GameState.instance.reset_state()
	GameState.instance.team_money = 1000000
	_replies.clear()
	_sequence = 0
	_dir = ""


func after_each() -> void:
	if GameState.instance.has_signal("world_upgrade_result") and GameState.instance.is_connected("world_upgrade_result", _on_result):
		GameState.instance.disconnect("world_upgrade_result", _on_result)
	get_tree().current_scene = _original_scene
	# Also covers the real counter temporarily moved outside current_scene.
	if is_instance_valid(_counter):
		_counter.free()
	if is_instance_valid(_world):
		_world.free()
	SessionManager.instance = _original_session
	SaveManager.instance = _original_save
	GameState.instance.load_snapshot(_snapshot)
	if is_instance_valid(_save):
		_save.free()
	if not _dir.is_empty():
		for file_name: String in DirAccess.get_files_at(_dir):
			DirAccess.remove_absolute(_dir.path_join(file_name))
		DirAccess.remove_absolute(_dir)
	Input.mouse_mode = _original_mouse
	_world = null
	_session = null
	_save = null
	_actor = null
	_counter = null
	await get_tree().process_frame


func _fixture() -> bool:
	var state: GameState = GameState.instance
	var present: bool = state.has_method("request_world_upgrade")
	assert_true(present, "request_world_upgrade API must exist")
	assert_true(state.has_signal("world_upgrade_result"), "correlated result signal must exist")
	if not present or not state.has_signal("world_upgrade_result"):
		return false
	var exists: bool = ResourceLoader.exists(SOURCE)
	assert_true(exists, "real upgrade_counter source must exist")
	if not exists:
		return false
	var script: Script = load(SOURCE) as Script
	assert_not_null(script)
	if script == null:
		return false
	var instance: Node = script.new() as Node
	assert_true(instance is Interactable, "counter must be a real Interactable")
	if not (instance is Interactable):
		if instance != null:
			instance.free()
		return false
	_counter = instance as Node3D
	assert_true(_counter.has_method("host_can_purchase"))
	if not _counter.has_method("host_can_purchase"):
		_counter.free()
		_counter = null
		return false
	_world = Node3D.new()
	_world.name = "WorldUpgradePurchaseTest"
	get_tree().root.add_child(_world)
	assert_true(_world.get_parent() == get_tree().root)
	get_tree().current_scene = _world
	assert_true(get_tree().current_scene == _world)
	_save = SaveManager.new()
	_save.use_test_save_dir("world_upgrade_purchase_186_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	_dir = _save.save_path.get_base_dir()
	SaveManager.instance = _save
	_session = SessionManager.new()
	_session.scene_change_enabled = false
	SessionManager.instance = _session
	_world.add_child(_session)
	_session._current_map = load("res://items/maps/praia.tres") as MapData
	_session._ready_peers.assign([1])
	_actor = PLAYER.instantiate() as Player
	_actor.name = "1"
	_world.add_child(_actor)
	_actor.set_physics_process(false)
	_actor.set_process(false)
	_actor.position = Vector3(0, 0, 1)
	_counter.set("map_id", "praia")
	_world.add_child(_counter)
	assert_true(_counter.is_in_group("upgrade_counters"))
	assert_true(_actor.is_alive())
	assert_true(_actor.is_local())
	state.connect("world_upgrade_result", _on_result)
	return true


func _on_result(request_id: int, upgrade_id: String, success: bool, message: String) -> void:
	_replies.append({"request_id": request_id, "upgrade_id": upgrade_id, "success": success,
		"message": message, "snapshot": GameState.instance.get_snapshot().duplicate(true)})


func _request(upgrade_id: String, path: NodePath, request_id: int = -1) -> Dictionary:
	if request_id < 0:
		_sequence += 1
		request_id = _sequence
	else:
		_sequence = maxi(_sequence, request_id)
	var count_before: int = _replies.size()
	GameState.instance.call("request_world_upgrade", upgrade_id, path, request_id)
	await wait_frames(3)
	assert_eq(_replies.size(), count_before + 1, "one correlated local reply per request")
	if _replies.size() <= count_before:
		return {}
	var reply: Dictionary = _replies.back()
	assert_eq(int(reply.get("request_id", -1)), request_id)
	assert_eq(str(reply.get("upgrade_id", "")), upgrade_id)
	return reply


func _reject(upgrade_id: String = "detector", path: NodePath = NodePath("")) -> void:
	var before: Dictionary = GameState.instance.get_snapshot().duplicate(true)
	var actual_path: NodePath = _counter.get_path() if path.is_empty() else path
	var reply: Dictionary = await _request(upgrade_id, actual_path)
	assert_false(bool(reply.get("success", true)), "must reject invalid purchase")
	assert_eq(GameState.instance.get_snapshot(), before, "denial cannot charge or change levels/progress")


func test_legacy_request_buy_upgrade_cannot_bypass_world_counter() -> void:
	# Intentionally no new-API/source guard: old endpoint must fail behaviorally.
	var state: GameState = GameState.instance
	var before: Dictionary = state.get_snapshot().duplicate(true)
	assert_true(state.get_upgrade_block_reason("detector").is_empty(), "enough money and no map prerequisite")
	state.request_buy_upgrade("detector")
	await wait_frames(2)
	assert_eq(state.team_money, int(before["team_money"]), "legacy request cannot charge")
	assert_eq(state.get_upgrade_level("detector"), 0, "legacy request cannot grant level")


func test_valid_purchase_request_one_charges_exact_cost_and_publishes_before_result() -> void:
	if not _fixture():
		return
	var cost: int = GameState.instance.get_next_upgrade_cost("detector")
	var money: int = GameState.instance.team_money
	watch_signals(GameState.instance)
	var reply: Dictionary = await _request("detector", _counter.get_path(), 1)
	assert_true(bool(reply.get("success", false)))
	assert_eq(GameState.instance.get_upgrade_level("detector"), 1)
	assert_eq(GameState.instance.team_money, money - cost)
	var at_result: Dictionary = reply.get("snapshot", {}) as Dictionary
	assert_eq(int(at_result.get("team_money", -1)), money - cost, "result observes applied state")
	assert_eq(int((at_result.get("upgrade_levels", {}) as Dictionary).get("detector", -1)), 1)
	assert_signal_emitted(GameState.instance, "state_synced")


func test_repeated_request_is_idempotent_but_same_id_other_product_is_denied() -> void:
	if not _fixture():
		return
	var reply: Dictionary = await _request("detector", _counter.get_path(), 1)
	assert_true(bool(reply.get("success", false)))
	var bought: Dictionary = GameState.instance.get_snapshot().duplicate(true)
	reply = await _request("detector", _counter.get_path(), 1)
	assert_true(bool(reply.get("success", false)), "same payload replays success without buying twice")
	assert_eq(GameState.instance.get_snapshot(), bought)
	reply = await _request("shovel", _counter.get_path(), 1)
	assert_false(bool(reply.get("success", true)), "request ID collision cannot buy another product")
	assert_eq(GameState.instance.get_snapshot(), bought)


func test_insufficient_money_maximum_and_required_map_follow_real_state() -> void:
	if not _fixture():
		return
	GameState.instance.load_snapshot({"team_money": 0})
	await _reject()
	GameState.instance.load_snapshot({"team_money": 1000000, "upgrade_levels": {"detector": GameState.instance.get_upgrade_max_level("detector")}})
	await _reject()
	GameState.instance.load_snapshot({"upgrade_levels": {"detector": 3}, "unlocked_maps": []})
	assert_eq(GameState.instance.get_next_upgrade_required_map("detector"), "ruinas")
	await _reject()
	GameState.instance.load_snapshot({"unlocked_maps": ["ruinas"]})
	var cost: int = GameState.instance.get_next_upgrade_cost("detector")
	var money: int = GameState.instance.team_money
	var reply: Dictionary = await _request("detector", _counter.get_path())
	assert_true(bool(reply.get("success", false)))
	assert_eq(GameState.instance.get_upgrade_level("detector"), 4)
	assert_eq(GameState.instance.team_money, money - cost)


func test_host_rejects_range_unready_wrong_map_authority_and_dead_actor() -> void:
	if not _fixture():
		return
	_actor.position.z = 3.0 # Strict 2.5, no generic Interactable slack.
	await _reject()
	_actor.position.z = 1.0
	_session._ready_peers.clear()
	await _reject()
	_session._ready_peers.assign([1])
	_counter.set("map_id", "campo")
	await _reject()
	_counter.set("map_id", "praia")
	_actor.set_multiplayer_authority(777)
	await _reject()
	_actor.set_multiplayer_authority(1)
	_actor.health = 0.0
	await _reject()


func test_real_layer_one_wall_blocks_host_line_of_sight() -> void:
	if not _fixture():
		return
	var wall: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(2, 3, 0.2)
	shape.shape = box
	wall.add_child(shape)
	_world.add_child(wall)
	wall.position = Vector3(0, 1, 0.5)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _reject()


func test_group_and_fake_method_plain_path_or_outside_scene_cannot_impersonate_counter() -> void:
	if not _fixture():
		return
	var fake: CounterFake = CounterFake.new()
	_world.add_child(fake)
	fake.add_to_group("upgrade_counters")
	await _reject("detector", fake.get_path())
	var plain: Node3D = Node3D.new()
	_world.add_child(plain)
	await _reject("detector", plain.get_path())
	await _reject("detector", NodePath("/root/NoSuchCounter186"))
	# Real script and group outside current_scene still cannot sell.
	_world.remove_child(_counter)
	get_tree().root.add_child(_counter)
	await _reject()
	_counter.free()
	_counter = null


func test_increasing_ids_correlate_distinct_results_and_downed_cannot_purchase() -> void:
	if not _fixture():
		return
	var first: Dictionary = await _request("detector", _counter.get_path())
	var second: Dictionary = await _request("shovel", _counter.get_path())
	assert_true(bool(first.get("success", false)))
	assert_true(bool(second.get("success", false)))
	assert_lt(int(first.get("request_id", -1)), int(second.get("request_id", -1)))
	assert_eq(GameState.instance.get_upgrade_level("detector"), 1)
	assert_eq(GameState.instance.get_upgrade_level("shovel"), 1)
	_actor.allow_downed = true
	_actor.enter_downed()
	assert_true(_actor.is_downed)
	await _reject("backpack")
