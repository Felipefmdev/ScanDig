extends GutTest

## Real production Session machine; only its outbound local ACK is held.
class HeldAckSession extends SessionManager:
	var held_token: int = 0
	func _send_rocket_prepare_ack(token: int) -> void:
		held_token = token
	func deliver_held_local_ack() -> bool:
		return _accept_rocket_prepare_ack(HOST_PEER_ID,held_token)

var saved_state: Dictionary
var session: HeldAckSession
var station: Node3D
var actor: Player
var placement: Node3D
var board: Interactable
var carried: CarriedItem
var adapter: GDScript

func before_each() -> void:
	saved_state = GameState.instance.get_snapshot()
	GameState.instance.completed_quests = ["vega_sinal","vega_foguete"]
	GameState.instance.defeated_bosses = ["the_sleeper"]
	session = HeldAckSession.new()
	session.scene_change_enabled = false
	add_child_autofree(session)
	session._current_map = load("res://items/maps/cratera.tres") as MapData
	session._ready_peers = [1]
	session._pending_summary = {"day":7,"map_id":"cratera","entries":[{"name":"Existing find","value":42}],"money_start":100}
	# Same disk-only adapter used by official station/departure-save tests.
	adapter = GDScript.new()
	adapter.source_code = "extends \"res://gameplay/quests/cratera/crater_rocket_station.gd\"\nvar save_calls: int = 0\nvar save_phases: Array[String] = []\nfunc _save_before_departure() -> bool:\n\tsave_calls += 1\n\tsave_phases.append(str(_session.get_rocket_transition()[\"phase\"]))\n\treturn true\n"
	assert_eq(adapter.reload(),OK,"Production station adapter parses; no staged source fallback")
	station = adapter.new() as Node3D
	add_child_autofree(station)
	placement = load("res://gameplay/environment/crater_rocket.gd").new() as Node3D
	placement.position = Vector3(-23,0,21)
	add_child_autofree(placement)
	assert_true(bool(station.call("configure",placement,session)))
	board = station.call("get_point",&"board") as Interactable
	assert_not_null(board)
	actor = load("res://gameplay/player/player.tscn").instantiate() as Player
	actor.name = "1"
	add_child_autofree(actor)
	actor.set_physics_process(false)
	actor.set_process(false)
	# Deliver settings/UI deferred callbacks before seeding exact carried state.
	await get_tree().process_frame
	await get_tree().process_frame
	actor.global_position = board.global_position+Vector3(0,0,.8)
	await get_tree().physics_frame
	await get_tree().physics_frame
	actor.set_physics_process(true)
	actor.set_process_input(true)
	actor.set_process_unhandled_input(true)
	actor.held_tool_id = &""
	actor.carrying_loot = false
	actor.health = 63.0
	actor.hunger = 41.0
	actor.session_money = 123
	actor.session_items_count = 4
	carried = CarriedItem.new()
	carried.tool_id = "lanterna_magnesio"
	carried.charges = 2
	carried.wear = 37
	actor.inventory.slots[1] = carried
	actor.inventory.selected_slot = 1

func after_each() -> void:
	GameState.instance.apply_snapshot(saved_state)
	await get_tree().process_frame
	await get_tree().process_frame

func _phase() -> String:
	return str(session.get_rocket_transition()["phase"])

func _board_into_prepare() -> int:
	assert_true(bool(station.call("host_request_board",1)),"Real station accepts safe repaired boarding")
	assert_eq(_phase(),"PREPARING","Held ACK observes the production prepare phase")
	assert_eq(session.get_current_map().id,"cratera")
	assert_eq(int(station.get("save_calls")),1)
	assert_eq(station.get("save_phases"),["IDLE"],"Persist before beginning prepare")
	assert_gt(session.held_token,0)
	assert_false(actor.is_physics_processing())
	assert_false(actor.is_processing_input())
	assert_false(actor.is_processing_unhandled_input())
	return session.held_token

func _assert_original_inventory() -> void:
	assert_same(actor.inventory.slots[1],carried)
	assert_eq(carried.charges,2)
	assert_eq(carried.wear,37)
	assert_eq(actor.inventory.selected_slot,1)
	assert_eq(actor.health,63.0)
	assert_eq(actor.hunger,41.0)
	assert_eq(actor.session_money,123)
	assert_eq(actor.session_items_count,4)

func test_cancel_reactivates_board_and_retry_same_station_preserves_payload_and_save_order() -> void:
	var station_id: int = station.get_instance_id()
	var day: int = GameState.instance.current_day
	var money: int = GameState.instance.team_money
	var summary: Dictionary = session._pending_summary.duplicate(true)
	var first: int = _board_into_prepare()
	assert_true(session.cancel_rocket_transition(first))
	assert_eq(_phase(),"IDLE")
	assert_eq(session.get_current_map().id,"cratera")
	assert_true(session._rocket_payload.is_empty())
	assert_true(actor.is_physics_processing())
	assert_true(actor.is_processing_input())
	assert_true(actor.is_processing_unhandled_input())
	_assert_original_inventory()
	assert_true(board.active,"Canceled departure must reactivate the real BOARD point")
	assert_eq(station.get_instance_id(),station_id,"Do not rebuild/configure another station to retry")
	assert_true(bool(station.call("host_request_board",1)),"Retry on SAME station after cancel")
	assert_eq(_phase(),"PREPARING")
	assert_gt(session.held_token,first,"Retry starts a new monotonic transaction")
	assert_eq(int(station.get("save_calls")),2,"Retry persists before its own prepare")
	assert_eq(station.get("save_phases"),["IDLE","IDLE"])
	assert_eq(GameState.instance.current_day,day)
	assert_eq(GameState.instance.team_money,money)
	assert_eq(session._pending_summary,summary)
	assert_eq(GameState.instance.completed_quests.count("vega_foguete"),1)
	_assert_original_inventory()

func test_no_reentry_or_extra_save_during_prepare() -> void:
	var token: int = _board_into_prepare()
	assert_false(bool(station.call("host_request_board",1)))
	assert_eq(_phase(),"PREPARING")
	assert_eq(session.held_token,token)
	assert_eq(int(station.get("save_calls")),1)
	assert_false(board.active)
	_assert_original_inventory()

func test_no_reentry_or_extra_save_during_committing() -> void:
	_board_into_prepare()
	# Deliver the held transport ACK to the real host handler, outside any RPC.
	# Actual production cleanup/_call_all/commit execute; no simulated commit call.
	assert_true(session.deliver_held_local_ack())
	assert_eq(_phase(),"COMMITTING")
	assert_eq(session.get_current_map().id,"lua")
	assert_false(bool(station.call("host_request_board",1)))
	assert_eq(int(station.get("save_calls")),1)
	assert_false(board.active)
	_assert_original_inventory()
