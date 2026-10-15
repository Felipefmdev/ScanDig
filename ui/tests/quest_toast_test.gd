# Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://ui/tests/quest_toast_test.gd
extends SceneTree

var _fails: int = 0

func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_fails += 1

func _wait(frames: int) -> void:
	for i in range(frames):
		await process_frame

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	# Save isolado: nada deste teste toca o user://scandig_save.json do jogador.
	SaveManager.instance.use_test_save_dir("quest_toast_test")
	await _wait(10)
	var gs: GameState = GameState.instance
	var ui: SessionUI = SessionUI.instance
	var session: Node = root.get_node_or_null(^"CoreSession")
	_check(gs != null and ui != null and session != null, "GameState, SessionUI e CoreSession presentes")
	if gs == null or ui == null or session == null:
		print("RESULT fails=%d" % _fails)
		quit(_fails)
		return
	var station: BaseStationUI = current_scene.get_node("UILayer/BaseStationUI") as BaseStationUI
	gs.reset_state()
	await _wait(3)
	var s0: String = GameState.SECRETS[0]
	var s1: String = GameState.SECRETS[1]
	var s2: String = GameState.SECRETS[2]

	# Fora da expedição nada aparece, mesmo sincronizado.
	gs.quest_completed.emit("ze_anzol", 600)
	_check(not ui.toast_panel.visible, "sem aviso no lobby")

	# 1. Expedição simulada + entrada numa sessão: o snapshot inicial não gera avisos.
	session.set("_current_map", load("res://items/maps/praia.tres"))
	ui._on_connected_to_server()
	_check(not ui._should_show_toast(), "antes do primeiro sync: não mostra")
	gs.load_snapshot({"completed_quests": ["ze_anzol"], "found_secrets": [s0, s1]})
	await _wait(3)
	_check(not ui.toast_panel.visible and ui._toast_queue.is_empty(), "leva inicial ignorada: %s" % ui.toast_label.text)
	_check(ui._should_show_toast(), "depois do sync: mostra")
	if station != null:
		_check(station.secrets_label.text == "Segredos —\u00a0Praia\u00a02/6\u00a0• Campo\u00a0Antigo\u00a00/6", "museu: %s" % station.secrets_label.text)

	# 2. Missão concluída depois do sync.
	gs.quest_completed.emit("ze_anzol", 600)
	_check(ui.toast_panel.visible and ui.toast_label.text == "Missão concluída: O anzol de ouro (+R$\u00a0600)", "aviso missão: %s" % ui.toast_label.text)

	# 3. Segredo novo entra na fila e aparece depois do aviso atual.
	gs.load_snapshot({"found_secrets": [s0, s1, s2]})
	await _wait(2)
	_check(ui._toast_queue.size() == 1, "segredo na fila: %d" % ui._toast_queue.size())
	if station != null:
		_check(station.secrets_label.text == "Segredos —\u00a0Praia\u00a03/6\u00a0• Campo\u00a0Antigo\u00a00/6", "museu após segredo: %s" % station.secrets_label.text)
	await create_timer(SessionUI.TOAST_SEC + 0.3).timeout
	_check(ui.toast_panel.visible and ui.toast_label.text == "Segredo encontrado! (Praia\u00a03/6)", "aviso segredo: %s" % ui.toast_label.text)
	await create_timer(SessionUI.TOAST_SEC + 0.3).timeout
	_check(not ui.toast_panel.visible, "aviso some depois de %.0f s" % SessionUI.TOAST_SEC)

	# 4. Id desconhecido usa nome padrão, sem erro.
	gs.quest_completed.emit("missao_inexistente", 0)
	_check(ui.toast_label.text == "Missão concluída: Missão (+R$\u00a00)", "missão desconhecida: %s" % ui.toast_label.text)

	# 5. Volta à base: nada aparece.
	ui._clear_toasts()
	session.set("_current_map", null)
	gs.secret_found.emit(s0)
	_check(not ui.toast_panel.visible, "sem aviso fora da expedição")

	gs.reset_state()
	print("RESULT fails=%d" % _fails)
	quit(_fails)
