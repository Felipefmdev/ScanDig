extends Interactable

## Physical opening/travel adapter. Team receipt/save belongs to GameState.
@export var route_id: String = ""
## Map containing this endpoint, including the return side. Receipt stays route_id.
@export var source_map: String = ""

var _session: SessionManager = null


func _init() -> void:
	interact_range = 2.5


func _ready() -> void:
	_session = SessionManager.instance
	super._ready()
	if GameState.instance != null:
		GameState.instance.state_synced.connect(_refresh_route_view)
	_refresh_route_view()


func _destination_name() -> String:
	var route: Dictionary = _route()
	if route.is_empty(): return ""
	var destination: String = route_id if source_map == str(route["source_map"]) else str(route["source_map"])
	var data: MapData = load("res://items/maps/%s.tres" % destination) as MapData
	return tr(data.display_name) if data != null else destination


func _refresh_route_view() -> void:
	var label: Label3D = get_node_or_null("Destination") as Label3D
	if label != null:
		label.text = _destination_name()
	if is_instance_valid(_prompt_label):
		_prompt_label.text = _prompt_text()
	var opened: bool = GameState.instance != null and GameState.instance.unlocked_maps.has(route_id)
	for rail_path: String in ["Gate/LowRail", "Gate/HighRail"]:
		var rail: Node3D = get_node_or_null(rail_path) as Node3D
		if rail != null: rail.visible = not opened
	var collision: CollisionShape3D = get_node_or_null("Gate/Collision") as CollisionShape3D
	if collision != null: collision.set_deferred("disabled", opened)


func _notification(what: int) -> void:
	super._notification(what)
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_route_view()


func _route() -> Dictionary:
	return GameState.MAP_UNLOCK_BOSSES.get(route_id, {}) as Dictionary


func get_prompt() -> String:
	var route: Dictionary = _route()
	if route.is_empty():
		return tr("Passagem indisponível")
	var state_owner: GameState = GameState.instance
	if state_owner == null:
		return tr("Passagem indisponível")
	if state_owner.unlocked_maps.has(route_id):
		return tr("[E] Viajar para %s") % _destination_name()
	if source_map != str(route.get("source_map", "")):
		return tr("Abra esta passagem pelo outro lado")
	var item_name: String = str(route.get("item_id", ""))
	var item_path: String = "res://items/catalog/%s.tres" % item_name
	if not item_name.is_empty() and ResourceLoader.exists(item_path):
		var item: ItemData = load(item_path) as ItemData
		if item != null:
			item_name = item.display_name
	if state_owner.is_boss_defeated(str(route.get("boss_id", ""))):
		return tr("[E] Usar %s para abrir a passagem") % tr(item_name)
	return tr("Requer %s") % tr(item_name)


func _host_interact(peer_id: int) -> void:
	# Inherited RPC captures the genuine sender before this deferred host-local call.
	# Core must not see a lingering guest remote_sender_id from the interaction RPC.
	if is_inside_tree() and multiplayer.is_server():
		_dispatch.call_deferred(peer_id)


func _dispatch(peer_id: int) -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var was_open: bool = GameState.instance != null and GameState.instance.unlocked_maps.has(route_id)
	var result: Error = host_request_interact(peer_id)
	if result == OK:
		_feedback(peer_id, tr("Preparando viagem...") if was_open else tr("Passagem aberta para a equipe."))
	elif result == ERR_FILE_CANT_WRITE or result == ERR_FILE_CANT_OPEN:
		_feedback(peer_id, tr("Não foi possível salvar a passagem. Tente novamente."))
	elif result == ERR_BUSY:
		_feedback(peer_id, tr("Reúna a equipe a até 5 m, sem ameaças a até 8 m, e tente novamente."))
	elif result == ERR_UNAUTHORIZED:
		_feedback(peer_id, tr("Não foi possível abrir esta passagem."))
	else:
		_feedback(peer_id, tr("Passagem indisponível. Tente novamente."))


func _feedback(peer_id: int, text: String) -> void:
	# No GUI-label access before ready/after teardown, including diagnostic fixtures.
	if peer_id <= 0 or not is_inside_tree() or not is_instance_valid(_say_label) or not is_instance_valid(_prompt_label):
		return
	if peer_id != multiplayer.get_unique_id() and not multiplayer.get_peers().has(peer_id):
		return
	say_to(peer_id, text)


func host_request_interact(peer_id: int) -> Error:
	var validation: Error = validate_request(peer_id)
	if validation != OK:
		return validation
	var state_owner: GameState = GameState.instance
	var route: Dictionary = _route()
	if state_owner.unlocked_maps.has(route_id):
		return OK if _session.request_passage_travel(self, peer_id) else ERR_BUSY
	if source_map != str(route["source_map"]):
		return ERR_UNAUTHORIZED
	return state_owner.open_boss_passage(route_id)


## Shared host validation for opening and the subsequent deliberate travel request.
func validate_request(peer_id: int) -> Error:
	if not is_inside_tree() or is_queued_for_deletion():
		return ERR_INVALID_PARAMETER
	if not multiplayer.is_server() or not is_multiplayer_authority() or multiplayer.get_remote_sender_id() != 0:
		return ERR_UNAUTHORIZED
	var scene: Node = get_tree().current_scene
	if scene == null or not scene.is_ancestor_of(self):
		return ERR_INVALID_PARAMETER
	if not is_instance_valid(_session) or _session != SessionManager.instance:
		return ERR_UNAVAILABLE
	var current_map: MapData = _session.get_current_map()
	var route: Dictionary = _route()
	var canonical_source: String = str(route.get("source_map", ""))
	if route.is_empty() or canonical_source.is_empty() or current_map == null:
		return ERR_INVALID_PARAMETER
	if source_map != current_map.id or (source_map != canonical_source and source_map != route_id):
		return ERR_INVALID_PARAMETER
	if str(_session.get_rocket_transition().get("phase", "INVALID")) != "IDLE":
		return ERR_BUSY
	if not active or peer_id <= 0 or not _session.is_peer_scene_ready(peer_id):
		return ERR_UNAUTHORIZED
	var actor: Player = HostSync.player_of(get_tree(), peer_id) as Player
	if actor == null or not actor.is_inside_tree() or actor.is_queued_for_deletion():
		return ERR_UNAUTHORIZED
	if not scene.is_ancestor_of(actor) or actor.multiplayer != multiplayer:
		return ERR_UNAUTHORIZED
	if String(actor.name) != str(peer_id) or actor.get_multiplayer_authority() != peer_id:
		return ERR_UNAUTHORIZED
	if not actor.is_alive() or actor.is_downed or not actor.is_node_ready():
		return ERR_UNAUTHORIZED
	if actor.global_position.distance_to(get_focus_point()) > 2.5 or not _has_los(actor):
		return ERR_UNAUTHORIZED
	var state_owner: GameState = GameState.instance
	if state_owner == null:
		return ERR_UNAVAILABLE
	return OK


func _has_los(actor: Player) -> bool:
	if not is_instance_valid(actor.head):
		return false
	var excluded: Array[RID] = [actor.get_rid()]
	for node: Node in actor.find_children("*", "CollisionObject3D", true, false):
		excluded.append((node as CollisionObject3D).get_rid())
	# The canonical gate is the target, not an obstacle in front of itself.
	for node: Node in find_children("*", "CollisionObject3D", true, false):
		excluded.append((node as CollisionObject3D).get_rid())
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		actor.head.global_position, get_focus_point(), 1, excluded)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
