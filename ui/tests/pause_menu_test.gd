# Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://ui/tests/pause_menu_test.gd
## #77: PauseMenu (autoload CorePauseMenu) e SettingsMenu. Solo pausa a árvore, coop (porta 7803)
## não; não abre com carregamento ou resumo; botões por papel; Configurações aplica no
## SettingsManager (arquivo do teste em user://test_saves/); resolução pede confirmação.
## Etapa 3: Esc (ação "pause") abre e fecha; aba Jogabilidade; em coop o player fica parado com o
## menu aberto e anda ao fechar; inverter Y. Acabamento: aviso "Configurações salvas" na frente do
## menu, "Descartar alterações?" ao voltar com mudanças, caixas Ligado/Desligado.
## #100: "Sair para o menu principal" (confirmação por caso; na base salva, em expedição não,
## em coop sai da sessão) leva à tela inicial, que no --script é pulada para a base.
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
	var dim: ColorRect = menu.root_control.get_node(^"Dim") as ColorRect
	_check(dim != null and dim.mouse_filter == Control.MOUSE_FILTER_STOP and dim.color.a >= 0.5, "fundo escurecido de tela cheia que segura o mouse")

	# 1. Solo: pausa a árvore e solta o mouse; fechar despausa.
	_check(menu.open() and PauseMenu.is_open() and menu.root_control.visible, "solo: abre")
	_check(paused, "solo: árvore pausada")
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "solo: mouse visível")
	_check(not menu.return_button.visible and not menu.leave_button.visible, "lobby offline: sem voltar à base nem sair da sessão")
	_check(menu.continue_button.visible and menu.settings_button.visible and menu.quit_button.visible, "continuar, configurações e sair do jogo visíveis")
	_check(menu.main_menu_button.visible and menu.main_menu_button.get_index() == menu.quit_button.get_index() - 1, "sair para o menu principal logo antes de sair do jogo")
	menu.continue_button.pressed.emit()
	_check(not PauseMenu.is_open() and not paused, "continuar fecha e despausa")
	_check(_open_signals == [true, false], "open_changed: %s" % str(_open_signals))

	# 1b. Esc (ação "pause"): abre; nas Configurações volta ao cartão; de novo fecha.
	await _press(KEY_ESCAPE)
	_check(PauseMenu.is_open() and paused, "Esc abre o menu (solo pausa)")
	menu.settings_button.pressed.emit()
	await _press(KEY_ESCAPE)
	_check(PauseMenu.is_open() and menu.card.visible and not menu.settings_menu.visible, "Esc nas Configurações volta ao cartão")
	menu.quit_button.pressed.emit()
	await _press(KEY_ESCAPE)
	_check(PauseMenu.is_open() and menu.card.visible and not menu.quit_panel.visible, "Esc na confirmação de saída volta ao cartão")
	await _press(KEY_ESCAPE)
	_check(not PauseMenu.is_open() and not paused, "Esc no cartão fecha e despausa")

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
	menu.main_menu_button.pressed.emit()
	_check(menu.quit_panel.visible and menu.quit_label.text == PauseMenu.MAIN_MENU_EXPEDITION_TEXT, "menu principal em expedição avisa que não salva")
	menu.quit_no_button.pressed.emit()
	menu.close()
	_check(ui.expedition_bar.visible, "cartão da expedição volta ao fechar")
	session.set("_current_map", null)

	# 4. Configurações: áudio aplica e grava; resolução pede confirmação e volta.
	menu.open()
	menu.settings_button.pressed.emit()
	var settings: SettingsMenu = menu.settings_menu
	_check(settings.visible and not menu.card.visible, "configurações abertas no lugar do cartão")
	_check(settings.tabs.get_tab_count() == 4 and not settings.tabs.is_tab_disabled(2) and not settings.tabs.is_tab_disabled(3), "abas: Vídeo, Áudio, Controles e Jogabilidade, todas ativas")
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
	await _check_controls(settings, sm)
	await _check_gameplay(settings, sm, menu)
	settings.back_button.pressed.emit()
	_check(menu.card.visible and not settings.visible, "voltar das configurações mostra o cartão")
	await _check_apply_and_discard(menu, sm)

	# 5. Sair do jogo pede confirmação (não clica em Sair).
	menu.quit_button.pressed.emit()
	_check(menu.quit_panel.visible and not menu.card.visible, "sair do jogo pede confirmação")
	menu.quit_no_button.pressed.emit()
	_check(menu.card.visible and not menu.quit_panel.visible, "cancelar volta ao cartão")
	menu.main_menu_button.pressed.emit()
	_check(menu.quit_panel.visible and menu.quit_label.text == PauseMenu.MAIN_MENU_BASE_TEXT and menu.quit_yes_button.text == "Ir para o menu", "menu principal na base: salva agora")
	menu.quit_no_button.pressed.emit()
	menu.quit_button.pressed.emit()
	_check(menu.quit_label.text == PauseMenu.QUIT_TEXT and menu.quit_yes_button.text == "Sair", "sair do jogo volta ao próprio texto")
	menu.quit_no_button.pressed.emit()
	menu.close()

	# 6. Coop (host online): não pausa; sair da sessão aparece.
	var net: NetworkManager = NetworkManager.instance
	_check(net.host_game(PORT) == OK, "host_game na porta %d" % PORT)
	await _wait(3)
	_check(menu.open() and not paused, "coop: abre sem pausar")
	_check(menu.leave_button.visible, "coop: sair da sessão visível")
	menu.main_menu_button.pressed.emit()
	_check(menu.quit_label.text == PauseMenu.MAIN_MENU_COOP_TEXT, "coop: menu principal sai da sessão")
	menu.quit_no_button.pressed.emit()
	menu.close()
	_check(not PauseMenu.is_open() and not paused, "coop: fecha")
	await _check_player(menu, sm)
	net.disconnect_game()
	await _wait(3)
	await _check_main_menu(menu)

	_finish()


## #100: confirmar "Sair para o menu principal". A tela inicial é pulada no --script, então
## volta-se à base: sem expedição, despausado, launch_mode limpo; na base o save é gravado.
func _check_main_menu(menu: PauseMenu) -> void:
	var save: SaveManager = SaveManager.instance
	var session: SessionManager = SessionManager.instance
	if save.has_save_file():
		save.delete_save_file()
	session.set("_current_map", load("res://items/maps/praia.tres"))
	SessionManager.launch_mode = SessionManager.LAUNCH_SOLO
	menu.open()
	menu.main_menu_button.pressed.emit()
	menu.quit_yes_button.pressed.emit()
	await _wait(10)
	_check(not PauseMenu.is_open() and not paused, "menu principal: pausa fechada e despausada")
	_check(not session.is_in_expedition() and SessionManager.launch_mode == "", "expedição e launch_mode limpos")
	_check(current_scene != null and current_scene.name == "LobbyBase", "título pulado no --script: base (%s)" % (current_scene.name if current_scene != null else "null"))
	_check(not save.has_save_file(), "em expedição não salva")
	menu.open()
	menu.main_menu_button.pressed.emit()
	menu.quit_yes_button.pressed.emit()
	await _wait(10)
	_check(save.has_save_file(), "na base salva antes de ir ao menu")
	_check(current_scene != null and current_scene.name == "LobbyBase", "de novo na base")


func _press(code: Key) -> void:
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = true
	root.push_input(ev)
	await _wait(1)


## Etapa 2: capturar tecla na aba Controles (Esc cancela, conflito pergunta, padrão restaura).
func _check_controls(settings: SettingsMenu, sm: SettingsManager) -> void:
	settings.tabs.current_tab = SettingsMenu.TAB_CONTROLS
	await _wait(2)
	var jump: Button = settings.control_buttons["jump"]
	_check(jump.text == "Espaço", "pular mostra Espaço: %s" % jump.text)
	jump.pressed.emit()
	_check(settings.capturing == "jump" and jump.text == SettingsMenu.CAPTURE_TEXT, "clicar espera a tecla")
	await _press(KEY_K)
	_check(settings.capturing == "" and sm.get_binding("jump") == {"type": "key", "code": KEY_K} and jump.text == "K", "pular → K: %s" % jump.text)
	(settings.control_buttons["drop"] as Button).pressed.emit()
	await _press(KEY_ESCAPE)
	_check(settings.capturing == "" and sm.get_binding("drop") == {"type": "key", "code": KEY_Q}, "Esc cancela a captura")
	(settings.control_buttons["interact"] as Button).pressed.emit()
	await _press(KEY_K)
	_check(settings.conflict_panel.visible and settings.conflict_label.text.contains("Pular"), "conflito avisa: %s" % settings.conflict_label.text)
	settings.swap_button.pressed.emit()
	_check(sm.get_binding("interact") == {"type": "key", "code": KEY_K} and sm.get_binding("jump") == {"type": "key", "code": KEY_E}, "trocar: interagir K, pular E")
	_check(not settings.conflict_panel.visible and settings.tabs.visible, "conflito fechado")
	settings.defaults_button.pressed.emit()
	_check(sm.get_binding("jump") == {"type": "key", "code": KEY_SPACE} and jump.text == "Espaço", "restaurar padrão nos controles")
	settings.tabs.current_tab = SettingsMenu.TAB_VIDEO


## Etapa 3: aba Jogabilidade aplica e grava no [gameplay]; FPS aparece; padrão restaura.
func _check_gameplay(settings: SettingsMenu, sm: SettingsManager, menu: PauseMenu) -> void:
	settings.tabs.current_tab = SettingsMenu.TAB_GAMEPLAY
	await _wait(2)
	_check(is_equal_approx(settings.sensitivity_slider.value, 100.0) and is_equal_approx(settings.fov_slider.value, 75.0) and settings.bobbing_check.button_pressed and not settings.invert_y_check.button_pressed, "Jogabilidade mostra os padrões")
	_check(settings.language_option.disabled and settings.language_option.get_item_text(0) == "Português (Brasil)", "idioma: só português, desativado")
	settings.sensitivity_slider.value = 160.0
	settings.fov_slider.value = 90.0
	settings.invert_y_check.button_pressed = true
	settings.bobbing_check.button_pressed = false
	settings.show_fps_check.button_pressed = true
	settings.hud_text_slider.value = 120.0
	_check(is_equal_approx(float(sm.get_value(SettingsManager.GAMEPLAY, "fov")), 75.0), "pendente até Aplicar")
	settings.apply_button.pressed.emit()
	var g: Dictionary = sm.get_section(SettingsManager.GAMEPLAY)
	_check(is_equal_approx(float(g["mouse_sensitivity"]), 0.004) and is_equal_approx(float(g["fov"]), 90.0) and g["invert_y"] == true and g["view_bobbing"] == false and g["show_fps"] == true and is_equal_approx(float(g["hud_text_scale"]), 1.2), "aplicado: %s" % str(g))
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	_check(is_equal_approx(float(cfg.get_value("gameplay", "fov", 0.0)), 90.0) and cfg.get_value("gameplay", "invert_y", false) == true, "gravado em [gameplay]")
	_check(menu.fps_label.visible, "mostrar FPS liga o contador")
	settings.defaults_button.pressed.emit()
	_check(sm.get_section(SettingsManager.GAMEPLAY) == SettingsManager.DEFAULTS[SettingsManager.GAMEPLAY] and not menu.fps_label.visible and is_equal_approx(settings.fov_slider.value, 75.0), "restaurar padrão na Jogabilidade")
	settings.tabs.current_tab = SettingsMenu.TAB_VIDEO


## Coop: com o menu aberto o player local não anda nem pula (a física segue); ao fechar, anda.
## Inverter Y e tamanho do texto do HUD chegam ao player pelo CoreSettings.
func _check_player(menu: PauseMenu, sm: SettingsManager) -> void:
	# O lobby não tem player (nasce nos mapas): um player do host num chão longe da base.
	var arena: Node3D = Node3D.new()
	arena.position = Vector3(0.0, -500.0, 0.0)
	current_scene.add_child(arena)
	var floor_body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(200.0, 1.0, 200.0)
	shape.shape = box
	floor_body.add_child(shape)
	arena.add_child(floor_body)
	var player: Player = (load("res://gameplay/player/player.tscn") as PackedScene).instantiate() as Player
	player.name = str(root.multiplayer.get_unique_id())
	player.position = Vector3(0.0, 1.0, 0.0)
	arena.add_child(player)
	await _wait(5)
	_check(player.is_local() and player.is_in_group(Player.LOCAL_GROUP), "player local do host")
	for i in range(20):
		await physics_frame
	_check(menu.open() and not paused, "coop: menu aberto, árvore rodando")
	player.velocity = Vector3.ZERO
	Input.action_press("move_forward")
	Input.action_press("jump")
	for i in range(15):
		await physics_frame
	var flat: Vector3 = Vector3(player.velocity.x, 0.0, player.velocity.z)
	_check(flat.length() < 0.05, "menu aberto: player parado (vel %.2f)" % flat.length())
	_check(player.velocity.y <= 0.01, "menu aberto: não pula (vel.y %.2f)" % player.velocity.y)
	Input.action_release("jump")
	menu.close()
	for i in range(15):
		await physics_frame
	flat = Vector3(player.velocity.x, 0.0, player.velocity.z)
	_check(flat.length() > 0.5, "menu fechado: player anda (vel %.2f)" % flat.length())
	Input.action_release("move_forward")

	# Inverter Y.
	sm.set_section(SettingsManager.GAMEPLAY, {"invert_y": false})
	player.head.rotation.x = 0.0
	player.apply_mouse_look(Vector2(0.0, 10.0))
	var normal: float = player.head.rotation.x
	sm.set_section(SettingsManager.GAMEPLAY, {"invert_y": true})
	_check(player.invert_y, "inverter Y chega ao player")
	player.head.rotation.x = 0.0
	player.apply_mouse_look(Vector2(0.0, 10.0))
	_check(normal < 0.0 and is_equal_approx(player.head.rotation.x, -normal), "inverter Y: %.4f vira %.4f" % [normal, player.head.rotation.x])

	# Tamanho do texto do HUD (inclusive texto criado depois).
	var label: Label = player.get_node(^"HUD/SessionInfoLabel") as Label
	var base: int = label.get_theme_font_size(&"font_size")
	sm.set_section(SettingsManager.GAMEPLAY, {"hud_text_scale": 1.5})
	_check(label.get_theme_font_size(&"font_size") == roundi(base * 1.5), "HUD 150 %%: %d → %d" % [base, label.get_theme_font_size(&"font_size")])
	var late: Label = Label.new()
	player.get_node(^"HUD").add_child(late)
	var late_base: int = late.get_theme_font_size(&"font_size")
	await _wait(2)
	_check(late.get_theme_font_size(&"font_size") == roundi(late_base * 1.5), "texto novo no HUD também escala: %d" % late.get_theme_font_size(&"font_size"))
	sm.restore_defaults(SettingsManager.GAMEPLAY)
	_check(label.get_theme_font_size(&"font_size") == base and not player.invert_y, "padrão volta o HUD e o eixo Y")
	arena.queue_free()


## Acabamento: aviso ao aplicar, pergunta ao voltar com mudanças, texto das caixas de marcar.
func _check_apply_and_discard(menu: PauseMenu, sm: SettingsManager) -> void:
	menu.settings_button.pressed.emit()
	var settings: SettingsMenu = menu.settings_menu
	await _wait(2)
	_check(not settings.has_pending_changes(), "sem mudanças ao abrir")

	# Caixas de marcar: o texto segue o estado.
	_check(settings.invert_y_check.text == "Desligado" and settings.bobbing_check.text == "Ligado" and settings.show_fps_check.text == "Desligado", "caixas: Desligado/Ligado conforme o estado")
	var vsync_on: bool = settings.vsync_check.button_pressed
	_check(settings.vsync_check.text == ("Ligado" if vsync_on else "Desligado"), "VSync mostra o estado: %s" % settings.vsync_check.text)
	settings.vsync_check.button_pressed = not vsync_on
	_check(settings.vsync_check.text == ("Desligado" if vsync_on else "Ligado"), "VSync troca o texto ao marcar")
	settings.vsync_check.button_pressed = vsync_on

	# Aplicar mostra "Configurações salvas" na frente do menu e some sozinho.
	settings.tabs.current_tab = SettingsMenu.TAB_AUDIO
	(settings.audio_sliders["sfx"] as HSlider).value = 70.0
	_check(settings.has_pending_changes(), "mudança pendente detectada")
	settings.apply_button.pressed.emit()
	await _wait(2)
	var notice: PanelContainer = settings.saved_notice
	var notice_rect: Rect2 = notice.get_global_rect()
	_check(notice.visible and notice.top_level and notice.modulate.a > 0.9, "aviso de salvo visível")
	_check((notice.get_child(0) as Label).text == "Configurações salvas", "texto do aviso")
	_check(settings.get_global_rect().encloses(notice_rect) and notice_rect.end.y <= settings.buttons_row.global_position.y, "aviso dentro do painel, acima dos botões: %s painel %s botões %s" % [str(notice_rect), str(settings.get_global_rect()), str(settings.buttons_row.get_global_rect())])
	_check(notice.get_index() == settings.get_child_count() - 1, "aviso desenhado por último (na frente)")
	_check(not settings.has_pending_changes() and is_equal_approx(float(sm.get_value(SettingsManager.AUDIO, "sfx")), 0.7), "aplicado e sem pendência")
	await create_timer(SettingsMenu.SAVED_SECONDS + 0.4, true, false, true).timeout
	_check(not notice.visible, "aviso some em ~2 s")

	# Voltar com mudança pendente pergunta; Cancelar mantém; Descartar volta ao valor salvo.
	settings.tabs.current_tab = SettingsMenu.TAB_GAMEPLAY
	settings.fov_slider.value = 95.0
	settings.back_button.pressed.emit()
	_check(settings.visible and settings.discard_panel.visible and not settings.tabs.visible and not settings.buttons_row.visible, "voltar com mudança pergunta 'Descartar alterações?'")
	settings.discard_cancel_button.pressed.emit()
	_check(not settings.discard_panel.visible and settings.tabs.visible and settings.buttons_row.visible and is_equal_approx(settings.fov_slider.value, 95.0), "cancelar mantém a mudança na tela")
	settings.show_saved_notice()
	settings.back_button.pressed.emit()
	_check(not settings.saved_notice.visible, "a pergunta esconde o aviso de salvo")
	settings.discard_button.pressed.emit()
	_check(menu.card.visible and not settings.visible and is_equal_approx(float(sm.get_value(SettingsManager.GAMEPLAY, "fov")), 75.0), "descartar volta ao cartão sem aplicar")
	_check(is_equal_approx(settings.fov_slider.value, 75.0) and not settings.has_pending_changes(), "tela volta ao valor salvo")

	# Esc com mudança: pergunta; Esc de novo cancela a pergunta; fechar o menu descarta sem perguntar.
	menu.settings_button.pressed.emit()
	settings.fov_slider.value = 90.0
	await _press(KEY_ESCAPE)
	_check(settings.discard_panel.visible and PauseMenu.is_open(), "Esc com mudança pergunta")
	await _press(KEY_ESCAPE)
	_check(not settings.discard_panel.visible and settings.visible, "Esc de novo cancela a pergunta")
	menu.close()
	_check(not PauseMenu.is_open() and not settings.discard_panel.visible and is_equal_approx(float(sm.get_value(SettingsManager.GAMEPLAY, "fov")), 75.0), "fechar o menu descarta sem perguntar")
	sm.restore_defaults(SettingsManager.AUDIO)
