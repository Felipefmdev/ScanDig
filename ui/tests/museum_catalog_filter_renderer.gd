extends SceneTree
## Run with a renderer to check focus, navigation, and optionally capture the Museum.


func _initialize() -> void:
	_run.call_deferred()


var _fails: int = 0


func _check(condition: bool, description: String) -> void:
	if not condition:
		_fails += 1
		print("FAIL " + description)


func _frames(count: int = 5) -> void:
	for frame: int in count:
		await process_frame


func _press(event: InputEvent) -> void:
	event.set("pressed", true)
	Input.parse_input_event(event)
	await _frames()
	var release: InputEvent = event.duplicate() as InputEvent
	release.set("pressed", false)
	Input.parse_input_event(release)
	await _frames()


func _key(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	await _press(event)


func _pad(button: JoyButton) -> void:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = button
	await _press(event)


func _capture(name: String) -> void:
	if OS.get_cmdline_user_args().has("--capture") and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var path: String = "user://museum225-%s-%s.png" % [str(root.size), name]
		_check(root.get_texture().get_image().save_png(path) == OK, "captura " + name)


func _run() -> void:
	SaveManager.instance.use_test_save_dir("museum225")
	change_scene_to_file("res://world/lobby_base.tscn")
	await _frames(15)
	var base: BaseStationUI = current_scene.get_node(^"UILayer/BaseStationUI") as BaseStationUI
	base.tab_container.current_tab = 1
	await _frames()
	var list: ItemList = base.museum_item_list
	var total: int = list.item_count
	var state: GameState = GameState.instance
	state.request_report_discovery("anel_do_poco", 0)
	await _frames()
	var hud: HUD = current_scene.get_node(^"HUD") as HUD
	var progress: String = hud.museum_label.text
	var filter: OptionButton = base.find_child("MuseumCatalogFilter", true, false) as OptionButton
	_check(filter != null, "Museu oferece filtro de catálogo")
	if filter == null:
		await _capture("antes")
		_finish()
		return
	_check(total > 1 and filter.selected == 0 and list.item_count == total, "Todos exibe o catálogo inteiro")
	await _capture("todos")
	await _key(KEY_TAB)
	_check(filter.has_focus(), "Tab chega ao filtro a partir de Ver museu")
	var scroll: ScrollContainer = base.tab_container.get_current_tab_control() as ScrollContainer
	_check(scroll.get_global_rect().encloses(filter.get_global_rect()), "filtro inteiro é visível ao receber foco")
	await _key(KEY_ENTER)
	_check(filter.get_popup().visible, "Enter abre as opções")
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	_check(filter.selected == 1 and list.item_count == 1 and list.get_item_text(0).contains(I18n.t("[DESCOBERTO]")), "Descobertos mostra apenas o item já descoberto")
	_check(filter.has_focus(), "teclado mantém o foco após aplicar filtro")
	await _capture("descobertos")
	base.focus_home()
	await _frames()
	await _pad(JOY_BUTTON_DPAD_DOWN)
	_check(filter.has_focus(), "direcional chega ao filtro a partir de Ver museu")
	await _pad(JOY_BUTTON_A)
	_check(filter.get_popup().visible, "A abre o filtro no controle")
	await _pad(JOY_BUTTON_DPAD_DOWN)
	await _pad(JOY_BUTTON_A)
	_check(filter.selected == 2 and list.item_count == total - 1, "Pendentes mostra somente itens faltantes")
	if list.item_count > 0:
		_check(not list.get_item_text(0).contains(I18n.t("[DESCOBERTO]")), "Pendentes não mostra linha descoberta")
	_check(filter.has_focus() and hud.museum_label.text == progress, "controle devolve foco e progresso geral é estável")
	await _capture("pendentes")
	state.request_report_discovery("anel_sinete", 0)
	await _frames()
	_check(filter.selected == 2 and list.item_count == total - 2, "nova descoberta atualiza o filtro ativo")
	state.discovered_items.clear()
	state.collection_updated.emit(0, total)
	base.museum_feedback_label.text = ""
	filter.select(1)
	filter.item_selected.emit(1)
	await _frames()
	var empty: Label = base.find_child("MuseumCatalogEmpty", true, false) as Label
	_check(empty != null and empty.is_visible_in_tree() and not empty.text.is_empty() and not list.visible, "estado vazio mostra mensagem")
	await _capture("vazio")
	TranslationServer.set_locale("en")
	await _frames()
	_check(filter.get_item_text(1) == "Discovered" and filter.selected == 1 and empty != null and empty.text == "No items in this filter.", "mudança de idioma mantém o filtro ativo")
	_finish()


func _finish() -> void:
	print("RESULT fails=%d" % _fails)
	quit(0 if _fails == 0 else 1)
