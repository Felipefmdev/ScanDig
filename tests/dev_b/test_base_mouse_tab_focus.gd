extends GutTest

## #180: native synthetic mouse tab click -> Tab -> Shift+Tab BEFORE graph audit.
## No renderer/PNG dependency: run normally in headless too. Input is not hardware.
## Real Base, no .bot_runs inheritance, no fake pressed/tab signal or focus seeding.
const BASE_SCENE: PackedScene = preload("res://ui/base_station_ui.tscn")
var _base: BaseStationUI = null
var _before: Dictionary = {}
var _save_before: Dictionary = {}
var _runner_ui: CanvasItem = null
var _runner_visible: bool = false
var _runner_changed: bool = false
var _configured: bool = false
var _neutral_key: Key = KEY_CAPSLOCK


func _frames(count: int = 3) -> void:
	for index: int in count:
		await get_tree().process_frame


func before_each() -> void:
	_configured = false
	_runner_changed = false
	assert_false(get_tree().paused)
	assert_false(PauseMenu.is_open() or VictoryScreen.is_open(), "isolated GUT process without foreign modal")
	if get_tree().paused or PauseMenu.is_open() or VictoryScreen.is_open(): return
	var neutral_found: bool = false
	for candidate: Key in [KEY_CAPSLOCK, KEY_F15, KEY_F16]:
		var bound: bool = false
		for action: StringName in InputMap.get_actions():
			for event: InputEvent in InputMap.action_get_events(action):
				if event is InputEventKey and ((event as InputEventKey).keycode == candidate or (event as InputEventKey).physical_keycode == candidate): bound = true
		if not bound:
			_neutral_key = candidate
			neutral_found = true
			break
	assert_true(neutral_found, "unbound neutral key available for device restoration")
	if not neutral_found: return
	_before = {"state": GameState.instance.get_snapshot().duplicate(true), "launch": SessionManager.launch_mode, "map": SessionManager.instance._current_map, "night": SessionManager.instance._night, "size": get_tree().root.size, "scale": get_tree().root.content_scale_factor, "mouse": Input.mouse_mode, "focus": get_viewport().gui_get_focus_owner(), "pad": InputDevice.using_gamepad(), "pointer": InputDevice.using_pointer(), "pad_id": InputDevice.instance._pad_device, "mouse_position": get_viewport().get_mouse_position(), "save_process": SaveManager.instance.is_processing(), "settings": SettingsManager.instance._values.duplicate(true), "settings_path": SettingsManager.instance.settings_path}
	for field: String in ["save_path", "_base_path", "_slot", "_progress_applied", "_write_blocked", "play_time_s", "last_map"]:
		_save_before[field] = SaveManager.instance.get(field)
	_configured = true
	SaveManager.instance.set_process(false)
	SaveManager.instance.use_test_save_dir("base_mouse180_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	SessionManager.launch_mode = SessionManager.LAUNCH_SOLO
	SessionManager.instance._current_map = null
	SessionManager.instance._night = false
	GameState.instance.reset_state()
	assert_true(GameState.instance.seen_creatures.is_empty(), "real empty diary fixture")
	assert_true(GameState.instance.defeated_bosses.is_empty())
	get_tree().root.size = Vector2i(1280, 720)
	get_tree().root.content_scale_factor = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_runner_ui = get_tree().root.get_node_or_null(^"GutRunner/GutLayer/GutScene") as CanvasItem
	if _runner_ui != null:
		var script: Script = _runner_ui.get_script() as Script
		assert_true(script != null and script.resource_path.begins_with("res://addons/gut/"), "hide only known runner CanvasItem")
		if script != null and script.resource_path.begins_with("res://addons/gut/"):
			_runner_visible = _runner_ui.visible
			_runner_ui.visible = false
			_runner_changed = true
	_base = BASE_SCENE.instantiate() as BaseStationUI
	get_tree().root.add_child(_base)
	await _frames(6)
	assert_true(_base.is_visible_in_tree())
	assert_not_null(_base.tab_container)
	assert_true(_base.tab_container.get_tab_bar().is_visible_in_tree())


func _inject(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _frames(2)


func _click_tab(bar: TabBar, index: int) -> void:
	var tab_rect: Rect2 = bar.get_tab_rect(index)
	assert_true(tab_rect.has_area(), "real visible tab hit area")
	# Match production CanvasItem and final viewport transforms; do not assume
	# global_rect coordinates are already physical viewport input coordinates.
	var position: Vector2 = bar.get_viewport().get_final_transform() * (bar.get_global_transform_with_canvas() * tab_rect.get_center())
	print("BASE_MOUSE180 tab=", index, " local=", tab_rect, " input=", position, " final=", bar.get_viewport().get_final_transform())
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	motion.relative = Vector2(8, 0)
	await _inject(motion)
	var hover: Control = get_viewport().gui_get_hovered_control()
	assert_true(hover == bar or (hover != null and bar.is_ancestor_of(hover)), "mouse hits actual product TabBar")
	for down: bool in [true, false]:
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = position
		click.global_position = position
		click.pressed = down
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		await _inject(click)
	await _frames()


func _exercise(page_name: String) -> void:
	if not _configured: return
	var tabs: TabContainer = _base.tab_container
	var bar: TabBar = tabs.get_tab_bar()
	var index: int = -1
	for candidate: int in tabs.get_tab_count():
		if str(tabs.get_tab_control(candidate).name) == page_name:
			index = candidate
	assert_gte(index, 0, "authored real page exists: " + page_name)
	if index < 0: return
	assert_false(tabs.is_tab_hidden(index))
	await _click_tab(bar, index)
	assert_eq(tabs.current_tab, index, "native mouse event selected actual page")
	assert_true(bar.has_focus(), "mouse click focuses TabBar, no manual grab_focus")
	var page: Control = tabs.get_current_tab_control()
	assert_true(page.is_visible_in_tree())
	if page_name == "Diário":
		assert_true(GameState.instance.seen_creatures.is_empty())
		assert_true(GameState.instance.defeated_bosses.is_empty())
	# These mixed-input checks MUST precede UiNavAudit, which grabs focus while
	# exploring and restores tab state. No fixture _sync_focus call is allowed.
	await UiNavAudit.inject(get_viewport(), &"ui_focus_next", UiNavAudit.KEYBOARD)
	await _frames()
	var focused: Control = get_viewport().gui_get_focus_owner()
	assert_not_null(focused, "Tab after mouse click preserves focus")
	if focused == null: return
	assert_true(focused.is_visible_in_tree(), "Tab never lands on hidden page")
	assert_true(focused == bar or page.is_ancestor_of(focused) or focused == page, "Tab stays in clicked page/bar chain")
	var page_controls: Array[Control] = UiFocus.focusables(page)
	if not page_controls.is_empty():
		assert_true(focused != bar, "nonempty page can be reached from clicked bar")
	await UiNavAudit.inject(get_viewport(), &"ui_focus_prev", UiNavAudit.KEYBOARD)
	await _frames()
	assert_true(bar.has_focus(), "Shift+Tab returns to clicked TabBar")
	assert_eq(tabs.current_tab, index, "mixed input did not silently change clicked page")
	var audit: Dictionary = await UiNavAudit.audit(_base, UiNavAudit.KEYBOARD, false)
	print("BASE_MOUSE180 audit ", page_name, " ", JSON.stringify(audit))
	assert_true(bool(audit["initial_ok"]), "audit starts from real mixed-input focus")
	assert_true((audit["missing"] as Array).is_empty(), "all visible interactive controls remain reachable")
	assert_true((audit["traps"] as Array).is_empty(), "no focus traps after restore/deferred drain")
	assert_true((audit["no_focus_style"] as Array).is_empty(), "focus style protection unchanged")
	assert_true(bar.has_focus(), "audit returns to original TabBar focus")
	assert_eq(tabs.current_tab, index, "audit restores original selected page")


func test_mouse_museum_tab_then_tab_shift_tab_and_keyboard_audit() -> void:
	await _exercise("Museu de Achados")


func test_mouse_empty_diary_tab_then_tab_shift_tab_and_keyboard_audit() -> void:
	await _exercise("Diário")


func after_each() -> void:
	if not _configured: return
	if is_instance_valid(_base): _base.free()
	_base = null
	await _frames()
	SessionManager.launch_mode = str(_before["launch"])
	SessionManager.instance._current_map = _before["map"] as MapData
	SessionManager.instance._night = bool(_before["night"])
	GameState.instance.load_snapshot(_before["state"])
	# Restore InputDevice by real neutral events after product UI is gone.
	if bool(_before["pad"]):
		for value: float in [0.6, 0.0]:
			var joy: InputEventJoypadMotion = InputEventJoypadMotion.new()
			joy.device = int(_before["pad_id"])
			joy.axis = JOY_AXIS_RIGHT_X
			joy.axis_value = value
			await _inject(joy)
	elif bool(_before["pointer"]):
		var motion: InputEventMouseMotion = InputEventMouseMotion.new()
		motion.position = _before["mouse_position"]
		motion.global_position = motion.position
		motion.relative = Vector2(8, 0)
		await _inject(motion)
	else:
		for down: bool in [true, false]:
			var key: InputEventKey = InputEventKey.new()
			key.keycode = _neutral_key
			key.physical_keycode = _neutral_key
			key.pressed = down
			await _inject(key)
	InputDevice.instance._pad_device = int(_before["pad_id"])
	assert_eq(InputDevice.using_gamepad(), bool(_before["pad"]))
	assert_eq(InputDevice.using_pointer(), bool(_before["pointer"]))
	get_tree().root.size = _before["size"]
	get_tree().root.content_scale_factor = float(_before["scale"])
	Input.mouse_mode = _before["mouse"]
	if _runner_changed and is_instance_valid(_runner_ui): _runner_ui.visible = _runner_visible
	var focus: Control = _before["focus"] as Control
	if is_instance_valid(focus) and focus.is_visible_in_tree(): focus.grab_focus()
	await _frames()
	for field: String in _save_before: SaveManager.instance.set(field, _save_before[field])
	SaveManager.instance.set_process(bool(_before["save_process"]))
	assert_eq(SettingsManager.instance._values, _before["settings"], "Settings unchanged; no settings API/disk writes")
	assert_eq(SettingsManager.instance.settings_path, str(_before["settings_path"]))
	_save_before.clear()
	_configured = false
