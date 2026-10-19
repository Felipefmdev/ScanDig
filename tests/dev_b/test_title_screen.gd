extends GutTest

## Tela inicial (#100): decisão de pular (bots/testes), Continuar só com save e no último slot,
## seletor de slots (novo/carregar/coop/apagar com confirmação), foco por teclado e o
## MultiplayerMenu oculto no solo e visível no coop. Saves em user://test_saves/devb_title.

const TITLE_SCENE: PackedScene = preload("res://world/title_screen.tscn")
const MENU_SCENE: PackedScene = preload("res://ui/multiplayer_menu.tscn")
const DIR: String = "user://test_saves/devb_title"

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
	SessionManager.launch_mode = ""


func after_all() -> void:
	SaveManager.instance.set_save_path(_orig_path)
	GameState.instance.reset_state()


func _title() -> TitleScreen:
	var title: TitleScreen = TITLE_SCENE.instantiate() as TitleScreen
	title.auto_skip = false
	title.scene_change_enabled = false
	add_child_autofree(title)
	return title


func _write_slot(n: int, money: int, saved_at: int, completed: bool = false) -> void:
	var data: Dictionary = {"version": SaveManager.SAVE_VERSION, "saved_at": saved_at, "team_money": money,
		"current_day": 3, "discovered_items": ["alianca_ouro"], "game_completed": completed,
		"defeated_bosses": [GameState.FINAL_BOSS_ID] if completed else []}
	var file: FileAccess = FileAccess.open(SaveManager.instance.slot_path(n), FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func test_should_skip_decision() -> void:
	assert_false(TitleScreen.should_skip(PackedStringArray([]), PackedStringArray([])), "jogo normal: mostra")
	assert_false(TitleScreen.should_skip(PackedStringArray(["--path", "."]), PackedStringArray(["--prefix=A_"])))
	assert_true(TitleScreen.should_skip(PackedStringArray([]), PackedStringArray(["--bot=C:/x/smoke.json"])), "bot pula")
	assert_false(TitleScreen.should_skip(PackedStringArray([]), PackedStringArray(["--bot=C:/x/smoke.json"]), false), "release: --bot= é ignorado")
	assert_false(TitleScreen.should_skip(PackedStringArray([]), PackedStringArray(["--bot=C:/x/qa.json", TitleScreen.BOT_KEEP_TITLE_ARG])), "bot que testa o título: mostra")
	assert_true(TitleScreen.should_skip(PackedStringArray(["--script", "x.gd"]), PackedStringArray([]), false), "--script pula também no release")
	assert_true(TitleScreen.should_skip(PackedStringArray(["--script", "res://core/tests/flow_test.gd"]), PackedStringArray([])), "--script pula")
	assert_true(TitleScreen.should_skip(PackedStringArray(["-s", "addons/gut/gut_cmdln.gd"]), PackedStringArray([])), "GUT pula")
	assert_true(TitleScreen.should_skip(OS.get_cmdline_args(), OS.get_cmdline_user_args()), "este GUT também")


func test_continue_hidden_without_save_and_focus_starts_on_new_game() -> void:
	var title: TitleScreen = _title()
	assert_false(title.continue_button.visible, "sem save: sem Continuar")
	assert_true(title.new_game_button.has_focus(), "foco no primeiro botão visível")
	assert_eq(title.new_game_button.focus_neighbor_top, title.quit_button.get_path(), "foco em anel entre os visíveis")
	assert_eq(title.quit_button.focus_neighbor_bottom, title.new_game_button.get_path())
	for button: Button in [title.new_game_button, title.load_button, title.coop_button, title.settings_button, title.quit_button]:
		assert_true(button.visible)
		assert_eq(button.focus_mode, Control.FOCUS_ALL, "navegável por teclado/controle")


func test_continue_uses_last_used_slot_solo() -> void:
	_write_slot(1, 111, 100)
	_write_slot(3, 333, 300)
	var title: TitleScreen = _title()
	assert_true(title.continue_button.visible)
	assert_true(title.continue_button.has_focus())
	title.continue_button.pressed.emit()
	assert_eq(SaveManager.instance.current_slot(), 3, "Continuar = último slot usado")
	assert_eq(GameState.instance.team_money, 333, "aplicou o save")
	assert_eq(SessionManager.launch_mode, SessionManager.LAUNCH_SOLO)
	assert_eq(title.launched_scene, SessionManager.LOBBY_SCENE, "vai para a base")


func test_slot_selector_lines() -> void:
	_write_slot(1, 1234, 1760000000, true)
	_write_slot(2, 50, 1760000500)
	var title: TitleScreen = _title()
	title.load_button.pressed.emit()
	assert_true(title.slots_panel.visible)
	assert_false(title.main_card.visible)
	assert_string_contains(title.slot_buttons[0].text, "Dia 3")
	assert_string_contains(title.slot_buttons[0].text, UiFormat.money(1234))
	assert_string_contains(title.slot_buttons[0].text, "Museu 1/")
	assert_string_contains(title.slot_buttons[0].text, "★", "jogo concluído")
	assert_false(title.slot_buttons[1].text.contains("★"))
	assert_string_contains(title.slot_buttons[2].text, "Vazio")
	assert_true(title.slot_delete_buttons[0].visible)
	assert_false(title.slot_delete_buttons[2].visible, "vazio: sem Apagar")
	assert_true(title.slot_buttons[1].has_focus(), "foco no último slot usado")


func test_load_empty_slot_starts_new_game() -> void:
	var title: TitleScreen = _title()
	title.show_slots("load")
	title.slot_buttons[1].pressed.emit()
	assert_eq(SaveManager.instance.current_slot(), 2)
	assert_true(FileAccess.file_exists(SaveManager.instance.slot_path(2)), "slot vazio: jogo novo gravado")
	assert_eq(SessionManager.launch_mode, SessionManager.LAUNCH_SOLO)


func test_new_game_on_occupied_slot_asks_first() -> void:
	_write_slot(1, 999, 100)
	var title: TitleScreen = _title()
	title.new_game_button.pressed.emit()
	title.slot_buttons[0].pressed.emit()
	assert_true(title.confirm_panel.visible, "slot ocupado: pede confirmação")
	assert_string_contains(title.confirm_label.text, "slot 1")
	assert_eq(title.launched_scene, "", "ainda não foi")
	title.confirm_ok_button.pressed.emit()
	assert_eq(GameState.instance.team_money, 100, "jogo novo")
	assert_true(FileAccess.file_exists(DIR + "/scandig_save_1.backup.json"), "o anterior foi para o backup")
	assert_eq(title.launched_scene, SessionManager.LOBBY_SCENE)


func test_delete_slot_with_confirmation() -> void:
	_write_slot(2, 500, 100)
	var title: TitleScreen = _title()
	title.show_slots("load")
	title.slot_delete_buttons[1].pressed.emit()
	assert_true(title.confirm_panel.visible)
	assert_eq(title.confirm_label.text, TitleScreen.DELETE_CONFIRM % 2)
	assert_true(title.confirm_cancel_button.has_focus(), "foco no Cancelar (ação perigosa)")
	title.confirm_cancel_button.pressed.emit()
	assert_true(FileAccess.file_exists(SaveManager.instance.slot_path(2)), "cancelar não apaga")
	assert_true(title.slots_panel.visible)
	title.slot_delete_buttons[1].pressed.emit()
	title.confirm_ok_button.pressed.emit()
	assert_false(FileAccess.file_exists(SaveManager.instance.slot_path(2)), "confirmar apaga")
	assert_string_contains(title.slot_buttons[1].text, "Vazio")
	assert_eq(title.launched_scene, "", "apagar não abre o jogo")


func test_coop_uses_chosen_slot() -> void:
	_write_slot(3, 777, 100)
	var title: TitleScreen = _title()
	assert_eq(title.coop_button.text, "Multiplayer", "o botão se chama Multiplayer, não Coop")
	title.coop_button.pressed.emit()
	assert_eq(title.slot_mode, "coop")
	assert_eq(title.slots_title.text, "Multiplayer: escolha o slot do host")
	title.slot_buttons[2].pressed.emit()
	assert_eq(SaveManager.instance.current_slot(), 3, "o host usa o slot escolhido")
	assert_eq(GameState.instance.team_money, 777)
	assert_eq(SessionManager.launch_mode, SessionManager.LAUNCH_COOP)


func test_multiplayer_menu_hidden_in_solo_shown_in_coop() -> void:
	SessionManager.launch_mode = SessionManager.LAUNCH_SOLO
	var solo: Control = MENU_SCENE.instantiate() as Control
	add_child_autofree(solo)
	assert_false(solo.visible, "solo: menu de rede oculto")
	SessionManager.launch_mode = SessionManager.LAUNCH_COOP
	var coop: Control = MENU_SCENE.instantiate() as Control
	add_child_autofree(coop)
	assert_true(coop.visible, "coop: menu de rede aberto")
	var header: Label = coop.find_child("TitleLabel", true, false) as Label
	assert_eq(header.text, "Multiplayer", "cabeçalho do menu de rede")
	SessionManager.launch_mode = ""
	var default_menu: Control = MENU_SCENE.instantiate() as Control
	add_child_autofree(default_menu)
	assert_true(default_menu.visible, "modo vazio (bots/testes): como sempre")


func test_settings_and_escape_return_to_main() -> void:
	var title: TitleScreen = _title()
	title.settings_button.pressed.emit()
	assert_true(title.settings_menu.visible, "Configurações reusa a SettingsMenu (#77)")
	assert_false(title.main_card.visible)
	title.settings_menu.closed.emit()
	assert_true(title.main_card.visible)
	title.load_button.pressed.emit()
	var ev: InputEventAction = InputEventAction.new()
	ev.action = &"ui_cancel"
	ev.pressed = true
	title._unhandled_input(ev)
	assert_true(title.main_card.visible, "Esc volta ao cartão principal")


## Polimento (#119): versão do projeto no canto, faixa da premissa, ícone em cada botão,
## leve escala no foco e o logo balançando.
func test_title_polish_version_tagline_icons_and_motion() -> void:
	assert_eq(str(ProjectSettings.get_setting("application/config/version", "")), "0.1.0", "versão no project.godot")
	var title: TitleScreen = _title()
	assert_eq(title.version_label.text, BuildInfo.display_text())
	assert_eq(title.tagline_label.text, TitleScreen.TAGLINE)
	for button: Button in [title.continue_button, title.new_game_button, title.load_button, title.coop_button, title.settings_button, title.quit_button]:
		assert_not_null(button.icon, "ícone em %s" % button.text)
	InputDevice.instance.set_using_pointer(false)
	title.load_button.grab_focus()
	await wait_seconds(0.2)
	assert_almost_eq(title.load_button.scale.x, TitleScreen.BUTTON_FOCUS_SCALE, 0.001, "foco por teclado cresce o botão")
	title.coop_button.grab_focus()
	await wait_seconds(0.2)
	assert_almost_eq(title.load_button.scale.x, 1.0, 0.001, "sem foco volta")
	InputDevice.instance.set_using_pointer(true)
	var start: float = title.logo_label.rotation
	await wait_seconds(0.3)
	assert_ne(title.logo_label.rotation, start, "logo balança")


## #122 (E5): com o mouse, o Continuar focado ao abrir fica da largura e no alinhamento dos
## outros (sem escala) e sem borda de foco; a borda volta ao navegar pelo teclado.
func test_continue_same_width_and_focus_only_with_keyboard() -> void:
	InputDevice.instance.set_using_pointer(true)
	_write_slot(1, 111, 100)
	var title: TitleScreen = _title()
	await wait_seconds(0.2)
	assert_true(title.continue_button.visible and title.continue_button.has_focus(), "Continuar focado")
	assert_almost_eq(title.continue_button.scale.x, 1.0, 0.001, "sem escala com o mouse")
	assert_eq(title.continue_button.size.x, title.new_game_button.size.x, "mesma largura")
	assert_eq(title.continue_button.global_position.x, title.new_game_button.global_position.x, "mesmo alinhamento")
	assert_eq(title.continue_button.get_theme_stylebox(&"focus").get_class(), "StyleBoxEmpty", "mouse: sem borda de foco")
	InputDevice.instance.set_using_pointer(false)
	assert_ne(title.continue_button.get_theme_stylebox(&"focus").get_class(), "StyleBoxEmpty", "teclado: borda de foco")
	InputDevice.instance.set_using_pointer(true)
