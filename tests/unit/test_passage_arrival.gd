extends GutTest

## #186: actual Session/PlayersRoot/Player construction, without a MultiplayerSpawner.
## Adapter supplies arrival context only AFTER checking the real base API exists.
## This is deterministic spawn-data proof, not an ENet or navigation fixture.
class ArrivalSession extends SessionManager:
	var fixture_arrival: Dictionary = {}
	func get_passage_arrival() -> Dictionary:
		return fixture_arrival.duplicate(true)

var _original_session: SessionManager
var _original_scene: Node
var _snapshot: Dictionary
var _world: Node3D = null
var _observed: Dictionary = {}


func before_each() -> void:
	_original_session = SessionManager.instance
	_original_scene = get_tree().current_scene
	_snapshot = GameState.instance.get_snapshot().duplicate(true)
	_observed.clear()


func after_each() -> void:
	get_tree().current_scene = _original_scene
	if is_instance_valid(_world):
		_world.free()
	_world = null
	SessionManager.instance = _original_session
	GameState.instance.load_snapshot(_snapshot)
	await get_tree().process_frame
	await get_tree().process_frame


func _has_api() -> bool:
	# Probe BASE, never the adapter which necessarily has the test override.
	var base: SessionManager = SessionManager.new()
	var present: bool = base.has_method("get_passage_arrival")
	assert_true(present, "Production SessionManager.get_passage_arrival must exist")
	base.free()
	return present


func _fixture(arrival: Dictionary, with_marker: bool = true) -> Dictionary:
	if not _has_api(): return {}
	_world = Node3D.new()
	_world.name = "ArrivalFixtureWorld"
	get_tree().root.add_child(_world)
	get_tree().current_scene = _world
	assert_true(_world.get_parent() == get_tree().root)
	assert_true(get_tree().current_scene == _world)
	var session: ArrivalSession = ArrivalSession.new()
	session.fixture_arrival = arrival.duplicate(true)
	session.scene_change_enabled = false
	SessionManager.instance = session
	_world.add_child(session)
	session._current_map = load("res://items/maps/campo.tres") as MapData
	session._ready_peers.clear() # Prevent PlayersRoot._ready from creating actors yet.
	var routes: Node3D = Node3D.new()
	routes.name = "WorldRoutes"
	routes.position = Vector3(3, .25, -2)
	_world.add_child(routes)
	var marker: Marker3D = null
	if with_marker:
		marker = Marker3D.new()
		marker.name = "Arrival_campo"
		marker.position = Vector3(-12, 1.75, 15)
		marker.rotation.y = PI * .5
		routes.add_child(marker)
	var players: PlayersRoot = PlayersRoot.new()
	players.name = "Players"
	players.position = Vector3(7, .3, -6)
	players.spawn_spacing = 2.0
	players.child_entered_tree.connect(_observe_entering_player)
	_world.add_child(players)
	assert_null(players.get_node_or_null("PlayerSpawner"), "Exercise production no-spawner branch")
	return {"session": session, "players": players, "marker": marker}


func _observe_entering_player(node: Node) -> void:
	var actor: Player = node as Player
	if actor == null: return
	_observed[String(actor.name)] = {
		"ready": actor.is_node_ready(), "local_position": actor.position,
		"world_position": actor.global_position, "yaw": actor.global_rotation.y,
		"authority": actor.get_multiplayer_authority(),
	}
	# Snapshot above stays pre-ready. Changing inherited processing while children
	# are still entering can query can_process on nodes outside the tree.
	_disable_after_ready.call_deferred(weakref(actor))


func _disable_after_ready(reference: WeakRef) -> void:
	# Some synchronous tests free the fixture before this deferred callback runs.
	var actor: Player = reference.get_ref() as Player
	if is_instance_valid(actor) and actor.is_inside_tree() and actor.is_node_ready() and not actor.is_queued_for_deletion():
		actor.process_mode = Node.PROCESS_MODE_DISABLED


func _assert_pose_before_ready(peer_id: int, position: Vector3, yaw: float) -> void:
	var key: String = str(peer_id)
	assert_true(_observed.has(key), "Observe spawned Player entering tree: " + key)
	if not _observed.has(key): return
	var observed: Dictionary = _observed[key]
	assert_false(bool(observed["ready"]), "Pose cannot wait until Player._ready")
	assert_lt((observed["world_position"] as Vector3).distance_to(position), .001, "World pose at arrival")
	assert_almost_eq(wrapf(float(observed["yaw"])-yaw,-PI,PI), 0.0, .001, "Arrival heading before ready")
	assert_eq(int(observed["authority"]), peer_id)


func test_base_api_returns_empty_without_a_passage_trip() -> void:
	if not _has_api(): return
	var base: SessionManager = SessionManager.new()
	var result: Variant = base.call("get_passage_arrival")
	assert_true(result is Dictionary, "Arrival API returns Dictionary")
	if result is Dictionary:
		assert_true(result.is_empty(), "No fabricated route/destination at startup")
	base.free()


func test_default_spawn_offsets_and_heading_are_unchanged_without_arrival() -> void:
	var f: Dictionary = _fixture({})
	if f.is_empty(): return
	var players: PlayersRoot = f.players as PlayersRoot
	var session: SessionManager = f.session as SessionManager
	session._ready_peers.assign([1, 22])
	var first: Player = players.spawn_player(1)
	var second: Player = players.spawn_player(22)
	assert_not_null(first)
	assert_not_null(second)
	_assert_pose_before_ready(1, players.to_global(Vector3.ZERO), 0.0)
	_assert_pose_before_ready(22, players.to_global(Vector3(players.spawn_spacing,0,0)), 0.0)
	assert_eq(players.get_child_count(), 2)


func test_marker_world_transform_and_spacing_reach_two_peers_before_ready() -> void:
	var f: Dictionary = _fixture({"route": "campo", "destination": "campo"})
	if f.is_empty(): return
	var players: PlayersRoot = f.players as PlayersRoot
	var marker: Marker3D = f.marker as Marker3D
	var session: SessionManager = f.session as SessionManager
	session._ready_peers.assign([1, 22])
	var first: Player = players.spawn_player(1)
	var second: Player = players.spawn_player(22)
	assert_not_null(first)
	assert_not_null(second)
	var expected_first: Vector3 = marker.global_position
	var expected_second: Vector3 = marker.global_transform * Vector3(players.spawn_spacing,0,0)
	_assert_pose_before_ready(1, expected_first, marker.global_rotation.y)
	_assert_pose_before_ready(22, expected_second, marker.global_rotation.y)
	if first != null and second != null:
		assert_lt(first.position.distance_to(players.to_local(expected_first)), .001, "Convert world anchor into translated Players local space")
		assert_lt(second.position.distance_to(players.to_local(expected_second)), .001)
		assert_almost_eq(first.global_position.distance_to(second.global_position), players.spawn_spacing, .001, "Peers remain separated around rotated marker")
		assert_true(first != second)
		assert_true(players.spawn_player(22) == second, "Repeated ready must reuse existing actor")
		assert_eq(players.get_child_count(), 2)


func test_create_player_applies_replicated_yaw_and_position_before_tree_entry() -> void:
	var f: Dictionary = _fixture({})
	if f.is_empty(): return
	var players: PlayersRoot = f.players as PlayersRoot
	var data: Dictionary = {"peer_id": 777, "pos": Vector3(2,.4,-3), "yaw": -1.1}
	var host_copy: Player = players._create_player(data) as Player
	var replica_copy: Player = players._create_player(data.duplicate(true)) as Player
	assert_not_null(host_copy)
	assert_not_null(replica_copy)
	for actor: Player in [host_copy, replica_copy]:
		if actor == null: continue
		assert_false(actor.is_inside_tree())
		assert_false(actor.is_node_ready())
		assert_eq(String(actor.name), "777")
		assert_eq(actor.position, data["pos"])
		assert_almost_eq(actor.rotation.y, -1.1, .001, "Serialized yaw must be applied by spawn_function, not later owner sync")
		actor.free()


func test_missing_marker_for_matching_arrival_fails_closed_without_origin_spawn() -> void:
	var f: Dictionary = _fixture({"route": "campo", "destination": "campo"}, false)
	if f.is_empty(): return
	var players: PlayersRoot = f.players as PlayersRoot
	var session: SessionManager = f.session as SessionManager
	session._ready_peers.assign([1, 22])
	assert_null(players.spawn_player(1), "Missing canonical arrival must not fall back to Players origin")
	assert_null(players.spawn_player(22))
	assert_true(_observed.is_empty(), "No Player enters tree at unintended origin")
	assert_eq(players.get_child_count(), 0)


func test_arrival_for_another_destination_does_not_override_current_default_spawn() -> void:
	var f: Dictionary = _fixture({"route": "campo", "destination": "ruinas"})
	if f.is_empty(): return
	var players: PlayersRoot = f.players as PlayersRoot
	var session: SessionManager = f.session as SessionManager
	session._ready_peers.assign([1])
	assert_not_null(players.spawn_player(1))
	_assert_pose_before_ready(1, players.to_global(Vector3.ZERO), 0.0)
