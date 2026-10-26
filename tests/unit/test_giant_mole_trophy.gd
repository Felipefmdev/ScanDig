extends GutTest

## #186: physical commercial trophy, independent of the derived passage credential.
## Real production scene, lethal take_damage and natural death frames; no direct
## _on_died/_process_dying calls, clock/state edits or manual reward/report calls.
const BOSS_SCENE: PackedScene = preload("res://gameplay/enemies/boss/giant_mole.tscn")
const TROPHY_ID: String = "garra_toupeira"

var arena: Node3D
var pickups: PickupsRoot
var boss: GiantMole
var _state_before: Dictionary = {}
var _defeats: Array[StringName] = []


func before_each() -> void:
	_state_before = GameState.instance.get_snapshot().duplicate(true)
	_defeats.clear()
	arena = Node3D.new()
	add_child_autofree(arena)
	# Keep the real falling pickup available throughout the death/cleanup window.
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(40.0, 1.0, 40.0)
	floor_shape.shape = box
	floor_shape.position.y = -0.5
	floor_body.add_child(floor_shape)
	arena.add_child(floor_body)
	pickups = PickupsRoot.new()
	pickups.name = "Pickups"
	arena.add_child(pickups)
	boss = BOSS_SCENE.instantiate() as GiantMole
	arena.add_child(boss)
	boss.boss_defeated.connect(_record_defeat)
	boss.wake_immediately()


func after_each() -> void:
	# The actual boss reports progression/creature state. Restore it for other tests;
	# do not replace the reporter, seed a credential or call save_game in this test.
	GameState.instance.load_snapshot(_state_before)


func _record_defeat(id: StringName) -> void:
	_defeats.append(id)


func _trophies() -> Array[ItemPickup]:
	var result: Array[ItemPickup] = []
	for child: Node in pickups.get_children():
		var pickup: ItemPickup = child as ItemPickup
		if pickup != null and pickup.carried != null and pickup.carried.item != null:
			if String(pickup.carried.item.id) == TROPHY_ID:
				result.append(pickup)
	return result


func test_real_death_drops_one_commercial_claw_and_never_repeats() -> void:
	await wait_frames(3)
	assert_true(boss.has_simulation_authority(), "Production boss simulates on host/offline")
	assert_eq(_trophies().size(), 0, "No claw is granted merely by spawning/waking")
	boss.take_damage(1.0)
	assert_true(boss.is_alive(), "Nonlethal real hit is a negative reward case")
	assert_eq(_trophies().size(), 0, "A wounded boss has not produced a trophy")
	watch_signals(boss)
	boss.take_damage(100000.0)
	assert_false(boss.is_alive(), "Lethal damage must enter actual death lifecycle")
	assert_signal_emit_count(boss, "died", 1, "Real EnemyBase death, not a fabricated reward")
	await wait_for_signal(boss.boss_defeated, 4.0)
	await wait_frames(2)
	assert_eq(_defeats.size(), 1, "Natural death frames report one defeat")
	if not _defeats.is_empty():
		assert_eq(_defeats[0], &"giant_mole")
	var dropped: Array[ItemPickup] = _trophies()
	assert_eq(dropped.size(), 1, "Real death must spawn exactly one physical garra_toupeira")
	if dropped.size() == 1:
		assert_true(dropped[0].is_inside_tree(), "Reward exists in the live pickup world")
		assert_true(dropped[0].get_parent() == pickups, "Uses the normal PickupsRoot path")
		assert_eq(dropped[0].carried.item.resource_path, "res://items/catalog/garra_toupeira.tres")
		assert_eq(dropped[0].carried.final_value, dropped[0].carried.item.base_value, "Commercial trophy retains catalogue value")
	# Repeated real hits during DYING must not restart death or grant another claw.
	if is_instance_valid(boss) and not boss.is_queued_for_deletion():
		for hit: int in range(3):
			boss.take_damage(100000.0)
	await wait_seconds(1.6)
	assert_eq(_defeats.size(), 1, "Death/cleanup does not report another defeat")
	assert_eq(_trophies().size(), 1, "Repeated lethal requests and natural cleanup keep one claw")
	assert_false(is_instance_valid(boss), "Real death animation eventually frees the boss")
