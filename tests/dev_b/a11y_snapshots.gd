# Capturas da acessibilidade (#140, precisa de janela):
# "C:/Godot/Godot_v4.3-stable_win64_console.exe" --path . --resolution 960x540 --windowed --script res://tests/dev_b/a11y_snapshots.gd -- [--only=aba,radar,legenda] [--lang=en]
# Grava em .bot_runs/a11y/: aba.png (Configurações > Acessibilidade, pela pausa na Base),
# radar_{off,protanopia,deuteranopia,tritanopia}.png (radar com um blip de cada material, inimigo
# e raro, mais as barras de vida/fome/ameaça e os marcadores do coop) e legenda.png (legendas no
# HUD da Praia). Nada é gravado no cfg do jogador (set_section com persist = false).
extends SceneTree

const OUT_DIR: String = "res://.bot_runs/a11y/"
## Detector de mentira: só o que o DetectorRadar lê.
const STUB_SOURCE: String = """extends "res://gameplay/detector/metal_detector.gd"

var stub_blips: Array[RadarBlip] = []
var stub_footer: PackedStringArray = []


func _ready() -> void:
	pass


func _process(_delta: float) -> void:
	sweep_angle = 1.1


func get_detector_level() -> int:
	return 3


func world_to_radar(world_pos: Vector3) -> Vector2:
	return Vector2(world_pos.x, world_pos.z)


func get_blips() -> Array[RadarBlip]:
	return stub_blips


func get_blip_alpha(_blip: RadarBlip) -> float:
	return 1.0


func is_pinpointing() -> bool:
	return false


func get_radar_view_distance() -> float:
	return 10.0


func get_rare_compass() -> Vector2:
	return Vector2(0.7, 0.7)


func get_footer_lines() -> PackedStringArray:
	return stub_footer
"""

var _only: PackedStringArray = []


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _wants(shot: String) -> bool:
	return _only.is_empty() or _only.has(shot)


func _save_shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path(OUT_DIR + "%s.png" % shot_name)
	print("SHOT %s (%d) view=%s" % [path, root.get_texture().get_image().save_png(path), root.get_visible_rect().size])


func _a11y(values: Dictionary) -> void:
	SettingsManager.instance.set_section(SettingsManager.ACCESSIBILITY, values, false)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=").split(",")
		elif arg.begins_with("--lang="):
			SettingsManager.instance.set_language(arg.trim_prefix("--lang="), false)
	SaveManager.instance.use_test_save_dir("a11y_snapshots")
	GameState.instance.reset_state()
	if _wants("aba"):
		await _tab()
	if _wants("radar"):
		await _radars()
	if _wants("legenda"):
		await _caption()
	SettingsManager.instance.restore_defaults(SettingsManager.ACCESSIBILITY, false)
	root.get_node(^"CoreSession").set("_current_map", null)
	GameState.instance.reset_state()
	quit()


func _tab() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	await _frames(40)
	_a11y({"colorblind_mode": "deuteranopia", "screen_shake": 0.6, "reduce_flashes": true, "hold_mode": "toggle", "captions": true})
	var pause: PauseMenu = PauseMenu.instance
	if pause == null or not pause.open():
		print("SHOT aba: pausa não abriu")
		return
	pause.settings_button.pressed.emit()
	await _frames(10)
	pause.settings_menu.tabs.current_tab = SettingsMenu.TAB_ACCESSIBILITY
	await _frames(5)
	pause.settings_menu.focus_first()
	await _frames(10)
	await _save_shot("aba")
	pause.settings_menu.discard()
	pause.close()
	_a11y(SettingsManager.DEFAULTS[SettingsManager.ACCESSIBILITY])
	await _frames(5)


func _radars() -> void:
	change_scene_to_file("res://world/lobby_base.tscn")
	await _frames(20)
	var stub_script: GDScript = GDScript.new()
	stub_script.source_code = STUB_SOURCE
	stub_script.reload()
	var detector: Node3D = stub_script.new() as Node3D
	var blips: Array[MetalDetector.RadarBlip] = []
	var specs: Array = [
		[Vector3(-5.5, 0, -4.0), ItemData.MaterialType.FERRO, false],
		[Vector3(-1.5, 0, -6.5), ItemData.MaterialType.ALUMINIO, false],
		[Vector3(3.5, 0, -5.0), ItemData.MaterialType.PRATA, false],
		[Vector3(5.5, 0, 1.0), ItemData.MaterialType.OURO, true],
		[Vector3(-4.5, 0, 3.5), ItemData.MaterialType.DESCONHECIDO, false],
	]
	for spec: Array in specs:
		var b: MetalDetector.RadarBlip = MetalDetector.RadarBlip.new()
		b.world_pos = spec[0]
		b.has_item = true
		b.material = spec[1]
		b.is_rare = spec[2]
		b.depth_cm = 10
		blips.append(b)
	var enemy: MetalDetector.RadarBlip = MetalDetector.RadarBlip.new()
	enemy.world_pos = Vector3(1.5, 0, 5.5)
	enemy.is_enemy = true
	blips.append(enemy)
	detector.set("stub_blips", blips)

	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 50
	root.add_child(layer)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.12, 0.1, 0.08)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var row: HBoxContainer = HBoxContainer.new()
	row.theme = load("res://ui/theme/scandig_theme.tres") as Theme
	row.position = Vector2(40, 40)
	row.add_theme_constant_override("separation", 40)
	layer.add_child(row)
	layer.add_child(detector)
	var radar: DetectorRadar = DetectorRadar.new()
	radar.detector = detector as MetalDetector
	radar.fill_background = true
	radar.custom_minimum_size = Vector2(380, 440)
	row.add_child(radar)
	var side: VBoxContainer = VBoxContainer.new()
	side.custom_minimum_size = Vector2(420, 0)
	side.add_theme_constant_override("separation", 12)
	row.add_child(side)
	var bars: Array[ProgressBar] = []
	for spec: Array in [["Vida", &"bar_health", 70.0], ["Fome", &"bar_hunger", 45.0],
			["Ameaça 0", &"threat_0", 20.0], ["Ameaça 1", &"threat_1", 45.0], ["Ameaça 2", &"threat_2", 70.0], ["Ameaça 3", &"threat_3", 95.0]]:
		var label: Label = Label.new()
		label.text = spec[0]
		label.add_theme_color_override(&"font_color", UiPalette.PAPER)
		side.add_child(label)
		var bar: ProgressBar = ProgressBar.new()
		bar.custom_minimum_size = Vector2(400, 18)
		bar.show_percentage = false
		bar.value = spec[2]
		side.add_child(bar)
		# Como no player: fome e ameaça têm fill próprio; a vida usa o do tema.
		if spec[1] != &"bar_health":
			var fill: StyleBoxFlat = (bar.get_theme_stylebox(&"fill") as StyleBoxFlat).duplicate() as StyleBoxFlat
			bar.add_theme_stylebox_override(&"fill", fill)
		A11y.tint_bar(bar, spec[1])
		bars.append(bar)
	var markers: HBoxContainer = HBoxContainer.new()
	markers.add_theme_constant_override("separation", 10)
	side.add_child(markers)
	var swatches: Array[ColorRect] = []
	for i: int in A11y.MARKER_ROLES.size():
		var swatch: ColorRect = ColorRect.new()
		swatch.custom_minimum_size = Vector2(120, 40)
		markers.add_child(swatch)
		swatches.append(swatch)
	for mode: String in SettingsManager.COLORBLIND_MODES:
		_a11y({"colorblind_mode": mode})
		detector.set("stub_footer", PackedStringArray([mode, "ferro alumínio prata ouro ? + inimigo"]))
		for i: int in swatches.size():
			swatches[i].color = A11y.color(A11y.MARKER_ROLES[i])
		await _frames(6)
		await _save_shot("radar_%s" % mode)
	_a11y({"colorblind_mode": "off"})
	layer.queue_free()
	await _frames(3)


func _caption() -> void:
	var session: Node = root.get_node(^"CoreSession")
	session.set("_current_map", null)
	change_scene_to_file("res://world/map_praia.tscn")
	await _frames(40)
	for i in range(300):
		if get_first_node_in_group(&"player") != null:
			break
		await process_frame
	await _frames(20)
	session.set("_current_map", load("res://items/maps/praia.tres"))
	SessionUI.instance._refresh_expedition_bar()
	var player: Node = get_first_node_in_group(&"player")
	(player.get_node(^"Head") as Node3D).rotation.x = -0.35
	_a11y({"captions": true})
	A11y.instance.reset_captions()
	A11y.caption(A11y.CAPTION_WEATHER)
	A11y.caption(A11y.CAPTION_CREATURE)
	await _frames(20)
	await _save_shot("legenda")
	session.set("_current_map", null)
