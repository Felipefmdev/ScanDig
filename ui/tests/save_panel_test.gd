# Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://ui/tests/save_panel_test.gd
# Painel "Progresso" do menu de rede com um SaveManager falso (contrato do pacote do save).
extends SceneTree

class FakeSave extends Node:
	signal save_load_failed(message: String)
	signal new_game_started()
	signal save_state_changed()

	var summary: Dictionary = {}
	var applied: bool = false
	var next_error: Error = OK
	var continue_calls: int = 0
	var new_game_calls: int = 0

	func get_save_summary() -> Dictionary:
		return summary

	func is_progress_applied() -> bool:
		return applied

	func continue_game() -> Error:
		continue_calls += 1
		if next_error == OK:
			applied = true
			save_state_changed.emit()
		return next_error

	func start_new_game() -> Error:
		new_game_calls += 1
		if next_error == OK:
			applied = true
			new_game_started.emit()
		return next_error

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
	SaveManager.instance.use_test_save_dir("save_panel_test")
	await _wait(10)
	var gs: GameState = GameState.instance
	var menu: MultiplayerMenu = current_scene.get_node_or_null("UILayer/MultiplayerMenu") as MultiplayerMenu
	var session: Node = root.get_node_or_null(^"CoreSession")
	_check(gs != null and menu != null and session != null, "GameState, MultiplayerMenu e CoreSession presentes")
	if gs == null or menu == null or session == null:
		print("RESULT fails=%d" % _fails)
		quit(_fails)
		return

	# 0. Formatação do dinheiro.
	_check(MultiplayerMenu.format_money(0) == "0" and MultiplayerMenu.format_money(999) == "999", "format_money curtos")
	_check(MultiplayerMenu.format_money(3200) == "3.200" and MultiplayerMenu.format_money(1234567) == "1.234.567", "format_money milhares")

	var fake: FakeSave = FakeSave.new()
	root.add_child(fake)
	fake.summary = {"exists": true, "valid": true, "version": 4, "day": 5, "money": 3200,
		"museum_found": 3, "museum_total": 27, "saved_at": 1760000000, "error": ""}
	menu.set_save_manager(fake)
	await _wait(2)

	# 1. Save válido, ainda não aplicado.
	_check(menu.progress_box.visible, "painel visível offline")
	_check(menu.continue_button.visible and menu.continue_button.text == "Continuar (Dia 5 • R$\u00a03.200)", "continuar: '%s'" % menu.continue_button.text)
	_check(menu.progress_info_label.text.begins_with("Museu: 3/27") and menu.progress_info_label.text.contains("Salvo em "), "info: '%s'" % menu.progress_info_label.text)
	_check(not menu.progress_label.visible and not menu.progress_warning_label.visible, "sem texto de progresso nem aviso")
	fake.summary["saved_at"] = 0
	fake.save_state_changed.emit()
	_check(menu.progress_info_label.text == "Museu: 3/27", "sem data com saved_at=0: '%s'" % menu.progress_info_label.text)

	# 2. Erros de continue_game.
	fake.next_error = ERR_BUSY
	menu.continue_button.pressed.emit()
	_check(menu.progress_warning_label.visible and menu.progress_warning_label.text == "Termine a expedição primeiro.", "ERR_BUSY: '%s'" % menu.progress_warning_label.text)
	fake.next_error = ERR_UNAUTHORIZED
	menu.continue_button.pressed.emit()
	_check(menu.progress_warning_label.text == "Só o host pode mudar o progresso.", "ERR_UNAUTHORIZED: '%s'" % menu.progress_warning_label.text)
	_check(menu.continue_button.visible, "continuar segue disponível após erro")

	# 3. Continuar com sucesso: só o texto.
	gs.load_snapshot({"team_money": 3200, "current_day": 5})
	fake.next_error = OK
	menu.continue_button.pressed.emit()
	await _wait(2)
	_check(fake.continue_calls == 3, "continue_game chamado: %d" % fake.continue_calls)
	_check(not menu.continue_button.visible, "aplicado: sem botão continuar")
	_check(menu.progress_label.visible and menu.progress_label.text == "Progresso: Dia 5 • R$\u00a03.200", "aplicado: '%s'" % menu.progress_label.text)
	_check(not menu.progress_warning_label.visible, "sucesso limpa o aviso")

	# 4. Novo jogo pede confirmação antes de chamar start_new_game.
	fake.applied = false
	fake.save_state_changed.emit()
	menu.new_game_button.pressed.emit()
	await _wait(2)
	_check(menu.new_game_dialog.visible, "confirmação aberta")
	_check(fake.new_game_calls == 0, "start_new_game ainda não chamado")
	_check(menu.new_game_dialog.dialog_text == "Apagar o progresso salvo (Dia 5 • R$\u00a03.200)? Um backup será salvo.", "texto: '%s'" % menu.new_game_dialog.dialog_text)
	menu.new_game_dialog.hide()
	menu.new_game_dialog.confirmed.emit()
	_check(fake.new_game_calls == 1, "start_new_game após confirmar: %d" % fake.new_game_calls)
	fake.summary = {"exists": false, "valid": false, "error": ""}
	menu.new_game_button.pressed.emit()
	await _wait(2)
	_check(menu.new_game_dialog.dialog_text == "Começar do zero?", "sem save: '%s'" % menu.new_game_dialog.dialog_text)
	menu.new_game_dialog.hide()

	# 5. Save ilegível: aviso e só "Novo jogo".
	fake.applied = false
	fake.summary = {"exists": true, "valid": false, "error": "JSON inválido"}
	fake.save_state_changed.emit()
	_check(menu.progress_warning_label.visible and menu.progress_warning_label.text == "Save ilegível: JSON inválido", "ilegível: '%s'" % menu.progress_warning_label.text)
	_check(not menu.continue_button.visible and not menu.progress_label.visible and menu.new_game_button.visible, "ilegível: só novo jogo")

	# 6. save_load_failed mostra o texto exato.
	fake.save_load_failed.emit("Save de uma versão mais nova do jogo (v9).")
	_check(menu.progress_warning_label.visible and menu.progress_warning_label.text == "Save de uma versão mais nova do jogo (v9).", "save_load_failed: '%s'" % menu.progress_warning_label.text)

	# 7. Em expedição: escondido.
	fake.summary = {"exists": true, "valid": true, "day": 5, "money": 3200, "museum_found": 3, "museum_total": 27, "saved_at": 0}
	session.set("_current_map", load("res://items/maps/praia.tres"))
	menu._refresh_progress_panel()
	_check(not menu.progress_box.visible, "expedição: painel escondido")
	session.set("_current_map", null)
	menu._refresh_progress_panel()
	_check(menu.progress_box.visible, "fora da expedição: painel de volta")

	# 8. Cliente (peer ENet tentando conectar, id != 1): escondido.
	var previous_peer: MultiplayerPeer = root.multiplayer.multiplayer_peer
	var client: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: Error = client.create_client("127.0.0.1", 7797)
	_check(err == OK, "peer cliente criado: %d" % err)
	root.multiplayer.multiplayer_peer = client
	menu._refresh_progress_panel()
	_check(not menu.progress_box.visible, "cliente: painel escondido")
	client.close()
	root.multiplayer.multiplayer_peer = previous_peer
	menu._refresh_progress_panel()
	_check(menu.progress_box.visible, "offline de novo: painel visível")

	menu.set_save_manager(null)
	fake.queue_free()
	gs.reset_state()
	print("RESULT fails=%d" % _fails)
	quit(_fails)
