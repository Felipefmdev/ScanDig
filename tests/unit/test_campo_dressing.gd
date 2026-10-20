extends GutTest

const DRESSING: Script = preload("res://gameplay/environment/campo_dressing.gd")


func test_routes_and_objectives_have_clear_cosmetics() -> void:
	var dressing: Node3D = DRESSING.new()
	autofree(dressing)
	for p: Vector2 in [Vector2(-12.5, -16.9), Vector2(-23.5, -17.2), Vector2(20.5, -3.3), Vector2(-4.9, -5), Vector2(6.4, -15), Vector2(12, -16), Vector2(-15, 19), Vector2(5, -5)]:
		assert_true(dressing.is_clear(p), "Zona de uso livre: %s" % p)
	assert_false(dressing.is_clear(Vector2(25, 25)), "Vegetação distante preservada")


func test_filter_removes_only_cosmetics_inside_corridor() -> void:
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	var dressing: Node3D = DRESSING.new()
	root.add_child(dressing)
	var poses: Array[Transform3D] = [Transform3D(Basis.IDENTITY, Vector3(5, 0, -5)), Transform3D(Basis.IDENTITY, Vector3(25, 0, 25))]
	var kept: Array[Transform3D] = dressing.kept_poses(poses, Transform3D.IDENTITY)
	assert_eq(kept.size(), 1)
	assert_eq(kept[0].origin, Vector3(25, 0, 25))
	for child: Node in dressing.get_children():
		assert_false(child is CollisionObject3D, "Dressing não cria colisão")
	await wait_frames(5)
