# Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://ui/tests/pause_menu_test.gd
## #77: PauseMenu (autoload CorePauseMenu) e SettingsMenu. Solo pausa a árvore, coop (porta 7803)
## não; não abre com carregamento ou resumo; botões por papel; Configurações aplica no
## SettingsManager (arquivo do teste em user://test_saves/); resolução pede confirmação.
extends SceneTree

const SETTINGS_PATH: String = "user://test_saves/pause_menu_test.cfg"
const PORT: int = 7803

var _fails: int = 0
var _open_signals: Array[bool] = []


func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_fails += 1


func _wait(frames: int) -> void:
	for i in range(frames):
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


func _finish() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
	if SettingsManager.instance != null:
		SettingsManager.instance.settings_path = SettingsManager.DEFAULT_PATH
	print("RESULT fails=%d" % _fails)
	quit(_fails)


func _run() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	SaveManager.instance.use_test_save_dir("pause_menu_test")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://test_saves"))
	await _wait(10)
	var menu: PauseMenu = PauseMenu.instance
	var ui: SessionUI = SessionUI.instance
	var sm: SettingsManager = SettingsManager.instance
	_check(menu != null and ui != null and sm != null, "PauseMenu, SessionUI e SettingsManager presentes")
	if menu == null or ui == null or sm == null:
		_finish()
		return
	sm.settings_path = SETTINGS_PATH
	menu.open_changed.connect(func(open: bool) -> void: _open_signals.append(open))
	_check(not PauseMenu.is_open() and not menu.root_control.visible, "começa fechado")
	_check(menu.layer > 1 and menu.layer < ui.layer, "camada acima do HUD e abaixo do SessionUI: %d" % menu.layer)

	# 1. Solo: pausa a árvore e solta o mouse; fechar despausa.
	_check(menu.open() and PauseMenu.is_open() and menu.root_control.visible, "solo: abre")
	_check(paused, "solo: árvore pausada")
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "solo: mouse visível")
	_check(not menu.return_button.visible and not menu.leave_button.visible, "lobby offline: sem voltar à base nem sair da sessão")
	_check(menu.continue_button.visible and menu.settings_button.visible and menu.quit_button.visible, "continuar, configurações e sair do jogo visíveis")
	menu.continue_button.pressed.emit()
	_check(not PauseMenu.is_open() and not paused, "continuar fecha e despausa")
	_check(_open_signals == [true, false], "open_changed: %s" % str(_open_signals))

	# 2. Não abre com carregamento ou resumo do dia.
	ui.loading_screen.visible = true
	_check(not menu.open() and not PauseMenu.is_open(), "não abre no carregamento")
	ui.loading_screen.visible = false
	ui.summary_panel.visible = true
	_check(not menu.open(), "não abre com o resumo do dia")
	ui.summary_panel.visible = false

	# 3. Host em expedição: voltar à base aparece.
	var session: Node = root.get_node(^"CoreSession")
	session.set("_current_map", load("res://items/maps/praia.tres"))
	menu.open()
	_check(menu.return_button.visible, "host em expedição: voltar à base visível")
	_check(not ui.expedition_bar.visible, "cartão da expedição escondido com o menu aberto")
	menu.close()
	_check(ui.expedition_bar.visible, "cartão da expedição volta ao fechar")
	session.set("_current_map", null)

	# 4. Configurações: áudio aplica e grava; resolução pede confirmação e volta.
	menu.open()
	menu.settings_button.pressed.emit()
	var settings: SettingsMenu = menu.settings_menu
	_check(settings.visible and not menu.card.visible, "configurações abertas no lugar do cartão")
	_check(settings.tabs.get_tab_count() == 4 and settings.tabs.is_tab_disabled(2) and settings.tabs.is_tab_disabled(3), "abas: Vídeo, Áudio e Controles/Jogabilidade desativadas")
	(settings.audio_sliders["master"] as HSlider).value = 40.0
	(settings.audio_sliders["music"] as HSlider).value = 0.0
	settings.apply_button.pressed.emit()
	_check(is_equal_approx(float(sm.get_value(SettingsManager.AUDIO, "master")), 0.4), "master 40 %% aplicado: %s" % str(sm.get_value(SettingsManager.AUDIO, "master")))
	_check((settings.audio_values["music"] as Label).text == "Mudo", "música em 0 mostra Mudo")
	var cfg: ConfigFile = ConfigFile.new()
	_check(cfg.load(SETTINGS_PATH) == OK and is_equal_approx(float(cfg.get_value("audio", "master", 0.0)), 0.4), "áudio gravado no arquivo do teste")
	var before_res: Vector2i = sm.get_value(SettingsManager.VIDEO, "resolution")
	var other: int = 0 if settings._resolutions[0] != before_res else 1
	settings.resolution_option.select(other)
	settings.apply_button.pressed.emit()
	_check(settings.confirm_panel.visible and not settings.tabs.visible and sm.is_video_trial_active(), "resolução nova: pede confirmação")
	settings.revert_button.pressed.emit()
	await _wait(2)
	_check(not sm.is_video_trial_active() and sm.get_value(SettingsManager.VIDEO, "resolution") == before_res and not settings.confirm_panel.visible, "voltar ao anterior restaura a resolução")
	settings.back_button.pressed.emit()
	_check(menu.card.visible and not settings.visible, "voltar das configurações mostra o cartão")

	# 5. Sair do jogo pede confirmação (não clica em Sair).
	menu.quit_button.pressed.emit()
	_check(menu.quit_panel.visible and not menu.card.visible, "sair do jogo pede confirmação")
	menu.quit_no_button.pressed.emit()
	_check(menu.card.visible and not menu.quit_panel.visible, "cancelar volta ao cartão")
	menu.close()

	# 6. Coop (host online): não pausa; sair da sessão aparece.
	var net: NetworkManager = NetworkManager.instance
	_check(net.host_game(PORT) == OK, "host_game na porta %d" % PORT)
	await _wait(3)
	_check(menu.open() and not paused, "coop: abre sem pausar")
	_check(menu.leave_button.visible, "coop: sair da sessão visível")
	menu.close()
	_check(not PauseMenu.is_open() and not paused, "coop: fecha")
	net.disconnect_game()
	await _wait(3)

	_finish()
