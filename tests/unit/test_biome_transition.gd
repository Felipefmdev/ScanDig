extends GutTest

## #186 offline protocol fixture, not real scene travel or ENet validation.
## Real Session/Player/prepare/ACK/commit/cache. Hold only ACK transport, commit
## delivery and destructive generation cleanup; never invent another machine.
const PASSAGE: String = "res://gameplay/environment/boss_passage.gd"
const PLAYER: PackedScene = preload("res://gameplay/player/player.tscn")


class HeldSession extends SessionManager:
	var sent: Array[Dictionary] = []
	var held_acks: Array[int] = []
	var captures: int = 0
	var cleanup_calls: int = 0
	var disk_at_prepare: Dictionary = {}
	var synced_peers: Array[int] = []


	func _sync_peer_scene(peer_id: int) -> void:
		synced_peers.append(peer_id) # Transport spy; never rpc_id to fake offline peer.


	func _call_all(method: StringName, args: Array) -> void:
		sent.append({"method": method, "args": args.duplicate(true)})
		if method == &"_rpc_commit_rocket":
			return
		if method == &"_rpc_prepare_passage":
			var save: SaveManager = SaveManager.instance
			if save != null and FileAccess.file_exists(save.save_path):
				var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save.save_path))
				if parsed is Dictionary:
					disk_at_prepare = parsed as Dictionary
		super._call_all(method, args)


	func _send_rocket_prepare_ack(token: int) -> void:
		held_acks.append(token)


	func capture_rocket_payload(player: Player) -> bool:
		captures += 1
		return super.capture_rocket_payload(player)


	func _cleanup_rocket_generation() -> bool:
		cleanup_calls += 1
		return true # Spy only: test performs old-owner removal after real commit.


class FailingDisk extends SaveManager:
	var writes: int = 0


	func save_to_file(_data: Dictionary) -> Error:
		writes += 1
		return ERR_FILE_CANT_WRITE


var _original_session: SessionManager = null
var _original_save: SaveManager = null
var _original_scene: Node = null
var _original_mouse: int = Input.MOUSE_MODE_VISIBLE
var _snapshot: Dictionary = {}
var _world: Node3D = null
var _session: HeldSession = null
var _save: SaveManager = null
var _endpoint: Node3D = null
var _actor: Player = null
var _dir: String = ""


func before_each() -> void:
	_original_session = SessionManager.instance
	_original_save = SaveManager.instance
	_original_scene = get_tree().current_scene
	_original_mouse = Input.mouse_mode
	_snapshot = GameState.instance.get_snapshot().duplicate(true)
	GameState.instance.reset_state()
	GameState.instance.team_money = 4321
	GameState.instance.current_day = 7
	_dir = ""


func after_each() -> void:
	if is_instance_valid(_session):
		_session._abandon_rocket_transition()
	get_tree().current_scene = _original_scene
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
	_endpoint = null
	_actor = null
	await get_tree().process_frame


func _fixture(source_map: String = "praia", receipt: bool = true, held: HeldSession = null) -> bool:
	_session = held if held != null else HeldSession.new()
	var present: bool = _session.has_method("request_passage_travel")
	assert_true(present, "SessionManager.request_passage_travel must exist")
	if not present:
		_session.free()
		_session = null
		return false
	assert_true(_session.has_method("_rpc_prepare_passage"), "real generalized prepare must exist")
	if not _session.has_method("_rpc_prepare_passage"):
		_session.free()
		_session = null
		return false
	var exists: bool = ResourceLoader.exists(PASSAGE)
	assert_true(exists, "real boss_passage endpoint must exist")
	if not exists:
		_session.free()
		_session = null
		return false
	_world = Node3D.new()
	_world.name = "BiomeTransitionFixture"
	get_tree().root.add_child(_world)
	assert_true(_world.get_parent() == get_tree().root)
	get_tree().current_scene = _world
	assert_true(get_tree().current_scene == _world)
	_save = SaveManager.new()
	_save.use_test_save_dir("biome_transition_186_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	_dir = _save.save_path.get_base_dir()
	SaveManager.instance = _save
	SessionManager.instance = _session
	_session.scene_change_enabled = false
	_world.add_child(_session)
	_session._current_map = load("res://items/maps/%s.tres" % source_map) as MapData
	_session._ready_peers.assign([1]) # Internal readiness, not a loaded destination proof.
	if receipt:
		GameState.instance.unlocked_maps = ["campo"]
	var script: Script = load(PASSAGE) as Script
	assert_not_null(script)
	if script == null:
		return false
	_endpoint = script.new() as Node3D
	assert_not_null(_endpoint)
	if _endpoint == null:
		return false
	_endpoint.set("route_id", "campo")
	_endpoint.set("source_map", source_map)
	_world.add_child(_endpoint)
	_actor = _spawn_owner()
	_actor.position = Vector3(0, 0, 1)
	assert_true(_actor.is_alive())
	assert_true(_actor.is_local())
	assert_true(_session.is_peer_scene_ready(1))
	assert_lte(_actor.global_position.distance_to(_endpoint.global_position), 5.0)
	assert_true(_save.is_progress_applied())
	return true


func _spawn_owner() -> Player:
	var player: Player = PLAYER.instantiate() as Player
	player.name = "1"
	_world.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	return player


func _request(peer_id: int = 1) -> bool:
	var result: Variant = _session.call("request_passage_travel", _endpoint, peer_id)
	assert_eq(typeof(result), TYPE_BOOL)
	return result is bool and bool(result)


func _phase() -> String:
	return str(_session.get_rocket_transition().get("phase", "INVALID"))


func _prepare() -> int:
	assert_true(_request())
	assert_eq(_phase(), "PREPARING")
	var transition: Dictionary = _session.get_rocket_transition()
	assert_eq(transition.get("roster", []), [1])
	assert_eq(str(transition.get("destination", "")), "campo", "explicit destination in shared transition getter")
	var token: int = int(transition.get("token", 0))
	assert_gt(token, 0)
	assert_eq(_session.held_acks, [token], "only ACK emitted by real prepare is held")
	assert_eq(_session.captures, 1)
	assert_eq(_session.cleanup_calls, 0)
	assert_eq(transition.get("acked", []), [])
	assert_eq(_session.get_current_map().id, "praia", "prepare is not commit")
	assert_false(_actor.is_processing_input())
	assert_false(_actor.is_processing_unhandled_input())
	assert_true((_session.disk_at_prepare.get("unlocked_maps", []) as Array).has("campo"), "real disk save precedes prepare")
	assert_eq(int(_session.disk_at_prepare.get("team_money", -1)), 4321)
	assert_eq(GameState.instance.current_day, 7)
	return token


func _assert_rejected_without_capture() -> void:
	assert_false(_request())
	assert_eq(_phase(), "IDLE")
	assert_eq(_session.captures, 0)
	assert_eq(_session.cleanup_calls, 0)
	assert_true(_session.held_acks.is_empty())
	assert_true(_session._rocket_payload.is_empty())
	assert_eq(GameState.instance.team_money, 4321)
	assert_eq(GameState.instance.current_day, 7)


func test_closed_receipt_rejects_even_with_boss_without_capture_or_charge() -> void:
	if not _fixture("praia", false):
		return
	GameState.instance.defeated_bosses = ["king_crab"]
	_assert_rejected_without_capture()
	assert_false(GameState.instance.unlocked_maps.has("campo"))


func test_real_ack_commit_and_replacement_preserve_post_ack_damage_once() -> void:
	if not _fixture():
		return
	var item: CarriedItem = CarriedItem.new()
	item.tool_id = "lanterna_magnesio"
	item.charges = 2
	_actor.inventory.slots[1] = item
	var token: int = _prepare()
	assert_true(_session._accept_rocket_prepare_ack(1, token), "deliver held real ACK")
	assert_eq(_phase(), "COMMITTING")
	assert_eq(_session.cleanup_calls, 1)
	assert_eq(_session.sent.back()["method"], &"_rpc_commit_rocket")
	var initial: float = _actor.health
	assert_almost_eq(initial, 100.0, 0.001, "production ready starts owner at 100")
	_actor.apply_damage(25.0)
	assert_almost_eq(_actor.health, initial - 25.0, 0.001, "real hit after ACK before held commit")
	_session._rpc_commit_rocket(token)
	assert_eq(_session.get_current_map().id, "campo")
	assert_eq(_session.captures, 1)
	# Actual old-owner tree_exit runs its payload observer before replacement ready.
	_actor.free()
	_actor = null
	var replacement: Player = _spawn_owner()
	assert_true(replacement.is_node_ready())
	assert_almost_eq(replacement.health, initial - 25.0, 0.001, "real ready restores damage; no expected-health setter")
	assert_same(replacement.inventory.slots[1], item)
	assert_false(_session.restore_rocket_payload(replacement), "ready already consumed cache once")
	assert_eq(_phase(), "IDLE")
	assert_eq(GameState.instance.team_money, 4321)
	assert_eq(GameState.instance.current_day, 7)
	assert_false(_session.scene_change_enabled, "no real scene/arrival-anchor claim")


func test_return_uses_same_campo_receipt_from_campo_to_praia() -> void:
	if not _fixture("campo"):
		return
	assert_true(GameState.MAP_UNLOCK_BOSSES.has("campo"))
	assert_eq(str(GameState.MAP_UNLOCK_BOSSES["campo"]["source_map"]), "praia")
	assert_true(_request())
	var transition: Dictionary = _session.get_rocket_transition()
	assert_eq(_phase(), "PREPARING")
	assert_eq(str(transition.get("destination", "")), "praia")
	assert_eq(_session.held_acks.size(), 1)
	var token: int = int(transition.get("token", 0))
	assert_true(_session._accept_rocket_prepare_ack(1, token))
	_session._rpc_commit_rocket(token)
	assert_eq(_session.get_current_map().id, "praia")
	assert_true(GameState.instance.unlocked_maps.has("campo"))
	assert_false(GameState.instance.unlocked_maps.has("praia"), "return needs no second receipt")
	assert_eq(GameState.instance.team_money, 4321)
	assert_eq(GameState.instance.current_day, 7)


func test_cancel_retry_rejects_stale_ack_prepare_and_commit() -> void:
	if not _fixture():
		return
	var input_before: bool = _actor.is_processing_input()
	var unhandled_before: bool = _actor.is_processing_unhandled_input()
	assert_true(unhandled_before, "real Player has an active unhandled-input handler")
	var old_token: int = _prepare()
	assert_true(_session.cancel_rocket_transition(old_token))
	assert_eq(_phase(), "IDLE")
	assert_true(_session._rocket_payload.is_empty())
	assert_eq(_actor.is_processing_input(), input_before, "restore the actual pre-prepare input flag")
	assert_eq(_actor.is_processing_unhandled_input(), unhandled_before, "restore the active gameplay input handler")
	assert_false(_session._accept_rocket_prepare_ack(1, old_token))
	assert_true(_request())
	var token: int = int(_session.get_rocket_transition()["token"])
	assert_gt(token, old_token)
	assert_eq(_session.captures, 2)
	assert_false(_session._accept_rocket_prepare_ack(1, old_token))
	_session.call("_rpc_prepare_passage", old_token, [1], "campo", "praia")
	_session._rpc_commit_rocket(old_token)
	assert_eq(_phase(), "PREPARING")
	assert_eq(_session.captures, 2, "stale prepare cannot recapture")
	assert_eq(_session.cleanup_calls, 0)
	assert_eq(_session.get_current_map().id, "praia")
	assert_true(_session.cancel_rocket_transition(token))


func test_range_missing_ready_missing_actor_and_downed_reject() -> void:
	if not _fixture():
		return
	_actor.position = Vector3(20, 0, 0)
	_assert_rejected_without_capture()
	_actor.position = Vector3(0, 0, 1)
	_session._ready_peers.clear()
	_assert_rejected_without_capture()
	_session._ready_peers.assign([1])
	_actor.free()
	_actor = null
	_assert_rejected_without_capture()
	_actor = _spawn_owner()
	_actor.position = Vector3(0, 0, 1)
	_actor.allow_downed = true
	_actor.enter_downed()
	assert_true(_actor.is_downed)
	_assert_rejected_without_capture()


func test_busy_transition_rejects_second_request_without_recapture() -> void:
	if not _fixture():
		return
	var token: int = _prepare()
	assert_false(_request())
	assert_eq(int(_session.get_rocket_transition()["token"]), token)
	assert_eq(_session.captures, 1)
	assert_eq(_session.cleanup_calls, 0)
	assert_eq(_session.held_acks, [token])
	assert_eq(GameState.instance.team_money, 4321)
	assert_eq(GameState.instance.current_day, 7)


func test_noncanonical_endpoint_source_and_route_reject_without_capture() -> void:
	if not _fixture():
		return
	_endpoint.set("source_map", "ruinas")
	_assert_rejected_without_capture()
	_endpoint.set("source_map", "praia")
	_endpoint.set("route_id", "lua")
	_assert_rejected_without_capture()
	_endpoint.set("route_id", "campo")
	var outsider: Node3D = Node3D.new()
	_world.add_child(outsider)
	assert_false(bool(_session.call("request_passage_travel", outsider, 1)), "plain Node3D is not a real passage")
	assert_eq(_session.captures, 0)


func _loading_api(recovery: bool = false) -> bool:
	# Check production, not HeldSession: its new transport seam exists before
	# the base implementation does, and must not conceal an absent production API.
	var production: SessionManager = SessionManager.new()
	var methods: Array[String] = ["get_passage_loading", "_sync_peer_scene"]
	if recovery:
		methods.append_array(["fail_passage_transition", "_rpc_recover_passage"])
	var present: bool = true
	for method: String in methods:
		var found: bool = production.has_method(method)
		assert_true(found, "production transition API must exist: " + method)
		present = present and found
	production.free()
	return present


func _loading() -> Dictionary:
	var result: Variant = _session.call("get_passage_loading")
	assert_true(result is Dictionary)
	return result as Dictionary if result is Dictionary else {}


func _commit_held_transition() -> int:
	var token: int = _prepare()
	assert_true(_session._accept_rocket_prepare_ack(1, token))
	assert_eq(_phase(), "COMMITTING")
	assert_eq(_session.cleanup_calls, 1)
	_session._rpc_commit_rocket(token)
	assert_eq(_session.get_current_map().id, "campo")
	return token


func test_loading_survives_owner_restore_and_defers_late_join_until_roster_ready() -> void:
	if not _loading_api() or not _fixture():
		return
	var token: int = _commit_held_transition()
	var loading: Dictionary = _loading()
	assert_true(bool(loading.get("active", false)))
	assert_eq(int(loading.get("token", 0)), token)
	assert_eq(loading.get("roster", []), [1])
	_session._on_peer_connected(777)
	assert_true(_session.synced_peers.is_empty(), "late join cannot sync during committed loading")
	assert_true((_loading().get("waiting_peers", []) as Array).has(777), "late join is queued, not added to frozen roster")
	_actor.free()
	_actor = _spawn_owner()
	assert_eq(_phase(), "IDLE", "owner restore finishes payload transaction only")
	assert_true(bool(_loading().get("active", false)), "roster-ready barrier outlives payload restore")
	assert_true(_session.synced_peers.is_empty())
	_session._mark_ready(1, "campo")
	assert_false(bool(_loading().get("active", true)))
	assert_eq(_session.synced_peers, [777], "only release queued scene sync after original roster ready")
	_session._mark_ready(1, "campo")
	assert_eq(_session.synced_peers, [777], "duplicate ready cannot release twice")


func test_failed_loading_preserves_damaged_payload_until_next_real_owner_ready() -> void:
	if not _loading_api(true) or not _fixture():
		return
	var item: CarriedItem = CarriedItem.new()
	item.tool_id = "lanterna_magnesio"
	item.charges = 2
	_actor.inventory.slots[1] = item
	var token: int = _commit_held_transition()
	_actor.apply_damage(25.0)
	assert_almost_eq(_actor.health, 75.0, 0.001, "real damage during committed loading")
	watch_signals(GameState.instance)
	assert_true(bool(_session.call("fail_passage_transition", token, "fixture load failure")))
	assert_null(_session.get_current_map(), "recover to lobby without ending expedition/day")
	assert_true(GameState.instance.unlocked_maps.has("campo"))
	assert_eq(GameState.instance.team_money, 4321)
	assert_eq(GameState.instance.current_day, 7)
	assert_signal_not_emitted(GameState.instance, "game_victory")
	assert_almost_eq(float(_session._rocket_payload.get("health", -1.0)), 75.0, 0.001)
	var recovery_slots: Array = _session._rocket_payload.get("slots", []) as Array
	assert_gt(recovery_slots.size(), 1, "recovery retains inventory slots")
	if recovery_slots.size() > 1:
		assert_same(recovery_slots[1], item)
	# Adapter-only next expedition entry. Leave old owner alive briefly to prove
	# an otherwise valid new request cannot replace a pending recovery cache.
	_session._rpc_enter_map("praia")
	_session._mark_ready(1, "praia")
	var captures: int = _session.captures
	assert_false(_request(), "pending recovery cache blocks new capture")
	assert_eq(_session.captures, captures)
	_actor.free()
	_actor = _spawn_owner()
	assert_almost_eq(_actor.health, 75.0, 0.001, "new real ready restores recovery cache")
	assert_same(_actor.inventory.slots[1], item)
	assert_eq(_actor.inventory.slots.count(item), 1, "one physical carried reference after recovery")
	assert_false(_session.restore_rocket_payload(_actor), "recovery payload consumed once")
	assert_true(_session._rocket_payload.is_empty())
	assert_eq(GameState.instance.current_day, 7)
	assert_false(_session.scene_change_enabled, "not crash recovery or actual loading")


func test_stale_failure_and_recovery_cannot_change_current_committed_loading() -> void:
	if not _loading_api(true) or not _fixture():
		return
	var token: int = _commit_held_transition()
	var loading: Dictionary = _loading().duplicate(true)
	var payload: Dictionary = _session._rocket_payload.duplicate()
	var state: Dictionary = GameState.instance.get_snapshot().duplicate(true)
	assert_false(bool(_session.call("fail_passage_transition", token + 100, "stale failure")))
	_session.call("_rpc_recover_passage", token + 100, "stale recovery")
	assert_eq(_loading(), loading)
	assert_eq(_session._rocket_payload, payload)
	assert_eq(GameState.instance.get_snapshot(), state)
	assert_eq(_session.get_current_map().id, "campo")
	assert_eq(_phase(), "COMMITTING")


func test_real_nearby_enemy_and_disk_failure_reject_before_prepare_or_capture() -> void:
	if not _fixture():
		return
	var enemy_scene: PackedScene = load("res://gameplay/enemies/crab/crab.tscn") as PackedScene
	assert_not_null(enemy_scene)
	if enemy_scene == null:
		return
	var enemy: EnemyBase = enemy_scene.instantiate() as EnemyBase
	assert_not_null(enemy)
	if enemy == null:
		return
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	_world.add_child(enemy)
	enemy.position = Vector3(2, 0, 0)
	# Drain deferred spawn/A11y listeners while the real enemy is still alive.
	await get_tree().process_frame
	assert_true(enemy.is_alive())
	assert_true(enemy.is_in_group(EnemyBase.GROUP))
	_assert_rejected_without_capture()
	assert_true(_session.sent.is_empty(), "threat cannot emit prepare")
	enemy.free()
	var failure: FailingDisk = FailingDisk.new()
	failure.set_save_path(_dir.path_join("failure.json"))
	SaveManager.instance = failure
	_save.free()
	_save = failure
	assert_true(_save.is_progress_applied())
	_assert_rejected_without_capture()
	assert_eq(failure.writes, 1, "save fails through actual save_game disk seam")
	assert_true(_session.sent.is_empty(), "failed save cannot emit prepare")
	assert_true(GameState.instance.unlocked_maps.has("campo"))


func _scene_failure_adapter() -> HeldSession:
	var production: SessionManager = SessionManager.new()
	var present: bool = production.has_method("_perform_scene_change")
	production.free()
	assert_true(present, "production scene-change error seam must exist")
	if not present:
		return null
	# Compile only after the base method exists: a static super call to an
	# absent future API would make the entire frozen test file fail to parse.
	var adapter: GDScript = GDScript.new()
	adapter.source_code = "extends \"res://tests/unit/test_biome_transition.gd\".HeldSession\nvar fail_scene_change: bool = false\nvar attempted_scenes: Array[String] = []\nfunc _perform_scene_change(scene_path: String) -> Error:\n\tattempted_scenes.append(scene_path)\n\tif fail_scene_change:\n\t\treturn ERR_CANT_OPEN\n\treturn super._perform_scene_change(scene_path)\n"
	assert_eq(adapter.reload(), OK, "guarded adapter must compile against real base seam")
	if not adapter.can_instantiate():
		return null
	return adapter.new() as HeldSession


func _assert_recovery_cache_after_loading_error(item: CarriedItem) -> void:
	assert_null(_session.get_current_map(), "failed loading recovers to lobby")
	assert_false(bool(_loading().get("active", true)))
	assert_eq(_phase(), "IDLE")
	assert_true(GameState.instance.unlocked_maps.has("campo"))
	assert_eq(GameState.instance.team_money, 4321)
	assert_eq(GameState.instance.current_day, 7, "loading failure never ends a day")
	assert_almost_eq(float(_session._rocket_payload.get("health", -1.0)), 75.0, 0.001)
	var slots: Array = _session._rocket_payload.get("slots", []) as Array
	assert_eq(slots.count(item), 1, "retain one carried reference in recovery memory")
	assert_signal_not_emitted(GameState.instance, "game_victory")


func test_real_thirty_second_commit_timeout_recovers_lobby_and_damaged_cache() -> void:
	if not _loading_api(true) or not _fixture():
		return
	var item: CarriedItem = CarriedItem.new()
	item.tool_id = "lanterna_magnesio"
	_actor.inventory.slots[1] = item
	_commit_held_transition()
	_actor.apply_damage(25.0)
	assert_almost_eq(_actor.health, 75.0, 0.001)
	assert_true(bool(_loading().get("active", false)))
	watch_signals(GameState.instance)
	# No timestamp/clock/time_scale override and no explicit fail invocation.
	# The real Session._process must enforce the 30s committed-loading timeout.
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 30250:
		await get_tree().process_frame
	assert_gte(Time.get_ticks_msec() - started, 30000)
	_assert_recovery_cache_after_loading_error(item)
	assert_false(_session.scene_change_enabled, "timeout is an offline frame-adapter proof")


func test_deferred_scene_change_error_recovers_without_real_scene_replacement() -> void:
	if not _loading_api(true):
		return
	var adapter: HeldSession = _scene_failure_adapter()
	if adapter == null:
		return
	if not _fixture("praia", true, adapter):
		return
	var item: CarriedItem = CarriedItem.new()
	item.tool_id = "lanterna_magnesio"
	_actor.inventory.slots[1] = item
	var token: int = _prepare()
	assert_true(_session._accept_rocket_prepare_ack(1, token))
	_actor.apply_damage(25.0)
	assert_almost_eq(_actor.health, 75.0, 0.001)
	_session.set("fail_scene_change", true)
	# Only this test enables the change request. Every actual attempt, including
	# lobby recovery, is intercepted by the failing override, never the engine.
	_session.scene_change_enabled = true
	watch_signals(GameState.instance)
	_session._rpc_commit_rocket(token)
	await wait_frames(4)
	var attempts: Array = _session.get("attempted_scenes") as Array
	assert_true(attempts.has("res://world/map_campo.tscn"), "deferred seam received actual destination")
	_assert_recovery_cache_after_loading_error(item)
	assert_true(get_tree().current_scene == _world, "adapter prevented all actual scene replacement")
	_session.scene_change_enabled = false
