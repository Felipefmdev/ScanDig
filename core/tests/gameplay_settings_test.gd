# Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/gameplay_settings_test.gd
## #77 etapa 3: o SettingsManager é dono da Jogabilidade ([gameplay]). As opções antigas do Esc
## ([player] mouse_sensitivity/fov/view_bobbing) migram sem perder nada, e o nome fica no [player].
## O player_settings.gd é só um invólucro. Arquivo do teste em user://test_saves/.
extends SceneTree

const PATH: String = "user://test_saves/gameplay_settings_test.cfg"
const PLAYER_SETTINGS: Script = preload("res://gameplay/player/player_settings.gd")

var _fails: int = 0


func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_fails += 1


func _wait(frames: int) -> void:
	for i in range(frames):
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


func _read() -> ConfigFile:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(PATH)
	return cfg


func _run() -> void:
	await _wait(3)
	var sm: SettingsManager = SettingsManager.instance
	_check(sm != null, "SettingsManager presente")
	if sm == null:
		print("RESULT fails=%d" % _fails)
		quit(_fails)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://test_saves"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

	# 1. Arquivo de antes do #77: opções do Esc em [player], junto do nome; [online] e [audio].
	var old: ConfigFile = ConfigFile.new()
	old.set_value("player", "name", "Murilo")
	old.set_value("player", "mouse_sensitivity", 0.004)
	old.set_value("player", "fov", 90.0)
	old.set_value("player", "view_bobbing", false)
	old.set_value("online", "noray_address", "noray.exemplo.org")
	old.set_value("audio", "master", 0.5)
	old.save(PATH)
	PLAYER_SETTINGS.call(&"set_settings_path", PATH)
	var g: Dictionary = sm.get_section(SettingsManager.GAMEPLAY)
	_check(is_equal_approx(float(g["mouse_sensitivity"]), 0.004) and is_equal_approx(float(g["fov"]), 90.0) and g["view_bobbing"] == false, "valores antigos lidos: %s" % str(g))
	_check(g["invert_y"] == false and g["show_fps"] == false and is_equal_approx(float(g["hud_text_scale"]), 1.0), "opções novas no padrão")
	var wrapped: Dictionary = PLAYER_SETTINGS.call(&"load_settings")
	_check(wrapped == g, "player_settings.load_settings() lê do CoreSettings")

	# 2. Primeira gravação: vão para [gameplay] e saem do [player]; o resto fica.
	_check(sm.save_settings() == OK, "gravado")
	var cfg: ConfigFile = _read()
	_check(is_equal_approx(float(cfg.get_value("gameplay", "fov", 0.0)), 90.0) and cfg.get_value("gameplay", "view_bobbing", true) == false and is_equal_approx(float(cfg.get_value("gameplay", "mouse_sensitivity", 0.0)), 0.004), "migrado para [gameplay]")
	_check(cfg.get_section_keys("player") == PackedStringArray(["name"]) and str(cfg.get_value("player", "name", "")) == "Murilo", "[player] só com o nome: %s" % str(cfg.get_section_keys("player")))
	_check(str(cfg.get_value("online", "noray_address", "")) == "noray.exemplo.org" and is_equal_approx(float(cfg.get_value("audio", "master", 0.0)), 0.5), "[online] e [audio] preservados")

	# 3. Recarregar depois da migração dá o mesmo resultado.
	sm.load_settings()
	_check(sm.get_section(SettingsManager.GAMEPLAY) == g, "recarregado igual")

	# 4. Se o arquivo tiver os dois, o [gameplay] vence o [player] antigo.
	cfg.set_value("player", "fov", 62.0)
	cfg.set_value("gameplay", "fov", 88.0)
	cfg.save(PATH)
	sm.load_settings()
	_check(is_equal_approx(float(sm.get_value(SettingsManager.GAMEPLAY, "fov")), 88.0), "[gameplay] vence o [player]")

	# 5. O invólucro grava pelo manager (nome preservado) e o sanitize vale para as novas.
	_check(PLAYER_SETTINGS.call(&"save_settings", {"invert_y": true, "hud_text_scale": 9.0, "show_fps": "sim"}) == OK, "save_settings do invólucro")
	cfg = _read()
	_check(cfg.get_value("gameplay", "invert_y", false) == true and is_equal_approx(float(cfg.get_value("gameplay", "hud_text_scale", 0.0)), SettingsManager.HUD_TEXT_SCALE_RANGE.y) and cfg.get_value("gameplay", "show_fps", true) == false, "invert_y gravado; escala no limite; tipo errado no padrão")
	_check(not cfg.has_section_key("player", "fov") and str(cfg.get_value("player", "name", "")) == "Murilo", "chave antiga apagada, nome continua")
	_check(is_equal_approx(float(cfg.get_value("gameplay", "fov", 0.0)), 88.0), "chaves ausentes ficam com o valor atual")

	# 6. Arquivo sem nada: padrões.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	sm.load_settings()
	_check(sm.get_section(SettingsManager.GAMEPLAY) == SettingsManager.DEFAULTS[SettingsManager.GAMEPLAY], "sem arquivo: padrões")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	sm.settings_path = SettingsManager.default_path()
	print("RESULT fails=%d" % _fails)
	quit(_fails)
