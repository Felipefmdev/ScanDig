# Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://ui/tests/expedition_tab_test.gd
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

func _select_map(map_list: ItemList, idx: int) -> void:
	map_list.select(idx)
	map_list.item_selected.emit(idx)

func _run() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	await _wait(10)
	var gs: GameState = GameState.instance
	_check(gs != null, "GameState presente")
	var ui: BaseStationUI = current_scene.get_node("UILayer/BaseStationUI") as BaseStationUI
	_check(ui != null, "BaseStationUI presente")
	if gs == null or ui == null:
		print("RESULT fails=%d" % _fails)
		quit(_fails)
		return

	var map_list: ItemList = ui.map_list
	var unlock_btn: Button = ui.unlock_map_btn
	var depart_btn: Button = ui.depart_btn
	var feedback: Label = ui.expedition_feedback_label
	_check(unlock_btn != null, "UnlockMapButton presente")

	gs.load_snapshot({"team_money": 2500, "current_day": 1, "discovered_items": [], "upgrade_levels": {}, "unlocked_maps": [], "defeated_bosses": []})
	await _wait(3)

	_check(map_list.item_count == 4, "4 mapas na lista: %d" % map_list.item_count)
	_check(map_list.get_item_text(0).begins_with("✔ Praia"), "item 0 jogável: %s" % map_list.get_item_text(0))
	var row1: String = map_list.get_item_text(1)
	_check(row1.contains("🔒 Campo Antigo") and row1.contains("Caranguejo-Rei"), "item 1 bloqueado: %s" % row1)

	_select_map(map_list, 1)
	_check(unlock_btn.visible, "desbloquear visível no Campo")
	_check(unlock_btn.disabled, "desbloquear desabilitado sem chefe: %s" % unlock_btn.tooltip_text)
	_check(depart_btn.disabled, "partir desabilitado no Campo bloqueado")

	gs.request_report_boss_defeated("king_crab")
	await _wait(3)
	_check(not unlock_btn.disabled, "desbloquear habilitado após chefe")
	_check(unlock_btn.text == "Desbloquear Campo Antigo (R$ 1200)", "texto do botão: %s" % unlock_btn.text)

	unlock_btn.pressed.emit()
	await _wait(5)
	_check(feedback.text == "Campo Antigo desbloqueado!", "feedback: %s" % feedback.text)
	_check(not unlock_btn.visible, "desbloquear oculto após compra")
	# Campo exige detector Nv.2 (upgrade detector >= 1): desbloqueado, mas ainda não jogável.
	var row1_no_detector: String = map_list.get_item_text(1)
	_check(not row1_no_detector.begins_with("✔") and not row1_no_detector.contains("🔒"), "item 1 sem detector Nv.2: %s" % row1_no_detector)
	_select_map(map_list, 1)
	_check(depart_btn.disabled and depart_btn.tooltip_text == "Requer detector nível 2.", "partir bloqueado sem detector Nv.2: %s" % depart_btn.tooltip_text)
	gs.load_snapshot({"upgrade_levels": {"detector": 1}})
	await _wait(3)
	_check(map_list.get_item_text(1).begins_with("✔ Campo Antigo"), "item 1 jogável: %s" % map_list.get_item_text(1))
	_select_map(map_list, 1)
	_check(not depart_btn.disabled, "partir habilitado no Campo: %s" % depart_btn.tooltip_text)

	# Ruínas ainda não tem cena: desbloqueada, mas "Em breve".
	gs.request_report_boss_defeated("giant_mole")
	gs.load_snapshot({"team_money": 8000})
	await _wait(3)
	_select_map(map_list, 2)
	_check(unlock_btn.visible and not unlock_btn.disabled, "desbloquear habilitado nas Ruínas: %s" % unlock_btn.tooltip_text)
	unlock_btn.pressed.emit()
	await _wait(5)
	_check(feedback.text == "Ruínas desbloqueado!", "feedback ruínas: %s" % feedback.text)
	_check(map_list.get_item_text(2).contains("Em breve"), "item 2 em breve: %s" % map_list.get_item_text(2))
	_check(depart_btn.disabled and depart_btn.tooltip_text == "Em breve.", "partir bloqueado nas Ruínas: %s" % depart_btn.tooltip_text)

	_select_map(map_list, 0)
	_check(not depart_btn.disabled, "partir habilitado na Praia: %s" % depart_btn.tooltip_text)

	gs.reset_state()
	print("RESULT fails=%d" % _fails)
	quit(_fails)
