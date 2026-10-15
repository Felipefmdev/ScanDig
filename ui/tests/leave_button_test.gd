# Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://ui/tests/leave_button_test.gd
# Host sozinho na porta 7793. Grava o save: faça backup.
extends SceneTree

const PORT: int = 7793

var _fails: int = 0
var _ready_pairs: Array[String] = []

func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_fails += 1

func _wait(frames: int) -> void:
	for i in range(frames):
		await process_frame

func _wait_until(cond: Callable, timeout_s: float) -> bool:
	var t: float = 0.0
	while not bool(cond.call()):
		if t >= timeout_s:
			return false
		await create_timer(0.1).timeout
		t += 0.1
	return true

## current_scene pode ser null durante a troca de cena.
func _scene_name() -> String:
	return String(current_scene.name) if current_scene != null else "null"

## O MultiplayerMenu é recriado a cada lobby: sempre busca o atual.
func _menu() -> MultiplayerMenu:
	if current_scene == null:
		return null
	return current_scene.get_node_or_null("UILayer/MultiplayerMenu") as MultiplayerMenu

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
	# Save isolado: nada deste teste toca o user://scandig_save.json do jogador.
	SaveManager.instance.use_test_save_dir("leave_button_test")
	await _wait(10)
	var gs: GameState = GameState.instance
	var sm: SessionManager = SessionManager.instance
	var net: NetworkManager = NetworkManager.instance
	var sui: SessionUI = SessionUI.instance
	_check(gs != null and sm != null and net != null and sui != null, "autoloads presentes")
	sm.peer_scene_ready.connect(func(peer_id: int, map_id: String) -> void: _ready_pairs.append("%d:%s" % [peer_id, map_id]))
	var menu: MultiplayerMenu = _menu()
	_check(menu != null and menu.leave_button != null, "MultiplayerMenu com LeaveButton")
	var bar_leave: Button = sui.leave_button

	# 1. Lobby offline.
	_check(not menu.leave_button.visible, "offline: sair do menu oculto")
	_check(not menu.host_button.disabled, "offline: host habilitado")
	_check(not bar_leave.visible, "offline: sair da barra oculto")
	_check(not sui.leave_confirm_panel.visible, "offline: confirmação oculta")

	# 2. Host.
	var err: Error = await _host(net)
	_check(err == OK, "host_game(%d)=%d" % [PORT, err])
	menu._refresh_session_buttons()
	_check(menu.leave_button.visible, "host: sair do menu visível")
	_check(menu.host_button.disabled and menu.join_button.disabled, "host: host/join desabilitados")
	_check(not menu.ip_line_edit.editable, "host: IP bloqueado")

	# 3. Saída no lobby.
	menu.leave_button.pressed.emit()
	await _wait(5)
	_check(menu.status_label.text == "Você encerrou a sessão (host).", "lobby: status '%s'" % menu.status_label.text)
	_check(not menu.leave_button.visible, "lobby: sair oculto após sair")
	_check(not menu.host_button.disabled, "lobby: host habilitado de novo")
	_check(_scene_name() == "LobbyBase", "lobby: continua no lobby: %s" % _scene_name())

	# 4. Expedição online.
	err = await _host(net)
	_check(err == OK, "host_game(%d) de novo=%d" % [PORT, err])
	sm.request_start_expedition("praia")
	var ready: bool = await _wait_until(func() -> bool: return _ready_pairs.has("1:praia"), 10.0)
	_check(ready, "peer_scene_ready(1, praia)")
	await _wait_until(func() -> bool: return sui.expedition_bar.visible, 3.0)
	_check(sui.expedition_bar.visible, "expedição: barra visível")
	_check(bar_leave.visible and not bar_leave.disabled, "expedição: sair da barra visível")

	# 5. Cancelar.
	bar_leave.pressed.emit()
	_check(sui.leave_confirm_panel.visible, "confirmação aberta")
	_check(sui.leave_confirm_label.text.begins_with("Você é o host"), "texto do host: %s" % sui.leave_confirm_label.text)
	sui.leave_cancel_button.pressed.emit()
	await _wait(3)
	_check(not sui.leave_confirm_panel.visible, "cancelar fecha a confirmação")
	_check(_scene_name() == "MapPraia", "cancelar mantém o mapa: %s" % _scene_name())

	# 6. Sair.
	var day_before: int = gs.current_day
	bar_leave.pressed.emit()
	sui.leave_confirm_button.pressed.emit()
	var back: bool = await _wait_until(func() -> bool: return _scene_name() == "LobbyBase" and not sm.is_in_expedition(), 5.0)
	_check(back, "saiu para o lobby: %s" % _scene_name())
	await _wait(10)
	_check(not sui.host_lost_panel.visible, "sair: host_lost oculto")
	_check(not sui.summary_panel.visible, "sair: resumo oculto")
	_check(not sui.expedition_bar.visible, "sair: barra oculta")
	_check(not sui.leave_confirm_panel.visible, "sair: confirmação oculta")
	_check(gs.current_day == day_before, "sair: dia não avançou: %d -> %d" % [day_before, gs.current_day])
	var new_menu: MultiplayerMenu = _menu()
	_check(new_menu != null and not new_menu.leave_button.visible, "novo lobby: sair do menu oculto")
	_check(new_menu != null and not new_menu.host_button.disabled, "novo lobby: host habilitado")

	# 7. Solo.
	_ready_pairs.clear()
	sm.request_start_expedition("praia")
	await _wait_until(func() -> bool: return _scene_name() == "MapPraia" and sui.expedition_bar.visible, 10.0)
	_check(sui.expedition_bar.visible, "solo: barra visível")
	_check(not bar_leave.visible, "solo: sair da barra oculto")
	_check(sui.return_button.visible, "solo: voltar à base visível")
	sm.request_end_expedition()
	var solo_back: bool = await _wait_until(func() -> bool: return _scene_name() == "LobbyBase" and not sm.is_in_expedition(), 5.0)
	_check(solo_back, "solo: voltou ao lobby: %s" % _scene_name())

	gs.reset_state()
	print("RESULT fails=%d" % _fails)
	quit(_fails)
