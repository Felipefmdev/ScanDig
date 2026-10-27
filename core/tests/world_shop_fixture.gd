extends RefCounted

## #186 headless test setup, NOT production validation or a fake host endpoint.
## Real core/counter/offer/Player/Inventory; host-local only, no ENet coverage claim.
const PLAYER: PackedScene = preload("res://gameplay/player/player.tscn")
const COUNTER: Script = preload("res://gameplay/environment/upgrade_counter.gd")
var errors: Array[String] = []
var actor: Player
var offer: ShopOffer
var counter: Node3D
var session: SessionManager
var _tree: SceneTree
var _world: Node3D
var _save: SaveManager
var _old_save: SaveManager
var _old_session: SessionManager
var _old_scene: Node
var _snapshot: Dictionary
var _mouse: Input.MouseMode
var _dir: String = ""
var _sequence: int = 0
var _item_results: Dictionary = {}
var _upgrade_results: Dictionary = {}


func setup(tree: SceneTree, label: String) -> bool:
	_tree = tree
	_old_scene = tree.current_scene
	_old_session = SessionManager.instance
	_old_save = SaveManager.instance
	_mouse = Input.mouse_mode
	_snapshot = GameState.instance.get_snapshot().duplicate(true)
	_save = SaveManager.new()
	_save.use_test_save_dir("world_shop_%s_%d_%d" % [label,OS.get_process_id(),Time.get_ticks_usec()])
	_dir = _save.save_path.get_base_dir()
	SaveManager.instance = _save
	GameState.instance.reset_state()
	_world = Node3D.new()
	_world.name = "WorldShopTestFixture"
	tree.root.add_child(_world)
	tree.current_scene = _world
	if tree.current_scene != _world or _world.get_parent() != tree.root:
		errors.append("Fixture must be actual direct-root current_scene")
		return false
	session = SessionManager.new()
	session.scene_change_enabled = false
	SessionManager.instance = session
	_world.add_child(session)
	session._current_map = load("res://items/maps/praia.tres") as MapData
	session._ready_peers.assign([1])
	actor = PLAYER.instantiate() as Player
	actor.name = "1"
	_world.add_child(actor)
	actor.set_physics_process(false)
	actor.set_process(false)
	actor.position = Vector3(0,0,1)
	counter = COUNTER.new() as Node3D
	counter.set("map_id","praia")
	counter.position = Vector3(-1,0,0)
	_world.add_child(counter)
	offer = ShopOffer.new()
	offer.tool_data = GameState.instance.get_tool_data("estilingue")
	offer.position = Vector3(1,0,0)
	_world.add_child(offer)
	if not actor.is_node_ready() or not actor.is_local() or not actor.is_alive():
		errors.append("Normal local ready/alive Player required")
	if not bool(counter.call("host_can_purchase",1)) or not offer.host_can_purchase(1):
		errors.append("Actual physical offer/counter validation rejected fixture")
	GameState.instance.world_item_result.connect(_on_item)
	GameState.instance.world_upgrade_result.connect(_on_upgrade)
	return errors.is_empty()


func _on_item(id: int, item: String, success: bool, message: String) -> void:
	_item_results[id] = {"request_id":id,"item_id":item,"success":success,"message":message}


func _on_upgrade(id: int, upgrade: String, success: bool, message: String) -> void:
	_upgrade_results[id] = {"request_id":id,"upgrade_id":upgrade,"success":success,"message":message}


func buy_upgrade(id: String) -> Dictionary:
	_sequence += 1
	var request: int = _sequence
	GameState.instance.request_world_upgrade(id,counter.get_path(),request)
	for frame: int in range(60):
		await _tree.process_frame
		if _upgrade_results.has(request): break
	var result: Dictionary = _upgrade_results.get(request,{})
	if result.is_empty() or str(result.get("upgrade_id","")) != id:
		errors.append("Missing/mismatched real upgrade reply:"+id)
	return result


func buy_item(id: String) -> Dictionary:
	_sequence += 1
	var request: int = _sequence
	var canonical: ToolData = GameState.instance.get_tool_data(id)
	if canonical != null: offer.tool_data = canonical
	GameState.instance.request_world_item(id,offer.get_path(),request)
	for frame: int in range(60):
		await _tree.process_frame
		if _item_results.has(request): break
	var result: Dictionary = _item_results.get(request,{})
	if result.is_empty() or str(result.get("item_id","")) != id:
		errors.append("Missing/mismatched real item reply:"+id)
		return result
	if bool(result.get("success",false)):
		for frame: int in range(60):
			if GameState.instance.is_world_item_delivered(request): break
			await _tree.process_frame
		if not GameState.instance.is_world_item_delivered(request):
			errors.append("Paid item not actually delivered to Inventory:"+id)
	return result


func product_count(id: String) -> int:
	var count: int = 0
	for carried: CarriedItem in actor.inventory.slots:
		if carried != null and String(carried.tool_id) == id: count += 1
	return count


func cleanup() -> void:
	var state: GameState = GameState.instance
	if state.world_item_result.is_connected(_on_item): state.world_item_result.disconnect(_on_item)
	if state.world_upgrade_result.is_connected(_on_upgrade): state.world_upgrade_result.disconnect(_on_upgrade)
	_tree.current_scene = _old_scene
	if is_instance_valid(_world): _world.free()
	SessionManager.instance = _old_session
	SaveManager.instance = _old_save
	state.reset_state()
	state.load_snapshot(_snapshot)
	if is_instance_valid(_save): _save.free()
	for file_name: String in DirAccess.get_files_at(_dir):
		DirAccess.remove_absolute(_dir.path_join(file_name))
	DirAccess.remove_absolute(_dir)
	Input.mouse_mode = _mouse
