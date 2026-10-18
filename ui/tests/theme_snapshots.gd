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
		if shot_names[i] == "expedicoes":
			# Campo Antigo travado pelo chefe: o motivo aparece embaixo da lista (#59).
			base.map_list.select(1)
			base.map_list.item_selected.emit(1)
		await _shot("lobby_%s" % shot_names[i])
		print("RECT %s %s base %s min_h %d" % [_tag, shot_names[i], _rect(base.get_child(0) as Control), int((base.get_child(0) as Control).get_combined_minimum_size().y)])
	# Mapa do Tesouro (#117): pergaminho com 0 peças, 4 (das duas linhas) e completo; completo a 150 %.
	var treasure_page: Control = tabs.get_node_or_null(BaseStationUI.TREASURE_TAB_TITLE) as Control
	if treasure_page != null:
		tabs.current_tab = treasure_page.get_index()
		var four: Array[String] = ["praia_frag_1", "ruinas_frag_1", "geleira_frag_2", "cratera_frag_2"]
		for shot: Array in [["mapa_tesouro_0", [] as Array[String]], ["mapa_tesouro_4", four], ["mapa_tesouro_completo", GameState.MAP_FRAGMENT_IDS]]:
			GameState.instance.load_snapshot({"map_fragments": shot[1]})
			await _shot(shot[0])
			print("RECT %s %s base %s mapa %s" % [_tag, shot[0], _rect(base.get_child(0) as Control), _rect(treasure_page.get_node(^"TreasureMapScroll") as Control)])
		SettingsManager.instance.set_section(SettingsManager.GAMEPLAY, {"hud_text_scale": 1.5}, false)
		await _shot("mapa_tesouro_completo_hud150")
		print("RECT %s mapa_hud150 base %s mapa %s" % [_tag, _rect(base.get_child(0) as Control), _rect(treasure_page.get_node(^"TreasureMapScroll") as Control)])
		SettingsManager.instance.set_section(SettingsManager.GAMEPLAY, {"hud_text_scale": 1.0}, false)
		GameState.instance.load_snapshot({"map_fragments": [] as Array[String]})
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
	# Barra de chefe real (BossHud do gameplay) para conferir que o ExpeditionBar não a cobre.
	var boss_hud: BossHud = BossHud.create("Caranguejo-Rei", 100.0, UiPalette.RED_BURNT)
	boss_hud.visible = true
	boss_hud.set_health(65.0)
	root.add_child(boss_hud)
	ui.leave_button.visible = true
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

	var bars_layer: CanvasLayer = CanvasLayer.new()
	bars_layer.layer = 60
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.theme = load("res://ui/theme/scandig_theme.tres") as Theme
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = &"WornPanel"
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 12)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.custom_minimum_size.x = 320
	var bar_specs: Array[Array] = [
		["ProgressBar (HP)", &""],
		["ThreatBar", &"ThreatBar"],
		["BossBar", &"BossBar"],
	]
	for spec: Array in bar_specs:
		var lbl: Label = Label.new()
		lbl.text = spec[0] as String
		vbox.add_child(lbl)
		var bar: ProgressBar = ProgressBar.new()
		bar.theme_type_variation = spec[1] as StringName
		bar.value = 65.0
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.custom_minimum_size = Vector2(320, 22)
		vbox.add_child(bar)
	margin.add_child(vbox)
	panel.add_child(margin)
	center.add_child(panel)
	bars_layer.add_child(center)
	root.add_child(bars_layer)
	await _shot("barras")
	bars_layer.queue_free()

	# Menu de pausa e Configurações (#77), por cima da expedição.
	var pause: PauseMenu = PauseMenu.instance
	if pause != null and pause.open():
		await _shot("pausa")
		pause.settings_button.pressed.emit()
		await _shot("config_video")
		pause.settings_menu.tabs.current_tab = 1
		await _shot("config_audio")
		pause.settings_menu.tabs.current_tab = 2
		await _shot("config_controles")
		pause.settings_menu.tabs.current_tab = 3
		await _shot("config_jogabilidade")
		# Fim da aba (Idioma) com o contador de FPS ligado (sem gravar no arquivo do jogador).
		var page: ScrollContainer = pause.settings_menu.tabs.get_child(3) as ScrollContainer
		page.scroll_vertical = 10000
		SettingsManager.instance.set_section(SettingsManager.GAMEPLAY, {"show_fps": true}, false)
		pause.settings_menu.refresh()
		await _shot("config_jogabilidade_fim")
		SettingsManager.instance.set_section(SettingsManager.GAMEPLAY, {"show_fps": false}, false)
		pause.settings_menu.refresh()
		page.scroll_vertical = 0
		# Aviso de salvo (chamado direto: nada é gravado) e pergunta ao voltar com mudança.
		pause.settings_menu.tabs.current_tab = 0
		pause.settings_menu.show_saved_notice()
		await _shot("config_salvo")
		pause.settings_menu.tabs.current_tab = 3
		pause.settings_menu.fov_slider.value = 95.0
		pause.settings_menu.back_button.pressed.emit()
		await _shot("config_descartar")
		pause.settings_menu.discard_button.pressed.emit()
		pause.settings_button.pressed.emit()
		pause.settings_menu.tabs.current_tab = 0
		pause.close()

	# Avisos da aba Jogabilidade com o HUD a 150 % (sem gravar) e tela "Jogo concluído" (#77, #81).
	if pause != null and pause.open():
		SettingsManager.instance.set_section(SettingsManager.GAMEPLAY, {"hud_text_scale": 1.5}, false)
		pause.settings_button.pressed.emit()
		pause.settings_menu.refresh()
		pause.settings_menu.tabs.current_tab = SettingsMenu.TAB_GAMEPLAY
		pause.settings_menu.show_saved_notice()
		await _shot("config_jogabilidade_salvo_hud150")
		pause.settings_menu.show_saved_notice(SettingsMenu.HINTS_RESET_TEXT)
		await _shot("config_jogabilidade_dicas_hud150")
		print("RECT aviso ", _rect(pause.settings_menu.saved_notice), " botões ", _rect(pause.settings_menu.buttons_row), " abas ", _rect(pause.settings_menu.tabs))
		pause.settings_menu.hide_saved_notice()
		pause.settings_menu.tabs.current_tab = 0
		pause.close()
		SettingsManager.instance.set_section(SettingsManager.GAMEPLAY, {"hud_text_scale": 1.0}, false)
	if VictoryScreen.instance != null:
		var won: Dictionary = GameState.instance.get_snapshot()
		won["discovered_items"] = ["alianca_ouro", "moeda_antiga", "bussola"]
		won["found_secrets"] = GameState.SECRETS.slice(0, 7)
		won["seen_creatures"] = ["crab", "hermit_crab", "seagull", "mole", "bat"]
		won["intact_items"] = ["alianca_ouro", "bussola"]
		won["map_fragments"] = GameState.MAP_FRAGMENT_IDS.slice(0, 5)
		GameState.instance.load_snapshot(won)
		GameState.instance._host_report_boss_defeated("gold_colossus")
		# Sobras das capturas anteriores (toast do segredo do snapshot acima, barra de chefe).
		ui._clear_toasts()
		boss_hud.visible = false
		await _shot("jogo_concluido")
		print("RECT vitória ", _rect(VictoryScreen.instance.card))
		VictoryScreen.instance.credits_button.pressed.emit()
		await _shot("victory_credits")
		print("RECT créditos ", _rect(VictoryScreen.instance.card))
		VictoryScreen.instance.close()

	# Clima (#99): aviso e ícone no canto superior direito, com o cartão da expedição (Praia)
	# e sem os painéis do lobby (em expedição eles não existem).
	if WeatherHud.instance != null and WeatherManager.instance != null:
		var ui_layer: CanvasLayer = current_scene.get_node_or_null(^"UILayer") as CanvasLayer
		if ui_layer != null:
			ui_layer.visible = false
		WeatherManager.instance.force_event(WeatherManager.KIND_RAIN, 30.0)
		WeatherHud.instance.show_toast(WeatherHud.WARNING_TEXTS[WeatherManager.KIND_RAIN])
		await _shot("clima_aviso_icone")
		print("RECT clima ícone ", _rect(WeatherHud.instance.icon_panel), " aviso ", _rect(WeatherHud.instance.toast_panel))
		WeatherManager.instance.stop()
		if ui_layer != null:
			ui_layer.visible = true


	session.set("_current_map", null)
	ui._refresh_expedition_bar()
	menu.set_save_manager(null)
	fake.queue_free()
	boss_hud.queue_free()
	GameState.instance.reset_state()
	await _pad_shots()
	await _title_shots()
	quit()


## Controle (#102): aba Controles com as duas colunas, foco visível no menu de pausa com o
## comando ativo e uma dica com o botão do comando ("Segure [B]…").
func _pad_shots() -> void:
	var pause: PauseMenu = PauseMenu.instance
	if pause == null or InputDevice.instance == null:
		return
	InputDevice.instance.set_using_gamepad(true)
	if pause.open():
		await _shot("pausa_foco_comando")
		pause.settings_button.pressed.emit()
		pause.settings_menu.tabs.current_tab = SettingsMenu.TAB_CONTROLS
		await _shot("config_controles_comando")
		print("RECT controles ", _rect(pause.settings_menu))
		pause.settings_menu.tabs.current_tab = 0
		pause.close()
	var player: Player = (load("res://gameplay/player/player.tscn") as PackedScene).instantiate() as Player
	current_scene.add_child(player)
	for i in range(5):
		await process_frame
	var hints: Script = load("res://gameplay/player/player_hints.gd")
	hints.reset_all()
	# Sem os painéis do lobby (a dica aparece em expedição, sem eles por cima).
	var ui_layer: CanvasLayer = current_scene.get_node_or_null(^"UILayer") as CanvasLayer
	if ui_layer != null:
		ui_layer.visible = false
	player.show_hint("throw")
	await _shot("dica_comando")
	if ui_layer != null:
		ui_layer.visible = true
	player.queue_free()
	InputDevice.instance.set_using_gamepad(false)


## Tela inicial e slots (#100): sem save, com save, seletor (1 com ★, 1 ocupado, 1 vazio) e a
## confirmação de apagar. A cena do lobby sai antes (a tela inicial tem câmera e céu próprios).
func _title_shots() -> void:
	current_scene.queue_free()
	# Deixa acabar a chuva da captura do clima (as últimas gotas ainda caem).
	await create_timer(1.0).timeout
	var save: SaveManager = SaveManager.instance
	for n: int in range(1, SaveManager.SLOT_COUNT + 1):
		if FileAccess.file_exists(save.slot_path(n)):
			DirAccess.remove_absolute(save.slot_path(n))
	var title: TitleScreen = (load("res://world/title_screen.tscn") as PackedScene).instantiate() as TitleScreen
	title.auto_skip = false
	title.scene_change_enabled = false
	root.add_child(title)
	await _shot("titulo_sem_save")
	var slots: Array = [
		{"day": 23, "money": 48250, "found": 52, "completed": true, "at": 1760700000},
		{"day": 6, "money": 1840, "found": 11, "completed": false, "at": 1760640000},
	]
	for i: int in slots.size():
		var s: Dictionary = slots[i]
		var items: Array = []
		for k: int in int(s["found"]):
			items.append("item_%d" % k)
		var file: FileAccess = FileAccess.open(save.slot_path(i + 1), FileAccess.WRITE)
		file.store_string(JSON.stringify({"version": SaveManager.SAVE_VERSION, "saved_at": s["at"], "team_money": s["money"],
			"current_day": s["day"], "discovered_items": items, "game_completed": s["completed"],
			"defeated_bosses": [GameState.FINAL_BOSS_ID] if s["completed"] else []}))
		file.close()
	title.show_main()
	await _shot("titulo_com_save")
	title.show_slots("load")
	await _shot("titulo_slots")
	print("RECT titulo slots ", _rect(title.slots_panel))
	title.slot_delete_buttons[1].pressed.emit()
	await _shot("titulo_apagar")
	title.queue_free()

