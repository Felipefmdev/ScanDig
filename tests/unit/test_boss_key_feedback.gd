extends GutTest

var _snapshot: Dictionary = {}

func before_each() -> void:
	_snapshot = GameState.instance.get_snapshot().duplicate(true)
	GameState.instance.reset_state()

func after_each() -> void:
	GameState.instance.load_snapshot(_snapshot)

func _has_signal() -> bool:
	var present: bool = GameState.instance.has_signal("boss_key_available")
	assert_true(present, "live key feedback contract exists")
	return present

func test_authentic_primary_defeats_emit_the_matching_key_once_without_opening_or_save_claim() -> void:
	if not _has_signal(): return
	watch_signals(GameState.instance)
	for route_id: String in GameState.MAP_UNLOCK_BOSSES:
		var boss: String = str(GameState.MAP_UNLOCK_BOSSES[route_id]["boss_id"])
		GameState.instance.request_report_boss_defeated(boss)
		GameState.instance.request_report_boss_defeated(boss)
		assert_signal_emitted_with_parameters(GameState.instance, "boss_key_available", [route_id])
		assert_false(GameState.instance.unlocked_maps.has(route_id), "key availability never opens route")
	assert_signal_emit_count(GameState.instance, "boss_key_available", 4)

func test_loading_existing_boss_history_does_not_replay_key_feedback() -> void:
	if not _has_signal(): return
	watch_signals(GameState.instance)
	GameState.instance.load_snapshot({"defeated_bosses":["king_crab","giant_mole"],"unlocked_maps":[]})
	assert_signal_not_emitted(GameState.instance, "boss_key_available")

func test_secondary_boss_and_invalid_id_do_not_grant_route_feedback() -> void:
	if not _has_signal(): return
	watch_signals(GameState.instance)
	GameState.instance.request_report_boss_defeated("octopus")
	GameState.instance.request_report_boss_defeated("not_a_boss")
	assert_signal_not_emitted(GameState.instance, "boss_key_available")
