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
