extends GutTest

func test_every_niche_step_has_visible_stone_matching_its_collision_top() -> void:
	var scene: Node3D = load("res://gameplay/quests/ruinas/ruinas_secrets.tscn").instantiate()
	add_child_autofree(scene)
	var tower: StaticBody3D = scene.get_node(^"Ground/NicheTower")
	var model: MeshInstance3D = tower.get_node_or_null(^"StoneSteps") as MeshInstance3D
	assert_not_null(model, "Three authored collision steps must not be invisible")
	if model == null: return
	assert_eq(model.mesh.get_surface_count(), 1)
	for name: String in ["Step1", "Step2", "Step3"]:
		var col: CollisionShape3D = tower.get_node(NodePath(name))
		var shape: BoxShape3D = col.shape
		var expected: Vector3 = col.position + Vector3.UP * shape.size.y * 0.5
		var highest: float = -INF
		var faces: PackedVector3Array = model.mesh.get_faces()
		for i: int in range(0, faces.size(), 3):
			var hit: Variant = Geometry3D.segment_intersects_triangle(expected + Vector3.UP * 3, expected - Vector3.UP * 3, faces[i], faces[i+1], faces[i+2])
			if hit != null: highest = maxf(highest, (hit as Vector3).y)
		assert_almost_eq(highest, expected.y, 0.001, name + " visible top equals collision")
	assert_almost_eq(model.mesh.get_aabb().position.y, 0.0, 0.001, "Stone has a base, not floating slabs")
