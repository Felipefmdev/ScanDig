# Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/quest_secret_test.gd
# Missões, segredos e chefes extras (#45) e save v4. Grava o save: faça backup.
extends SceneTree

var _fails: int = 0
var _quest_signals: Array[String] = []
var _secret_signals: Array[String] = []

func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_fails += 1

func _wait(frames: int) -> void:
	for i in range(frames):
		await process_frame

func _initialize() -> void:
	_run.call_deferred()

func _on_quest_completed(quest_id: String, reward: int) -> void:
	_quest_signals.append("%s:%d" % [quest_id, reward])

func _on_secret_found(secret_id: String) -> void:
	_secret_signals.append(secret_id)

func _run() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	await _wait(10)
	# Save isolado: o teste não lê nem grava o save do jogador.
	SaveManager.instance.use_test_save_dir("quest_secret_test")
	var gs: GameState = GameState.instance
	var save: SaveManager = SaveManager.instance
	_check(gs != null and save != null, "GameState e SaveManager presentes")
	if gs == null or save == null:
		print("RESULT fails=%d" % _fails)
		quit(_fails)
		return
	gs.quest_completed.connect(_on_quest_completed)
	gs.secret_found.connect(_on_secret_found)
	gs.load_snapshot({"team_money": 1000, "current_day": 1, "discovered_items": [], "upgrade_levels": {}, "unlocked_maps": [], "defeated_bosses": [], "completed_quests": [], "found_secrets": []})
	_quest_signals.clear()
	_secret_signals.clear()

	# Missão: paga 600 uma vez só.
	gs.request_complete_quest("ze_anzol")
	_check(gs.is_quest_completed("ze_anzol"), "ze_anzol concluída")
	_check(gs.team_money == 1600, "missão pagou 600: %d" % gs.team_money)
	_check(_quest_signals == ["ze_anzol:600"], "quest_completed uma vez com 600: %s" % str(_quest_signals))
	gs.request_complete_quest("ze_anzol")
	_check(gs.team_money == 1600, "segunda chamada não paga: %d" % gs.team_money)
	_check(_quest_signals.size() == 1, "sem sinal repetido: %s" % str(_quest_signals))
	gs.request_complete_quest("missao_falsa")
	gs.request_complete_quest("../catalog/alianca_ouro")
	_check(gs.completed_quests == ["ze_anzol"] and gs.team_money == 1600, "missão desconhecida ignorada: %s" % str(gs.completed_quests))

	# Segredo: registra uma vez, sem dinheiro; id desconhecido é ignorado.
	gs.request_report_secret("praia_polvo")
	_check(gs.is_secret_found("praia_polvo"), "praia_polvo encontrado")
	_check(_secret_signals == ["praia_polvo"], "secret_found uma vez: %s" % str(_secret_signals))
	gs.request_report_secret("praia_polvo")
	gs.request_report_secret("segredo_falso")
	_check(gs.found_secrets == ["praia_polvo"], "segredo repetido/desconhecido ignorado: %s" % str(gs.found_secrets))
	_check(_secret_signals.size() == 1 and gs.team_money == 1600, "segredo não paga nem repete sinal")

	# Chefe extra: registrado, sem desbloquear nada.
	gs.request_report_boss_defeated("octopus")
	_check(gs.is_boss_defeated("octopus"), "octopus registrado")
	_check(gs.unlocked_maps.is_empty(), "octopus não desbloqueia mapa: %s" % str(gs.unlocked_maps))
	_check(gs.get_map_unlock_block_reason("campo") == "Vença o chefe Caranguejo-Rei (Praia) para liberar.", "campo continua pedindo o Caranguejo-Rei")
	gs.request_report_boss_defeated("chefe_falso")
	_check(gs.defeated_bosses == ["octopus"], "chefe desconhecido ignorado: %s" % str(gs.defeated_bosses))

	# Snapshot leva as duas listas.
	var snapshot: Dictionary = gs.get_snapshot()
	_check(snapshot.get("completed_quests", []) == ["ze_anzol"] and snapshot.get("found_secrets", []) == ["praia_polvo"], "snapshot com as listas: %s" % str(snapshot))

	# Save v4: salvar e carregar mantém as listas.
	_check(save.save_game() == OK, "save_game OK")
	var saved: Dictionary = save.load_from_file()
	_check(int(saved.get("version", 0)) == 4, "save versão 4: %s" % str(saved.get("version")))
	gs.reset_state()
	_check(gs.completed_quests.is_empty() and gs.found_secrets.is_empty(), "reset limpa as listas")
	_quest_signals.clear()
	_secret_signals.clear()
	_check(save.load_game() == OK, "load_game v4 OK")
	_check(gs.is_quest_completed("ze_anzol") and gs.is_secret_found("praia_polvo"), "listas voltam do save: %s / %s" % [str(gs.completed_quests), str(gs.found_secrets)])
	_check(gs.team_money == 1600 and gs.is_boss_defeated("octopus"), "dinheiro e chefes voltam do save")
	# A missão carregada não paga de novo.
	gs.request_complete_quest("ze_anzol")
	_check(gs.team_money == 1600, "missão do save não paga de novo: %d" % gs.team_money)

	# Save v3: sem as listas novas; ancient_guardian agora libera a Geleira.
	_check(save.save_to_file({"version": 3, "team_money": 30000, "current_day": 9, "discovered_items": [],
		"upgrade_levels": {"detector": 4}, "unlocked_maps": ["campo", "ruinas"],
		"defeated_bosses": ["king_crab", "giant_mole", "ancient_guardian"]}) == OK, "grava save v3")
	_check(save.load_game() == OK, "load_game v3 OK")
	_check(gs.completed_quests.is_empty() and gs.found_secrets.is_empty(), "save v3 carrega listas vazias: %s / %s" % [str(gs.completed_quests), str(gs.found_secrets)])
	_check(gs.team_money == 30000 and gs.current_day == 9, "save v3 mantém dinheiro e dia")
	_check(gs.is_boss_defeated("ancient_guardian"), "save v3 mantém ancient_guardian")
	_check(gs.get_map_unlock_block_reason("geleira") == "", "ancient_guardian libera a Geleira: %s" % gs.get_map_unlock_block_reason("geleira"))
	_check(gs.get_map_unlock_block_reason("cratera") == "Vença o chefe Mamute Congelado (Geleira Eterna) para liberar.", "cratera pede o Mamute: %s" % gs.get_map_unlock_block_reason("cratera"))

	gs.reset_state()
	print("RESULT fails=%d" % _fails)
	quit(_fails)
