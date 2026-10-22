extends GutTest
## Physical RED first. Do not substitute manually-triggered interactions for access.

const PROD: String = "res://gameplay/environment/glacier_structure.gd"
var igloo: Node3D


func before_each() -> void:
	var script: Script = load(PROD)
	igloo = script.new()
	igloo.set("kind", 5)
	igloo.set("size", Vector3(2.6, 2.0, 2.6))
	igloo.rotation.y = deg_to_rad(-45.0)
	add_child_autofree(igloo)
	await wait_frames(3)


func test_standing_player_has_continuous_tunnel_and_center_clearance() -> void:
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	var blocked: int = 0
	for z: float in [-4.2, -3.7, -3.0, -2.5, -2.0, -1.5, -0.8, 0.0]:
		var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		q.shape = capsule
		q.transform = Transform3D(Basis.IDENTITY, igloo.to_global(Vector3(0, 1.03, z)))
		q.collision_mask = 1
		blocked += igloo.get_world_3d().direct_space_state.intersect_shape(q).size()
	assert_eq(blocked, 0, "Player standing capsule fits actual tunnel and interior without crouch")


func test_door_line_of_sight_reaches_existing_center_relic() -> void:
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(igloo.to_global(Vector3(0, 1.6, -4.2)), igloo.to_global(Vector3(0, 0.2, 0)), 1)
	var hit: Dictionary = igloo.get_world_3d().direct_space_state.intersect_ray(q)
	assert_true(hit.is_empty(), "Looking at relic through entry must not hit a solid sphere or tunnel cap")


func test_player_walks_from_entrance_to_relic_interaction_range() -> void:
	var player: CharacterBody3D = CharacterBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	shape.shape = cap
	shape.position.y = 0.9
	player.add_child(shape)
	player.collision_layer = 1
	player.collision_mask = 1
	player.position = igloo.to_global(Vector3(0, 0.12, -4.2))
	add_child_autofree(player)
	await wait_frames(2)
	for step: int in range(25):
		player.move_and_collide(igloo.global_basis * Vector3(0, 0, 0.16))
	assert_gt(igloo.to_local(player.global_position).z, -0.5, "Physical walk reaches center area")
	assert_lt(player.global_position.distance_to(igloo.to_global(Vector3(0, 0.2, 0))), 2.5, "Existing relic interact range is reachable from outside structure")


func test_shell_keeps_side_back_collision_and_dome_snow_profile() -> void:
	for end: Vector3 in [Vector3(3.1, 1.0, 0), Vector3(-3.1, 1.0, 0), Vector3(0, 1.0, 3.1)]:
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(igloo.to_global(Vector3(0, 1.0, 0)), igloo.to_global(end), 1)
		assert_false(igloo.get_world_3d().direct_space_state.intersect_ray(q).is_empty(), "Actual shell sides/back remain, not collision disabled")
	var model: MeshInstance3D = igloo.get_node("Mesh")
	assert_almost_eq(model.mesh.get_aabb().end.y, 2.6, 0.12, "Snow dome remains at existing scale")
	assert_true(model.mesh.get_aabb().size.x >= 4.9 and model.mesh.get_aabb().size.x <= 5.5, "Dome footprint preserved")
