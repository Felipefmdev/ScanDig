# Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://ui/tests/room_code_ui_test.gd
# UI do código de sala (#30) sem noray: os sinais do NetworkManager são emitidos à mão.
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

func _type_code(menu: MultiplayerMenu, text: String) -> void:
	menu.code_line_edit.text = text
	menu.code_line_edit.text_changed.emit(text)

func _run() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	# Save isolado: nada deste teste toca o user://scandig_save.json do jogador.
	SaveManager.instance.use_test_save_dir("room_code_ui_test")
	await _wait(10)
	var net: NetworkManager = NetworkManager.instance
	var menu: MultiplayerMenu = current_scene.get_node_or_null("UILayer/MultiplayerMenu") as MultiplayerMenu
	_check(net != null and menu != null, "NetworkManager e MultiplayerMenu presentes")
	if net == null or menu == null:
		print("RESULT fails=%d" % _fails)
		quit(_fails)
		return

	# 0. Modo padrão: Online (código).
	_check(menu.mode_tabs.current_tab == 0, "aba padrão online: %d" % menu.mode_tabs.current_tab)
	_check(menu.mode_tabs.get_tab_title(0) == "Online (código)" and menu.mode_tabs.get_tab_title(1) == "Rede local (IP)", "títulos das abas")
	_check(menu.code_line_edit.max_length == 7 and menu.code_line_edit.placeholder_text == "K7Q-3MX", "campo do código")
	_check(not menu.room_code_box.visible and not menu.cancel_button.visible and not menu.retry_button.visible, "estado inicial sem código/cancelar/tentar")

	# 1. Validação do código.
	for bad: String in ["K7Q3M", "K7Q-3M0", ""]:
		_type_code(menu, bad)
		_check(menu.join_code_button.disabled, "entrar desabilitado com '%s'" % bad)
	_type_code(menu, "k7q-3mx")
	_check(menu.code_line_edit.text == "K7Q-3MX", "maiúsculas: '%s'" % menu.code_line_edit.text)
	_check(not menu.join_code_button.disabled, "entrar habilitado com 'k7q-3mx'")

	# 2. Host: criando sala -> código pronto.
	menu._online_attempt = "host"
	menu._set_status("Criando sala...")
	menu._refresh_session_buttons()
	_check(menu.host_online_button.disabled and menu.join_code_button.disabled and menu.host_button.disabled, "tentativa: hospedar/entrar desabilitados")
	_check(menu.cancel_button.visible, "tentativa: cancelar visível")
	net.online_join_progress.emit("registrando")
	_check(menu.status_label.text == "Criando sala...", "host registrando mantém 'Criando sala...': '%s'" % menu.status_label.text)
	net.room_code_ready.emit("K7Q3MX")
	_check(menu.room_code_box.visible and menu.room_code_label.text == "K7Q-3MX", "código exibido: '%s'" % menu.room_code_label.text)
	_check(menu.get_code_to_copy() == "K7Q3MX", "copiar sem hífen: '%s'" % menu.get_code_to_copy())
	menu.copy_code_button.pressed.emit()
	_check(menu.status_label.text == "Código copiado!", "status copiado: '%s'" % menu.status_label.text)
	_check(not menu.cancel_button.visible, "código pronto: cancelar oculto")
	menu._hide_room_code()

	# 2b. Erro do host e depois sucesso: "Tentar de novo" some quando o código chega.
	menu._online_attempt = "host"
	net.connection_error.emit("Servidor de salas fora do ar.")
	_check(menu.retry_button.visible, "erro do host: tentar de novo visível")
	menu._online_attempt = "host"
	net.room_code_ready.emit("K7Q3MX")
	_check(not menu.retry_button.visible, "código pronto: tentar de novo oculto")
	menu._hide_room_code()

	# 3. Etapas do cliente.
	menu._online_attempt = "join"
	menu._refresh_session_buttons()
	var stages: Dictionary = {
		"registrando": "Conectando ao servidor de salas...",
		"punch": "Conectando ao amigo...",
		"relay": "Conexão direta falhou, usando o servidor...",
	}
	for stage: String in stages:
		net.online_join_progress.emit(stage)
		_check(menu.status_label.text == stages[stage], "etapa %s: '%s'" % [stage, menu.status_label.text])
	_check(menu.join_code_button.disabled and menu.cancel_button.visible, "entrando: botões bloqueados, cancelar visível")
	net.online_join_progress.emit("conectado")
	_check(menu.status_label.text == "", "conectado limpa o status: '%s'" % menu.status_label.text)
	_check(not menu.cancel_button.visible, "conectado: cancelar oculto")

	# 4. Erro do cliente: mensagem do core e botões de volta.
	menu._online_attempt = "join"
	menu._refresh_session_buttons()
	net.connection_error.emit("Sala não encontrada.")
	_check(menu.status_label.text == "Sala não encontrada.", "erro: '%s'" % menu.status_label.text)
	_check(not menu.join_code_button.disabled and not menu.host_online_button.disabled, "erro: entrar/hospedar reabilitados")
	_check(not menu.cancel_button.visible and not menu.retry_button.visible, "erro do cliente: sem cancelar/tentar")

	# 5. Erro do host: "Tentar de novo".
	menu._online_attempt = "host"
	menu._refresh_session_buttons()
	net.connection_error.emit("Servidor de salas fora do ar.")
	_check(menu.status_label.text == "Servidor de salas fora do ar.", "erro host: '%s'" % menu.status_label.text)
	_check(menu.retry_button.visible and not menu.retry_button.disabled, "tentar de novo visível")

	# 6. Cancelar.
	menu._online_attempt = "join"
	menu._refresh_session_buttons()
	menu.cancel_button.pressed.emit()
	await _wait(2)
	_check(not menu.cancel_button.visible and not menu.join_code_button.disabled, "cancelar libera os botões")

	print("RESULT fails=%d" % _fails)
	quit(_fails)
