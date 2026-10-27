extends GutTest

const OFFSETS: Dictionary = {
	&"clear_base": Vector3(0,0,2.3), &"secure_connection": Vector3(2.3,0,.8),
	&"align_receiver": Vector3(-2.3,0,.8), &"board": Vector3(0,0,3.5),
}
var saved_state: Dictionary = {}

func before_each() -> void:
	if GameState.instance != null:
		saved_state = GameState.instance.get_snapshot()
		GameState.instance.completed_quests = []
		GameState.instance.defeated_bosses = []

func after_each() -> void:
	if GameState.instance != null and not saved_state.is_empty():
		GameState.instance.apply_snapshot(saved_state)
	await get_tree().process_frame
	await get_tree().process_frame

func _await_rocket_commit(session: SessionManager) -> void:
	for frame: int in range(120):
		if session.get_current_map() != null and session.get_current_map().id=="lua": return
		await get_tree().process_frame

func _source() -> Script:
	var path: String = "res://gameplay/quests/cratera/crater_rocket_station.gd"
	assert_true(ResourceLoader.exists(path), "Station coordinator absent: " + path)
	if not ResourceLoader.exists(path): return null
	return load(path) as Script

func _fixture() -> Dictionary:
	var source: Script = _source()
	if source == null: return {}
	GameState.instance.completed_quests = ["vega_sinal"]
	GameState.instance.defeated_bosses = ["the_sleeper"]
	# Substitute only disk persistence; all station validation and travel are real.
	var adapter: GDScript = GDScript.new()
	adapter.source_code = "extends \"%s\"\nfunc _save_before_departure() -> bool:\n\treturn true\n" % source.resource_path
	assert_eq(adapter.reload(),OK)
	var station: Node3D = adapter.new() as Node3D
	add_child_autofree(station)
	for method: String in ["configure","get_point","is_task_complete","host_request_task","host_request_board"]:
		assert_true(station.has_method(method), "Required station API: " + method)
		if not station.has_method(method): return {}
	var placement: Node3D = load("res://gameplay/environment/crater_rocket.gd").new() as Node3D
	placement.position = Vector3(-23,0,21)
	add_child_autofree(placement)
	var session: SessionManager = SessionManager.new()
	session.scene_change_enabled = false
	add_child_autofree(session)
	session._current_map = load("res://items/maps/cratera.tres") as MapData
	session._ready_peers = [1]
	assert_true(bool(station.call("configure",placement,session)))
	var player: Player = load("res://gameplay/player/player.tscn").instantiate() as Player
	player.name = "1"
	add_child_autofree(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.add_to_group(&"players")
	player.health = player.max_health
	player.held_tool_id = &""
	player.carrying_loot = false
	return {"station":station,"placement":placement,"session":session,"player":player}

func _at(f: Dictionary, id: StringName) -> void:
	var point: Interactable = f.station.call("get_point",id) as Interactable
	assert_not_null(point)
	if point != null: f.player.global_position = point.global_position + Vector3(0,0,.8)

func test_missing_configuration_cannot_fallback_to_origin_or_local_actor() -> void:
	var source: Script = _source()
	if source == null: return
	var station: Node3D = source.new() as Node3D
	add_child_autofree(station)
	assert_false(bool(station.call("configure",null,null)))
	assert_false(bool(station.call("host_request_task",&"clear_base",1)))
	assert_false(bool(station.call("host_request_board",1)))

func test_points_use_placement_meter_offsets_not_scaled_glb_and_have_no_colliders() -> void:
	var f: Dictionary = _fixture()
	if f.is_empty(): return
	for id: StringName in OFFSETS:
		var point: Interactable = f.station.call("get_point",id) as Interactable
		assert_not_null(point)
		if point == null: continue
		var expected: Vector3 = f.placement.global_position + OFFSETS[id]
		assert_almost_eq(point.global_position.x,expected.x,.001)
		assert_almost_eq(point.global_position.z,expected.z,.001)
		assert_gt(absf(point.global_position.x+23.0)+absf(point.global_position.z-21.0),1.8)
	assert_eq(f.station.find_children("*","CollisionObject3D",true,false).size(),0)

func test_null_peer_and_node3d_impostor_never_advance() -> void:
	var f: Dictionary = _fixture()
	if f.is_empty(): return
	assert_false(bool(f.station.call("host_request_task",&"clear_base",999)))
	var impostor: Node3D = Node3D.new()
	impostor.name = "777"
	add_child_autofree(impostor)
	impostor.add_to_group(&"players")
	f.session._ready_peers.append(777)
	assert_false(bool(f.station.call("host_request_task",&"clear_base",777)))
	assert_false(bool(f.station.call("is_task_complete",&"clear_base")))

func test_clear_requires_basic_shovel_alive_actor_and_short_range() -> void:
	var f: Dictionary = _fixture()
	if f.is_empty(): return
	_at(f,&"clear_base")
	f.player.held_tool_id = &"detector"
	assert_false(bool(f.station.call("host_request_task",&"clear_base",1)))
	f.player.held_tool_id = &""
	f.player.carrying_loot = true
	assert_false(bool(f.station.call("host_request_task",&"clear_base",1)),"Empty tool ID while carrying loot is not the basic shovel state")
	f.player.carrying_loot = false
	f.player.health = 0
	assert_false(bool(f.station.call("host_request_task",&"clear_base",1)))
	f.player.health = f.player.max_health
	f.player.is_downed = true
	assert_false(bool(f.station.call("host_request_task",&"clear_base",1)))
	f.player.is_downed = false
	f.player.position += Vector3(0,0,4)
	assert_false(bool(f.station.call("host_request_task",&"clear_base",1)))
	_at(f,&"clear_base")
	await get_tree().physics_frame
	assert_true(bool(f.station.call("host_request_task",&"clear_base",1)))
	assert_true(bool(f.station.call("is_task_complete",&"clear_base")))

func test_task_los_blocked_by_real_static_body() -> void:
	var f: Dictionary = _fixture()
	if f.is_empty(): return
	_at(f,&"secure_connection")
	var point: Interactable = f.station.call("get_point",&"secure_connection") as Interactable
	var wall: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(1,3,.15)
	shape.shape = box
	wall.add_child(shape)
	add_child_autofree(wall)
	wall.global_position = point.global_position + Vector3(0,1,.4)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_false(bool(f.station.call("host_request_task",&"secure_connection",1)))
	assert_false(bool(f.station.call("is_task_complete",&"secure_connection")))

func test_each_prerequisite_is_required_before_any_task_can_advance() -> void:
	var f: Dictionary = _fixture()
	if f.is_empty(): return
	for missing: String in ["vega_sinal","the_sleeper"]:
		GameState.instance.completed_quests.clear()
		GameState.instance.defeated_bosses.clear()
		if missing != "vega_sinal": GameState.instance.completed_quests.append("vega_sinal")
		if missing != "the_sleeper": GameState.instance.defeated_bosses.append("the_sleeper")
		for id: StringName in [&"clear_base",&"secure_connection",&"align_receiver"]:
			_at(f,id)
			await get_tree().physics_frame
			assert_false(bool(f.station.call("host_request_task",id,1)),"Missing prerequisite: " + missing)
			assert_false(bool(f.station.call("is_task_complete",id)))
	assert_false(GameState.instance.is_quest_completed("vega_foguete"))

func test_three_distinct_tasks_complete_once_and_persist_quest_before_board() -> void:
	var f: Dictionary = _fixture()
	if f.is_empty(): return
	for id: StringName in [&"clear_base",&"secure_connection",&"align_receiver"]:
		_at(f,id)
		await get_tree().physics_frame
		assert_true(bool(f.station.call("host_request_task",id,1)))
		assert_true(bool(f.station.call("is_task_complete",id)))
		assert_false(bool(f.station.call("host_request_task",id,1)),"Repeat cannot apply another completion")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(GameState.instance.is_quest_completed("vega_foguete"))
	assert_eq(GameState.instance.completed_quests.count("vega_foguete"),1)

func test_board_uses_persisted_flag_not_fallback_or_missing_ready_actor() -> void:
	var f: Dictionary = _fixture()
	if f.is_empty(): return
	_at(f,&"board")
	var fallback: Array[String] = QuestRewards.completed_quests.duplicate()
	QuestRewards.completed_quests = ["vega_foguete"]
	assert_false(bool(f.station.call("host_request_board",1)))
	QuestRewards.completed_quests = fallback
	GameState.instance.completed_quests = ["vega_foguete"]
	f.session._ready_peers.clear()
	assert_false(bool(f.station.call("host_request_board",1)))
	f.session._ready_peers.assign([1,777])
	assert_false(bool(f.station.call("host_request_board",1)),"Ready peer with missing real Player blocks")
	assert_eq(f.session.get_current_map().id,"cratera")

func test_board_rejects_real_distant_or_downed_ready_peer_without_dragging() -> void:
	var f: Dictionary = _fixture()
	if f.is_empty(): return
	GameState.instance.completed_quests = ["vega_foguete"]
	_at(f,&"board")
	var guest: Player = load("res://gameplay/player/player.tscn").instantiate() as Player
	guest.name = "22"
	guest.set_multiplayer_authority(22)
	add_child_autofree(guest)
	guest.process_mode = Node.PROCESS_MODE_DISABLED
	guest.add_to_group(&"players")
	f.session._ready_peers.assign([1,22])
	guest.global_position = f.placement.global_position + Vector3(5.1,0,0)
	var at: Vector3 = guest.global_position
	assert_false(bool(f.station.call("host_request_board",1)))
	assert_eq(guest.global_position,at)
	guest.global_position = f.placement.global_position + Vector3(0,0,4)
	guest.is_downed = true
	assert_false(bool(f.station.call("host_request_board",1)))
	assert_eq(f.session.get_current_map().id,"cratera")

func test_live_enemy_inside_eight_meters_blocks_even_with_persisted_quest() -> void:
	var f: Dictionary = _fixture()
	if f.is_empty(): return
	GameState.instance.completed_quests = ["vega_foguete"]
	_at(f,&"board")
	var enemy: EnemyBase = EnemyBase.new()
	add_child_autofree(enemy)
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	enemy.global_position = f.placement.global_position + Vector3(7.9,0,0)
	enemy.health = 50
	await get_tree().physics_frame
	assert_false(bool(f.station.call("host_request_board",1)))
	assert_eq(f.session.get_current_map().id,"cratera")

func test_persisted_repair_safe_board_uses_real_session_once_without_dragging() -> void:
	var f: Dictionary = _fixture()
	if f.is_empty(): return
	GameState.instance.completed_quests = ["vega_foguete"]
	_at(f,&"board")
	await get_tree().physics_frame
	var at: Vector3 = f.player.global_position
	var day: int = GameState.instance.current_day
	var money: int = GameState.instance.team_money
	assert_true(bool(f.station.call("host_request_board",1)))
	await _await_rocket_commit(f.session)
	assert_eq(f.session.get_current_map().id,"lua")
	assert_eq(f.player.global_position,at)
	assert_eq(GameState.instance.current_day,day)
	assert_eq(GameState.instance.team_money,money)
	assert_false(bool(f.station.call("host_request_board",1)))
