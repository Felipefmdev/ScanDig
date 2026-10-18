# Capturas da vitrine do Museu (#111) e FPS da base com o museu completo (precisa de janela):
# "C:/Godot/Godot_v4.3-stable_win64_console.exe" --path . --resolution 960x540 --windowed --script res://tests/dev_b/museum_snapshots.gd
# Grava museum_{vazio,parcial,completo}.png em .bot_runs/theme/ e imprime "FPS <estado> avg min".
# Save isolado (use_test_save_dir): não toca o save do jogador.
extends SceneTree

const OUT_DIR: String = "res://.bot_runs/theme/"
const FPS_SECONDS: int = 10


func _initialize() -> void:
	_run.call_deferred()


func _shot(shot_name: String) -> void:
	for i in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path(OUT_DIR + "museum_%s.png" % shot_name)
	var err: Error = root.get_texture().get_image().save_png(path)
	print("SHOT %s (%d)" % [path, err])


func _measure_fps(label: String) -> void:
	var samples: Array[float] = []
	for s in range(FPS_SECONDS):
		await create_timer(1.0).timeout
		samples.append(Engine.get_frames_per_second())
	var total: float = 0.0
	for v: float in samples:
		total += v
	print("FPS %s avg %.1f min %.1f" % [label, total / samples.size(), samples.min()])


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	SaveManager.instance.use_test_save_dir("museum_snapshots")
	GameState.instance.reset_state()
	change_scene_to_file("res://world/lobby_base.tscn")
	for i in range(20):
		await process_frame
	var museum: MuseumDisplay = current_scene.get_node("MuseumDisplay") as MuseumDisplay
	var all_ids: Array[String] = []
	for site_id: String in museum.get_site_items():
		for id: String in museum.get_site_items()[site_id]:
			all_ids.append(id)
	await _shot("vazio")
	await _measure_fps("vazio")

	# Parcial: um pouco de cada sítio, com raras e intactas; o ídolo ainda não.
	var partial: Array = []
	var rare: Array = []
	var intact: Array = []
	for site_id: String in museum.get_site_items():
		var ids: Array = museum.get_site_items()[site_id]
		for k in range(ids.size()):
			if k % 3 == 0 and ids[k] != MuseumDisplay.HIGHLIGHT_ID:
				partial.append(ids[k])
				if k % 2 == 0:
					intact.append(ids[k])
				if k % 9 == 0:
					rare.append(ids[k])
	GameState.instance.load_snapshot({"discovered_items": partial, "rare_items": rare, "intact_items": intact})
	await _shot("parcial")

	var full_rare: Array = rare.duplicate()
	full_rare.append_array(["olho_do_polvo", "machado_viking", MuseumDisplay.HIGHLIGHT_ID])
	GameState.instance.load_snapshot({"discovered_items": all_ids, "rare_items": full_rare, "intact_items": all_ids.slice(0, 30)})
	await _shot("completo")
	print("PIECES %d/%d" % [museum.get_piece_count(), all_ids.size()])
	await _measure_fps("completo")
	GameState.instance.reset_state()
	quit()
