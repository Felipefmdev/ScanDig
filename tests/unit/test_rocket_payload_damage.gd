extends GutTest

## Regression: real owner damage during rocket transition. Real Session/Player/damage; only transport and cleanup held.
## Same seams as tests/unit/test_rocket_transition.gd, not a replacement machine.
class HeldSession extends SessionManager:
	var sent: Array[Dictionary] = []
	var captures: int = 0
	var cleanup_calls: int = 0

	func _call_all(method: StringName, args: Array) -> void:
		sent.append({"method":method,"args":args.duplicate(true)})

	func _send_rocket_prepare_ack(token: int) -> void:
		sent.append({"method":&"ACK","args":[token]})

	func capture_rocket_payload(player: Player) -> bool:
		captures += 1
		return super.capture_rocket_payload(player)

	func _cleanup_rocket_generation() -> bool:
		cleanup_calls += 1
		return true # No despawn/network claim; retain real actor/drop for inspection.

var session: HeldSession
var actor: Player
var replacement: Player
var branch: Node3D
var carried: CarriedItem
var saved_state: Dictionary
var initial_health: float
var actor_id: int

func before_each() -> void:
	saved_state = GameState.instance.get_snapshot()
	GameState.instance.completed_quests = ["vega_foguete"]
	session = HeldSession.new()
	session.scene_change_enabled = false
	add_child_autofree(session)
	session._current_map = load("res://items/maps/cratera.tres") as MapData
	session._ready_peers = [1]
	branch = Node3D.new()
	add_child_autofree(branch)
	actor = load("res://gameplay/player/player.tscn").instantiate() as Player
	actor.name = "1"
	# Real exported mode: lethal damage enters downed instead of solo auto-respawn.
	# This does not fake an online peer or overwrite health/is_downed.
	actor.allow_downed = true
	branch.add_child(actor)
	actor.set_physics_process(false)
	actor.set_process(false)
	await get_tree().process_frame
	await get_tree().process_frame
	actor.set_process_input(true)
	actor.set_process_unhandled_input(true)
	initial_health = actor.health
	actor_id = actor.get_instance_id()
	assert_gt(initial_health,0.0,"Production Player ready supplies initial health")
	assert_true(actor.is_alive())
	carried = CarriedItem.new()
	carried.tool_id = "lanterna_magnesio"
	carried.charges = 2
	carried.wear = 37
	actor.inventory.slots[1] = carried
	actor.inventory.selected_slot = 1
	replacement = null
	watch_signals(actor)

func after_each() -> void:
	# Preserve all live targets while deferred settings/UI callbacks drain.
	# Restore flags/cache using the production reset, never health/items by assignment.
	session._abandon_rocket_transition()
	GameState.instance.apply_snapshot(saved_state)
	await get_tree().process_frame
	await get_tree().process_frame

func _phase() -> String:
	return str(session.get_rocket_transition()["phase"])

func _prepare() -> int:
	assert_true(session.request_rocket_travel())
	assert_eq(_phase(),"PREPARING")
	assert_eq(session.get_current_map().id,"cratera")
	var token: int = int(session.get_rocket_transition()["token"])
	session._rpc_prepare_rocket(token,[1])
	assert_eq(session.captures,1)
	assert_eq(session.cleanup_calls,0)
	assert_eq(session.sent.back()["method"],&"ACK","Capture and quiescence happened before held ACK")
	assert_eq(session.get_rocket_transition()["acked"],[])
	assert_false(actor.is_physics_processing())
	assert_false(actor.is_processing_input())
	assert_false(actor.is_processing_unhandled_input())
	assert_same((session._rocket_payload["slots"] as Array)[1],carried)
	assert_eq(float(session._rocket_payload["health"]),initial_health)
	return token

func _damage(lethal: bool) -> float:
	var amount: float = initial_health * (2.0 if lethal else 0.25)
	# Production damage entry. No take_damage override, direct health assignment,
	# invulnerability override, artificial signal or state setter in this fixture.
	actor.apply_damage(amount)
	var expected: float = 0.0 if lethal else initial_health-amount
	assert_almost_eq(actor.health,expected,0.001,"Real post-PREPARE damage must actually land; immunity is not the contract")
	assert_eq(actor.get_instance_id(),actor_id)
	if lethal:
		assert_signal_emit_count(actor,"died",1)
		assert_true(actor.is_downed,"Real lethal path, not a fake health=0 observation")
		assert_false(actor.is_alive())
		assert_false(actor.inventory.slots.has(carried),"Real death drops inventory")
		assert_eq(_drop_count(),1,"Death creates exactly one physical owner of the carried reference")
	else:
		assert_signal_not_emitted(actor,"died")
		assert_true(actor.is_alive())
		_assert_carried(actor)
	return expected

func _assert_carried(player: Player) -> void:
	assert_same(player.inventory.slots[1],carried)
	assert_eq(player.inventory.selected_slot,1)
	assert_eq(carried.charges,2)
	assert_eq(carried.wear,37)

func _drop_count() -> int:
	var count: int = 0
	for node: Node in branch.get_children():
		var pickup: ItemPickup = node as ItemPickup
		if pickup != null and pickup.carried == carried:
			count += 1
	return count

func _assert_original_post_damage(expected: float, lethal: bool) -> void:
	assert_eq(actor.get_instance_id(),actor_id,"Keep original actor alive as a test object")
	assert_almost_eq(actor.health,expected,0.001,"Cancel/abort must not erase landed damage")
	if lethal:
		assert_false(actor.is_alive(),"Cancellation cannot revive a downed owner")
		assert_true(actor.is_downed)
		assert_false(actor.inventory.slots.has(carried))
		assert_eq(_drop_count(),1)
	else:
		_assert_carried(actor)

func _cancel_after_damage(lethal: bool) -> void:
	var token: int = _prepare()
	var expected: float = _damage(lethal)
	# A production fix may already have cancelled in response to damage.
	if _phase() == "PREPARING":
		assert_true(session.cancel_rocket_transition(token))
	assert_eq(_phase(),"IDLE")
	assert_eq(session.get_current_map().id,"cratera")
	assert_true(session._rocket_payload.is_empty())
	assert_eq(session.cleanup_calls,0)
	_assert_original_post_damage(expected,lethal)
	assert_false(session._accept_rocket_prepare_ack(1,token),"Cancelled ACK cannot resurrect transaction")

func _commit_after_damage(lethal: bool) -> void:
	var token: int = _prepare()
	var expected: float = _damage(lethal)
	# Deliver only an ACK emitted by real prepare. Never force phase/cache/commit.
	var accepted: bool = session._accept_rocket_prepare_ack(1,token)
	if _phase() == "IDLE":
		# Handler's boolean is not the recovery contract; observe actual terminal state.
		assert_eq(session.get_current_map().id,"cratera")
		assert_true(session._rocket_payload.is_empty())
		_assert_original_post_damage(expected,lethal)
		return
	assert_eq(_phase(),"COMMITTING","Invalidated damage must not leave an owner indefinitely frozen in PREPARING")
	if _phase() != "COMMITTING": return
	assert_true(accepted)
	assert_eq(session.sent.back()["method"],&"_rpc_commit_rocket")
	assert_eq(int((session.sent.back()["args"] as Array)[0]),token)
	session._rpc_commit_rocket(token)
	assert_eq(session.get_current_map().id,"lua")
	# New actual production Player; original actor and real death drop stay inspectable.
	replacement = load("res://gameplay/player/player.tscn").instantiate() as Player
	replacement.name = "Replacement"
	branch.add_child(replacement)
	replacement.set_physics_process(false)
	replacement.set_process(false)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(session.restore_rocket_payload(replacement))
	assert_almost_eq(replacement.health,expected,0.001,"Commit restore must not roll back landed damage")
	assert_false(session.restore_rocket_payload(replacement),"Cache restores once")
	assert_eq(_phase(),"IDLE")
	_assert_original_post_damage(expected,lethal)
	if lethal:
		assert_false(replacement.is_alive(),"Commit cannot resurrect the owner after real lethal damage")
		assert_false(replacement.inventory.slots.has(carried),"Do not clone pre-death cache into the replacement while item remains dropped")
		assert_eq(_drop_count(),1)
	else:
		_assert_carried(replacement)

func test_nonlethal_damage_survives_cancel() -> void:
	_cancel_after_damage(false)

func test_lethal_damage_survives_cancel_without_revive_or_item_duplication() -> void:
	_cancel_after_damage(true)

func test_nonlethal_damage_survives_ack_commit_or_safe_abort() -> void:
	await _commit_after_damage(false)

func test_lethal_damage_cannot_be_undone_by_ack_commit_or_restore() -> void:
	await _commit_after_damage(true)


## Os casos adicionais de ciclo de vida usam o mesmo Player/HeldSession real acima.
## No production method replacement, damage setter or new state machine.

func _ack_and_hold_commit(token: int) -> void:
	assert_true(session._accept_rocket_prepare_ack(1,token))
	assert_eq(_phase(),"COMMITTING")
	assert_eq(session.sent.back()["method"],&"_rpc_commit_rocket")
	assert_eq(session.captures,1)
	assert_eq(session.get_current_map().id,"cratera","Commit queued, not yet delivered")

func _deliver_commit(token: int) -> void:
	assert_eq(session.sent.back()["method"],&"_rpc_commit_rocket")
	session._rpc_commit_rocket(token)
	assert_eq(session.get_current_map().id,"lua")
	assert_eq(_phase(),"COMMITTING")
	assert_true(actor.is_inside_tree(),"Scene change disabled: old actor remains for the late-hit window")
	assert_false(actor.is_physics_processing())
	assert_false(actor.is_processing_input())

func _replace_after_real_exit(heal_old_after_exit: bool = false) -> void:
	# Exit the actual old owner while keeping it alive for stale-listener inspection.
	# Reparent only after exit; do not request_ready or seed any Player result fields.
	branch.remove_child(actor)
	add_child_autofree(actor)
	if heal_old_after_exit:
		actor.heal(initial_health*0.05)
		assert_almost_eq(actor.health,initial_health*0.80,0.001,"Old actor really changed after its payload lifetime ended")
	replacement = load("res://gameplay/player/player.tscn").instantiate() as Player
	replacement.name = "ReplacementFollowup"
	watch_signals(replacement)
	branch.add_child(replacement)
	replacement.set_physics_process(false)
	replacement.set_process(false)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(session.restore_rocket_payload(replacement))
	assert_false(session.restore_rocket_payload(replacement))
	assert_eq(_phase(),"IDLE")
	assert_eq(session.captures,1,"Observers update state without a second capture")

func _late_hit(after_commit: bool, lethal: bool) -> void:
	var token: int = _prepare()
	_ack_and_hold_commit(token)
	if after_commit:
		_deliver_commit(token)
	var expected: float = _damage(lethal)
	if not after_commit:
		_deliver_commit(token)
	await _replace_after_real_exit()
	assert_almost_eq(replacement.health,expected,0.001,"Damage after ACK/commit must survive actual old-owner exit")
	assert_eq(replacement.is_downed,lethal)
	assert_eq(replacement.is_alive(),not lethal)
	if lethal:
		assert_false(replacement.inventory.slots.has(carried))
		assert_eq(_drop_count(),1)
		assert_signal_not_emitted(replacement,"died")
	else:
		_assert_carried(replacement)

func test_followup_nonlethal_after_ack_before_commit() -> void:
	await _late_hit(false,false)

func test_followup_lethal_after_ack_before_commit() -> void:
	await _late_hit(false,true)

func test_followup_nonlethal_after_commit_before_owner_exit() -> void:
	await _late_hit(true,false)

func test_followup_exited_old_owner_signal_cannot_contaminate_saved_payload() -> void:
	var token: int = _prepare()
	_ack_and_hold_commit(token)
	_damage(false)
	_deliver_commit(token)
	await _replace_after_real_exit(true)
	assert_almost_eq(replacement.health,initial_health*0.75,0.001,"Real heal on an exited old owner must not update the finalized payload")
	_assert_carried(replacement)

func test_followup_lethal_after_commit_before_owner_exit() -> void:
	await _late_hit(true,true)

func test_followup_real_heal_after_damage_preserves_increase() -> void:
	var token: int = _prepare()
	_ack_and_hold_commit(token)
	_damage(false)
	actor.heal(initial_health*0.10)
	var expected: float = initial_health*0.85
	assert_almost_eq(actor.health,expected,0.001,"Real healing is not clamped to previously observed damage")
	_deliver_commit(token)
	await _replace_after_real_exit()
	assert_almost_eq(replacement.health,expected,0.001)
	assert_false(replacement.is_downed)
	_assert_carried(replacement)

func test_followup_lethal_then_real_revive_keeps_empty_bag_and_current_health() -> void:
	var token: int = _prepare()
	_ack_and_hold_commit(token)
	_damage(true)
	# Real Player API, also used by the team-wipe path. No fake revived signal.
	actor.revive(0.4)
	var expected: float = maxf(actor.max_health*0.4,1.0)
	assert_almost_eq(actor.health,expected,0.001)
	assert_false(actor.is_downed)
	assert_true(actor.is_alive())
	assert_false(actor.inventory.slots.has(carried))
	assert_eq(_drop_count(),1)
	var expected_hunger: float = actor.hunger
	_deliver_commit(token)
	await _replace_after_real_exit()
	assert_almost_eq(replacement.health,expected,0.001)
	assert_almost_eq(replacement.hunger,expected_hunger,0.001)
	assert_false(replacement.is_downed,"A historical death must not latch downed forever")
	assert_true(replacement.is_alive())
	assert_false(replacement.inventory.slots.has(carried))
	assert_eq(_drop_count(),1)
	assert_signal_emit_count(actor,"died",1,"Restore cannot replay death")

func test_followup_solo_real_death_respawn_is_not_suppressed_or_item_reverted() -> void:
	actor.allow_downed = false
	var token: int = _prepare()
	_ack_and_hold_commit(token)
	actor.apply_damage(initial_health*2.0)
	assert_signal_emit_count(actor,"died",1)
	assert_false(actor.is_downed)
	assert_true(actor.is_alive(),"Production solo death legitimately respawns")
	assert_eq(actor.health,actor.max_health)
	assert_false(actor.inventory.slots.has(carried))
	assert_eq(_drop_count(),1)
	var expected_health: float = actor.health
	var expected_hunger: float = actor.hunger
	_deliver_commit(token)
	await _replace_after_real_exit()
	assert_almost_eq(replacement.health,expected_health,0.001)
	assert_almost_eq(replacement.hunger,expected_hunger,0.001)
	assert_true(replacement.is_alive())
	assert_false(replacement.is_downed)
	assert_false(replacement.inventory.slots.has(carried),"Solo respawn never refills the pre-death bag")
	assert_eq(_drop_count(),1)

func _listener_counts() -> Array[int]:
	# Public signal metadata, not private observer fields or source-text matching.
	var counts: Array[int] = []
	for signal_name: StringName in [&"health_changed",&"hunger_changed",&"player_downed",&"tree_exiting"]:
		counts.append(actor.get_signal_connection_list(signal_name).size())
	for signal_name: StringName in [&"inventory_changed",&"selected_slot_changed"]:
		counts.append(actor.inventory.get_signal_connection_list(signal_name).size())
	return counts

func test_followup_cancel_retry_disconnects_observers_and_stale_token_cannot_touch_new_payload() -> void:
	var baseline: Array[int] = _listener_counts()
	var first: int = _prepare()
	var observing: Array[int] = _listener_counts()
	assert_ne(observing,baseline,"Observer connections are exercised, not guessed from payload")
	_damage(false)
	assert_true(session.cancel_rocket_transition(first))
	assert_eq(_listener_counts(),baseline,"Cancel removes only the transaction listeners")
	assert_true(session._rocket_payload.is_empty())
	# Keep the real original actor; a late legitimate heal must not repopulate old cache.
	actor.heal(initial_health*0.05)
	assert_almost_eq(actor.health,initial_health*0.80,0.001)
	assert_true(session._rocket_payload.is_empty(),"Cancelled token has no live cache")
	assert_true(session.request_rocket_travel())
	var second: int = int(session.get_rocket_transition()["token"])
	assert_gt(second,first)
	session._rpc_prepare_rocket(second,[1])
	assert_eq(session.captures,2,"Exactly once per transaction, not once per signal")
	assert_eq(_listener_counts(),observing,"Retry does not accumulate listeners")
	assert_false(session.cancel_rocket_transition(first))
	assert_false(session._accept_rocket_prepare_ack(1,first))
	assert_eq(int(session.get_rocket_transition()["token"]),second)
	actor.heal(initial_health*0.05)
	assert_almost_eq(float(session._rocket_payload["health"]),initial_health*0.85,0.001,"Only the current owner state updates the new capture")
	assert_same((session._rocket_payload["slots"] as Array)[1],carried)
	assert_true(session.cancel_rocket_transition(second))
	assert_eq(_listener_counts(),baseline)
	session._abandon_rocket_transition()
	assert_true(session._rocket_payload.is_empty())
	assert_eq(_listener_counts(),baseline,"Repeated teardown is idempotent")
