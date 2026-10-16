extends RefCounted

## Preferências do jogador (não do progresso). Invólucro fino do SettingsManager (autoload
## CoreSettings, #77), dono do user://scandig_settings.cfg: as opções ficam na seção [gameplay]
## (as antigas de [player] são migradas por ele). Opções novas de jogador entram por lá.

const PATH: String = SettingsManager.DEFAULT_PATH
const SECTION: String = SettingsManager.GAMEPLAY
const DEFAULTS: Dictionary = SettingsManager.DEFAULTS[SettingsManager.GAMEPLAY]
const SENSITIVITY_RANGE: Vector2 = SettingsManager.SENSITIVITY_RANGE
const FOV_RANGE: Vector2 = SettingsManager.FOV_RANGE


## Testes: troca o arquivo do SettingsManager e relê.
static func set_settings_path(p: String) -> void:
	var sm: SettingsManager = SettingsManager.instance
	if sm == null:
		return
	sm.settings_path = p
	sm.load_settings()


static func settings_path() -> String:
	var sm: SettingsManager = SettingsManager.instance
	return sm.settings_path if sm != null else PATH


static func load_settings() -> Dictionary:
	var sm: SettingsManager = SettingsManager.instance
	return sm.get_section(SECTION) if sm != null else DEFAULTS.duplicate()


## Aplica (o player escuta CoreSettings.settings_changed) e grava preservando as outras seções.
static func save_settings(values: Dictionary) -> Error:
	var sm: SettingsManager = SettingsManager.instance
	if sm == null:
		return ERR_UNAVAILABLE
	sm.set_section(SECTION, values, false)
	return sm.save_settings()


static func sanitize(values: Dictionary) -> Dictionary:
	return SettingsManager.sanitize(SECTION, values)
