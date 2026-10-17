extends GutTest

## #95: na Geleira o barulho solta avalanches nas encostas e faz cair estalactites. Cavar com
## cuidado não chega a fazer cair uma estalactite; cavar à pressa sim.

var world: Node3D
var hazards: GeleiraHazards


class FakePlayer extends Node3D:
	var damage: float = 0.0
	var knock: Vector3 = Vector3.ZERO

	func apply_damage(amount: float, _from: Vector3 = Vector3.INF) -> void:
		damage += amount

	func apply_knockback(impulse: Vector3, _shake: float = 0.0) -> void:
		knock += impulse


func before_each() -> void:
	world = Node3D.new()
	add_child_autoqfree(world)
	var pickups: PickupsRoot = PickupsRoot.new()
	world.add_child(pickups)
	hazards = GeleiraHazards.new()
	world.add_child(hazards)


func _player_at(pos: Vector3) -> FakePlayer:
	var p: FakePlayer = FakePlayer.new()
	p.add_to_group(&"players")
	world.add_child(p)
	p.global_position = pos
	return p


func test_stalactites_hang_under_the_arches() -> void:
	assert_eq(hazards.stalactites.size(), 6, "3 no arco de gelo e 3 na gruta")
	for s: Dictionary in hazards.stalactites:
		assert_gt((s["top"] as Vector3).y - float(s["ground"]), 2.5, "Penduradas bem acima do chão")


func test_careful_digging_never_drops_a_stalactite() -> void:
	var top: Vector3 = hazards.stalactites[0]["top"]
	var origin: Vector3 = Vector3(top.x, 0.0, top.z)
	# pazadas cuidadosas a ~1.4 s: o barulho decai mais depressa do que acumula
	for i: int in 12:
		hazards.on_noise(DisturbanceMeter.NOISE_CAREFUL_DIG, origin, 0.2)
		hazards._process(1.4)
	assert_false(bool(hazards.stalactites[0]["fallen"]), "Cuidado = segurança")


func test_fast_digging_drops_the_stalactite_and_hurts_below() -> void:
	var top: Vector3 = hazards.stalactites[0]["top"]
	var under: FakePlayer = _player_at(Vector3(top.x, float(hazards.stalactites[0]["ground"]), top.z))
	var origin: Vector3 = Vector3(top.x + 1.0, 0.0, top.z)
	hazards.on_noise(DisturbanceMeter.NOISE_FAST_DIG, origin, 0.2)
	hazards._process(0.9)
	hazards.on_noise(DisturbanceMeter.NOISE_FAST_DIG, origin, 0.2)
	assert_true(bool(hazards.stalactites[0]["fallen"]), "Duas pazadas rápidas por baixo derrubam-na")
	assert_eq(under.damage, 0.0, "Primeiro a sombra: ainda dá para fugir")
	await wait_seconds(GeleiraHazards.STALACTITE_SHADOW_TIME + GeleiraHazards.STALACTITE_FALL_TIME + 0.2)
	assert_eq(under.damage, GeleiraHazards.STALACTITE_DAMAGE, "Magoa quem ficou por baixo")
	assert_false((hazards.stalactites[0]["node"] as Node3D).visible, "Partiu-se no chão")


func test_far_noise_does_not_touch_stalactites() -> void:
	for i: int in 6:
		hazards.on_noise(DisturbanceMeter.NOISE_FAST_DIG, Vector3(-20.0, 0.0, 15.0), 0.2)
	for s: Dictionary in hazards.stalactites:
		assert_false(bool(s["fallen"]))


func test_slope_near_walls_only() -> void:
	assert_true(hazards.slope_near(Vector3(0.0, 0.0, 0.0)).is_empty(), "No meio do mapa não há encosta")
	var s: Dictionary = hazards.slope_near(Vector3(-24.0, 0.0, 10.0))
	assert_false(s.is_empty(), "Junto à parede oeste")
	assert_eq(s["dir"], Vector3(1.0, 0.0, 0.0), "A neve desce para dentro do mapa")
	assert_almost_eq((s["start"] as Vector3).x, -hazards.slope_half, 0.01)


func test_quiet_noise_near_a_wall_is_safe() -> void:
	hazards.on_noise(DisturbanceMeter.NOISE_FAST_DIG, Vector3(-24.0, 0.0, 10.0), hazards.avalanche_ratio - 0.1)
	assert_eq(hazards._avalanche_cd, 0.0, "Abaixo do limiar a encosta aguenta")


func test_avalanche_pushes_players_and_reburies_spots() -> void:
	var start: Vector3 = Vector3(-29.0, 0.0, 10.0)
	var dir: Vector3 = Vector3(1.0, 0.0, 0.0)
	var caught: FakePlayer = _player_at(Vector3(-25.0, 0.0, 10.0))
	var safe: FakePlayer = _player_at(Vector3(-10.0, 0.0, 10.0))
	var spot: BuriedSpot = (load("res://items/buried_spot.tscn") as PackedScene).instantiate() as BuriedSpot
	world.add_child(spot)
	spot.global_position = Vector3(-24.0, 0.0, 11.0)
	spot.dirt_layers = 1
	hazards.on_noise(DisturbanceMeter.NOISE_FAST_DIG, Vector3(-24.0, 0.0, 10.0), hazards.avalanche_ratio + 0.1)
	assert_gt(hazards._avalanche_cd, 0.0, "Avalanche disparada")
	assert_eq(caught.knock, Vector3.ZERO, "Telegrafada: ainda não chegou")
	await wait_seconds(hazards.avalanche_telegraph + 0.2)
	assert_gt(caught.knock.dot(dir), 5.0, "Empurra quem estava na faixa")
	assert_eq(safe.knock, Vector3.ZERO, "Longe da encosta não acontece nada")
	assert_eq(spot.dirt_layers, BuriedSpot.MAX_DIRT_LAYERS, "O spot voltou a ficar soterrado")
	assert_eq(hazards.get_snow_mound_count(), 1, "Monte de neve por cima")
	assert_true(GeleiraHazards.in_avalanche(Vector3(-25.0, 0.0, 10.0), start, dir))


func test_avalanche_has_a_cooldown() -> void:
	var origin: Vector3 = Vector3(-24.0, 0.0, 10.0)
	hazards.on_noise(DisturbanceMeter.NOISE_FAST_DIG, origin, 0.9)
	var cd: float = hazards._avalanche_cd
	hazards._process(1.0)
	hazards.on_noise(DisturbanceMeter.NOISE_FAST_DIG, origin, 0.9)
	assert_almost_eq(hazards._avalanche_cd, cd - 1.0, 0.01, "Uma de cada vez")


func test_geleira_scene_has_hazards() -> void:
	var secrets: Node = (load("res://gameplay/quests/geleira/geleira_secrets.tscn") as PackedScene).instantiate()
	assert_not_null(secrets.get_node_or_null(^"Hazards") as GeleiraHazards)
	secrets.free()
