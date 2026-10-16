extends GutTest

## #43, #57: Testes dos 3 Chefes da Geleira Eterna:
##   - Mamute Congelado (chefe principal)
##   - Morsa Anciã (chefe de missão)
##   - Yeti da Gruta (chefe escondido)

const MAMMOTH_SCENE: PackedScene = preload("res://gameplay/enemies/boss/frozen_mammoth.tscn")
const ANCIENT_WALRUS_SCENE: PackedScene = preload("res://gameplay/enemies/boss/ancient_walrus.tscn")
const YETI_SCENE: PackedScene = preload("res://gameplay/enemies/boss/cave_yeti.tscn")

const MammothScript := preload("res://gameplay/enemies/boss/frozen_mammoth.gd")
const AncientWalrusScript := preload("res://gameplay/enemies/boss/ancient_walrus.gd")
const YetiScript := preload("res://gameplay/enemies/boss/cave_yeti.gd")

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
# Testes do Mamute Congelado
# ---------------------------------------------------------------------------

func test_frozen_mammoth_setup_and_stats() -> void:
	var mammoth: Node3D = MAMMOTH_SCENE.instantiate()
	arena.add_child(mammoth)
	mammoth.call(&"wake_immediately")

	assert_eq(mammoth.get("max_health"), 1350.0)
	assert_eq(mammoth.get("health"), 1350.0)
	assert_true(mammoth.is_in_group(&"bosses"))
	assert_true(mammoth.is_in_group(&"enemies"))
	assert_eq(MammothScript.BOSS_ID, &"frozen_mammoth")
	assert_eq(MammothScript.TROPHY_ITEM_ID, "dente_mamute")
	assert_eq(mammoth.get("collision_layer"), 8)


func test_frozen_mammoth_charge_stuck_weak_point() -> void:
	var mammoth: Node3D = MAMMOTH_SCENE.instantiate()
	arena.add_child(mammoth)
	mammoth.call(&"wake_immediately")

	var dummy: BossDummyPlayer = BossDummyPlayer.new()
	arena.add_child(dummy)
	dummy.global_position = Vector3(0.0, 0.0, -1.5)

	# Dano normal
	mammoth.take_damage(20.0)
	assert_almost_eq(mammoth.get("health"), 1330.0, 0.01)

	# Fica preso após investida
	mammoth.call(&"_enter_state", MammothScript.State.STUCK)
	assert_true(mammoth.call(&"is_weak_point_exposed"), "Mamute preso no gelo tem ponto fraco exposto")
	mammoth.take_damage(20.0)
	# 20 * 2.5 = 50 dano
	assert_almost_eq(mammoth.get("health"), 1280.0, 0.01, "Ponto fraco recebe 2.5x dano")


func test_frozen_mammoth_stomp_avalanche() -> void:
	var mammoth: Node3D = MAMMOTH_SCENE.instantiate()
	arena.add_child(mammoth)
	mammoth.call(&"wake_immediately")

	var dummy: BossDummyPlayer = BossDummyPlayer.new()
	arena.add_child(dummy)
	dummy.global_position = Vector3(0.0, 0.0, -2.0)

	mammoth.call(&"_enter_state", MammothScript.State.STOMP)
	mammoth.call(&"_execute_stomp_and_avalanche")
	assert_gt(dummy.damage_taken, 0.0, "Dummy recebe dano do pisao")
	assert_gt(dummy.last_knockback.y, 6.0, "Pisao lanca dummy pelos ares")


func test_frozen_mammoth_defeat_and_trophy() -> void:
	var mammoth: Node3D = MAMMOTH_SCENE.instantiate()
	arena.add_child(mammoth)
	mammoth.call(&"wake_immediately")

	watch_signals(mammoth)
	mammoth.take_damage(5000.0)
	assert_true(mammoth.get("health") <= 0.0)
	assert_eq(mammoth.get("state"), MammothScript.State.DYING)

	mammoth.set("_state_time", 1.3)
	mammoth.call(&"_process_dying", 0.05)

	assert_signal_emitted_with_parameters(mammoth, "boss_defeated", [MammothScript.BOSS_ID])
	assert_true(ResourceLoader.exists("res://items/catalog/%s.tres" % MammothScript.TROPHY_ITEM_ID))


# ---------------------------------------------------------------------------
# Testes da Morsa Anciã
# ---------------------------------------------------------------------------

func test_ancient_walrus_setup_and_stats() -> void:
	var walrus: Node3D = ANCIENT_WALRUS_SCENE.instantiate()
	arena.add_child(walrus)
	walrus.call(&"wake_immediately")

	assert_eq(walrus.get("max_health"), 1150.0)
	assert_eq(walrus.get("health"), 1150.0)
	assert_true(walrus.is_in_group(&"bosses"))
	assert_true(walrus.is_in_group(&"enemies"))
	assert_eq(AncientWalrusScript.BOSS_ID, &"ancient_walrus")
	assert_eq(AncientWalrusScript.TROPHY_ITEM_ID, "bussola_antiga")
	assert_eq(walrus.get("collision_layer"), 8)


func test_ancient_walrus_slide_and_crush() -> void:
	var walrus: Node3D = ANCIENT_WALRUS_SCENE.instantiate()
	arena.add_child(walrus)
	walrus.call(&"wake_immediately")

	var dummy: BossDummyPlayer = BossDummyPlayer.new()
	arena.add_child(dummy)
	dummy.global_position = Vector3(0.0, 0.0, -1.8)

	walrus.call(&"_enter_state", AncientWalrusScript.State.CRUSH)
	walrus.call(&"_execute_crush")
	assert_gt(dummy.damage_taken, 0.0, "Dummy recebe dano do esmagar")
	assert_gt(dummy.last_knockback.y, 8.0, "Esmagar da morsa arremessa dummy")

	# Estado de recuperação
	walrus.call(&"_enter_state", AncientWalrusScript.State.RECOVER)
	assert_true(walrus.call(&"is_exhausted"), "Morsa exausta em RECOVER")
	var hp_before: float = walrus.get("health")
	walrus.take_damage(20.0)
	assert_almost_eq(walrus.get("health"), hp_before - (20.0 * 1.8), 0.01, "Exausta recebe 1.8x dano")


func test_ancient_walrus_defeat_and_trophies() -> void:
	var walrus: Node3D = ANCIENT_WALRUS_SCENE.instantiate()
	arena.add_child(walrus)
	walrus.call(&"wake_immediately")

	watch_signals(walrus)
	walrus.take_damage(5000.0)
	assert_true(walrus.get("health") <= 0.0)
	assert_eq(walrus.get("state"), AncientWalrusScript.State.DYING)

	walrus.set("_state_time", 1.3)
	walrus.call(&"_process_dying", 0.05)

	assert_signal_emitted_with_parameters(walrus, "boss_defeated", [AncientWalrusScript.BOSS_ID])
	assert_true(ResourceLoader.exists("res://items/catalog/%s.tres" % AncientWalrusScript.TROPHY_ITEM_ID))
	assert_true(ResourceLoader.exists("res://items/catalog/%s.tres" % AncientWalrusScript.SECONDARY_TROPHY_ID))


# ---------------------------------------------------------------------------
# Testes do Yeti da Gruta
# ---------------------------------------------------------------------------

func test_cave_yeti_setup_and_stats() -> void:
	var yeti: Node3D = YETI_SCENE.instantiate()
	arena.add_child(yeti)
	yeti.call(&"wake_immediately")

	assert_eq(yeti.get("max_health"), 1200.0)
	assert_eq(yeti.get("health"), 1200.0)
	assert_true(yeti.is_in_group(&"bosses"))
	assert_true(yeti.is_in_group(&"enemies"))
	assert_eq(YetiScript.BOSS_ID, &"cave_yeti")
	assert_eq(YetiScript.TROPHY_ITEM_ID, "fossil_gelo")
	assert_eq(yeti.get("collision_layer"), 8)


func test_cave_yeti_helicopter_and_dizzy() -> void:
	var yeti: Node3D = YETI_SCENE.instantiate()
	arena.add_child(yeti)
	yeti.call(&"wake_immediately")

	var dummy: BossDummyPlayer = BossDummyPlayer.new()
	arena.add_child(dummy)
	dummy.global_position = Vector3(0.0, 0.0, -1.2)

	# Fica tonto após o giro de helicóptero
	yeti.call(&"_enter_state", YetiScript.State.DIZZY)
	assert_true(yeti.call(&"is_weak_point_exposed"), "Yeti tonto tem ponto fraco exposto")
	yeti.take_damage(20.0)
	# 20 * 2.5 = 50 dano
	assert_almost_eq(yeti.get("health"), 1200.0 - 50.0, 0.01, "Yeti tonto recebe 2.5x dano")


func test_cave_yeti_belly_jump() -> void:
	var yeti: Node3D = YETI_SCENE.instantiate()
	arena.add_child(yeti)
	yeti.call(&"wake_immediately")

	var dummy: BossDummyPlayer = BossDummyPlayer.new()
	arena.add_child(dummy)
	dummy.global_position = Vector3(0.0, 0.0, -1.5)

	yeti.set("net_attack_point", yeti.global_position)
	yeti.call(&"_enter_state", YetiScript.State.BELLY_JUMP)
	assert_eq(yeti.get("state"), YetiScript.State.BELLY_JUMP)


func test_cave_yeti_defeat_and_trophy() -> void:
	var yeti: Node3D = YETI_SCENE.instantiate()
	arena.add_child(yeti)
	yeti.call(&"wake_immediately")

	watch_signals(yeti)
	yeti.take_damage(5000.0)
	assert_true(yeti.get("health") <= 0.0)
	assert_eq(yeti.get("state"), YetiScript.State.DYING)

	yeti.set("_state_time", 1.3)
	yeti.call(&"_process_dying", 0.05)

	assert_signal_emitted_with_parameters(yeti, "boss_defeated", [YetiScript.BOSS_ID])
	assert_true(ResourceLoader.exists("res://items/catalog/%s.tres" % YetiScript.TROPHY_ITEM_ID))
