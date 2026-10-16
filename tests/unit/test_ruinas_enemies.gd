extends GutTest

## #42: inimigos das Ruínas (Guardião de pedra, Morcego) e o mapa.

const GUARDIAN_SCENE: PackedScene = preload("res://gameplay/enemies/stone_guardian/stone_guardian.tscn")
const BAT_SCENE: PackedScene = preload("res://gameplay/enemies/bat/bat.tscn")

var world: Node3D


func before_each() -> void:
	world = Node3D.new()
	add_child_autofree(world)


func _guardian() -> StoneGuardian:
	var g: StoneGuardian = GUARDIAN_SCENE.instantiate() as StoneGuardian
	world.add_child(g)
	g.call(&"_enter_state", StoneGuardian.State.WALK)
	return g


func test_guardian_armor_opens_when_stunned_or_dizzy() -> void:
	var g: StoneGuardian = _guardian()
	g.take_damage(10.0)
	assert_almost_eq(g.health, 136.0, 0.01, "de pedra: só 40 %")
	g.stun(1.0)
	g.take_damage(10.0)
	assert_almost_eq(g.health, 126.0, 0.01, "atordoado (lanterna): dano inteiro")
	g.call(&"_enter_state", StoneGuardian.State.DIZZY)
	assert_true(g.is_armor_open())


func test_guardian_roll_hits_and_gets_dizzy() -> void:
	var g: StoneGuardian = _guardian()
	g.net_roll_dir = Vector3.FORWARD
	g.call(&"_enter_state", StoneGuardian.State.ROLL)
	assert_eq(g.state, StoneGuardian.State.ROLL)
	# Contra nada (sem chão nem paredes) acaba o percurso e fica tonto.
	for i: int in 120:
		g._enemy_physics(0.05)
		if g.state != StoneGuardian.State.ROLL:
			break
	assert_eq(g.state, StoneGuardian.State.DIZZY)


func test_bat_flees_from_lantern() -> void:
	var bat: Bat = BAT_SCENE.instantiate() as Bat
	world.add_child(bat)
	bat.global_position = Vector3(0.0, 0.0, -3.0)
	assert_true(bat.is_in_group(LanternFlash.GROUP_FLEES))
	var shooter: Node3D = Node3D.new()
	world.add_child(shooter)
	var hits: int = LanternFlash.fire(Vector3(0.0, -0.5, 0.0), Vector3.FORWARD, shooter)
	assert_eq(hits, 1)
	assert_true(bat.is_fleeing())


func test_kinds_and_map_scene() -> void:
	for kind: StringName in [&"stone_guardian", &"bat"]:
		assert_true(EnemySpawner.KIND_SCENES.has(kind), String(kind))
	assert_true(ResourceLoader.exists("res://world/map_ruinas.tscn"))
	assert_almost_eq(RuinsTerrain.height_at(0.0, -21.0), RuinsTerrain.TEMPLE_HEIGHT, 0.05, "plataforma do templo")
	assert_lt(RuinsTerrain.height_at(-22.0, -6.0), -1.0, "cripta afundada")
