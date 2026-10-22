extends GutTest

const PROD: String = "res://gameplay/environment/glacier_structure.gd"
var cabin: Node3D


func before_each() -> void:
	var script: Script = load(PROD)
	cabin = script.new()
	cabin.set("kind", 4)
	cabin.rotation.y = deg_to_rad(30.0)
	add_child_autofree(cabin)
	await wait_frames(3)


func test_normal_player_capsule_has_continuous_entry_and_interior_clearance() -> void:
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	var blocked: int = 0
	for z: float in [-2.8, -2.2, -1.85, -1.5, -0.9, -0.4, 0.1]:
		var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		q.shape = cap
		q.transform = Transform3D(Basis.IDENTITY, cabin.to_global(Vector3(0, 1.03, z)))
		q.collision_mask = 1
		blocked += cabin.get_world_3d().direct_space_state.intersect_shape(q).size()
	assert_eq(blocked, 0, "Standard player capsule passes real opening and enters usable interior")


func test_door_view_reaches_bjorn_and_hearth_without_wall_occlusion() -> void:
	var camera: Vector3 = cabin.to_global(Vector3(0, 1.6, -2.8))
	var bjorn_focus: Vector3 = cabin.to_global(Vector3(0.683, 1.1, -0.183))
	var hearth_focus: Vector3 = cabin.to_global(Vector3(-0.85, 0.6, 1.0))
	for point: Vector3 in [bjorn_focus, hearth_focus]:
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(camera, point, 1)
		var hit: Dictionary = cabin.get_world_3d().direct_space_state.intersect_ray(q)
		assert_true(hit.is_empty(), "Entry camera has physical LOS to interior interaction, not a painted solid door")


func test_walls_still_enclose_sides_and_back_and_floor_supports_interior() -> void:
	for end: Vector3 in [Vector3(3, 1.2, 0), Vector3(-3, 1.2, 0), Vector3(0, 1.2, 3)]:
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(cabin.to_global(Vector3(0, 1.2, 0)), cabin.to_global(end), 1)
		var hit: Dictionary = cabin.get_world_3d().direct_space_state.intersect_ray(q)
		assert_false(hit.is_empty(), "Opening must not remove whole cabin collision")
	var floor_query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(cabin.to_global(Vector3(0.5, 0.5, 0.3)), cabin.to_global(Vector3(0.5, -0.2, 0.3)), 1)
	var floor_hit: Dictionary = cabin.get_world_3d().direct_space_state.intersect_ray(floor_query)
	assert_false(floor_hit.is_empty(), "Interior floor supports feet")
	if not floor_hit.is_empty():
		assert_lt(absf(cabin.to_local(floor_hit.position).y), 0.12, "Floor is near ground rather than former solid body top")


func test_normal_capsule_can_cross_door_without_teleport_or_jump() -> void:
	var body: CharacterBody3D = CharacterBody3D.new()
	var col: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	col.shape = cap
	col.position.y = 0.9
	body.add_child(col)
	body.collision_layer = 1
	body.collision_mask = 1
	body.position = cabin.to_global(Vector3(0, 0.12, -2.8))
	add_child_autofree(body)
	await wait_frames(2)
	var collisions: int = 0
	for step: int in range(20):
		if body.move_and_collide(cabin.global_basis * Vector3(0, 0, 0.15)) != null:
			collisions += 1
	assert_eq(collisions, 0, "Walking capsule traverses entry at ground height")
	assert_gt(cabin.to_local(body.global_position).z, -0.1)
