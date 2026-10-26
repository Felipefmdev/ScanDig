extends GutTest

## Regressão #188: cenas/ataques reais, com observador de dano como nas suites de chefes.
const ECHO: PackedScene = preload("res://gameplay/enemies/boss/the_echo.tscn")
const MAMMOTH: PackedScene = preload("res://gameplay/enemies/boss/frozen_mammoth.tscn")
const DT: float = 1.0 / 60.0

class Observer extends Node3D:
	var damage: float = 0.0
	var impulses: Array[Vector3] = []
	func _ready() -> void:
		add_to_group("player")
		add_to_group("players")
	func take_damage(amount: float) -> void:
		damage += amount
	func apply_knockback(impulse: Vector3, _shake: float = 0.0) -> void:
		impulses.append(impulse)

var arena: Node3D = null
var dummy: Observer = null
var particle_refs: Array[WeakRef] = []
var case_name: String = "setup"
var max_particle_wait: float = 0.0


func before_each() -> void:
	arena = Node3D.new()
	arena.name = "Boss188TranslatedParent"
	arena.position = Vector3(17,3,-11)
	add_child(arena)
	dummy = Observer.new()
	dummy.name = "1"
	arena.add_child(dummy)
	dummy.global_position = Vector3(100,10,100)
	particle_refs.clear()
	max_particle_wait = 0.0
	case_name = "setup"
	printerr("BOSS188 BEGIN fixture translated_parent=",arena.global_position)


func _boss(scene: PackedScene) -> EnemyBase:
	var boss: EnemyBase = scene.instantiate() as EnemyBase
	boss.position = Vector3(5,2,7)
	arena.add_child(boss)
	# Deterministic attack unit slice, matching chaos suite stepping, no concurrent AI.
	boss.set_physics_process(false)
	assert_true(boss.is_node_ready())
	assert_true(boss.has_simulation_authority())
	assert_eq(boss._all_players().size(),1,"isolated observation target; fail if unrelated live players contaminate fixture")
	var expected_after_ready: Vector3 = Vector3(22,1.5,-4) if boss is FrozenMammoth else Vector3(22,5,-4)
	assert_almost_eq(boss.global_position,expected_after_ready,Vector3.ONE*.001,"translated setup includes Mammoth EMERGE lowering world Y by3.5")
	return boss


func _watch_particles() -> void:
	if not is_instance_valid(arena): return
	for node: Node in arena.get_children():
		if node is CPUParticles3D:
			var particles: CPUParticles3D = node as CPUParticles3D
			var known: bool = false
			for reference: WeakRef in particle_refs:
				if reference.get_ref() == particles: known = true
			if not known: particle_refs.append(weakref(particles))
			max_particle_wait = maxf(max_particle_wait,particles.lifetime+.3+.25)


func _drain_timers() -> void:
	_watch_particles()
	printerr("BOSS188 ",case_name," TIMER_WAIT seconds=",max_particle_wait," particles=",particle_refs.size())
	if max_particle_wait > 0:
		await get_tree().create_timer(max_particle_wait).timeout
		max_particle_wait = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	for reference: WeakRef in particle_refs:
		assert_null(reference.get_ref(),"real production particle retirement completed")
	printerr("BOSS188 ",case_name," TIMER_DRAINED")


func after_each() -> void:
	# Let actual production timers fire even if a geometric assertion failed.
	await _drain_timers()
	if is_instance_valid(arena): arena.free()
	arena = null
	dummy = null
	await get_tree().process_frame
	printerr("BOSS188 END ",case_name)


func test_echo_sonic_ring_world_position_damage_knockback_and_expiry() -> void:
	case_name = "echo_sonic"
	var boss: TheEcho = _boss(ECHO) as TheEcho
	var center: Vector3 = boss.global_position
	dummy.global_position = center+Vector3(2,0,0)
	var multiplier: float = DifficultyProfile.current(get_tree()).enemy_damage_multiplier
	printerr("BOSS188 ",case_name," ATTACK center=",center)
	boss._execute_sonic_rings()
	assert_eq(boss._sonic_rings.size(),1,"real attack emits one ring")
	assert_almost_eq(dummy.damage,boss.sonic_damage*multiplier,.001,"sonic damage pipeline preserved")
	assert_eq(dummy.impulses.size(),1)
	if not dummy.impulses.is_empty(): assert_almost_eq(dummy.impulses[0],Vector3(15,8,0),Vector3.ONE*.001,"existing radial knockback")
	if boss._sonic_rings.size() != 1: return
	var ring: MeshInstance3D = boss._sonic_rings[0]
	var reference: WeakRef = weakref(ring)
	printerr("BOSS188 ",case_name," POSITION expected=",center," actual=",ring.global_position)
	assert_true(ring.top_level)
	assert_almost_eq(ring.global_position,center,Vector3.ONE*.001,"ring world center equals attack origin")
	for frame: int in 40: boss._update_sonic_rings(DT)
	assert_eq(boss._sonic_rings.size(),0,"natural expansion threshold removes ring registry")
	assert_eq(boss._ring_scales.size(),0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_null(reference.get_ref(),"queued ring is freed")
	_watch_particles()


func test_echo_three_recorded_delayed_bursts_keep_world_centers() -> void:
	case_name = "echo_delayed3"
	var boss: TheEcho = _boss(ECHO) as TheEcho
	var visited: Array[Vector3] = []
	for offset: float in [-3.0,0.0,3.0]:
		var point: Vector3 = boss.global_position+Vector3(offset,0,4)
		visited.append(point)
		dummy.global_position = point
		# Existing chaos test pattern: request a real trail sample, don't seed net points.
		boss._trail_timer = 0.0
		boss._record_trail(DT)
	boss._enter_state(TheEcho.State.ECHO_TELE)
	assert_eq(boss.net_echo_points.size(),3,"three recorded samples reach real attack")
	for index: int in mini(3,boss.net_echo_points.size()):
		assert_almost_eq(boss.net_echo_points[index],visited[index],Vector3.ONE*.001,"no floor fixture: record fallback preserves actual visited point")
	var seen: Dictionary = {}
	var multiplier: float = DifficultyProfile.current(get_tree()).enemy_damage_multiplier
	for frame: int in 210:
		boss._enemy_physics(DT)
		for ring: MeshInstance3D in boss._sonic_rings:
			if seen.has(ring.get_instance_id()): continue
			var index: int = seen.size()
			seen[ring.get_instance_id()] = weakref(ring)
			if index < visited.size():
				printerr("BOSS188 ",case_name," POSITION index=",index," expected=",visited[index]+Vector3.UP*.1," actual=",ring.global_position)
				assert_almost_eq(ring.global_position,visited[index]+Vector3.UP*.1,Vector3.ONE*.001,"each burst at its recorded world point")
		if seen.size() == 3: break
	assert_eq(seen.size(),3,"observe all three distinct bursts, even if oldest already retired")
	assert_almost_eq(dummy.damage,TheEcho.ECHO_DAMAGE*multiplier,.001,"only final recorded point hits stationary observer")
	assert_eq(dummy.impulses.size(),1)
	if not dummy.impulses.is_empty(): assert_almost_eq(dummy.impulses[0],Vector3(0,11,-4),Vector3.ONE*.001,"existing center fallback echo knockback")
	for frame: int in 40: boss._update_sonic_rings(DT)
	await get_tree().process_frame
	await get_tree().process_frame
	for reference: WeakRef in seen.values(): assert_null(reference.get_ref(),"all observed rings retire")
	_watch_particles()


func test_mammoth_two_snowballs_world_spawn_movement_hit_and_cleanup() -> void:
	case_name = "mammoth_snowballs2"
	var boss: FrozenMammoth = _boss(MAMMOTH) as FrozenMammoth
	assert_eq(boss.phase,1,"default phase produces two snowballs")
	var center: Vector3 = boss.global_position
	dummy.global_position = center+Vector3(2,0,0)
	var multiplier: float = DifficultyProfile.current(get_tree()).enemy_damage_multiplier
	boss._execute_stomp_and_avalanche()
	assert_almost_eq(dummy.damage,boss.stomp_damage*multiplier,.001,"stomp damage unchanged")
	assert_eq(dummy.impulses.size(),1)
	if not dummy.impulses.is_empty(): assert_almost_eq(dummy.impulses[0],Vector3(10,7,0),Vector3.ONE*.001,"stomp knockback unchanged")
	assert_eq(boss._snowballs.size(),2,"real phase1 attack emits two")
	if boss._snowballs.size() != 2: return
	var refs: Array[WeakRef] = []
	var origins: Array[Vector3] = []
	var dirs: Array[Vector3] = []
	for index: int in 2:
		var direction: Vector3 = Vector3.FORWARD.rotated(Vector3.UP,-.5+float(index))
		var expected: Vector3 = center+Vector3.UP*.8+direction*1.5
		dirs.append(direction)
		origins.append(expected)
		var ball: MeshInstance3D = boss._snowballs[index]
		refs.append(weakref(ball))
		printerr("BOSS188 ",case_name," POSITION index=",index," expected=",expected," actual=",ball.global_position)
		assert_almost_eq(ball.global_position,expected,Vector3.ONE*.001,"snowball world spawn contract")
		assert_almost_eq(boss._snowball_dirs[index],direction,Vector3.ONE*.001)
		assert_almost_eq(boss._snowball_speeds[index],8.5,.001)
	dummy.global_position = origins[0]+dirs[0]*8.5*.1
	boss._update_snowballs(.1)
	assert_eq(boss._snowballs.size(),2,"first movement step must retain both in-range projectiles")
	if boss._snowballs.size() != 2: return
	for index: int in 2:
		assert_almost_eq(boss._snowballs[index].global_position,origins[index]+dirs[index]*.85,Vector3.ONE*.001,"projectile advances in world direction")
	assert_almost_eq(dummy.damage,(boss.stomp_damage+boss.snowball_damage)*multiplier,.001,"one actual projectile collision adds existing damage")
	assert_eq(dummy.impulses.size(),2)
	if dummy.impulses.size() >= 2: assert_almost_eq(dummy.impulses[1],dirs[0]*12.0+Vector3.UP*4,Vector3.ONE*.001,"snowball knockback preserved")
	dummy.global_position = Vector3(100,10,100)
	for frame: int in 200: boss._update_snowballs(DT)
	assert_eq(boss._snowballs.size(),0,"distance expiry clears projectiles")
	assert_eq(boss._snowball_dirs.size(),0)
	assert_eq(boss._snowball_speeds.size(),0)
	await get_tree().process_frame
	await get_tree().process_frame
	for reference: WeakRef in refs: assert_null(reference.get_ref())
	_watch_particles()


func test_attack_scene_teardown_before_real_particle_timers() -> void:
	case_name = "early_scene_teardown"
	var echo: TheEcho = _boss(ECHO) as TheEcho
	var mammoth: FrozenMammoth = _boss(MAMMOTH) as FrozenMammoth
	echo._execute_sonic_rings()
	mammoth._execute_stomp_and_avalanche()
	_watch_particles()
	assert_gt(particle_refs.size(),0,"actual attacks scheduled production particle timers")
	var arena_ref: WeakRef = weakref(arena)
	var echo_ref: WeakRef = weakref(echo)
	var mammoth_ref: WeakRef = weakref(mammoth)
	var mesh_refs: Array[WeakRef] = []
	for ring: MeshInstance3D in echo._sonic_rings: mesh_refs.append(weakref(ring))
	for ball: MeshInstance3D in mammoth._snowballs: mesh_refs.append(weakref(ball))
	printerr("BOSS188 ",case_name," FREE_SCENE_BEFORE_TIMER")
	arena.free()
	arena = null
	dummy = null
	assert_null(arena_ref.get_ref())
	assert_null(echo_ref.get_ref())
	assert_null(mammoth_ref.get_ref())
	for reference: WeakRef in mesh_refs: assert_null(reference.get_ref(),"top-level meshes still owned children and freed with scene")
	await _drain_timers()
	assert_true(is_inside_tree(),"GUT watcher survives timeout after boss/scene teardown")
