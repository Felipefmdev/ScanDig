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


## A Base aberta refaz as linhas montadas por código; as abas (auto_translate) cabem sem setas
## em inglês também com a interface a 130 %.
func test_base_station_refreshes_and_tabs_fit_in_english() -> void:
	GameState.instance.reset_state()
	var ui: BaseStationUI = (load("res://ui/base_station_ui.tscn") as PackedScene).instantiate() as BaseStationUI
	add_child_autofree(ui)
	await wait_frames(3)
	assert_string_starts_with(ui.secrets_label.text, "Segredos —")
	_sm.set_language("en")
	assert_string_starts_with(ui.secrets_label.text, "Secrets —", "segredos refeitos na troca")
	assert_string_contains(ui.journal_info_label.text, "Field Notebook")
	var bar: TabBar = ui.tab_container.get_tab_bar()
	assert_eq(bar.atr(bar.get_tab_title(0)), "Shop", "aba Loja pelo auto_translate")
	for scale: float in [1.0, 1.3]:
		get_tree().root.content_scale_factor = scale
		await wait_frames(3)
		var total: float = 0.0
		for i: int in bar.tab_count:
			total += bar.get_tab_rect(i).size.x
		assert_lt(total, bar.size.x, "abas em inglês cabem (escala %.1f): %.0f < %.0f" % [scale, total, bar.size.x])
		assert_false(bar.get_offset_buttons_visible(), "sem setas em inglês (escala %.1f)" % scale)
	get_tree().root.content_scale_factor = 1.0
	_sm.set_language("pt_BR")
	assert_string_starts_with(ui.secrets_label.text, "Segredos —", "de volta ao PT-BR")
	GameState.instance.reset_state()


## Mensagem com número que vai pela rede (I18n.fmt): cada um traduz no seu idioma.
func test_packed_messages_and_money_follow_the_language() -> void:
	var packed: String = I18n.fmt("⏳ O chefe está se cansando: %d s para fugir!", [30])
	assert_eq(I18n.t(packed), "⏳ O chefe está se cansando: 30 s para fugir!")
	assert_eq(I18n.t(I18n.fmt("Comprado: %s", ["Dinamite"])), "Comprado: Dinamite")
	assert_eq(MoneyFormat.money(3200), "R$" + MoneyFormat.NBSP + "3.200")
	_sm.set_language("en")
	assert_eq(I18n.t(packed), "⏳ The boss is tiring: 30 s until it flees!")
	assert_eq(I18n.t(I18n.fmt("Comprado: %s", ["Dinamite"])), "Bought: Dynamite", "texto nos argumentos também")
	assert_eq(MoneyFormat.money(3200), "R$" + MoneyFormat.NBSP + "3,200", "milhar com vírgula em inglês")
	assert_eq(InputDevice.fill_key_prompts("[E] Pegar a chave"), "[E] Pick up the key", "prompt traduzido, tecla mantida")


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
