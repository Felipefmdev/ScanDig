extends GutTest

## Navegação por teclado e comando em todas as telas (#135), com UiNavAudit: foco inicial certo,
## todo controle interativo alcançável só com as setas/Tab (ou o direcional), nenhuma armadilha,
## borda de foco presente e Esc/B voltando ou fechando uma camada.

const TITLE_SCENE: PackedScene = preload("res://world/title_screen.tscn")
const BASE_SCENE: PackedScene = preload("res://ui/base_station_ui.tscn")
const MENU_SCENE: PackedScene = preload("res://ui/multiplayer_menu.tscn")
const DIR: String = "user://test_saves/devb_nav_audit"
const DEVICES: Array[String] = [UiNavAudit.KEYBOARD, UiNavAudit.PAD]

var _orig_path: String = ""


func before_all() -> void:
	_orig_path = SaveManager.instance.save_path


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for file_name: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute("%s/%s" % [DIR, file_name])
	SaveManager.instance.set_save_path(DIR + "/scandig_save.json")
	GameState.instance.reset_state()
	SessionManager.launch_mode = ""


func after_each() -> void:
	if PauseMenu.instance != null:
		PauseMenu.instance.close()
	if VictoryScreen.instance != null:
		VictoryScreen.instance.close()
	if SessionUI.instance != null:
		SessionUI.instance.summary_panel.visible = false
		SessionUI.instance.leave_confirm_panel.visible = false
		SessionUI.instance.host_lost_panel.visible = false
		SessionUI.instance._update_mouse()
	GameState.instance.reset_state()
	SessionManager.launch_mode = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if InputDevice.instance != null:
		InputDevice.instance.set_using_gamepad(false)
		InputDevice.instance.set_using_pointer(true)


func after_all() -> void:
	SaveManager.instance.set_save_path(_orig_path)


func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()


func _frames(count: int = 2) -> void:
	for i: int in count:
		await get_tree().process_frame


func _write_slot(n: int) -> void:
	var data: Dictionary = {"version": SaveManager.SAVE_VERSION, "saved_at": 1750000000, "team_money": 10,
		"current_day": 3, "discovered_items": []}
	var file: FileAccess = FileAccess.open(SaveManager.instance.slot_path(n), FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func _title() -> TitleScreen:
	var title: TitleScreen = TITLE_SCENE.instantiate() as TitleScreen
	title.auto_skip = false
	title.scene_change_enabled = false
	add_child_autofree(title)
	return title


## Audita `root` no teclado e no comando: tudo alcançado, sem armadilhas e com borda de foco.
func _assert_nav(screen: String, root: Control, allow_leave: bool = false) -> void:
	for device: String in DEVICES:
		var r: Dictionary = await UiNavAudit.audit(root, device, allow_leave)
		gut.p("%s [%s]: %s  inicial=%s" % [screen, device, UiNavAudit.score(r), r["initial"]])
		for key: String in ["missing", "traps", "no_focus_style"]:
			for line: Variant in r[key]:
				gut.p("    %s: %s" % [key, line])
		assert_true(r["initial_ok"], "%s [%s]: foco inicial na tela (%s)" % [screen, device, r["initial"]])
		assert_eq(r["missing"], [], "%s [%s]: todos alcançados" % [screen, device])
		assert_eq(r["traps"], [], "%s [%s]: sem armadilhas" % [screen, device])
		assert_eq(r["no_focus_style"], [], "%s [%s]: borda de foco visível" % [screen, device])


func test_title_main_card() -> void:
	_write_slot(1)
	var title: TitleScreen = _title()
	await _frames()
	assert_eq(_focus(), title.continue_button, "com save: foco em Continuar")
	await _assert_nav("título", title.main_card)


func test_title_slots_and_delete() -> void:
	_write_slot(2)
	var title: TitleScreen = _title()
	await _frames()
	for device: String in DEVICES:
		title.show_slots("load")
		await _frames()
		assert_true(title.slots_panel.is_ancestor_of(_focus()), "slots: foco num slot")
		await _assert_nav("slots", title.slots_panel)
		title.slot_delete_buttons[1].grab_focus()
		title.slot_delete_buttons[1].pressed.emit()
		await _frames()
		assert_eq(_focus(), title.confirm_cancel_button, "apagar: foco no Cancelar")
		await _assert_nav("apagar slot", title.confirm_panel)
		var back: Dictionary = await UiNavAudit.check_cancel(title.confirm_panel, device)
		assert_true(back["closed"] and title.slots_panel.visible, "%s: Esc/B fecha a confirmação" % device)
		assert_true(title.slots_panel.is_ancestor_of(_focus()), "%s: foco volta aos slots" % device)
		back = await UiNavAudit.check_cancel(title.slots_panel, device)
		assert_true(back["closed"] and title.main_card.visible, "%s: Esc/B volta ao cartão" % device)
		assert_true(title.main_card.is_ancestor_of(_focus()), "%s: foco volta ao cartão" % device)


## Cards novos (#139) com o botão "Abrir pasta de saves" ligado (no headless ele fica fora).
func test_title_slot_cards_with_save_folder() -> void:
	_write_slot(1)
	_write_slot(3)
	var title: TitleScreen = _title()
	await _frames()
	title.save_folder_enabled = true
	for device: String in DEVICES:
		title.show_slots("load")
		await _frames()
		assert_true(title.slots_panel.is_ancestor_of(_focus()), "slots: foco num slot")
		await _assert_nav("slots com pasta", title.slots_panel)
		var back: Dictionary = await UiNavAudit.check_cancel(title.slots_panel, device)
		assert_true(back["closed"] and title.main_card.visible, "%s: Esc/B volta ao cartão" % device)


func test_title_credits() -> void:
	var title: TitleScreen = _title()
	await _frames()
	title.show_credits()
	await _frames()
	assert_eq(_focus(), title.credits_view.scroll, "créditos: foco na área com rolagem")
	await _assert_nav("créditos do título", title.credits_panel)
	var back: Dictionary = await UiNavAudit.check_cancel(title.credits_panel, UiNavAudit.PAD)
	assert_true(back["closed"] and title.main_card.visible, "B volta ao menu")
	assert_eq(_focus(), title.credits_button)


func test_title_settings_every_tab() -> void:
	var title: TitleScreen = _title()
	await _frames()
	title.show_settings()
	await _frames()
	var settings: SettingsMenu = title.settings_menu
	await _assert_settings_tabs(settings)
	for device: String in DEVICES:
		title.show_settings()
		await _frames()
		var back: Dictionary = await UiNavAudit.check_cancel(settings, device)
		assert_true(back["closed"] and title.main_card.visible, "%s: Esc/B sai das configurações" % device)
		assert_true(title.main_card.is_ancestor_of(_focus()), "%s: foco volta ao cartão" % device)


func _assert_settings_tabs(settings: SettingsMenu) -> void:
	settings.tabs.current_tab = 0
	await _frames(1)
	settings.focus_first()
	for i: int in settings.tabs.get_tab_count():
		if i > 0:
			await UiNavAudit.inject(get_viewport(), &"tab_next", UiNavAudit.PAD)
		await _frames()
		assert_eq(settings.tabs.current_tab, i, "RB vai para a aba %d" % i)
		await _assert_nav("config/%s" % settings.tabs.get_tab_title(i), settings)


func test_settings_capture_cancel_keeps_menu() -> void:
	var pause: PauseMenu = PauseMenu.instance
	assert_true(pause.open())
	pause.settings_button.pressed.emit()
	var settings: SettingsMenu = pause.settings_menu
	settings.tabs.current_tab = SettingsMenu.TAB_CONTROLS
	await _frames()
	for device: String in DEVICES:
		var button: Button = (settings.pad_buttons if device == UiNavAudit.PAD else settings.control_buttons)["jump"]
		button.grab_focus()
		await UiNavAudit.inject(get_viewport(), &"ui_accept", device)
		assert_false(settings.capturing.is_empty(), "%s: aceitar começa a captura" % device)
		var back: Dictionary = await UiNavAudit.check_cancel(settings, device)
		assert_false(back["closed"], "%s: Esc/B só cancela a captura" % device)
		assert_true(settings.capturing.is_empty(), "%s: captura cancelada" % device)
		await _frames()
		assert_eq(_focus(), button, "%s: foco volta ao botão da ação" % device)


func test_pause_card_and_settings() -> void:
	var pause: PauseMenu = PauseMenu.instance
	for device: String in DEVICES:
		assert_true(pause.open())
		await _frames()
		assert_eq(_focus(), pause.continue_button, "pausa: foco em Continuar")
		await _assert_nav("pausa", pause.card)
		pause.quit_button.pressed.emit()
		await _frames()
		await _assert_nav("pausa/sair", pause.quit_panel)
		var back: Dictionary = await UiNavAudit.check_cancel(pause.quit_panel, device)
		assert_true(back["closed"] and pause.card.visible, "%s: Esc/B fecha a confirmação" % device)
		back = await UiNavAudit.check_cancel(pause.card, device)
		assert_true(back["closed"] and not PauseMenu.is_open(), "%s: Esc/B fecha a pausa" % device)
	assert_true(pause.open())
	pause.settings_button.pressed.emit()
	await _frames()
	await _assert_settings_tabs(pause.settings_menu)
	var back_settings: Dictionary = await UiNavAudit.check_cancel(pause.settings_menu, UiNavAudit.PAD)
	assert_true(back_settings["closed"] and pause.card.visible, "B sai das configurações da pausa")
	assert_eq(_focus(), pause.continue_button)


func test_victory_and_credits() -> void:
	GameState.instance._host_report_boss_defeated("gold_colossus")
	var screen: VictoryScreen = VictoryScreen.instance
	await _frames()
	assert_eq(_focus(), screen.continue_button, "vitória: foco em Continuar explorando")
	await _assert_nav("vitória", screen.card)
	screen.show_credits()
	await _frames()
	await _assert_nav("créditos", screen.card)
	var back: Dictionary = await UiNavAudit.check_cancel(screen.credits_view, UiNavAudit.KEYBOARD)
	assert_true(back["closed"] and screen.summary_view.visible, "Esc volta às contagens")
	back = await UiNavAudit.check_cancel(screen.card, UiNavAudit.PAD)
	assert_true(back["closed"] and not VictoryScreen.is_open(), "B fecha a vitória")


func test_base_every_tab() -> void:
	GameState.instance.team_money = 5000
	var base: BaseStationUI = BASE_SCENE.instantiate() as BaseStationUI
	add_child_autofree(base)
	await _frames(3)
	var tabs: TabContainer = base.tab_container
	for i: int in tabs.get_tab_count():
		if i > 0:
			await UiNavAudit.inject(get_viewport(), &"tab_next", UiNavAudit.KEYBOARD)
			await _frames()
		await _assert_nav("base/%s" % tabs.get_tab_control(i).name, base)


func test_coop_menu() -> void:
	SessionManager.launch_mode = SessionManager.LAUNCH_COOP
	var menu: MultiplayerMenu = MENU_SCENE.instantiate() as MultiplayerMenu
	add_child_autofree(menu)
	await _frames()
	assert_eq(_focus(), menu.host_online_button, "coop: foco em Criar sala online")
	await _assert_nav("menu coop", menu)
	menu.mode_tabs.get_tab_bar().grab_focus()
	await UiNavAudit.inject(get_viewport(), &"ui_right", UiNavAudit.PAD)
	await _frames()
	assert_eq(menu.mode_tabs.current_tab, 1, "direita na barra vai para Rede local")
	await _assert_nav("menu coop/rede local", menu)


func test_coop_menu_relinks_when_join_enables() -> void:
	SessionManager.launch_mode = SessionManager.LAUNCH_COOP
	var menu: MultiplayerMenu = MENU_SCENE.instantiate() as MultiplayerMenu
	add_child_autofree(menu)
	await _frames()
	assert_true(menu.join_code_button.disabled, "sem código: Entrar desativado")
	menu.code_line_edit.grab_focus()
	await UiNavAudit.inject(get_viewport(), &"ui_down", UiNavAudit.PAD)
	assert_ne(_focus(), menu.join_code_button, "baixo pula o Entrar desativado")
	menu.code_line_edit.grab_focus()
	menu.code_line_edit.text = "ABC234"
	menu.code_line_edit.text_changed.emit("ABC234")
	await _frames()
	if not menu.join_code_button.disabled:
		await UiNavAudit.inject(get_viewport(), &"ui_down", UiNavAudit.PAD)
		assert_eq(_focus(), menu.join_code_button, "com código válido o Entrar entra na corrente")


func test_pause_returns_focus_to_base() -> void:
	var base: BaseStationUI = BASE_SCENE.instantiate() as BaseStationUI
	add_child_autofree(base)
	await _frames(3)
	var before: Control = _focus()
	assert_true(base.is_ancestor_of(before), "base com foco")
	assert_true(PauseMenu.instance.open())
	var back: Dictionary = await UiNavAudit.check_cancel(PauseMenu.instance.card, UiNavAudit.PAD)
	assert_true(back["closed"] and not PauseMenu.is_open(), "B fecha a pausa")
	assert_eq(_focus(), before, "foco volta à Base")


func test_summary_without_previous_focus_goes_home() -> void:
	var base: BaseStationUI = BASE_SCENE.instantiate() as BaseStationUI
	add_child_autofree(base)
	await _frames(3)
	get_viewport().gui_release_focus()
	var ui: SessionUI = SessionUI.instance
	ui._show_summary({"day": 2, "map_id": "praia", "entries": []})
	await _frames()
	var back: Dictionary = await UiNavAudit.check_cancel(ui.summary_panel, UiNavAudit.KEYBOARD)
	assert_true(back["closed"], "Esc fecha o resumo")
	assert_true(base.is_ancestor_of(_focus()), "sem foco anterior: foco vai para a Base (%s)" % _focus())


func test_leave_confirm_and_host_lost() -> void:
	var ui: SessionUI = SessionUI.instance
	ui._on_leave_pressed()
	await _frames()
	assert_eq(_focus(), ui.leave_cancel_button, "sair: foco no Cancelar")
	await _assert_nav("sair da sessão", ui.leave_confirm_panel)
	var back: Dictionary = await UiNavAudit.check_cancel(ui.leave_confirm_panel, UiNavAudit.PAD)
	assert_true(back["closed"], "B cancela a saída")
	ui._on_host_lost()
	await _frames()
	assert_eq(_focus(), ui.host_lost_close_button, "host caiu: foco em Fechar")
	await _assert_nav("host caiu", ui.host_lost_panel)
	back = await UiNavAudit.check_cancel(ui.host_lost_panel, UiNavAudit.KEYBOARD)
	assert_true(back["closed"], "Esc fecha o aviso")


func test_day_summary() -> void:
	var ui: SessionUI = SessionUI.instance
	ui._show_summary({"day": 2, "map_id": "praia", "entries": [], "money_earned": 0})
	await _frames()
	assert_eq(_focus(), ui.summary_close_button, "resumo: foco em Fechar")
	await _assert_nav("resumo do dia", ui.summary_panel)
	for device: String in DEVICES:
		ui._show_summary({"day": 2, "map_id": "praia", "entries": [], "money_earned": 0})
		await _frames()
		var back: Dictionary = await UiNavAudit.check_cancel(ui.summary_panel, device)
		assert_true(back["closed"], "%s: Esc/B fecha o resumo" % device)


func test_toast_does_not_steal_focus() -> void:
	var pause: PauseMenu = PauseMenu.instance
	assert_true(pause.open())
	await _frames()
	var before: Control = _focus()
	SessionUI.instance.show_save_toast("Não foi possível salvar")
	SessionUI.instance._enqueue_toast("Missão concluída")
	await _frames(3)
	assert_eq(_focus(), before, "toasts não roubam o foco")
	SessionUI.instance.hide_save_toast()


func test_disabled_buttons_leave_navigation() -> void:
	GameState.instance.team_money = 0
	var base: BaseStationUI = BASE_SCENE.instantiate() as BaseStationUI
	add_child_autofree(base)
	await _frames(3)
	base.tab_container.current_tab = 0
	await _frames(1)
	UiFocus.focus_tab_page(base.tab_container)
	await _frames(1)
	await _assert_nav("loja sem saldo", base)
	var pause: PauseMenu = PauseMenu.instance
	assert_true(pause.open())
	pause.settings_button.pressed.emit()
	var settings: SettingsMenu = pause.settings_menu
	settings.tabs.current_tab = SettingsMenu.TAB_VIDEO
	await _frames(1)
	settings.focus_first()
	var fullscreen: int = SettingsMenu.WINDOW_LABELS.keys().find("fullscreen")
	if fullscreen >= 0:
		settings.window_mode_option.select(fullscreen)
		settings.window_mode_option.item_selected.emit(fullscreen)
		await _frames()
		assert_true(settings.resolution_option.disabled, "tela cheia: resolução desativada")
		await _assert_nav("config/Vídeo tela cheia", settings)


func test_lobby_behind_summary_keeps_summary_focus() -> void:
	var ui: SessionUI = SessionUI.instance
	ui._show_summary({"day": 2, "map_id": "praia", "entries": []})
	await _frames()
	SessionManager.launch_mode = SessionManager.LAUNCH_COOP
	var menu: MultiplayerMenu = MENU_SCENE.instantiate() as MultiplayerMenu
	add_child_autofree(menu)
	SessionManager.launch_mode = ""
	var base: BaseStationUI = BASE_SCENE.instantiate() as BaseStationUI
	add_child_autofree(base)
	await _frames(3)
	assert_eq(_focus(), ui.summary_close_button, "lobby carregando atrás não rouba o foco do resumo")
