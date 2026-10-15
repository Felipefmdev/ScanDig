extends GutTest

const BOSS_SCENE: PackedScene = preload("res://gameplay/enemies/boss/giant_mole.tscn")

var arena: Node3D
var boss: GiantMole


func before_each() -> void:
	arena = Node3D.new()
	add_child_autofree(arena)
	boss = BOSS_SCENE.instantiate() as GiantMole
	arena.add_child(boss)
	boss.wake_immediately()


func _count(kind: Variant) -> int:
	var n: int = 0
	for c: Node in arena.get_children():
		if is_instance_of(c, kind):
			n += 1
	return n


func _step(frames: int) -> void:
	for i: int in frames:
		boss._physics_process(1.0 / 60.0)


func test_stats() -> void:
	assert_eq(boss.max_health, 800.0)
	assert_eq(boss.health, 800.0)
	assert_true(boss.is_in_group("enemies"))
	assert_true(boss.is_in_group("bosses"))
	assert_eq(boss.collision_layer, 8)
	assert_eq(GiantMole.BOSS_ID, &"giant_mole")


func test_invulnerable_while_emerging() -> void:
	var fresh: GiantMole = BOSS_SCENE.instantiate() as GiantMole
	arena.add_child(fresh)
	fresh.take_damage(50.0)
	assert_eq(fresh.health, 800.0)


func test_immune_underground() -> void:
	boss._enter_state(GiantMole.State.TUNNEL)
	assert_true(boss.is_underground())
	boss.take_damage(100.0)
	assert_eq(boss.health, 800.0)


func test_dazed_weak_point_doubles_damage() -> void:
	boss.take_damage(10.0)
	assert_eq(boss.health, 790.0)
	boss._enter_state(GiantMole.State.DAZED)
	assert_true(boss.is_weak_point_exposed())
	boss.take_damage(10.0)
	assert_eq(boss.health, 770.0)


func test_tunnel_erupts_under_player_then_dazed() -> void:
	var dummy: DamageDummy = DamageDummy.new()
	arena.add_child(dummy)
	dummy.global_position = Vector3(5.0, 0.0, 0.0)
	boss._erupts_left = 1
	boss._enter_state(GiantMole.State.TUNNEL)
	for i: int in 400:
		if boss.state != GiantMole.State.TUNNEL:
			break
		_step(1)
	assert_eq(boss.state, GiantMole.State.ERUPT_TELEGRAPH, "chegou debaixo do jogador")
	assert_almost_eq(boss.global_position.x, 5.0, 0.7)
	_step(int(boss.erupt_telegraph_time * 60.0) + 2)
	assert_gt(dummy.damage_taken, 0.0, "irromper fere")
	_step(30)
	assert_eq(boss.state, GiantMole.State.DAZED)


func test_tunnel_respects_leash() -> void:
	var dummy: DamageDummy = DamageDummy.new()
	arena.add_child(dummy)
	dummy.global_position = Vector3(40.0, 0.0, 0.0)
	boss._enter_state(GiantMole.State.TUNNEL)
	_step(400)
	var off: Vector3 = boss.global_position - boss.get_home()
	assert_lt(Vector2(off.x, off.z).length(), boss.leash_radius + 0.01)


func test_reinforcements_and_phase_two() -> void:
	watch_signals(boss)
	boss.take_damage(800.0 * 0.35)
	assert_signal_emitted(boss, "reinforcements_called")
	assert_eq(_count(Mole), 2, "2 toupeiras a 66%")
	boss.take_damage(800.0 * 0.2)
	assert_eq(boss.phase, 2)
	assert_signal_emitted_with_parameters(boss, "phase_changed", [2])
	assert_eq(boss.get_erupt_repeats(), 2, "irrompe 2x na fase 2")
	assert_gt(boss.get_tunnel_speed(), boss.tunnel_speed)
	boss.take_damage(800.0 * 0.15)
	assert_eq(_count(Mole), 4, "+2 toupeiras a 33%")


func test_net_cap_and_repellent_immunity() -> void:
	boss.stun(5.0)
	assert_true(boss.is_stunned())
	assert_almost_eq(boss.get("_stun_left") as float, GiantMole.NET_STUN_CAP, 0.001)
	boss.flee_from(Vector3.ZERO, 8.0)
	assert_false(boss.is_fleeing())


func test_death_reports_giant_mole_to_core() -> void:
	var state: GameState = GameState.instance
	var had_it: bool = state.defeated_bosses.has("giant_mole")
	state.defeated_bosses.erase("giant_mole")
	watch_signals(boss)
	boss.take_damage(5000.0)
	assert_false(boss.is_alive())
	for i: int in range(130):
		boss._process(1.0 / 60.0)
	assert_signal_emitted_with_parameters(boss, "boss_defeated", [&"giant_mole"])
	assert_true(state.is_boss_defeated("giant_mole"), "libera as Ruinas")
	if not had_it:
		state.defeated_bosses.erase("giant_mole")


func test_altar_wakes_giant_mole() -> void:
	var altar: MoleAltar = MoleAltar.new()
	arena.add_child(altar)
	assert_null(altar.item)
	assert_true(altar.is_in_group("buried_spots"))
	var res: Dictionary = {}
	for i: int in range(4):
		res = altar.dig(true)
	assert_true(res.get("revealed", false))
	var bosses: int = _count(GiantMole)
	assert_eq(bosses, 2, "o altar acordou outra toupeira gigante (além da do before_each)")
