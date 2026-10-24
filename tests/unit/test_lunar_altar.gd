extends GutTest

const SOURCE: String = "res://gameplay/environment/lunar_altar.gd"


func after_each() -> void:
	# Drain deferred A11y node checks before GUT frees fixture bosses.
	await get_tree().process_frame
	await get_tree().process_frame

class BossStub extends EnemyBase:
	func _ready() -> void:
		super._ready()
		add_to_group(&"bosses")

class ActivationSpy extends Node:
	var actor_ready: bool = true
	var defeated: bool = false
	var refuse_spawn: bool = false
	var positions: Array[Vector3] = []
	var bosses: Array[EnemyBase] = []
	func is_ready_peer(_peer_id: int) -> bool:
		return actor_ready
	func is_defeated() -> bool:
		return defeated
	func spawn(at: Vector3) -> EnemyBase:
		positions.append(at)
		if refuse_spawn: return null
		var boss: BossStub = BossStub.new()
		add_child(boss)
		boss.global_position = at
		boss.set_physics_process(false)
		bosses.append(boss)
		return boss


func _spy() -> ActivationSpy:
	var spy: ActivationSpy = ActivationSpy.new()
	add_child_autofree(spy)
	return spy


func _altar(spy: ActivationSpy) -> BuriedSpot:
	assert_true(ResourceLoader.exists(SOURCE),"RED: lunar altar staged source is absent")
	if not ResourceLoader.exists(SOURCE): return null
	var altar: BuriedSpot = (load(SOURCE) as Script).new() as BuriedSpot
	assert_not_null(altar,"Reuse BuriedSpot")
	if altar == null: return null
	for method: StringName in [&"configure_activation",&"get_activation_state"]:
		assert_true(altar.has_method(method),String(method))
		if not altar.has_method(method):
			altar.free()
			return null
	altar.call(&"configure_activation",spy.is_ready_peer,spy.is_defeated,spy.spawn)
	altar.position = Vector3(0,-0.8,-15)
	add_child_autoqfree(altar)
	return altar


func _player() -> Player:
	var player: Player = load("res://gameplay/player/player.tscn").instantiate() as Player
	player.name = "1"
	add_child_autoqfree(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.global_position = Vector3(0,-0.8,-13.5)
	return player


func _dig_all(altar: BuriedSpot, player: Player) -> void:
	for i: int in 3:
		altar.dig(true,1.0,false,player)


func test_three_host_dug_layers_spawn_once_at_arena_ground() -> void:
	var spy: ActivationSpy = _spy()
	var altar: BuriedSpot = _altar(spy)
	if altar == null: return
	var player: Player = _player()
	assert_true(altar.networked,"Client uses request_dig, not local wake")
	assert_null(altar.item)
	assert_false(altar.free_on_reveal)
	for i: int in 3:
		var result: Dictionary = altar.dig(true,1.0,false,player)
		assert_true(bool(result.get("dug",false)))
		assert_eq(altar.dirt_layers,2-i)
		assert_eq(spy.positions.size(),1 if i==2 else 0)
	assert_eq(StringName(altar.call(&"get_activation_state")),&"ACTIVE")
	assert_eq(spy.positions,[Vector3(0,-0.8,-15)])
	_dig_all(altar,player)
	assert_eq(spy.positions.size(),1,"No duplicate boss from repeated dig/reveal")


func test_missing_fake_dead_and_distant_actors_cannot_remove_layers() -> void:
	var spy: ActivationSpy = _spy()
	var altar: BuriedSpot = _altar(spy)
	if altar == null: return
	altar.dig(true,1.0,false)
	var fake: Node3D = Node3D.new()
	add_child_autofree(fake)
	fake.global_position = altar.global_position
	altar.dig(true,1.0,false,fake)
	var player: Player = _player()
	player.health = 0.0
	altar.dig(true,1.0,false,player)
	player.health = player.max_health
	player.global_position = altar.global_position+Vector3.RIGHT*3.0
	altar.dig(true,1.0,false,player)
	assert_eq(altar.dirt_layers,3)
	assert_eq(spy.positions.size(),0)


func test_not_ready_refused_and_real_host_actorless_dig_is_supported() -> void:
	var spy: ActivationSpy = _spy()
	var altar: BuriedSpot = _altar(spy)
	if altar == null: return
	var player: Player = _player()
	spy.actor_ready = false
	altar.dig(true,1.0,false,player)
	assert_eq(altar.dirt_layers,3)
	spy.actor_ready = true
	var result: Dictionary = altar.dig(true,1.0,false)
	assert_true(bool(result.get("dug",false)),"Actual local Player shovel omits digger")
	assert_eq(altar.dirt_layers,2)
	assert_eq(spy.positions.size(),0)


func test_no_actorless_wake_endpoint_or_zero_layer_assignment_bypass() -> void:
	var spy: ActivationSpy = _spy()
	var altar: BuriedSpot = _altar(spy)
	if altar == null: return
	assert_false(altar.has_method(&"_rpc_request_wake"),"Do not inherit unsafe BossAltar wake RPC")
	var player: Player = _player()
	altar.dirt_layers = 0
	altar.dig(true,1.0,false,player)
	assert_eq(spy.positions.size(),0,"No spawn without accepted authoritative shovel work")


func test_real_base_timeout_rearms_three_layers_without_auto_spawn() -> void:
	var spy: ActivationSpy = _spy()
	var altar: BuriedSpot = _altar(spy)
	if altar == null: return
	var player: Player = _player()
	_dig_all(altar,player)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(spy.bosses.size(),1)
	if spy.bosses.is_empty(): return
	spy.bosses[0].call(&"_tick_boss_timer",300.0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(altar.dirt_layers,3)
	assert_eq(StringName(altar.call(&"get_activation_state")),&"BURIED")
	assert_eq(spy.positions.size(),1,"Timeout alone does not spawn again")
	_dig_all(altar,player)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(spy.positions.size(),2)


func test_persisted_defeat_and_same_map_death_prevent_reactivation() -> void:
	var spy: ActivationSpy = _spy()
	spy.defeated = true
	var altar: BuriedSpot = _altar(spy)
	if altar == null: return
	var player: Player = _player()
	_dig_all(altar,player)
	assert_eq(spy.positions.size(),0)
	assert_eq(StringName(altar.call(&"get_activation_state")),&"DEFEATED")
	var live_spy: ActivationSpy = _spy()
	var live: BuriedSpot = _altar(live_spy)
	if live == null: return
	_dig_all(live,player)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(live_spy.bosses.size(),1)
	if live_spy.bosses.is_empty(): return
	live_spy.bosses[0].take_damage(1000.0)
	await get_tree().process_frame
	await get_tree().process_frame
	_dig_all(live,player)
	assert_eq(live_spy.positions.size(),1,"Do not wait for persistent snapshot to prevent respawn")
	assert_eq(StringName(live.call(&"get_activation_state")),&"DEFEATED")


func test_spawn_failure_rearms_and_bad_offset_cannot_consume_work() -> void:
	var spy: ActivationSpy = _spy()
	spy.refuse_spawn = true
	var altar: BuriedSpot = _altar(spy)
	if altar == null: return
	var player: Player = _player()
	_dig_all(altar,player)
	assert_eq(altar.dirt_layers,3)
	assert_eq(StringName(altar.call(&"get_activation_state")),&"BURIED")
	spy.refuse_spawn = false
	altar.set("boss_offset",Vector3(3.01,0,0))
	altar.dig(true,1.0,false,player)
	assert_eq(altar.dirt_layers,3,"Keep boss within the agreed spawn footprint")
	assert_eq(spy.positions.size(),1)
