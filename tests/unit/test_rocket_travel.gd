extends GutTest

var _snapshot: Dictionary
var _session: SessionManager
var _actor: Player

func before_each() -> void:
	_snapshot = GameState.instance.get_snapshot()
	_session = SessionManager.new()
	_session.scene_change_enabled = false
	add_child_autofree(_session)
	_session._current_map = load("res://items/maps/cratera.tres") as MapData
	_session._pending_summary = {"day":7,"map_id":"cratera","entries":[{"name":"Existing find","value":42}],"money_start":100}
	GameState.instance.completed_quests = []
	_session._ready_peers = [1]
	_actor = load("res://gameplay/player/player.tscn").instantiate() as Player
	_actor.name = "1"
	add_child_autofree(_actor)
	_actor.set_physics_process(false)
	_actor.set_process(false)
	await get_tree().process_frame
	await get_tree().process_frame

func after_each() -> void:
	GameState.instance.apply_snapshot(_snapshot)
	await get_tree().process_frame
	await get_tree().process_frame

func _await_rocket_commit() -> void:
	for frame: int in range(120):
		if _session.get_current_map() != null and _session.get_current_map().id=="lua": return
		await get_tree().process_frame

func _has_travel() -> bool:
	assert_true(_session.has_method("request_rocket_travel"), "Dedicated travel must preserve the active expedition")
	return _session.has_method("request_rocket_travel")

func test_missing_persisted_repair_cannot_travel() -> void:
	if not _has_travel(): return
	assert_false(bool(_session.call("request_rocket_travel")))
	assert_eq(_session.get_current_map().id,"cratera")

func test_travel_preserves_day_money_summary_and_does_not_restart_expedition() -> void:
	if not _has_travel(): return
	GameState.instance.completed_quests = ["vega_foguete"]
	var day: int = GameState.instance.current_day
	var money: int = GameState.instance.team_money
	var summary: Dictionary = _session._pending_summary.duplicate(true)
	watch_signals(_session)
	_session._ready_peers = [1,22]
	assert_true(bool(_session.call("request_rocket_travel")))
	await _await_rocket_commit()
	assert_eq(_session.get_current_map().id,"lua")
	assert_eq(GameState.instance.current_day,day)
	assert_eq(GameState.instance.team_money,money)
	assert_eq(_session._pending_summary,summary)
	assert_eq(_session.get_sync_scene_args(),["lua",false])
	assert_true(_session._ready_peers.is_empty())
	assert_signal_not_emitted(_session,"expedition_started")
	assert_signal_not_emitted(_session,"expedition_ended")
	assert_signal_not_emitted(_session,"expedition_ending")
	assert_false(bool(_session.call("request_rocket_travel")), "Repeat requests must not start another transition")

func test_base_cannot_launch_lua_even_after_repair() -> void:
	GameState.instance.completed_quests = ["vega_foguete"]
	assert_false(_session.can_start_map("lua"),"Lua is reached by rocket, not the base's departure menu")

func test_lua_is_not_a_base_departure_offer() -> void:
	for map: MapData in _session.get_available_maps():
		assert_ne(map.id,"lua","Narrative destination must not appear as a purchasable base map")
