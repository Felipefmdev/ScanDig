# Capturas da hotbar de 8 slots ao lado da mão do viewmodel (precisa de janela):
# "C:/Godot/Godot_v4.3-stable_win64_console.exe" --path . --resolution 960x540 --windowed --script res://tests/dev_b/hotbar_hand_snapshots.gd -- --prefix=960_
# Grava em .bot_runs/theme/<prefixo>hotbar_mao_ui{100,130}.png e imprime os retângulos (coordenadas
# do HUD). Save isolado (use_test_save_dir): não toca o save do jogador.
extends SceneTree

const OUT_DIR: String = "res://.bot_runs/theme/"
const HandRects = preload("res://tests/dev_b/test_hotbar_hand_clearance.gd")

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
	SaveManager.instance.use_test_save_dir("hotbar_hand_snapshots")
	GameState.instance.reset_state()
	GameState.instance.load_snapshot({"team_money": 12345, "upgrade_levels": {"backpack": 5}})
	change_scene_to_file("res://world/map_praia.tscn")
	await _frames(40)
	var player: Node = get_first_node_in_group(&"player")
	var inv: Inventory = player.get("inventory") as Inventory
	for id: String in ["moeda_antiga", "concha_dourada", "bussola_naufragio"]:
		var data: ItemData = load("res://items/catalog/%s.tres" % id) as ItemData
		inv.add_item(CarriedItem.create(data, data.base_value, 1.0, false))
	# Estilingue no último slot (o mais perto da mão), na mão.
	for i: int in inv.capacity - inv.get_count() - 1:
		inv.add_item(CarriedItem.create(load("res://items/catalog/moeda_antiga.tres") as ItemData, 10, 1.0, false))
	inv.add_item(CarriedItem.create_from_tool_data(load("res://items/tools/estilingue.tres") as ToolData))
	inv.select(inv.capacity - 1)
	var hotbar: Control = player.get_node(^"HUD/Hotbar") as Control
	var cam: Camera3D = player.get_node(^"Head/Camera3D") as Camera3D
	for s: float in [1.0, 1.3]:
		root.content_scale_factor = s
		await _frames(20)
		await RenderingServer.frame_post_draw
		var bar: Rect2 = hotbar.get_global_rect()
		var hand: Rect2 = HandRects.viewmodel_rect(cam)
		var gap: float = HandRects.gap(bar, hand)
		var path: String = ProjectSettings.globalize_path(OUT_DIR + "%shotbar_mao_ui%d.png" % [_prefix, int(s * 100.0)])
		var err: Error = root.get_texture().get_image().save_png(path)
		print("SHOT %s (%d) view=%s bar=%s hand=%s gap=%.1f" % [path, err, root.get_visible_rect().size, bar, hand, gap])
	root.content_scale_factor = 1.0
	GameState.instance.reset_state()
	quit()
