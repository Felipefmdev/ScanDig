## Fixture de validação visual e funcional do HUD compacto (#212) com ator Player real.
## Executar SOMENTE sob reserva explícita de engine concedida pela Rede e Sistemas, com APPDATA isolado:
## 1280x720:
##   $env:APPDATA='C:/Projeto jogo/ScanDig/.bot_runs/qa212/hud/appdata_720'; & 'C:/Godot/Godot_v4.3-stable_win64_console.exe' --path . --resolution 1280x720 --windowed --script res://ui/tests/hud_212_snapshots.gd
## 1920x1080:
##   $env:APPDATA='C:/Projeto jogo/ScanDig/.bot_runs/qa212/hud/appdata_1080'; & 'C:/Godot/Godot_v4.3-stable_win64_console.exe' --path . --resolution 1920x1080 --windowed --script res://ui/tests/hud_212_snapshots.gd
extends SceneTree

const DEFAULT_OUT_DIR: String = "res://.bot_runs/qa212/hud/"
const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/player.tscn")
const CATALOG_8_IDS: Array[String] = [
	"moeda_antiga",
	"concha_dourada",
	"alianca_ouro",
	"bussola_antiga",
	"relogio_bolso_antigo",
	"calice_prata",
	"dente_mamute",
	"engrenagem_alienigena",
]

var _out_dir: String = DEFAULT_OUT_DIR
var _tag: String = ""
var _fails: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_fails += 1


func _shot(shot_name: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	var abs_path: String = ProjectSettings.globalize_path(_out_dir + shot_name + "_" + _tag + ".png")
	var img: Image = root.get_texture().get_image()
	var img_size: Vector2i = img.get_size() if img != null else Vector2i.ZERO
	var err: Error = img.save_png(abs_path) if img != null else ERR_UNAVAILABLE
	print("SHOT %s err=%d size=%s root_size=%s" % [abs_path, err, img_size, root.size])
	_check(err == OK and img_size == root.size, "captura gravada em resolução física exata (%s == %s): %s_%s" % [img_size, root.size, shot_name, _tag])


func _build_arena() -> Node3D:
	var arena: Node3D = Node3D.new()
	arena.name = "Hud212Arena"
	var env_node: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.76, 0.70, 0.56)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.95, 0.92, 0.85)
	env.ambient_light_energy = 0.9
	env_node.environment = env
	arena.add_child(env_node)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, 35.0, 0.0)
	arena.add_child(sun)

	var floor_body: StaticBody3D = StaticBody3D.new()
	var col: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(40.0, 1.0, 40.0)
	col.shape = box
	col.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(col)
	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var plane: BoxMesh = BoxMesh.new()
	plane.size = Vector3(40.0, 1.0, 40.0)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.84, 0.76, 0.58)
	plane.material = mat
	mesh_inst.mesh = plane
	mesh_inst.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(mesh_inst)
	arena.add_child(floor_body)
	return arena


func _seed_game_state_quietly(snapshot: Dictionary) -> void:
	var session: Node = root.get_node_or_null(^"CoreSession")
	var ui: SessionUI = SessionUI.instance
	var prev_map: Variant = session.get("_current_map") if session != null else null
	if session != null:
		session.set("_current_map", null)
	ui._synced_once = false
	GameState.instance.load_snapshot(snapshot)
	ui._synced_once = false
	ui._clear_toasts()
	if session != null:
		session.set("_current_map", prev_map)
	ui._refresh_expedition_bar()


func _fill_inventory(player: Player, count: int, override_size_category: int = -1) -> void:
	player.inventory.take_all()
	for i: int in count:
		var id: String = CATALOG_8_IDS[i % CATALOG_8_IDS.size()]
		var path: String = "res://items/catalog/%s.tres" % id
		var exists: bool = ResourceLoader.exists(path)
		_check(exists, "recurso real do catálogo existe: %s" % path)
		if not exists:
			continue
		var data: ItemData = load(path) as ItemData
		_check(data != null, "ItemData carregado: %s" % id)
		if data != null:
			var item_ref: ItemData = data
			if override_size_category >= 0:
				item_ref = data.duplicate() as ItemData
				item_ref.size_category = override_size_category as ItemData.SizeCategory
			var added: bool = player.inventory.add_item(CarriedItem.create(item_ref, item_ref.base_value, 1.0, false))
			_check(added, "item %d/%d adicionado à mochila (%s)" % [i + 1, count, id])
	player.clear_messages()
	_check(player.inventory.get_count() == count, "contagem efetiva da mochila == %d (atual=%d, cap=%d)" % [count, player.inventory.get_count(), player.inventory.capacity])
	_check(player.hotbar._slot_panels.size() == player.inventory.capacity, "hotbar construiu %d slots para capacidade %d" % [player.hotbar._slot_panels.size(), player.inventory.capacity])


func _assert_hud_geometry(tag: String, player: Player, ui: SessionUI) -> void:
	var hud: CanvasLayer = player.get_node(^"HUD") as CanvasLayer
	var hp_panel: Control = hud.get_node(^"HealthPanel") as Control
	var chips: Control = hud.get_node(^"TopChips") as Control
	var threat: Control = hud.get_node(^"ThreatPanel") as Control
	var hotbar: Hotbar = hud.get_node(^"Hotbar") as Hotbar
	var exp_bar: Control = ui.expedition_bar
	var view: Vector2 = root.get_visible_rect().size
	var margin: Vector2 = view * 0.05
	var hp_rect: Rect2 = hp_panel.get_global_rect()
	var chips_rect: Rect2 = chips.get_global_rect()
	var threat_rect: Rect2 = threat.get_global_rect()
	var hotbar_rect: Rect2 = hotbar.get_bar_rect(player.inventory.capacity)
	var exp_rect: Rect2 = exp_bar.get_global_rect()

	print("RECTS [%s] root=%s view=%s margin5%%=%s hp=%s chips=%s threat=%s(vis=%s) hotbar(%d/%d)=%s exp=%s(vis=%s)" % [
		tag,
		root.size,
		view,
		margin,
		hp_rect,
		chips_rect,
		threat_rect,
		threat.visible,
		player.inventory.get_count(),
		player.inventory.capacity,
		hotbar_rect,
		exp_rect,
		exp_bar.visible,
	])

	# Asserção de proporção 16:9 sob stretch canvas_items/expand e visibilidade da barra de expedição:
	_check(is_equal_approx(view.x / maxf(view.y, 1.0), 16.0 / 9.0), "%s: viewport lógica 16:9 (%s)" % [tag, view])
	_check(exp_bar.is_visible_in_tree(), "%s: ExpeditionBar visível na árvore (is_visible_in_tree)" % tag)

	# Gates de margem segura 5% (safe bounds independentes do helper sob teste):
	_check(hp_rect.position.x >= margin.x - 1.5 and hp_rect.end.y <= view.y - margin.y + 1.5, "%s: HealthPanel respeita margem segura 5%% (%s)" % [tag, hp_rect])
	_check(chips_rect.position.x >= margin.x - 1.5 and chips_rect.position.y >= margin.y - 1.5, "%s: TopChips respeita margem segura 5%% (%s)" % [tag, chips_rect])
	_check(exp_rect.end.x <= view.x - margin.x + 1.5 and exp_rect.end.y <= view.y - margin.y + 1.5, "%s: ExpeditionBar respeita margem segura 5%% (%s)" % [tag, exp_rect])
	if threat.visible:
		_check(threat_rect.position.x >= margin.x - 1.5 and threat_rect.position.y >= margin.y - 1.5, "%s: ThreatPanel respeita margem segura 5%% (%s)" % [tag, threat_rect])

	# Gates de colisão entre elementos do HUD:
	_check(chips_rect.end.y <= hp_rect.position.y + 0.5 and not chips_rect.intersects(hp_rect), "%s: TopChips acima e sem colidir com HealthPanel" % tag)
	_check(not hp_rect.intersects(hotbar_rect), "%s: HealthPanel não colide com Hotbar (%d slots)" % [tag, player.inventory.capacity])
	_check(not chips_rect.intersects(hotbar_rect), "%s: TopChips não colide com Hotbar (%d slots)" % [tag, player.inventory.capacity])
	_check(not hotbar_rect.intersects(exp_rect), "%s: Hotbar (%d slots) não colide com ExpeditionBar" % [tag, player.inventory.capacity])
	_check(not hp_rect.intersects(exp_rect) and not chips_rect.intersects(exp_rect), "%s: grupo inferior esquerdo não colide com ExpeditionBar" % tag)
	if threat.visible:
		_check(not threat_rect.intersects(chips_rect) and not threat_rect.intersects(hp_rect) and not threat_rect.intersects(exp_rect), "%s: ThreatPanel não colide com vitais/chips/ExpeditionBar" % tag)
	if ui.toast_panel.visible:
		var toast_rect: Rect2 = ui.toast_panel.get_global_rect()
		_check(not toast_rect.intersects(hp_rect) and not toast_rect.intersects(chips_rect) and not toast_rect.intersects(hotbar_rect) and not toast_rect.intersects(exp_rect), "%s: ToastPanel não colide com vitais/chips/hotbar/ExpeditionBar" % tag)
		if threat.visible:
			_check(not toast_rect.intersects(threat_rect), "%s: ToastPanel não colide com ThreatPanel" % tag)


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out-dir="):
			_out_dir = arg.trim_prefix("--out-dir=")
			if not _out_dir.ends_with("/"):
				_out_dir += "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir))
	SaveManager.instance.use_test_save_dir("hud_212_snapshots")
	await _frames(2)
	var view_size: Vector2i = root.size
	var logical_view: Vector2 = root.get_visible_rect().size
	_tag = "%dx%d" % [view_size.x, view_size.y]
	var user_data_dir: String = OS.get_user_data_dir()
	var save_path_rel: String = SaveManager.instance.save_path
	var save_path_abs: String = ProjectSettings.globalize_path(save_path_rel)
	print("USERDATA %s save_path=%s abs=%s tag=%s root_size=%s logical_view=%s out_dir=%s" % [user_data_dir, save_path_rel, save_path_abs, _tag, view_size, logical_view, _out_dir])
	_check(save_path_rel == "user://test_saves/hud_212_snapshots/scandig_save.json", "SaveManager.save_path isolado em test_saves (%s)" % save_path_rel)
	_check(save_path_abs.begins_with(user_data_dir), "save_path absoluto dentro de OS.get_user_data_dir (%s)" % save_path_abs)
	_check(view_size == Vector2i(1280, 720) or view_size == Vector2i(1920, 1080), "resolução física da janela 16:9 alvo (720p ou 1080p): %s" % [view_size])
	_check(is_equal_approx(logical_view.x / maxf(logical_view.y, 1.0), 16.0 / 9.0), "viewport lógica 16:9 sob stretch canvas_items/expand: %s" % [logical_view])

	var sm: SettingsManager = SettingsManager.instance
	var gs: GameState = GameState.instance
	var ui: SessionUI = SessionUI.instance
	var session: Node = root.get_node_or_null(^"CoreSession")
	if session != null:
		session.set("_current_map", null)
	ui._synced_once = false
	gs.reset_state()
	ui._synced_once = false
	ui._clear_toasts()
	_check(not ui._should_show_toast(), "seed fora de expedição bloqueia toasts automáticos")

	# Validação 1: escala automática settings_hud_text INICIAL em 1.5x (antes do Player entrar na árvore):
	sm.set_section(SettingsManager.GAMEPLAY, {"hud_text_scale": 1.5}, false)

	var arena: Node3D = _build_arena()
	root.add_child(arena)
	current_scene = arena

	var player: Player = PLAYER_SCENE.instantiate() as Player
	arena.add_child(player)
	await _frames(8)
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)

	var hud: CanvasLayer = player.get_node(^"HUD") as CanvasLayer
	var hp_panel: Control = hud.get_node(^"HealthPanel") as Control
	var top_chips: Control = hud.get_node(^"TopChips") as Control
	var threat_panel: Control = hud.get_node(^"ThreatPanel") as Control
	var arcs: PlayerHudStyle.VitalsArcs = hud.get_node_or_null(^"HealthPanel/VitalsArcs") as PlayerHudStyle.VitalsArcs
	_check(hud.is_in_group(SettingsManager.HUD_TEXT_GROUP), "HUD do Player registrado em settings_hud_text")
	_check(arcs != null, "VitalsArcs presente no Player real")
	var base_hp_font: int = int(arcs.hp_value_label().get_meta(PlayerHudStyle.SETTINGS_BASE_FONT_META, 13))
	var base_money_font: int = int(player.session_info_label.get_meta(PlayerHudStyle.SETTINGS_BASE_FONT_META, 18))
	_check(arcs.hp_value_label().get_theme_font_size(&"font_size") == roundi(float(base_hp_font) * 1.5), "escala automática INICIAL 1.5x aplicada ao spawnar Player em HpValueLabel (%d -> %d)" % [base_hp_font, arcs.hp_value_label().get_theme_font_size(&"font_size")])
	_check(player.session_info_label.get_theme_font_size(&"font_size") == roundi(float(base_money_font) * 1.5), "escala automática INICIAL 1.5x aplicada ao spawnar Player em MoneyChip (%d -> %d)" % [base_money_font, player.session_info_label.get_theme_font_size(&"font_size")])

	# Transição em runtime 1.5x -> 1.0x para os estados 01..05:
	sm.set_section(SettingsManager.GAMEPLAY, {"hud_text_scale": 1.0}, false)
	await _frames(4)
	_check(arcs.hp_value_label().get_theme_font_size(&"font_size") == base_hp_font, "mudança posterior 1.5x -> 1.0x restaura HpValueLabel (%d)" % arcs.hp_value_label().get_theme_font_size(&"font_size"))

	if session != null:
		session.set("_current_map", load("res://items/maps/praia.tres"))
	ui.loading_screen.hide()
	ui._refresh_expedition_bar()
	await _frames(4)

	# Estado 01: Normal + Hotbar Vazia (0/3 slots) em escala 1.0:
	_seed_game_state_quietly({"team_money": 250, "upgrade_levels": {"backpack": 0}})
	player._apply_backpack_capacity()
	_fill_inventory(player, 0)
	_check(player.inventory.capacity == 3 and player.inventory.is_empty(), "estado 01: hotbar vazia (0/3 slots)")
	player.health = 100.0
	player._on_health_changed(100.0, player.max_health)
	player.set_hunger(100.0)
	player.threat_bar.value = 0.0
	ui._clear_toasts()
	await _frames(4)
	_check(not threat_panel.visible, "estado 01: ThreatPanel oculto com ameaça 0")
	_check(not ui.leave_button.is_visible_in_tree(), "estado 01 (offline): LeaveButton oculto sem sessão online real")
	_assert_hud_geometry("01_normal_s10", player, ui)
	await _shot("01_normal_s10")

	# Estado 02: Vida Baixa (20/100 <= 25%) em escala 1.0:
	player.health = 20.0
	player._on_health_changed(20.0, player.max_health)
	await _frames(4)
	_check(arcs.hp_value_label().text.begins_with("!"), "estado 02: prefixo não cromático '!' em HpValueLabel (%s)" % arcs.hp_value_label().text)
	_check(arcs.status_text().contains("!♥"), "estado 02: alerta !♥ em StatusLabel (%s)" % arcs.status_text())
	_assert_hud_geometry("02_low_hp_s10", player, ui)
	await _shot("02_low_hp_s10")

	# Estado 03: Fome Baixa (18/100) + Peso Parcial (MEDIO) e Sobrecarga Real (GRANDE) em escala 1.0:
	player.health = 75.0
	player._on_health_changed(75.0, player.max_health)
	player.set_hunger(18.0)
	_fill_inventory(player, 2, ItemData.SizeCategory.MEDIO)
	await _frames(2)
	_check(not player.is_overloaded() and player.backpack_weight_multiplier() < 1.0, "estado 03a: itens MEDIO reduzem backpack_weight_multiplier (%.2f) sem is_overloaded" % player.backpack_weight_multiplier())
	_check(arcs.status_text().contains("🎒 -"), "estado 03a: StatusLabel preserva indicador percentual de peso (%s)" % arcs.status_text())
	_fill_inventory(player, 3, ItemData.SizeCategory.GRANDE)
	await _frames(4)
	_check(player.is_overloaded() and player.backpack_weight_multiplier() < 1.0, "estado 03b: itens GRANDE ativam is_overloaded() e reduzem backpack_weight_multiplier (%.2f)" % player.backpack_weight_multiplier())
	_check(arcs.food_value_label().text.begins_with("!"), "estado 03b: prefixo '!' em FoodValueLabel (%s)" % arcs.food_value_label().text)
	_check(arcs.status_text().contains("(com fome!)"), "estado 03b: StatusLabel preserva '(com fome!)' (%s)" % arcs.status_text())
	_check(arcs.status_text().contains("pesado"), "estado 03b: StatusLabel preserva '🎒 pesado' (%s)" % arcs.status_text())
	_assert_hud_geometry("03_low_hunger_weight_s10", player, ui)
	await _shot("03_low_hunger_weight_s10")

	# Estado 04: Ameaça Contextual (72/100) + Preview Explícito de Botão Online de Saída + Toast de Expedição (escala 1.0):
	threat_panel.set_meta(&"allow_contextual_threat_without_meter", true)
	player.threat_bar.value = 72.0
	A11y.tint_bar(player.threat_bar, A11y.threat_role(3))
	ui.leave_button.visible = true
	print("ONLINE_LEAVE_PREVIEW [04_threat_toast_online_s10] leave_button.visible=true (preview visual declarado sem rede real; _is_online=%s)" % [ui._is_online()])
	ui._synced_once = true
	ui._enqueue_toast("Missão concluída: Primeiros Achados (+R$ 150)", true)
	await _frames(4)
	_check(threat_panel.visible, "estado 04: ThreatPanel visível com ameaça 72")
	_check(ui.expedition_bar.is_visible_in_tree() and ui.leave_button.is_visible_in_tree(), "estado 04: ExpeditionBar e preview de LeaveButton visíveis na árvore (is_visible_in_tree)")
	_check(ui.toast_panel.visible, "estado 04: ToastPanel visível")
	_assert_hud_geometry("04_threat_toast_online_s10", player, ui)
	await _shot("04_threat_toast_online_s10")

	# Aguarda expiração REAL do SceneTreeTimer (SessionUI.TOAST_SEC = 3.0s) para não vazar timer no teardown:
	ui._synced_once = false
	await create_timer(SessionUI.TOAST_SEC + 0.25, true, false, true).timeout
	await _frames(4)
	_check(not ui.toast_panel.visible and ui._toast_queue.is_empty(), "estado 04: SceneTreeTimer de 3s do toast expirou naturalmente sem pendência")

	# Estado 05: Mochila Cheia 8/8 Slots Reais + Dinheiro Alto + Radar Real (3D) + Preview Radar 2D Declarado (escala 1.0):
	_seed_game_state_quietly({"team_money": 987650, "upgrade_levels": {"backpack": 5}})
	player._apply_backpack_capacity()
	_fill_inventory(player, 8)
	player._update_session_hud()
	_check(player.inventory.capacity == 8 and player.inventory.get_count() == 8 and player.inventory.is_full(), "estado 05: 8/8 slots reais preenchidos e mochila cheia")
	_check(player.bag_info_label.text.contains("8/8"), "estado 05: BagChip exibe 8/8 (%s)" % player.bag_info_label.text)

	# Ativa detector REAL de produção (visor 3D em MetalDetector/RadarViewport) e compara com geometria 2D:
	player.detector.set_active(true)
	var view: Vector2 = root.get_visible_rect().size
	var prod_debug_radar_rect: Rect2 = Rect2(24.0, view.y - 330.0, 220.0, 244.0)
	_check(player.detector.is_active() and player.detector.radar_viewport != null and not player.detector.debug_screen_radar, "estado 05: radar REAL de produção usa SubViewport 3D (%s) com debug_screen_radar=false" % [player.detector.radar_viewport.size])

	# Preview 2D explícito (declarado como preview, não integração de produção) acima de TopChips:
	var preview_radar: DetectorRadar = DetectorRadar.new()
	preview_radar.name = "PreviewRadar2D_NotProd"
	preview_radar.theme = preload("res://ui/theme/scandig_theme.tres")
	preview_radar.detector = player.detector
	preview_radar.anchor_left = 0.05
	preview_radar.anchor_right = 0.05
	preview_radar.anchor_top = 0.95
	preview_radar.anchor_bottom = 0.95
	preview_radar.offset_left = 0.0
	preview_radar.offset_right = 170.0
	preview_radar.offset_bottom = top_chips.offset_top - 8.0
	preview_radar.offset_top = preview_radar.offset_bottom - 170.0
	hud.add_child(preview_radar)
	await _frames(4)
	var preview_rect: Rect2 = preview_radar.get_global_rect()
	print("RADAR_COMPARE [%s] prod_3d_viewport=%s prod_debug_screen_radar_off_rect=%s(colide_vitals=%s) preview_2d_rect=%s" % [
		_tag,
		player.detector.radar_viewport.size,
		prod_debug_radar_rect,
		prod_debug_radar_rect.intersects(top_chips.get_global_rect()) or prod_debug_radar_rect.intersects(hp_panel.get_global_rect()),
		preview_rect,
	])
	_check(not preview_rect.intersects(top_chips.get_global_rect()) and not preview_rect.intersects(hp_panel.get_global_rect()) and not preview_rect.intersects(threat_panel.get_global_rect()), "estado 05: PreviewRadar2D_NotProd não colide com ThreatPanel/TopChips/HealthPanel")
	_assert_hud_geometry("05_full_8slots_radar_s10", player, ui)
	await _shot("05_full_8slots_radar_s10")

	# Estado 06: Mudança posterior em runtime 1.0x -> 1.5x via settings_hud_text (testa tanto 8/8 cheio quanto 0/3 vazio):
	sm.set_section(SettingsManager.GAMEPLAY, {"hud_text_scale": 1.5}, false)
	await _frames(4)
	preview_radar.offset_bottom = top_chips.offset_top - 8.0
	preview_radar.offset_top = preview_radar.offset_bottom - 170.0
	await _frames(2)
	_check(arcs.hp_value_label().get_theme_font_size(&"font_size") == roundi(float(base_hp_font) * 1.5), "estado 06: mudança posterior 1.0x -> 1.5x escala HpValueLabel (%d -> %d)" % [base_hp_font, arcs.hp_value_label().get_theme_font_size(&"font_size")])
	_check(player.session_info_label.get_theme_font_size(&"font_size") == roundi(float(base_money_font) * 1.5), "estado 06: mudança posterior 1.0x -> 1.5x escala MoneyChip")
	_assert_hud_geometry("06_full_scale15", player, ui)
	await _shot("06_full_scale15")

	# Valida também geometria em 1.5x com hotbar vazia (0/3 slots):
	_seed_game_state_quietly({"team_money": 987650, "upgrade_levels": {"backpack": 0}})
	player._apply_backpack_capacity()
	_fill_inventory(player, 0)
	player._update_session_hud()
	await _frames(4)
	_assert_hud_geometry("06b_empty_hotbar_scale15", player, ui)

	# Teardown limpo sem gerar novo toast na restauração:
	preview_radar.queue_free()
	player.detector.set_active(false)
	player.clear_messages()
	sm.set_section(SettingsManager.GAMEPLAY, {"hud_text_scale": 1.0}, false)
	if session != null:
		session.set("_current_map", null)
	ui._synced_once = false
	ui._clear_toasts()
	ui.leave_button.visible = false
	ui._refresh_expedition_bar()
	gs.reset_state()
	ui._synced_once = false
	ui._clear_toasts()
	_check(not ui.toast_panel.visible and ui._toast_queue.is_empty(), "teardown: nenhum novo toast gerado na restauração")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	arena.queue_free()
	await _frames(6)
	print("RESULT fails=%d" % _fails)
	quit(_fails)
