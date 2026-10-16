extends GutTest

## Opções do jogador: sensibilidade, campo de visão e balanço da câmera. O [Esc] abre o menu de
## pausa (CorePauseMenu, #77).

const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/player.tscn")
const SETTINGS: Script = preload("res://gameplay/player/player_settings.gd")
const TEST_PATH: String = "user://test_saves/settings_test.cfg"

var _orig_path: String = ""


func before_each() -> void:
	_orig_path = SETTINGS.settings_path()
	DirAccess.make_dir_recursive_absolute("user://test_saves")
	SETTINGS.set_settings_path(TEST_PATH)
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(TEST_PATH)


func after_each() -> void:
	if PauseMenu.instance != null:
		PauseMenu.instance.close()
	SETTINGS.set_settings_path(_orig_path)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_defaults_without_file() -> void:
	assert_eq(SETTINGS.load_settings(), SETTINGS.DEFAULTS)


func test_save_load_roundtrip_and_sanitize() -> void:
	SETTINGS.save_settings({"mouse_sensitivity": 0.004, "fov": 90.0, "view_bobbing": false})
	var v: Dictionary = SETTINGS.load_settings()
	assert_almost_eq(float(v["mouse_sensitivity"]), 0.004, 0.00001)
	assert_almost_eq(float(v["fov"]), 90.0, 0.001)
	assert_false(v["view_bobbing"])
	var bad: Dictionary = SETTINGS.sanitize({"fov": 500, "mouse_sensitivity": "x", "view_bobbing": 3})
	assert_eq(bad["fov"], SETTINGS.FOV_RANGE.y, "fora da faixa vira o limite")
	assert_eq(bad["mouse_sensitivity"], SETTINGS.DEFAULTS["mouse_sensitivity"], "tipo errado volta ao padrão")
	assert_true(bad["view_bobbing"])


func test_pause_menu_toggles_and_settings_apply() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	assert_false(player.is_settings_open())
	player.toggle_settings(true)
	assert_true(player.is_settings_open(), "toggle_settings abre o menu de pausa")
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE, "mouse livre com o menu aberto")
	player.toggle_settings(false)
	assert_false(player.is_settings_open())
	player.apply_settings({"fov": 95.0, "view_bobbing": false})
	assert_almost_eq(player.camera.fov, 95.0, 0.01, "campo de visão aplicado")
	assert_false(player.view_bobbing)
