extends GutTest

## 3 slots de save (#100): migração do save antigo para o slot 1, salvar/carregar por slot,
## isolamento, apagar, último usado e trava fora de host/offline ou em expedição.
## Tudo em user://test_saves/devb_slots (set_save_path vira a pasta base dos slots).

const DIR: String = "user://test_saves/devb_slots"
const BASE: String = DIR + "/scandig_save.json"

var _orig_path: String = ""


func before_all() -> void:
	_orig_path = SaveManager.instance.save_path


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for file_name: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute("%s/%s" % [DIR, file_name])
	SaveManager.instance.set_save_path(BASE)
	GameState.instance.reset_state()


func after_all() -> void:
	SaveManager.instance.set_save_path(_orig_path)
	GameState.instance.reset_state()


func _write(path: String, data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func _full_save(money: int, saved_at: int) -> Dictionary:
	return {
		"version": SaveManager.SAVE_VERSION, "saved_at": saved_at, "team_money": money, "current_day": 7,
		"equipped_detector_level": 2,
		"discovered_items": ["alianca_ouro", "moeda_antiga"], "upgrade_levels": {"detector": 1},
		"unlocked_maps": ["campo"], "defeated_bosses": ["king_crab"], "completed_quests": ["ze_anzol"],
		"found_secrets": [GameState.SECRETS[0]], "seen_creatures": ["crab", "bat"], "intact_items": ["alianca_ouro"],
		"game_completed": false,
	}


func test_slot_paths_follow_base_dir() -> void:
	var save: SaveManager = SaveManager.instance
	assert_eq(save.current_slot(), 0, "set_save_path: sem slot (como antes)")
	assert_eq(save.save_path, BASE)
	for n: int in range(1, SaveManager.SLOT_COUNT + 1):
		assert_eq(save.slot_path(n), "%s/scandig_save_%d.json" % [DIR, n])
	assert_false(SaveManager.is_valid_slot(0))
	assert_false(SaveManager.is_valid_slot(SaveManager.SLOT_COUNT + 1))
	assert_true(SaveManager._running_tests(), "GUT nunca migra nem troca o save do jogador")


func test_migration_copies_legacy_to_slot_one_without_loss() -> void:
	var save: SaveManager = SaveManager.instance
	var data: Dictionary = _full_save(4321, 1760000000)
	_write(BASE, data)
	_write(DIR + "/scandig_save.backup.json", _full_save(111, 1750000000))
	var original: String = FileAccess.get_file_as_string(BASE)

	assert_true(save.migrate_legacy_save(), "migrou")
	assert_true(FileAccess.file_exists(save.slot_path(1)))
	assert_eq(FileAccess.get_file_as_string(save.slot_path(1)), original, "slot 1 = save antigo, byte a byte")
	assert_true(FileAccess.file_exists(DIR + "/scandig_save_1.backup.json"), "backup copiado junto")
	assert_false(FileAccess.file_exists(BASE), "o antigo saiu do lugar")
	assert_eq(FileAccess.get_file_as_string(DIR + "/" + SaveManager.LEGACY_FILE_NAME), original, "e ficou como legacy (não apagado)")
	assert_false(save.migrate_legacy_save(), "só uma vez")

	assert_eq(save.select_slot(1), OK)
	assert_eq(save.continue_game(), OK)
	var gs: GameState = GameState.instance
	assert_eq(gs.team_money, 4321)
	assert_eq(gs.current_day, 7)
	for key: String in SaveManager.LIST_FIELDS:
		assert_eq(Array(gs.get(key)), Array(data[key]), "campo %s preservado" % key)
	assert_eq(int(gs.upgrade_levels.get("detector", 0)), 1)
	var summary: Dictionary = save.get_slot_summary(1)
	assert_eq(int(summary["saved_at"]), 1760000000, "saved_at preservado")
	assert_eq(int(summary["slot"]), 1)


func test_migration_never_overwrites_existing_slot_one() -> void:
	var save: SaveManager = SaveManager.instance
	_write(BASE, _full_save(1, 1))
	_write(save.slot_path(1), _full_save(999, 2))
	assert_false(save.migrate_legacy_save())
	assert_eq(int(save.get_slot_summary(1)["money"]), 999)
	assert_true(FileAccess.file_exists(BASE), "o antigo fica onde estava")


func test_save_and_load_per_slot_are_isolated() -> void:
	var save: SaveManager = SaveManager.instance
	var gs: GameState = GameState.instance
	assert_eq(save.select_slot(1), OK)
	assert_eq(save.start_new_game(), OK)
	gs.team_money = 500
	assert_eq(save.save_game(), OK)
	assert_eq(save.select_slot(2), OK)
	assert_eq(gs.team_money, 100, "slot vazio começa do zero")
	assert_eq(save.start_new_game(), OK)
	gs.team_money = 900
	assert_eq(save.save_game(), OK)
	assert_eq(save.current_slot(), 2)
	assert_eq(int(save.get_slot_summary(1)["money"]), 500)
	assert_eq(int(save.get_slot_summary(2)["money"]), 900)
	assert_false(bool(save.get_slot_summary(3)["exists"]), "slot 3 vazio")
	assert_eq(save.select_slot(1), OK)
	assert_eq(save.continue_game(), OK)
	assert_eq(gs.team_money, 500, "voltar ao slot 1 carrega o dele")
	assert_true(FileAccess.file_exists(save.slot_path(1)))
	assert_false(FileAccess.file_exists(save.slot_path(1) + ".tmp"), "gravação atômica por slot")
	gs.team_money = 650
	assert_eq(save.start_new_game(), OK)
	assert_true(FileAccess.file_exists(DIR + "/scandig_save_1.backup.json"), "novo jogo guarda o backup do próprio slot")
	assert_false(FileAccess.file_exists(DIR + "/scandig_save_2.backup.json"), "e não mexe no do slot 2")


func test_delete_slot() -> void:
	var save: SaveManager = SaveManager.instance
	_write(save.slot_path(2), _full_save(300, 10))
	_write(DIR + "/scandig_save_2.backup.json", _full_save(200, 5))
	assert_eq(save.delete_slot(2), OK)
	assert_false(bool(save.get_slot_summary(2)["exists"]))
	assert_false(FileAccess.file_exists(DIR + "/scandig_save_2.backup.json"), "backup do slot também")
	assert_eq(save.delete_slot(2), OK, "apagar vazio não dá erro")
	assert_eq(save.delete_slot(4), ERR_INVALID_PARAMETER)


func test_last_used_slot_by_saved_at() -> void:
	var save: SaveManager = SaveManager.instance
	assert_eq(save.last_used_slot(), -1, "sem saves")
	_write(save.slot_path(1), _full_save(1, 100))
	_write(save.slot_path(3), _full_save(3, 300))
	_write(save.slot_path(2), _full_save(2, 200))
	assert_eq(save.last_used_slot(), 3)
	var corrupt: FileAccess = FileAccess.open(save.slot_path(1), FileAccess.WRITE)
	corrupt.store_string("{nao e json")
	corrupt.close()
	_write(save.slot_path(3), {"version": 99, "team_money": 1, "saved_at": 999})
	assert_eq(save.last_used_slot(), 2, "ignora corrompido e versão nova")


func test_select_slot_blocked_in_expedition() -> void:
	var save: SaveManager = SaveManager.instance
	var session: SessionManager = SessionManager.instance
	session.set("_current_map", load("res://items/maps/praia.tres"))
	assert_eq(save.select_slot(2), ERR_BUSY, "em expedição não troca")
	assert_eq(save.delete_slot(2), ERR_BUSY)
	session.set("_current_map", null)
	assert_eq(save.current_slot(), 0, "nada mudou")


func test_select_slot_blocked_as_client() -> void:
	var save: SaveManager = SaveManager.instance
	var mp: MultiplayerAPI = get_tree().root.multiplayer
	var original: MultiplayerPeer = mp.multiplayer_peer
	var client: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	assert_eq(client.create_client("127.0.0.1", 7899), OK)
	mp.multiplayer_peer = client
	var result: Error = save.select_slot(2)
	mp.multiplayer_peer = original
	client.close()
	assert_eq(result, ERR_UNAUTHORIZED, "cliente não troca de slot")
	assert_eq(save.current_slot(), 0)
