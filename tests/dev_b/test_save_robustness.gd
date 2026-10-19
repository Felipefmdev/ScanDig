extends GutTest

## Robustez do save (#132): corrompido, truncado, vazio, versões antigas e campos faltando, slot
## vazio, versão mais nova e disco cheio / rename recusado (nunca estraga o save anterior).
## Tudo em user://test_saves/devb_save_robust.

const DIR: String = "user://test_saves/devb_save_robust"
const BASE: String = DIR + "/scandig_save.json"


## SaveManager com escrita/rename que falham sob comando (não entra na árvore).
class FaultySave extends SaveManager:
	## "" normal; "partial" grava metade e diz OK; "write" falha na escrita; "rename_tmp" recusa
	## renomear o .tmp; "rename_all" recusa todo rename; "no_overwrite" recusa renomear por cima.
	var fault: String = ""

	func _write_file(path: String, text: String) -> Error:
		match fault:
			"partial":
				return super(path, text.substr(0, text.length() / 2))
			"write":
				super(path, text.substr(0, 10))
				return ERR_FILE_CANT_WRITE
		return super(path, text)

	func _rename_file(from: String, to: String) -> Error:
		match fault:
			"rename_tmp":
				if from.ends_with(".tmp"):
					return ERR_FILE_CANT_WRITE
			"rename_all":
				return ERR_FILE_CANT_WRITE
			"no_overwrite":
				if FileAccess.file_exists(to):
					return ERR_ALREADY_EXISTS
		return super(from, to)


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


func _write_text(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	if path == BASE:
		# Como ao abrir o jogo: o save do disco ainda não foi aplicado.
		SaveManager.instance.set_save_path(BASE)


func _write(path: String, data: Dictionary) -> void:
	_write_text(path, JSON.stringify(data, "\t"))


func _full_save(money: int) -> Dictionary:
	return {
		"version": SaveManager.SAVE_VERSION, "saved_at": 1760000000, "team_money": money, "current_day": 6,
		"discovered_items": ["alianca_ouro", "moeda_antiga"], "upgrade_levels": {"detector": 1},
		"unlocked_maps": ["campo"], "defeated_bosses": ["king_crab"], "completed_quests": [],
		"found_secrets": [], "seen_creatures": ["crab"], "intact_items": ["alianca_ouro"],
		"rare_items": [], "map_fragments": [], "built_shortcuts": [], "game_completed": false,
	}


## Dinheiro de um jogo novo (GameState.reset_state).
func _fresh_money() -> int:
	var gs: GameState = GameState.instance
	var current: int = gs.team_money
	gs.reset_state()
	var fresh: int = gs.team_money
	gs.team_money = current
	return fresh


func _files_with_prefix(prefix: String) -> Array[String]:
	var found: Array[String] = []
	for file_name: String in DirAccess.get_files_at(DIR):
		if file_name.begins_with(prefix):
			found.append(file_name)
	return found


## Save ilegível: continue_game avisa, guarda o arquivo como corrupt-*, começa do zero e grava.
func _assert_quarantined(original: String, label: String) -> void:
	var save: SaveManager = SaveManager.instance
	var summary: Dictionary = save.get_save_summary()
	assert_true(summary["exists"] and not summary["valid"], "%s: resumo existe e é inválido" % label)
	GameState.instance.team_money = 777
	watch_signals(save)
	assert_eq(save.continue_game(), ERR_FILE_CORRUPT, "%s: continue_game devolve ERR_FILE_CORRUPT" % label)
	assert_signal_emitted_with_parameters(save, "save_load_failed", [SaveManager.MSG_CORRUPT])
	assert_eq(GameState.instance.team_money, _fresh_money(), "%s: jogo novo" % label)
	assert_false(save.has_save_file(), "%s: o corrompido saiu do lugar" % label)
	var quarantined: Array[String] = _files_with_prefix("scandig_save.corrupt-")
	assert_eq(quarantined.size(), 1, "%s: um arquivo de quarentena" % label)
	if quarantined.size() == 1:
		assert_eq(FileAccess.get_file_as_string("%s/%s" % [DIR, quarantined[0]]), original, "%s: guardado sem alteração" % label)
	assert_eq(save.save_game(), OK, "%s: depois grava normalmente" % label)
	assert_eq(save._read_save()["status"], SaveManager.ReadStatus.OK)


func test_invalid_json_goes_to_quarantine() -> void:
	var text: String = "{\"version\": 4, \"team_money\": 50, oops"
	_write_text(BASE, text)
	_assert_quarantined(text, "JSON inválido")


func test_truncated_save_goes_to_quarantine() -> void:
	var full: String = JSON.stringify(_full_save(4321), "\t")
	var half: String = full.substr(0, full.length() / 2)
	_write_text(BASE, half)
	_assert_quarantined(half, "truncado")


func test_empty_and_zeroed_files_go_to_quarantine() -> void:
	_write_text(BASE, "")
	_assert_quarantined("", "arquivo vazio")
	before_each()
	var zeros: FileAccess = FileAccess.open(BASE, FileAccess.WRITE)
	zeros.store_buffer(PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0]))
	zeros.close()
	SaveManager.instance.set_save_path(BASE)
	_assert_quarantined(FileAccess.get_file_as_string(BASE), "bytes zerados")


func test_wrong_types_go_to_quarantine() -> void:
	for data: Variant in [
		{"version": 4, "team_money": "muito"},
		{"version": 4, "team_money": 10, "rare_items": "rubi"},
		{"version": 4, "team_money": 10, "upgrade_levels": [1, 2]},
		{"version": "4", "team_money": 10},
		[1, 2, 3],
	]:
		before_each()
		var text: String = JSON.stringify(data, "\t")
		_write_text(BASE, text)
		_assert_quarantined(text, str(data))


func test_old_versions_load_with_defaults() -> void:
	var save: SaveManager = SaveManager.instance
	var cases: Array[Dictionary] = [
		{"team_money": 120, "current_day": 2, "discovered_items": ["moeda_antiga"], "equipped_detector_level": 3},
		{"version": 1, "team_money": 120, "current_day": 2, "discovered_items": ["moeda_antiga"], "equipped_detector_level": 3},
		{"version": 2, "team_money": 220, "current_day": 3, "discovered_items": [], "upgrade_levels": {"detector": 2, "pa_obsoleta": 9}},
		{"version": 3, "team_money": 320, "current_day": 4, "discovered_items": [], "upgrade_levels": {"detector": 2},
			"unlocked_maps": ["campo"], "defeated_bosses": ["king_crab"]},
	]
	for data: Dictionary in cases:
		before_each()
		_write(BASE, data)
		assert_eq(save.continue_game(), OK, "v%d carrega" % int(data.get("version", 1)))
		var gs: GameState = GameState.instance
		assert_eq(gs.team_money, int(data["team_money"]))
		assert_eq(gs.current_day, int(data["current_day"]))
		assert_eq(gs.get_upgrade_level("detector"), 2, "detector do v1 (nível 3 = upgrade 2) e dos v2/v3")
		assert_false(gs.upgrade_levels.has("pa_obsoleta"), "chave obsoleta descartada")
		for key: String in ["completed_quests", "found_secrets", "seen_creatures", "intact_items", "rare_items", "built_shortcuts"]:
			assert_eq((gs.get(key) as Array).size(), 0, "%s começa vazio" % key)
		assert_eq(gs.unlocked_maps.has("campo"), data.has("unlocked_maps"))
		assert_eq(save.save_game(), OK)
		var saved: Dictionary = save.load_from_file()
		assert_eq(int(saved["version"]), SaveManager.SAVE_VERSION, "regrava na versão atual")
		for key: String in SaveManager.LIST_FIELDS:
			assert_true(saved.get(key) is Array, "regravado com %s" % key)


func test_current_version_missing_new_fields() -> void:
	var save: SaveManager = SaveManager.instance
	var data: Dictionary = _full_save(900)
	for key: String in ["rare_items", "map_fragments", "intact_items", "seen_creatures", "built_shortcuts", "game_completed", "saved_at", "current_day", "upgrade_levels"]:
		data.erase(key)
	_write(BASE, data)
	assert_eq(save.continue_game(), OK)
	var gs: GameState = GameState.instance
	assert_eq(gs.team_money, 900)
	assert_eq(gs.discovered_items.size(), 2)
	assert_eq(gs.intact_items.size(), 0)
	assert_eq(gs.rare_items.size(), 0)
	assert_false(gs.game_completed)
	assert_eq(gs.get_upgrade_level("detector"), 0)


func test_upgrade_levels_with_bad_values_do_not_break_load() -> void:
	var save: SaveManager = SaveManager.instance
	var data: Dictionary = _full_save(500)
	data["upgrade_levels"] = {"detector": null, "shovel": "x", "battery": 99}
	data["discovered_items"] = ["moeda_antiga", null, 3, "moeda_antiga"]
	_write(BASE, data)
	assert_eq(save.continue_game(), OK)
	var gs: GameState = GameState.instance
	assert_eq(gs.team_money, 500)
	assert_eq(gs.get_upgrade_level("detector"), 0, "null vira 0")
	assert_true(gs.discovered_items.has("moeda_antiga"))
	assert_false(gs.discovered_items.has("<null>"), "null não vira item")
	for key: String in gs.upgrade_levels.keys():
		assert_between(gs.get_upgrade_level(key), 0, gs.get_upgrade_max_level(key), "%s dentro do limite" % key)


func test_empty_slot() -> void:
	var save: SaveManager = SaveManager.instance
	var summary: Dictionary = save.get_slot_summary(2)
	assert_false(summary["exists"])
	assert_false(summary["valid"])
	assert_eq(summary["error"], "")
	GameState.instance.team_money = 999
	assert_eq(save.select_slot(2), OK)
	assert_eq(GameState.instance.team_money, _fresh_money(), "slot vazio começa do zero")
	assert_true(save.is_progress_applied())
	assert_eq(save.continue_game(), OK, "continuar num slot vazio não falha")
	assert_eq(save.load_game(), ERR_FILE_NOT_FOUND)
	assert_eq(save.save_game(), OK)
	assert_true(FileAccess.file_exists(save.slot_path(2)))
	assert_false(FileAccess.file_exists(save.slot_path(1)), "não toca nos outros slots")
	assert_eq(save.delete_slot(2), OK)
	assert_false(save.get_slot_summary(2)["exists"])


func test_newer_version_is_kept_and_blocks_writes() -> void:
	var save: SaveManager = SaveManager.instance
	var data: Dictionary = _full_save(5000)
	data["version"] = SaveManager.SAVE_VERSION + 1
	data["campo_do_futuro"] = {"x": 1}
	_write(BASE, data)
	var original: String = FileAccess.get_file_as_string(BASE)
	watch_signals(save)
	assert_eq(save.continue_game(), ERR_FILE_UNRECOGNIZED)
	assert_signal_emitted_with_parameters(save, "save_load_failed", [SaveManager.MSG_NEWER])
	assert_eq(save.save_game(), ERR_UNAUTHORIZED, "não grava por cima")
	assert_signal_emitted(save, "save_failed")
	assert_eq(FileAccess.get_file_as_string(BASE), original, "o save novo fica intacto")
	assert_eq(_files_with_prefix("scandig_save.corrupt-").size(), 0, "não vai para a quarentena")
	assert_eq(save.start_new_game(), OK, "jogo novo é escolha explícita")
	assert_eq(FileAccess.get_file_as_string(save.get_backup_path()), original, "e guarda o mais novo no backup")


func _faulty(fault: String) -> FaultySave:
	var faulty: FaultySave = autofree(FaultySave.new())
	faulty.set_save_path(BASE)
	assert_eq(faulty.load_game(GameState.instance), OK, "save anterior carregado")
	faulty.fault = fault
	GameState.instance.team_money = 12345
	return faulty


func test_disk_full_or_rename_failure_keeps_previous_save() -> void:
	for fault: String in ["partial", "write", "rename_tmp", "rename_all"]:
		before_each()
		_write(BASE, _full_save(4321))
		var original: String = FileAccess.get_file_as_string(BASE)
		var faulty: FaultySave = _faulty(fault)
		watch_signals(faulty)
		assert_ne(faulty.save_game(GameState.instance), OK, "%s: save_game falha" % fault)
		assert_signal_emitted(faulty, "save_failed", fault)
		assert_eq(FileAccess.get_file_as_string(BASE), original, "%s: save anterior intacto" % fault)
		assert_eq(_files_with_prefix("scandig_save.json."), [] as Array[String], "%s: sem .tmp/.old sobrando" % fault)
		faulty.fault = ""
		assert_eq(faulty.save_game(GameState.instance), OK, "%s: com espaço de novo, grava" % fault)
		assert_eq(int(faulty.load_from_file()["team_money"]), 12345)


func test_rename_without_overwrite_still_saves() -> void:
	_write(BASE, _full_save(4321))
	var faulty: FaultySave = _faulty("no_overwrite")
	assert_eq(faulty.save_game(GameState.instance), OK)
	assert_eq(int(faulty.load_from_file()["team_money"]), 12345)
	assert_eq(_files_with_prefix("scandig_save.json."), [] as Array[String], "sem .tmp/.old sobrando")


func test_interrupted_replace_restores_old_save() -> void:
	# Fechou entre tirar o save do lugar e pôr o .tmp: só sobrou o .old.
	_write(BASE + ".old", _full_save(4321))
	_write_text(BASE + ".tmp", "{\"version\": 4, \"team")
	var save: SaveManager = SaveManager.instance
	save.set_save_path(BASE)
	assert_true(save.has_save_file(), "o .old voltou a ser o save")
	assert_eq(save.continue_game(), OK)
	assert_eq(GameState.instance.team_money, 4321)
