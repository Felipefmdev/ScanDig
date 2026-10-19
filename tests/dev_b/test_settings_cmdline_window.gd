extends GutTest

## #126: --resolution/--fullscreen não chegam ao OS.get_cmdline_args(); o SettingsManager deteta a
## escolha da linha de comando pela janela que o motor abriu (diferente da do projeto).


func test_project_window_is_not_cmdline() -> void:
	var size: Vector2i = SettingsManager.project_window_size()
	assert_gt(size.x, 0)
	assert_gt(size.y, 0)
	assert_false(SettingsManager.window_from_cmdline(size, DisplayServer.WINDOW_MODE_WINDOWED),
		"janela do projeto: vale a escolha salva")


func test_resolution_arg_is_cmdline() -> void:
	assert_true(SettingsManager.window_from_cmdline(Vector2i(1920, 1080), DisplayServer.WINDOW_MODE_WINDOWED),
		"--resolution 1920x1080: a linha de comando manda")


func test_fullscreen_arg_is_cmdline() -> void:
	assert_true(SettingsManager.window_from_cmdline(SettingsManager.project_window_size(), DisplayServer.WINDOW_MODE_FULLSCREEN),
		"--fullscreen: a linha de comando manda")

