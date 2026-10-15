# Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://ui/tests/lobby_names_test.gd
# Host sozinho na porta 7798, sem UPnP real (o upnp_finished é emitido à mão).
# Grava o nome em user://scandig_settings.cfg: faça backup.
extends SceneTree

const PORT: int = 7798

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

func _host(net: NetworkManager) -> Error:
	# Fechar o servidor ENet pode levar alguns frames para liberar a porta.
	var err: Error = net.host_game(PORT)
	var tries: int = 0
	while err != OK and tries < 10:
		await _wait(10)
		err = net.host_game(PORT)
		tries += 1
	return err

func _run() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	await _wait(10)
	var net: NetworkManager = NetworkManager.instance
	var menu: MultiplayerMenu = current_scene.get_node_or_null("UILayer/MultiplayerMenu") as MultiplayerMenu
	_check(net != null and menu != null, "NetworkManager e MultiplayerMenu presentes")
	if net == null or menu == null:
		print("RESULT fails=%d" % _fails)
		quit(_fails)
		return
	var name_backup: String = net.local_player_name
	var name_edit: LineEdit = menu.name_line_edit
	_check(name_edit != null and name_edit.visible, "campo de nome visível")
	_check(name_edit.text == name_backup, "campo começa com o nome salvo: '%s'" % name_edit.text)

	# 1. Nome.
	name_edit.text = "  Murilo  "
	name_edit.text_submitted.emit(name_edit.text)
	_check(net.local_player_name == "Murilo", "nome local sanitizado: '%s'" % net.local_player_name)
	_check(name_edit.text == "Murilo", "campo reescrito: '%s'" % name_edit.text)

	# 2. Lista.
	var err: Error = await _host(net)
	_check(err == OK, "host_game(%d)=%d" % [PORT, err])
	await _wait(3)
	var list: ItemList = menu.players_list
	_check(list.item_count == 1, "lista com 1 jogador: %d" % list.item_count)
	_check(list.item_count > 0 and list.get_item_text(0) == "Murilo (host) (você)", "linha do host: '%s'" % (list.get_item_text(0) if list.item_count > 0 else ""))

	# 3. UPnP com sucesso.
	net.public_ip = "203.0.113.5"
	net.upnp_finished.emit(true, "203.0.113.5", "ok-msg")
	_check(menu.status_label.text == "ok-msg", "status ok: '%s'" % menu.status_label.text)
	_check(menu.share_label.visible and menu.share_label.text.contains("203.0.113.5"), "share com IP: '%s'" % menu.share_label.text)
	_check(menu.copy_ip_button.visible, "copiar IP visível")
	menu.copy_ip_button.pressed.emit()
	_check(menu.status_label.text == "IP copiado!", "status copiado: '%s'" % menu.status_label.text)

	# 4. UPnP com falha.
	net.upnp_finished.emit(false, "", "falhou-msg")
	_check(menu.status_label.text == "falhou-msg", "status falha: '%s'" % menu.status_label.text)
	_check(not menu.copy_ip_button.visible, "copiar IP oculto na falha")
	_check(menu.share_label.visible and not menu.share_label.text.contains("203.0.113.5"), "share só com rede local: '%s'" % menu.share_label.text)

	# 5. Erro.
	net.connection_error.emit("erro-x")
	_check(menu.status_label.text == "erro-x", "status erro: '%s'" % menu.status_label.text)

	# 6. Saída.
	net.disconnect_game()
	await _wait(5)
	_check(not menu.share_label.visible, "share oculto após sair")
	_check(not menu.copy_ip_button.visible, "copiar IP oculto após sair")
	_check(name_edit.text == "Murilo", "nome mantido após sair: '%s'" % name_edit.text)

	# 7. IP inválido.
	menu.ip_line_edit.text = "abc"
	menu.join_button.pressed.emit()
	await _wait(2)
	_check(menu.status_label.text == "Endereço inválido: abc", "status IP inválido: '%s'" % menu.status_label.text)
	_check(not menu.leave_button.visible, "sem sessão após IP inválido")

	# 8. Restaura o nome.
	net.set_local_player_name(name_backup, true)
	print("RESULT fails=%d" % _fails)
	quit(_fails)
