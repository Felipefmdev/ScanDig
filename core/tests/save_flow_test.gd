## Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/save_flow_test.gd
## Política do save: carregar sem perder progresso, continue_game, start_new_game,
## save corrompido e versão nova. Cada caso usa um save isolado em user://test_saves/.
extends SceneTree

var _fails: int = 0
var _load_failed: Array[String] = []
var _new_games: int = 0
var _state_changes: int = 0
var save: SaveManager = null
var gs: GameState = null
var sm: SessionManager = null

func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_fails += 1

func _wait(frames: int) -> void:
	for i in range(frames):
		await process_frame

func _wait_until(cond: Callable, max_frames: int) -> bool:
	for i in range(max_frames):
		if bool(cond.call()):
			return true
		await process_frame
	return bool(cond.call())

func _initialize() -> void:
	_run.call_deferred()

## Save isolado com `data` no disco, ainda não aplicado; GameState no estado inicial.
func _prepare(test_name: String, data: Dictionary) -> void:
	save.use_test_save_dir(test_name)
	gs.reset_state()
	if not data.is_empty():
		_check(save.save_to_file(data) == OK, "%s: grava o save de teste" % test_name)
	save.set_save_path(save.save_path)
	_load_failed.clear()
	_new_games = 0
	_state_changes = 0

func _file_text(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""

func _start_expedition() -> bool:
	sm.request_start_expedition("praia")
	return await _wait_until(func() -> bool: return sm.is_in_expedition() and current_scene != null and current_scene.name == "MapPraia", 120)

func _end_expedition() -> bool:
	sm.request_end_expedition()
	return await _wait_until(func() -> bool: return not sm.is_in_expedition() and current_scene != null and current_scene.name == "LobbyBase", 120)

func _run() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	await _wait(10)
	save = SaveManager.instance
	gs = GameState.instance
	sm = SessionManager.instance
	_check(save != null and gs != null and sm != null, "autoloads presentes")
	save.save_load_failed.connect(func(message: String) -> void: _load_failed.append(message))
	save.new_game_started.connect(func() -> void: _new_games += 1)
	save.save_state_changed.connect(func() -> void: _state_changes += 1)
	_check(save.SAVE_VERSION == 6, "SAVE_VERSION 6")

	await _case_auto_apply()
	await _case_continue()
	await _case_new_game()
	await _case_corrupt()
	await _case_newer_version()

	save.use_test_save_dir("save_flow_test")
	gs.reset_state()
	print("RESULT fails=%d" % _fails)
	quit(_fails)


## Save v4 no disco, ninguém escolhe nada: a expedição aplica antes e o fim grava dia+1.
func _case_auto_apply() -> void:
	_prepare("save_flow_auto", {"version": 4, "saved_at": 1700000000, "team_money": 3200, "current_day": 5,
		"discovered_items": ["moeda_antiga"], "upgrade_levels": {"detector": 1, "backpack": 2},
		"unlocked_maps": [], "defeated_bosses": ["king_crab"], "completed_quests": ["ze_anzol"], "found_secrets": []})
	_check(not save.is_progress_applied(), "auto: save no disco ainda não aplicado")
	var summary: Dictionary = save.get_save_summary()
	print("auto summary: ", summary)
	_check(summary["exists"] and summary["valid"] and summary["version"] == 4, "auto: resumo válido v4")
	_check(summary["day"] == 5 and summary["money"] == 3200 and summary["museum_found"] == 1, "auto: resumo com dia 5, R$ 3200, 1 no museu")
	_check(summary["museum_total"] == gs.get_total_catalog_items() and summary["saved_at"] == 1700000000 and summary["error"] == "", "auto: museum_total, saved_at e sem erro")
	_check(gs.team_money == 100 and gs.current_day == 1, "auto: o resumo não aplica")

	var before: String = _file_text(save.save_path)
	_check(save.save_game() == ERR_UNAVAILABLE, "auto: save_game recusa gravar por cima do save não aplicado")
	_check(_file_text(save.save_path) == before, "auto: arquivo intacto depois da recusa")

	_check(await _start_expedition(), "auto: expedição começou")
	_check(save.is_progress_applied(), "auto: aplicado ao começar a expedição")
	_check(gs.team_money == 3200 and gs.current_day == 5 and gs.discovered_items.has("moeda_antiga"), "auto: estado do save antes da expedição: R$ %d, dia %d" % [gs.team_money, gs.current_day])
	_check(gs.get_upgrade_level("backpack") == 2 and gs.is_quest_completed("ze_anzol"), "auto: upgrades e missões do save")
	gs.request_report_discovery("chave_enferrujada", 20)
	await _wait(2)
	_check(await _end_expedition(), "auto: voltou ao lobby")
	var saved: Dictionary = save.load_from_file()
	print("auto saved: ", saved)
	_check(int(saved.get("current_day", 0)) == 6, "auto: gravou dia 6: %s" % str(saved.get("current_day")))
	_check(int(saved.get("team_money", 0)) >= 3200, "auto: não perdeu dinheiro: %s" % str(saved.get("team_money")))
	var items: Array = saved.get("discovered_items", [])
	_check(items.has("moeda_antiga") and items.has("chave_enferrujada"), "auto: museu antigo + item novo: %s" % str(items))
	_check(int(saved.get("version", 0)) == SaveManager.SAVE_VERSION and int(saved.get("saved_at", 0)) > 1700000000, "auto: versão atual e saved_at novo")
	_check(int(sm.get_last_summary().get("money_start", 0)) == 3200, "auto: resumo começa com R$ 3200: %s" % str(sm.get_last_summary().get("money_start")))
	_check(not FileAccess.file_exists(save.save_path + ".tmp"), "auto: sem .tmp sobrando (gravação atômica)")


## continue_game aplica uma vez; a segunda chamada não recarrega.
func _case_continue() -> void:
	_prepare("save_flow_continue", {"version": 4, "team_money": 999, "current_day": 7, "discovered_items": ["lata_enferrujada"]})
	var summary: Dictionary = save.get_save_summary()
	_check(summary["day"] == 7 and summary["money"] == 999 and gs.team_money == 100, "continue: resumo sem aplicar")
	_check(save.continue_game() == OK, "continue: OK")
	_check(gs.team_money == 999 and gs.current_day == 7 and save.is_progress_applied(), "continue: aplicou R$ 999 / dia 7")
	gs.load_snapshot({"team_money": 5})
	_check(save.continue_game() == OK and gs.team_money == 5, "continue: idempotente (não recarrega): %d" % gs.team_money)
	_check(save.save_game() == OK, "continue: grava depois de aplicado")
	# Save v3 também continua (convertido).
	_prepare("save_flow_continue_v3", {"version": 3, "team_money": 450, "current_day": 3, "discovered_items": [],
		"upgrade_levels": {"detector": 1}, "unlocked_maps": ["campo"], "defeated_bosses": ["king_crab"]})
	_check(save.continue_game() == OK and gs.team_money == 450 and gs.is_map_unlocked("campo"), "continue: save v3 convertido")
	_check(gs.completed_quests.is_empty() and gs.found_secrets.is_empty(), "continue: v3 sem missões/segredos")


## start_new_game: backup, R$ 100 / dia 1, save gravado; ERR_BUSY durante a expedição.
func _case_new_game() -> void:
	_prepare("save_flow_new", {"version": 4, "team_money": 999, "current_day": 7, "discovered_items": ["lata_enferrujada"]})
	var old_text: String = _file_text(save.save_path)
	_check(save.start_new_game() == OK, "novo: OK")
	_check(_file_text(save.get_backup_path()) == old_text, "novo: backup com o save antigo em %s" % save.get_backup_path())
	_check(gs.team_money == 100 and gs.current_day == 1 and gs.discovered_items.is_empty(), "novo: R$ 100, dia 1, museu vazio")
	var saved: Dictionary = save.load_from_file()
	_check(int(saved.get("team_money", 0)) == 100 and int(saved.get("current_day", 0)) == 1, "novo: save gravado já")
	_check(_new_games == 1 and _state_changes > 0 and save.is_progress_applied(), "novo: new_game_started e save_state_changed")
	_check(await _start_expedition(), "novo: expedição começou")
	_check(save.start_new_game() == ERR_BUSY, "novo: ERR_BUSY durante a expedição")
	_check(save.continue_game() == ERR_BUSY, "continue: ERR_BUSY durante a expedição")
	_check(await _end_expedition(), "novo: voltou ao lobby")


## JSON inválido ou tipo errado: guarda como corrupt-*, avisa e começa do zero.
func _case_corrupt() -> void:
	_prepare("save_flow_corrupt", {})
	var file: FileAccess = FileAccess.open(save.save_path, FileAccess.WRITE)
	file.store_string("{ \"team_money\": 500, isto não é json")
	file.close()
	save.set_save_path(save.save_path)
	var summary: Dictionary = save.get_save_summary()
	print("corrupt summary: ", summary)
	_check(summary["exists"] and not summary["valid"] and not str(summary["error"]).is_empty(), "corrompido: resumo inválido com motivo")
	gs.load_snapshot({"team_money": 777})
	_check(save.continue_game() == ERR_FILE_CORRUPT, "corrompido: continue_game devolve ERR_FILE_CORRUPT")
	_check(_load_failed == [SaveManager.MSG_CORRUPT], "corrompido: save_load_failed: %s" % str(_load_failed))
	var dir_path: String = save.save_path.get_base_dir()
	var corrupt_files: Array[String] = []
	for name: String in DirAccess.get_files_at(dir_path):
		if name.begins_with("scandig_save.corrupt-") and name.ends_with(".json"):
			corrupt_files.append(name)
	_check(corrupt_files.size() == 1 and not FileAccess.file_exists(save.save_path), "corrompido: virou %s" % str(corrupt_files))
	_check(gs.team_money == 100 and gs.current_day == 1 and save.is_progress_applied(), "corrompido: jogo novo e progresso aplicado")
	_check(save.save_game() == OK, "corrompido: depois grava normalmente")

	# Tipo errado que o apply_snapshot rejeitaria: o mesmo caminho, pela expedição.
	_prepare("save_flow_corrupt_type", {"version": 4, "team_money": 300, "discovered_items": "moeda_antiga"})
	_check(not save.get_save_summary()["valid"], "corrompido (tipo): resumo inválido: %s" % save.get_save_summary()["error"])
	_check(await _start_expedition(), "corrompido (tipo): expedição começou")
	_check(_load_failed == [SaveManager.MSG_CORRUPT] and gs.team_money == 100, "corrompido (tipo): avisou e começou do zero")
	_check(await _end_expedition(), "corrompido (tipo): voltou ao lobby")
	_check(int(save.load_from_file().get("current_day", 0)) == 2, "corrompido (tipo): o jogo novo foi gravado")


## Versão 99: não aplica, bloqueia a gravação e não toca no arquivo.
func _case_newer_version() -> void:
	_prepare("save_flow_newer", {"version": 99, "team_money": 50000, "current_day": 40, "campo_do_futuro": {"x": 1}})
	var original: String = _file_text(save.save_path)
	var summary: Dictionary = save.get_save_summary()
	_check(summary["exists"] and not summary["valid"] and summary["version"] == 99, "v99: resumo inválido com versão 99: %s" % str(summary))
	_check(save.save_game() == ERR_UNAUTHORIZED, "v99: save_game recusa antes de tentar carregar")
	_check(save.continue_game() == ERR_FILE_UNRECOGNIZED, "v99: continue_game não aplica")
	_check(_load_failed == [SaveManager.MSG_NEWER], "v99: save_load_failed: %s" % str(_load_failed))
	_check(gs.team_money == 100 and gs.current_day == 1, "v99: estado não veio do save")
	_check(save.save_game() == ERR_UNAUTHORIZED, "v99: save_game bloqueado na sessão")
	_check(await _start_expedition(), "v99: expedição começou")
	_check(await _end_expedition(), "v99: voltou ao lobby")
	_check(_file_text(save.save_path) == original, "v99: arquivo intacto depois da expedição")
	# Novo jogo explícito libera: guarda o v99 no backup.
	_check(save.start_new_game() == OK and _file_text(save.get_backup_path()) == original, "v99: start_new_game guarda o v99 no backup")
	_check(int(save.load_from_file().get("version", 0)) == SaveManager.SAVE_VERSION, "v99: save novo na versão atual")
