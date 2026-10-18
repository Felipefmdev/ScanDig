extends GutTest

## Aba Controles com a coluna do comando (#102): botões por coluna, captura de botão/eixo,
## Esc/B cancelam, conflito e troca por coluna, "Restaurar padrão" volta as duas, foco
## cima/baixo por coluna. Configurações em user://test_saves.

const SETTINGS_PATH: String = "user://test_saves/devb_controls_tab.cfg"

var _orig_path: String = ""
var _menu: SettingsMenu = null


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute("user://test_saves")
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(SETTINGS_PATH)
	var sm: SettingsManager = SettingsManager.instance
	_orig_path = sm.settings_path
	sm.settings_path = SETTINGS_PATH
	sm.reset_controls()
	_menu = SettingsMenu.new()
	add_child_autofree(_menu)
	_menu.tabs.current_tab = SettingsMenu.TAB_CONTROLS


func after_each() -> void:
	var sm: SettingsManager = SettingsManager.instance
	sm.reset_controls()
	sm.settings_path = _orig_path
	if InputDevice.instance != null:
		InputDevice.instance.set_using_gamepad(false)


func _joy(button: JoyButton) -> InputEventJoypadButton:
	var ev: InputEventJoypadButton = InputEventJoypadButton.new()
	ev.button_index = button
	ev.pressed = true
	return ev


func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var ev: InputEventJoypadMotion = InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	return ev


func test_two_columns_with_labels() -> void:
	for action: String in SettingsManager.CONTROL_ACTIONS:
		assert_true(_menu.control_buttons.has(action) and _menu.pad_buttons.has(action), "linha de %s nas duas colunas" % action)
	assert_eq((_menu.control_buttons["jump"] as Button).text, "Espaço")
	assert_eq((_menu.pad_buttons["jump"] as Button).text, "A")
	assert_eq((_menu.pad_buttons["use_tool"] as Button).text, "RT")
	assert_eq((_menu.pad_buttons["move_forward"] as Button).text, "Analógico E ↑")
	assert_eq((_menu.control_buttons["look_up"] as Button).text, "—", "olhar não tem tecla padrão")
	var grid: GridContainer = (_menu.control_buttons["jump"] as Control).get_parent() as GridContainer
	assert_eq(grid.columns, 3)
	var headers: Array[String] = []
	for child: Node in grid.get_children():
		if child is Label and ((child as Label).text == "Teclado/Mouse" or (child as Label).text == "Comando"):
			headers.append((child as Label).text)
	assert_eq(headers, ["Teclado/Mouse", "Comando"] as Array[String])


func test_capture_pad_button_with_conflict_and_swap() -> void:
	var sm: SettingsManager = SettingsManager.instance
	_menu.start_capture("jump", SettingsMenu.COLUMN_PAD)
	assert_eq((_menu.pad_buttons["jump"] as Button).text, SettingsMenu.CAPTURE_PAD_TEXT)
	assert_eq((_menu.control_buttons["jump"] as Button).text, "Espaço", "a outra coluna não espera")
	_menu._input(_axis(JOY_AXIS_RIGHT_X, 0.3))
	assert_eq(_menu.capturing, "jump", "eixo fraco não conta")
	_menu._input(_joy(JOY_BUTTON_Y))
	assert_true(_menu.conflict_panel.visible, "Y já é próximo espaço: pergunta")
	assert_string_contains(_menu.conflict_label.text, "Próximo espaço")
	_menu.swap_button.pressed.emit()
	assert_eq(sm.get_pad_binding("jump"), {"type": "joy_button", "code": JOY_BUTTON_Y})
	assert_eq(sm.get_pad_binding("slot_next"), {"type": "joy_button", "code": JOY_BUTTON_A}, "troca na coluna do comando")
	assert_eq(sm.get_binding("jump"), {"type": "key", "code": KEY_SPACE}, "teclado intacto")
	assert_eq((_menu.pad_buttons["jump"] as Button).text, "Y")


func test_capture_pad_axis() -> void:
	var sm: SettingsManager = SettingsManager.instance
	_menu.start_capture("attack", SettingsMenu.COLUMN_PAD)
	_menu._input(_axis(JOY_AXIS_RIGHT_Y, 0.9))
	assert_true(_menu.conflict_panel.visible, "analógico D ↓ já é olhar para baixo")
	_menu.conflict_cancel_button.pressed.emit()
	assert_eq(_menu.capturing, "", "cancelar sai da captura")
	_menu.start_capture("slot_1", SettingsMenu.COLUMN_PAD)
	_menu._input(_axis(JOY_AXIS_TRIGGER_LEFT, -0.0))
	_menu._input(_joy(JOY_BUTTON_DPAD_UP))
	assert_eq(sm.get_pad_binding("slot_1"), {"type": "joy_button", "code": JOY_BUTTON_DPAD_UP}, "↑ livre vira o espaço 1")


func test_b_and_esc_cancel_capture() -> void:
	var sm: SettingsManager = SettingsManager.instance
	_menu.start_capture("attack", SettingsMenu.COLUMN_PAD)
	_menu._input(_joy(JOY_BUTTON_B))
	assert_eq(_menu.capturing, "", "B cancela")
	assert_eq(sm.get_pad_binding("attack"), {"type": "joy_button", "code": JOY_BUTTON_RIGHT_SHOULDER}, "nada mudou")
	_menu.start_capture("attack", SettingsMenu.COLUMN_PAD)
	var esc: InputEventKey = InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	_menu._input(esc)
	assert_eq(_menu.capturing, "", "Esc cancela")


func test_keyboard_column_ignores_pad() -> void:
	var sm: SettingsManager = SettingsManager.instance
	_menu.start_capture("jump", SettingsMenu.COLUMN_KEYBOARD)
	_menu._input(_joy(JOY_BUTTON_X))
	assert_eq(_menu.capturing, "jump", "botão do comando não vira tecla")
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_K
	key.pressed = true
	_menu._input(key)
	assert_eq(sm.get_binding("jump"), {"type": "key", "code": KEY_K})
	assert_eq(sm.get_pad_binding("jump"), {"type": "joy_button", "code": JOY_BUTTON_A}, "comando intacto")
	_menu.start_capture("interact", SettingsMenu.COLUMN_PAD)
	_menu._input(key)
	assert_eq(_menu.capturing, "interact", "tecla não vira botão do comando")


func test_restore_defaults_restores_both_columns() -> void:
	var sm: SettingsManager = SettingsManager.instance
	sm.set_binding("jump", {"type": "key", "code": KEY_K})
	sm.set_binding("jump", {"type": "joy_button", "code": JOY_BUTTON_DPAD_UP})
	_menu.defaults_button.pressed.emit()
	assert_eq(sm.get_binding("jump"), {"type": "key", "code": KEY_SPACE})
	assert_eq(sm.get_pad_binding("jump"), {"type": "joy_button", "code": JOY_BUTTON_A})
	assert_eq((_menu.pad_buttons["jump"] as Button).text, "A")


func test_focus_moves_within_each_column() -> void:
	await get_tree().process_frame  # a aba Controles fica visível no frame seguinte
	_menu.focus_first()
	var kb_first: Button = _menu.control_buttons[SettingsManager.CONTROL_ACTIONS[0]]
	var kb_second: Button = _menu.control_buttons[SettingsManager.CONTROL_ACTIONS[1]]
	var pad_first: Button = _menu.pad_buttons[SettingsManager.CONTROL_ACTIONS[0]]
	var pad_second: Button = _menu.pad_buttons[SettingsManager.CONTROL_ACTIONS[1]]
	assert_eq(kb_first.focus_neighbor_bottom, kb_second.get_path(), "↓ na coluna do teclado")
	assert_eq(pad_first.focus_neighbor_bottom, pad_second.get_path(), "↓ na coluna do comando")
	assert_eq(kb_first.focus_neighbor_right, pad_first.get_path(), "→ vai para o comando")
	assert_eq(pad_first.focus_neighbor_left, kb_first.get_path())
