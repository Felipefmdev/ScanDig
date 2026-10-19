extends GutTest

## Menus navegáveis por comando e teclado (#102): foco inicial, ui_down/ui_accept movem e
## apertam, ui_cancel (B/Esc) volta uma camada por vez, LB/RB trocam de aba. Título, pausa,
## configurações (cada aba), vitória/créditos, base e menu coop.

const TITLE_SCENE: PackedScene = preload("res://world/title_screen.tscn")
const BASE_SCENE: PackedScene = preload("res://ui/base_station_ui.tscn")
const MENU_SCENE: PackedScene = preload("res://ui/multiplayer_menu.tscn")
const DIR: String = "user://test_saves/devb_gamepad_menus"

var _orig_path: String = ""


func before_all() -> void:
	_orig_path = SaveManager.instance.save_path


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for file_name: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute("%s/%s" % [DIR, file_name])
	SaveManager.instance.set_save_path(DIR + "/scandig_save.json")
	SessionManager.launch_mode = ""


func after_each() -> void:
	if PauseMenu.instance != null:
		PauseMenu.instance.close()
	if VictoryScreen.instance != null:
		VictoryScreen.instance.close()
	if GameState.instance != null:
		GameState.instance.reset_state()
	SessionManager.launch_mode = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if InputDevice.instance != null:
		InputDevice.instance.set_using_gamepad(false)


func after_all() -> void:
	SaveManager.instance.set_save_path(_orig_path)


func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()


## Ação de menu (pressionar e soltar) pelo viewport, como o comando/teclado faria.
func _action(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var ev: InputEventAction = InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		get_viewport().push_input(ev)
	await get_tree().process_frame


func _joy(button: JoyButton) -> void:
	var ev: InputEventJoypadButton = InputEventJoypadButton.new()
	ev.button_index = button
	ev.pressed = true
	get_viewport().push_input(ev)
	await get_tree().process_frame


func test_ui_actions_have_pad_buttons() -> void:
	var accept: bool = false
	for ev: InputEvent in InputMap.action_get_events(&"ui_accept"):
		accept = accept or (ev is InputEventJoypadButton and (ev as InputEventJoypadButton).button_index == JOY_BUTTON_A)
	assert_true(accept, "A confirma nos menus")


func test_title_navigation() -> void:
	var title: TitleScreen = TITLE_SCENE.instantiate() as TitleScreen
	title.auto_skip = false
	title.scene_change_enabled = false
	add_child_autofree(title)
	await get_tree().process_frame
	assert_eq(_focus(), title.new_game_button, "sem save: foco em Novo jogo")
	await _action(&"ui_down")
	assert_eq(_focus(), title.load_button, "ui_down desce")
	await _action(&"ui_accept")
	assert_true(title.slots_panel.visible, "ui_accept aperta Carregar")
	assert_true(title.slots_panel.is_ancestor_of(_focus()), "foco no seletor de slots")
	await _action(&"ui_cancel")
	assert_true(title.main_card.visible and not title.slots_panel.visible, "B volta ao cartão")
	title.settings_button.grab_focus()
	await _action(&"ui_accept")
	assert_true(title.settings_menu.visible)
	assert_true(title.settings_menu.is_ancestor_of(_focus()), "Configurações: foco no primeiro controle")
	await _action(&"ui_cancel")
	assert_true(title.main_card.visible, "B sai das configurações")


func test_pause_navigation_one_layer_at_a_time() -> void:
	var pause: PauseMenu = PauseMenu.instance
	assert_true(pause.open())
	assert_eq(_focus(), pause.continue_button, "abre com foco em Continuar")
	await _action(&"ui_down")
	assert_eq(_focus(), pause.settings_button)
	await _action(&"ui_accept")
	assert_true(pause.settings_menu.visible, "A entra nas Configurações")
	assert_true(pause.settings_menu.is_ancestor_of(_focus()), "foco na aba Vídeo")
	await _action(&"ui_cancel")
	assert_true(pause.card.visible and PauseMenu.is_open(), "B volta ao cartão (não fecha)")
	assert_eq(_focus(), pause.continue_button)
	pause.quit_button.grab_focus()
	await _action(&"ui_accept")
	assert_true(pause.quit_panel.visible)
	assert_eq(_focus(), pause.quit_no_button, "confirmação foca o Cancelar")
	await _action(&"ui_cancel")
	assert_true(pause.card.visible and PauseMenu.is_open())
	await _action(&"ui_cancel")
	assert_false(PauseMenu.is_open(), "B no cartão fecha")


func test_settings_tabs_with_shoulders() -> void:
	var pause: PauseMenu = PauseMenu.instance
	assert_true(pause.open())
	pause.settings_button.pressed.emit()
	var settings: SettingsMenu = pause.settings_menu
	assert_eq(settings.tabs.current_tab, SettingsMenu.TAB_VIDEO)
	for expected: int in [SettingsMenu.TAB_AUDIO, SettingsMenu.TAB_CONTROLS, SettingsMenu.TAB_GAMEPLAY, SettingsMenu.TAB_VIDEO]:
		await _joy(JOY_BUTTON_RIGHT_SHOULDER)
		assert_eq(settings.tabs.current_tab, expected, "RB vai para a aba %d" % expected)
		var page: Control = settings.tabs.get_current_tab_control()
		assert_true(page.is_ancestor_of(_focus()), "aba %d: foco no primeiro controle (%s)" % [expected, _focus()])
	await _joy(JOY_BUTTON_LEFT_SHOULDER)
	assert_eq(settings.tabs.current_tab, SettingsMenu.TAB_GAMEPLAY, "LB volta")
	var first: Control = _focus()
	await _action(&"ui_down")
	assert_ne(_focus(), first, "ui_down anda dentro da aba")
	assert_eq(settings.window_mode_option.focus_mode, Control.FOCUS_ALL, "controles focáveis")
	assert_eq((settings.control_buttons["jump"] as Button).focus_mode, Control.FOCUS_ALL)


func test_victory_and_credits() -> void:
	GameState.instance._host_report_boss_defeated("gold_colossus")
	var screen: VictoryScreen = VictoryScreen.instance
	assert_true(VictoryScreen.is_open())
	assert_eq(_focus(), screen.continue_button, "abre com foco em Continuar explorando")
	await _action(&"ui_down")
	assert_eq(_focus(), screen.credits_button)
	await _action(&"ui_accept")
	assert_true(screen.credits_view.visible)
	assert_eq(_focus(), screen.credits_back_button, "créditos: foco em Voltar")
	var cancel: InputEventAction = InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	screen._unhandled_input(cancel)
	assert_true(screen.summary_view.visible and VictoryScreen.is_open(), "B volta às contagens")
	screen._unhandled_input(cancel)
	assert_false(VictoryScreen.is_open(), "B de novo fecha")


func test_base_station_focus_and_tabs() -> void:
	# Com saldo: sem ele os Comprar ficam desativados e saem da navegação (#135, foco na barra).
	GameState.instance.team_money = 5000
	var base: BaseStationUI = BASE_SCENE.instantiate() as BaseStationUI
	add_child_autofree(base)
	await get_tree().process_frame
	await get_tree().process_frame
	var page: Control = base.tab_container.get_current_tab_control()
	assert_true(page.is_ancestor_of(_focus()), "base abre com foco na aba atual (%s)" % _focus())
	var tab: int = base.tab_container.current_tab
	await _joy(JOY_BUTTON_RIGHT_SHOULDER)
	assert_ne(base.tab_container.current_tab, tab, "RB troca de aba")
	assert_true(base.tab_container.get_current_tab_control().is_ancestor_of(_focus()), "foco na aba nova")


func test_coop_menu_focus() -> void:
	SessionManager.launch_mode = SessionManager.LAUNCH_COOP
	var menu: MultiplayerMenu = MENU_SCENE.instantiate() as MultiplayerMenu
	add_child_autofree(menu)
	await get_tree().process_frame
	assert_eq(_focus(), menu.host_online_button, "coop: foco em Criar sala online")
	await _action(&"ui_down")
	assert_ne(_focus(), menu.host_online_button, "ui_down anda no menu de rede")
