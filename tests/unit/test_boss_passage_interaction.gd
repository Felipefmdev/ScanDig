extends GutTest


func test_delivered_gate_geometry_does_not_occlude_its_own_focus_but_external_wall_does() -> void:
	var f: Dictionary = _fixture()
	if f.is_empty(): return
	f.passage.free()
	var gate: Node3D = (load("res://gameplay/environment/boss_passage.tscn") as PackedScene).instantiate()
	gate.set("route_id", "campo")
	gate.set("source_map", "praia")
	_world.add_child(gate)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(int(gate.call("validate_request", 1)), OK, "real gate must not block its own LOS")
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
	assert_eq(int(gate.call("validate_request", 1)), ERR_UNAUTHORIZED, "external occluder remains enforced")

## #186 host-local interaction boundary. No ENet/travel claim; no second E on an
## already-open route until the travel API is defined. Missing source is RED, not parse.
const SOURCE: String = "res://gameplay/environment/boss_passage.gd"
const PLAYER: PackedScene = preload("res://gameplay/player/player.tscn")

class DiskAdapter extends SaveManager:
	var writes: int = 0
	var fail_write: bool = false
	func save_to_file(data: Dictionary) -> Error:
		writes += 1
		return ERR_FILE_CANT_WRITE if fail_write else super.save_to_file(data)

var _original_session: SessionManager
var _original_save: SaveManager
var _original_scene: Node
var _snapshot: Dictionary
var _world: Node3D
var _session: SessionManager
var _save: DiskAdapter
var _dir: String = ""


func before_each() -> void:
	_original_session = SessionManager.instance
	_original_save = SaveManager.instance
	_original_scene = get_tree().current_scene
	_snapshot = GameState.instance.get_snapshot().duplicate(true)
	GameState.instance.reset_state()
	GameState.instance.team_money = 0
	GameState.instance.current_day = 7


func after_each() -> void:
	get_tree().current_scene = _original_scene
	# Free fixture users before restoring static services; original services survive.
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
	_world = null
	_session = null
	_save = null
	_dir = ""
	await get_tree().process_frame


func _fixture(map_id: String = "praia", source_map: String = "praia", route_id: String = "campo") -> Dictionary:
	var exists: bool = ResourceLoader.exists(SOURCE)
	assert_true(exists, "Production boss_passage.gd must exist")
	if not exists:
		return {}
	var source: Script = load(SOURCE) as Script
	assert_not_null(source)
	if source == null:
		return {}
	_world = Node3D.new()
	_world.name = "PassageTestWorld"
	get_tree().root.add_child(_world)
	get_tree().current_scene = _world
	assert_true(_world.get_parent() == get_tree().root, "Fixture scene must be a direct root child")
	assert_true(get_tree().current_scene == _world, "Fixture current_scene assignment must succeed")
	_save = DiskAdapter.new()
	_save.use_test_save_dir("boss_passage_interaction_186_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	_dir = _save.save_path.get_base_dir()
	SaveManager.instance = _save
	_session = SessionManager.new()
	_session.scene_change_enabled = false
	SessionManager.instance = _session
	_world.add_child(_session)
	_session._current_map = load("res://items/maps/%s.tres" % map_id) as MapData
	_session._ready_peers.assign([1])
	var player: Player = PLAYER.instantiate() as Player
	player.name = "1"
	player.process_mode = Node.PROCESS_MODE_DISABLED
	_world.add_child(player)
	player.position = Vector3(0, 0, 1)
	player.health = player.max_health
	player.is_downed = false
	var passage: Node = source.new() as Node
	assert_true(passage is Interactable, "Passage inherits Interactable")
	assert_true(passage.has_method("host_request_interact"))
	if not (passage is Interactable) or not passage.has_method("host_request_interact"):
		passage.free()
		return {}
	passage.set("route_id", route_id)
	passage.set("source_map", source_map)
	_world.add_child(passage)
	return {"passage": passage, "player": player}


func _request(f: Dictionary, peer_id: int = 1) -> int:
	var value: Variant = f.passage.call("host_request_interact", peer_id)
	assert_eq(typeof(value), TYPE_INT, "Interaction returns an Error, not bool/null")
	return int(value) if value is int else FAILED


func _assert_untouched() -> void:
	assert_false(GameState.instance.unlocked_maps.has("campo"))
	assert_eq(_save.writes, 0, "Rejected request cannot reach persistence")
	assert_eq(GameState.instance.team_money, 0)
	assert_eq(GameState.instance.current_day, 7)


func test_first_e_opens_real_save_without_money_or_travel() -> void:
	var f: Dictionary = _fixture()
	if f.is_empty(): return
	GameState.instance.defeated_bosses.assign(["king_crab"])
	assert_true(_world.is_ancestor_of(f.passage))
	assert_eq(f.passage.get("focus_offset"), Vector3(0, .6, 0))
	assert_eq(float(f.passage.get("interact_range")), 2.5)
	watch_signals(_session)
	assert_eq(_request(f), OK)
	assert_true(GameState.instance.unlocked_maps.has("campo"))
	assert_eq(_save.writes, 1)
	assert_true(FileAccess.file_exists(_save.save_path), "Opening reaches real isolated disk")
	if FileAccess.file_exists(_save.save_path):
		var disk: Variant = JSON.parse_string(FileAccess.get_file_as_string(_save.save_path))
		assert_true(disk is Dictionary)
		if disk is Dictionary:
			assert_true((disk.get("unlocked_maps", []) as Array).has("campo"))
	assert_eq(GameState.instance.team_money, 0, "No access fee, even with no money")
	assert_eq(GameState.instance.current_day, 7)
	await wait_frames(3)
	assert_eq(_session.get_current_map().id, "praia", "First E opens only")
	assert_true(get_tree().current_scene == _world)
	assert_signal_not_emitted(_session, "scene_changing")
	assert_signal_not_emitted(_session, "expedition_ending")


func test_no_credential_rejects_without_save() -> void:
	var f: Dictionary = _fixture()
	if f.is_empty(): return
	assert_eq(_request(f), ERR_UNAUTHORIZED)
	_assert_untouched()


func test_failed_save_keeps_route_closed_and_same_first_e_can_retry() -> void:
	var f: Dictionary = _fixture()
	if f.is_empty(): return
	GameState.instance.defeated_bosses.assign(["king_crab"])
	_save.fail_write = true
	assert_eq(_request(f), ERR_FILE_CANT_WRITE)
	assert_eq(_save.writes, 1)
	assert_false(GameState.instance.unlocked_maps.has("campo"))
	assert_true(GameState.instance.defeated_bosses.has("king_crab"))
	assert_eq(_session.get_current_map().id, "praia")
	_save.fail_write = false
	assert_eq(_request(f), OK, "Retry after failure is still a first opening, not travel")
	assert_eq(_save.writes, 2)
	assert_true(GameState.instance.unlocked_maps.has("campo"))
	assert_eq(GameState.instance.team_money, 0)
	assert_eq(_session.get_current_map().id, "praia")


func test_missing_actor_unready_dead_downed_or_wrong_authority_cannot_open() -> void:
	var f: Dictionary = _fixture()
	if f.is_empty(): return
	GameState.instance.defeated_bosses.assign(["king_crab"])
	_session._ready_peers.append(777)
	assert_ne(_request(f, 777), OK, "No Player for ready peer; no host fallback")
	assert_ne(_request(f, 0), OK, "Invalid peer cannot resolve to local actor")
	_session._ready_peers.clear()
	assert_ne(_request(f), OK, "Existing Player is not enough without scene-ready")
	_session._ready_peers.assign([1])
	f.player.health = 0.0
	assert_ne(_request(f), OK, "Dead Player rejected")
	f.player.health = f.player.max_health
	f.player.is_downed = true
	assert_ne(_request(f), OK, "Downed with restored health still rejected")
	f.player.is_downed = false
	f.player.set_multiplayer_authority(777)
	assert_ne(_request(f), OK, "Player name alone does not establish owner authority")
	f.player.set_multiplayer_authority(1)
	_assert_untouched()


func test_outside_strict_range_and_blocked_los_reject() -> void:
	var f: Dictionary = _fixture()
	if f.is_empty(): return
	GameState.instance.defeated_bosses.assign(["king_crab"])
	f.player.position.z = 3.0
	assert_ne(_request(f), OK, "No generic Interactable range slack at the passage")
	f.player.position.z = 1.0
	var wall: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(2, 3, .2)
	shape.shape = box
	wall.add_child(shape)
	_world.add_child(wall)
	wall.position = Vector3(0, 1, .5)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_ne(_request(f), OK, "Real layer1 wall occludes head-to-focus LOS")
	_assert_untouched()


func test_invalid_route_or_source_map_cannot_open_any_receipt() -> void:
	var f: Dictionary = _fixture()
	if f.is_empty(): return
	GameState.instance.defeated_bosses.assign(["king_crab"])
	for invalid: String in ["", "lua", "praia", "Campo", "../campo"]:
		f.passage.set("route_id", invalid)
		assert_eq(_request(f), ERR_INVALID_PARAMETER, invalid)
	f.passage.set("route_id", "campo")
	f.passage.set("source_map", "ruinas")
	assert_eq(_request(f), ERR_INVALID_PARAMETER, "Canonical route side must match current map")
	_assert_untouched()


func test_return_endpoint_cannot_first_open_route_or_substitute_destination_receipt() -> void:
	var f: Dictionary = _fixture("campo", "campo", "campo")
	if f.is_empty(): return
	GameState.instance.defeated_bosses.assign(["king_crab"])
	# Praia is initially accessible; it is not the Praia<->Campo route receipt.
	assert_ne(_request(f), OK, "Closed route opens only at its original Praia endpoint")
	_assert_untouched()


func test_existing_fixed_receipt_prompts_the_correct_destination_without_passive_save() -> void:
	var f: Dictionary = _fixture()
	if f.is_empty(): return
	GameState.instance.unlocked_maps.assign(["campo"])
	var passage: Interactable = f.passage as Interactable
	assert_eq(str(passage.get("route_id")), "campo")
	assert_eq(passage.get_prompt(), "[E] Viajar para Campo Antigo")
	# Reading the same receipt on the return side never initiates travel.
	_session._current_map = load("res://items/maps/campo.tres") as MapData
	passage.set("source_map", "campo")
	assert_eq(str(passage.get("route_id")), "campo", "Return receipt is campo, never destination praia")
	assert_eq(passage.get_prompt(), "[E] Viajar para Praia")
	await wait_frames(2)
	assert_eq(_save.writes, 0, "Reading/displaying an existing receipt must not save again")
	assert_eq(GameState.instance.unlocked_maps.size(), 1)


func test_passage_outside_current_scene_is_not_a_canonical_endpoint() -> void:
	var f: Dictionary = _fixture()
	if f.is_empty(): return
	GameState.instance.defeated_bosses.assign(["king_crab"])
	_world.remove_child(f.passage)
	add_child(f.passage)
	assert_ne(_request(f), OK)
	remove_child(f.passage)
	f.passage.free()
	_assert_untouched()
