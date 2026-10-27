extends Interactable

## Physical authorization boundary; prices, ledger and purchases remain in core.
@export var map_id: String = "praia"

const COUNTER_GROUP: StringName = &"upgrade_counters"
const SHOP_SOURCE: String = "res://ui/world_upgrade_shop.gd"
var _shop: CanvasLayer = null
var _commerce_state: GameState = null


func _init() -> void:
	interact_range = 2.5
	focus_offset = Vector3(0, .6, 0)


func _ready() -> void:
	add_to_group(COUNTER_GROUP)
	super._ready()
	_connect_purchase_results()


func _exit_tree() -> void:
	if is_instance_valid(_commerce_state) and _commerce_state.has_signal("world_upgrade_result"):
		if _commerce_state.is_connected("world_upgrade_result", _on_world_upgrade_result):
			_commerce_state.disconnect("world_upgrade_result", _on_world_upgrade_result)
	if is_instance_valid(_shop) and _shop.has_method("close"):
		_shop.call("close")
	super._exit_tree()


func get_prompt() -> String:
	return tr("[E] Melhorias")


## Shared geometry/lifecycle check: accepts host replicas as well as local UI owners.
## The UI separately requires is_local; the host separately proves sender/authority.
func is_actor_in_range(actor: Player) -> bool:
	if not is_inside_tree() or is_queued_for_deletion() or not active:
		return false
	if not is_instance_valid(actor) or not actor.is_inside_tree() or actor.is_queued_for_deletion():
		return false
	if not actor.is_node_ready() or not actor.is_alive() or actor.is_downed:
		return false
	var scene: Node = get_tree().current_scene
	if scene == null or not scene.is_ancestor_of(self) or not scene.is_ancestor_of(actor):
		return false
	if actor.multiplayer != multiplayer:
		return false
	var session: SessionManager = SessionManager.instance
	if not is_instance_valid(session) or session.get_current_map() == null:
		return false
	if map_id.is_empty() or session.get_current_map().id != map_id:
		return false
	if str(session.get_rocket_transition().get("phase", "INVALID")) != "IDLE":
		return false
	if actor.global_position.distance_to(get_focus_point()) > 2.5:
		return false
	return _has_los(actor)


func host_can_purchase(peer_id: int) -> bool:
	if not is_inside_tree() or not multiplayer.is_server() or not is_multiplayer_authority():
		return false
	if multiplayer.get_remote_sender_id() != 0 or peer_id <= 0:
		return false
	var session: SessionManager = SessionManager.instance
	if not is_instance_valid(session) or not session.is_peer_scene_ready(peer_id):
		return false
	var actor: Player = HostSync.player_of(get_tree(), peer_id) as Player
	if not is_instance_valid(actor) or String(actor.name) != str(peer_id):
		return false
	if actor.get_multiplayer_authority() != peer_id:
		return false
	return is_actor_in_range(actor)


func _has_los(actor: Player) -> bool:
	if not is_instance_valid(actor.head):
		return false
	var excluded: Array[RID] = [actor.get_rid()]
	for node: Node in actor.find_children("*", "CollisionObject3D", true, false):
		excluded.append((node as CollisionObject3D).get_rid())
	for node: Node in find_children("*", "CollisionObject3D", true, false):
		excluded.append((node as CollisionObject3D).get_rid())
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		actor.head.global_position, get_focus_point(), 1, excluded)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _host_interact(peer_id: int) -> void:
	# Interactable derives peer_id from the genuine RPC sender before deferring.
	if is_inside_tree() and multiplayer.is_server():
		_host_open.call_deferred(peer_id)


func _host_open(peer_id: int) -> void:
	if not host_can_purchase(peer_id):
		return
	if peer_id == multiplayer.get_unique_id():
		_open_local()
	else:
		HostSync.send_to(self, peer_id, &"_rpc_open_shop")


@rpc("authority", "call_remote", "reliable")
func _rpc_open_shop() -> void:
	if not is_inside_tree() or multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	_open_local()


func _local_actor() -> Player:
	if not is_inside_tree():
		return null
	var id: int = multiplayer.get_unique_id()
	var actor: Player = HostSync.player_of(get_tree(), id) as Player
	if not is_instance_valid(actor) or not actor.is_local() or String(actor.name) != str(id):
		return null
	if actor.get_multiplayer_authority() != id:
		return null
	return actor


func _open_local() -> bool:
	var actor: Player = _local_actor()
	if actor == null or not is_actor_in_range(actor):
		return false
	if not is_instance_valid(_shop):
		if not ResourceLoader.exists(SHOP_SOURCE):
			return false
		var source: Script = load(SHOP_SOURCE) as Script
		if source == null:
			return false
		_shop = source.new() as CanvasLayer
		if _shop == null:
			return false
		_shop.name = "WorldUpgradeShop"
		add_child(_shop)
		if not _shop.has_signal("purchase_requested") or not _shop.has_method("open_for") or not _shop.has_method("complete_purchase"):
			_shop.queue_free()
			_shop = null
			return false
		_shop.connect("purchase_requested", _on_purchase_requested)
	_connect_purchase_results()
	# Only one contextual commerce modal owns local focus at a time.
	for other: Node in get_tree().get_nodes_in_group(&"world_upgrade_shops"):
		if other != _shop and other.has_method("close"):
			other.call("close")
	return bool(_shop.call("open_for", self, actor))


func _connect_purchase_results() -> void:
	var state_owner: GameState = GameState.instance
	if not is_instance_valid(state_owner) or not state_owner.has_signal("world_upgrade_result"):
		return
	if is_instance_valid(_commerce_state) and _commerce_state != state_owner:
		if _commerce_state.has_signal("world_upgrade_result") and _commerce_state.is_connected("world_upgrade_result", _on_world_upgrade_result):
			_commerce_state.disconnect("world_upgrade_result", _on_world_upgrade_result)
	_commerce_state = state_owner
	if not _commerce_state.is_connected("world_upgrade_result", _on_world_upgrade_result):
		_commerce_state.connect("world_upgrade_result", _on_world_upgrade_result)


func _on_purchase_requested(upgrade_id: String, request_id: int) -> void:
	if not is_instance_valid(_shop) or not _shop.is_inside_tree() or not is_inside_tree():
		return
	var actor: Player = _local_actor()
	if actor == null or not is_actor_in_range(actor):
		_shop.call("close")
		return
	if not _shop.has_method("is_open_for") or not bool(_shop.call("is_open_for", actor)):
		return
	_connect_purchase_results()
	if request_id <= 0 or not is_instance_valid(_commerce_state) or not _commerce_state.has_method("request_world_upgrade"):
		_shop.call("complete_purchase", request_id, false, tr("Loja indisponível. Tente novamente."))
		return
	# Forward only ID, canonical node path and correlation token; no price or result.
	_commerce_state.call("request_world_upgrade", upgrade_id, get_path(), request_id)


func _on_world_upgrade_result(request_id: int, _upgrade_id: String, success: bool, message: String) -> void:
	if is_instance_valid(_shop) and _shop.is_inside_tree() and _shop.has_method("complete_purchase"):
		_shop.call("complete_purchase", request_id, success, message)
