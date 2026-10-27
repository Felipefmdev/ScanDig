extends GutTest

## Real input regression: live inspector labels follow device and pad binding changes.
## Native stderr remains an independent gate; no direct device/signal/UI refresh.
const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/player.tscn")
var _player: Player = null
var _world: Node3D = null
var _before: Dictionary = {}
var _save_before: Dictionary = {}
var _input_before: Dictionary = {}
var _runner_ui: CanvasItem = null
var _runner_visible: bool = false
var _configured: bool = false
var _ready_for_case: bool = false
var _runner_changed: bool = false
var _case: String = "setup"
var _card_id: int = 0
var _content_before: Dictionary = {}


func _frames() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame


func before_each() -> void:
	_configured = false
	_ready_for_case = false
	_runner_changed = false
	assert_not_null(InputDevice.instance)
	assert_not_null(SettingsManager.instance)
	assert_false(get_tree().paused)
	assert_false(PauseMenu.is_open() or VictoryScreen.is_open())
	assert_true(get_tree().get_nodes_in_group(Player.LOCAL_GROUP).is_empty(), "isolated process: no foreign Player")
	assert_true(SessionManager.instance._rocket_payload.is_empty(), "ready must not consume pending payload")
	if get_tree().paused or PauseMenu.is_open() or VictoryScreen.is_open() or not get_tree().get_nodes_in_group(Player.LOCAL_GROUP).is_empty() or not SessionManager.instance._rocket_payload.is_empty(): return
	var sm: SettingsManager = SettingsManager.instance
	_before = {"settings": sm._values.duplicate(true), "settings_path": sm.settings_path, "locale": TranslationServer.get_locale(), "state": GameState.instance.get_snapshot().duplicate(true), "map": SessionManager.instance._current_map, "night": SessionManager.instance._night, "mouse": Input.mouse_mode, "focus": get_viewport().gui_get_focus_owner(), "pad": InputDevice.using_gamepad(), "pointer": InputDevice.using_pointer(), "pad_id": InputDevice.instance._pad_device, "mouse_position": get_viewport().get_mouse_position(), "save_process": SaveManager.instance.is_processing(), "window_size": get_tree().root.size, "window_scale": get_tree().root.content_scale_factor, "window_mode": DisplayServer.window_get_mode(), "borderless": DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS)}
	for field: String in ["save_path", "_base_path", "_slot", "_progress_applied", "_write_blocked", "play_time_s", "last_map"]:
		_save_before[field] = SaveManager.instance.get(field)
	_input_before.clear()
	for action: StringName in InputMap.get_actions():
		var events: Array[InputEvent] = []
		for event: InputEvent in InputMap.action_get_events(action): events.append(event.duplicate() as InputEvent)
		_input_before[str(action)] = {"deadzone": InputMap.action_get_deadzone(action), "events": events}
	_configured = true
	var test_namespace: String = "inspect180_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	SaveManager.instance.set_process(false)
	SaveManager.instance.use_test_save_dir(test_namespace)
	sm.settings_path = "user://test_saves/%s/settings.cfg" % test_namespace
	sm.reset_controls() # Public setup: deterministic bindings, writes only unique test path.
	TranslationServer.set_locale("pt_BR")
	SessionManager.instance._current_map = null
	SessionManager.instance._night = false
	_runner_ui = get_tree().root.get_node_or_null(^"GutRunner/GutLayer/GutScene") as CanvasItem
	if _runner_ui != null:
		var script: Script = _runner_ui.get_script() as Script
		assert_true(script != null and script.resource_path.begins_with("res://addons/gut/"), "known runner overlay only")
		if script != null and script.resource_path.begins_with("res://addons/gut/"):
			_runner_visible = _runner_ui.visible
			_runner_ui.visible = false
			_runner_changed = true
		else:
			return
	_world = Node3D.new()
	add_child(_world)
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.position.y = -0.5
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(20, 1, 20)
	collision.shape = shape
	floor_body.add_child(collision)
	_world.add_child(floor_body)
	_player = PLAYER_SCENE.instantiate() as Player
	_player.position = Vector3(0, 0.2, 0)
	_world.add_child(_player)
	# Keep real physics/input active: inventory action dispatch runs in physics.
	await _frames()
	assert_true(_player.is_local())
	assert_not_null(_player.inspect_card)
	assert_false(_player.is_inspecting)
	assert_null(_player.inventory.get_selected(), "empty-hand shovel isolates labels from item switching")
	assert_true(InputMap.has_action("inspect"))
	# Neutral key must switch device without invoking any configured action.
	for action: StringName in InputMap.get_actions():
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				assert_false((event as InputEventKey).keycode == KEY_CAPSLOCK or (event as InputEventKey).physical_keycode == KEY_CAPSLOCK, "CapsLock must be unbound: " + str(action))
	_ready_for_case = true


func _inject(event: InputEvent) -> void:
	printerr("INSPECT180 ", _case, " input ", event.as_text())
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _frames()


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		await _inject(event)


func _button(code: JoyButton) -> void:
	for down: bool in [true, false]:
		var event: InputEventJoypadButton = InputEventJoypadButton.new()
		event.device = -1
		event.button_index = code
		event.pressed = down
		event.pressure = 1.0 if down else 0.0
		await _inject(event)


func _pad_motion(device: int = -1) -> void:
	for value: float in [0.6, 0.0]:
		var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
		event.device = device
		event.axis = JOY_AXIS_RIGHT_X
		event.axis_value = value
		await _inject(event)


func _remember_card() -> void:
	assert_true(_player.is_inspecting and _player.inspect_card.is_visible_in_tree(), "opened through real inspect input")
	_card_id = _player.inspect_card.get_instance_id()
	_content_before = {"title": _player.inspect_card.title_label.text, "stats": _player.inspect_card.stats_label.text, "description": _player.inspect_card.description_label.text, "selected": _player.inventory.selected_slot, "count": _player.inventory.slots.size()}


func _assert_live_card(label: String, previous: String) -> void:
	assert_true(_player.is_inspecting, "card remains open without toggling inspect")
	assert_true(_player.inspect_card.is_visible_in_tree())
	assert_eq(_player.inspect_card.get_instance_id(), _card_id, "same real widget")
	var text: String = _player.inspect_card.controls_label.text
	printerr("INSPECT180 ", _case, " observed_controls=", text)
	assert_string_contains(text, "[%s] Fechar inspeção" % label)
	assert_false(text.contains("[%s] Fechar inspeção" % previous), "old close binding replaced")
	assert_eq(_player.inspect_card.title_label.text, _content_before["title"])
	assert_eq(_player.inspect_card.stats_label.text, _content_before["stats"])
	assert_eq(_player.inspect_card.description_label.text, _content_before["description"])
	assert_eq(_player.inventory.selected_slot, _content_before["selected"])
	assert_eq(_player.inventory.slots.size(), _content_before["count"])


func test_open_keyboard_card_updates_after_real_pad_motion() -> void:
	_case = "keyboard_to_pad"
	if not _ready_for_case: return
	await _key(KEY_R)
	assert_false(InputDevice.using_gamepad())
	assert_string_contains(_player.inspect_card.controls_label.text, "[R] Fechar inspeção")
	_remember_card()
	await _pad_motion()
	assert_true(InputDevice.using_gamepad(), "real joy axis crossed activity threshold")
	_assert_live_card("R3", "R")


func test_open_pad_card_updates_after_real_neutral_key() -> void:
	_case = "pad_to_keyboard"
	if not _ready_for_case: return
	await _button(JOY_BUTTON_RIGHT_STICK)
	assert_true(InputDevice.using_gamepad())
	assert_string_contains(_player.inspect_card.controls_label.text, "[R3] Fechar inspeção")
	_remember_card()
	await _key(KEY_CAPSLOCK)
	assert_false(InputDevice.using_gamepad(), "real neutral key switched device without inspect action")
	_assert_live_card("R", "R3")


func test_open_pad_card_updates_after_public_pad_rebinding() -> void:
	_case = "pad_binding_changed"
	if not _ready_for_case: return
	await _button(JOY_BUTTON_RIGHT_STICK)
	assert_true(InputDevice.using_gamepad())
	_remember_card()
	printerr("INSPECT180 ", _case, " set_binding_begin")
	# There is no set_pad_binding API. Binding type selects the pad column.
	assert_true(SettingsManager.instance.set_binding("inspect", {"type": "joy_button", "code": JOY_BUTTON_RIGHT_SHOULDER}, true))
	printerr("INSPECT180 ", _case, " set_binding_returned")
	await _frames()
	assert_eq(SettingsManager.instance.get_pad_binding("inspect"), {"type": "joy_button", "code": JOY_BUTTON_RIGHT_SHOULDER})
	assert_true(InputDevice.using_gamepad(), "no event/device setter after rebinding")
	_assert_live_card("RB", "R3")


func after_each() -> void:
	if not _configured: return
	printerr("INSPECT180 ", _case, " cleanup_begin")
	if is_instance_valid(_world): _world.free()
	_world = null
	_player = null
	var sm: SettingsManager = SettingsManager.instance
	sm._values = (_before["settings"] as Dictionary).duplicate(true)
	sm.settings_path = str(_before["settings_path"])
	sm.apply_all() # No save_settings call: original disk contents are never overwritten.
	for action: StringName in InputMap.get_actions():
		if not _input_before.has(str(action)): InputMap.erase_action(action)
	for action: String in _input_before:
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_set_deadzone(action, float(_input_before[action]["deadzone"]))
		InputMap.action_erase_events(action)
		for event: InputEvent in _input_before[action]["events"]: InputMap.action_add_event(action, event)
	SessionManager.instance._current_map = _before["map"] as MapData
	SessionManager.instance._night = bool(_before["night"])
	GameState.instance.load_snapshot(_before["state"])
	for field: String in _save_before: SaveManager.instance.set(field, _save_before[field])
	TranslationServer.set_locale(str(_before["locale"]))
	# Restore active device through actual events after the actor is gone.
	if bool(_before["pad"]):
		await _pad_motion(int(_before["pad_id"]))
	elif bool(_before["pointer"]):
		var motion: InputEventMouseMotion = InputEventMouseMotion.new()
		motion.position = _before["mouse_position"]
		motion.global_position = motion.position
		motion.relative = Vector2(8, 0)
		await _inject(motion)
	else:
		await _key(KEY_CAPSLOCK)
	# Metadata only; observation itself was restored by events, not a device setter.
	InputDevice.instance._pad_device = int(_before["pad_id"])
	assert_eq(InputDevice.using_gamepad(), bool(_before["pad"]))
	assert_eq(InputDevice.using_pointer(), bool(_before["pointer"]))
	DisplayServer.window_set_mode(_before["window_mode"])
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, bool(_before["borderless"]))
	get_tree().root.size = _before["window_size"]
	get_tree().root.content_scale_factor = float(_before["window_scale"])
	Input.mouse_mode = _before["mouse"]
	if _runner_changed and is_instance_valid(_runner_ui): _runner_ui.visible = _runner_visible
	var focus: Control = _before["focus"] as Control
	if is_instance_valid(focus) and focus.is_visible_in_tree(): focus.grab_focus()
	await _frames()
	for field: String in _save_before: SaveManager.instance.set(field, _save_before[field])
	SaveManager.instance.set_process(bool(_before["save_process"]))
	_save_before.clear()
	_input_before.clear()
	_configured = false
	printerr("INSPECT180 ", _case, " cleanup_end")
