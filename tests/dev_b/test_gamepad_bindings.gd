extends GutTest

## Controle (#102): bindings de comando no CoreSettings (coluna [controls_pad]) e InputDevice
## (dispositivo em uso, nomes dos botões, olhar com o analógico). Configurações em
## user://test_saves (nunca no scandig_settings.cfg do jogador).

const SETTINGS_PATH: String = "user://test_saves/devb_gamepad_settings.cfg"

var _orig_path: String = ""


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute("user://test_saves")
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(SETTINGS_PATH)
	var sm: SettingsManager = SettingsManager.instance
	_orig_path = sm.settings_path
	sm.settings_path = SETTINGS_PATH
	sm.reset_controls()


func after_each() -> void:
	var sm: SettingsManager = SettingsManager.instance
	sm.reset_controls()
	sm.settings_path = _orig_path
	if InputDevice.instance != null:
		InputDevice.instance.set_using_gamepad(false)


func _pad_events(action: String) -> Array[InputEvent]:
	var out: Array[InputEvent] = []
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
			out.append(ev)
	return out


func _has_button(action: String, button: JoyButton) -> bool:
	for ev: InputEvent in _pad_events(action):
		if ev is InputEventJoypadButton and (ev as InputEventJoypadButton).button_index == button:
			return true
	return false


func test_default_pad_bindings_in_input_map() -> void:
	assert_true(_has_button("jump", JOY_BUTTON_A), "A pula")
	assert_true(_has_button("interact", JOY_BUTTON_X), "X interage")
	assert_true(_has_button("drop", JOY_BUTTON_B), "B solta/arremessa")
	assert_true(_has_button("attack", JOY_BUTTON_RIGHT_SHOULDER), "RB ataca")
	assert_true(_has_button("slot_prev", JOY_BUTTON_LEFT_SHOULDER) and _has_button("slot_prev", JOY_BUTTON_DPAD_LEFT), "LB e ← voltam o espaço")
	assert_true(_has_button("slot_next", JOY_BUTTON_Y) and _has_button("slot_next", JOY_BUTTON_DPAD_RIGHT), "Y e → avançam o espaço")
	assert_true(_has_button("pause", JOY_BUTTON_START), "Start pausa")
	assert_true(_has_button("sprint", JOY_BUTTON_LEFT_STICK), "L3 corre")
	assert_true(_has_button("inspect", JOY_BUTTON_RIGHT_STICK), "R3 abre a inspeção sem depender do teclado")
	assert_eq(SettingsManager.instance.find_conflict("inspect", {"type": "joy_button", "code": JOY_BUTTON_RIGHT_STICK}), "", "R3 não disputa outra ação padrão")
	var fwd: Array[InputEvent] = _pad_events("move_forward")
	assert_eq(fwd.size(), 1)
	var motion: InputEventJoypadMotion = fwd[0] as InputEventJoypadMotion
	assert_true(motion != null and motion.axis == JOY_AXIS_LEFT_Y and motion.axis_value < 0.0, "analógico esquerdo para cima anda")
	assert_eq(motion.device, -1, "qualquer controle")
	var tool: InputEventJoypadMotion = _pad_events("use_tool")[0] as InputEventJoypadMotion
	assert_eq(tool.axis, JOY_AXIS_TRIGGER_RIGHT, "RT usa a ferramenta")
	assert_almost_eq(InputMap.action_get_deadzone("look_right"), 0.02, 0.001, "olhar: zona morta no InputDevice")
	assert_true(_has_button("ui_accept", JOY_BUTTON_A), "menus: A confirma")
	assert_true(_has_button("ui_cancel", JOY_BUTTON_B), "menus: B volta")
	var keys: int = 0
	for ev: InputEvent in InputMap.action_get_events("jump"):
		if ev is InputEventKey:
			keys += 1
	assert_eq(keys, 1, "a coluna do teclado continua lá")


func test_remap_pad_save_and_load() -> void:
	var sm: SettingsManager = SettingsManager.instance
	var y: Dictionary = {"type": "joy_button", "code": JOY_BUTTON_Y}
	assert_eq(sm.find_conflict("jump", y), "slot_next", "Y já é próximo espaço")
	assert_false(sm.set_binding("jump", y), "conflito sem trocar: recusa")
	assert_true(sm.set_binding("jump", y, true), "trocar")
	assert_eq(sm.get_pad_binding("jump"), y)
	assert_eq(sm.get_pad_binding("slot_next"), {"type": "joy_button", "code": JOY_BUTTON_A}, "a outra ação fica com o A")
	assert_true(_has_button("jump", JOY_BUTTON_Y) and not _has_button("jump", JOY_BUTTON_A), "InputMap atualizado")
	assert_eq(sm.get_binding("jump"), {"type": "key", "code": KEY_SPACE}, "a coluna do teclado não mudou")
	var lt_down: Dictionary = {"type": "joy_axis", "code": JOY_AXIS_RIGHT_Y, "sign": 1}
	assert_eq(sm.find_conflict("look_up", lt_down), "look_down")
	var cfg: ConfigFile = ConfigFile.new()
	assert_eq(cfg.load(SETTINGS_PATH), OK)
	assert_true(cfg.has_section(SettingsManager.CONTROLS_PAD), "gravado em [controls_pad]")
	sm.load_settings()
	assert_eq(sm.get_pad_binding("jump"), y, "carregado do arquivo de teste")
	assert_eq(sm.get_pad_binding("slot_next"), {"type": "joy_button", "code": JOY_BUTTON_A})


func test_swap_without_previous_unbinds_other() -> void:
	var sm: SettingsManager = SettingsManager.instance
	# slot_1 não tem botão no comando: pegar o A do pulo deixa o pulo sem botão.
	assert_true(sm.get_pad_binding("slot_1").is_empty())
	assert_true(sm.set_binding("slot_1", {"type": "joy_button", "code": JOY_BUTTON_A}, true))
	assert_true(sm.get_pad_binding("jump").is_empty(), "pulo sem botão (não volta ao padrão)")
	assert_true(_pad_events("jump").is_empty())
	sm.reset_controls()
	assert_true(_has_button("jump", JOY_BUTTON_A), "restaurar padrão volta as duas colunas")
	assert_true(sm.get_pad_binding("slot_1").is_empty())


func test_old_settings_file_keeps_keyboard_and_gets_pad_defaults() -> void:
	var sm: SettingsManager = SettingsManager.instance
	var old: ConfigFile = ConfigFile.new()
	old.set_value("controls", "jump", {"type": "key", "code": KEY_K})
	old.set_value("gameplay", "fov", 80.0)
	old.save(SETTINGS_PATH)
	sm.load_settings()
	sm.apply_all()
	assert_eq(sm.get_binding("jump"), {"type": "key", "code": KEY_K}, "troca antiga do teclado vale")
	assert_eq(sm.get_pad_binding("jump"), {"type": "joy_button", "code": JOY_BUTTON_A}, "comando com os padrões")
	assert_true(_has_button("jump", JOY_BUTTON_A))
	assert_true(_has_button("inspect", JOY_BUTTON_RIGHT_STICK), "configuração antiga recebe o padrão de inspeção")


func test_old_custom_right_stick_binding_keeps_priority() -> void:
	var sm: SettingsManager = SettingsManager.instance
	var old: ConfigFile = ConfigFile.new()
	var right_stick: Dictionary = {"type": "joy_button", "code": JOY_BUTTON_RIGHT_STICK}
	old.set_value(SettingsManager.CONTROLS_PAD, "jump", right_stick)
	assert_eq(old.save(SETTINGS_PATH), OK)
	sm.load_settings()
	sm.apply_all()
	assert_eq(sm.get_pad_binding("jump"), right_stick, "preferência antiga é preservada")
	assert_true(_has_button("jump", JOY_BUTTON_RIGHT_STICK))
	assert_true(sm.get_pad_binding("inspect").is_empty(), "novo padrão não disputa R3 já personalizado")
	assert_true(_pad_events("inspect").is_empty(), "R3 não dispara duas ações")


func test_sanitize_pad_section_and_look_sensitivity() -> void:
	var out: Dictionary = SettingsManager.sanitize(SettingsManager.CONTROLS_PAD, {
		"jump": {"type": "joy_button", "code": JOY_BUTTON_X},
		"drop": {"type": "joy_axis", "code": JOY_AXIS_LEFT_X, "sign": 3},
		"attack": {"type": "key", "code": KEY_F},
		"sprint": {"type": "none"},
	})
	assert_eq(out["jump"], {"type": "joy_button", "code": JOY_BUTTON_X})
	assert_false(out.has("drop"), "sinal inválido cai fora")
	assert_false(out.has("attack"), "tecla não vai para a coluna do comando")
	assert_eq(out["sprint"], {"type": "none"}, "sem botão explícito")
	var g: Dictionary = SettingsManager.sanitize(SettingsManager.GAMEPLAY, {"pad_look_sensitivity": 999})
	assert_eq(g["pad_look_sensitivity"], SettingsManager.PAD_LOOK_SENSITIVITY_RANGE.y)
	assert_eq(SettingsManager.sanitize(SettingsManager.GAMEPLAY, {})["pad_look_sensitivity"], 180.0)


func test_labels_and_events() -> void:
	assert_eq(SettingsManager.binding_label({"type": "joy_button", "code": JOY_BUTTON_A}), "A")
	assert_eq(SettingsManager.binding_label({"type": "joy_button", "code": JOY_BUTTON_LEFT_SHOULDER}), "LB")
	assert_eq(SettingsManager.binding_label({"type": "joy_button", "code": JOY_BUTTON_DPAD_LEFT}), "←")
	assert_eq(SettingsManager.binding_label({"type": "joy_axis", "code": JOY_AXIS_TRIGGER_RIGHT, "sign": 1}), "RT")
	assert_eq(SettingsManager.binding_label({"type": "joy_axis", "code": JOY_AXIS_LEFT_Y, "sign": -1}), "Analógico E ↑")
	assert_eq(SettingsManager.binding_label({"type": "key", "code": KEY_E}), "E")
	var press: InputEventJoypadButton = InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_B
	press.pressed = true
	assert_eq(SettingsManager.binding_from_event(press), {"type": "joy_button", "code": JOY_BUTTON_B})
	var axis: InputEventJoypadMotion = InputEventJoypadMotion.new()
	axis.axis = JOY_AXIS_TRIGGER_LEFT
	axis.axis_value = 0.8
	assert_eq(SettingsManager.binding_from_event(axis), {"type": "joy_axis", "code": JOY_AXIS_TRIGGER_LEFT, "sign": 1})
	axis.axis_value = -0.3
	assert_true(SettingsManager.binding_from_event(axis).is_empty(), "eixo fraco não vira binding")


func test_input_device_switches_and_labels() -> void:
	var device: InputDevice = InputDevice.instance
	assert_not_null(device, "autoload CoreInputDevice")
	device.set_using_gamepad(false)
	watch_signals(device)
	var drift: InputEventJoypadMotion = InputEventJoypadMotion.new()
	drift.axis = JOY_AXIS_RIGHT_X
	drift.axis_value = 0.1
	device.observe(drift)
	assert_false(device.is_using_gamepad(), "deriva leve não troca")
	var press: InputEventJoypadButton = InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_A
	press.pressed = true
	device.observe(press)
	device.observe(press)
	assert_true(device.is_using_gamepad())
	assert_signal_emit_count(device, "device_changed", 1, "uma vez por troca")
	assert_eq(InputDevice.action_label("drop"), "B")
	assert_eq(InputDevice.fill_action_labels("Segure [{drop}] para arremessar"), "Segure [B] para arremessar")
	var jitter: InputEventMouseMotion = InputEventMouseMotion.new()
	jitter.relative = Vector2(1, 1)
	device.observe(jitter)
	assert_true(device.is_using_gamepad(), "tremida do mouse não troca")
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	device.observe(key)
	assert_false(device.is_using_gamepad())
	assert_signal_emit_count(device, "device_changed", 2)
	assert_eq(InputDevice.action_label("drop"), "Q")
	assert_eq(InputDevice.action_label("slot_next"), "Y", "sem tecla: cai no botão do comando")


## #122: ponteiro = o mouse foi o último a mexer; tecla e comando desligam (borda de foco nos menus).
func test_pointer_follows_last_input() -> void:
	var device: InputDevice = InputDevice.instance
	device.set_using_pointer(true)
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_DOWN
	key.pressed = true
	device.observe(key)
	assert_false(InputDevice.using_pointer(), "tecla: navegando pelo teclado")
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	device.observe(click)
	assert_true(InputDevice.using_pointer(), "clique: mouse")
	var press: InputEventJoypadButton = InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_DPAD_DOWN
	press.pressed = true
	device.observe(press)
	assert_false(InputDevice.using_pointer(), "comando: sem ponteiro")
	var holder: Control = Control.new()
	add_child_autofree(holder)
	UiFocus.follow_pointer(holder)
	assert_null(holder.theme, "fora do mouse: tema herdado (com borda)")
	device.set_using_pointer(true)
	assert_eq(holder.theme, UiFocus.pointer_theme(), "mouse: tema que apaga a borda de foco")
	device.set_using_gamepad(false)


func test_look_vector_deadzone_and_curve() -> void:
	assert_eq(InputDevice.look_vector(Vector2(0.1, 0.05)), Vector2.ZERO, "dentro da zona morta: zero")
	assert_almost_eq(InputDevice.look_vector(Vector2(1, 0)), Vector2(1, 0), Vector2.ONE * 0.0001, "no fim: 1")
	var half: Vector2 = InputDevice.look_vector(Vector2(0.575, 0))
	var expected: float = pow((0.575 - InputDevice.LOOK_DEADZONE) / (1.0 - InputDevice.LOOK_DEADZONE), InputDevice.LOOK_CURVE)
	assert_almost_eq(half.x, expected, 0.0001, "curva na magnitude")
	assert_lt(half.x, 0.5, "precisão perto do centro")
	var rel: Vector2 = InputDevice.pad_look_relative(Vector2(1, 0), 0.5, 180.0, 0.0025)
	assert_almost_eq(rel.x * 0.0025, deg_to_rad(90.0), 0.0001, "180°/s por 0,5 s = 90° pelo caminho do mouse")
	assert_eq(InputDevice.pad_look_relative(Vector2(0.05, 0), 1.0, 180.0, 0.0025), Vector2.ZERO)
