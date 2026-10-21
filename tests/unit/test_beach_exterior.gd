extends GutTest

func _fixture() -> Node3D:
	var path: String = "res://gameplay/environment/beach_dressing.gd"
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	var decor: Node3D = Node3D.new()
	decor.name = "Decor"
	root.add_child(decor)
	var props: Node3D = Node3D.new()
	props.name = "Props"
	decor.add_child(props)
	var banca: Node3D = Node3D.new()
	banca.name = "Banca"
	root.add_child(banca)
	var sea: MeshInstance3D = MeshInstance3D.new()
	sea.name = "Sea"
	var plane: PlaneMesh = PlaneMesh.new()
	plane.material = StandardMaterial3D.new()
	sea.mesh = plane
	root.add_child(sea)
	var script: Script = load(path) as Script
	var dressing: Node3D = script.new()
	dressing.name = "BeachDressing"
	root.add_child(dressing)
	return dressing


func _roots(dressing: Node) -> Array[Node3D]:
	var found: Array[Node3D] = []
	for node: Node in dressing.find_children("*", "Node3D", true, false):
		if node.is_in_group("praia_exterior_roots"):
			found.append(node as Node3D)
	return found


func test_external_palms_stay_on_land_and_strip_seams() -> void:
	var dressing: Node3D = _fixture()
	var roots: Array[Node3D] = _roots(dressing)
	assert_true(roots.size() >= 8 and roots.size() <= 10, "Grupos exteriores presentes, entre 8 e 10 palmeiras")
	for palm: Node3D in roots:
		assert_true(palm is PalmModel, "Reusar PalmModel")
		var p: Vector3 = palm.position
		assert_true(p.x >= -55.0 and p.x <= -38.0, "Lado terrestre exterior")
		assert_true(p.z >= -24.0 and p.z <= 24.0, "Preservar extremos costeiros")
		assert_almost_eq(p.z / 8.0, roundf(p.z / 8.0), 0.0001, "Raiz na costura do strip")
		assert_true(float(palm.get("height")) >= 5.0 and float(palm.get("height")) <= 7.0, "Copa na escala aprovada")


func test_every_root_is_supported_by_actual_coast_triangles() -> void:
	var dressing: Node3D = _fixture()
	var coast: MeshInstance3D = dressing.get_node("ContinuidadeCosta") as MeshInstance3D
	var faces: PackedVector3Array = coast.mesh.get_faces()
	var roots: Array[Node3D] = _roots(dressing)
	assert_gt(roots.size(), 0, "Sem aprovação vazia de apoio")
	for palm: Node3D in roots:
		var p: Vector3 = palm.position
		var expected: float = lerpf(BeachTerrain.height_at(-31.0, p.z) - 0.15, -1.0, (-31.0 - p.x) / 119.0) - 0.04
		assert_almost_eq(p.y, expected, 0.001, "Fórmula exata na costura")
		var hit: bool = false
		for i: int in range(0, faces.size(), 3):
			var point: Variant = Geometry3D.ray_intersects_triangle(Vector3(p.x, 100.0, p.z), Vector3.DOWN, faces[i], faces[i + 1], faces[i + 2])
			if point != null:
				hit = true
				assert_almost_eq(p.y, (point as Vector3).y - 0.04, 0.001, "Apoio na malha real, não extrapolação de BeachTerrain")
				break
		assert_true(hit, "Raiz tem triângulo de costa sob ela")


func test_external_group_has_no_collision_or_scene_owner() -> void:
	var dressing: Node3D = _fixture()
	var exterior: Node = dressing.get_node_or_null("PalmeiralExterior")
	assert_not_null(exterior, "Novo grupo externo isolado")
	if exterior != null:
		_check_cosmetic(exterior)


func _check_cosmetic(node: Node) -> void:
	assert_null(node.owner, "Cosmético não serializado")
	assert_false(node is CollisionObject3D or node is CollisionShape3D, "Nenhum colisor externo")
	for child: Node in node.get_children():
		_check_cosmetic(child)
