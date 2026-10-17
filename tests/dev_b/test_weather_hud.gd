extends GutTest

## Aviso/ícone do clima e a opção "Efeitos de clima fortes" (#99). Configurações gravadas só em
## user://test_saves (nunca no scandig_settings.cfg do jogador).

const SETTINGS_PATH: String = "user://test_saves/devb_weather_settings.cfg"

var _orig_settings_path: String = ""


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute("user://test_saves")
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(SETTINGS_PATH)
	var sm: SettingsManager = SettingsManager.instance
	_orig_settings_path = sm.settings_path
	sm.settings_path = SETTINGS_PATH


func after_each() -> void:
	if WeatherManager.instance != null:
		WeatherManager.instance.stop()
	var sm: SettingsManager = SettingsManager.instance
	sm.set_section(SettingsManager.VIDEO, {"strong_weather_fx": true})
	sm.settings_path = _orig_settings_path
	if WeatherHud.instance != null:
		WeatherHud.instance.hide_toast()


func test_strong_weather_default_and_sanitize() -> void:
	assert_true(bool(SettingsManager.DEFAULTS[SettingsManager.VIDEO]["strong_weather_fx"]), "padrão: ligado")
	assert_true(SettingsManager.sanitize(SettingsManager.VIDEO, {"strong_weather_fx": "sim"})["strong_weather_fx"], "tipo errado volta ao padrão")
	assert_false(SettingsManager.sanitize(SettingsManager.VIDEO, {"strong_weather_fx": false})["strong_weather_fx"])


func test_menu_option_applies_and_reduces_particles_live() -> void:
	var sm: SettingsManager = SettingsManager.instance
	var fx: WeatherFx = WeatherFx.instance
	assert_not_null(fx, "autoload CoreWeatherFx")
	WeatherManager.instance.force_event(WeatherManager.KIND_RAIN, 30.0)
	assert_true(fx.is_running())
	var full: int = fx.particles.amount
	assert_eq(full, WeatherFx.particle_amount(WeatherManager.KIND_RAIN, true))

	var menu: SettingsMenu = SettingsMenu.new()
	add_child_autofree(menu)
	assert_true(menu.strong_weather_check.button_pressed, "padrão: ligado")
	menu.strong_weather_check.button_pressed = false
	assert_true(menu.has_pending_changes(), "pendente até Aplicar")
	assert_eq(fx.particles.amount, full, "antes de Aplicar nada muda")
	menu._on_apply_pressed()
	assert_false(bool(sm.get_value(SettingsManager.VIDEO, "strong_weather_fx")), "Aplicar desliga")
	assert_false(fx.strong, "o visual ouve settings_changed")
	assert_eq(fx.particles.amount, int(round(full * WeatherFx.WEAK_PARTICLE_RATIO)), "fortes desligado: metade das partículas")
	assert_almost_eq(WeatherManager.now_dig_speed_mult(), 1.3, 0.001, "o jogo não muda")
	var cfg: ConfigFile = ConfigFile.new()
	assert_eq(cfg.load(SETTINGS_PATH), OK)
	assert_false(bool(cfg.get_value(SettingsManager.VIDEO, "strong_weather_fx", true)), "gravado no cfg de teste")

	menu.refresh()
	assert_false(menu.strong_weather_check.button_pressed, "refresh lê o valor salvo")
	sm.set_section(SettingsManager.VIDEO, {"strong_weather_fx": true})
	assert_eq(fx.particles.amount, full, "religado: volta ao cheio ao vivo")


func test_hud_warning_icon_and_clear_toast() -> void:
	var hud: WeatherHud = WeatherHud.instance
	assert_not_null(hud, "autoload CoreWeatherUI")
	assert_true(hud.root_control.is_in_group(SettingsManager.HUD_TEXT_GROUP), "segue o tamanho do texto do HUD")
	var core: WeatherManager = WeatherManager.instance
	core.start_cycle("geleira")
	core.force_weather()
	assert_true(hud.toast_panel.visible, "aviso no warning")
	assert_eq(hud.toast_label.text, "Nevasca chegando…")
	assert_false(hud.icon_panel.visible, "sem ícone antes de começar")
	core.tick(WeatherManager.FORCE_WARNING_S)
	assert_true(core.is_active())
	assert_true(hud.icon_panel.visible, "ícone com o evento ativo")
	assert_string_contains(hud.icon_label.text, "Nevasca")
	core.tick(core.time_left())
	assert_false(hud.icon_panel.visible, "fim: some o ícone")
	assert_true(hud.toast_panel.visible)
	assert_eq(hud.toast_label.text, WeatherHud.CLEAR_TEXT)
	core.force_event(WeatherManager.KIND_ASHSTORM, 30.0)
	core.stop()
	assert_false(hud.toast_panel.visible, "troca de cena: sem 'O tempo abriu'")


func test_hud_sits_top_right_below_threat_bar() -> void:
	var hud: WeatherHud = WeatherHud.instance
	WeatherManager.instance.force_event(WeatherManager.KIND_RAIN, 30.0)
	hud.show_toast("Chuva chegando…")
	await get_tree().process_frame
	await get_tree().process_frame
	var view: Rect2 = hud.root_control.get_viewport_rect()
	for panel: Control in [hud.icon_panel, hud.toast_panel]:
		var rect: Rect2 = panel.get_global_rect()
		assert_true(view.encloses(rect), "dentro da tela: %s" % rect)
		assert_gt(rect.position.x, view.size.x * 0.5, "metade direita")
		assert_gte(rect.position.y, WeatherHud.ICON_TOP - 0.5, "abaixo da barra de Ameaça")
		assert_lt(rect.end.y, view.size.y * 0.4, "longe da barra de expedição (canto inferior direito)")
