extends GutTest

const CRAB_SCENE: PackedScene = preload("res://gameplay/enemies/crab/crab.tscn")


class FakePlayer extends Node3D:
	var hits: Array[float] = []

	func take_damage(amount: float) -> void:
		hits.append(amount)


func after_each() -> void:
	DifficultyProfile.override = null


func test_solo_profile() -> void:
	var p: DifficultyProfile = DifficultyProfile.for_player_count(1)
	assert_eq(p.max_alive, 3)
	assert_eq(p.ambient_grace_seconds, 180.0)
	assert_eq(p.ambient_interval_multiplier, 1.8)
	assert_eq(p.crabs_per_level, [1, 1, 2] as Array[int])
	assert_eq(p.hermits_per_level, [0, 1, 1] as Array[int])
	assert_eq(p.seagulls_per_level, [0, 0, 1] as Array[int])
	assert_eq(p.enemy_damage_multiplier, 0.6)


func test_duo_keeps_current_values_and_crowd_is_harder() -> void:
	var duo: DifficultyProfile = DifficultyProfile.for_player_count(2)
	assert_eq(duo.max_alive, 6)
	assert_eq(duo.ambient_grace_seconds, 0.0)
	assert_eq(duo.crabs_per_level, [1, 2, 4] as Array[int])
	assert_eq(duo.enemy_damage_multiplier, 1.0)
	var four: DifficultyProfile = DifficultyProfile.for_player_count(4)
	assert_gt(four.max_alive, duo.max_alive)
	assert_gt(four.enemy_damage_multiplier, duo.enemy_damage_multiplier)
	assert_lt(four.ambient_interval_multiplier, duo.ambient_interval_multiplier)


func test_offline_counts_as_solo() -> void:
	assert_eq(DifficultyProfile.get_player_count(get_tree()), 1)


func test_enemy_damage_scaled_in_solo() -> void:
	DifficultyProfile.override = DifficultyProfile.for_player_count(1)
	var crab: Crab = CRAB_SCENE.instantiate() as Crab
	add_child_autofree(crab)
	var fake: FakePlayer = FakePlayer.new()
	add_child_autofree(fake)
	crab.call("_deal_damage", fake, 10.0)
	assert_almost_eq(fake.hits[0], 6.0, 0.001, "solo: dano x0.6")
	DifficultyProfile.override = DifficultyProfile.for_player_count(2)
	crab.call("_deal_damage", fake, 10.0)
	assert_almost_eq(fake.hits[1], 10.0, 0.001, "coop: dano normal")


func test_spawner_solo_threshold_and_cap() -> void:
	DifficultyProfile.override = DifficultyProfile.for_player_count(1)
	var spawner: EnemySpawner = EnemySpawner.new()
	add_child_autofree(spawner)
	assert_eq(spawner.get_max_alive(), 3)
	# Nível 3 em solo pediria 2 crabs + 1 ermitão + 1 gaivota, mas o máximo vivo é 3
	spawner.call("_on_threshold_reached", 3, Vector3.ZERO)
	assert_true(spawner.get_alive_count() <= 3, "respeita max_alive=3 em solo")


func test_spawner_grace_period_blocks_ambient() -> void:
	DifficultyProfile.override = DifficultyProfile.for_player_count(1)
	var spawner: EnemySpawner = EnemySpawner.new()
	add_child_autofree(spawner)
	var player: Node3D = Node3D.new()
	player.add_to_group("player")
	add_child_autofree(player)
	spawner.set("_ambient_timer", 0.0)
	spawner.call("_process_ambient", 1.0)
	assert_eq(spawner.get_alive_count(), 0, "sem spawns ambiente durante a graça")
	assert_true(float(spawner.get("_ambient_timer")) <= 0.0, "temporizador parado durante a graça")
