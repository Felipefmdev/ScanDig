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
var _money: Label = null
var _feedback: Label = null
var _close_button: Button = null
var _buttons: Dictionary = {}
var _details: Dictionary = {}
var _pending_request: int = 0
var _pending_started: int = 0
## Timeout is an unknown result, not permission to charge a new intent.
var _intent_request: int = 0
var _intent_upgrade: String = ""


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


func _process(_delta: float) -> void:
	if not _open:
		return
	if get_tree().current_scene != _scene or not is_instance_valid(_counter) or not is_instance_valid(_actor):
		close()
		return
	if not _valid_actor(_counter, _actor):
		close()
		return
	if PauseMenu.is_open() or VictoryScreen.is_open():
		close()
		return
	if _pending_request != 0 and Time.get_ticks_msec() - _pending_started >= REQUEST_TIMEOUT_MSEC:
		_pending_request = 0
		_feedback.text = tr("Sem resposta do host. Tente novamente.")
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
	_feedback.text = ""
	_open = true
	_root.show()
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
	if is_instance_valid(_root):
		_root.hide()
	Input.mouse_mode = _previous_mouse
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
	add_child(_root)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.02, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 400)
	center.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 12)
	margin.add_child(column)
	var title: Label = Label.new()
	title.text = "Melhorias"
	title.add_theme_font_size_override(&"font_size", 28)
	column.add_child(title)
	_money = Label.new()
	column.add_child(_money)
	for id: String in IDS:
		var row: HBoxContainer = HBoxContainer.new()
		column.add_child(row)
		var detail: Label = Label.new()
		detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(detail)
		_details[id] = detail
		var button: Button = Button.new()
		button.name = "Buy_" + id
		button.custom_minimum_size = Vector2(180, 48)
		button.pressed.connect(_buy.bind(id))
		row.add_child(button)
		_buttons[id] = button
	_feedback = Label.new()
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.custom_minimum_size.y = 42
	column.add_child(_feedback)
	_close_button = Button.new()
	_close_button.text = "Fechar"
	_close_button.pressed.connect(close)
	column.add_child(_close_button)


func _refresh() -> void:
	var state: GameState = GameState.instance
	if state == null or not is_instance_valid(_money):
		return
	_money.text = tr("Saldo da equipe: %s") % MoneyFormat.money(state.team_money)
	for id: String in IDS:
		var level: int = state.get_upgrade_level(id)
		var maximum: int = state.get_upgrade_max_level(id)
		var cost: int = state.get_next_upgrade_cost(id)
		var detail: Label = _details[id] as Label
		detail.text = "%s  ·  %s" % [tr(str(GameState.UPGRADES[id]["name"])), tr("Nível %d/%d") % [level, maximum]]
		var button: Button = _buttons[id] as Button
		var reason: String = state.get_upgrade_block_reason(id)
		button.text = tr("Máximo") if cost < 0 else "%s  %s" % [tr("Comprar"), MoneyFormat.money(cost)]
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
	_feedback.text = tr("Processando compra...")
	_refresh()
	purchase_requested.emit(upgrade_id, _pending_request)


## A counter only completes the matching request; a late reply cannot complete a newer one.
func complete_purchase(request_id: int, _success: bool, message: String) -> void:
	if request_id == 0 or request_id != _intent_request:
		return
	_pending_request = 0
	_intent_request = 0
	_intent_upgrade = ""
	_feedback.text = message
	_refresh()
