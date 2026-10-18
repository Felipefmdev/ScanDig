# Capturas do HUD de jogo sem cartão e da hotbar com slots vazios (#122, precisa de janela):
# "C:/Godot/Godot_v4.3-stable_win64_console.exe" --path . --resolution 960x540 --windowed --script res://tests/dev_b/hud_polish_snapshots.gd -- --prefix=960_
# Grava em .bot_runs/theme/<prefixo>hud_{praia,geleira}.png, olhando para o chão (areia/neve) para
# conferir a leitura do texto contornado. Save isolado (use_test_save_dir).
extends SceneTree

const OUT_DIR: String = "res://.bot_runs/theme/"
const MAPS: Dictionary = {"praia": "res://world/map_praia.tscn", "geleira": "res://world/map_geleira.tscn"}

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
	SaveManager.instance.use_test_save_dir("hud_polish_snapshots")
	GameState.instance.reset_state()
	GameState.instance.load_snapshot({"team_money": 12345, "upgrade_levels": {"backpack": 5}})
	var session: Node = root.get_node(^"CoreSession")
	for map_id: String in MAPS:
		# Fora da expedição o Players cria o jogador local na hora; o mapa só entra depois.
		session.set("_current_map", null)
		change_scene_to_file(MAPS[map_id])
		await _frames(40)
		for i in range(300):
			if get_first_node_in_group(&"player") != null:
				break
			await process_frame
		await _frames(20)
		session.set("_current_map", load("res://items/maps/%s.tres" % map_id))
		SessionUI.instance._refresh_expedition_bar()
		var player: Node = get_first_node_in_group(&"player")
		var inv: Inventory = player.get("inventory") as Inventory
		for id: String in ["moeda_antiga", "concha_dourada"]:
			var data: ItemData = load("res://items/catalog/%s.tres" % id) as ItemData
			inv.add_item(CarriedItem.create(data, data.base_value, 1.0, false))
		player.set("health", 62.0)
		(player.get_node(^"Head") as Node3D).rotation.x = -0.75
		await _frames(30)
		await RenderingServer.frame_post_draw
		var path: String = ProjectSettings.globalize_path(OUT_DIR + "%shud_%s.png" % [_prefix, map_id])
		var err: Error = root.get_texture().get_image().save_png(path)
		print("SHOT %s (%d) view=%s" % [path, err, root.get_visible_rect().size])
	session.set("_current_map", null)
	GameState.instance.reset_state()
	quit()
