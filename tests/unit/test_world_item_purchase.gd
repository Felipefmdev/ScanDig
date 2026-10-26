extends GutTest

## #186 ToolData commerce only: real offer/catalogue/actor/core, no upgrade ledger.
## Host-local correlation tests; per-remote-peer isolation still needs real ENet.
const PLAYER: PackedScene = preload("res://gameplay/player/player.tscn")
const PRODUCT: ToolData = preload("res://items/tools/repelente.tres")
const OTHER_PRODUCT: ToolData = preload("res://items/tools/estilingue.tres")

class OfferFake extends Node3D:
	func host_can_purchase(_peer: int) -> bool:
		return true

var _original_session: SessionManager
var _original_save: SaveManager
var _original_scene: Node
var _original_mouse: int
var _snapshot: Dictionary
var _world: Node3D = null
var _session: SessionManager = null
var _save: SaveManager = null
var _offer: ShopOffer = null
var _actor: Player = null
var _dir: String = ""
var _sequence: int = 0
var _replies: Array[Dictionary] = []


func before_each() -> void:
	_original_session = SessionManager.instance
	_original_save = SaveManager.instance
	_original_scene = get_tree().current_scene
	_original_mouse = Input.mouse_mode
	_snapshot = GameState.instance.get_snapshot().duplicate(true)
	GameState.instance.reset_state()
	GameState.instance.team_money = 10000
	_replies.clear()
	_sequence = 0


func after_each() -> void:
	_restore_integration_state()
	var state: GameState = GameState.instance
	if state.has_signal("world_item_result") and state.is_connected("world_item_result", _on_result):
		state.disconnect("world_item_result", _on_result)
	get_tree().current_scene = _original_scene
	# Also free an offer temporarily reparented outside the fixture scene.
	if is_instance_valid(_offer): _offer.free()
	if is_instance_valid(_world): _world.free()
	SessionManager.instance = _original_session
	SaveManager.instance = _original_save
	state.reset_state() # Clear ephemeral purchase ledgers, then restore persisted snapshot.
	state.load_snapshot(_snapshot)
	if is_instance_valid(_save): _save.free()
	if not _dir.is_empty():
		for file_name: String in DirAccess.get_files_at(_dir):
			DirAccess.remove_absolute(_dir.path_join(file_name))
		DirAccess.remove_absolute(_dir)
	Input.mouse_mode = _original_mouse
	_world = null
	_offer = null
	_actor = null
	_session = null
	_save = null
	_dir = ""
	await get_tree().process_frame


func _fixture() -> bool:
	var state: GameState = GameState.instance
	var present: bool = state.has_method("request_world_item")
	assert_true(present, "Production request_world_item API must exist")
	assert_true(state.has_signal("world_item_result"), "Production correlated item signal must exist")
	if not present or not state.has_signal("world_item_result"): return false
	_offer = ShopOffer.new()
	assert_true(_offer.has_method("host_can_purchase"), "Real ShopOffer physical host validation must exist")
	if not _offer.has_method("host_can_purchase"): return false
	_world = Node3D.new()
	_world.name = "WorldItemPurchaseFixture"
	get_tree().root.add_child(_world)
	get_tree().current_scene = _world
	assert_true(_world.get_parent() == get_tree().root)
	assert_true(get_tree().current_scene == _world)
	_save = SaveManager.new()
	_save.use_test_save_dir("world_item_purchase_186_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()])
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
	# Disable ongoing movement only after normal Player._ready has completed.
	_actor.set_physics_process(false)
	_actor.set_process(false)
	_actor.position = Vector3(0,0,1)
	_offer.tool_data = PRODUCT
	_world.add_child(_offer)
	assert_true(_offer.is_in_group(ShopOffer.GROUP))
	assert_true(PRODUCT == state.get_tool_data(String(PRODUCT.id)), "Exact cached canonical ToolData")
	assert_gt(PRODUCT.price,0)
	state.connect("world_item_result",_on_result)
	return true


func _on_result(request_id: int, item_id: String, success: bool, message: String) -> void:
	_replies.append({"request_id": request_id, "item_id": item_id, "success": success,
		"message": message, "snapshot": GameState.instance.get_snapshot().duplicate(true)})


func _request(item_id: String, path: NodePath, request_id: int = -1) -> Dictionary:
	if request_id < 0:
		_sequence += 1
		request_id = _sequence
	else: _sequence = maxi(_sequence,request_id)
	var count: int = _replies.size()
	GameState.instance.call("request_world_item",item_id,path,request_id)
	for frame: int in range(30):
		await get_tree().process_frame
		if _replies.size() > count: break
	assert_eq(_replies.size(),count+1,"One correlated reply for every local request")
	if _replies.size() <= count: return {}
	var reply: Dictionary = _replies.back()
	assert_eq(int(reply.get("request_id",-1)),request_id)
	assert_eq(str(reply.get("item_id","")),item_id)
	return reply


func _deny(item_id: String = "repelente", path: NodePath = NodePath("")) -> void:
	var before: Dictionary = GameState.instance.get_snapshot().duplicate(true)
	var target: NodePath = _offer.get_path() if path.is_empty() else path
	var reply: Dictionary = await _request(item_id,target)
	assert_false(bool(reply.get("success",true)))
	assert_eq(GameState.instance.get_snapshot(),before,"Denied item request cannot charge/change progression")


func test_legacy_purchase_without_physical_context_is_denied_without_debit() -> void:
	# No new-API guard here: legacy must produce a behavioral RED before implementation.
	var state: GameState = GameState.instance
	var before: Dictionary = state.get_snapshot().duplicate(true)
	watch_signals(state)
	state.request_purchase_item("repelente")
	await wait_frames(2)
	assert_eq(state.get_snapshot(),before,"Legacy context-free request must not charge")
	assert_signal_emitted(state,"item_purchase_result")
	var args: Variant = get_signal_parameters(state,"item_purchase_result")
	if args is Array and args.size() >= 2:
		assert_false(bool(args[1]),"Legacy request explicitly denied")


func test_valid_real_offer_charges_exact_catalogue_price_before_result() -> void:
	if not _fixture(): return
	var state: GameState = GameState.instance
	var money: int = state.team_money
	var upgrades: Dictionary = state.upgrade_levels.duplicate(true)
	watch_signals(state)
	var reply: Dictionary = await _request("repelente",_offer.get_path(),1)
	assert_true(bool(reply.get("success",false)))
	assert_eq(state.team_money,money-PRODUCT.price)
	assert_eq(int((reply.get("snapshot",{}) as Dictionary).get("team_money",-1)),money-PRODUCT.price)
	assert_eq(state.upgrade_levels,upgrades,"ToolData purchase never changes upgrade levels")
	assert_signal_emitted(state,"state_synced")


func test_same_request_replays_without_charge_and_product_or_offer_collision_denies() -> void:
	if not _fixture(): return
	var path: NodePath = _offer.get_path()
	var reply: Dictionary = await _request("repelente",path,1)
	assert_true(bool(reply.get("success",false)))
	var bought: Dictionary = GameState.instance.get_snapshot().duplicate(true)
	reply = await _request("repelente",path,1)
	assert_true(bool(reply.get("success",false)),"Identical payload replays the receipt")
	assert_eq(GameState.instance.get_snapshot(),bought)
	reply = await _request("estilingue",path,1)
	assert_false(bool(reply.get("success",true)),"Same ID/different product collision")
	assert_eq(GameState.instance.get_snapshot(),bought)
	var second_offer: ShopOffer = ShopOffer.new()
	second_offer.tool_data = PRODUCT
	_world.add_child(second_offer)
	reply = await _request("repelente",second_offer.get_path(),1)
	assert_false(bool(reply.get("success",true)),"Same ID/different canonical offer collision")
	assert_eq(GameState.instance.get_snapshot(),bought)


func test_new_ids_buy_existing_consumable_again_without_touching_upgrade_ledger() -> void:
	if not _fixture(): return
	var money: int = GameState.instance.team_money
	var first: Dictionary = await _request("repelente",_offer.get_path(),1)
	var second: Dictionary = await _request("repelente",_offer.get_path(),2)
	assert_true(bool(first.get("success",false)))
	assert_true(bool(second.get("success",false)))
	assert_eq(GameState.instance.team_money,money-2*PRODUCT.price)
	assert_eq(int(second.get("request_id",-1)),2)
	assert_eq(GameState.instance.get_upgrade_level("detector"),0)


func test_unready_wrong_authority_dead_downed_and_out_of_range_are_denied() -> void:
	if not _fixture(): return
	_session._ready_peers.clear()
	await _deny()
	_session._ready_peers.assign([1])
	_actor.set_multiplayer_authority(777)
	await _deny()
	_actor.set_multiplayer_authority(1)
	_actor.health = 0.0
	await _deny()
	_actor.health = _actor.max_health
	_actor.is_downed = true
	await _deny()
	_actor.is_downed = false
	_actor.position.z = 3.0
	await _deny()


func test_missing_real_actor_and_plain_group_impostor_are_denied() -> void:
	if not _fixture(): return
	_actor.free()
	_actor = null
	await _deny()
	var impostor: Node3D = Node3D.new()
	impostor.name = "1"
	_world.add_child(impostor)
	impostor.add_to_group(&"players")
	await _deny()


func test_actual_layer_one_wall_blocks_purchase_line_of_sight() -> void:
	if not _fixture(): return
	var wall: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(2,3,.2)
	shape.shape = box
	wall.add_child(shape)
	_world.add_child(wall)
	wall.position = Vector3(0,1,.5)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _deny()


func test_requested_product_must_equal_offer_and_exact_canonical_resource() -> void:
	if not _fixture(): return
	await _deny("estilingue")
	var cloned: ToolData = PRODUCT.duplicate(true) as ToolData
	assert_true(cloned != PRODUCT)
	_offer.tool_data = cloned
	await _deny("repelente")
	_offer.tool_data = OTHER_PRODUCT
	await _deny("repelente")
	_offer.tool_data = PRODUCT
	var reply: Dictionary = await _request("repelente",_offer.get_path())
	assert_true(bool(reply.get("success",false)),"Canonical resource succeeds with a fresh request")


func test_group_fake_node_missing_path_and_offer_outside_current_scene_are_denied() -> void:
	if not _fixture(): return
	await _deny("repelente",NodePath("/root/NoPhysicalOffer186"))
	var fake: OfferFake = OfferFake.new()
	_world.add_child(fake)
	fake.add_to_group(ShopOffer.GROUP)
	await _deny("repelente",fake.get_path())
	_offer.remove_from_group(ShopOffer.GROUP)
	await _deny()
	_offer.add_to_group(ShopOffer.GROUP)
	_world.remove_child(_offer)
	add_child(_offer)
	await _deny("repelente",_offer.get_path())


func test_insufficient_money_invalid_product_and_nonpositive_request_id_do_not_charge() -> void:
	if not _fixture(): return
	GameState.instance.team_money = PRODUCT.price-1
	await _deny()
	GameState.instance.team_money = 10000
	for invalid: String in ["","../repelente","produto_inexistente_186"]:
		await _deny(invalid)
	var before: Dictionary = GameState.instance.get_snapshot().duplicate(true)
	var reply: Dictionary = await _request("repelente",_offer.get_path(),0)
	assert_false(bool(reply.get("success",true)))
	assert_eq(GameState.instance.get_snapshot(),before)


## Delivery broker extension. The ten authorization tests above remain unchanged.
func _has_delivery_api() -> bool:
	var state: GameState = GameState.instance
	var present: bool = state.has_method("is_world_item_delivered")
	assert_true(present,"Real core delivery status API must exist; no fixture substitute")
	assert_true(state.has_signal("world_item_delivered"),"Real post-add delivery signal must exist")
	return present and state.has_signal("world_item_delivered")


func _product_count(inventory: Inventory) -> int:
	var count: int = 0
	for carried: CarriedItem in inventory.slots:
		if carried != null and carried.tool_id == PRODUCT.id:
			count += 1
	return count


func _await_real_delivery(request_id: int) -> bool:
	for frame: int in range(30):
		if bool(GameState.instance.call("is_world_item_delivered",request_id)): return true
		await get_tree().process_frame
	return bool(GameState.instance.call("is_world_item_delivered",request_id))


func test_paid_item_waits_for_real_bag_space_then_delivers_once_despite_replay() -> void:
	if not _has_delivery_api() or not _fixture(): return
	var state: GameState = GameState.instance
	var bag: Inventory = _actor.inventory
	var money: int = state.team_money
	var boundary: Dictionary = {"filled": false, "callback": false}
	# Fill AFTER authorization, synchronously inside its result callback and before
	# the next broker _process. Fillers are unrelated real ToolData-backed items.
	var fill_on_result: Callable = func(request_id: int, _item_id: String, success: bool, _message: String) -> void:
		if request_id != 1 or not success: return
		boundary["callback"] = true
		for slot: int in range(bag.capacity):
			if bag.is_full(): break
			bag.add_item(CarriedItem.create_from_tool_data(OTHER_PRODUCT))
		boundary["filled"] = bag.is_full()
	state.connect("world_item_result",fill_on_result,CONNECT_ONE_SHOT)
	watch_signals(state)
	var path: NodePath = _offer.get_path()
	var reply: Dictionary = await _request("repelente",path,1)
	if state.is_connected("world_item_result",fill_on_result): state.disconnect("world_item_result",fill_on_result)
	assert_true(bool(reply.get("success",false)))
	assert_true(bool(boundary["callback"]))
	assert_true(bool(boundary["filled"]),"Race setup fills bag with real Inventory.add_item")
	await wait_frames(3)
	assert_eq(state.team_money,money-PRODUCT.price,"Authorization charged exactly once")
	assert_false(bool(state.call("is_world_item_delivered",1)),"Full bag leaves paid delivery pending")
	assert_eq(_product_count(bag),0,"Authorization alone is not an inventory grant")
	assert_signal_not_emitted(state,"world_item_delivered")
	var blocker: int = -1
	for slot: int in range(bag.capacity):
		var carried: CarriedItem = bag.get_item(slot)
		if carried != null and carried.tool_id == OTHER_PRODUCT.id:
			blocker = slot
			break
	assert_gte(blocker,0,"Find a filler slot to release through real Inventory API")
	if blocker < 0: return
	assert_not_null(bag.remove_at(blocker))
	assert_true(await _await_real_delivery(1),"One newly available slot releases the queued item")
	assert_eq(_product_count(bag),1)
	assert_signal_emitted_with_parameters(state,"world_item_delivered",[1,"repelente"])
	assert_signal_emit_count(state,"world_item_delivered",1)
	reply = await _request("repelente",path,1)
	assert_true(bool(reply.get("success",false)),"Replay is the same paid intent")
	await wait_frames(3)
	assert_eq(state.team_money,money-PRODUCT.price)
	assert_true(bool(state.call("is_world_item_delivered",1)))
	assert_eq(_product_count(bag),1,"Replayed success cannot manufacture another CarriedItem")
	assert_signal_emit_count(state,"world_item_delivered",1)


func test_paid_delivery_survives_offer_free_after_authorization() -> void:
	if not _has_delivery_api() or not _fixture(): return
	var state: GameState = GameState.instance
	var bag: Inventory = _actor.inventory
	var money: int = state.team_money
	var boundary: Dictionary = {"offer_freed": false}
	var free_on_result: Callable = func(request_id: int, _item_id: String, success: bool, _message: String) -> void:
		if request_id != 1 or not success: return
		_offer.free()
		_offer = null
		boundary["offer_freed"] = true
	state.connect("world_item_result",free_on_result,CONNECT_ONE_SHOT)
	watch_signals(state)
	var path: NodePath = _offer.get_path()
	var reply: Dictionary = await _request("repelente",path,1)
	if state.is_connected("world_item_result",free_on_result): state.disconnect("world_item_result",free_on_result)
	assert_true(bool(reply.get("success",false)))
	assert_true(bool(boundary["offer_freed"]),"Offer is gone before broker processes delivery")
	assert_false(is_instance_valid(_offer))
	assert_true(await _await_real_delivery(1),"Broker, not the destroyed offer, owns pending item")
	assert_eq(state.team_money,money-PRODUCT.price)
	assert_eq(_product_count(bag),1)
	assert_signal_emit_count(state,"world_item_delivered",1)


func test_dead_owner_defers_delivery_until_a_real_ready_live_replacement_exists() -> void:
	if not _has_delivery_api() or not _fixture(): return
	var state: GameState = GameState.instance
	var money: int = state.team_money
	var boundary: Dictionary = {"dead": false}
	var death_on_result: Callable = func(request_id: int, _item_id: String, success: bool, _message: String) -> void:
		if request_id != 1 or not success: return
		# Diagnostic race setup, not a claim about combat/respawn gameplay.
		_actor.health = 0.0
		boundary["dead"] = true
	state.connect("world_item_result",death_on_result,CONNECT_ONE_SHOT)
	watch_signals(state)
	var reply: Dictionary = await _request("repelente",_offer.get_path(),1)
	if state.is_connected("world_item_result",death_on_result): state.disconnect("world_item_result",death_on_result)
	assert_true(bool(reply.get("success",false)))
	assert_true(bool(boundary["dead"]))
	await wait_frames(3)
	assert_false(bool(state.call("is_world_item_delivered",1)))
	assert_eq(_product_count(_actor.inventory),0)
	assert_signal_not_emitted(state,"world_item_delivered")
	_actor.free()
	_actor = null
	await wait_frames(3)
	assert_false(bool(state.call("is_world_item_delivered",1)),"No owner actor is not a delivery target")
	_actor = PLAYER.instantiate() as Player
	_actor.name = "1"
	_world.add_child(_actor)
	_actor.set_physics_process(false)
	_actor.set_process(false)
	assert_true(_actor.is_node_ready())
	assert_true(_actor.is_alive())
	assert_true(_actor.is_local())
	assert_true(_session.is_peer_scene_ready(1))
	assert_true(await _await_real_delivery(1))
	assert_eq(state.team_money,money-PRODUCT.price)
	assert_eq(_product_count(_actor.inventory),1)
	assert_signal_emit_count(state,"world_item_delivered",1)


## Real core adapter: only records requests and delays actual receive-result calls.
## Validation, ledger, debit, snapshot, _process broker and Inventory.add_item are inherited.
class DelayedItemResults extends GameState:
	var requested_ids: Array[int] = []
	var held: Array[Dictionary] = []
	var released_count: int = 0
	var hold_results: bool = true

	func request_world_item(item_id: String, offer_path: NodePath, request_id: int) -> void:
		requested_ids.append(request_id)
		super.request_world_item(item_id,offer_path,request_id)

	@rpc("authority", "call_remote", "reliable")
	func _receive_world_item_result(request_id: int, item_id: String, success: bool, message: String) -> void:
		if hold_results:
			held.append({"request_id":request_id,"item_id":item_id,"success":success,"message":message})
		else:
			super._receive_world_item_result(request_id,item_id,success,message)

	func release_all() -> void:
		hold_results = false
		var replies: Array[Dictionary] = held.duplicate(true)
		held.clear()
		for reply: Dictionary in replies:
			released_count += 1
			super._receive_world_item_result(int(reply["request_id"]),str(reply["item_id"]),bool(reply["success"]),str(reply["message"]))

var _integration_state: DelayedItemResults = null
var _integration_original: GameState = null


func _install_delayed_state() -> bool:
	# Check the real base before using an override which would otherwise hide absence.
	var state: GameState = GameState.instance
	assert_true(state.has_method("request_world_item"))
	assert_true(state.has_method("_receive_world_item_result"))
	if not state.has_method("request_world_item") or not state.has_method("_receive_world_item_result"):
		return false
	_integration_original = state
	var initial: Dictionary = state.get_snapshot().duplicate(true)
	_integration_state = DelayedItemResults.new()
	# The autoload stays alive; this adapter owns only its own inherited live broker.
	get_tree().root.add_child(_integration_state)
	GameState.instance = _integration_state
	_integration_state.load_snapshot(initial)
	return true


func _restore_integration_state() -> void:
	if is_instance_valid(_integration_state):
		if _integration_state.is_connected("world_item_result",_on_result):
			_integration_state.disconnect("world_item_result",_on_result)
		# Restore FIRST; inherited _exit_tree must not clear the actual autoload instance.
		GameState.instance = _integration_original
		_integration_state.free()
	_integration_state = null
	_integration_original = null


func test_shop_offer_try_buy_returns_null_carried_after_real_broker_delivery() -> void:
	if not _has_delivery_api() or not _fixture(): return
	var money: int = GameState.instance.team_money
	var bag: Inventory = _actor.inventory
	assert_eq(_product_count(bag),0)
	var result: Dictionary = await _offer.try_buy(bag)
	assert_true(bool(result.get("ok",false)),"Real ShopOffer uses contextual item purchase")
	assert_true(result.has("carried"))
	assert_null(result.get("carried"),"Player must not add a second CarriedItem after broker already delivered")
	assert_eq(_product_count(bag),1,"Exactly one real inventory grant through broker")
	assert_eq(GameState.instance.team_money,money-PRODUCT.price)
	await wait_frames(3)
	assert_eq(_product_count(bag),1)
	assert_eq(GameState.instance.team_money,money-PRODUCT.price)


func test_shop_offer_real_timeout_retry_reuses_paid_intent_then_new_purchase_uses_new_id() -> void:
	if not _has_delivery_api() or not _install_delayed_state(): return
	if not _fixture(): return # after_each restores static instance even on guard failure.
	var state: DelayedItemResults = _integration_state
	var bag: Inventory = _actor.inventory
	var money: int = state.team_money
	assert_lte(bag.get_count(),bag.capacity-2,"Normal initial bag has room for two actual consumables")
	if bag.get_count() > bag.capacity-2: return
	var started: int = Time.get_ticks_msec()
	var first: Dictionary = await _offer.try_buy(bag)
	var elapsed: int = Time.get_ticks_msec()-started
	assert_gte(elapsed,5000,"Wait the actual unchanged five-second offer timeout")
	assert_false(bool(first.get("ok",true)),"Withheld real result times out")
	assert_null(first.get("carried"))
	assert_eq(state.requested_ids.size(),1,"First try reached the REAL contextual endpoint")
	assert_eq(state.held.size(),1,"Adapter retained the real host reply")
	assert_eq(state.team_money,money-PRODUCT.price,"Host actually charged before the timeout")
	assert_eq(_product_count(bag),0,"No fabricated grant before real reply reaches broker")
	if state.requested_ids.size() != 1 or state.held.size() != 1: return
	assert_true(bool(state.held[0]["success"]),"Withheld response was a genuine successful authorization")
	var first_id: int = state.requested_ids[0]
	assert_false(state.is_world_item_delivered(first_id))
	# A genuine0.2s SceneTreeTimer releases A+B during the second await. No clock,
	# time_scale, PURCHASE_TIMEOUT or host result is edited by the fixture.
	var release_timer: SceneTreeTimer = get_tree().create_timer(.2)
	release_timer.timeout.connect(state.release_all,CONNECT_ONE_SHOT)
	var second: Dictionary = await _offer.try_buy(bag)
	# Drain the real timer even when a buggy retry returns early; no freed callback.
	if release_timer.time_left > 0.0: await release_timer.timeout
	assert_eq(state.requested_ids.size(),2)
	if state.requested_ids.size() >= 2:
		assert_eq(state.requested_ids[1],first_id,"Retry reuses the unresolved paid intent")
	assert_eq(state.released_count,2,"Release both genuine original/replayed replies")
	assert_true(bool(second.get("ok",false)))
	assert_null(second.get("carried"))
	assert_true(state.is_world_item_delivered(first_id))
	assert_eq(_product_count(bag),1)
	assert_eq(state.team_money,money-PRODUCT.price,"Retry never charges again")
	var third: Dictionary = await _offer.try_buy(bag)
	assert_true(bool(third.get("ok",false)),"Explicit later purchase is a new intent")
	assert_null(third.get("carried"))
	assert_eq(state.requested_ids.size(),3)
	if state.requested_ids.size() >= 3:
		assert_ne(state.requested_ids[2],first_id,"Success releases intent for next purchase")
	assert_eq(_product_count(bag),2)
	assert_eq(state.team_money,money-2*PRODUCT.price)
	await wait_frames(3)
	assert_eq(_product_count(bag),2)
