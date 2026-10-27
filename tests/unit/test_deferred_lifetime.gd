extends GutTest

## Regressões de ciclo de vida: liberação antes do callback e onda em pai transladado.
## Exercita A11y, Player e timers reais; o runner também deve verificar erros nativos.
const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/player.tscn")
const EPS: float = 0.0001

var _world: Node3D = null
var _case: String = "setup"


func before_each() -> void:
	_world = Node3D.new()
	_world.name = "Lifecycle186Probe"
	add_child(_world)
	assert_true(_world.is_inside_tree(), "real tree required")
	await get_tree().process_frame


func after_each() -> void:
	print("LIFECYCLE186 ", _case, " cleanup_begin")
	var world_ref: WeakRef = weakref(_world) if is_instance_valid(_world) else null
	if is_instance_valid(_world):
		_world.free()
	_world = null
	if world_ref != null:
		assert_null(world_ref.get_ref(), "fixture tree freed manually once")
	await get_tree().process_frame
	await get_tree().process_frame
	print("LIFECYCLE186 ", _case, " cleanup_end")


func _real_a11y_available() -> bool:
	var a11y: A11y = A11y.instance
	assert_not_null(a11y, "production CoreA11y autoload required")
	if a11y == null:
		return false
	assert_true(get_tree().node_added.is_connected(a11y._on_node_added), "real listener must be connected")
	return get_tree().node_added.is_connected(a11y._on_node_added)


func test_a11y_enemy_freed_before_deferred_flush() -> void:
	_case = "a11y_immediate_free"
	if not _real_a11y_available():
		return
	print("LIFECYCLE186 ", _case, " add_begin")
	var enemy: EnemyBase = EnemyBase.new()
	var enemy_ref: WeakRef = weakref(enemy)
	_world.add_child(enemy)
	enemy.set_physics_process(false)
	assert_true(enemy.is_inside_tree())
	assert_true(enemy.is_in_group(EnemyBase.GROUP))
	# Deliberately no await between add and free: production node_added queues A11y.
	enemy.free()
	assert_null(enemy_ref.get_ref(), "enemy gone before deferred callback")
	print("LIFECYCLE186 ", _case, " freed_before_flush")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_null(enemy_ref.get_ref(), "no resurrection by observer")
	assert_eq(_world.get_child_count(), 0, "no enemy or replacement remains")
	assert_true(is_instance_valid(A11y.instance), "autoload survives")
	print("LIFECYCLE186 ", _case, " flush_end")


func test_a11y_control_enemy_survives_deferred_flush() -> void:
	_case = "a11y_survives_flush"
	if not _real_a11y_available():
		return
	print("LIFECYCLE186 ", _case, " add_begin")
	var enemy: EnemyBase = EnemyBase.new()
	var enemy_ref: WeakRef = weakref(enemy)
	_world.add_child(enemy)
	enemy.set_physics_process(false)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(is_instance_valid(enemy), "control survives queued observer")
	assert_true(enemy.is_inside_tree())
	print("LIFECYCLE186 ", _case, " flush_end_before_free")
	enemy.free()
	assert_null(enemy_ref.get_ref())
	await get_tree().process_frame
	assert_eq(_world.get_child_count(), 0)
	print("LIFECYCLE186 ", _case, " free_end")


func test_real_player_pulse_places_wave_at_world_origin_under_translated_parent() -> void:
	_case = "real_player_pulse"
	# No target is needed: the real attack always creates its wave. Avoid mixing
	# A11y enemy teardown, damage materials, pickups, or network state into this case.
	assert_eq(get_tree().get_nodes_in_group(EnemyBase.GROUP).size(), 0, "run isolated: no foreign enemy")
	assert_eq(get_tree().get_nodes_in_group(ItemPickup.GROUP).size(), 0, "run isolated: no foreign pickup")
	if not get_tree().get_nodes_in_group(EnemyBase.GROUP).is_empty() or not get_tree().get_nodes_in_group(ItemPickup.GROUP).is_empty():
		return
	_world.position = Vector3(17.0, 4.0, -11.0)
	var player: Player = PLAYER_SCENE.instantiate() as Player
	_world.add_child(player)
	player.set_physics_process(false)
	player.set_process_input(false)
	player.set_process_unhandled_input(false)
	player.position = Vector3(2.0, 1.0, 3.0)
	await get_tree().process_frame
	assert_not_null(player.camera, "real Player ready must create/bind camera")
	if player.camera == null:
		return
	var forward: Vector3 = -player.camera.global_basis.z
	var expected_origin: Vector3 = player.camera.global_position + forward * 0.5
	var previous_ids: Array[int] = []
	for child: Node in _world.get_children():
		previous_ids.append(child.get_instance_id())
	print("LIFECYCLE186 ", _case, " attack_begin expected=", expected_origin)
	var affected: int = player.fire_magnetic_pulse()
	assert_eq(affected, 0, "empty arena: attack executes without forged targets")
	var rings: Array[MeshInstance3D] = []
	for child: Node in _world.get_children():
		if not previous_ids.has(child.get_instance_id()) and child is MeshInstance3D:
			var mesh_node: MeshInstance3D = child as MeshInstance3D
			if mesh_node.mesh is TorusMesh:
				rings.append(mesh_node)
	assert_eq(rings.size(), 1, "real attack creates exactly one torus wave")
	if rings.size() != 1:
		return
	var ring: MeshInstance3D = rings[0]
	var ring_ref: WeakRef = weakref(ring)
	assert_true(ring.is_inside_tree())
	assert_eq(ring.get_parent(), _world)
	print("LIFECYCLE186 ", _case, " attack_end actual=", ring.global_position)
	assert_almost_eq(ring.global_position.x, expected_origin.x, EPS, "wave world X independent of parent translation")
	assert_almost_eq(ring.global_position.y, expected_origin.y, EPS, "wave world Y independent of parent translation")
	assert_almost_eq(ring.global_position.z, expected_origin.z, EPS, "wave world Z independent of parent translation")
	rings.clear()
	ring = null
	# Production wave lifetime is .35s. Real timer, no custom_step/time mutation.
	await get_tree().create_timer(0.65, true, false, true).timeout
	await get_tree().process_frame
	assert_null(ring_ref.get_ref(), "production tween removes its wave")
	assert_true(is_instance_valid(player), "attack cleanup preserves actor")
	print("LIFECYCLE186 ", _case, " lifetime_end")
