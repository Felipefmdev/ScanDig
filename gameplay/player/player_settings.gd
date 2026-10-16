extends RefCounted

## Preferências do jogador (não do progresso): ficam em user://, fora do save do mundo,
## e valem para todos os mapas e sessões.

const PATH: String = "user://scandig_settings.cfg"
const SECTION: String = "player"
const DEFAULTS: Dictionary = {
	"mouse_sensitivity": 0.0025,
	"fov": 75.0,
	"view_bobbing": true,
}
const SENSITIVITY_RANGE: Vector2 = Vector2(0.0005, 0.008)
const FOV_RANGE: Vector2 = Vector2(60.0, 100.0)

## Caminho trocável nos testes (para não tocar nas preferências reais). Fica no Engine e não
## numa static var: o GUT recarrega scripts e cada cópia teria a sua.
const PATH_META: StringName = &"scandig_settings_path"


static func set_settings_path(p: String) -> void:
	Engine.set_meta(PATH_META, p)


static func settings_path() -> String:
	return str(Engine.get_meta(PATH_META, PATH))


static func load_settings() -> Dictionary:
	var out: Dictionary = DEFAULTS.duplicate()
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(settings_path()) != OK:
		return out
	for key: String in DEFAULTS:
		out[key] = cfg.get_value(SECTION, key, DEFAULTS[key])
	return sanitize(out)


static func save_settings(values: Dictionary) -> Error:
	var cfg: ConfigFile = ConfigFile.new()
	var clean: Dictionary = sanitize(values)
	for key: String in clean:
		cfg.set_value(SECTION, key, clean[key])
	return cfg.save(settings_path())


## Tipos e faixas válidos: um arquivo editado à mão não quebra o jogo.
static func sanitize(values: Dictionary) -> Dictionary:
	var out: Dictionary = DEFAULTS.duplicate()
	var sens: Variant = values.get("mouse_sensitivity")
	if sens is float or sens is int:
		out["mouse_sensitivity"] = clampf(float(sens), SENSITIVITY_RANGE.x, SENSITIVITY_RANGE.y)
	var fov: Variant = values.get("fov")
	if fov is float or fov is int:
		out["fov"] = clampf(float(fov), FOV_RANGE.x, FOV_RANGE.y)
	var bob: Variant = values.get("view_bobbing")
	if bob is bool:
		out["view_bobbing"] = bob
	return out
