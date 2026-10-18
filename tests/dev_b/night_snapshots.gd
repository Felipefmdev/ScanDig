# Capturas da expedição noturna (#109) (precisa de janela):
# "C:/Godot/Godot_v4.3-stable_win64_console.exe" --path . --resolution 960x540 --windowed --script res://tests/dev_b/night_snapshots.gd
# Grava em .bot_runs/theme/noite_{praia_dia,praia_noite,lanterna,mesa}.png. Save isolado
# (use_test_save_dir): não toca o save do jogador.
extends SceneTree

const OUT_DIR: String = "res://.bot_runs/theme/"


func _initialize() -> void:
	_run.call_deferred()


func _shot(shot_name: String, frames: int = 6) -> void:
	for i in range(frames):
		await process_frame
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path(OUT_DIR + "noite_%s.png" % shot_name)
	var err: Error = root.get_texture().get_image().save_png(path)
	print("SHOT %s (%d)" % [path, err])


func _wait_map() -> void:
	var sm: SessionManager = SessionManager.instance
	while not sm.is_peer_scene_ready(1):
		await process_frame
	await create_timer(1.0).timeout


func _close_summary() -> void:
	var ui: Node = root.get_node_or_null(^"CoreSessionUI")
	if ui != null and ui.has_method(&"_on_summary_close_pressed"):
		ui.call(&"_on_summary_close_pressed")


func _player() -> Player:
	return get_first_node_in_group(Player.LOCAL_GROUP) as Player


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	SaveManager.instance.use_test_save_dir("night_snapshots")
	GameState.instance.reset_state()
	var sm: SessionManager = SessionManager.instance
	change_scene_to_file(SessionManager.LOBBY_SCENE)
	await create_timer(1.0).timeout

	sm.request_start_expedition("praia")
	await _wait_map()
	await _shot("praia_dia", 20)
	sm.request_end_expedition()
	await create_timer(1.5).timeout
	_close_summary()

	sm.request_start_expedition("praia", true)
	await _wait_map()
	await create_timer(float(NightMode.config("praia")["fade_s"]) + 0.5).timeout
	await _shot("praia_noite", 20)

	# Lanterna na mão, mirando a areia à frente.
	var player: Player = _player()
	var lantern: ToolData = load("res://items/tools/lanterna_magnesio.tres") as ToolData
	player.inventory.add_item(CarriedItem.create_from_tool_data(lantern))
	for i: int in player.inventory.slots.size():
		var c: CarriedItem = player.inventory.slots[i]
		if c != null and c.tool_id == NightFx.LANTERN_TOOL:
			player.inventory.select(i)
	player.camera.rotation.x = deg_to_rad(-22.0)
	await _shot("lanterna", 30)

	sm.request_end_expedition()
	await create_timer(1.5).timeout
	_close_summary()
	var base: BaseStationUI = current_scene.get_node("UILayer/BaseStationUI") as BaseStationUI
	base.tab_container.current_tab = 2
	for i: int in base._maps.size():
		if base._maps[i].id == "praia":
			base.map_list.select(i)
			base.map_list.item_selected.emit(i)
	base.night_check.button_pressed = true
	await _shot("mesa", 12)
	GameState.instance.reset_state()
	quit()
