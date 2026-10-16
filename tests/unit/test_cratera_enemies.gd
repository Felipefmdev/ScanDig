extends GutTest

## #44, #57: Inimigos da Cratera (Criatura Rastejante, Criatura Flutuante) e itens do catálogo.

const CRAWLER_SCENE: PackedScene = preload("res://gameplay/enemies/crawler/crawler.tscn")
const FLOATER_SCENE: PackedScene = preload("res://gameplay/enemies/floater/floater.tscn")

const CrawlerScript := preload("res://gameplay/enemies/crawler/crawler.gd")
const FloaterScript := preload("res://gameplay/enemies/floater/floater.gd")

var world: Node3D


class CrateraDummyPlayer extends Node3D:
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
	world = Node3D.new()
	add_child_autofree(world)


func test_spawner_kinds_registered() -> void:
	for kind: StringName in [&"crawler", &"floater", &"the_sleeper", &"the_echo"]:
		assert_true(EnemySpawner.KIND_SCENES.has(kind), "EnemySpawner deve registar %s" % String(kind))
		assert_true(ResourceLoader.exists(EnemySpawner.KIND_SCENES[kind]), "Cena de %s deve existir" % String(kind))


func test_catalog_items_exist() -> void:
	var items: Array[String] = [
		"cristal_eco",
		"nucleo_adormecido",
		"geodo_estrelar"
	]
	for item_id: String in items:
		var path: String = "res://items/catalog/%s.tres" % item_id
		assert_true(ResourceLoader.exists(path), "Item %s deve existir no catalogo" % path)
		var item: ItemData = load(path) as ItemData
		assert_not_null(item, "Item %s deve carregar como ItemData" % item_id)
		assert_eq(item.id, item_id, "Item id deve bater certo")


func test_crawler_leap_and_damage() -> void:
	var crawler: Node3D = CRAWLER_SCENE.instantiate()
	world.add_child(crawler)
	crawler.global_position = Vector3(0.0, 0.0, 0.0)

	var dummy: CrateraDummyPlayer = CrateraDummyPlayer.new()
	world.add_child(dummy)
	dummy.global_position = Vector3(0.0, 0.0, -1.0)

	assert_true(crawler.is_in_group(EnemyBase.GROUP), "Crawler deve estar no grupo enemies")
	assert_eq(crawler.get("collision_layer"), 8, "Crawler na camada 4 (8)")

	crawler.take_damage(15.0)
	assert_almost_eq(crawler.get("health"), 45.0, 0.01, "Crawler deve receber 15 de dano (60 - 15 = 45)")

	# Testa o salto como mola (spring jump)
	crawler.set("net_spring_dir", Vector3.FORWARD)
	crawler.call(&"_enter_state", CrawlerScript.State.SPRING_JUMP)
	assert_eq(crawler.get("state"), CrawlerScript.State.SPRING_JUMP)

	# Simula física para acertar no dummy
	crawler.call(&"_process_spring_jump", 0.05)
	assert_gt(dummy.damage_taken, 0.0, "Dummy deve receber dano do salto da criatura rastejante")
	assert_gt(dummy.last_knockback.length(), 0.0, "Dummy deve sofrer knockback do salto")


func test_floater_pulse_and_gravity() -> void:
	var floater: Node3D = FLOATER_SCENE.instantiate()
	world.add_child(floater)
	floater.global_position = Vector3(0.0, 0.0, 0.0)

	var dummy: CrateraDummyPlayer = CrateraDummyPlayer.new()
	world.add_child(dummy)
	dummy.global_position = Vector3(0.0, 0.0, -1.2)

	assert_true(floater.is_in_group(EnemyBase.GROUP), "Floater deve estar no grupo enemies")
	assert_eq(floater.get("collision_layer"), 8, "Floater na camada 4 (8)")

	floater.take_damage(20.0)
	assert_almost_eq(floater.get("health"), 50.0, 0.01, "Floater deve receber 20 de dano (70 - 20 = 50)")

	# Dispara pulso de gravidade
	floater.call(&"_enter_state", FloaterScript.State.PULSE)
	assert_eq(floater.get("state"), FloaterScript.State.PULSE)
	floater.call(&"_execute_pulse")

	assert_gt(dummy.damage_taken, 0.0, "Dummy deve receber dano do pulso de gravidade")
	assert_gt(dummy.last_knockback.y, 7.0, "Pulso gravitacional deve lancar dummy bem alto no ar")
