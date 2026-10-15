# Capturas do theme (precisa de janela):
# "C:/Godot/Godot_v4.3-stable_win64_console.exe" --path . --resolution 960x540 --windowed --script res://ui/tests/theme_snapshots.gd
# Grava PNGs em .bot_runs/theme/ (no .gitignore) e imprime os retângulos dos painéis.
# Prefixo opcional nos arquivos (comparar variantes do theme): acrescente "-- --prefix=A_".
extends SceneTree

const OUT_DIR: String = "res://.bot_runs/theme/"

class FakeSave extends Node:
	signal save_state_changed()
	var summary: Dictionary = {"exists": true, "valid": true, "day": 12, "money": 123456,
		"museum_found": 14, "museum_total": 27, "saved_at": 1760500000}

	func get_save_summary() -> Dictionary:
		return summary

	func is_progress_applied() -> bool:
		return false

	func continue_game() -> Error:
		return OK

	func start_new_game() -> Error:
		return OK

var _tag: String = ""
var _prefix: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _shot(shot_name: String) -> void:
	for i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path(OUT_DIR + "%s%s_%s.png" % [_prefix, shot_name, _tag])
	var err: Error = root.get_texture().get_image().save_png(path)
	print("SHOT %s (%d)" % [path, err])


func _rect(n: Control) -> String:
	var r: Rect2 = n.get_global_rect()
	return "x %d-%d y %d-%d" % [r.position.x, r.end.x, r.position.y, r.end.y]


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	change_scene_to_file("res://world/lobby_base.tscn")
	# Save isolado: nada daqui toca o user://scandig_save.json do jogador.
	SaveManager.instance.use_test_save_dir("theme_snapshots")
	for i in range(20):
		await process_frame
	_tag = "%dx%d" % [root.size.x, root.size.y]
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--prefix="):
			_prefix = arg.trim_prefix("--prefix=")
	var base: BaseStationUI = current_scene.get_node("UILayer/BaseStationUI") as BaseStationUI
	var menu: MultiplayerMenu = current_scene.get_node("UILayer/MultiplayerMenu") as MultiplayerMenu
	var hud: Node = current_scene.find_child("HUD", true, false)
	var ui: SessionUI = SessionUI.instance
	var fake: FakeSave = FakeSave.new()
	root.add_child(fake)
	menu.set_save_manager(fake)

	# 3 segredos da Praia encontrados: o Museu mostra a contagem por mapa.
	GameState.instance.load_snapshot({"found_secrets": [GameState.SECRETS[0], GameState.SECRETS[1], GameState.SECRETS[2]]})
	var tabs: TabContainer = base.get_node("%TabContainer") as TabContainer
	var shot_names: Array[String] = ["loja", "museu", "expedicoes"]
	for i in range(3):
		tabs.current_tab = i
		await _shot("lobby_%s" % shot_names[i])
		print("RECT %s %s base %s min_h %d" % [_tag, shot_names[i], _rect(base.get_child(0) as Control), int((base.get_child(0) as Control).get_combined_minimum_size().y)])
	tabs.current_tab = 0
	print("RECT %s menu %s" % [_tag, _rect(menu.get_child(0) as Control)])
	if hud != null:
		print("RECT %s hud %s" % [_tag, _rect(hud.get_node("MarginContainer/PanelContainer") as Control)])

	menu.mode_tabs.current_tab = 1
	await _shot("menu_rede_local")
	print("RECT %s menu_lan %s" % [_tag, _rect(menu.get_child(0) as Control)])
	menu.mode_tabs.current_tab = 0
	NetworkManager.instance.room_code_ready.emit("K7Q3MX")
	await _shot("menu_online_codigo")
	print("RECT %s menu_code %s" % [_tag, _rect(menu.get_child(0) as Control)])
	menu._hide_room_code()

	menu.new_game_button.pressed.emit()
	await _shot("dialogo_novo_jogo")
	menu.new_game_dialog.hide()

	var session: Node = root.get_node(^"CoreSession")
	session.set("_current_map", load("res://items/maps/praia.tres"))
	ui._refresh_expedition_bar()
	ui.toast_label.text = "Missão concluída: O anzol de ouro (+R$ 600)"
	ui.toast_panel.visible = true
	await _shot("aviso")
	ui._clear_toasts()
	ui._on_secret_found(GameState.SECRETS[2])
	await _shot("aviso_segredo")
	ui._clear_toasts()
	ui.toast_panel.visible = false

	ui._show_summary({"day": 3, "map_name": "Praia", "money_start": 1200, "money_end": 2150, "money_earned": 950,
		"entries": [
			{"name": "Moeda antiga", "action": "sold", "value": 300},
			{"name": "Anel de prata", "action": "donated", "value": 450},
			{"name": "Lata enferrujada", "action": "sold", "value": 200},
		]})
	await _shot("resumo_do_dia")
	ui._on_summary_close_pressed()
	session.set("_current_map", null)
	ui._refresh_expedition_bar()
	menu.set_save_manager(null)
	fake.queue_free()
	GameState.instance.reset_state()
	quit()
