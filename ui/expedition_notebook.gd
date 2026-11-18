extends CanvasLayer

## Consulta local: não escreve progresso, não pausa a árvore e não cria RPCs.
## O Player local monta o caderno e consulta is_open_for no bloqueio de ações.
const GROUP: StringName = &"expedition_notebooks"
const BASE: GDScript = preload("res://ui/base_station_ui.gd")

var _actor: Node = null
var _scene: Node = null
var _opened: bool = false
var _previous_mouse: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _previous_focus: WeakRef = null
var _root: Control = null
var _tabs: TabContainer = null
var _title: Label = null
var _hint: Label = null
var _close_button: Button = null
var _journal: VBoxContainer = null
var _collection: VBoxContainer = null
var _achievements: AchievementsTab = null
var _entries: Dictionary = {}
var _access_hint: Label = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 44
	add_to_group(GROUP)
	_build()
	_root.hide()
	_access_hint = Label.new()
	_access_hint.name = "AccessHint"
	_access_hint.add_theme_font_override(&"font", _root.theme.default_font)
	_access_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_access_hint.add_theme_font_size_override(&"font_size", 13)
	_access_hint.add_theme_color_override(&"font_color", UiPalette.PAPER_LIGHT)
	_access_hint.add_theme_color_override(&"font_outline_color", UiPalette.INK)
	_access_hint.add_theme_constant_override(&"outline_size", 3)
	_access_hint.hide()
	add_child(_access_hint)
	if GameState.instance != null:
		GameState.instance.state_synced.connect(refresh)
	if SessionManager.instance != null:
		SessionManager.instance.scene_changing.connect(_on_scene_changing)
	refresh()


func bind(player: Node) -> void:
	close()
	_actor = player


func is_open_for(player: Node) -> bool:
	return _opened and is_instance_valid(player) and _actor == player


func _valid_context() -> bool:
	if not is_instance_valid(_actor) or not _actor.is_inside_tree() or _actor.is_queued_for_deletion():
		return false
	if not _actor.has_method("is_local") or not bool(_actor.call("is_local")):
		return false
	if not _actor.has_method("is_alive") or not bool(_actor.call("is_alive")):
		return false
	if "is_downed" in _actor and bool(_actor.get("is_downed")):
		return false
	return SessionManager.instance != null and SessionManager.instance.is_in_expedition() and get_tree().current_scene != null and get_tree().current_scene.is_ancestor_of(_actor)


func _other_modal() -> bool:
	if UiFocus.modal_open():
		return true
	var session_ui: SessionUI = SessionUI.instance
	if session_ui != null and session_ui.loading_screen != null and session_ui.loading_screen.visible:
		return true
	for shop: Node in get_tree().get_nodes_in_group(&"world_upgrade_shops"):
		if shop.has_method("is_open") and bool(shop.call("is_open")):
			return true
	if is_instance_valid(_actor):
		var wheel: Node = _actor.get("marker_wheel") as Node
		if is_instance_valid(wheel) and wheel.has_method("is_wheel_open") and bool(wheel.call("is_wheel_open")):
			return true
	return false


func open() -> void:
	if not is_node_ready() or _opened or not _valid_context() or _other_modal():
		return
	_scene = get_tree().current_scene
	_previous_mouse = Input.mouse_mode
	var focus: Control = get_viewport().gui_get_focus_owner()
	_previous_focus = weakref(focus) if focus != null else null
	_opened = true
	refresh()
	_root.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_link_navigation()
	_close_button.grab_focus()


func close() -> void:
	_dismiss(not _other_modal() if is_inside_tree() else false)


func _dismiss(restore: bool) -> void:
	if not _opened:
		return
	_opened = false
	_root.hide()
	# Uma camada superveniente já é dona do cursor/foco.
	if restore:
		Input.mouse_mode = _previous_mouse
		var focus: Control = _previous_focus.get_ref() as Control if _previous_focus != null else null
		if is_instance_valid(focus) and focus.is_inside_tree() and focus.is_visible_in_tree():
			focus.grab_focus()
	_previous_focus = null
	_scene = null


func _on_scene_changing(_path: String) -> void:
	_dismiss(false)


func _exit_tree() -> void:
	_dismiss(false)


func _process(_delta: float) -> void:
	if _opened and (_other_modal() or not _valid_context() or get_tree().current_scene != _scene):
		_dismiss(false)
	_update_access_hint()


func _update_access_hint() -> void:
	if _access_hint == null:
		return
	_access_hint.visible = not _opened and _valid_context() and not _other_modal()
	if not _access_hint.visible:
		return
	var event: InputEvent = null
	var shortcut: String = "G"
	if InputDevice.using_gamepad():
		var pad: InputEventJoypadButton = InputEventJoypadButton.new()
		pad.pressed = true
		pad.button_index = JOY_BUTTON_BACK
		event = pad
		shortcut = "Select"
	else:
		var key: InputEventKey = InputEventKey.new()
		key.pressed = true
		key.keycode = KEY_G
		key.physical_keycode = KEY_G
		event = key
	if shortcut_conflicts(event):
		_access_hint.hide()
		return
	_access_hint.text = "%s [%s]" % [tr("Diário"), shortcut]
	var view: Vector2 = get_viewport().get_visible_rect().size
	var top: float = view.y * 0.95 - 100.0
	var vitals: Control = _actor.get_node_or_null(^"HUD/HealthPanel") as Control
	if vitals != null:
		top = vitals.get_global_rect().position.y
	_access_hint.size = _access_hint.get_combined_minimum_size()
	_access_hint.position = Vector2(view.x * 0.05, top - _access_hint.size.y - 8.0)


## G físico/Select só abrem se nenhuma ação configurada já usar o evento.
## Não adiciona ações ao InputMap e respeita remapeamentos existentes.
func _shortcut(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		return key.pressed and not key.echo and not key.ctrl_pressed and not key.alt_pressed and not key.meta_pressed and not key.shift_pressed and (key.physical_keycode == KEY_G or (key.physical_keycode == KEY_NONE and key.keycode == KEY_G))
	if event is InputEventJoypadButton:
		var pad: InputEventJoypadButton = event as InputEventJoypadButton
		return pad.pressed and pad.button_index == JOY_BUTTON_BACK
	return false


func shortcut_conflicts(event: InputEvent) -> bool:
	for action: StringName in InputMap.get_actions():
		if InputMap.event_is_action(event, action):
			return true
	return false


func _input(event: InputEvent) -> void:
	if _opened:
		if _other_modal() or not _valid_context():
			_dismiss(false)
			return
		if (_shortcut(event) and not shortcut_conflicts(event)) or event.is_action_pressed(&"ui_cancel", false, true):
			close()
			get_viewport().set_input_as_handled()
			return
		var step: int = UiFocus.tab_step(event)
		if step != 0:
			UiFocus.step_tab(_tabs, step, [_close_button])
			get_viewport().set_input_as_handled()
	elif _shortcut(event) and not shortcut_conflicts(event):
		open()
		if _opened:
			get_viewport().set_input_as_handled()


func _build() -> void:
	_root = Control.new()
	_root.name = "ExpeditionNotebook"
	_root.theme = preload("res://ui/theme/scandig_theme.tres")
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(UiPalette.INK, 0.62)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = &"WornPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.anchor_left = 0.07
	panel.anchor_right = 0.93
	panel.anchor_top = 0.07
	panel.anchor_bottom = 0.93
	_root.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 10)
	margin.add_child(column)
	var header: HBoxContainer = HBoxContainer.new()
	column.add_child(header)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_size_override(&"font_size", 26)
	header.add_child(_title)
	_close_button = Button.new()
	_close_button.custom_minimum_size = Vector2(120, 44)
	_close_button.pressed.connect(close)
	header.add_child(_close_button)
	_hint = Label.new()
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_hint)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.tab_changed.connect(_on_tab_changed)
	column.add_child(_tabs)
	_journal = _page("Diário")
	var achievements_page: VBoxContainer = _page("Conquistas")
	_achievements = AchievementsTab.new()
	achievements_page.add_child(_achievements)
	_collection = _page("Coleção")
	UiFocus.follow_pointer(column)


func _page(title: String) -> VBoxContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_tabs.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override(&"separation", 8)
	scroll.add_child(list)
	return list


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()


func _on_tab_changed(_index: int) -> void:
	_focus_page.call_deferred()


func _focus_page() -> void:
	if not _opened:
		return
	_link_navigation()
	var first: Control = UiFocus.first_focusable(_tabs.get_current_tab_control())
	if first != null:
		first.grab_focus()


func _link_navigation() -> void:
	var controls: Array = [_tabs.get_tab_bar()]
	controls.append_array(UiFocus.focusables(_tabs.get_current_tab_control()))
	controls.append(_close_button)
	UiFocus.link_chain(controls)


func _clear(list: VBoxContainer) -> void:
	for child: Node in list.get_children():
		list.remove_child(child)
		child.queue_free()


func _row(list: VBoxContainer, id: String, title: String, detail: String, texture: Texture2D) -> void:
	var row: Button = Button.new()
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.text = "%s\n%s" % [title, detail]
	row.icon = texture
	row.add_theme_font_size_override(&"font_size", 18)
	row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# O Button calcula a altura do texto antes de receber a largura da VBox.
	# Uma largura mínima evita uma ficha de centenas de pixels no primeiro layout.
	row.custom_minimum_size = Vector2(280, 56)
	list.add_child(row)
	_entries[id] = row


func entry_text(id: String) -> String:
	var row: Button = _entries.get(id) as Button
	return row.text if row != null else ""


func refresh() -> void:
	if _journal == null:
		return
	# Evita reconstruções de snapshot invisíveis e preserva foco na linha atual.
	var focused_id: String = ""
	var focus: Control = get_viewport().gui_get_focus_owner()
	for id: String in _entries:
		if _entries[id] == focus:
			focused_id = id
	_title.text = tr("Caderno de Expedição")
	_close_button.text = tr("Fechar")
	_hint.text = tr("A expedição continua enquanto você consulta o caderno.")
	for index: int in 3:
		_tabs.set_tab_title(index, tr(["Diário", "Conquistas", "Coleção"][index]))
	_clear(_journal)
	_clear(_collection)
	_entries.clear()
	var gs: GameState = GameState.instance
	var seen: Array = Array(gs.seen_creatures) if gs != null else []
	var defeated: Array = Array(gs.defeated_bosses) if gs != null else []
	for kind: String in BASE.CREATURE_ORDER:
		if not GameState.CREATURES.has(kind):
			continue
		var meta: Dictionary = BASE.CREATURE_FIELD_META[kind]
		var known: bool = seen.has(kind)
		_row(_journal, kind, tr(str(GameState.CREATURES[kind])) if known else "???",
			tr("%s • Catalogado") % tr(str(meta["region"])) if known else tr("%s • Por avistar") % tr(str(meta["region"])),
			BASE._build_journal_mini_texture(kind, known, meta["color"], false))
	for boss_id: String in BASE.BOSS_ORDER:
		var meta: Dictionary = BASE.BOSS_FIELD_META[boss_id]
		var known: bool = defeated.has(boss_id)
		_row(_journal, boss_id, "✔ " + tr(str(meta["name"])) if known else "???",
			tr("%s • Vencido") % tr(str(meta["region"])) if known else tr("%s • Guardião") % tr(str(meta["region"])),
			BASE._build_journal_mini_texture(boss_id, known, meta["color"], true))
	var count: int = gs.discovered_items.size() if gs != null else 0
	var label: Label = Label.new()
	label.text = tr("Museu  %d/%d") % [count, gs.get_total_catalog_items() if gs != null else 0]
	_collection.add_child(label)
	if gs != null:
		for item_id: String in gs.discovered_items:
			_row(_collection, "item:" + item_id, tr(gs.get_item_display_name(item_id)), tr("Coleção"), UiIcons.get_icon("museum", 32))
	_achievements.refresh()
	if _opened:
		_link_navigation()
		if not focused_id.is_empty() and _entries.has(focused_id):
			(_entries[focused_id] as Control).grab_focus()
