extends CanvasLayer

## Contextual commerce view only. The physical counter owns host validation and requests.
signal purchase_requested(upgrade_id: String, request_id: int)

const GROUP: StringName = &"world_upgrade_shops"
const IDS: Array[String] = ["detector", "pinpointer", "shovel", "backpack"]
const REQUEST_TIMEOUT_MSEC: int = 8000
static var _request_sequence: int = 0

var _open: bool = false
var _actor: Player = null
var _counter: Node3D = null
var _scene: Node = null
var _previous_focus: WeakRef = null
var _previous_mouse: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _root: Control = null
var _shade: ColorRect = null
var _panel: PanelContainer = null
var _coin_icon: TextureRect = null
var _money: Label = null
var _feedback: Label = null
var _close_button: Button = null
var _buttons: Dictionary = {}
var _cards: Dictionary = {}
var _details: Dictionary = {}
var _names: Dictionary = {}
var _pips: Dictionary = {}
var _pending_request: int = 0
var _pending_started: int = 0
## Timeout is an unknown result, not permission to charge a new intent.
var _intent_request: int = 0
var _intent_upgrade: String = ""
var _displayed_money: int = -1
var _money_tween: Tween = null


func _ready() -> void:
	layer = 44
	add_to_group(GROUP)
	_build()
	if GameState.instance != null:
		GameState.instance.state_synced.connect(_refresh)
	_root.hide()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()


func _exit_tree() -> void:
	close()


func _close_if_invalid() -> bool:
	if get_tree().current_scene != _scene or not is_instance_valid(_counter) or not is_instance_valid(_actor):
		close()
		return true
	if not _valid_actor(_counter, _actor):
		close()
		return true
	if PauseMenu.is_open() or VictoryScreen.is_open():
		close()
		return true
	return false


func _physics_process(_delta: float) -> void:
	if _open:
		_close_if_invalid()


func _process(_delta: float) -> void:
	if not _open or _close_if_invalid():
		return
	if _pending_request != 0 and Time.get_ticks_msec() - _pending_started >= REQUEST_TIMEOUT_MSEC:
		_pending_request = 0
		_set_feedback(tr("Sem resposta do host. Tente novamente."), UiPalette.RED_BURNT)
		UiMotion.shake(_feedback, 1.8, 0.22, false)
		_refresh()


func _input(event: InputEvent) -> void:
	if _open and event.is_action_pressed(&"ui_cancel", false, true):
		close()
		get_viewport().set_input_as_handled()


func _valid_actor(counter: Node3D, actor: Player) -> bool:
	if not is_instance_valid(counter) or not is_instance_valid(actor):
		return false
	if not counter.is_inside_tree() or counter.is_queued_for_deletion() or not counter.is_in_group(&"upgrade_counters"):
		return false
	if not actor.is_inside_tree() or actor.is_queued_for_deletion() or not actor.is_local() or not actor.is_alive() or actor.is_downed:
		return false
	var scene: Node = get_tree().current_scene
	if scene == null or not scene.is_ancestor_of(counter) or not scene.is_ancestor_of(actor):
		return false
	return counter.has_method("is_actor_in_range") and bool(counter.call("is_actor_in_range", actor))


func open_for(counter: Node3D, actor: Player) -> bool:
	if not is_node_ready() or _open or PauseMenu.is_open() or VictoryScreen.is_open() or not _valid_actor(counter, actor):
		return false
	_actor = actor
	_counter = counter
	_scene = get_tree().current_scene
	var focus: Control = get_viewport().gui_get_focus_owner()
	_previous_focus = weakref(focus) if focus != null else null
	_previous_mouse = Input.mouse_mode
	_pending_request = 0
	_set_feedback("")
	_open = true
	_root.show()
	if SessionUI.instance != null and SessionUI.instance.expedition_bar != null:
		SessionUI.instance.expedition_bar.visible = false
	UiMotion.fade_backdrop(_shade, false)
	UiMotion.pop_in(_panel, false, 0.94, 0.18)
	for idx: int in IDS.size():
		UiMotion.pop_in(_cards.get(IDS[idx]) as Control, false, 0.97, 0.16, float(idx) * 0.03)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()
	_close_button.grab_focus()
	return true


func close() -> void:
	if not _open:
		return
	_open = false
	_pending_request = 0
	_actor = null
	_counter = null
	_scene = null
	UiMotion.stop(_panel)
	UiMotion.stop(_shade)
	UiMotion.stop(_coin_icon)
	if _money_tween != null:
		_money_tween.kill()
		_money_tween = null
	_displayed_money = -1
	for id: String in IDS:
		UiMotion.stop(_cards.get(id) as Control)
	if is_instance_valid(_root):
		_root.hide()
	Input.mouse_mode = _previous_mouse
	if SessionUI.instance != null and SessionUI.instance.expedition_bar != null:
		SessionUI.instance.call(&"_refresh_expedition_bar")
	if _previous_focus != null:
		var focus: Control = _previous_focus.get_ref() as Control
		if is_instance_valid(focus) and focus.is_inside_tree() and focus.is_visible_in_tree():
			focus.grab_focus()
	_previous_focus = null


func is_open() -> bool:
	return _open


func is_open_for(actor: Player) -> bool:
	return _open and _actor == actor


func get_upgrade_button(upgrade_id: String) -> Button:
	return _buttons.get(upgrade_id) as Button


func _build() -> void:
	_root = Control.new()
	_root.name = "WorldShop"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = preload("res://ui/theme/scandig_theme.tres")
	_root.visibility_changed.connect(func() -> void:
		if not _root.visible and _money_tween != null:
			_money_tween.kill()
			_money_tween = null
			_displayed_money = -1
		if SessionUI.instance != null and SessionUI.instance.expedition_bar != null:
			SessionUI.instance.call(&"_refresh_expedition_bar"))
	add_child(_root)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(UiPalette.INK, 0.62)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	_shade = shade
	var center: FitCenterContainer = FitCenterContainer.new()
	center.margin = 16.0
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	UiFocus.follow_pointer(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = &"WornPanel"
	panel.custom_minimum_size = Vector2(620, 0)
	center.add_child(panel)
	_panel = panel
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 10)
	margin.add_child(column)

	var header: HBoxContainer = HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override(&"separation", 10)
	var wrench: TextureRect = TextureRect.new()
	wrench.texture = UiIcons.get_icon("wrench", 32)
	wrench.custom_minimum_size = Vector2(26, 26)
	wrench.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wrench.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	wrench.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(wrench)
	var title: Label = Label.new()
	title.text = "Melhorias"
	title.theme_type_variation = &"TitleLabel"
	header.add_child(title)
	column.add_child(header)
	column.add_child(HSeparator.new())

	var money_card: PanelContainer = PanelContainer.new()
	money_card.theme_type_variation = &"SummaryTotalPanel"
	var money_row: HBoxContainer = HBoxContainer.new()
	money_row.alignment = BoxContainer.ALIGNMENT_CENTER
	money_row.add_theme_constant_override(&"separation", 8)
	money_card.add_child(money_row)
	var coin_icon: TextureRect = TextureRect.new()
	_coin_icon = coin_icon
	coin_icon.texture = UiIcons.get_icon("coin", 24)
	coin_icon.custom_minimum_size = Vector2(20, 20)
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	money_row.add_child(coin_icon)
	_money = Label.new()
	money_row.add_child(_money)
	column.add_child(money_card)

	for id: String in IDS:
		var card: PanelContainer = PanelContainer.new()
		card.theme_type_variation = &"InsetPanel"
		column.add_child(card)
		_cards[id] = card
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 10)
		card.add_child(row)
		var icon: TextureRect = TextureRect.new()
		icon.texture = UiIcons.get_icon(id, 64)
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
		var info: VBoxContainer = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.alignment = BoxContainer.ALIGNMENT_CENTER
		info.add_theme_constant_override(&"separation", 2)
		row.add_child(info)
		var name_label: Label = Label.new()
		info.add_child(name_label)
		_names[id] = name_label
		var sub_row: HBoxContainer = HBoxContainer.new()
		sub_row.add_theme_constant_override(&"separation", 8)
		info.add_child(sub_row)
		var pips: HBoxContainer = HBoxContainer.new()
		pips.add_theme_constant_override(&"separation", 3)
		pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sub_row.add_child(pips)
		_pips[id] = pips
		var detail: Label = Label.new()
		detail.theme_type_variation = &"HintLabel"
		detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sub_row.add_child(detail)
		_details[id] = detail
		var button: Button = Button.new()
		button.name = "Buy_" + id
		button.theme_type_variation = &"PrimaryButton"
		button.custom_minimum_size = Vector2(192, 44)
		button.add_theme_constant_override(&"icon_max_width", 18)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(_buy.bind(id))
		UiMotion.attach_button(button)
		row.add_child(button)
		_buttons[id] = button
	_feedback = Label.new()
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.custom_minimum_size.y = 26
	column.add_child(_feedback)
	column.add_child(HSeparator.new())
	_close_button = Button.new()
	_close_button.text = "Fechar"
	_close_button.icon = UiIcons.get_icon("door", 32)
	_close_button.add_theme_constant_override(&"icon_max_width", 18)
	_close_button.custom_minimum_size = Vector2(180, 44)
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close_button.pressed.connect(close)
	UiMotion.attach_button(_close_button)
	column.add_child(_close_button)


func _set_feedback(message: String, accent: Color = UiPalette.WOOD) -> void:
	_feedback.text = message
	if message.is_empty():
		_feedback.remove_theme_stylebox_override(&"normal")
		return
	var pill: StyleBoxFlat = StyleBoxFlat.new()
	pill.bg_color = UiPalette.PAPER_LIGHT.lerp(accent, 0.12)
	pill.border_color = accent
	pill.set_border_width_all(1)
	pill.set_corner_radius_all(10)
	pill.content_margin_left = 10.0
	pill.content_margin_right = 10.0
	pill.content_margin_top = 4.0
	pill.content_margin_bottom = 4.0
	_feedback.add_theme_color_override(&"font_color", accent)
	_feedback.add_theme_stylebox_override(&"normal", pill)


func _rebuild_pips(pips: HBoxContainer, level: int, maximum: int) -> void:
	for child: Node in pips.get_children():
		pips.remove_child(child)
		child.queue_free()
	var fill: Color = UiPalette.GREEN_BOTTLE if level >= maximum else UiPalette.ORANGE
	for i: int in maximum:
		var pip: Panel = Panel.new()
		pip.custom_minimum_size = Vector2(14, 8)
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = fill if i < level else UiPalette.PAPER_DARK
		sb.border_color = UiPalette.INK
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(2)
		pip.add_theme_stylebox_override(&"panel", sb)
		pips.add_child(pip)


func _set_button_state(btn: Button, accent: Color) -> void:
	if accent.a <= 0.0:
		btn.remove_theme_stylebox_override(&"disabled")
		btn.remove_theme_color_override(&"font_disabled_color")
		return
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = UiPalette.PAPER_LIGHT
	style.border_color = accent
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	btn.add_theme_stylebox_override(&"disabled", style)
	btn.add_theme_color_override(&"font_disabled_color", accent)


func _map_display_name(map_id: String) -> String:
	var res_path: String = "res://items/maps/%s.tres" % map_id
	if ResourceLoader.exists(res_path):
		var md: MapData = load(res_path) as MapData
		if md != null and not md.display_name.is_empty():
			return md.display_name
	return map_id


func _update_money_label(target_money: int) -> void:
	if _money_tween != null:
		_money_tween.kill()
		_money_tween = null
	if UiMotion.is_instant() or _displayed_money < 0 or _displayed_money == target_money or _root == null or not _root.visible or not is_inside_tree():
		_displayed_money = target_money
		_money.text = tr("Saldo da equipe: %s") % MoneyFormat.money(target_money)
		return
	var start_val: int = _displayed_money
	_displayed_money = target_money
	_money_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_money_tween.tween_method(func(val: float) -> void:
		if is_instance_valid(_money):
			_money.text = tr("Saldo da equipe: %s") % MoneyFormat.money(roundi(val)),
		float(start_val), float(target_money), 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_money_tween.tween_callback(func() -> void:
		if is_instance_valid(_money):
			_money.text = tr("Saldo da equipe: %s") % MoneyFormat.money(target_money)
		_money_tween = null)


func _refresh() -> void:
	var state: GameState = GameState.instance
	if state == null or not is_instance_valid(_money):
		return
	_update_money_label(state.team_money)
	for id: String in IDS:
		var level: int = state.get_upgrade_level(id)
		var maximum: int = state.get_upgrade_max_level(id)
		var cost: int = state.get_next_upgrade_cost(id)
		var name_label: Label = _names[id] as Label
		name_label.text = tr(str(GameState.UPGRADES[id]["name"]))
		_rebuild_pips(_pips[id] as HBoxContainer, level, maximum)
		var detail: Label = _details[id] as Label
		var base_detail: String = tr("Nível %d/%d  •  radar Nv.%d") % [level, maximum, level + 1] if id == "detector" else tr("Nível %d/%d") % [level, maximum]
		var button: Button = _buttons[id] as Button
		var reason: String = state.get_upgrade_block_reason(id)
		var required_map: String = state.get_next_upgrade_required_map(id)
		var at_maximum: bool = cost < 0
		var map_locked: bool = not at_maximum and not required_map.is_empty() and not state.is_map_unlocked(required_map)
		var no_money: bool = not at_maximum and not map_locked and not reason.is_empty() and state.team_money < cost
		if at_maximum:
			detail.text = base_detail
			detail.add_theme_color_override(&"font_color", UiPalette.GREEN_BOTTLE)
			button.icon = UiIcons.get_icon("check", 32)
			button.text = tr("Máximo")
			_set_button_state(button, UiPalette.GREEN_BOTTLE)
		elif map_locked:
			detail.text = "%s  ·  %s" % [base_detail, tr("🔒 Requer %s") % tr(_map_display_name(required_map))]
			detail.add_theme_color_override(&"font_color", UiPalette.METAL)
			button.icon = UiIcons.get_icon("lock", 32)
			button.text = MoneyFormat.money(cost)
			_set_button_state(button, UiPalette.METAL)
		elif no_money:
			detail.text = base_detail
			detail.remove_theme_color_override(&"font_color")
			button.icon = UiIcons.get_icon("coin", 32)
			button.text = "%s · %s" % [tr("Sem saldo"), MoneyFormat.money(cost)]
			_set_button_state(button, UiPalette.RED_BURNT)
		else:
			detail.text = base_detail
			detail.remove_theme_color_override(&"font_color")
			button.icon = UiIcons.get_icon("coin", 32)
			button.text = "%s  %s" % [tr("Comprar"), MoneyFormat.money(cost)]
			_set_button_state(button, Color.TRANSPARENT)
		button.tooltip_text = reason
		if _intent_request != 0:
			button.disabled = _pending_request != 0 or id != _intent_upgrade
		else:
			button.disabled = not reason.is_empty()
	var navigation: Array = _buttons.values()
	navigation.append(_close_button)
	UiFocus.skip_disabled(navigation)
	UiFocus.link_chain(navigation)


func _buy(upgrade_id: String) -> void:
	var button: Button = get_upgrade_button(upgrade_id)
	if not _open or button == null or button.disabled:
		return
	# A queued button press can precede _process after a counter/actor was freed.
	# Check references before passing them into a typed method.
	if not is_instance_valid(_counter) or not is_instance_valid(_actor):
		close()
		return
	if not _valid_actor(_counter, _actor):
		close()
		return
	if _intent_request == 0:
		_request_sequence += 1
		_intent_request = _request_sequence
		_intent_upgrade = upgrade_id
	elif _intent_upgrade != upgrade_id:
		return
	_pending_request = _intent_request
	_pending_started = Time.get_ticks_msec()
	_set_feedback(tr("Processando compra..."))
	_refresh()
	purchase_requested.emit(upgrade_id, _pending_request)


## A counter only completes the matching request; a late reply cannot complete a newer one.
func complete_purchase(request_id: int, success: bool, message: String) -> void:
	if request_id == 0 or request_id != _intent_request:
		return
	var target_id: String = _intent_upgrade
	_pending_request = 0
	_intent_request = 0
	_intent_upgrade = ""
	_set_feedback(message, UiPalette.GREEN_BOTTLE if success else UiPalette.RED_BURNT)
	_refresh()
	if success:
		UiMotion.pulse(_cards.get(target_id) as Control, 1.035, 0.20, false)
		UiMotion.pulse(_coin_icon, 1.22, 0.22, false)
		UiMotion.pulse(_feedback, 1.03, 0.18, false)
		var pips: HBoxContainer = _pips.get(target_id) as HBoxContainer
		var lv: int = GameState.instance.get_upgrade_level(target_id) if GameState.instance != null else 0
		if pips != null and lv > 0 and lv <= pips.get_child_count():
			UiMotion.pulse(pips.get_child(lv - 1) as Control, 1.32, 0.22, false)
	else:
		UiMotion.shake(_feedback, 1.8, 0.22, false)
