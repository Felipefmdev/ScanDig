extends "res://ui/tests/hud_212_snapshots.gd"

## #212: contrato do saldo circular com Player real, sem mudar gameplay.
## A fixture herdada fornece arena, capturas e seed sem save real.
var _capture_money: bool = false


func _money_geometry(player: Player, expected: int) -> void:
	var hud: CanvasLayer = player.get_node(^"HUD") as CanvasLayer
	var arcs: Control = hud.get_node(^"HealthPanel/VitalsArcs") as Control
	var money: Label = arcs.get_node_or_null(^"MoneyValueLabel") as Label
	var food: Label = arcs.get_node(^"FoodValueLabel") as Label
	var bag: Control = hud.get_node(^"TopChips/BagChip") as Control
	_check(not bag.visible and not bag.is_visible_in_tree(), "BagChip oculto, inclusive propriedade visible")
	_check(is_instance_valid(player.bag_info_label) and is_instance_valid(player.session_info_label), "caminhos originais dos Labels preservados")
	_check(player.session_info_label.text.contains(MoneyFormat.money(expected)), "Player atualizou a fonte original do saldo")
	_check(money != null, "terceiro mostrador possui Label real MoneyValueLabel")
	if money == null:
		return
	_check(money.text == MoneyFormat.money(expected), "saldo completo sem titulo nem porcentagem: " + money.text)
	_check(arcs.has_method(&"money_ratio"), "mostrador expoe razao visual do saldo")
	if arcs.has_method(&"money_ratio"):
		var expected_ratio: float = clampf(float(expected) / 10000.0, 0.0, 1.0)
		_check(is_equal_approx(float(arcs.call(&"money_ratio")), expected_ratio), "arco acompanha saldo/%d com clamp: %.4f" % [10000, expected_ratio])
	_check(money.is_visible_in_tree(), "saldo circular visivel na arvore")
	_check(money.get_theme_font_size(&"font_size") == food.get_theme_font_size(&"font_size"), "saldo e fome usam mesma fonte e escala")
	var money_rect: Rect2 = money.get_global_rect()
	var food_rect: Rect2 = food.get_global_rect()
	_check(money_rect.position.x >= food_rect.end.x + 4.0, "saldo alto fica a direita da fome sem sobreposicao")
	_check(money.size.x >= money.get_combined_minimum_size().x, "saldo completo cabe sem corte ou abreviacao")
	_check(is_equal_approx(money_rect.position.y, food_rect.position.y), "saldo alinhado sob o terceiro mostrador")
	var panel: Control = hud.get_node(^"HealthPanel") as Control
	var panel_rect: Rect2 = panel.get_global_rect()
	_check(panel_rect.end.x >= money_rect.end.x - 0.5, "painel abrange a largura do saldo alto")
	_check(not panel_rect.intersects(player.hotbar.get_bar_rect(player.inventory.capacity)), "mostradores nao sobrepoem hotbar")
	_check(not panel_rect.intersects(SessionUI.instance.expedition_bar.get_global_rect()), "mostradores nao sobrepoem mapa/dia")
	_check(root.get_visible_rect().encloses(money_rect), "saldo dentro da viewport")
	print("MONEY text=%s font=%d rect=%s food=%s panel=%s" % [money.text, money.get_theme_font_size(&"font_size"), money_rect, food_rect, panel_rect])


func _capture_state(shot_name: String) -> void:
	if _capture_money:
		await _shot(shot_name)


## Usa o desenho de produção isolado de moeda/texto, para medir o arco efetivo.
## O renderer Dummy não produz pixels: este gate roda apenas na fixture com janela.
func _check_draw_boundary() -> void:
	if not _capture_money:
		return
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(224, 224)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var probe: MoneyDrawProbe = MoneyDrawProbe.new()
	viewport.add_child(probe)
	root.add_child(viewport)
	for balance: int in [0, 50, 51]:
		probe.ratio = float(balance) / 10000.0
		probe.queue_redraw()
		await _frames(3)
		await RenderingServer.frame_post_draw
		var pixels: Image = viewport.get_texture().get_image()
		var gold_pixels: int = 0
		for y: int in pixels.get_height():
			for x: int in pixels.get_width():
				var pixel: Color = pixels.get_pixel(x, y)
				if pixel.a > 0.9 and pixel.r > 0.7 and pixel.g > 0.45 and pixel.b < 0.4:
					gold_pixels += 1
		_check(gold_pixels == 0 if balance == 0 else gold_pixels > 0, "DESENHO saldo%d: pixels dourados=%d" % [balance, gold_pixels])
		var path: String = ProjectSettings.globalize_path(_out_dir + "draw_%d_%s.png" % [balance, _tag])
		_check(pixels.save_png(path) == OK, "captura isolada do arco: " + path)
	viewport.queue_free()
	await _frames(3)


func _run() -> void:
	_out_dir = "res://.bot_runs/qa212/money-dial/shots/"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out-dir="):
			_out_dir = arg.trim_prefix("--out-dir=") + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir))
	SaveManager.instance.use_test_save_dir("hud_money_dial")
	await _frames(2)
	_tag = "%dx%d" % [root.size.x, root.size.y]
	print("USERDATA %s SAVE %s PHYSICAL %s LOGICAL %s" % [OS.get_user_data_dir(), ProjectSettings.globalize_path(SaveManager.instance.save_path), root.size, root.get_visible_rect().size])
	var gs: GameState = GameState.instance
	var ui: SessionUI = SessionUI.instance
	var session: Node = root.get_node(^"CoreSession")
	session.set("_current_map", null)
	ui._synced_once = false
	gs.reset_state()
	ui._synced_once = false
	ui._clear_toasts()
	SettingsManager.instance.set_section(SettingsManager.GAMEPLAY, {"hud_text_scale": 1.5}, false)
	var arena: Node3D = _build_arena()
	root.add_child(arena)
	current_scene = arena
	var player: Player = PLAYER_SCENE.instantiate() as Player
	arena.add_child(player)
	await _frames(8)
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	var hud: CanvasLayer = player.get_node(^"HUD") as CanvasLayer
	session.set("_current_map", load("res://items/maps/praia.tres"))
	ui.loading_screen.hide()
	ui._refresh_expedition_bar()
	_seed_game_state_quietly({"team_money": 82})
	await _frames(4)
	_money_geometry(player, 82)
	SettingsManager.instance.set_section(SettingsManager.GAMEPLAY, {"hud_text_scale": 1.0}, false)
	await _frames(4)
	_money_geometry(player, 82)
	await _capture_state("01_money82")
	for balance: int in [1, 50, 51, 402, 5000, 10000]:
		gs.team_money = balance
		gs.money_changed.emit(balance)
		await _frames(4)
		_money_geometry(player, balance)
		await _capture_state("money_progress_%d" % balance)
	# Formatação executada nos dois locales, com NBSP e agrupamento real do MoneyFormat.
	var previous_locale: String = TranslationServer.get_locale()
	for locale: String in ["pt_BR", "en"]:
		TranslationServer.set_locale(locale)
		gs.team_money = 5000
		gs.money_changed.emit(5000)
		await _frames(4)
		_money_geometry(player, 5000)
		var grouped: String = "5,000" if locale == "en" else "5.000"
		_check(player.session_info_label.text.contains("R$" + MoneyFormat.NBSP + grouped), "fonte real com locale %s e NBSP" % locale)
	TranslationServer.set_locale(previous_locale)
	gs.money_changed.emit(gs.team_money)
	await _frames(4)
	await _check_draw_boundary()
	var original_count: int = player.inventory.get_count()
	# Sinal real: o Player deve atualizar seu Label sem chamada manual ao HUD.
	gs.team_money = 987650
	gs.money_changed.emit(gs.team_money)
	await _frames(4)
	_money_geometry(player, 987650)
	_check(player.inventory.get_count() == original_count, "mudanca de saldo preserva inventario")
	await _capture_state("02_money_high")
	SettingsManager.instance.set_section(SettingsManager.GAMEPLAY, {"hud_text_scale": 1.5}, false)
	PlayerHudStyle.apply(hud)
	PlayerHudStyle.apply(hud)
	await _frames(4)
	_money_geometry(player, 987650)
	_check(hud.get_node(^"HealthPanel").find_children("MoneyValueLabel", "Label", true, false).size() == 1, "reaplicacao nao duplica saldo")
	await _capture_state("03_money_high_scale15")
	# Limite alto do saldo: preserva digitos e layout sem reduzir fonte.
	gs.team_money = 2147483647
	gs.money_changed.emit(gs.team_money)
	await _frames(4)
	_money_geometry(player, gs.team_money)
	await _capture_state("04_money_billion_scale15")
	gs.team_money = 0
	gs.money_changed.emit(0)
	await _frames(4)
	_money_geometry(player, 0)
	_check(player.inventory.get_count() == original_count, "inventario continua intacto apos reaplicacoes")
	session.set("_current_map", null)
	ui._synced_once = false
	ui._clear_toasts()
	ui._refresh_expedition_bar()
	SettingsManager.instance.set_section(SettingsManager.GAMEPLAY, {"hud_text_scale": 1.0}, false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	arena.queue_free()
	await _frames(6)
	print("RESULT fails=%d" % _fails)
	quit(_fails)


class MoneyDrawProbe extends PlayerHudStyle.VitalsArcs:
	var ratio: float = 0.0

	func _init() -> void:
		for child: Node in get_children():
			if child is CanvasItem:
				(child as CanvasItem).hide()

	func _draw() -> void:
		_draw_dial(Vector2(112.0, 112.0), 80.0, 4.0, ratio, UiPalette.GOLD, null, false)
