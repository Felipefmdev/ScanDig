# Teste headless: "C:/Godot/Godot_v4.3-stable_win64_console.exe" --headless --path . --script res://core/tests/settings_file_test.gd
## #76: o user://scandig_settings.cfg tem dois escritores (SettingsManager, com as opções do
## player em [gameplay] desde o #77, e o nome/[online] do NetworkManager). Gravar um não pode
## apagar o outro. Sob --script os dois gravam o cfg de teste (SettingsManager.TEST_PATH), nunca
## o do jogador; o arquivo é copiado e restaurado no fim.
extends SceneTree

const PATH: String = SettingsManager.TEST_PATH
const BACKUP: String = "user://test_saves/settings_test.cfg.testbak"
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
	var had_file: bool = FileAccess.file_exists(PATH)
	if had_file:
		DirAccess.copy_absolute(ProjectSettings.globalize_path(PATH), ProjectSettings.globalize_path(BACKUP))
	PLAYER_SETTINGS.call(&"set_settings_path", PATH)
	await _wait(3)

	# 1. Nome e [online] existem; salvar as opções do Esc não pode apagá-los.
	var initial: ConfigFile = ConfigFile.new()
	initial.set_value("player", "name", "Murilo")
	initial.set_value("online", "noray_address", "noray.exemplo.org")
	initial.set_value("online", "noray_port", 9999)
	_check(initial.save(PATH) == OK, "arquivo inicial gravado")
	_check(PLAYER_SETTINGS.call(&"save_settings", {"mouse_sensitivity": 0.004, "fov": 90.0, "view_bobbing": false}) == OK, "opções do player gravadas")
	var after_player: ConfigFile = _read()
	_check(str(after_player.get_value("player", "name", "")) == "Murilo", "nome continua: '%s'" % str(after_player.get_value("player", "name", "")))
	_check(str(after_player.get_value("online", "noray_address", "")) == "noray.exemplo.org" and int(after_player.get_value("online", "noray_port", 0)) == 9999, "[online] continua")
	_check(is_equal_approx(float(after_player.get_value("gameplay", "fov", 0.0)), 90.0), "fov gravado em [gameplay]")

	# 2. O contrário: salvar o nome pelo NetworkManager não apaga as opções do player.
	var net: NetworkManager = NetworkManager.instance
	_check(net != null, "NetworkManager presente")
	if net != null:
		net.set_local_player_name("Outro Nome")
		var after_name: ConfigFile = _read()
		_check(str(after_name.get_value("player", "name", "")) == "Outro Nome", "nome novo gravado")
		var fov: float = float(after_name.get_value("gameplay", "fov", 0.0))
		_check(is_equal_approx(fov, 90.0) and after_name.get_value("gameplay", "view_bobbing", true) == false and is_equal_approx(float(after_name.get_value("gameplay", "mouse_sensitivity", 0.0)), 0.004), "opções do player continuam no arquivo")
		_check(str(after_name.get_value("online", "noray_address", "")) == "noray.exemplo.org", "[online] continua depois do nome")

	# 3. Sem arquivo: as opções criam o arquivo do zero.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	_check(PLAYER_SETTINGS.call(&"save_settings", {"fov": 70.0}) == OK and FileAccess.file_exists(PATH), "sem arquivo: opções criam o arquivo")

	# Restaura o arquivo do jogador.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	if had_file:
		DirAccess.rename_absolute(ProjectSettings.globalize_path(BACKUP), ProjectSettings.globalize_path(PATH))
	_check(FileAccess.file_exists(PATH) == had_file, "arquivo do jogador restaurado")
	print("RESULT fails=%d" % _fails)
	quit(_fails)
