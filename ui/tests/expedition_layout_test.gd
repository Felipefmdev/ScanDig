extends SceneTree

var _fails: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for frame: int in count:
		await process_frame


func _check(condition: bool, description: String) -> void:
	print(("PASS " if condition else "FAIL ") + description)
	if not condition:
		_fails += 1


func _check_page(base: BaseStationUI, context: String) -> void:
	var page: ScrollContainer = base.tab_container.get_current_tab_control() as ScrollContainer
	var list: ItemList = base.map_list
	var list_rect: Rect2 = list.get_global_rect()
	var viewport: Rect2 = page.get_global_rect()
	_check(page.scroll_vertical == 0 and viewport.encloses(base.depart_btn.get_global_rect()), context + " Partir inteiro sem rolar")
	for index: int in list.item_count:
		var row: Rect2 = list.get_item_rect(index)
		row.position += list_rect.position - Vector2(0.0, list.get_v_scroll_bar().value)
		_check(list_rect.encloses(row) and viewport.encloses(row), context + " linha %d inteira" % index)
	if base.map_status_label.visible:
		_check(viewport.encloses(base.map_status_label.get_global_rect()), context + " motivo visível")
	if base.night_check.visible:
		_check(viewport.encloses(base.night_check.get_global_rect()), context + " opção noturna visível")


func _check_navigation(base: BaseStationUI) -> void:
	var list: ItemList = base.map_list
	var point: Vector2 = list.get_global_rect().position + list.get_item_rect(1).get_center()
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = point
	click.pressed = true
	root.push_input(click, true)
	click.pressed = false
	root.push_input(click, true)
	_check(list.is_selected(1) and base.depart_btn.disabled, "clique seleciona rota bloqueada")

	list.select(0)
	list.item_selected.emit(0)
	await _frames(3)
	base.night_check.grab_focus()
	_check(base.night_check.has_focus(), "Noite recebe foco")
	var dpad: InputEventJoypadButton = InputEventJoypadButton.new()
	dpad.button_index = JOY_BUTTON_DPAD_RIGHT
	dpad.pressed = true
	root.push_input(dpad)
	_check(base.depart_btn.has_focus(), "direcional do comando move de Noite para Partir")


func _run() -> void:
	SaveManager.instance.use_test_save_dir("expedition_layout_test")
	SessionManager.launch_mode = SessionManager.LAUNCH_SOLO
	change_scene_to_file(SessionManager.LOBBY_SCENE)
	await _frames(12)
	var base: BaseStationUI = current_scene.get_node(^"UILayer/BaseStationUI") as BaseStationUI
	base.tab_container.current_tab = 2
	_check(base.map_list.item_count == 5, "cinco destinos disponíveis na lista")
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = resolution
		for locale: String in ["pt_BR", "en"]:
			TranslationServer.set_locale(locale)
			for scale_factor: float in [1.0, 1.3]:
				root.content_scale_factor = scale_factor
				for map_index: int in range(base.map_list.item_count):
					base.map_list.select(map_index)
					base.map_list.item_selected.emit(map_index)
					await _frames(5)
					var context: String = "%s %s %.1f rota=%d" % [resolution, locale, scale_factor, map_index]
					_check(base.night_check.visible == (map_index == 0), context + " disponibilidade da opção noturna")
					_check(base.map_status_label.visible == (map_index != 0), context + " disponibilidade do motivo")
					_check_page(base, context)
	root.size = Vector2i(1280, 720)
	await _frames(5)
	await _check_navigation(base)
	GameState.instance.request_report_boss_defeated("king_crab")
	base.map_list.select(1)
	base.map_list.item_selected.emit(1)
	await _frames(5)
	_check(base.map_status_label.text.contains("→"), "motivo de passagem informa origem e destino")
	_check_page(base, "motivo com passagem em 720p a 130%")
	base.map_list.select(0)
	base.map_list.item_selected.emit(0)
	base._on_expedition_start_failed("O destino não terminou de carregar. Tente novamente pela base.")
	await _frames(5)
	var page: Control = base.tab_container.get_current_tab_control()
	_check(base.expedition_feedback_label.is_visible_in_tree() and page.get_global_rect().encloses(base.expedition_feedback_label.get_global_rect()), "mensagem de falha aparece inteira em 720p a 130%")
	GameState.instance.request_report_boss_defeated("ancient_guardian")
	_check(GameState.instance.open_boss_passage("geleira") == OK, "fixture libera a Geleira Eterna")
	base.map_list.select(3)
	base.map_list.item_selected.emit(3)
	base.night_check.button_pressed = true
	await _frames(5)
	_check(base.is_night_selected() and not base.depart_btn.disabled, "expedição noturna disponível na Geleira Eterna")
	_check_page(base, "destino longo à noite em 720p a 130%")
	GameState.instance.reset_state()
	print("RESULT fails=%d" % _fails)
	quit(_fails)
