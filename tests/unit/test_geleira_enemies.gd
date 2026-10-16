extends GutTest

## #43, #57: Inimigos da Geleira Eterna (Lobo do Gelo, Pinguim-Ladrão, Morsa) e itens.

const WOLF_SCENE: PackedScene = preload("res://gameplay/enemies/ice_wolf/ice_wolf.tscn")
const PENGUIN_SCENE: PackedScene = preload("res://gameplay/enemies/penguin/penguin.tscn")
const WALRUS_SCENE: PackedScene = preload("res://gameplay/enemies/walrus/walrus.tscn")

const IceWolfScript := preload("res://gameplay/enemies/ice_wolf/ice_wolf.gd")
const PenguinScript := preload("res://gameplay/enemies/penguin/penguin.gd")
const WalrusScript := preload("res://gameplay/enemies/walrus/walrus.gd")

var world: Node3D


class GeleiraDummyPlayer extends Node3D:
	var damage_taken: float = 0.0
	var last_knockback: Vector3 = Vector3.ZERO
	var held_loot: CarriedItem = null

	func _ready() -> void:
		add_to_group("player")

	func take_damage(amount: float) -> void:
		damage_taken += amount

	func apply_knockback(impulse: Vector3, _shake: float = 0.0) -> void:
		last_knockback = impulse

	func steal_loot() -> CarriedItem:
		var stolen: CarriedItem = held_loot
		held_loot = null
		return stolen


func before_each() -> void:
	world = Node3D.new()
	add_child_autofree(world)


func test_spawner_kinds_registered() -> void:
	for kind: StringName in [&"ice_wolf", &"penguin", &"walrus", &"frozen_mammoth", &"ancient_walrus", &"cave_yeti"]:
		assert_true(EnemySpawner.KIND_SCENES.has(kind), "EnemySpawner deve registar %s" % String(kind))
		assert_true(ResourceLoader.exists(EnemySpawner.KIND_SCENES[kind]), "Cena de %s deve existir" % String(kind))


func test_catalog_items_exist() -> void:
	var items: Array[String] = [
		"bussola_antiga",
		"dente_mamute",
		"machado_viking",
		"fossil_gelo",
		"cenoura_ouro"
	]
	for item_id: String in items:
		var path: String = "res://items/catalog/%s.tres" % item_id
		assert_true(ResourceLoader.exists(path), "Item %s deve existir no catalogo" % path)
		var item: ItemData = load(path) as ItemData
		assert_not_null(item, "Item %s deve carregar como ItemData" % item_id)
		assert_eq(item.id, item_id, "Item id deve bater certo")


func test_ice_wolf_leap_and_damage() -> void:
	var wolf: Node3D = WOLF_SCENE.instantiate()
	world.add_child(wolf)
	wolf.global_position = Vector3(0.0, 0.0, 0.0)

	var dummy: GeleiraDummyPlayer = GeleiraDummyPlayer.new()
	world.add_child(dummy)
	dummy.global_position = Vector3(0.0, 0.0, -1.0)

	assert_true(wolf.is_in_group(EnemyBase.GROUP), "Lobo do gelo deve estar no grupo enemies")
	assert_eq(wolf.collision_layer, 8, "Lobo do gelo na camada 4 (8)")

	wolf.take_damage(15.0)
	assert_almost_eq(wolf.health, 50.0, 0.01, "Lobo deve receber 15 de dano")

	# Testa o salto com investida
	wolf.set("net_leap_dir", Vector3.FORWARD)
	wolf.call(&"_enter_state", IceWolfScript.State.LEAP)
	assert_eq(wolf.get("state"), IceWolfScript.State.LEAP)

	# Simula física para acertar no dummy
	wolf.call(&"_process_leap", 0.05)
	assert_gt(dummy.damage_taken, 0.0, "Dummy deve receber dano do salto do lobo")
	assert_gt(dummy.last_knockback.length(), 0.0, "Dummy deve sofrer knockback do salto do lobo")


func test_penguin_slide_and_steal_loot() -> void:
	var penguin: Node3D = PENGUIN_SCENE.instantiate()
	world.add_child(penguin)
	penguin.global_position = Vector3(0.0, 0.0, 0.0)

	var dummy: GeleiraDummyPlayer = GeleiraDummyPlayer.new()
	world.add_child(dummy)
	dummy.global_position = Vector3(0.0, 0.0, -0.8)

	var carrot: ItemData = load("res://items/catalog/cenoura_ouro.tres") as ItemData
	var carried: CarriedItem = CarriedItem.create(carrot, carrot.base_value, 1.0, false)
	dummy.held_loot = carried

	penguin.call(&"_enter_state", PenguinScript.State.SLIDE)
	assert_eq(penguin.get("state"), PenguinScript.State.SLIDE)

	# Bumping the dummy
	penguin.call(&"_bump_player", dummy)
	assert_gt(dummy.damage_taken, 0.0, "Dummy deve receber dano da trombada do pinguim")
	assert_gt(dummy.last_knockback.length(), 0.0, "Dummy deve voar com solavanco How to Fish")
	assert_not_null(penguin.get("held_loot"), "Pinguim deve ter roubado o saque da vitima")
	assert_null(dummy.held_loot, "Dummy deve ter ficado sem o saque")
	assert_eq(penguin.get("state"), PenguinScript.State.FLEE, "Pinguim foge apos roubar o saque")


func test_walrus_blubber_armor_and_slam() -> void:
	var walrus: Node3D = WALRUS_SCENE.instantiate()
	world.add_child(walrus)
	walrus.global_position = Vector3(0.0, 0.0, 0.0)

	var dummy: GeleiraDummyPlayer = GeleiraDummyPlayer.new()
	world.add_child(dummy)
	dummy.global_position = Vector3(0.0, 0.0, -1.5)

	# Dano com gordura amortecedora (55%)
	walrus.take_damage(20.0)
	assert_almost_eq(walrus.health, 110.0 - (20.0 * 0.55), 0.01, "Gordura deve reduzir dano para 55%%")

	# Quando atordoado ou em recuperação, armadura fica aberta
	walrus.stun(1.0)
	assert_true(walrus.call(&"is_armor_open"), "Guarda aberta enquanto atordoado")
	var hp_before: float = walrus.health
	walrus.take_damage(20.0)
	assert_almost_eq(walrus.health, hp_before - 20.0, 0.01, "Dano total de 20 enquanto atordoado")

	# Barrigada no gelo
	walrus.call(&"_enter_state", WalrusScript.State.SLAM)
	walrus.call(&"_execute_slam")
	assert_gt(dummy.damage_taken, 0.0, "Dummy deve receber dano da barrigada")
	assert_gt(dummy.last_knockback.y, 8.0, "Barrigada da morsa deve lancar dummy bem alto no ar")
