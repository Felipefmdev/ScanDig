extends GutTest

## Prepared RED only. No staged implementation/fallback and no core registration.
const SOURCE: String = "res://gameplay/enemies/boss/lunar_warden.gd"
const STEP: float = 0.05

class VictimSpy extends Node3D:
	var hits: int = 0
	var damage: float = 0.0

	func take_damage(amount: float) -> void:
		hits += 1
		damage += amount


func _boss(network: bool = false) -> EnemyBase:
	assert_true(ResourceLoader.exists(SOURCE), "RED: lunar_warden staged source is absent")
	if not ResourceLoader.exists(SOURCE): return null
	var source: Script = load(SOURCE) as Script
	assert_not_null(source)
	if source == null: return null
	var boss: EnemyBase = source.new() as EnemyBase
	assert_not_null(boss, "Lunar boss must reuse EnemyBase")
	if boss == null: return null
	for method: StringName in [&"get_combat_state", &"get_weak_point_position", &"set_defeat_reporter"]:
		assert_true(boss.has_method(method), String(method))
		if not boss.has_method(method):
			boss.free()
			return null
	if network: boss.setup_network()
	add_child_autoqfree(boss)
	boss.set_physics_process(false)
	boss.set_process(false)
	return boss


func _state(boss: EnemyBase) -> StringName:
	return StringName(boss.call(&"get_combat_state"))


func _tick(boss: EnemyBase, seconds: float) -> void:
	var remaining: float = seconds
	while remaining > 0.000001 and is_instance_valid(boss) and not boss.is_queued_for_deletion():
		var delta: float = minf(STEP, remaining)
		boss.call(&"_physics_process", delta)
		remaining -= delta


func _until(boss: EnemyBase, desired: StringName, limit: float = 15.0) -> bool:
	var elapsed: float = 0.0
	while _state(boss) != desired and elapsed < limit:
		_tick(boss, STEP)
		elapsed += STEP
	assert_eq(_state(boss), desired, "Cycle reaches " + String(desired))
	return _state(boss) == desired


func _victim(at: Vector3) -> VictimSpy:
	var victim: VictimSpy = VictimSpy.new()
	add_child_autofree(victim)
	victim.global_position = at
	victim.add_to_group(&"players")
	return victim


func test_telegraph_lasts_at_least_one_point_five_seconds_without_damage() -> void:
	var boss: EnemyBase = _boss()
	if boss == null: return
	var victim: VictimSpy = _victim(boss.global_position + Vector3(0,0,-3))
	assert_eq(_state(boss), &"TELEGRAPH")
	_tick(boss, 1.49)
	assert_eq(_state(boss), &"TELEGRAPH", "No short warning")
	assert_eq(victim.hits, 0)
	assert_true(_until(boss, &"EXPOSED"))


func test_protected_states_reject_damage_but_exposure_accepts_basic_damage() -> void:
	var boss: EnemyBase = _boss()
	if boss == null: return
	var initial: float = boss.health
	boss.take_damage(25.0)
	assert_eq(boss.health, initial, "Protected during warning")
	if not _until(boss, &"STRIKE"): return
	boss.take_damage(25.0)
	assert_eq(boss.health, initial, "Protected during strike")
	if not _until(boss, &"EXPOSED"): return
	boss.take_damage(25.0)
	assert_lt(boss.health, initial, "Basic tool damage works without inventory/consumable")
	if not _until(boss, &"COOLDOWN"): return
	var after: float = boss.health
	boss.take_damage(25.0)
	assert_eq(boss.health, after, "Protection returns during cooldown")


func test_strike_hits_locked_lane_once_and_lateral_escape_is_safe() -> void:
	var boss: EnemyBase = _boss()
	if boss == null: return
	var inline: VictimSpy = _victim(boss.global_position + Vector3(0,0,-3))
	# Let host lock origin/direction; players then occupy the indicated lane.
	_tick(boss, STEP)
	var origin: Vector3 = boss.get("net_attack_origin")
	var direction: Vector3 = boss.get("net_attack_dir")
	direction.y = 0.0
	assert_gt(direction.length(), 0.9)
	direction = direction.normalized()
	var side: Vector3 = Vector3(-direction.z,0,direction.x)
	inline.global_position = origin + direction*3.0
	var escaped: VictimSpy = _victim(inline.global_position + side*2.0)
	var behind: VictimSpy = _victim(origin - direction*2.0)
	if not _until(boss, &"EXPOSED"): return
	assert_eq(inline.hits, 1, "One hit per victim per strike, not per tick")
	assert_gt(inline.damage, 0.0)
	assert_eq(escaped.hits, 0, "Walkable lateral escape outside lane")
	assert_eq(behind.hits, 0, "Finite forward lane, not an infinite line")


func test_exposure_five_seconds_then_two_seconds_of_protected_cooldown() -> void:
	var boss: EnemyBase = _boss()
	if boss == null: return
	if not _until(boss, &"EXPOSED"): return
	_tick(boss, 4.90)
	assert_eq(_state(boss), &"EXPOSED")
	if not _until(boss, &"COOLDOWN"): return
	_tick(boss, 1.90)
	assert_eq(_state(boss), &"COOLDOWN", "At least 2s protected pause after attack/exposure")
	assert_true(_until(boss, &"TELEGRAPH"))


func test_real_basic_shovel_attack_reaches_exposed_boss_origin() -> void:
	var boss: EnemyBase = _boss()
	if boss == null: return
	if not _until(boss, &"EXPOSED"): return
	var player: Player = load("res://gameplay/player/player.tscn").instantiate() as Player
	add_child_autoqfree(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.global_position = boss.global_position + Vector3(0,0,2.0)
	player.look_at(Vector3(boss.global_position.x,player.global_position.y,boss.global_position.z))
	var weak: Vector3 = boss.call(&"get_weak_point_position")
	assert_lte(Vector2(weak.x-player.global_position.x,weak.z-player.global_position.z).length(),2.2)
	assert_lte(weak.y-player.global_position.y,1.8,"Core lowered to reachable height")
	assert_gte(weak.y-player.global_position.y,0.0)
	var before: float = boss.health
	player.call(&"_on_swing_hit")
	assert_lt(boss.health,before,"Actual Player shovel routing hits during exposure")


func test_repeated_stun_and_flee_cannot_lock_or_skip_combat_cycle() -> void:
	var boss: EnemyBase = _boss()
	if boss == null: return
	for i: int in 20:
		boss.stun(6.0)
		boss.flee_from(Vector3.ZERO,10.0)
		_tick(boss,0.1)
	assert_false(boss.is_stunned())
	assert_false(boss.is_fleeing())
	assert_true(_until(boss,&"EXPOSED"))
	assert_true(_until(boss,&"COOLDOWN"))
	assert_true(_until(boss,&"TELEGRAPH"))


func test_replication_configuration_includes_spawn_attack_and_phase_fields() -> void:
	var boss: EnemyBase = _boss(true)
	if boss == null: return
	var sync: MultiplayerSynchronizer = boss.get_net_sync()
	assert_not_null(sync)
	if sync == null: return
	var config: SceneReplicationConfig = sync.replication_config
	for path: NodePath in [NodePath(".:net_state"),NodePath(".:health"),NodePath(".:net_attack_origin"),NodePath(".:net_attack_dir"),NodePath(".:net_phase_elapsed")]:
		assert_true(config.has_property(path),"Replicated field " + String(path))
		if config.has_property(path):
			assert_true(config.property_get_spawn(path),"Late join spawn includes " + String(path))


func test_lethal_damage_submits_lunar_final_id_exactly_once() -> void:
	var boss: EnemyBase = _boss()
	if boss == null: return
	var reports: Array[String] = []
	boss.call(&"set_defeat_reporter",func(id: String) -> void: reports.append(id))
	if not _until(boss,&"EXPOSED"): return
	boss.take_damage(boss.max_health*100.0)
	boss.take_damage(boss.max_health*100.0)
	_tick(boss,0.1)
	await wait_frames(2)
	assert_eq(reports,["lunar_warden"],"One host report, no repeated reward/victory from duplicate hits")
	assert_eq(GameState.FINAL_BOSS_ID,"lunar_warden","Integrated final is the lunar boss")
