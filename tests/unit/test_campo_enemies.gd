extends GutTest

## Inimigos do Campo Antigo (#20): cobra, toupeira e o EnemySpawner por kinds.

const SNAKE_SCENE: PackedScene = preload("res://gameplay/enemies/snake/snake.tscn")
const MOLE_SCENE: PackedScene = preload("res://gameplay/enemies/mole/mole.tscn")

var arena: Node3D


func before_each() -> void:
	arena = Node3D.new()
	add_child_autofree(arena)


func _snake() -> Snake:
	var s: Snake = SNAKE_SCENE.instantiate() as Snake
	arena.add_child(s)
	return s


func _mole() -> Mole:
	var m: Mole = MOLE_SCENE.instantiate() as Mole
	arena.add_child(m)
	return m


func _step(e: EnemyBase, frames: int) -> void:
	for i: int in frames:
		e._physics_process(1.0 / 60.0)


func test_snake_stats_and_groups() -> void:
	var s: Snake = _snake()
	assert_eq(s.max_health, 30.0)
	assert_true(s.is_in_group("enemies"))
	assert_eq(s.collision_layer, 8)
	assert_lt(s.move_speed, 4.5, "mais lenta que o jogador (4.5)")


func test_snake_immune_while_emerging_then_chases() -> void:
	var s: Snake = _snake()
	s.take_damage(10.0)
	assert_eq(s.health, 30.0, "imune a sair da erva")
	_step(s, 40)
	assert_eq(s.state, Snake.State.CHASE)
	s.take_damage(10.0)
	assert_eq(s.health, 20.0)


func test_snake_flees_after_stun_and_leaves() -> void:
	var s: Snake = _snake()
	_step(s, 40)
	s.stun(0.5)
	assert_true(s.stunned, "campo replicável stunned")
	_step(s, 40)
	assert_false(s.is_stunned())
	assert_true(s.is_fleeing(), "foge quando o atordoamento acaba")
	assert_eq(s.state, Snake.State.FLEE)
	s.fleeing = false
	_step(s, 2)
	assert_eq(s.state, Snake.State.LEAVE)
	_step(s, 60)
	assert_true(s.is_queued_for_deletion(), "some na erva")


func test_mole_immune_underground_and_vulnerable_when_exposed() -> void:
	var m: Mole = _mole()
	assert_eq(m.state, Mole.State.UNDERGROUND)
	m.take_damage(20.0)
	assert_eq(m.health, 45.0, "imune debaixo de terra")
	m.stun(2.0)
	assert_false(m.is_stunned())
	m._enter_state(Mole.State.EXPOSED)
	m.take_damage(20.0)
	assert_eq(m.health, 25.0)


func test_mole_erupts_under_target_and_damages() -> void:
	var m: Mole = _mole()
	var dummy: DamageDummy = DamageDummy.new()
	arena.add_child(dummy)
	dummy.global_position = Vector3(0.3, 0.0, 0.0)
	_step(m, 2)
	assert_eq(m.state, Mole.State.TELEGRAPH, "parou debaixo do jogador")
	_step(m, int(m.telegraph_time * 60.0) + 2)
	assert_eq(m.state, Mole.State.ERUPT)
	assert_gt(dummy.damage_taken, 0.0, "irromper fere quem ficou no aviso")
	_step(m, 20)
	assert_eq(m.state, Mole.State.EXPOSED)


func test_mole_dodge_by_leaving_warning() -> void:
	var m: Mole = _mole()
	var dummy: DamageDummy = DamageDummy.new()
	arena.add_child(dummy)
	dummy.global_position = Vector3(0.3, 0.0, 0.0)
	_step(m, 2)
	dummy.global_position = Vector3(4.0, 0.0, 0.0)
	_step(m, int(m.telegraph_time * 60.0) + 2)
	assert_eq(dummy.damage_taken, 0.0, "sair da marca evita o golpe")


func test_replicated_client_does_not_simulate() -> void:
	var s: Snake = _snake()
	assert_true(s.has_simulation_authority(), "solo = host")
	s.replicated = true
	assert_true(s.has_simulation_authority(), "sem peer de rede continua a simular")


func test_spawner_spawns_by_data() -> void:
	var spawner: EnemySpawner = EnemySpawner.new()
	spawner.primary_kind = &"snake"
	spawner.secondary_kind = &"mole"
	add_child_autofree(spawner)
	var data: Dictionary = EnemySpawner.make_spawn_data(&"snake", Vector3(1, 0, 2), 2)
	assert_eq(data, {"kind": "snake", "pos": Vector3(1, 0, 2), "level": 2})
	var e: Node3D = spawner.spawn_from_data(data)
	assert_true(e is Snake)
	assert_eq((e as Snake).spawn_level, 2)
	assert_almost_eq(e.global_position.x, 1.0, 0.001)
	assert_true(spawner.spawn_from_data(EnemySpawner.make_spawn_data(&"mole", Vector3.ZERO, 0)) is Mole)
	assert_null(spawner.spawn_from_data({"kind": "dragao", "pos": Vector3.ZERO, "level": 0}))
	assert_eq(spawner.get_alive_count(), 2)
	for kind: StringName in EnemySpawner.KIND_SCENES:
		assert_not_null(EnemySpawner.scene_for_kind(kind), "cena de %s" % kind)


func test_campo_spawner_uses_campo_kinds() -> void:
	var scene: PackedScene = load("res://world/map_campo.tscn") as PackedScene
	var state: SceneState = scene.get_state()
	var found: bool = false
	for i: int in state.get_node_count():
		if state.get_node_name(i) != &"EnemySpawner":
			continue
		found = true
		for p: int in state.get_node_property_count(i):
			match state.get_node_property_name(i, p):
				&"primary_kind":
					assert_eq(state.get_node_property_value(i, p), &"snake")
				&"secondary_kind":
					assert_eq(state.get_node_property_value(i, p), &"mole")
				&"seagulls_per_level":
					assert_eq(state.get_node_property_value(i, p), [0, 0, 0], "sem gaivotas no Campo")
	assert_true(found)
