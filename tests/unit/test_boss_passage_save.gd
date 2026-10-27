extends GutTest

## #186: host-local API contract, no RPC/ENet proof in this fixture.
## Missing API fails an assertion and returns before any dynamic invocation.
const ROUTES: Dictionary = {
	"campo": "king_crab",
	"ruinas": "giant_mole",
	"geleira": "ancient_guardian",
	"cratera": "frozen_mammoth",
}


class DiskAdapter extends SaveManager:
	var writes: int = 0
	var fail_write: bool = false
	var attempted: Dictionary = {}


	func save_to_file(data: Dictionary) -> Error:
		writes += 1
		attempted = data.duplicate(true)
		if fail_write:
			return ERR_FILE_CANT_WRITE
		return super.save_to_file(data)


var _original_save: SaveManager = null
var _snapshot: Dictionary = {}
var _save: DiskAdapter = null
var _dir: String = ""


func before_each() -> void:
	_original_save = SaveManager.instance
	_snapshot = GameState.instance.get_snapshot().duplicate(true)
	GameState.instance.reset_state()
	_save = DiskAdapter.new()
	_dir = "user://test_saves/boss_passage_save_186_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	assert_eq(DirAccess.make_dir_recursive_absolute(_dir), OK)
	_save.set_save_path(_dir.path_join("scandig_save.json"))
	SaveManager.instance = _save
	GameState.instance.team_money = 4321
	GameState.instance.current_day = 7


func after_each() -> void:
	# Restore static instance even when a test returns early for missing API.
	SaveManager.instance = _original_save
	GameState.instance.load_snapshot(_snapshot)
	_save.free()
	for file_name: String in DirAccess.get_files_at(_dir):
		DirAccess.remove_absolute(_dir.path_join(file_name))
	DirAccess.remove_absolute(_dir)


func _has_api() -> bool:
	var present: bool = GameState.instance.has_method("open_boss_passage")
	assert_true(present, "GameState.open_boss_passage(route_id) host-local API must exist")
	return present


func _open(route_id: String) -> int:
	var result: Variant = GameState.instance.call("open_boss_passage", route_id)
	assert_eq(typeof(result), TYPE_INT, "opening returns an Error, not a bool/null")
	return int(result) if result is int else FAILED


func _disk() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_save.save_path))
	assert_true(parsed is Dictionary, "saved JSON must be readable")
	return parsed as Dictionary if parsed is Dictionary else {}


func test_success_saves_each_canonical_receipt_and_reloads_using_v6_fields() -> void:
	if not _has_api():
		return
	assert_true(_save.is_progress_applied(), "new isolated save has applied empty progress")
	watch_signals(GameState.instance)
	for route_id: String in ROUTES:
		GameState.instance.defeated_bosses.append(str(ROUTES[route_id]))
		assert_eq(_open(route_id), OK, route_id)
		assert_true(GameState.instance.unlocked_maps.has(route_id), route_id)
		assert_true((_save.attempted.get("unlocked_maps", []) as Array).has(route_id), "tentative receipt reaches real save_game")
	assert_eq(_save.writes, 4)
	assert_eq(GameState.instance.team_money, 4321)
	assert_signal_emitted(GameState.instance, "progression_changed", "successful opening publishes before any reload")
	var disk: Dictionary = _disk()
	assert_eq(int(disk.get("version", -1)), 6, "no schema bump needed for existing receipt")
	assert_eq(int(disk.get("team_money", -1)), 4321)
	assert_eq((disk.get("unlocked_maps", []) as Array).size(), 4)
	assert_false(disk.has("boss_passages"), "no parallel passage progress field")
	assert_false(disk.has("boss_keys"), "credential is derived from defeated_bosses")
	GameState.instance.reset_state()
	assert_eq(_save.load_game(GameState.instance), OK)
	for route_id: String in ROUTES:
		assert_true(GameState.instance.is_map_unlocked(route_id), "durable receipt: " + route_id)
		assert_true(GameState.instance.is_boss_defeated(str(ROUTES[route_id])), route_id)
	assert_eq(GameState.instance.team_money, 4321)


func test_failed_write_rolls_back_only_new_receipt_and_retry_succeeds() -> void:
	if not _has_api():
		return
	GameState.instance.unlocked_maps = ["ruinas"]
	GameState.instance.defeated_bosses = ["king_crab"]
	GameState.instance.discovered_items = ["moeda_antiga"]
	var before: Dictionary = GameState.instance.get_snapshot().duplicate(true)
	_save.fail_write = true
	watch_signals(GameState.instance)
	watch_signals(_save)
	assert_eq(_open("campo"), ERR_FILE_CANT_WRITE)
	assert_eq(_save.writes, 1, "failure must reach disk adapter")
	assert_true((_save.attempted.get("unlocked_maps", []) as Array).has("campo"))
	assert_eq(GameState.instance.get_snapshot(), before, "existing progress survives rollback")
	assert_false(FileAccess.file_exists(_save.save_path))
	assert_signal_not_emitted(GameState.instance, "progression_changed", "failed tentative receipt is not published")
	assert_signal_not_emitted(_save, "game_saved")
	assert_signal_emitted(_save, "save_failed")
	_save.fail_write = false
	assert_eq(_open("campo"), OK, "retry keeps boss credential usable")
	assert_eq(_save.writes, 2)
	assert_true(GameState.instance.unlocked_maps.has("ruinas"))
	assert_true(GameState.instance.unlocked_maps.has("campo"))
	assert_eq(GameState.instance.team_money, 4321)
	assert_true((_disk().get("unlocked_maps", []) as Array).has("campo"))


func test_failed_extension_preserves_previous_disk_receipt_byte_for_byte() -> void:
	if not _has_api():
		return
	GameState.instance.defeated_bosses = ["king_crab", "giant_mole"]
	assert_eq(_open("campo"), OK)
	var original: String = FileAccess.get_file_as_string(_save.save_path)
	_save.fail_write = true
	assert_eq(_open("ruinas"), ERR_FILE_CANT_WRITE)
	assert_eq(FileAccess.get_file_as_string(_save.save_path), original)
	assert_true(GameState.instance.unlocked_maps.has("campo"))
	assert_false(GameState.instance.unlocked_maps.has("ruinas"))
	assert_eq(GameState.instance.team_money, 4321)


func test_already_open_receipt_is_ok_without_write_or_credential() -> void:
	if not _has_api():
		return
	GameState.instance.unlocked_maps = ["campo"]
	_save.fail_write = true
	watch_signals(GameState.instance)
	assert_eq(_open("campo"), OK, "legacy receipt needs no boss or fresh disk write")
	assert_eq(_save.writes, 0)
	assert_eq(GameState.instance.unlocked_maps.count("campo"), 1)
	assert_eq(GameState.instance.team_money, 4321)
	assert_signal_not_emitted(GameState.instance, "progression_changed")


func test_closed_routes_without_matching_boss_never_write_or_charge() -> void:
	if not _has_api():
		return
	# Wrong boss also must not authorize another canonical route.
	for route_id: String in ROUTES:
		GameState.instance.defeated_bosses = ["gold_colossus"]
		assert_ne(_open(route_id), OK, route_id)
		assert_false(GameState.instance.unlocked_maps.has(route_id))
	assert_eq(_save.writes, 0)
	assert_eq(GameState.instance.team_money, 4321)
	assert_false(FileAccess.file_exists(_save.save_path))


func test_invalid_routes_including_lua_never_write_even_with_all_bosses() -> void:
	if not _has_api():
		return
	for route_id: String in ROUTES:
		GameState.instance.defeated_bosses.append(str(ROUTES[route_id]))
	GameState.instance.completed_quests = ["vega_foguete"]
	var before: Dictionary = GameState.instance.get_snapshot().duplicate(true)
	for invalid: String in ["", "lua", "praia", "Campo", "../campo", "unknown"]:
		assert_ne(_open(invalid), OK, invalid)
	assert_eq(_save.writes, 0)
	assert_eq(GameState.instance.get_snapshot(), before)


func test_existing_unapplied_save_cannot_be_overwritten_by_opening() -> void:
	if not _has_api():
		return
	# Establish a real save, then reset only the manager's applied flag through
	# its public path API, as when an existing slot has not been loaded yet.
	assert_eq(_save.save_game(GameState.instance), OK)
	var original: String = FileAccess.get_file_as_string(_save.save_path)
	_save.set_save_path(_save.save_path)
	assert_false(_save.is_progress_applied())
	_save.writes = 0
	GameState.instance.defeated_bosses = ["king_crab"]
	watch_signals(GameState.instance)
	assert_ne(_open("campo"), OK, "must not silently apply another save or overwrite it")
	assert_eq(_save.writes, 0)
	assert_false(_save.is_progress_applied())
	assert_false(GameState.instance.unlocked_maps.has("campo"))
	assert_eq(GameState.instance.team_money, 4321)
	assert_eq(FileAccess.get_file_as_string(_save.save_path), original)
	assert_signal_not_emitted(GameState.instance, "progression_changed")
