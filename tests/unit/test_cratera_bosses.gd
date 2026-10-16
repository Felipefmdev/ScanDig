extends GutTest

## #44, #57: Testes dos Chefes da Cratera:
##   - O Que Dorme Lá Em Baixo (chefe principal final)
##   - O Eco (chefe escondido)

const THE_SLEEPER_SCENE: PackedScene = preload("res://gameplay/enemies/boss/the_sleeper.tscn")
const THE_ECHO_SCENE: PackedScene = preload("res://gameplay/enemies/boss/the_echo.tscn")

const TheSleeperScript := preload("res://gameplay/enemies/boss/the_sleeper.gd")
const TheEchoScript := preload("res://gameplay/enemies/boss/the_echo.gd")

var arena: Node3D


class BossDummyPlayer extends Node3D:
	var damage_taken: float = 0.0
	var last_knockback: Vector3 = Vector3.ZERO

	func _ready() -> void:
		add_to_group("player")
		add_to_group("players")

	func take_damage(amount: float) -> void:
		damage_taken += amount

	func apply_knockback(impulse: Vector3, _shake: float = 0.0) -> void:
		last_knockback = impulse


func before_each() -> void:
	QuestRewards.reset_session()
	arena = Node3D.new()
	add_child_autofree(arena)


# ---------------------------------------------------------------------------
# Testes do "O Que Dorme Lá Em Baixo" (The Sleeper)
# ---------------------------------------------------------------------------

func test_the_sleeper_setup_and_stats() -> void:
	var sleeper: Node3D = THE_SLEEPER_SCENE.instantiate()
	arena.add_child(sleeper)
	sleeper.call(&"wake_immediately")

	assert_eq(sleeper.get("max_health"), 1600.0)
	assert_eq(sleeper.get("health"), 1600.0)
	assert_true(sleeper.is_in_group(&"bosses"))
	assert_true(sleeper.is_in_group(&"enemies"))
	assert_eq(TheSleeperScript.BOSS_ID, &"the_sleeper")
	assert_eq(TheSleeperScript.TROPHY_ITEM_ID, "nucleo_adormecido")
	assert_eq(TheSleeperScript.SECONDARY_TROPHY_ID, "orbe_vibrante")
	assert_eq(sleeper.get("collision_layer"), 8)


func test_the_sleeper_exposed_weak_point() -> void:
	var sleeper: Node3D = THE_SLEEPER_SCENE.instantiate()
	arena.add_child(sleeper)
	sleeper.call(&"wake_immediately")

	# Dano normal
	sleeper.take_damage(20.0)
	assert_almost_eq(sleeper.get("health"), 1580.0, 0.01)

	# Fica exposto após grandes ataques
	sleeper.call(&"_enter_state", TheSleeperScript.State.EXPOSED)
	assert_true(sleeper.call(&"is_weak_point_exposed"), "Núcleo de ametista fica exposto")
	sleeper.take_damage(20.0)
	# 20 * 2.5 = 50 dano
	assert_almost_eq(sleeper.get("health"), 1530.0, 0.01, "Ponto fraco recebe 2.5x dano")


func test_the_sleeper_gravity_inversion_and_spikes() -> void:
	var sleeper: Node3D = THE_SLEEPER_SCENE.instantiate()
	arena.add_child(sleeper)
	sleeper.call(&"wake_immediately")

	var dummy: BossDummyPlayer = BossDummyPlayer.new()
	arena.add_child(dummy)
	dummy.global_position = Vector3(0.0, 0.0, -2.0)

	# Inversão de gravidade
	sleeper.call(&"_enter_state", TheSleeperScript.State.GRAVITY_INVERT)
	sleeper.call(&"_execute_gravity_invert")
	assert_gt(dummy.damage_taken, 0.0, "Dummy recebe dano da inversao de gravidade")
	assert_gt(dummy.last_knockback.y, 10.0, "Inversao de gravidade arremessa dummy alto no ar")

	# Reset dummy
	dummy.damage_taken = 0.0
	dummy.last_knockback = Vector3.ZERO

	# Espigões de cristal
	sleeper.set("net_attack_point", dummy.global_position)
	sleeper.call(&"_enter_state", TheSleeperScript.State.CRYSTAL_SPIKES)
	sleeper.call(&"_execute_crystal_spikes")
	assert_gt(dummy.damage_taken, 0.0, "Dummy recebe dano dos espigoes de cristal")
	assert_gt(dummy.last_knockback.length(), 0.0, "Espigoes empurram o dummy")


func test_the_sleeper_defeat_and_trophies() -> void:
	var sleeper: Node3D = THE_SLEEPER_SCENE.instantiate()
	arena.add_child(sleeper)
	sleeper.call(&"wake_immediately")

	watch_signals(sleeper)
	sleeper.take_damage(5000.0)
	assert_true(sleeper.get("health") <= 0.0)
	assert_eq(sleeper.get("state"), TheSleeperScript.State.DYING)

	sleeper.set("_state_time", 1.3)
	sleeper.call(&"_process_dying", 0.05)

	assert_signal_emitted_with_parameters(sleeper, "boss_defeated", [TheSleeperScript.BOSS_ID])
	assert_true(ResourceLoader.exists("res://items/catalog/%s.tres" % TheSleeperScript.TROPHY_ITEM_ID))
	assert_true(ResourceLoader.exists("res://items/catalog/%s.tres" % TheSleeperScript.SECONDARY_TROPHY_ID))


# ---------------------------------------------------------------------------
# Testes do "O Eco" (The Echo)
# ---------------------------------------------------------------------------

func test_the_echo_setup_and_stats() -> void:
	var echo: Node3D = THE_ECHO_SCENE.instantiate()
	arena.add_child(echo)
	echo.call(&"wake_immediately")

	assert_eq(echo.get("max_health"), 1250.0)
	assert_eq(echo.get("health"), 1250.0)
	assert_true(echo.is_in_group(&"bosses"))
	assert_true(echo.is_in_group(&"enemies"))
	assert_eq(TheEchoScript.BOSS_ID, &"the_echo")
	assert_eq(TheEchoScript.TROPHY_ITEM_ID, "cristal_eco")
	assert_eq(echo.get("collision_layer"), 8)


func test_the_echo_sonic_ring_and_knockback() -> void:
	var echo: Node3D = THE_ECHO_SCENE.instantiate()
	arena.add_child(echo)
	echo.call(&"wake_immediately")

	var dummy: BossDummyPlayer = BossDummyPlayer.new()
	arena.add_child(dummy)
	dummy.global_position = Vector3(0.0, 0.0, -1.8)

	echo.call(&"_enter_state", TheEchoScript.State.SONIC_RING)
	echo.call(&"_execute_sonic_rings")
	assert_gt(dummy.damage_taken, 0.0, "Dummy recebe dano da onda sonica")
	assert_gt(dummy.last_knockback.length(), 10.0, "Onda sonica da knockback extremo estilo How to Fish")


func test_the_echo_shattered_dizzy_weak_point() -> void:
	var echo: Node3D = THE_ECHO_SCENE.instantiate()
	arena.add_child(echo)
	echo.call(&"wake_immediately")

	# Dano normal
	echo.take_damage(20.0)
	assert_almost_eq(echo.get("health"), 1230.0, 0.01)

	# Fica desfeito / tonto após ressonância máxima
	echo.call(&"_enter_state", TheEchoScript.State.SHATTERED_DIZZY)
	assert_true(echo.call(&"is_weak_point_exposed"), "Eco desfeito tem ponto fraco exposto")
	echo.take_damage(20.0)
	# 20 * 2.5 = 50 dano
	assert_almost_eq(echo.get("health"), 1180.0, 0.01, "Ponto fraco recebe 2.5x dano")


func test_the_echo_defeat_and_trophy() -> void:
	var echo: Node3D = THE_ECHO_SCENE.instantiate()
	arena.add_child(echo)
	echo.call(&"wake_immediately")

	watch_signals(echo)
	echo.take_damage(5000.0)
	assert_true(echo.get("health") <= 0.0)
	assert_eq(echo.get("state"), TheEchoScript.State.DYING)

	echo.set("_state_time", 1.3)
	echo.call(&"_process_dying", 0.05)

	assert_signal_emitted_with_parameters(echo, "boss_defeated", [TheEchoScript.BOSS_ID])
	assert_true(ResourceLoader.exists("res://items/catalog/%s.tres" % TheEchoScript.TROPHY_ITEM_ID))
