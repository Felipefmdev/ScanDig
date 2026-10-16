extends GutTest

const CRAWLER_SCENE: PackedScene = preload("res://gameplay/enemies/crawler/crawler.tscn")
const CrawlerScript := preload("res://gameplay/enemies/crawler/crawler.gd")
const ICE_WOLF_SCENE: PackedScene = preload("res://gameplay/enemies/ice_wolf/ice_wolf.tscn")
const IceWolfScript := preload("res://gameplay/enemies/ice_wolf/ice_wolf.gd")
const STONE_GUARDIAN_SCENE: PackedScene = preload("res://gameplay/enemies/stone_guardian/stone_guardian.tscn")
const StoneGuardianScript := preload("res://gameplay/enemies/stone_guardian/stone_guardian.gd")


class TelegraphDummyPlayer:
	extends CharacterBody3D

	var health: float = 100.0
	var damage_taken: float = 0.0
	var last_knockback: Vector3 = Vector3.ZERO

	func _ready() -> void:
		add_to_group("player")
		add_to_group("players")

	func take_damage(amount: float) -> void:
		damage_taken += amount
		health -= amount

	func apply_knockback(impulse: Vector3, _duration: float = 0.1) -> void:
		last_knockback = impulse


var world: Node3D = null


func before_each() -> void:
	world = Node3D.new()
	add_child_autofree(world)


func test_crawler_bite_windup_and_cooldown() -> void:
	var crawler: Node3D = CRAWLER_SCENE.instantiate()
	world.add_child(crawler)
	crawler.global_position = Vector3(0.0, 0.0, 0.0)

	var dummy: TelegraphDummyPlayer = TelegraphDummyPlayer.new()
	world.add_child(dummy)
	dummy.global_position = Vector3(0.0, 0.0, -1.0)

	crawler.call(&"_enter_state", CrawlerScript.State.CRAWL)
	crawler.call(&"_process_crawl", 0.02)

	assert_eq(crawler.get("state"), CrawlerScript.State.BITE_WINDUP, "Crawler deve entrar em BITE_WINDUP antes de morder (#63)")
	assert_eq(dummy.damage_taken, 0.0, "Dummy nao deve levar dano imediatamente no windup")

	# Completa o windup
	crawler.call(&"_enemy_physics", 0.4)
	assert_gt(dummy.damage_taken, 0.0, "Dummy deve receber dano apos concluir o windup")
	assert_gt(dummy.last_knockback.length(), 0.0, "Dummy deve sofrer knockback para quebrar o lock de mordida")
	assert_gt(float(crawler.get("_bite_cooldown")), 1.0, "Crawler deve ter cooldown de mordida ativo")
	assert_eq(crawler.get("state"), CrawlerScript.State.RECOVER, "Crawler deve ir para RECOVER apos a mordida")


func test_ice_wolf_bite_windup_and_cooldown() -> void:
	var wolf: Node3D = ICE_WOLF_SCENE.instantiate()
	world.add_child(wolf)
	wolf.global_position = Vector3(0.0, 0.0, 0.0)

	var dummy: TelegraphDummyPlayer = TelegraphDummyPlayer.new()
	world.add_child(dummy)
	dummy.global_position = Vector3(0.0, 0.0, -1.0)

	wolf.call(&"_enter_state", IceWolfScript.State.CHASE)
	wolf.call(&"_process_chase", 0.02)

	assert_eq(wolf.get("state"), IceWolfScript.State.BITE_WINDUP, "Lobo deve entrar em BITE_WINDUP antes de morder (#63)")
	assert_eq(dummy.damage_taken, 0.0, "Dummy nao deve levar dano imediatamente no windup")

	# Completa o windup
	wolf.call(&"_enemy_physics", 0.4)
	assert_gt(dummy.damage_taken, 0.0, "Dummy deve receber dano apos concluir o windup")
	assert_gt(dummy.last_knockback.length(), 0.0, "Dummy deve sofrer knockback que afasta o jogador")
	assert_gt(float(wolf.get("_bite_cooldown")), 1.0, "Lobo deve ter cooldown de mordida ativo")
	assert_eq(wolf.get("state"), IceWolfScript.State.RECOVER, "Lobo deve ir para RECOVER apos a mordida")


func test_stone_guardian_smash_telegraph() -> void:
	var guardian: Node3D = STONE_GUARDIAN_SCENE.instantiate()
	world.add_child(guardian)
	guardian.global_position = Vector3(0.0, 0.0, 0.0)

	var dummy: TelegraphDummyPlayer = TelegraphDummyPlayer.new()
	world.add_child(dummy)
	dummy.global_position = Vector3(0.0, 0.0, -1.0)

	guardian.call(&"_enter_state", StoneGuardianScript.State.WALK)
	guardian.call(&"_process_walk", 0.02)

	assert_eq(guardian.get("state"), StoneGuardianScript.State.WINDUP, "Guardião deve entrar em WINDUP quando jogador esta no alcance de ataque")
