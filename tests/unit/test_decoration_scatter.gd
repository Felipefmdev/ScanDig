extends GutTest

## Decoração espalhada (estudo How to Fish): determinística, sem colisão, uma MultiMesh por tipo.

const SCATTER: Script = preload("res://gameplay/environment/decoration_scatter.gd")


func _ground() -> void:
	var g: StaticBody3D = StaticBody3D.new()
	var col: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	col.shape = box
	g.add_child(col)
	add_child_autofree(g)
	g.global_position = Vector3(0, -0.5, 0)


func _scatter(theme_name: String, seed_v: int) -> Node3D:
	var s: Node3D = SCATTER.new()
	s.set("theme", theme_name)
	s.set("seed_value", seed_v)
	s.set("count", 120)
	add_child_autofree(s)
	return s


func test_every_theme_builds_multimeshes_without_collision() -> void:
	_ground()
	await get_tree().physics_frame
	for t: String in ["praia", "campo", "ruinas", "geleira", "cratera"]:
		var s: Node3D = _scatter(t, 7)
		var placed: int = s.call("build")
		assert_gt(placed, 60, "%s espalhou props" % t)
		var mms: Array[Node] = s.find_children("*", "MultiMeshInstance3D", true, false)
		assert_gt(mms.size(), 2, "%s: um MultiMesh por tipo" % t)
		assert_eq(s.find_children("*", "CollisionShape3D", true, false).size(), 0, "sem colisão")


func test_same_seed_same_layout() -> void:
	_ground()
	await get_tree().physics_frame
	var a: Node3D = _scatter("campo", 42)
	var b: Node3D = _scatter("campo", 42)
	assert_eq(a.call("build"), b.call("build"), "mesma semente, mesma quantidade (todos os peers iguais)")


func test_open_side_skips_border() -> void:
	_ground()
	await get_tree().physics_frame
	var closed: Node3D = _scatter("praia", 3)
	var open: Node3D = _scatter("praia", 3)
	open.set("open_sides", PackedInt32Array([3]))
	assert_lt(open.call("build"), closed.call("build"), "lado do mar sem rochas")
