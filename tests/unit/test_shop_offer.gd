extends GutTest

## ShopOffer.try_buy() uses a real contextual offer and the core delivery broker.
## Host-local unit integration, not an ENet or campaign claim.

const SLINGSHOT: ToolData = preload("res://items/tools/estilingue.tres")
const PITCHFORK: ToolData = preload("res://items/tools/forcado.tres")
const PLAYER: PackedScene = preload("res://gameplay/player/player.tscn")

var offer: ShopOffer
var inv: Inventory
var state: GameState
var _snapshot: Dictionary = {}
var _original_scene: Node
var _original_session: SessionManager
var _original_save: SaveManager
var _original_mouse: int
var _world: Node3D
var _session: SessionManager
var _save: SaveManager
var _actor: Player
var _dir: String = ""


func before_each() -> void:
	state = GameState.instance
	_snapshot = state.get_snapshot().duplicate(true)
	_original_scene = get_tree().current_scene
	_original_session = SessionManager.instance
	_original_save = SaveManager.instance
	_original_mouse = Input.mouse_mode
	state.reset_state()
	_world = Node3D.new()
	_world.name = "ShopOfferIntegrationWorld"
	get_tree().root.add_child(_world)
	get_tree().current_scene = _world
	assert_true(_world.get_parent() == get_tree().root)
	assert_true(get_tree().current_scene == _world)
	_save = SaveManager.new()
	_save.use_test_save_dir("shop_offer_186_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()])
	_dir = _save.save_path.get_base_dir()
	SaveManager.instance = _save
	_session = SessionManager.new()
	_session.scene_change_enabled = false
	SessionManager.instance = _session
	_world.add_child(_session)
	_session._current_map = load("res://items/maps/praia.tres") as MapData
	_session._ready_peers.assign([1])
	_actor = PLAYER.instantiate() as Player
	_actor.name = "1"
	_world.add_child(_actor)
	_actor.set_physics_process(false)
	_actor.set_process(false)
	_actor.position = Vector3(0,0,1)
	inv = _actor.inventory
	offer = ShopOffer.new()
	offer.tool_data = SLINGSHOT
	_world.add_child(offer)
	assert_true(offer.is_in_group(ShopOffer.GROUP))
	assert_true(_actor.is_node_ready())
	assert_true(_actor.is_local())
	assert_true(_actor.is_alive())


func after_each() -> void:
	get_tree().current_scene = _original_scene
	if is_instance_valid(_world): _world.free()
	SessionManager.instance = _original_session
	SaveManager.instance = _original_save
	state.reset_state() # Clear ephemeral item ledger/queue, then restore real snapshot.
	state.load_snapshot(_snapshot)
	if is_instance_valid(_save): _save.free()
	for file_name: String in DirAccess.get_files_at(_dir):
		DirAccess.remove_absolute(_dir.path_join(file_name))
	DirAccess.remove_absolute(_dir)
	Input.mouse_mode = _original_mouse
	await get_tree().process_frame


func _loot() -> CarriedItem:
	var item: ItemData = ItemData.new()
	item.id = "teste"
	return CarriedItem.create(item, 10, 1.0, false)


func test_buy_debits_on_host_and_delivers_one_tool() -> void:
	state.team_money = SLINGSHOT.price + 50
	assert_true(offer.host_can_purchase(1),"Real physical context is eligible before payment")
	watch_signals(state)
	var r: Dictionary = await offer.try_buy(inv)
	assert_true(r["ok"], r["message"])
	assert_eq(state.team_money, 50)
	assert_null(r["carried"],"Broker already delivered; Player must not grant again")
	var delivered: Array[CarriedItem] = []
	for c: CarriedItem in inv.slots:
		if c != null and c.tool_id == SLINGSHOT.id: delivered.append(c)
	assert_eq(delivered.size(),1,"One real slingshot in the actual Player inventory")
	if delivered.size() == 1:
		assert_true(delivered[0].is_tool())
		assert_true(delivered[0].tool_data == SLINGSHOT)
	assert_signal_emit_count(state,"world_item_delivered",1)


func test_insufficient_money_keeps_balance() -> void:
	state.team_money = SLINGSHOT.price - 1
	assert_true(offer.host_can_purchase(1),"Insufficient balance is checked at a valid physical bank")
	var r: Dictionary = await offer.try_buy(inv)
	assert_false(r["ok"])
	assert_string_contains(r["message"], "Saldo insuficiente")
	assert_eq(state.team_money, SLINGSHOT.price - 1)
	assert_null(r["carried"])
	for c: CarriedItem in inv.slots:
		if c != null: assert_ne(c.tool_id,SLINGSHOT.id)


func test_full_backpack_does_not_request() -> void:
	state.team_money = 1000
	for i: int in range(inv.capacity-inv.get_count()):
		assert_true(inv.add_item(_loot()))
	assert_true(inv.is_full())
	watch_signals(state)
	var r: Dictionary = await offer.try_buy(inv)
	assert_false(r["ok"])
	assert_eq(state.team_money, 1000)
	assert_signal_not_emitted(state,"world_item_result","Full initial bag never requests payment")


func test_unknown_tool_is_unavailable() -> void:
	var fake: ToolData = ToolData.new()
	fake.id = &"nao_existe"
	fake.price = 10
	offer.tool_data = fake
	state.team_money = 1000
	var r: Dictionary = await offer.try_buy(inv)
	assert_false(r["ok"])
	assert_eq(state.team_money, 1000)


func test_world_scene_offer_does_not_add_fallback_box() -> void:
	var world_scene_offer: ShopOffer = ShopOffer.new()
	world_scene_offer.tool_data = PITCHFORK
	_world.add_child(world_scene_offer)

	var fallback_boxes: Array[MeshInstance3D] = []
	var has_world_model: bool = false
	for child: Node in world_scene_offer.get_children():
		if child is MeshInstance3D:
			fallback_boxes.append(child as MeshInstance3D)
		if child.scene_file_path == PITCHFORK.world_scene.resource_path:
			has_world_model = true

	assert_true(has_world_model, "A oferta deve instanciar o modelo da ferramenta.")
	assert_eq(fallback_boxes.size(), 0, "Uma world_scene não deve deixar a caixa MeshInstance3D órfã.")
