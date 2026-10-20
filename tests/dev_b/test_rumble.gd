extends GutTest

## Vibração do comando (#148): o helper recebe os eventos com a força escalada pela opção,
## 0 % e sem comando não vibram, o detector respeita o limite de frequência e só vibra o do
## jogador local, a explosão cai com a distância e com "reduzir flashes". Sem comando físico:
## Rumble.backend grava as chamadas no lugar do Input.start_joy_vibration.

const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/player.tscn")

var _calls: Array[Dictionary] = []


func before_each() -> void:
	_calls.clear()
	Rumble.reset()
	Rumble.backend = func(device: int, weak: float, strong: float, seconds: float) -> void:
		_calls.append({"device": device, "weak": weak, "strong": strong, "seconds": seconds})
	_set_vibration(1.0)
	_use_pad(true)


func after_each() -> void:
	Rumble.backend = Callable()
	Rumble.reset()
	var sm: SettingsManager = SettingsManager.instance
	sm.set_section(SettingsManager.GAMEPLAY, {"pad_vibration": 1.0}, false)
	sm.set_section(SettingsManager.ACCESSIBILITY, {"reduce_flashes": false}, false)
	_use_pad(false)


func _set_vibration(value: float) -> void:
	SettingsManager.instance.set_section(SettingsManager.GAMEPLAY, {"pad_vibration": value}, false)


func _use_pad(on: bool) -> void:
	if on:
		var ev: InputEventJoypadButton = InputEventJoypadButton.new()
		ev.device = 0
		ev.button_index = JOY_BUTTON_A
		ev.pressed = true
		InputDevice.instance.observe(ev)
	else:
		InputDevice.instance.set_using_gamepad(false)


func test_settings_default_and_clamp() -> void:
	assert_eq(SettingsManager.sanitize(SettingsManager.GAMEPLAY, {})["pad_vibration"], 1.0)
	assert_eq(SettingsManager.sanitize(SettingsManager.GAMEPLAY, {"pad_vibration": 7})["pad_vibration"], 1.0)
	assert_eq(SettingsManager.sanitize(SettingsManager.GAMEPLAY, {"pad_vibration": -1.0})["pad_vibration"], 0.0)
	assert_eq(SettingsManager.sanitize(SettingsManager.GAMEPLAY, {"pad_vibration": "x"})["pad_vibration"], 1.0)


func test_pad_device_comes_from_last_pad_event() -> void:
	var ev: InputEventJoypadMotion = InputEventJoypadMotion.new()
	ev.device = 2
	ev.axis = JOY_AXIS_LEFT_X
	ev.axis_value = 0.9
	InputDevice.instance.observe(ev)
	assert_eq(InputDevice.pad_device(), 2)
	assert_true(Rumble.on_dig_found(false, 1000))
	assert_eq(int(_calls[0]["device"]), 2, "vibra no comando que mexeu por último")
	_use_pad(true)


func test_damage_is_proportional_and_scaled() -> void:
	assert_true(Rumble.on_damage(10.0, 100.0, 1000))
	var small: float = _calls[0]["strong"]
	Rumble.reset()
	assert_true(Rumble.on_damage(40.0, 100.0, 1000))
	assert_almost_eq(float(_calls[1]["strong"]), 1.0, 0.001, "40 % da vida = cheia")
	assert_gt(float(_calls[1]["strong"]), small, "dano maior vibra mais")
	Rumble.reset()
	_set_vibration(0.5)
	assert_true(Rumble.on_damage(40.0, 100.0, 1000))
	assert_almost_eq(float(_calls[2]["strong"]), 0.5, 0.001, "opção em 50 % corta pela metade")
	assert_almost_eq(float(_calls[2]["weak"]), 0.3, 0.001)


func test_zero_percent_never_vibrates() -> void:
	_set_vibration(0.0)
	assert_false(Rumble.on_damage(50.0, 100.0, 1000))
	assert_false(Rumble.on_explosion(1.0, 1000))
	assert_false(Rumble.on_dig_found(true, 1000))
	assert_false(Rumble.on_detector_ping(1.0, null, 1000))
	assert_false(Rumble.on_boss_entry(1000))
	assert_false(Rumble.on_heavy_hit(0.3, 1000))
	assert_eq(_calls.size(), 0)


func test_keyboard_never_vibrates() -> void:
	_use_pad(false)
	assert_false(Rumble.on_damage(50.0, 100.0, 1000))
	assert_false(Rumble.on_boss_entry(1000))
	assert_false(Rumble.preview(1.0, 1000))
	assert_eq(_calls.size(), 0, "sem o comando em uso, nada")


func test_explosion_falls_with_distance_and_reduced_flashes() -> void:
	assert_true(Rumble.on_explosion(1.0, 1000))
	Rumble.reset()
	assert_true(Rumble.on_explosion(12.0, 1000))
	assert_gt(float(_calls[0]["strong"]), float(_calls[1]["strong"]), "perto vibra mais")
	Rumble.reset()
	assert_false(Rumble.on_explosion(Rumble.EXPLOSION_RANGE + 1.0, 1000), "longe não vibra")
	SettingsManager.instance.set_section(SettingsManager.ACCESSIBILITY, {"reduce_flashes": true}, false)
	assert_true(Rumble.on_explosion(1.0, 1000))
	assert_almost_eq(float(_calls[2]["strong"]), float(_calls[0]["strong"]) * A11y.REDUCED_FLASH, 0.001, "reduzir flashes corta a explosão")


func test_screen_shake_does_not_change_vibration() -> void:
	SettingsManager.instance.set_section(SettingsManager.ACCESSIBILITY, {"screen_shake": 0.0}, false)
	assert_true(Rumble.on_damage(40.0, 100.0, 1000))
	assert_almost_eq(float(_calls[0]["strong"]), 1.0, 0.001)
	SettingsManager.instance.set_section(SettingsManager.ACCESSIBILITY, {"screen_shake": 1.0}, false)


func test_detector_rate_limit_and_threshold() -> void:
	assert_false(Rumble.on_detector_ping(0.3, null, 1000), "sinal fraco não vibra")
	assert_true(Rumble.on_detector_ping(0.9, null, 1000))
	assert_false(Rumble.on_detector_ping(1.0, null, 1000 + Rumble.DETECTOR_INTERVAL_MS - 100), "dentro do intervalo")
	assert_true(Rumble.on_detector_ping(1.0, null, 1000 + Rumble.DETECTOR_INTERVAL_MS + 10))
	assert_eq(_calls.size(), 2)
	for call: Dictionary in _calls:
		assert_lte(float(call["weak"]), Rumble.DETECTOR_WEAK.y, "pulso suave")
		assert_eq(float(call["strong"]), 0.0)


func test_detector_of_remote_player_does_not_vibrate() -> void:
	var remote: Player = PLAYER_SCENE.instantiate() as Player
	var coil: Node = Node.new()
	remote.add_child(coil)
	assert_false(Rumble.on_detector_ping(1.0, coil, 1000), "detector de outro jogador")
	remote.free()


func test_weaker_does_not_cut_stronger() -> void:
	assert_true(Rumble.on_boss_entry(1000))
	assert_false(Rumble.on_dig_found(false, 1100), "a do chefe ainda está vibrando")
	assert_true(Rumble.on_dig_found(false, 1000 + 700), "depois que acabou, vibra")


func test_heavy_hit_scales_with_shake() -> void:
	assert_false(Rumble.on_heavy_hit(0.0, 1000))
	assert_true(Rumble.on_heavy_hit(0.05, 1000))
	Rumble.reset()
	assert_true(Rumble.on_heavy_hit(0.3, 1000))
	assert_gt(float(_calls[1]["strong"]), float(_calls[0]["strong"]))


func test_player_damage_reaches_helper() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(player)
	_use_pad(true)
	player.take_damage(20.0)
	assert_eq(_calls.size(), 1, "dano no jogador local vibra")
	Rumble.reset()
	player.apply_knockback(Vector3.UP, 0.2)
	assert_eq(_calls.size(), 2, "golpe forte vibra")


func test_controls_tab_slider_saves_setting() -> void:
	var menu: SettingsMenu = SettingsMenu.new()
	add_child_autofree(menu)
	assert_eq(menu.vibration_slider.value, 100.0)
	menu.vibration_slider.value = 0.0
	assert_eq(menu.vibration_value.text, "Desligada")
	assert_true(menu.has_pending_changes())
	menu._on_apply_pressed()
	assert_eq(Rumble.setting(), 0.0)
	assert_false(Rumble.on_damage(50.0, 100.0, 1000))
	menu.tabs.current_tab = SettingsMenu.TAB_CONTROLS
	menu._on_defaults_pressed()
	assert_eq(Rumble.setting(), 1.0, "Restaurar padrão da aba Controles volta a vibração")
	assert_eq(menu.vibration_slider.value, 100.0)
