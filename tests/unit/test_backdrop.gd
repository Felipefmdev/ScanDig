extends GutTest

## Fundo distante (horizonte): silhuetas a 60-140 m, sem colisão nem owner; mar só na Praia.

const BACKDROP: Script = preload("res://gameplay/environment/backdrop.gd")


func _make(theme_name: String, seed_v: int = 3) -> Node3D:
	var b: Node3D = BACKDROP.new()
	b.set("theme", theme_name)
	b.set("seed_value", seed_v)
	add_child_autofree(b)
	return b


func test_every_theme_builds_far_silhouettes_without_collision() -> void:
	for t: String in ["praia", "campo", "ruinas", "geleira", "cratera"]:
		var b: Node3D = _make(t)
		var placed: int = b.call("build")
		assert_gt(placed, 4, "%s colocou silhuetas" % t)
		var hills: MeshInstance3D = b.get_node_or_null("Hills") as MeshInstance3D
		assert_not_null(hills, "%s tem Hills" % t)
		assert_eq(b.find_children("*", "CollisionObject3D", true, false).size(), 0, "sem colisão")
		assert_eq(b.find_children("*", "CollisionShape3D", true, false).size(), 0, "sem shapes")
		for c: Node in b.get_children():
			assert_null(c.owner, "%s: %s sem owner (#47)" % [t, c.name])
		var aabb: AABB = hills.mesh.get_aabb()
		var far: float = maxf(maxf(absf(aabb.position.x), absf(aabb.end.x)), maxf(absf(aabb.position.z), absf(aabb.end.z)))
		assert_lt(far, 140.0 + 40.0, "%s dentro do horizonte" % t)
		assert_gt(far, 60.0, "%s longe do centro" % t)
		assert_eq(b.get_node_or_null("Sea") != null, t == "praia", "%s: mar só na Praia" % t)


func test_silhouettes_keep_out_of_play_area() -> void:
	var b: Node3D = _make("campo")
	var hills: MeshInstance3D = b.get_node("Hills") as MeshInstance3D
	var arrays: Array = hills.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var min_r: float = INF
	for v: Vector3 in verts:
		min_r = minf(min_r, Vector2(v.x, v.z).length())
	assert_gt(min_r, 40.0, "nenhum vértice invade a área de jogo")


func test_praia_land_hills_stay_off_sea_side() -> void:
	var b: Node3D = _make("praia")
	var verts: PackedVector3Array = (b.get_node("Hills") as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var max_x: float = -INF
	for v: Vector3 in verts:
		max_x = maxf(max_x, v.x)
	assert_lt(max_x, 40.0, "colinas da Praia longe do mar (+X)")
	var sea: MeshInstance3D = b.get_node("Sea") as MeshInstance3D
	assert_gt(sea.mesh.get_aabb().end.x, 300.0, "mar até ao horizonte")


func test_same_seed_same_layout_and_rebuild_is_idempotent() -> void:
	var a: Node3D = _make("geleira", 9)
	var b: Node3D = _make("geleira", 9)
	var ma: Mesh = (a.get_node("Hills") as MeshInstance3D).mesh
	var mb: Mesh = (b.get_node("Hills") as MeshInstance3D).mesh
	assert_eq(ma.get_aabb(), mb.get_aabb(), "determinístico")
	a.call("build")
	assert_eq(a.get_child_count(), 1, "rebuild não duplica filhos")
