extends SceneTree

## #212: regressão do foco grosso de Tela cheia; clipping da rolagem não é o bug.
var _fails: int = 0
var _capture: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok:
		_fails += 1


func _run() -> void:
	SaveManager.instance.use_test_save_dir("settings_video_focus")
	var previous_scale: float = root.content_scale_factor
	root.content_scale_factor = 1.05
	print("USERDATA %s SAVE %s" % [OS.get_user_data_dir(), ProjectSettings.globalize_path(SaveManager.instance.save_path)])
	var menu: SettingsMenu = PauseMenu.instance.settings_menu
	PauseMenu.instance.open()
	PauseMenu.instance.call(&"_on_settings_pressed")
	menu.ui_scale_slider.value = 105.0
	for frame: int in 4:
		await process_frame
	var focus: StyleBoxFlat = menu.window_mode_option.get_theme_stylebox(&"focus") as StyleBoxFlat
	_check(focus != null, "OptionButton tem foco visivel")
	_check(focus.border_width_left == 1 and focus.border_width_top == 1, "foco fino de 1px em Tela cheia")
	_check(focus.expand_margin_left <= 1.0 and focus.expand_margin_top <= 1.0, "foco sem expansao grossa ao redor do campo")
	_check(focus.border_width_left > 0 and focus.border_color.is_equal_approx(UiPalette.INK), "contorno de foco mantem contraste INK")
	_check(menu.window_mode_option.focus_mode == Control.FOCUS_ALL, "teclado e comando continuam alcancando o campo")
	menu.window_mode_option.grab_focus()
	await process_frame
	_check(root.gui_get_focus_owner() == menu.window_mode_option, "foco real em Tela cheia")
	var quality_focus: StyleBoxFlat = menu.quality_option.get_theme_stylebox(&"focus") as StyleBoxFlat
	_check(quality_focus.border_width_left == focus.border_width_left and is_equal_approx(quality_focus.expand_margin_left, focus.expand_margin_left), "campos de opcao usam a mesma geometria de foco")
	if _capture:
		var output: String = "res://.bot_runs/qa212/access/settings/"
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("--out-dir="):
				output = arg.trim_prefix("--out-dir=") + "/"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
		await RenderingServer.frame_post_draw
		var shot: String = output + "settings_focus_%dx%d.png" % [root.size.x, root.size.y]
		_check(root.get_texture().get_image().save_png(ProjectSettings.globalize_path(shot)) == OK, "SHOT " + shot)
	menu.discard()
	PauseMenu.instance.close()
	paused = false
	root.content_scale_factor = previous_scale
	await process_frame
	print("RESULT fails=%d" % _fails)
	quit(_fails)
