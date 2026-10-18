# Capturas do lobby com a Base e o MultiplayerMenu (coop), ui_scale 1.0 e 1.3 (precisa de janela):
# "C:/Godot/Godot_v4.3-stable_win64_console.exe" --path . --resolution 960x540 --windowed --script res://tests/dev_b/lobby_menu_snapshots.gd -- --prefix=depois_
# Grava em .bot_runs/theme/<prefixo>lobby_menu_ui{100,130,130_aberto}.png e imprime os retângulos. Save isolado.
extends SceneTree

const OUT_DIR: String = "res://.bot_runs/theme/"
const BaseRect = preload("res://tests/dev_b/test_lobby_menu_base_layout.gd")

var _prefix: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--prefix="):
			_prefix = arg.trim_prefix("--prefix=")
	SaveManager.instance.use_test_save_dir("lobby_menu_snapshots")
	GameState.instance.reset_state()
	SessionManager.launch_mode = SessionManager.LAUNCH_COOP
	change_scene_to_file("res://world/lobby_base.tscn")
	await _frames(30)
	var menu: Control = current_scene.get_node(^"UILayer/MultiplayerMenu") as Control
	var base: Control = current_scene.get_node(^"UILayer/BaseStationUI") as Control
	for s: float in [1.0, 1.3]:
		root.content_scale_factor = s
		await _frames(20)
		await RenderingServer.frame_post_draw
		var path: String = ProjectSettings.globalize_path(OUT_DIR + "%slobby_menu_ui%d.png" % [_prefix, int(s * 100.0)])
		var err: Error = root.get_texture().get_image().save_png(path)
		var panel: Control = menu.get_child(0) as Control
		var m: Rect2 = panel.get_global_rect() if panel.is_visible_in_tree() else Rect2()
		var br: Rect2 = BaseRect.visual_rect(base)
		print("SHOT %s (%d) view=%s menu=%s base=%s cruza=%s" % [path, err, root.get_visible_rect().size, m, br, m.intersects(br)])
	# ui 1.3 com o menu aberto (por cima da Base) pelo botão "Multiplayer".
	var button: Button = menu.get_node_or_null(^"CollapseButton") as Button
	if button != null:
		button.pressed.emit()
		await _frames(10)
		await RenderingServer.frame_post_draw
		var open_path: String = ProjectSettings.globalize_path(OUT_DIR + "%slobby_menu_ui130_aberto.png" % _prefix)
		print("SHOT %s (%d)" % [open_path, root.get_texture().get_image().save_png(open_path)])
	root.content_scale_factor = 1.0
	SessionManager.launch_mode = ""
	GameState.instance.reset_state()
	quit()
