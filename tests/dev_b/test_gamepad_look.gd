extends GutTest

## Olhar com o analógico direito (#102): zona morta zera, a curva/sensibilidade dão os graus,
## inverter Y vale, o caído usa a órbita; menu aberto ou mouse solto bloqueiam (a mesma trava do
## mouse); LB/Y (← →) trocam o espaço da mochila. O headless não captura o mouse, então a conta
## (_pad_look_step) e a trava (_pad_look_allowed) são testadas separadas.

const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/player.tscn")

var _player: Player = null


func before_each() -> void:
	_player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(_player)
	SettingsManager.instance.set_section(SettingsManager.GAMEPLAY, {"pad_look_sensitivity": 180.0, "invert_y": false}, false)
	_player.invert_y = false


func after_each() -> void:
	for action: StringName in [&"look_left", &"look_right", &"look_up", &"look_down"]:
		Input.action_release(action)
	if PauseMenu.instance != null:
		PauseMenu.instance.close()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_raw_input_reads_look_actions() -> void:
	Input.action_press(&"look_right", 0.8)
	Input.action_press(&"look_up", 0.4)
	assert_almost_eq(InputDevice.raw_look_input(), Vector2(0.8, -0.4), Vector2.ONE * 0.001, "direita/cima do analógico direito")


func test_deadzone_does_nothing() -> void:
	var yaw: float = _player.rotation.y
	_player._pad_look_step(0.5, Vector2(0.1, 0.05))
	assert_eq(_player.rotation.y, yaw, "deriva dentro da zona morta não gira")


func test_full_stick_turns_by_sensitivity() -> void:
	var yaw: float = _player.rotation.y
	_player._pad_look_step(0.5, Vector2(1, 0))
	assert_almost_eq(_player.rotation.y, yaw - deg_to_rad(90.0), 0.001, "180°/s por 0,5 s = 90° para a direita")
	SettingsManager.instance.set_section(SettingsManager.GAMEPLAY, {"pad_look_sensitivity": 90.0}, false)
	yaw = _player.rotation.y
	_player._pad_look_step(0.5, Vector2(-1, 0))
	assert_almost_eq(_player.rotation.y, yaw + deg_to_rad(45.0), 0.001, "sensibilidade 90°/s")


func test_curve_is_gentler_than_linear() -> void:
	var yaw: float = _player.rotation.y
	_player._pad_look_step(1.0, Vector2(0.5, 0))
	var turned: float = absf(_player.rotation.y - yaw)
	assert_gt(turned, 0.0)
	assert_lt(turned, deg_to_rad(90.0), "meio analógico gira menos que a metade (curva)")


func test_invert_y_applies_to_stick() -> void:
	_player.head.rotation.x = 0.0
	_player._pad_look_step(0.1, Vector2(0, 1))
	assert_lt(_player.head.rotation.x, 0.0, "analógico para baixo olha para baixo")
	_player.head.rotation.x = 0.0
	_player.invert_y = true
	_player._pad_look_step(0.1, Vector2(0, 1))
	assert_gt(_player.head.rotation.x, 0.0, "inverter Y vale para o comando")


func test_downed_uses_orbit() -> void:
	_player.is_downed = true
	var orbit_yaw: float = _player._downed_orbit_yaw
	var body_yaw: float = _player.rotation.y
	_player._pad_look_step(0.25, Vector2(1, 0))
	assert_ne(_player._downed_orbit_yaw, orbit_yaw, "caído: o analógico gira a órbita")
	assert_eq(_player.rotation.y, body_yaw, "e não o corpo")


func test_menu_or_free_mouse_blocks() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	assert_false(_player._pad_look_allowed(), "mouse solto (solo): não olha, como o mouse")
	var yaw: float = _player.rotation.y
	Input.action_press(&"look_right", 1.0)
	_player._apply_pad_look(0.5)
	assert_eq(_player.rotation.y, yaw)
	assert_true(PauseMenu.instance.open())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	assert_false(_player._pad_look_allowed(), "menu aberto: não olha")


func test_shoulder_and_y_cycle_backpack() -> void:
	_player.inventory.select(0)
	var y: InputEventJoypadButton = InputEventJoypadButton.new()
	y.button_index = JOY_BUTTON_Y
	y.pressed = true
	_player._unhandled_input(y)
	assert_eq(_player.inventory.selected_slot, 1, "Y = próximo espaço")
	var lb: InputEventJoypadButton = InputEventJoypadButton.new()
	lb.button_index = JOY_BUTTON_LEFT_SHOULDER
	lb.pressed = true
	_player._unhandled_input(lb)
	assert_eq(_player.inventory.selected_slot, 0, "LB = espaço anterior")
	var dpad: InputEventJoypadButton = InputEventJoypadButton.new()
	dpad.button_index = JOY_BUTTON_DPAD_RIGHT
	dpad.pressed = true
	_player._unhandled_input(dpad)
	assert_eq(_player.inventory.selected_slot, 1, "→ também")
