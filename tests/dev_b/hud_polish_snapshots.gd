# Capturas do polimento de UI do lote E (#122, precisa de janela):
# "C:/Godot/Godot_v4.3-stable_win64_console.exe" --path . --resolution 960x540 --windowed --script res://tests/dev_b/hud_polish_snapshots.gd -- --prefix=960_ [--only=hud,titulo,loja,loja_praia]
# Grava em .bot_runs/theme/<prefixo>: hud_{praia,geleira}.png (HUD sem cartão e hotbar com slots
# vazios, olhando para a areia/neve), titulo.png, loja_sem_saldo.png e loja_praia.png (rótulos 3D).
# Save isolado (use_test_save_dir).
extends SceneTree

const OUT_DIR: String = "res://.bot_runs/theme/"
const MAPS: Dictionary = {"praia": "res://world/map_praia.tscn", "geleira": "res://world/map_geleira.tscn"}

var _prefix: String = ""
var _only: PackedStringArray = []


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
		elif arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=").split(",")
	SaveManager.instance.use_test_save_dir("hud_polish_snapshots")
	GameState.instance.reset_state()
	GameState.instance.load_snapshot({"team_money": 12345, "upgrade_levels": {"backpack": 5}})
	var session: Node = root.get_node(^"CoreSession")
	if _wants("titulo"):
		await _title()
	if _wants("loja"):
		await _base_shop()
	if _wants("loja_praia"):
		await _praia_shop()
	for map_id: String in (MAPS if _wants("hud") else {}):
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


func _wants(shot: String) -> bool:
	return _only.is_empty() or _only.has(shot)


func _save_shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path(OUT_DIR + "%s%s.png" % [_prefix, shot_name])
	print("SHOT %s (%d) view=%s" % [path, root.get_texture().get_image().save_png(path), root.get_visible_rect().size])


## Título com save (Continuar visível). O --script pularia a tela: monta à mão.
func _title() -> void:
	# Um slot válido para o Continuar aparecer.
	var file: FileAccess = FileAccess.open(SaveManager.instance.slot_path(1), FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": SaveManager.SAVE_VERSION, "saved_at": 100, "team_money": 111, "current_day": 3}))
	file.close()
	var title: TitleScreen = (load("res://world/title_screen.tscn") as PackedScene).instantiate() as TitleScreen
	title.auto_skip = false
	title.scene_change_enabled = false
	root.add_child(title)
	current_scene = title
	await _frames(40)
	await _save_shot("titulo")
	title.queue_free()
	await _frames(2)


## Loja da Base sem saldo (R$ 0), com o mouse (sem foco visível).
func _base_shop() -> void:
	GameState.instance.load_snapshot({"team_money": 0})
	change_scene_to_file("res://world/lobby_base.tscn")
	await _frames(40)
	var base: BaseStationUI = current_scene.get_node("UILayer/BaseStationUI") as BaseStationUI
	(base.get_node("%TabContainer") as TabContainer).current_tab = 0
	await _frames(20)
	await _save_shot("loja_sem_saldo")
	GameState.instance.load_snapshot({"team_money": 12345})


## Rótulos 3D da loja da Praia, vistos de frente a uns metros.
func _praia_shop() -> void:
	root.get_node(^"CoreSession").set("_current_map", null)
	change_scene_to_file(MAPS["praia"])
	await _frames(40)
	for i in range(300):
		if get_first_node_in_group(&"player") != null:
			break
		await process_frame
	await _frames(20)
	var offers: Array[Node3D] = []
	for n: Node in current_scene.find_children("*", "", true, false):
		if n is Node3D and n.get_script() != null and str((n.get_script() as Script).resource_path).contains("shop_offer"):
			offers.append(n as Node3D)
	if offers.is_empty():
		print("SHOT loja_praia: sem ofertas")
		return
	var center: Vector3 = Vector3.ZERO
	for o: Node3D in offers:
		center += o.global_position
	center /= offers.size()
	var player: Node3D = get_first_node_in_group(&"player") as Node3D
	var head: Node3D = player.get_node(^"Head") as Node3D
	player.global_position = center + Vector3(0, 0, 4.5)
	player.look_at(Vector3(center.x, player.global_position.y, center.z))
	head.rotation.x = -0.2
	await _frames(30)
	await _save_shot("loja_praia")
