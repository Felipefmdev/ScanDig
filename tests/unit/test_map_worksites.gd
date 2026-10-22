extends GutTest

const SCATTER: Script = preload("res://gameplay/environment/decoration_scatter.gd")

func _scatter(theme: String) -> Node3D:
	var scatter: Node3D = SCATTER.new()
	scatter.set("theme", theme)
	scatter.set("count", 0)
	add_child_autofree(scatter)
	return scatter

func test_all_five_maps_receive_one_cosmetic_worksite_batch() -> void:
	for theme: String in ["praia", "campo", "ruinas", "geleira", "cratera"]:
		var scatter: Node3D = _scatter(theme)
		for i: int in 4:
			await get_tree().physics_frame
		var group: Node = scatter.get_node_or_null(^"MapWorksites")
		assert_not_null(group, "%s: composição interna integra o mapa em runtime" % theme)
		if group == null:
			continue
		var meshes: Array[Node] = group.find_children("*", "MeshInstance3D", true, false)
		assert_eq(meshes.size(), 1, "Uma malha por mapa, sem draw call por objeto")
		for mesh_node: Node in meshes:
			var mesh: MeshInstance3D = mesh_node as MeshInstance3D
			assert_not_null(mesh.mesh)
			assert_eq(mesh.mesh.get_surface_count(), 1)
			assert_gt(mesh.mesh.get_faces().size(), 0)
			assert_lte(mesh.mesh.get_faces().size(), 18000)
			assert_eq(mesh.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
			assert_true(mesh.material_override is ShaderMaterial)
		for child: Node in group.find_children("*", "", true, false):
			assert_null(child.owner, "Nada serializado incidentalmente na cena")
			assert_false(child is CollisionObject3D or child is CollisionShape3D or child is Area3D)

func test_rebuild_replaces_worksite_without_duplicate_or_rng_side_effect() -> void:
	var scatter: Node3D = _scatter("praia")
	for i: int in 4:
		await get_tree().physics_frame
	var group: Node = scatter.get_node_or_null(^"MapWorksites")
	assert_not_null(group)
	if group == null:
		return
	var before: MeshInstance3D = group.get_child(0) as MeshInstance3D
	var faces: PackedVector3Array = before.mesh.get_faces()
	seed(161)
	var expected: int = randi()
	seed(161)
	scatter.call("build")
	assert_eq(randi(), expected, "Geometria cosmética não altera RNG global")
	await get_tree().process_frame
	group = scatter.get_node_or_null(^"MapWorksites")
	assert_not_null(group)
	if group != null:
		assert_eq(group.get_child_count(), 1)
		assert_eq((group.get_child(0) as MeshInstance3D).mesh.get_faces(), faces)
	assert_eq(scatter.find_children("MapWorksites", "", false, false).size(), 1)
