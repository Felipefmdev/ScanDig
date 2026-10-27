extends GutTest

## RED contract against the real SessionManager. No replacement state machine.
## Transport is held so each local boundary can be inspected before delivery.
class HeldSession extends SessionManager:
	var sent: Array[Dictionary] = []
	var captures: int = 0
	var cleanup_calls: int = 0
	var cleanup_had_payload: bool = false
	var cleanup_player_alive: bool = false
	var observed_player: Player

	func _call_all(method: StringName, args: Array) -> void:
		sent.append({"method":method,"args":args.duplicate(true),"cleanup_calls":cleanup_calls})

	func capture_rocket_payload(player: Player) -> bool:
		captures += 1
		return super.capture_rocket_payload(player)

	# Proposed transport seam only: production sends ACK to host (or local host handler).
	func _send_rocket_prepare_ack(token: int) -> void:
		sent.append({"method":&"ACK","args":[token]})

	# Proposed host cleanup seam. This spy deliberately does NOT prove real despawns.
	func _cleanup_rocket_generation() -> bool:
		cleanup_calls += 1
		cleanup_had_payload = not _rocket_payload.is_empty()
		cleanup_player_alive = is_instance_valid(observed_player) and observed_player.is_inside_tree()
		return true

var session: HeldSession
var actor: Player
var item: CarriedItem
var snapshot: Dictionary
var initial_summary: Dictionary

func before_each() -> void:
	snapshot = GameState.instance.get_snapshot()
	session = HeldSession.new()
	session.scene_change_enabled = false
	add_child_autofree(session)
	session._current_map = load("res://items/maps/cratera.tres") as MapData
	session._ready_peers = [1]
	session._pending_summary = {"day":7,"map_id":"cratera","entries":[{"name":"Existing find","value":42}],"money_start":100}
	initial_summary = session._pending_summary.duplicate(true)
	GameState.instance.completed_quests = ["vega_foguete"]
	actor = load("res://gameplay/player/player.tscn").instantiate() as Player
	actor.name = "1"
	add_child_autofree(actor)
	actor.set_physics_process(false)
	actor.set_process(false)
	# Settings schedules new text scaling; keep its targets alive through delivery.
	await get_tree().process_frame
	await get_tree().process_frame
	actor.set_physics_process(true)
	actor.set_process(true)
	actor.set_process_input(true)
	actor.set_process_unhandled_input(true)
	session.observed_player = actor
	item = CarriedItem.new()
	item.tool_id = "lanterna_magnesio"
	item.charges = 2
	item.wear = 37
	actor.inventory.slots[1] = item
	actor.inventory.selected_slot = 1
	actor.health = 63.0
	actor.hunger = 41.0
	actor.session_money = 123
	actor.session_items_count = 4

func after_each() -> void:
	GameState.instance.apply_snapshot(snapshot)
	await get_tree().process_frame
	await get_tree().process_frame

func _contract() -> bool:
	var required: Array[StringName] = [&"get_rocket_transition",&"cancel_rocket_transition",&"_rpc_prepare_rocket",&"_accept_rocket_prepare_ack",&"_rpc_commit_rocket"]
	for method: StringName in required:
		if not session.has_method(method):
			assert_true(false,"Real SessionManager missing two-phase API: "+String(method))
			return false
	return true

func _state() -> Dictionary:
	return session.call("get_rocket_transition") as Dictionary

func _start() -> int:
	assert_true(session.request_rocket_travel())
	var state: Dictionary = _state()
	assert_eq(str(state.get("phase","")),"PREPARING")
	assert_eq(state.get("roster",[]),[1],"Offline roster is actual local host, not injected fake peers")
	return int(state.get("token",0))

func _prepare(token: int) -> void:
	session.call("_rpc_prepare_rocket",token,[1])

func _ack(token: int, sender: int = 1) -> bool:
	# UNIT validation helper only; this is explicitly NOT proof of RPC sender identity.
	return bool(session.call("_accept_rocket_prepare_ack",sender,token))

func _assert_item() -> void:
	assert_same(actor.inventory.slots[1],item)
	assert_eq(item.charges,2)
	assert_eq(item.wear,37)
	assert_eq(actor.inventory.selected_slot,1)

func test_request_starts_prepare_without_scene_change_or_cleanup() -> void:
	# This behavioral RED runs even before the proposed inspection APIs exist.
	assert_true(session.request_rocket_travel())
	assert_eq(session.sent.size(),1)
	assert_eq(session.sent[0]["method"],&"_rpc_prepare_rocket","Legacy one-shot travel RPC is not PREPARE")
	assert_eq(session.get_current_map().id,"cratera")
	assert_eq(session.cleanup_calls,0)
	assert_true(actor.is_inside_tree())
	assert_true(session._rocket_payload.is_empty(),"Transport held: owner has not received PREPARE")

func test_owner_captures_once_and_suspends_before_ack_without_disabling_subtree() -> void:
	if not _contract(): return
	var token: int = _start()
	_prepare(token)
	assert_eq(session.captures,1)
	assert_same((session._rocket_payload["slots"] as Array)[1],item)
	assert_false(actor.is_physics_processing())
	assert_false(actor.is_processing_input())
	assert_false(actor.is_processing_unhandled_input())
	assert_true(actor.is_processing(),"Do not blanket-disable unrelated Player process")
	assert_ne(actor.process_mode,Node.PROCESS_MODE_DISABLED)
	assert_false(actor.net_sync.get_visibility_for(1),"Owner NetSync publication gate closed before ACK")
	assert_true(actor.net_sync.is_inside_tree(),"Keep synchronizer registered; do not destroy subtree")
	assert_eq(session.sent.back()["method"],&"ACK")
	_prepare(token)
	assert_eq(session.captures,1,"Duplicate PREPARE cannot replace owner-local references")
	assert_eq(session.cleanup_calls,0,"No host cleanup until valid ACK")
	_assert_item()

func test_token_monotonic_and_reentry_does_not_replace_transaction() -> void:
	if not _contract(): return
	var first: int = _start()
	assert_gt(first,0)
	assert_false(session.request_rocket_travel())
	assert_eq(int(_state()["token"]),first)
	assert_true(bool(session.call("cancel_rocket_transition",first)))
	var second: int = _start()
	assert_gt(second,first)
	assert_false(bool(session.call("cancel_rocket_transition",first)),"Stale cancel cannot cancel a newer prepare")
	assert_eq(str(_state()["phase"]),"PREPARING")

func test_ack_requires_prepared_owner_roster_current_token_and_is_once_only() -> void:
	if not _contract(): return
	var token: int = _start()
	assert_false(_ack(token),"No ACK accepted before actual owner capture")
	_prepare(token)
	assert_false(_ack(token,0),"No remote sender identity")
	assert_false(_ack(token,321),"Sender outside actual roster")
	assert_false(_ack(token-1))
	assert_false(_ack(token+1))
	assert_eq(session.cleanup_calls,0)
	assert_true(_ack(token))
	assert_eq(session.cleanup_calls,1)
	assert_false(_ack(token),"Duplicate ACK cannot repeat cleanup/commit")
	assert_eq(session.cleanup_calls,1)

func test_cleanup_follows_capture_and_precedes_commit_without_day_or_summary_end() -> void:
	if not _contract(): return
	var day: int = GameState.instance.current_day
	var money: int = GameState.instance.team_money
	watch_signals(session)
	var token: int = _start()
	_prepare(token)
	assert_true(_ack(token))
	assert_true(session.cleanup_had_payload)
	assert_true(session.cleanup_player_alive)
	var commit: Dictionary = session.sent.back()
	assert_eq(commit["method"],&"_rpc_commit_rocket")
	assert_eq(int(commit["cleanup_calls"]),1,"Host cleanup returns before commit is enqueued")
	assert_eq(session.captures,1)
	assert_eq(GameState.instance.current_day,day)
	assert_eq(GameState.instance.team_money,money)
	assert_eq(session._pending_summary,initial_summary)
	for signal_name: String in ["expedition_ending","expedition_ended","expedition_started"]:
		assert_signal_not_emitted(session,signal_name)

func test_cancel_restores_exact_prior_flags_and_keeps_inventory() -> void:
	if not _contract(): return
	actor.set_physics_process(false)
	actor.set_process_input(false)
	actor.net_sync.public_visibility = false
	var token: int = _start()
	_prepare(token)
	assert_true(bool(session.call("cancel_rocket_transition",token)))
	assert_false(actor.is_physics_processing(),"Restore original false, not unconditional true")
	assert_false(actor.is_processing_input())
	assert_true(actor.is_processing_unhandled_input())
	assert_true(actor.is_processing())
	assert_false(actor.net_sync.public_visibility)
	assert_true(session._rocket_payload.is_empty(),"Release capture without clearing actual inventory")
	assert_eq(session.cleanup_calls,0)
	assert_eq(session.get_current_map().id,"cratera")
	_assert_item()

func test_cancel_restores_active_flags_and_visibility() -> void:
	if not _contract(): return
	var token: int = _start()
	_prepare(token)
	assert_true(bool(session.call("cancel_rocket_transition",token)))
	assert_true(actor.is_physics_processing())
	assert_true(actor.is_processing_input())
	assert_true(actor.is_processing_unhandled_input())
	assert_true(actor.net_sync.public_visibility)
	_assert_item()

func test_commit_uses_capture_even_after_old_player_removed_and_restore_consumes_once() -> void:
	if not _contract(): return
	var token: int = _start()
	_prepare(token)
	assert_true(_ack(token))
	# Existing actor's deferred settings callbacks must finish before detaching it.
	await get_tree().process_frame
	await get_tree().process_frame
	remove_child(actor)
	session.call("_rpc_commit_rocket",token)
	assert_eq(session.captures,1,"Commit never recaptures an absent Player")
	assert_eq(session.get_current_map().id,"lua")
	var replacement: Player = load("res://gameplay/player/player.tscn").instantiate() as Player
	replacement.name = "1"
	add_child_autofree(replacement)
	replacement.set_physics_process(false)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(session.restore_rocket_payload(replacement))
	assert_same(replacement.inventory.slots[1],item)
	assert_eq(replacement.health,63.0)
	assert_eq(replacement.hunger,41.0)
	assert_eq(replacement.session_money,123)
	assert_eq(replacement.session_items_count,4)
	assert_false(session.restore_rocket_payload(replacement))
	# Return detached fixture actor to GUT ownership without running ready again.
	add_child(actor)

func test_uncaptured_or_stale_commit_cannot_change_map() -> void:
	if not _contract(): return
	var token: int = _start()
	session.call("_rpc_commit_rocket",token)
	assert_eq(session.get_current_map().id,"cratera")
	_prepare(token)
	session.call("_rpc_commit_rocket",token+1)
	assert_eq(session.get_current_map().id,"cratera")
	assert_eq(session.cleanup_calls,0)
	_assert_item()

func test_missing_capture_at_commit_never_replaces_it_with_live_inventory() -> void:
	if not _contract(): return
	var token: int = _start()
	_prepare(token)
	assert_true(_ack(token))
	session._rocket_payload.clear() # Deliberately invalidate the local prerequisite.
	session.call("_rpc_commit_rocket",token)
	assert_eq(session.captures,1,"Empty cache is never permission to recapture live inventory")
	assert_eq(session.get_current_map().id,"cratera")
	_assert_item()

func test_title_clears_transaction_and_cache_without_erasing_carried_item() -> void:
	if not _contract(): return
	var token: int = _start()
	_prepare(token)
	session.return_to_title()
	assert_eq(str(_state()["phase"]),"IDLE")
	assert_true(session._rocket_payload.is_empty())
	assert_false(_ack(token))
	_assert_item()

func test_disconnect_clears_transaction_and_owner_cache() -> void:
	if not _contract(): return
	var token: int = _start()
	_prepare(token)
	session._on_server_disconnected()
	assert_eq(str(_state()["phase"]),"IDLE")
	assert_true(session._rocket_payload.is_empty())
	assert_false(_ack(token))
	_assert_item()
