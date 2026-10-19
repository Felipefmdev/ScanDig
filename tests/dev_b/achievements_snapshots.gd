# Capturas das conquistas (#141, precisa de janela):
# "C:/Godot/Godot_v4.3-stable_win64_console.exe" --path . --resolution 960x540 --windowed --script res://tests/dev_b/achievements_snapshots.gd -- [--only=aba,toast,vitoria] [--lang=en]
# Grava em .bot_runs/achievements/: aba.png (Base > Conquistas, foco de teclado numa linha),
# toast.png (aviso de conquista na Base) e vitoria.png (tela de vitória com a Campanha). Com
# --lang=en os nomes ganham o sufixo _en. Save isolado (use_test_save_dir); nada vai para o do jogador.
extends SceneTree

const OUT_DIR: String = "res://.bot_runs/achievements/"

var _only: PackedStringArray = []
var _suffix: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _wants(shot: String) -> bool:
	return _only.is_empty() or _only.has(shot)


func _save_shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path(OUT_DIR + "%s%s.png" % [shot_name, _suffix])
	print("SHOT %s (%d) view=%s" % [path, root.get_texture().get_image().save_png(path), root.get_visible_rect().size])


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=").split(",")
		elif arg.begins_with("--lang="):
			SettingsManager.instance.set_language(arg.trim_prefix("--lang="), false)
			_suffix = "_" + arg.trim_prefix("--lang=")
	SaveManager.instance.use_test_save_dir("achievements_snapshots")
	# Meio de campanha: algumas conquistas, outras a caminho.
	GameState.instance.load_snapshot({"team_money": 8400, "current_day": 12,
		"defeated_bosses": ["king_crab", "giant_mole"], "unlocked_maps": ["campo", "ruinas"],
		"seen_creatures": ["crab", "seagull", "snake", "mole"], "completed_quests": ["ze_anzol"],
		"stats": {"expeditions": 11, "night_expeditions": 1, "items_found": 64, "items_sold": 31,
			"items_donated": 18, "money_earned": 48250, "creatures_defeated": 57, "digs": 940, "dig_depth_cm": 6120}})
	change_scene_to_file("res://world/lobby_base.tscn")
	await _frames(40)
	if _wants("aba"):
		await _tab()
	if _wants("toast"):
		await _toast()
	if _wants("vitoria"):
		await _victory()
	GameState.instance.reset_state()
	quit()


func _tab() -> void:
	var base: BaseStationUI = current_scene.get_node("UILayer/BaseStationUI") as BaseStationUI
	var tab: AchievementsTab = base.achievements_tab
	base.tab_container.current_tab = tab.get_parent().get_index()
	await _frames(10)
	tab.get_row("boss_king_crab").grab_focus()
	await _frames(15)
	await _save_shot("aba")


func _toast() -> void:
	var base: BaseStationUI = current_scene.get_node("UILayer/BaseStationUI") as BaseStationUI
	base.tab_container.current_tab = 0
	await _frames(5)
	GameState.instance.add_stats({"digs": 60})
	await _frames(20)
	await _save_shot("toast")


func _victory() -> void:
	SessionUI.instance._clear_toasts()
	VictoryScreen.instance.open()
	await _frames(20)
	await _save_shot("vitoria")
	VictoryScreen.instance.close()
	await _frames(5)
