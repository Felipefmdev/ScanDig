extends GutTest

var snapshot: Dictionary = {}

func before_each() -> void:
	snapshot = GameState.instance.get_snapshot()
	GameState.instance.completed_quests = ["vega_foguete"]

func after_each() -> void:
	GameState.instance.apply_snapshot(snapshot)
	await get_tree().process_frame
	await get_tree().process_frame

func _await_rocket_commit(session: SessionManager) -> void:
	for frame: int in range(120):
		if session.get_current_map() != null and session.get_current_map().id=="lua": return
		await get_tree().process_frame

func _fixture(save_ok: bool) -> Dictionary:
	var path: String = "res://gameplay/quests/cratera/crater_rocket_station.gd"
	var source: GDScript = GDScript.new()
	# Only the disk adapter is substituted; real station, actors and travel execute.
	source.source_code = "extends \"%s\"\nvar save_ok: bool = true\nvar save_calls: int = 0\nfunc _save_before_departure() -> bool:\n\tsave_calls += 1\n\treturn save_ok\n" % path
	assert_eq(source.reload(),OK)
	var station: Node3D = source.new() as Node3D
	station.set("save_ok",save_ok)
	add_child_autofree(station)
	var placement: Node3D = load("res://gameplay/environment/crater_rocket.gd").new() as Node3D
	placement.position = Vector3(-23,0,21)
	add_child_autofree(placement)
	var session: SessionManager = SessionManager.new()
	session.scene_change_enabled = false
	add_child_autofree(session)
	session._current_map = load("res://items/maps/cratera.tres") as MapData
	session._ready_peers = [1]
	assert_true(station.call("configure",placement,session))
	var player: Player = load("res://gameplay/player/player.tscn").instantiate() as Player
	player.name = "1"
	add_child_autofree(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var point: Interactable = station.call("get_point",&"board") as Interactable
	player.global_position = point.global_position + Vector3(0,0,.8)
	return {"station":station,"session":session,"player":player,"source":source}

func test_failed_save_keeps_everyone_in_cratera_and_allows_retry() -> void:
	var fixture: Dictionary = _fixture(false)
	await get_tree().physics_frame
	assert_false(fixture.station.call("host_request_board",1))
	assert_eq(fixture.station.get("save_calls"),1)
	assert_eq(fixture.session.get_current_map().id,"cratera")
	fixture.station.set("save_ok",true)
	assert_true(fixture.station.call("host_request_board",1))
	assert_eq(fixture.station.get("save_calls"),2)
	await _await_rocket_commit(fixture.session)
	assert_eq(fixture.session.get_current_map().id,"lua")

func test_successful_board_persists_once_before_travel() -> void:
	var fixture: Dictionary = _fixture(true)
	await get_tree().physics_frame
	assert_true(fixture.station.call("host_request_board",1))
	assert_eq(fixture.station.get("save_calls"),1)
	await _await_rocket_commit(fixture.session)
	assert_eq(fixture.session.get_current_map().id,"lua")
	assert_false(fixture.station.call("host_request_board",1))
	assert_eq(fixture.station.get("save_calls"),1)
