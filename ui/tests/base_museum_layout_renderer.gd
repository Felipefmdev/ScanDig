extends SceneTree
## Renderer real obrigatorio antes do merge; headless nao constitui aceite.
## Godot --path . --windowed --resolution 1280x720 --script res://ui/tests/base_museum_layout_renderer.gd
## Gate: exit0, sem SCRIPT/Parse Error ou FAIL; CHECKS count=36 e RESULT fails=0.
## #215: catalogo legivel, uma rolagem, progresso separado e dev opt-in.
const BASE_SCENE: PackedScene = preload("res://ui/base_station_ui.tscn")
const DEV_NAMES: Array[String] = ["SimLabel", "SimSeparator", "ItemSelectBox", "SellItemButton", "RegisterItemButton"]
var _checks: int = 0
var _fails: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	_checks += 1
	_fails += 0 if ok else 1
	print(("PASS " if ok else "FAIL ") + message)


func _frames(count: int = 4) -> void:
	for frame: int in count:
		await process_frame


func _key(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(2)
	event = event.duplicate() as InputEventKey
	event.pressed = false
	Input.parse_input_event(event)
	await _frames()


func _run() -> void:
	SaveManager.instance.use_test_save_dir("museum_layout215")
	var packed: Control = BASE_SCENE.instantiate() as Control
	for id: String in DEV_NAMES:
		var control: Control = packed.find_child(id, true, false) as Control
		_check(control != null and not control.visible, "cena oculta simulacao por padrao: " + id)
		if control is BaseButton:
			_check(control.focus_mode == Control.FOCUS_NONE, "cena remove simulacao da cadeia de foco: " + id)
	packed.free()
	change_scene_to_file("res://world/lobby_base.tscn")
	await _frames(12)
	var ui: BaseStationUI = current_scene.get_node(^"UILayer/BaseStationUI") as BaseStationUI
	var state: GameState = GameState.instance
	var money_before: int = state.team_money
	var tabs: TabContainer = ui.tab_container
	tabs.current_tab = 1
	await _frames()
	var outer: ScrollContainer = tabs.get_current_tab_control() as ScrollContainer
	var list: ItemList = ui.museum_item_list
	var secrets: Label = ui.secrets_label
	var info: Label = ui.find_child("MuseumInfoLabel", true, false) as Label
	_check(outer != null and outer.follow_focus and outer.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "pagina Museu conserva unica rolagem externa vertical")
	_check(list.auto_height and not list.get_v_scroll_bar().visible, "catalogo cresce sem scrollbar interna concorrente")
	_check(list.max_columns == 1 and list.icon_mode == ItemList.ICON_MODE_TOP and list.max_text_lines >= 3 and list.fixed_column_width > 0 and list.fixed_column_width <= int(list.size.x), "catalogo uma coluna com quebra de texto pela largura disponivel")
	_check(secrets.get_parent() != list.get_parent() and info != null and secrets.get_global_rect().end.y + 6.0 <= info.global_position.y, "resumo de progresso separado e acima do titulo do catalogo")
	_check(ui.view_museum_btn.visible and ui.view_museum_btn.theme_type_variation == &"PrimaryButton" and ui.view_museum_btn.custom_minimum_size.y >= 44.0 and ui.view_museum_btn.focus_mode == Control.FOCUS_ALL, "Ver museu destacado e acionavel por foco")
	_check(outer != null and outer.get_global_rect().encloses(ui.view_museum_btn.get_global_rect()) and outer.get_global_rect().encloses(secrets.get_global_rect()), "entrada Museu exibe CTA e progresso antes de navegar catalogo")
	_check(ui.view_museum_btn.has_focus(), "entrada Museu prioriza foco no CTA em vez do ItemList alto")
	for id: String in DEV_NAMES:
		var control: Control = ui.find_child(id, true, false) as Control
		_check(control != null and not control.visible, "debug sem flag nao expoe simulacao: " + id)
		if control is BaseButton:
			_check(control.focus_mode == Control.FOCUS_NONE, "debug sem flag nao foca simulacao: " + id)
	# Explicit policy also covers export/release; no pretending OS debug implies opt-in.
	for policy: Dictionary in [{"debug": true, "args": PackedStringArray(), "want": false}, {"debug": false, "args": PackedStringArray(["--dev-ui"]), "want": false}, {"debug": true, "args": PackedStringArray(["--dev-ui"]), "want": true}, {"debug": true, "args": PackedStringArray(["--other"]), "want": false}]:
		_check(ui.has_method("museum_dev_enabled") and bool(ui.call("museum_dev_enabled", policy["debug"], policy["args"])) == bool(policy["want"]), "politica dev exige debug E flag explicita: " + str(policy))
	var catalog: Array = ui.get("_catalog_items")
	var data_ok: bool = list.item_count == catalog.size() and list.item_count > 1
	for index: int in catalog.size():
		var item: ItemData = catalog[index] as ItemData
		data_ok = data_ok and list.get_item_text(index) == BaseStationUI.museum_line(item, state.discovered_items.has(item.id), state.intact_items.has(item.id))
	_check(data_ok, "catalogo preserva dados completos e museum_line")
	var list_id: int = list.get_instance_id()
	ui.call("_refresh_museum_display")
	_check(ui.museum_item_list.get_instance_id() == list_id and ui.get_node(^"%MuseumItemList") == list and ui.get_node(^"%SecretsLabel") == secrets, "refresh/reparent preservam referencias e uniqueIDs")
	list.select(0)
	list.grab_focus()
	# Godot4.3 ItemList supports PageDown/arrows, not Home/End.
	for step: int in list.item_count:
		if list.get_selected_items().has(list.item_count - 1):
			break
		await _key(KEY_PAGEDOWN)
	var selected: PackedInt32Array = list.get_selected_items()
	_check(list.has_focus() and selected.size() == 1 and selected[0] == list.item_count - 1, "PageDown seleciona ultimo item sem retirar foco do catalogo")
	if outer != null:
		var last: Rect2 = list.get_item_rect(list.item_count - 1)
		last.position += list.global_position - Vector2(0.0, list.get_v_scroll_bar().value)
		var visible_area: Rect2 = outer.get_global_rect()
		_check(last.position.y >= visible_area.position.y - 1.0 and last.end.y <= visible_area.end.y + 1.0, "outer exibe linha selecionada por PageDown")
	ui.focus_home()
	await _frames()
	_check(outer != null and outer.get_global_rect().encloses(ui.view_museum_btn.get_global_rect()) and outer.get_global_rect().encloses(secrets.get_global_rect()), "focus_home Museu reexibe CTA e progresso depois do fim do catalogo")
	_check(ui.view_museum_btn.has_focus(), "focus_home Museu devolve foco ao CTA")
	ui.view_museum_btn.grab_focus()
	ui.view_museum_btn.pressed.emit()
	var view: MuseumView = get_first_node_in_group(MuseumView.GROUP) as MuseumView
	_check(view != null and view.is_open() and not ui.is_visible_in_tree(), "Ver museu continua abrindo vitrine real")
	await _key(KEY_ESCAPE)
	_check(not view.is_open() and ui.is_visible_in_tree() and ui.view_museum_btn.has_focus(), "Esc retorna da vitrine com foco em Ver museu")
	_check(ui.map_list != null and ui.depart_btn != null and tabs.get_tab_count() >= 3 and state.team_money == money_before, "demais abas e saldo preservados")
	print("CHECKS count=%d" % _checks)
	print("RESULT fails=%d" % _fails)
	quit(0 if _fails == 0 else 1)
