# Capturas do lago congelado da Geleira (#129: brilho do gelo) na mesma câmera, para comparar
# antes/depois de mexer nos materiais (precisa de janela):
# "C:/Godot/Godot_v4.3-stable_win64_console.exe" --path . --resolution 960x540 --windowed --script res://tests/dev_b/geleira_ice_snapshots.gd -- --tag=antes
# Grava em .bot_runs/geleira_ice/<tag>_{lago,placa}.png. Save isolado (use_test_save_dir).
extends SceneTree

const OUT_DIR: String = "res://.bot_runs/geleira_ice/"

var _tag: String = "atual"


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):
			_tag = arg.trim_prefix("--tag=")
	_run.call_deferred()


func _shot(shot_name: String, frames: int = 20) -> void:
	for i in range(frames):
		await process_frame
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path(OUT_DIR + "%s_%s.png" % [_tag, shot_name])
	var err: Error = root.get_texture().get_image().save_png(path)
	print("SHOT %s (%d)" % [path, err])


func _find(node: Node, script_class: StringName) -> Node:
	var script: Script = node.get_script() as Script
	if script != null and script.get_global_name() == script_class:
		return node
	for child: Node in node.get_children():
		var hit: Node = _find(child, script_class)
		if hit != null:
			return hit
	return null


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	SaveManager.instance.use_test_save_dir("geleira_ice_snapshots")
	GameState.instance.reset_state()
	SaveManager.instance.ensure_progress_applied()
	GameState.instance.unlocked_maps.append("geleira")
	GameState.instance.equipped_detector_level = 10
	var sm: SessionManager = SessionManager.instance
	change_scene_to_file(SessionManager.LOBBY_SCENE)
	await create_timer(1.0).timeout

	sm.request_start_expedition("geleira")
	while not sm.is_peer_scene_ready(1):
		await process_frame
	await create_timer(1.5).timeout
	# Sem clima (chuva/neve mudaria a imagem entre as duas corridas).
	WeatherManager.instance.stop()

	var lake: Node3D = _find(current_scene, &"FrozenLake") as Node3D
	var floe: Node3D = _find(current_scene, &"IceFloe") as Node3D
	if lake == null or floe == null:
		push_error("lago/placa não encontrados na Geleira")
		quit(1)
		return
	var cam: Camera3D = Camera3D.new()
	current_scene.add_child(cam)
	cam.make_current()

	var center: Vector3 = lake.global_position + Vector3(FrozenLake.CENTER_OFFSET.x, 0.0, FrozenLake.CENTER_OFFSET.y)
	cam.look_at_from_position(center + Vector3(0.0, 7.0, 12.0), center)
	await _shot("lago")

	cam.look_at_from_position(floe.global_position + Vector3(1.5, 1.6, 2.5), floe.global_position)
	await _shot("placa")
	quit(0)
