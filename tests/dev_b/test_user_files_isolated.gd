extends GutTest

## Sob GUT nada grava os arquivos reais do jogador no user:// (opções, nome, saves, dicas):
## os caminhos efetivos ficam em user://test_saves/ e gravar de verdade não muda os reais.

const HINTS: Script = preload("res://gameplay/player/player_hints.gd")
const TEST_DIR: String = "user://test_saves/"

var _real_files: PackedStringArray = []


func before_all() -> void:
	_real_files = [SettingsManager.DEFAULT_PATH, SaveManager.SAVE_FILE_PATH, HINTS.PATH]
	for n: int in range(1, SaveManager.SLOT_COUNT + 1):
		_real_files.append("user://%s" % (SaveManager.SLOT_FILE_FORMAT % n))
		_real_files.append("user://%s.backup.json" % (SaveManager.SLOT_FILE_FORMAT % n).get_basename())


func _snapshot() -> Dictionary:
	var out: Dictionary = {}
	for path: String in _real_files:
		out[path] = FileAccess.get_md5(path) if FileAccess.file_exists(path) else ""
	return out


func test_effective_paths_are_test_paths() -> void:
	assert_true(SettingsManager.default_path().begins_with(TEST_DIR), "cfg padrão sob teste: %s" % SettingsManager.default_path())
	assert_true(SettingsManager.instance.settings_path.begins_with(TEST_DIR), "cfg em uso: %s" % SettingsManager.instance.settings_path)
	assert_true(SaveManager.instance.save_path.begins_with(TEST_DIR), "save em uso: %s" % SaveManager.instance.save_path)
	assert_true(SaveManager.instance.slot_path(1).begins_with(TEST_DIR), "slots: %s" % SaveManager.instance.slot_path(1))
	assert_true(str(HINTS.call(&"hints_path")).begins_with(TEST_DIR), "dicas: %s" % HINTS.call(&"hints_path"))


func test_writes_do_not_touch_real_files() -> void:
	var before: Dictionary = _snapshot()
	var sm: SettingsManager = SettingsManager.instance
	var net: NetworkManager = NetworkManager.instance
	var name_backup: String = net.local_player_name
	sm.set_section(SettingsManager.GAMEPLAY, {"fov": 77.0})
	sm.set_binding("jump", {"type": "key", "code": KEY_K}, true)
	sm.reset_controls()
	sm.set_section(SettingsManager.GAMEPLAY, SettingsManager.DEFAULTS[SettingsManager.GAMEPLAY])
	net.set_local_player_name("Guarda")
	net.set_local_player_name(name_backup)
	SaveManager.instance.save_game()
	HINTS.call(&"take", "hunger")
	assert_eq(_snapshot(), before, "arquivos reais do user:// intactos")
