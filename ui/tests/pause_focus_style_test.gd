extends SceneTree
## #77: foco local fino em Continuar, preservando navegacao e ativacao reais.
const THEME: Theme = preload("res://ui/theme/scandig_theme.tres")
var _checks: int = 0
var _fails: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	_checks += 1
	_fails += 0 if ok else 1
	print(("PASS " if ok else "FAIL ") + message)


func _key(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	await process_frame
	event = event.duplicate() as InputEventKey
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func _pad(button: JoyButton) -> void:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	await process_frame
	event = event.duplicate() as InputEventJoypadButton
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func _run() -> void:
	await process_frame
	var menu: PauseMenu = root.get_node(^"CorePauseMenu") as PauseMenu
	var shared: StyleBoxFlat = THEME.get_stylebox(&"focus", &"PrimaryButton") as StyleBoxFlat
	var focus: StyleBoxFlat = menu.continue_button.get_theme_stylebox(&"focus") as StyleBoxFlat
	_check(menu.continue_button.has_theme_stylebox_override(&"focus") and focus != shared, "Continuar possui foco privado sem alterar Theme")
	var thin: bool = focus != null and not focus.draw_center
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		thin = thin and focus.get_border_width(side) == 1 and is_zero_approx(focus.get_expand_margin(side))
	_check(thin, "foco tem borda1 interna sem expansao externa ou preenchimento")
	_check(focus != null and focus.border_color.is_equal_approx(UiPalette.PAPER_LIGHT), "indicador claro visivel sobre borda escura e botao laranja")
	_check(focus != null and focus.corner_radius_top_left == shared.corner_radius_top_left and focus.corner_radius_bottom_right == shared.corner_radius_bottom_right, "cantos compativeis com estilo original")
	_check(shared.border_width_left == 3 and is_equal_approx(shared.expand_margin_left, 3.0) and not menu.settings_button.has_theme_stylebox_override(&"focus"), "Theme e demais botoes preservados")
	var home: Button = Button.new()
	home.text = "Foco anterior QA"
	root.add_child(home)
	home.grab_focus()
	var mouse_before: Input.MouseMode = Input.mouse_mode
	_check(menu.open(), "menu abre pelo fluxo existente")
	_check(menu.continue_button.focus_mode == Control.FOCUS_ALL and menu.continue_button.has_focus(), "open mantem FOCUS_ALL e grab_focus em Continuar")
	await _key(KEY_TAB)
	_check(menu.settings_button.has_focus(), "Tab navega de Continuar para Configuracoes")
	await _key(KEY_UP)
	_check(menu.continue_button.has_focus(), "seta cima retorna para Continuar")
	await _pad(JOY_BUTTON_DPAD_DOWN)
	_check(menu.settings_button.has_focus(), "controle navega para Configuracoes")
	await _pad(JOY_BUTTON_DPAD_UP)
	_check(menu.continue_button.has_focus(), "controle retorna para Continuar")
	await _key(KEY_ENTER)
	_check(not PauseMenu.is_open() and not paused, "ativacao real de Continuar fecha e despausa")
	_check(home.has_focus() and Input.mouse_mode == mouse_before, "fechar restaura foco e mouse anteriores")
	menu.close()
	home.free()
	print("RESULT checks=%d fails=%d" % [_checks, _fails])
	quit(0 if _fails == 0 else 1)
