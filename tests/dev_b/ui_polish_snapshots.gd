# Capturas do polimento da UI (#119), antes e depois (precisa de janela):
# "C:/Godot/Godot_v4.3-stable_win64_console.exe" --path . --resolution 960x540 --windowed --script res://tests/dev_b/ui_polish_snapshots.gd -- --prefix=antes_
# Grava em .bot_runs/theme/<prefixo>{titulo,hud_praia,hotbar,loja,museu,base_ui130}.png. Save isolado
# (use_test_save_dir): não toca o save do jogador.
extends SceneTree

const OUT_DIR: String = "res://.bot_runs/theme/"
const HOTBAR_ITEMS: Array[String] = ["moeda_antiga", "concha_dourada", "bussola_naufragio"]
const HOTBAR_TOOLS: Array[String] = ["dinamite", "estilingue"]

var _prefix: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _shot(shot_name: String, frames: int = 6) -> void:
	for i in range(frames):
		await process_frame
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path(OUT_DIR + "%s%s.png" % [_prefix, shot_name])
	var err: Error = root.get_texture().get_image().save_png(path)
	print("SHOT %s (%d)" % [path, err])


func _frames(n: int) -> void:
	for i in range(n):
		await process_frame


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--prefix="):
			_prefix = arg.trim_prefix("--prefix=")
	SaveManager.instance.use_test_save_dir("ui_polish_snapshots")
	GameState.instance.reset_state()
	GameState.instance.load_snapshot({"team_money": 12345, "upgrade_levels": {"backpack": 2}})

	# Título (o --script pularia a tela: monta à mão, sem trocar de cena).
	var title: TitleScreen = (load("res://world/title_screen.tscn") as PackedScene).instantiate() as TitleScreen
	title.auto_skip = false
	title.scene_change_enabled = false
	root.add_child(title)
	current_scene = title
	await _shot("titulo", 30)
	title.queue_free()
	await _frames(2)

	# HUD em jogo na Praia, com achados e ferramentas na mochila.
	change_scene_to_file("res://world/map_praia.tscn")
	await _frames(40)
	var player: Node = get_first_node_in_group(&"player")
	if player != null:
		var inv: Inventory = player.get("inventory") as Inventory
		for id: String in HOTBAR_ITEMS:
			var data: ItemData = load("res://items/catalog/%s.tres" % id) as ItemData
			inv.add_item(CarriedItem.create(data, data.base_value, 1.0, id == "bussola_naufragio"))
		for id: String in HOTBAR_TOOLS:
			inv.add_item(CarriedItem.create_from_tool_data(load("res://items/tools/%s.tres" % id) as ToolData))
		inv.select(1)
	await _shot("hud_praia", 30)
	var hotbar: Control = player.get_node_or_null(^"HUD/Hotbar") as Control if player != null else null
	if hotbar != null:
		var img: Image = root.get_texture().get_image()
		# Coordenadas do HUD estão no tamanho base; a imagem, no tamanho da janela.
		var k: Vector2 = Vector2(img.get_size()) / root.get_visible_rect().size
		var g: Rect2 = hotbar.get_global_rect().grow(16.0)
		var r: Rect2 = Rect2(g.position * k, g.size * k)
		var crop: Rect2i = Rect2i(r).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		var path: String = ProjectSettings.globalize_path(OUT_DIR + "%shotbar.png" % _prefix)
		print("SHOT %s (%d)" % [path, img.get_region(crop).save_png(path)])

	# Base: Loja e a vitrine do Museu com algumas peças.
	change_scene_to_file("res://world/lobby_base.tscn")
	await _frames(30)
	var base: BaseStationUI = current_scene.get_node("UILayer/BaseStationUI") as BaseStationUI
	var tabs: TabContainer = base.get_node("%TabContainer") as TabContainer
	tabs.current_tab = 0
	await _shot("loja")
	var museum: MuseumDisplay = current_scene.get_node("MuseumDisplay") as MuseumDisplay
	var some: Array = []
	for site_id: String in museum.get_site_items():
		var ids: Array = museum.get_site_items()[site_id]
		for k in range(0, ids.size(), 2):
			some.append(ids[k])
	GameState.instance.load_snapshot({"discovered_items": some})
	# "Ver museu": a câmera vai da tenda até a vitrine (MuseumView), só com o "Voltar".
	var view: MuseumView = current_scene.get_node("MuseumView") as MuseumView
	view.open()
	await create_timer(MuseumView.TWEEN_TIME + 0.3).timeout
	await _shot("museu", 12)
	view.close()
	await create_timer(MuseumView.TWEEN_TIME + 0.3).timeout
	# Base com ui_scale 1.3 (cabe na tela, com rolagem nas abas).
	root.content_scale_factor = 1.3
	tabs.current_tab = 1
	await _shot("base_ui130", 20)
	root.content_scale_factor = 1.0
	GameState.instance.reset_state()
	quit()
