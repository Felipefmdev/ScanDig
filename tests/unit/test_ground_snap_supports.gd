extends GutTest

const PROD: String = "res://gameplay/environment/ground_snap.gd"
const RUINS: Script = preload("res://gameplay/environment/ruins_terrain.gd")
const GLACIER: Script = preload("res://gameplay/environment/glacier_terrain.gd")
const CRATER: Script = preload("res://gameplay/environment/crater_terrain.gd")


func test_explicit_supports_follow_settled_support_and_are_idempotent() -> void:
	var snap: Node3D = _snap(2)
	var tower: StaticBody3D = StaticBody3D.new()
	tower.name = "Tower"
	tower.position = Vector3(10, 0, 13)
	snap.add_child(tower)
	var step: CollisionShape3D = CollisionShape3D.new()
	step.name = "Step3"
	step.position = Vector3(1.2, 1.5, 0)
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(1.2, 0.6, 1.2)
	step.shape = shape
	tower.add_child(step)
	var chalice: Node3D = _child(snap, "Chalice", Vector3(11.2, 1.8, 13))
	var altar: Node3D = _child(snap, "Altar", Vector3(0, 0.9, -16))
	var dagger: Node3D = _child(snap, "Dagger", Vector3(0, 1.5, -16))
	_configure(snap, {"Chalice": 0.3, "Dagger": 0.61}, {"Chalice": NodePath("Tower/Step3"), "Dagger": NodePath("Altar")})
	add_child_autofree(snap)
	await wait_frames(2)
	assert_almost_eq(chalice.global_position.y, step.global_position.y + shape.size.y * 0.5, 0.001, "Chalice rests on step rather than terrain below it")
	assert_almost_eq(dagger.global_position.y, altar.global_position.y + 0.61, 0.001, "Dagger rests on actual altar table")
	var first: Vector3 = chalice.global_position
	var first_dagger: Vector3 = dagger.global_position
	for repeat: int in range(3):
		snap.call("snap")
	assert_eq(chalice.global_position, first, "Repeated snap cannot accumulate authored/support Y")
	assert_eq(dagger.global_position, first_dagger)
	# Altered support transform must be settled before dependent children next time.
	tower.position.x += 1.0
	snap.call("snap")
	assert_almost_eq(chalice.global_position.y, step.global_position.y + 0.3, 0.001)


func test_explicit_offset_does_not_change_regular_crypt_lake_or_authored_y() -> void:
	for config: Array in [[2, RUINS, Vector3(-22, -1.3, -6)], [3, GLACIER, Vector3(14, -0.65, -8)], [4, CRATER, Vector3(-12.5, 0, 8.5)]]:
		var snap: Node3D = _snap(config[0])
		var ordinary: Node3D = _child(snap, "Ordinary", config[2])
		var raised: Node3D = _child(snap, "Raised", Vector3(4, 2.5, -16))
		_configure(snap, {"Raised": 2.5}, {})
		add_child_autofree(snap)
		await wait_frames(1)
		var ground: float = config[1].call("height_at", ordinary.position.x, ordinary.position.z)
		assert_almost_eq(ordinary.position.y, ground, 0.001, "Unconfigured authored Y is not added to ground")
		var raised_ground: float = config[1].call("height_at", 4.0, -16.0)
		assert_almost_eq(raised.position.y, raised_ground + 2.5, 0.001, "Only explicitly declared suspended piece has an offset")
		var previous: Vector3 = raised.position
		snap.call("snap")
		assert_eq(raised.position, previous)


func test_outside_tree_keeps_scene_transforms_intact() -> void:
	var snap: Node3D = _snap(2)
	var n: Node3D = _child(snap, "Raised", Vector3(5, 0.3, -7))
	n.rotation.y = 0.7
	_configure(snap, {"Raised": 2.5}, {})
	var authored: Transform3D = n.transform
	snap.call("snap")
	assert_eq(n.transform, authored, "No scene transform mutation outside tree/editor workflow")
	snap.free()


func test_orb_height_matches_real_pillar_support_and_stalactite_remains_suspended() -> void:
	var map: Node3D = (load("res://world/map_cratera.tscn") as PackedScene).instantiate()
	var ground: Node3D = map.get_node("CrateraSecrets/Ground")
	add_child_autofree(map)
	await wait_frames(4)
	var orb: Node3D = ground.get_node("OrbRelic")
	var terrain_y: float = CRATER.height_at(orb.global_position.x, orb.global_position.z)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(orb.global_position.x, terrain_y + 8, orb.global_position.z), Vector3(orb.global_position.x, terrain_y, orb.global_position.z), 1)
	var hit: Dictionary = map.get_world_3d().direct_space_state.intersect_ray(query)
	assert_false(hit.is_empty(), "Actual pillar collider exists under relic")
	if not hit.is_empty():
		assert_true(str((hit.collider as Node).get_parent().name).begins_with("CraterPillar"), "Support must be the intended pillar, not arbitrary terrain")
		assert_almost_eq(orb.global_position.y, (hit.position as Vector3).y, 0.061, "Relic rests at pillar cap, not inside it")
	assert_gt(orb.global_position.y - terrain_y, 5.7)
	var snap: Node3D = _snap(3)
	var hanging: Node3D = _child(snap, "Stalactite", Vector3(4, 2.5, -16))
	_configure(snap, {"Stalactite": 2.5}, {})
	add_child_autofree(snap)
	assert_almost_eq(hanging.position.y, GLACIER.height_at(4, -16) + 2.5, 0.001)


func _configure(snap: Node3D, offsets: Dictionary, supports: Dictionary) -> void:
	snap.set("height_offsets", offsets)
	snap.set("support_paths", supports)


func _snap(terrain: int) -> Node3D:
	var snap: Node3D = _script().new()
	snap.set("terrain", terrain)
	snap.set("sink", 0.0)
	return snap


func _script() -> Script:
	return load(PROD)


func _child(parent: Node, child_name: String, pos: Vector3) -> Node3D:
	var n: Node3D = Node3D.new()
	n.name = child_name
	n.position = pos
	parent.add_child(n)
	return n
