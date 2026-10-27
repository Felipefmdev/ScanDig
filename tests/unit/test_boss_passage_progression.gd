extends GutTest

## #186: existing APIs only; Codex runs RED before changing production.
## E1 neither receipt nor boss; E2 receipt only; E3 boss only; E4 both.
## These labels describe the migration matrix, not new production API names.
const ROUTES: Dictionary = {
	"campo": "king_crab",
	"ruinas": "giant_mole",
	"geleira": "ancient_guardian",
	"cratera": "frozen_mammoth",
}
const LEGACY_VERSION: int = 5
const MONEY: int = 1000000

var _snapshot: Dictionary = {}
var _save: SaveManager = null
var _dir: String = ""


func before_each() -> void:
	_snapshot = GameState.instance.get_snapshot().duplicate(true)
	GameState.instance.reset_state()
	# A separate manager never enters the tree or replaces SaveManager.instance.
	_save = SaveManager.new()
	_dir = "user://test_saves/boss_passage_186_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	assert_eq(DirAccess.make_dir_recursive_absolute(_dir), OK)
	_save.set_save_path(_dir + "/scandig_save.json")


func after_each() -> void:
	GameState.instance.load_snapshot(_snapshot)
	_save.free()
	# Delete only this test's uniquely named fixture directory, never player saves.
	for file_name: String in DirAccess.get_files_at(_dir):
		DirAccess.remove_absolute(_dir.path_join(file_name))
	DirAccess.remove_absolute(_dir)


func _legacy(receipts: Array, bosses: Array) -> Dictionary:
	return {
		"version": LEGACY_VERSION,
		"saved_at": 1760000000,
		"team_money": MONEY,
		"current_day": 9,
		"unlocked_maps": receipts,
		"defeated_bosses": bosses,
		"upgrade_levels": {"detector": 0},
		"discovered_items": [],
		"completed_quests": [],
	}


func _load_legacy(data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(_save.save_path, FileAccess.WRITE)
	assert_not_null(file, "isolated migration fixture must be writable")
	if file == null:
		return
	file.store_string(JSON.stringify(data))
	file.close()
	assert_eq(_save.load_game(GameState.instance), OK, "real SaveManager migration/load")
	assert_eq(GameState.instance.team_money, MONEY, "load neither charges nor refunds historic purchases")
	assert_eq(GameState.instance.current_day, 9, "load must not start a trip/day")
	assert_eq(GameState.instance.discovered_items.size(), 0, "load must not award commercial loot")


func test_e1_no_receipt_no_boss_keeps_all_four_routes_closed() -> void:
	_load_legacy(_legacy([], []))
	for map_id: String in ROUTES:
		assert_false(GameState.instance.is_map_unlocked(map_id), map_id)
		assert_false(GameState.instance.is_boss_defeated(str(ROUTES[map_id])), map_id)
	assert_true(GameState.instance.is_map_unlocked("praia"))


func test_e2_legacy_receipts_survive_without_boss_and_without_refund() -> void:
	_load_legacy(_legacy(ROUTES.keys(), []))
	for map_id: String in ROUTES:
		assert_true(GameState.instance.unlocked_maps.has(map_id), "receipt preserved: " + map_id)
		assert_true(GameState.instance.is_map_unlocked(map_id), map_id)
		assert_false(GameState.instance.is_boss_defeated(str(ROUTES[map_id])), "no fabricated defeat: " + map_id)


func test_e3_defeated_bosses_survive_but_do_not_open_routes_on_load() -> void:
	watch_signals(GameState.instance)
	_load_legacy(_legacy([], ROUTES.values()))
	for map_id: String in ROUTES:
		assert_true(GameState.instance.is_boss_defeated(str(ROUTES[map_id])), "credential source preserved: " + map_id)
		assert_false(GameState.instance.is_map_unlocked(map_id), "requires passage interaction: " + map_id)
		assert_false(GameState.instance.unlocked_maps.has(map_id), map_id)
	assert_signal_not_emitted(GameState.instance, "game_victory")
	assert_signal_not_emitted(GameState.instance, "quest_completed")


func test_e4_receipts_and_defeats_survive_repeated_load_without_rewards() -> void:
	watch_signals(GameState.instance)
	var data: Dictionary = _legacy(ROUTES.keys(), ROUTES.values())
	_load_legacy(data)
	var first: Dictionary = GameState.instance.get_snapshot().duplicate(true)
	_load_legacy(data)
	assert_eq(GameState.instance.get_snapshot(), first, "loading twice is idempotent")
	for map_id: String in ROUTES:
		assert_true(GameState.instance.is_map_unlocked(map_id), map_id)
		assert_true(GameState.instance.is_boss_defeated(str(ROUTES[map_id])), map_id)
	assert_signal_not_emitted(GameState.instance, "game_victory")
	assert_signal_not_emitted(GameState.instance, "quest_completed")


func test_praia_is_initial_by_explicit_rule_even_with_positive_price() -> void:
	var map_data: MapData = load("res://items/maps/praia.tres") as MapData
	assert_not_null(map_data)
	if map_data == null:
		return
	var old_cost: int = map_data.unlock_cost
	map_data.unlock_cost = 12345
	var open: bool = GameState.instance.is_map_unlocked("praia")
	map_data.unlock_cost = old_cost
	assert_true(open, "Praia initial access must not depend on its economic price")


func test_zero_price_is_not_a_receipt_for_other_terrestrial_maps() -> void:
	for map_id: String in ROUTES:
		var map_data: MapData = load("res://items/maps/%s.tres" % map_id) as MapData
		assert_not_null(map_data, map_id)
		if map_data == null:
			continue
		var old_cost: int = map_data.unlock_cost
		map_data.unlock_cost = 0
		var open: bool = GameState.instance.is_map_unlocked(map_id)
		map_data.unlock_cost = old_cost
		assert_false(open, "zero price cannot bypass passage: " + map_id)


func test_lua_receipt_alone_does_not_replace_rocket_quest() -> void:
	GameState.instance.unlocked_maps = ["lua"]
	assert_false(GameState.instance.is_map_unlocked("lua"))
	GameState.instance.completed_quests = ["vega_foguete"]
	assert_true(GameState.instance.is_map_unlocked("lua"))
	var session: SessionManager = SessionManager.new()
	assert_false(session.can_start_map("lua"), "Base cannot launch Lua even after rocket repair")
	session.free()


func test_legacy_unlock_request_cannot_buy_routes_even_with_boss_and_money() -> void:
	GameState.instance.team_money = MONEY
	for map_id: String in ROUTES:
		GameState.instance.defeated_bosses.append(str(ROUTES[map_id]))
	for map_id: String in ROUTES:
		GameState.instance.request_unlock_map(map_id)
		assert_false(GameState.instance.unlocked_maps.has(map_id), "legacy endpoint cannot issue receipt: " + map_id)
		assert_false(GameState.instance.is_map_unlocked(map_id), map_id)
		assert_eq(GameState.instance.team_money, MONEY, "denied request cannot charge: " + map_id)


func test_open_terrestrial_routes_can_start_with_baseline_detector() -> void:
	for map_id: String in ROUTES:
		GameState.instance.unlocked_maps.append(map_id)
	assert_eq(GameState.instance.equipped_detector_level, 1, "baseline detector control")
	var session: SessionManager = SessionManager.new()
	for map_id: String in ROUTES:
		assert_true(session.can_start_map(map_id), "detector efficiency cannot gate permanent route: " + map_id)
	session.free()
