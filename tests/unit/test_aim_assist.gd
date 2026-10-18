extends GutTest

## Testes unitários para a mira assistida no comando (#90, How to Fish PlayerAimAssist).
## Cobre: ativação só com comando e estilingue/arpão, limites de cone (18° aquisição,
## 40° quebra), alcance (60 m), rotação suave até 120°/s em yaw e pitch, respeito à opção
## controller_aim_assist no SettingsManager e ignorar inimigos mortos ou jogador caído.

const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/player.tscn")

var _player: Player = null


func before_each() -> void:
	_player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(_player)
	if InputDevice.instance != null:
		InputDevice.instance.set_using_gamepad(true)
	if SettingsManager.instance != null:
		SettingsManager.instance.set_section(SettingsManager.GAMEPLAY, {"controller_aim_assist": true}, false)
	_player.invert_y = false
	_player.rotation = Vector3.ZERO
	if _player.head != null:
		_player.head.rotation = Vector3.ZERO


func after_each() -> void:
	if InputDevice.instance != null:
		InputDevice.instance.set_using_gamepad(false)
	if SettingsManager.instance != null:
		SettingsManager.instance.set_section(SettingsManager.GAMEPLAY, {"controller_aim_assist": true}, false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


class MockEnemy extends Node3D:
	var health: float = 50.0

	func is_alive() -> bool:
		return health > 0.0


func _equip_slingshot() -> void:
	var sl: CarriedItem = CarriedItem.create_tool(&"estilingue", "Estilingue")
	_player.inventory.add_item(sl)
	var idx: int = _player.inventory.slots.find(sl)
	_player.inventory.select(idx)


func _equip_harpoon() -> void:
	var hp: CarriedItem = CarriedItem.create_tool(&"arpao_corda", "Arpão de Corda")
	_player.inventory.add_item(hp)
	var idx: int = _player.inventory.slots.find(hp)
	_player.inventory.select(idx)


func _spawn_enemy(pos: Vector3, health_val: float = 50.0) -> Node3D:
	var enemy: MockEnemy = MockEnemy.new()
	enemy.name = "TestEnemy"
	enemy.add_to_group("enemies")
	enemy.health = health_val
	add_child_autofree(enemy)
	enemy.global_position = pos
	return enemy


func test_constants_match_how_to_fish_spec() -> void:
	assert_almost_eq(Player.AIM_ASSIST_RANGE, 60.0, 0.001, "Alcance máximo 60m")
	assert_almost_eq(Player.AIM_ASSIST_ACQUIRE_RAD, deg_to_rad(18.0), 0.001, "Cone de aquisição 18°")
	assert_almost_eq(Player.AIM_ASSIST_BREAK_RAD, deg_to_rad(40.0), 0.001, "Cone de quebra de mira 40°")
	assert_almost_eq(Player.AIM_ASSIST_MAX_SPEED_RAD, deg_to_rad(120.0), 0.001, "Velocidade máxima de rotação 120°/s")
	assert_almost_eq(Player.AIM_ASSIST_SHARPNESS, 10.0, 0.001, "Nitidez 10")
	assert_almost_eq(Player.AIM_ASSIST_SCAN_INTERVAL, 0.1, 0.001, "Intervalo de varredura 0,1s")


func test_inactive_with_mouse_and_keyboard() -> void:
	_equip_slingshot()
	assert_true(_player.is_aim_assist_active(), "Ativo com comando")
	InputDevice.instance.set_using_gamepad(false)
	assert_false(_player.is_aim_assist_active(), "Inativo com teclado/mouse")


func test_inactive_when_disabled_in_settings() -> void:
	_equip_slingshot()
	assert_true(_player.is_aim_assist_active())
	SettingsManager.instance.set_section(SettingsManager.GAMEPLAY, {"controller_aim_assist": false}, false)
	assert_false(_player.is_aim_assist_active(), "Inativo quando desligado nas configurações")


func test_active_only_for_slingshot_and_harpoon() -> void:
	# Mãos vazias
	assert_false(_player.is_aim_assist_active())

	# Pá / Forcado / Detetor
	_player.inventory.take_all()
	var shovel: CarriedItem = CarriedItem.create_tool(&"pa", "Pá")
	_player.inventory.add_item(shovel)
	_player.inventory.select(0)
	assert_false(_player.is_aim_assist_active(), "Pá não tem mira assistida")

	_player.inventory.take_all()
	var detector: CarriedItem = CarriedItem.create_tool(&"detector", "Detector")
	_player.inventory.add_item(detector)
	_player.inventory.select(0)
	assert_false(_player.is_aim_assist_active(), "Detector não tem mira assistida")

	# Estilingue
	_player.inventory.take_all()
	_equip_slingshot()
	assert_true(_player.is_aim_assist_active(), "Estilingue tem mira assistida")

	# Arpão
	_player.inventory.take_all()
	_equip_harpoon()
	assert_true(_player.is_aim_assist_active(), "Arpão tem mira assistida")


func test_acquires_enemy_within_18_deg_and_60m() -> void:
	_equip_slingshot()
	var enemy: Node3D = _spawn_enemy(Vector3(0.0, 0.0, -15.0))
	_player.update_aim_assist(0.1)
	assert_eq(_player.get_aim_assist_target(), enemy, "Inimigo frontal a 15m é adquirido")


func test_ignores_enemy_outside_18_deg() -> void:
	_equip_slingshot()
	# Inimigo a 25° (> 18°)
	var angle: float = deg_to_rad(25.0)
	var pos: Vector3 = Vector3(sin(angle) * 15.0, 0.0, -cos(angle) * 15.0)
	_spawn_enemy(pos)
	_player.update_aim_assist(0.1)
	assert_null(_player.get_aim_assist_target(), "Inimigo fora do cone de 18° é ignorado")


func test_ignores_enemy_beyond_60m() -> void:
	_equip_slingshot()
	_spawn_enemy(Vector3(0.0, 0.0, -65.0))
	_player.update_aim_assist(0.1)
	assert_null(_player.get_aim_assist_target(), "Inimigo além de 60m é ignorado")


func test_breaks_tracking_beyond_40_deg() -> void:
	_equip_slingshot()
	# Adquire a 10°
	var angle: float = deg_to_rad(10.0)
	var enemy: Node3D = _spawn_enemy(Vector3(sin(angle) * 10.0, 0.0, -cos(angle) * 10.0))
	_player.update_aim_assist(0.1)
	assert_eq(_player.get_aim_assist_target(), enemy)

	# Vira o jogador 50° para o lado oposto -> ângulo relativo passa de 40°
	_player.rotate_y(deg_to_rad(50.0))
	_player.update_aim_assist(0.05)
	assert_null(_player.get_aim_assist_target(), "Alvo é perdido ao passar de 40°")


func test_nudges_yaw_and_pitch_toward_enemy() -> void:
	_equip_slingshot()
	# Inimigo à direita e acima (X=2, Y=2, Z=-10; ~11.3° cone < 18°)
	_spawn_enemy(Vector3(2.0, 2.0, -10.0))
	_player.rotation.y = 0.0
	_player.head.rotation.x = 0.0

	_player.update_aim_assist(0.1)

	assert_lt(_player.rotation.y, 0.0, "Gira para a direita em direção ao alvo")
	assert_gt(_player.head.rotation.x, 0.0, "Inclina a cabeça para cima em direção ao alvo")


func test_ignores_dead_enemy() -> void:
	_equip_slingshot()
	_spawn_enemy(Vector3(0.0, 0.0, -10.0), 0.0) # Vida zerada
	_player.update_aim_assist(0.1)
	assert_null(_player.get_aim_assist_target(), "Inimigo morto com vida <= 0 não é mirado")


func test_inactive_when_downed() -> void:
	_equip_slingshot()
	_player.is_downed = true
	assert_false(_player.is_aim_assist_active(), "Mira assistida inativa para jogador caído")
