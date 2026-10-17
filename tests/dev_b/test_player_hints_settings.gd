extends GutTest

## Dicas de primeira vez x Configurações (#77): a dica de arremesso mostra a tecla configurada.
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
