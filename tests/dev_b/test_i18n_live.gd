extends GutTest

## Troca de idioma ao vivo (#131): Configurações > Jogabilidade > Idioma muda o TranslationServer
## na hora, grava [general] language e as telas abertas se refazem (os textos fixos pelo
## auto_translate dos Controls, os montados por código no NOTIFICATION_TRANSLATION_CHANGED).

var _sm: SettingsManager = null


func before_each() -> void:
	_sm = SettingsManager.instance
	assert_not_null(_sm, "autoload CoreSettings")
	_sm.settings_path = SettingsManager.default_path()


func after_each() -> void:
	if _sm != null:
		_sm.set_language("pt_BR")
	assert_eq(TranslationServer.get_locale(), "pt_BR", "volta ao PT-BR")


func test_language_option_switches_live_and_saves() -> void:
	var menu: SettingsMenu = SettingsMenu.new()
	add_child_autofree(menu)
	var option: OptionButton = menu.language_option
	assert_false(option.disabled, "Idioma habilitado")
	assert_eq(option.item_count, 2)
	assert_eq(option.get_item_text(0), "Português (Brasil)")
	assert_eq(option.get_item_text(1), "English")
	assert_eq(option.selected, 0, "padrão: PT-BR")
	assert_eq(menu.control_buttons["jump"].text, "Espaço")

	option.select(1)
	option.item_selected.emit(1)
	assert_eq(TranslationServer.get_locale(), "en", "troca na hora, sem Aplicar")
	assert_eq(_sm.get_language(), "en")
	var cfg: ConfigFile = ConfigFile.new()
	assert_eq(cfg.load(_sm.settings_path), OK)
	assert_eq(cfg.get_value(SettingsManager.GENERAL, "language", ""), "en", "gravado no settings")
	assert_eq(menu.title_label.atr(menu.title_label.text), "Settings", "título fixo pelo auto_translate")
	assert_eq(menu.control_buttons["jump"].text, "Space", "nome de tecla refeito ao trocar o idioma")
	assert_false(menu.has_pending_changes(), "trocar o idioma não deixa mudança pendente")

	option.select(0)
	option.item_selected.emit(0)
	assert_eq(TranslationServer.get_locale(), "pt_BR")
	assert_eq(menu.control_buttons["jump"].text, "Espaço")
	assert_eq(menu.title_label.atr(menu.title_label.text), "Configurações")


func test_saved_language_is_applied_on_load() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value(SettingsManager.GENERAL, "language", "en")
	assert_eq(cfg.save(_sm.settings_path), OK)
	_sm.load_settings()
	_sm.apply_all()
	assert_eq(TranslationServer.get_locale(), "en", "idioma salvo vale ao abrir o jogo")
	assert_eq(tr("Configurações"), "Settings")
	cfg.set_value(SettingsManager.GENERAL, "language", "klingon")
	assert_eq(cfg.save(_sm.settings_path), OK)
	_sm.load_settings()
	_sm.apply_all()
	assert_eq(TranslationServer.get_locale(), "pt_BR", "idioma inválido no arquivo: PT-BR")
