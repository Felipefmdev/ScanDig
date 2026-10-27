extends Node3D

## #120: host-authoritative repair and boarding; visual placement remains separate.
const FLOW: Script = preload("res://gameplay/quests/cratera/rocket_repair.gd")
const TERRAIN: Script = preload("res://gameplay/environment/crater_terrain.gd")
const TASKS: Array[StringName] = [&"clear_base",&"secure_connection",&"align_receiver"]
const OFFSETS: Dictionary = {
	&"clear_base":Vector3(0,0,2.3), &"secure_connection":Vector3(2.3,0,.8),
	&"align_receiver":Vector3(-2.3,0,.8), &"board":Vector3(0,0,3.5),
}
const PROMPTS: Dictionary = {
	&"clear_base":"[E] Limpar base com a pá", &"secure_connection":"[E] Fixar conexão",
	&"align_receiver":"[E] Alinhar receptor", &"board":"[E] Embarcar para a Lua",
}

class ProgressPort extends Node:
	func is_quest_completed(id: String) -> bool:
		return GameState.instance != null and GameState.instance.is_quest_completed(id)
	func is_boss_defeated(id: String) -> bool:
		return GameState.instance != null and GameState.instance.is_boss_defeated(id)
	func complete_quest(id: String) -> void:
		# FLOW's READY is provisional until GameState acknowledges this deferred call.
		if GameState.instance != null and multiplayer.is_server():
			GameState.instance.request_complete_quest.call_deferred(id)

class StationPoint extends Interactable:
	var station: Node3D = null
	var task_id: StringName = &""
	func get_prompt() -> String:
		if GameState.instance == null: return prompt
		if not GameState.instance.is_quest_completed("vega_sinal"):
			return "[E] Conclua a missão da Vega"
		if not GameState.instance.is_boss_defeated("the_sleeper"):
			return "[E] Vença o Dorminhoco"
		if task_id == &"board" and not GameState.instance.is_quest_completed("vega_foguete"):
			return "[E] Repare os três pontos do foguete"
		return prompt
	func _host_interact(peer_id: int) -> void:
		# Inherited request_interact RPC derives peer_id from remote sender, never payload.
		if active and HostSync.is_host(self):
			_dispatch.call_deferred(peer_id)
	func _dispatch(peer_id: int) -> void:
		if not is_instance_valid(station) or not station.is_inside_tree(): return
		if task_id == &"board": station.call("host_request_board",peer_id)
		else: station.call("host_request_task",task_id,peer_id)

@export var placement_path: NodePath = NodePath("../CraterRocket")

func _ready() -> void:
	# Direct editor views retain the visual rocket without inventing a session.
	var session: SessionManager = SessionManager.instance
	if session != null and session.is_in_expedition():
		configure(get_node_or_null(placement_path) as Node3D,session)

var _placement: Node3D = null
var _session: SessionManager = null
var _flow: Node = null
var _port: ProgressPort = null
var _points: Dictionary = {}
var _tasks: Dictionary = {}
var _departed: bool = false

func configure(placement: Node3D, session: SessionManager) -> bool:
	_reset()
	if not is_inside_tree() or not is_instance_valid(placement) or not placement.is_inside_tree(): return false
	if not is_instance_valid(session) or not session.is_inside_tree() or GameState.instance == null: return false
	if session.get_current_map() == null or session.get_current_map().id != "cratera": return false
	if placement.get_node_or_null(^"Rocket") == null or placement.get_node_or_null(^"Supports") == null: return false
	_placement = placement
	_session = session
	_port = ProgressPort.new()
	_port.name = "ProgressPort"
	add_child(_port)
	_flow = FLOW.new() as Node
	_flow.name = "RepairFlow"
	add_child(_flow)
	_flow.call("configure",_port)
	for id: StringName in OFFSETS:
		var point: StationPoint = StationPoint.new()
		point.name = String(id)
		point.station = self
		point.task_id = id
		point.prompt = PROMPTS[id]
		point.interact_range = 2.6
		point.focus_offset = Vector3(0,.6,0)
		add_child(point)
		var offset: Vector3 = OFFSETS[id]
		var at: Vector3 = placement.global_position + offset
		at.y = _ground_height(at.x,at.z)
		point.global_position = at
		_points[id] = point
	if HostSync.is_host(self):
		_session.peer_scene_ready.connect(_on_peer_ready)
		_session.rocket_travel_cancelled.connect(_on_travel_cancelled)
		_restore_persisted()
	return true

func _reset() -> void:
	if is_instance_valid(_session) and _session.peer_scene_ready.is_connected(_on_peer_ready):
		_session.peer_scene_ready.disconnect(_on_peer_ready)
	if is_instance_valid(_session) and _session.rocket_travel_cancelled.is_connected(_on_travel_cancelled):
		_session.rocket_travel_cancelled.disconnect(_on_travel_cancelled)
	for point: Node in _points.values():
		if is_instance_valid(point):
			remove_child(point)
			point.queue_free()
	_points.clear()
	for node: Node in [_flow,_port]:
		if is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	_flow = null
	_port = null
	_placement = null
	_session = null
	_tasks.clear()
	_departed = false

func _exit_tree() -> void:
	if is_instance_valid(_session) and _session.peer_scene_ready.is_connected(_on_peer_ready):
		_session.peer_scene_ready.disconnect(_on_peer_ready)
	if is_instance_valid(_session) and _session.rocket_travel_cancelled.is_connected(_on_travel_cancelled):
		_session.rocket_travel_cancelled.disconnect(_on_travel_cancelled)

func get_point(id: StringName) -> Interactable:
	return _points.get(id) as Interactable

func is_task_complete(id: StringName) -> bool:
	if not TASKS.has(id): return false
	return _tasks.has(id) or (_configured() and GameState.instance.is_quest_completed("vega_foguete"))

func _configured() -> bool:
	return is_inside_tree() and is_instance_valid(_placement) and _placement.is_inside_tree() \
		and is_instance_valid(_session) and _session.is_inside_tree() and GameState.instance != null \
		and _session.get_current_map() != null and _session.get_current_map().id == "cratera" \
		and is_instance_valid(_flow)

func _actor(peer_id: int, point: Interactable) -> Player:
	if not _configured() or not HostSync.is_host(self) or point == null or _departed: return null
	if not _session.is_peer_scene_ready(peer_id): return null
	var actor: Player = HostSync.player_of(get_tree(),peer_id) as Player
	if actor == null or not actor.is_inside_tree() or actor.is_queued_for_deletion() or not actor.is_alive(): return null
	if actor.get_multiplayer_authority() != peer_id: return null
	if actor.global_position.distance_to(point.get_focus_point()) > 2.6: return null
	if not _has_los(actor,point): return null
	return actor

func _has_los(actor: Player, point: Interactable) -> bool:
	if actor.head == null or not is_instance_valid(actor.head): return false
	var excluded: Array[RID] = [actor.get_rid()]
	for node: Node in actor.find_children("*","CollisionObject3D",true,false):
		excluded.append((node as CollisionObject3D).get_rid())
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		actor.head.global_position,point.get_focus_point(),1,excluded)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func host_request_task(id: StringName, peer_id: int) -> bool:
	if not TASKS.has(id): return false
	var actor: Player = _actor(peer_id,get_point(id))
	if actor == null: return false
	if not GameState.instance.is_quest_completed("vega_sinal") or not GameState.instance.is_boss_defeated("the_sleeper"): return false
	if id == &"clear_base" and (not actor.held_tool_id.is_empty() or actor.carrying_loot): return false
	if not bool(_flow.call("complete_task",id)): return false
	_tasks[id] = true
	_apply_points()
	HostSync.broadcast(self,&"_rpc_snapshot",[_tasks.keys(),_departed])
	return true

func host_request_board(peer_id: int) -> bool:
	if _actor(peer_id,get_point(&"board")) == null: return false
	if not GameState.instance.is_quest_completed("vega_foguete"): return false
	# Ready alone is insufficient: include every connected peer, even still loading.
	var peers: Array[int] = _session.get_ready_peers()
	if not peers.has(1): peers.append(1)
	for connected: int in multiplayer.get_peers():
		if not peers.has(connected): peers.append(connected)
	for participant: int in peers:
		if not _session.is_peer_scene_ready(participant): return false
		var actor: Player = HostSync.player_of(get_tree(),participant) as Player
		if actor == null or not actor.is_inside_tree() or actor.is_queued_for_deletion() or not actor.is_alive(): return false
		if actor.get_multiplayer_authority() != participant: return false
		if Vector2(actor.global_position.x-_placement.global_position.x,actor.global_position.z-_placement.global_position.z).length() > 5.0: return false
	for node: Node in get_tree().get_nodes_in_group(EnemyBase.GROUP):
		var enemy: EnemyBase = node as EnemyBase
		if enemy != null and enemy.is_inside_tree() and enemy.is_alive():
			if Vector2(enemy.global_position.x-_placement.global_position.x,enemy.global_position.z-_placement.global_position.z).length() <= 8.0: return false
	# Persist the acknowledged quest before releasing the old scene.
	if not _save_before_departure():
		get_point(&"board").say_to(peer_id,"Não foi possível salvar. Tente embarcar novamente.")
		return false
	# No yield between final validation and existing session travel. RPC path was deferred.
	if not _session.request_rocket_travel(): return false
	_departed = true
	_apply_points()
	return true

## Narrow disk adapter: fixtures substitute this method without mocking travel.
func _save_before_departure() -> bool:
	var save: SaveManager = SaveManager.instance
	return save != null and save.is_progress_applied() and save.save_game() == OK

func _restore_persisted() -> void:
	if GameState.instance.is_quest_completed("vega_foguete"):
		for id: StringName in TASKS: _tasks[id] = true
	_apply_points()

func _apply_points() -> void:
	for id: StringName in _points:
		var point: Interactable = _points[id] as Interactable
		point.active = not _departed and (id == &"board" or not _tasks.has(id))
		point.state = 1 if _tasks.has(id) else 0

func _on_travel_cancelled(_token: int) -> void:
	if not _configured() or not HostSync.is_host(self): return
	if _session.get_rocket_transition()["phase"] != "IDLE": return
	_departed = false
	_apply_points()
	HostSync.broadcast(self,&"_rpc_snapshot",[_tasks.keys(),_departed])

func _on_peer_ready(peer_id: int, map_id: String) -> void:
	if map_id != "cratera" or not _configured() or not HostSync.is_host(self): return
	_restore_persisted()
	HostSync.send_to(self,peer_id,&"_rpc_snapshot",[_tasks.keys(),_departed])

@rpc("authority","call_remote","reliable")
func _rpc_snapshot(completed: Array, departed: bool) -> void:
	_tasks.clear()
	for id: Variant in completed:
		var task: StringName = StringName(str(id))
		if TASKS.has(task): _tasks[task] = true
	_departed = departed
	_apply_points()

static func _ground_height(x: float, z: float) -> float:
	var x0: float = floor(x)
	var z0: float = floor(z)
	var u: float = x-x0
	var v: float = z-z0
	var a: float = TERRAIN.height_at(x0,z0)
	var b: float = TERRAIN.height_at(x0+1,z0)
	var c: float = TERRAIN.height_at(x0,z0+1)
	if u+v <= 1: return a+u*(b-a)+v*(c-a)
	var d: float = TERRAIN.height_at(x0+1,z0+1)
	return d+(1-u)*(c-d)+(1-v)*(b-d)
