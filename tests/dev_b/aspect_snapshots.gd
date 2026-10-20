# QA de proporções de tela (#146): passa as telas principais por 5 resoluções × ui_scale 1.0/1.3,
# confere o layout por retângulos (layout_audit.gd) e grava as capturas:
# "C:/Godot/Godot_v4.3-stable_win64_console.exe" --path . --resolution 1280x800 --windowed --script res://tests/dev_b/aspect_snapshots.gd -- [--only=titulo,slots,...] [--res=1280x800,...] [--ui=1.0,1.3] [--no-shots]
# Com --headless e --no-shots só confere. Telas: titulo, slots, pausa, config_{video,audio,controles,
# jogabilidade,acessibilidade}, base_{loja,museu,expedicoes,diario,mapa,conquistas}, ver_museu,
# toast_conquista, vitoria, creditos, hud_praia. Grava .bot_runs/aspect/<WxH>_ui<escala>/<tela>.png e
# .bot_runs/aspect/report.json ({tela: {combo: [problemas]}}); imprime "LAYOUT <tela> <combo> ok|N".
# Save isolado (use_test_save_dir).
extends SceneTree

const Audit: GDScript = preload("res://tests/dev_b/layout_audit.gd")
const OUT_DIR: String = "res://.bot_runs/aspect/"
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 800), Vector2i(2560, 1080), Vector2i(1024, 768), Vector2i(3840, 2160), Vector2i(1366, 768)]
const UI_SCALES: Array[float] = [1.0, 1.3]
const CONFIG_TABS: Array[String] = ["config_video", "config_audio", "config_controles", "config_jogabilidade", "config_acessibilidade"]
const BASE_TABS: Array[String] = ["base_loja", "base_museu", "base_expedicoes", "base_diario", "base_mapa", "base_conquistas"]

var _only: PackedStringArray = []
var _resolutions: Array[Vector2i] = RESOLUTIONS.duplicate()
var _scales: Array[float] = UI_SCALES.duplicate()
var _shots: bool = true
var _report: Dictionary = {}
var _total: int = 0
## Avisos que não podem cruzar painel de nenhuma camada (layout_audit `floating`).
var _floating: Array[Control] = []


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _wants(shot: String) -> bool:
	if _only.is_empty():
		return true
	for s: String in _only:
		if shot == s or shot.begins_with(s + "_"):
			return true
	return false


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=").split(",")
		elif arg.begins_with("--res="):
			_resolutions.clear()
			for r: String in arg.trim_prefix("--res=").split(","):
				_resolutions.append(Vector2i(r.get_slice("x", 0).to_int(), r.get_slice("x", 1).to_int()))
		elif arg.begins_with("--ui="):
			_scales.clear()
			for s: String in arg.trim_prefix("--ui=").split(","):
				_scales.append(s.to_float())
		elif arg == "--no-shots":
			_shots = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	SaveManager.instance.use_test_save_dir("aspect_snapshots")
	GameState.instance.reset_state()
	_campaign_state()
	if _wants("titulo") or _wants("slots"):
		await _title()
	change_scene_to_file("res://world/lobby_base.tscn")
	await _frames(40)
	await _base()
	if _wants("pausa") or _wants("config"):
		await _pause()
	if _wants("ver_museu"):
		await _museum_view()
	if _wants("toast_conquista"):
		await _toast()
	if _wants("vitoria") or _wants("creditos"):
		await _victory()
	if _wants("hud_praia"):
		await _hud_praia()
	_set_combo(Vector2i(1280, 800), 1.0)
	var file: FileAccess = FileAccess.open(OUT_DIR + "report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(_report, "\t"))
	file.close()
	print("LAYOUT total de problemas: %d" % _total)
	root.get_node(^"CoreSession").set("_current_map", null)
	GameState.instance.reset_state()
	quit()


## Meio de campanha: dinheiro, mapas, conquistas e museu com peças, para as abas terem conteúdo.
func _campaign_state() -> void:
	GameState.instance.load_snapshot({"team_money": 48250, "current_day": 23,
		"defeated_bosses": ["king_crab", "giant_mole", "octopus"], "unlocked_maps": ["campo", "ruinas", "geleira"],
		"seen_creatures": ["crab", "seagull", "snake", "mole"], "completed_quests": ["ze_anzol"],
		"discovered_items": ["alianca_ouro", "moeda_antiga", "bussola_lata", "concha_dourada"],
		"upgrade_levels": {"backpack": 3, "detector": 2},
		"stats": {"expeditions": 31, "night_expeditions": 3, "items_found": 264, "items_sold": 131,
			"items_donated": 48, "money_earned": 148250, "creatures_defeated": 157, "digs": 2940, "dig_depth_cm": 61200}})


func _set_combo(res: Vector2i, ui_scale: float) -> void:
	root.size = res
	root.content_scale_factor = ui_scale


func _combo_name(res: Vector2i, ui_scale: float) -> String:
	return "%dx%d_ui%.1f" % [res.x, res.y, ui_scale]


## Passa a tela atual por todas as combinações: confere e grava. `prepare` (opcional) roda a cada
## combinação, depois do redimensionamento (toasts que somem, abas que mudam).
func _sweep(screen: String, prepare: Callable = Callable(), ignore: Array[NodePath] = []) -> void:
	if not _wants(screen):
		return
	for res: Vector2i in _resolutions:
		for ui_scale: float in _scales:
			_set_combo(res, ui_scale)
			if prepare.is_valid():
				await prepare.call()
			await _frames(8)
			var combo: String = _combo_name(res, ui_scale)
			var issues: Array[Dictionary] = Audit.audit(root, ignore, null, _floating)
			_total += issues.size()
			if not _report.has(screen):
				_report[screen] = {}
			_report[screen][combo] = issues
			print("LAYOUT %s %s %s view=%s" % [screen, combo, "ok" if issues.is_empty() else str(issues.size()), root.get_visible_rect().size])
			if not issues.is_empty():
				print(Audit.describe(issues).indent("    "))
			if _shots:
				await RenderingServer.frame_post_draw
				var dir: String = OUT_DIR + combo + "/"
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
				root.get_texture().get_image().save_png(ProjectSettings.globalize_path(dir + screen + ".png"))


func _title() -> void:
	var file: FileAccess = FileAccess.open(SaveManager.instance.slot_path(1), FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": SaveManager.SAVE_VERSION, "saved_at": 100, "last_played": 100,
		"team_money": 48250, "current_day": 23, "play_time_s": 7500, "last_map": "praia",
		"discovered_items": ["alianca_ouro"], "defeated_bosses": ["king_crab"]}))
	file.close()
	var title: TitleScreen = (load("res://world/title_screen.tscn") as PackedScene).instantiate() as TitleScreen
	title.auto_skip = false
	title.scene_change_enabled = false
	root.add_child(title)
	current_scene = title
	await _frames(40)
	await _sweep("titulo")
	title.show_slots("load")
	await _frames(20)
	await _sweep("slots")
	current_scene = null
	title.queue_free()
	await _frames(2)


func _base() -> void:
	var base: BaseStationUI = current_scene.get_node("UILayer/BaseStationUI") as BaseStationUI
	for i: int in BASE_TABS.size():
		await _sweep(BASE_TABS[i], func() -> void: base.tab_container.current_tab = i)
	base.tab_container.current_tab = 0
	await _frames(5)


func _pause() -> void:
	var pause: PauseMenu = PauseMenu.instance
	if pause == null or not pause.open():
		print("LAYOUT pausa: não abriu")
		return
	await _frames(10)
	await _sweep("pausa")
	pause.settings_button.pressed.emit()
	await _frames(10)
	for i: int in CONFIG_TABS.size():
		await _sweep(CONFIG_TABS[i], func() -> void: pause.settings_menu.tabs.current_tab = i)
	pause.settings_menu.discard()
	pause.close()
	await _frames(5)


func _museum_view() -> void:
	var base: BaseStationUI = current_scene.get_node("UILayer/BaseStationUI") as BaseStationUI
	var view: MuseumView = current_scene.get_node("MuseumView") as MuseumView
	base.tab_container.current_tab = 1
	await _frames(3)
	base.view_museum_btn.pressed.emit()
	await create_timer(MuseumView.TWEEN_TIME + 0.3).timeout
	await _sweep("ver_museu")
	view.back_button.pressed.emit()
	await create_timer(MuseumView.TWEEN_TIME + 0.3).timeout
	base.tab_container.current_tab = 0
	await _frames(5)


func _toast() -> void:
	_floating = [SessionUI.instance.toast_panel]
	await _sweep("toast_conquista", func() -> void:
		SessionUI.instance._clear_toasts()
		SessionUI.instance._on_achievement_unlocked("digs_1000")
		await _frames(30))
	_floating = []
	SessionUI.instance._clear_toasts()


func _victory() -> void:
	SessionUI.instance._clear_toasts()
	VictoryScreen.instance.open()
	await _frames(20)
	await _sweep("vitoria")
	VictoryScreen.instance.show_credits()
	await _frames(10)
	await _sweep("creditos")
	VictoryScreen.instance.close()
	await _frames(5)


func _hud_praia() -> void:
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
	var inv: Inventory = player.get("inventory") as Inventory
	for id: String in ["moeda_antiga", "concha_dourada"]:
		var data: ItemData = load("res://items/catalog/%s.tres" % id) as ItemData
		inv.add_item(CarriedItem.create(data, data.base_value, 1.0, false))
	player.set("health", 62.0)
	(player.get_node(^"Head") as Node3D).rotation.x = -0.75
	await _frames(30)
	await _sweep("hud_praia")
