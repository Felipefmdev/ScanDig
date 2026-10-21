extends Node3D

## #152: caminhos e clareiras locais, sem alterar terreno, colisores ou objetivos.
var routes: Array[PackedVector2Array] = [
	PackedVector2Array([Vector2(3.5, 3.5), Vector2(-2, -3), Vector2(-8, -8.5), Vector2(-11, -11)]),
	PackedVector2Array([Vector2(3.5, 3.5), Vector2(5, -5), Vector2(6, -11.5)]),
	PackedVector2Array([Vector2(5, -5), Vector2(10, -6), Vector2(24, -6)]),
	PackedVector2Array([Vector2(0, 1), Vector2(-2.5, 6.5)]),
]
const CLEARINGS: Array[Vector3] = [
	Vector3(0, 0, 3), Vector3(3.5, 3.5, 4.5), Vector3(7.5, 1, 3.5),
	Vector3(-2.5, 6.5, 2.5), Vector3(-6, -5, 2.7), Vector3(-4.9, -5, 2),
	Vector3(20.5, -4.5, 3.5), Vector3(-21.4, 8.5, 2.5), Vector3(-15, 19, 3),
	Vector3(-18, -18, 8.5), Vector3(5.2, -15, 3), Vector3(17.5, -17, 5),
]


func _ready() -> void:
	_build_paths()
	_build_exterior()
	# Scatter termina após dois frames de física. Revalidar após cada espera.
	for i: int in 3:
		await get_tree().physics_frame
		if not is_inside_tree():
			return
	_clear_cosmetics()


func is_clear(p: Vector2) -> bool:
	for zone: Vector3 in CLEARINGS:
		if p.distance_to(Vector2(zone.x, zone.y)) < zone.z:
			return true
	# Preserva a visão da torre para o desenho da lavoura.
	if p.distance_to(Geometry2D.get_closest_point_to_segment(p, Vector2(6.4, -15), Vector2(17.5, -17))) < 1.5:
		return true
	for route: PackedVector2Array in routes:
		for i: int in route.size() - 1:
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p, route[i], route[i + 1])) < 1.8:
				return true
	return false


func _clear_cosmetics() -> void:
	var root: Node = get_parent()
	var grass: MultiMeshInstance3D = root.get_node_or_null("Terrain/Grass") as MultiMeshInstance3D
	if grass != null:
		_filter(grass)
	var scatter: Node = root.get_node_or_null("DecorationScatter")
	if scatter != null:
		for child: Node in scatter.get_children():
			if child is MultiMeshInstance3D and String(child.name).begins_with("Deco_") and not String(child.name).begins_with("Deco_border"):
				_filter(child as MultiMeshInstance3D)


func _filter(node: MultiMeshInstance3D) -> void:
	if node.multimesh == null:
		return
	var source: MultiMesh = node.multimesh
	var poses: Array[Transform3D] = []
	for i: int in source.instance_count:
		poses.append(source.get_instance_transform(i))
	var kept: Array[Transform3D] = kept_poses(poses, node.global_transform)
	var result: MultiMesh = MultiMesh.new()
	result.transform_format = MultiMesh.TRANSFORM_3D
	result.mesh = source.mesh
	result.instance_count = kept.size()
	for i: int in kept.size():
		result.set_instance_transform(i, kept[i])
	node.multimesh = result


func kept_poses(poses: Array[Transform3D], frame: Transform3D) -> Array[Transform3D]:
	var kept: Array[Transform3D] = []
	for pose: Transform3D in poses:
		var p: Vector3 = frame * pose.origin
		if not is_clear(Vector2(p.x, p.z)):
			kept.append(pose)
	return kept


func _build_paths() -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Grelha fina acompanha o relevo; só pinta os corredores, nunca a arena ou segredos.
	for x: int in range(-24, 51):
		for z: int in range(-26, 17):
			var p: Vector2 = Vector2(float(x) * 0.5, float(z) * 0.5)
			var on_route: bool = false
			for route: PackedVector2Array in routes:
				for i: int in route.size() - 1:
					if p.distance_to(Geometry2D.get_closest_point_to_segment(p, route[i], route[i + 1])) < 1.25:
						on_route = true
			if not on_route:
				continue
			var a: Vector3 = _ground(p)
			var b: Vector3 = _ground(p + Vector2(0.5, 0))
			var c: Vector3 = _ground(p + Vector2(0.5, 0.5))
			var d: Vector3 = _ground(p + Vector2(0, 0.5))
			for v: Vector3 in [a, d, c, a, c, b]:
				st.set_color(Color("#927447") if (x + z) % 3 == 0 else Color("#a38653"))
				st.add_vertex(v)
	st.generate_normals()
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.name = "CaminhosTerra"
	mesh.mesh = st.commit()
	mesh.material_override = ToonKit.vertex_material(false)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)


func _ground(p: Vector2) -> Vector3:
	return Vector3(p.x, FieldTerrain.height_at(p.x, p.y) + 0.045, p.y)


## #157: composição externa sobre o relevo existente; só cosméticos sem owner/colisão.
func _build_exterior() -> void:
	var grove: Node3D = Node3D.new()
	grove.name = "CampoExterior"
	add_child(grove)
	var trees: Array[Vector3] = [
		Vector3(-39, 10, 4.2), Vector3(-42, 15, 5.0), Vector3(-37, 19, 3.6),
		Vector3(-41, 24, 4.6), Vector3(-35, 26, 3.3), Vector3(-43, 29, 4.1),
		Vector3(-14, 39, 3.8), Vector3(-9, 43, 4.7), Vector3(-5, 37, 3.4),
		Vector3(5, 41, 4.5), Vector3(10, 38, 3.7), Vector3(15, 43, 4.9),
		Vector3(20, 39, 3.5),
	]
	for i: int in trees.size():
		var spec: Vector3 = trees[i]
		var tree: FieldTreeModel = FieldTreeModel.new()
		tree.name = "OliveiraExterior%d" % i
		tree.height = spec.z
		tree.canopy_radius = 1.6 + float(i % 3) * 0.25
		tree.leaf_dark = Color("#465536")
		tree.leaf_light = Color("#899653")
		tree.seed_value = 157 + i * 31
		_exterior_root(grove, tree, Vector2(spec.x, spec.y))
	# Moitas baixas escalonam o prado, sem fechar os intervalos entre bosques.
	for i: int in 9:
		var bush: FieldTreeModel = FieldTreeModel.new()
		bush.name = "MoitaExterior%d" % i
		bush.height = 0.18
		bush.canopy_radius = 0.48 + float(i % 3) * 0.12
		bush.blobs = 3
		bush.leaf_dark = Color("#53613c")
		bush.leaf_light = Color("#8c9755")
		bush.seed_value = 1157 + i
		var p: Vector2 = Vector2(-34.0 - float(i % 3) * 2.0, 5.0 + float(i) * 3.7)
		_exterior_root(grove, bush, p)
	_build_outer_crops(grove)


func _exterior_root(parent: Node3D, node: Node3D, p: Vector2) -> void:
	node.position = Vector3(p.x, FieldTerrain.height_at(p.x, p.y) - 0.04, p.y)
	node.add_to_group("campo_exterior_roots")
	parent.add_child(node)


func _build_outer_crops(parent: Node3D) -> void:
	# Talhões separados por prado; todos os vértices do chão seguem o relevo analítico.
	var soil: SurfaceTool = SurfaceTool.new()
	soil.begin(Mesh.PRIMITIVE_TRIANGLES)
	for start_z: float in [-25.0, 3.0]:
		for x: int in range(35, 43):
			for z: int in range(int(start_z), int(start_z) + 13):
				for offset: Vector2 in [Vector2.ZERO, Vector2(0, 1), Vector2.ONE, Vector2.ZERO, Vector2.ONE, Vector2(1, 0)]:
					var p: Vector2 = Vector2(float(x), float(z)) + offset
					soil.set_color(Color("#887346") if x % 2 == 0 else Color("#9b8550"))
					soil.add_vertex(Vector3(p.x, FieldTerrain.height_at(p.x, p.y) + 0.025, p.y))
	soil.generate_normals()
	var ground: MeshInstance3D = MeshInstance3D.new()
	ground.name = "TalhoesExteriores"
	ground.mesh = soil.commit()
	ground.material_override = ToonKit.vertex_material(false)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ground)
	# Uma malha partilhada por todas as touceiras; palha baixa mantém a vista da torre.
	var stalks: SurfaceTool = SurfaceTool.new()
	stalks.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in 3:
		var foot: Vector3 = Vector3(float(i - 1) * 0.085, 0.0, 0.0)
		LowPolyMesh.prism(stalks, foot, foot + Vector3(0.035, 0.62 + float(i % 2) * 0.14, 0.025), 0.035, 0.025, 4, Color("#baab65"))
	var crop_mesh: Mesh = ToonKit.commit(stalks)
	var crop_material: Material = ToonKit.vertex_material(false)
	var instances: MultiMesh = MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = crop_mesh
	instances.instance_count = 80
	var index: int = 0
	for start_z: float in [-25.0, 3.0]:
		for row: int in 5:
			for col: int in 8:
				var p: Vector2 = Vector2(35.5 + float(row) * 1.5, start_z + 0.7 + float(col) * 1.5)
				var origin: Vector3 = Vector3(p.x, FieldTerrain.height_at(p.x, p.y) - 0.04, p.y)
				instances.set_instance_transform(index, Transform3D(Basis.IDENTITY, origin))
				index += 1
	var crops: MultiMeshInstance3D = MultiMeshInstance3D.new()
	crops.name = "LavouraExterior"
	crops.multimesh = instances
	crops.material_override = crop_material
	crops.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(crops)
