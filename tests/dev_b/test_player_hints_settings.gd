extends GutTest

## Dicas de primeira vez x Configurações (#77): a dica de arremesso mostra a tecla configurada,
## "Mostrar dicas" desliga as dicas sem gastá-las e "Rever dicas" faz todas voltarem.
## Isolado: dicas e configurações em user://test_saves (nunca os arquivos reais do jogador).

const HINTS: Script = preload("res://gameplay/player/player_hints.gd")
const HINTS_PATH: String = "user://test_saves/devb_hints.cfg"
const SETTINGS_PATH: String = "user://test_saves/devb_settings.cfg"

var _orig_settings_path: String = ""


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute("user://test_saves")
	for path: String in [HINTS_PATH, SETTINGS_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	HINTS.set_hints_path(HINTS_PATH)
	var sm: SettingsManager = SettingsManager.instance
	if sm != null:
		_orig_settings_path = sm.settings_path
		sm.settings_path = SETTINGS_PATH


func after_each() -> void:
	var sm: SettingsManager = SettingsManager.instance
	if sm != null:
		sm.reset_controls()
		sm.set_section(SettingsManager.GAMEPLAY, {"show_hints": true})
		sm.settings_path = _orig_settings_path
	Engine.remove_meta(HINTS.PATH_META)


func test_throw_hint_uses_configured_drop_key() -> void:
	var sm: SettingsManager = SettingsManager.instance
	assert_not_null(sm, "CoreSettings presente")
	assert_true(sm.set_binding("drop", {"type": "key", "code": KEY_G}), "drop trocado para G")
	var text: String = HINTS.take("throw")
	assert_string_contains(text, "[G]")
	assert_false(text.contains("{drop}"), "sem o marcador cru")
	assert_true(HINTS.has_seen("throw"))


func test_throw_hint_default_key() -> void:
	var text: String = HINTS.take("throw")
	assert_string_contains(text, "[Q]")


func test_throw_hint_without_settings_manager() -> void:
	var sm: SettingsManager = SettingsManager.instance
	SettingsManager.instance = null
	var text: String = HINTS.take("throw")
	SettingsManager.instance = sm
	assert_string_contains(text, "[Q]")
	assert_false(text.contains("{drop}"))


func test_gut_uses_default_settings() -> void:
	assert_true(SettingsManager._running_tests(), "GUT conta como teste (não lê o cfg real)")
	assert_true(bool(SettingsManager.DEFAULTS[SettingsManager.GAMEPLAY]["show_hints"]))
	var bad: Dictionary = SettingsManager.sanitize(SettingsManager.GAMEPLAY, {"show_hints": "nao"})
	assert_true(bad["show_hints"], "tipo errado volta ao padrão")
	var off: Dictionary = SettingsManager.sanitize(SettingsManager.GAMEPLAY, {"show_hints": false})
	assert_false(off["show_hints"])


func test_show_hints_off_does_not_spend_hint() -> void:
	var sm: SettingsManager = SettingsManager.instance
	sm.set_section(SettingsManager.GAMEPLAY, {"show_hints": false})
	assert_eq(HINTS.take("hunger"), "", "desligado: sem texto")
	assert_false(HINTS.has_seen("hunger"), "desligado: não marca como vista")
	assert_false(FileAccess.file_exists(HINTS_PATH), "desligado: não grava nada")
	sm.set_section(SettingsManager.GAMEPLAY, {"show_hints": true})
	assert_ne(HINTS.take("hunger"), "", "religado: a dica aparece")
	assert_true(HINTS.has_seen("hunger"))


func test_reset_all_brings_hints_back() -> void:
	assert_ne(HINTS.take("hunger"), "")
	assert_ne(HINTS.take("wear"), "")
	assert_eq(HINTS.take("hunger"), "", "já vista")
	HINTS.reset_all()
	assert_false(HINTS.has_seen("hunger"))
	assert_false(HINTS.has_seen("wear"))
	assert_ne(HINTS.take("hunger"), "", "depois de Rever dicas aparece de novo")
	HINTS.reset_all()
	HINTS.reset_all()
	assert_false(HINTS.has_seen("hunger"), "sem arquivo: não quebra")


func test_menu_show_hints_checkbox_applies() -> void:
	var sm: SettingsManager = SettingsManager.instance
	var menu: SettingsMenu = SettingsMenu.new()
	add_child_autofree(menu)
	assert_true(menu.show_hints_check.button_pressed, "padrão: ligado")
	assert_false(menu.has_pending_changes())
	menu.show_hints_check.button_pressed = false
	assert_true(menu.has_pending_changes(), "desmarcar fica pendente até Aplicar")
	assert_true(bool(sm.get_value(SettingsManager.GAMEPLAY, "show_hints")), "ainda não aplicado")
	menu._on_apply_pressed()
	assert_false(bool(sm.get_value(SettingsManager.GAMEPLAY, "show_hints")), "Aplicar desliga")
	assert_false(menu.has_pending_changes())
	var cfg: ConfigFile = ConfigFile.new()
	assert_eq(cfg.load(SETTINGS_PATH), OK)
	assert_false(bool(cfg.get_value(SettingsManager.GAMEPLAY, "show_hints", true)), "gravado no cfg de teste")
	menu.refresh()
	assert_false(menu.show_hints_check.button_pressed, "refresh lê o valor salvo")


func test_review_hints_button_is_immediate_and_keeps_clean_state() -> void:
	var menu: SettingsMenu = SettingsMenu.new()
	add_child_autofree(menu)
	assert_ne(HINTS.take("seagull"), "")
	var clean: Dictionary = menu._clean_state.duplicate(true)
	menu.review_hints_button.pressed.emit()
	assert_false(HINTS.has_seen("seagull"), "Rever dicas apaga as vistas na hora")
	assert_eq(menu._clean_state, clean, "não mexe no estado limpo")
	assert_false(menu.has_pending_changes(), "não suja o descartar")
	assert_true(menu.saved_notice.visible, "mostra o aviso")
	assert_eq(menu.saved_notice_label.text, SettingsMenu.HINTS_RESET_TEXT)
	menu.show_saved_notice()
	assert_eq(menu.saved_notice_label.text, SettingsMenu.SAVED_TEXT, "o mesmo aviso volta ao texto padrão")
