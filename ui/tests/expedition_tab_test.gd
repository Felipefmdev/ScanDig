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

## Preços e detector exigido vêm dos .tres dos mapas (#64): o teste confere regras, não preços.
func _map(map_id: String) -> MapData:
	return load("res://items/maps/%s.tres" % map_id) as MapData

func _run() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	# Save isolado: nada deste teste toca o user://scandig_save.json do jogador.
	SaveManager.instance.use_test_save_dir("expedition_tab_test")
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
	var unlock_btn: Button = ui.get("unlock_map_btn") as Button
	var depart_btn: Button = ui.depart_btn
	var status_label: Label = ui.map_status_label
	_check(unlock_btn == null or (not unlock_btn.visible and unlock_btn.disabled), "menu sem comando de abrir rotas")
	_check(status_label != null, "MapStatusLabel presente")
	# #59: cor de aviso no tamanho padrão do theme (não o 15 do WarningLabel).
	_check(status_label.theme_type_variation == &"StatusLabel", "MapStatusLabel usa StatusLabel: %s" % status_label.theme_type_variation)
	_check(status_label.get_theme_font_size("font_size") == ui.map_list.get_theme_font_size("font_size") and status_label.get_theme_color("font_color").is_equal_approx(UiPalette.RED_BURNT), "MapStatusLabel no tamanho padrão e em RED_BURNT: %d" % status_label.get_theme_font_size("font_size"))

	var campo_data: MapData = _map("campo")
	gs.load_snapshot({"team_money": campo_data.unlock_cost + 1300, "current_day": 1, "discovered_items": [], "upgrade_levels": {}, "unlocked_maps": [], "defeated_bosses": []})
	await _wait(3)

	_check(map_list.item_count == 5, "5 mapas na lista: %d" % map_list.item_count)
	var row3: String = map_list.get_item_text(3)
	_check(row3.contains("🔒 Geleira Eterna"), "item 3 Geleira bloqueada: %s" % row3)
	_check(map_list.get_item_text(4).contains("Cratera"), "item 4 Cratera: %s" % map_list.get_item_text(4))
	_check(map_list.get_item_text(0).begins_with("✔ Praia"), "item 0 jogável: %s" % map_list.get_item_text(0))
	var row1: String = map_list.get_item_text(1)
	_check(row1.contains("🔒 Campo Antigo") and row1.contains("Caranguejo-Rei"), "item 1 bloqueado: %s" % row1)

	_select_map(map_list, 1)
	_check(unlock_btn == null or (not unlock_btn.visible and unlock_btn.disabled), "Campo fechado nao expoe compra")
	_check(depart_btn.disabled, "partir desabilitado no Campo bloqueado")
	# Motivo visivel e tooltip de partir continuam, sem acao de compra.
	var boss_reason: String = "Vença o chefe Caranguejo-Rei (Praia) para liberar."
	_check(status_label.visible and status_label.text == "🔒 " + boss_reason, "motivo visível no Campo: '%s'" % status_label.text)
	_check(depart_btn.tooltip_text == boss_reason, "partir explica rota fechada")
	_select_map(map_list, 0)
	_check(not status_label.visible, "sem motivo na Praia jogável")
	_select_map(map_list, 1)

	gs.request_report_boss_defeated("king_crab")
	await _wait(3)
	_check(not gs.is_map_unlocked("campo"), "chefe derrotado nao abre pelo menu")
	_check(unlock_btn == null or (not unlock_btn.visible and unlock_btn.disabled), "sem Unlock mesmo com chefe e saldo")
	_check(status_label.visible and status_label.text.contains("passagem"), "uso da chave na passagem fica explicito")
	var money_before: int = gs.team_money
	if unlock_btn != null:
		unlock_btn.pressed.emit()
	await _wait(3)
	_check(not gs.is_map_unlocked("campo") and gs.team_money == money_before, "sinal legado da UI nao abre nem cobra")
	# Somente seed host-local de recibo salvo: nao alegar interacao fisica neste testeUI.
	_check(gs.open_boss_passage("campo") == OK, "abertura host-local com save OK")
	await _wait(3)
	_check(gs.team_money == money_before, "abertura nao debita preco MapData")
	_check(campo_data.unlock_cost > 0 and campo_data.required_detector_level > 1, "dados historicos preservados")
	_check(gs.equipped_detector_level == 1, "detector inicial preservado")
	_check(map_list.get_item_text(1).begins_with("✔ Campo Antigo"), "Campo com recibo jogavel sem upgrade")
	_select_map(map_list, 1)
	_check(not depart_btn.disabled and not status_label.visible, "partir habilitado sem motivo de detector")
	for route_id: String in ["ruinas", "geleira"]:
		var route: Dictionary = GameState.MAP_UNLOCK_BOSSES[route_id]
		gs.request_report_boss_defeated(str(route["boss_id"]))
		_check(gs.open_boss_passage(route_id) == OK, "recibo salvo: " + route_id)
		await _wait(3)
		var index: int = 2 if route_id == "ruinas" else 3
		_select_map(map_list, index)
		_check(map_list.get_item_text(index).begins_with("✔"), "recibo jogavel: " + route_id)
		_check(not depart_btn.disabled and not status_label.visible, "sem gate de detector: " + route_id)
		_check(_map(route_id).required_detector_level > 1 and _map(route_id).unlock_cost > 0, "MapData historico: " + route_id)
		_check(gs.team_money == money_before, "sem compra/reembolso: " + route_id)

	_select_map(map_list, 0)
	_check(not depart_btn.disabled, "partir habilitado na Praia: %s" % depart_btn.tooltip_text)

	gs.reset_state()
	print("RESULT fails=%d" % _fails)
	quit(_fails)
