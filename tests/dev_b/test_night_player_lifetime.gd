extends GutTest

## Regressão #188: restore real após o Player liberar luzes/chip.
## Conferir stderr nativo mesmo quando todos os asserts do GUT passam.
const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/player.tscn")
const PRAIA: MapData = preload("res://items/maps/praia.tres")
const NIGHT_FIELDS: Array[String] = ["environment_root", "lantern_light", "detector_glow", "night_chip", "_map_id", "_cfg", "_amount", "_tween", "_world_env", "_env_original", "_env_copy", "_sky_material", "_sun", "_base", "_player"]

var _night: NightFx = null
var _world: Node3D = null
var _player: Player = null
var _environment: WorldEnvironment = null
var _original_environment: Environment = null
var _night_before: Dictionary = {}
var _save_before: Dictionary = {}
var _game_before: Dictionary = {}
var _settings_before: Dictionary = {}
var _session_before: Dictionary = {}
var _refs: Dictionary = {}
var _night_processing: bool = false
var _save_processing: bool = false
var _mouse_before: Input.MouseMode
var _configured: bool = false
var _case: String = "setup"


func before_each() -> void:
	_configured = false
	_night = NightFx.instance
	assert_not_null(_night, "real CoreNightFx required")
	if _night == null:
		return
	assert_false(_night.is_active(), "isolated process: do not interrupt an existing night")
	assert_true(get_tree().get_nodes_in_group(Player.LOCAL_GROUP).is_empty(), "no foreign local actor")
	assert_true(SessionManager.instance._rocket_payload.is_empty(), "no pending payload may be consumed by ready")
	assert_eq(str(SessionManager.instance.get_rocket_transition().get("phase", "")), "IDLE", "no active transition")
	var has_owned_refs: bool = false
	for field: String in ["lantern_light", "detector_glow", "night_chip"]:
		assert_null(_night.get(field), "no foreign NightFx owned reference: " + field)
		has_owned_refs = has_owned_refs or _night.get(field) != null
	if has_owned_refs or _night.is_active() or not get_tree().get_nodes_in_group(Player.LOCAL_GROUP).is_empty() or not SessionManager.instance._rocket_payload.is_empty() or str(SessionManager.instance.get_rocket_transition().get("phase", "")) != "IDLE":
		return
	for field: String in NIGHT_FIELDS:
		_night_before[field] = _night.get(field)
	_night_processing = _night.is_processing()
	_game_before = GameState.instance.get_snapshot().duplicate(true)
	_settings_before = SettingsManager.instance._values.duplicate(true)
	_session_before = {"map": SessionManager.instance._current_map, "night": SessionManager.instance._night}
	for field: String in ["save_path", "_base_path", "_slot", "_progress_applied", "_write_blocked", "play_time_s", "last_map"]:
		_save_before[field] = SaveManager.instance.get(field)
	_save_processing = SaveManager.instance.is_processing()
	_mouse_before = Input.mouse_mode
	_configured = true
	SaveManager.instance.set_process(false)
	SaveManager.instance.use_test_save_dir("night188_%d" % Time.get_ticks_usec())
	_world = Node3D.new()
	_world.name = "Night188World"
	add_child(_world)
	_environment = WorldEnvironment.new()
	_original_environment = Environment.new()
	_environment.environment = _original_environment
	_world.add_child(_environment)
	_night.environment_root = _world
	SessionManager.instance._current_map = PRAIA
	SessionManager.instance._night = true
	_player = PLAYER_SCENE.instantiate() as Player
	_world.add_child(_player)
	_player.set_physics_process(false)
	_player.set_process_input(false)
	_player.set_process_unhandled_input(false)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(_player.is_inside_tree(), "real Player ready in actual tree")
	assert_not_null(_player.camera)
	assert_not_null(_player.detector)
	assert_not_null(_player.get_node_or_null(^"HUD/TopChips"))
	_refs.clear()


func after_each() -> void:
	if not _configured:
		return
	printerr("NIGHT188 ", _case, " cleanup_restore_begin")
	_night.restore()
	if is_instance_valid(_world):
		_world.free()
	_world = null
	_player = null
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(NightFx.instance == _night, "autoload singleton was never swapped")
	SessionManager.instance._current_map = _session_before["map"] as MapData
	SessionManager.instance._night = bool(_session_before["night"])
	GameState.instance.load_snapshot(_game_before)
	for field: String in _save_before:
		SaveManager.instance.set(field, _save_before[field])
	SaveManager.instance.set_process(_save_processing)
	for field: String in NIGHT_FIELDS:
		_night.set(field, _night_before[field])
	_night.set_process(_night_processing)
	assert_eq(SettingsManager.instance._values, _settings_before, "settings were not modified")
	Input.mouse_mode = _mouse_before
	_night_before.clear()
	_save_before.clear()
	_refs.clear()
	_configured = false
	printerr("NIGHT188 ", _case, " cleanup_end")


func _start_real_night() -> bool:
	printerr("NIGHT188 ", _case, " start_begin")
	_night.start("praia", true)
	assert_true(_night.is_active())
	assert_true(_night.is_processing())
	assert_true(_environment.environment != _original_environment, "real environment copy installed")
	assert_true(_night._local_player() == _player)
	for field: String in ["lantern_light", "detector_glow", "night_chip"]:
		var object: Variant = _night.get(field)
		assert_true(is_instance_valid(object), "real owned child created: " + field)
		if not is_instance_valid(object):
			return false
		var node: Node = object as Node
		assert_true(_player.is_ancestor_of(node), "light/chip actually belongs to real Player")
		assert_true(node.is_inside_tree())
		_refs[field] = weakref(node)
	printerr("NIGHT188 ", _case, " start_end all_children_alive")
	return true


func _assert_retired() -> void:
	assert_false(_night.is_active())
	assert_false(_night.is_processing())
	assert_null(_night._player)
	assert_null(_night.lantern_light)
	assert_null(_night.detector_glow)
	assert_null(_night.night_chip)
	assert_true(_environment.environment == _original_environment, "same original Environment restored")
	for field: String in _refs:
		var reference: WeakRef = _refs[field] as WeakRef
		assert_null(reference.get_ref(), "retired real child: " + field)


func _free_player() -> void:
	var reference: WeakRef = weakref(_player)
	printerr("NIGHT188 ", _case, " player_free_begin")
	_player.free()
	_player = null
	assert_null(reference.get_ref())
	for field: String in _refs:
		var child_ref: WeakRef = _refs[field] as WeakRef
		assert_null(child_ref.get_ref(), "Player teardown removed child: " + field)
	printerr("NIGHT188 ", _case, " player_free_end")


func test_player_free_before_real_restore() -> void:
	_case = "free_before_restore"
	if not _configured or not _start_real_night():
		return
	_free_player()
	printerr("NIGHT188 ", _case, " local_player_lookup_begin")
	assert_null(_night._local_player(), "real cache lookup rejects destroyed actor")
	printerr("NIGHT188 ", _case, " local_player_lookup_end restore_begin")
	_night.restore()
	printerr("NIGHT188 ", _case, " restore_returned")
	await get_tree().process_frame
	await get_tree().process_frame
	_assert_retired()


func test_control_restore_before_player_free() -> void:
	_case = "restore_before_free"
	if not _configured or not _start_real_night():
		return
	printerr("NIGHT188 ", _case, " restore_begin actor_alive")
	_night.restore()
	printerr("NIGHT188 ", _case, " restore_returned")
	assert_true(is_instance_valid(_player), "restore does not destroy actor")
	await get_tree().process_frame
	await get_tree().process_frame
	_assert_retired()
	_free_player()


func test_repeated_restore_before_and_after_actor_teardown() -> void:
	_case = "repeat_restore"
	if not _configured or not _start_real_night():
		return
	printerr("NIGHT188 ", _case, " restore1_begin actor_alive")
	_night.restore()
	printerr("NIGHT188 ", _case, " restore2_begin actor_alive")
	_night.restore()
	await get_tree().process_frame
	await get_tree().process_frame
	_assert_retired()
	_free_player()
	printerr("NIGHT188 ", _case, " restore3_begin actor_gone")
	_night.restore()
	printerr("NIGHT188 ", _case, " restore4_begin actor_gone")
	_night.restore()
	await get_tree().process_frame
	_assert_retired()
	printerr("NIGHT188 ", _case, " repeats_end")
