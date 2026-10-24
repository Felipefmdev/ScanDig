extends GutTest

const ARRIVAL_PATH: String = "res://gameplay/environment/lunar_arrival.gd"


func test_arrival_assets_are_normalized_and_grounded_outside_route() -> void:
	assert_true(ResourceLoader.exists(ARRIVAL_PATH), "Composição lunar precisa existir")
	if not ResourceLoader.exists(ARRIVAL_PATH): return
	var source: Script = load(ARRIVAL_PATH) as Script
	var terrain: Script = load("res://gameplay/environment/lunar_terrain.gd") as Script
	var node: Node3D = source.new() as Node3D
	add_child_autofree(node)
	var meshes: Array[Node] = node.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 2, "Foguete e apoios têm malhas reais")
	var route: Array[Vector2] = [Vector2(0,18),Vector2(-4,10),Vector2(3,3),Vector2(-4,-5),Vector2(0,-15)]
	var minimum_clearance: float = INF
	for child: Node in meshes:
		var mesh: MeshInstance3D = child as MeshInstance3D
		var bounds: AABB = mesh.get_aabb()
		for corner: int in 8:
			var point: Vector3 = mesh.global_transform * bounds.get_endpoint(corner)
			var xz: Vector2 = Vector2(point.x,point.z)
			for i: int in route.size()-1:
				var closest: Vector2 = Geometry2D.get_closest_point_to_segment(xz,route[i],route[i+1])
				minimum_clearance = minf(minimum_clearance,xz.distance_to(closest))
	assert_gt(minimum_clearance,2.4,"Nenhuma peça invade a rota")
	var rocket: Node3D = node.get_node_or_null("Rocket") as Node3D
	assert_not_null(rocket)
	if rocket != null:
		assert_almost_eq(rocket.position.x,7.0,0.001)
		assert_almost_eq(rocket.position.z,18.0,0.001)
		assert_almost_eq(rocket.position.y,float(terrain.height_at(7,18)),0.10)
	var collider: CollisionShape3D = node.get_node_or_null("Rocket/Body/Collision") as CollisionShape3D
	assert_not_null(collider,"Foguete fechado tem colisão correspondente à geometria")
	if collider != null:
		assert_true(collider.shape is ConcavePolygonShape3D)


func test_equipment_keeps_yellow_under_direct_light() -> void:
	if DisplayServer.get_name() == "headless":
		pending("Paleta sob luz direta exige renderer real; executar com janela")
		return
	if not ResourceLoader.exists(ARRIVAL_PATH): return
	var node: Node3D = (load(ARRIVAL_PATH) as Script).new() as Node3D
	add_child_autofree(node)
	var yellow: ShaderMaterial = null
	for child: Node in node.find_children("*","MeshInstance3D",true,false):
		var mesh: MeshInstance3D = child as MeshInstance3D
		for surface: int in mesh.mesh.get_surface_count():
			var material: ShaderMaterial = mesh.get_active_material(surface) as ShaderMaterial
			if material == null: continue
			var paint: Color = material.get_shader_parameter(&"albedo_color")
			if paint.r > 0.8 and paint.g > 0.3 and paint.g < 0.9 and paint.b < 0.6:
				yellow = material
	assert_not_null(yellow,"Material amarelo preservado na importação")
	if yellow == null: return
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(64,64)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child_autofree(viewport)
	var camera: Camera3D = Camera3D.new()
	camera.position = Vector3(0,0,3)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.0
	viewport.add_child(camera)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.light_energy = 1.7
	viewport.add_child(light)
	var scene: Node3D = (load("res://world/map_lua.tscn") as PackedScene).instantiate() as Node3D
	light.light_energy = (scene.get_node("SunLight") as DirectionalLight3D).light_energy
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = (scene.get_node("WorldEnvironment") as WorldEnvironment).environment
	viewport.add_child(environment)
	scene.free()
	var plate: MeshInstance3D = MeshInstance3D.new()
	plate.mesh = QuadMesh.new()
	plate.material_override = yellow.duplicate() as ShaderMaterial
	plate.material_override.next_pass = null
	viewport.add_child(plate)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var pixel: Color = viewport.get_texture().get_image().get_pixel(32,32)
	assert_gt(pixel.r, pixel.b * 1.3,"Luz direta mantém distinção amarelo/azul, sem virar branco")
	assert_gt(pixel.r, pixel.g * 1.08,"A iluminação lunar mantém o amarelo alaranjado sem saturar R e G: "+str(pixel))


func _segment_distance(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> float:
	if Geometry2D.segment_intersects_segment(a,b,c,d) != null: return 0.0
	return minf(minf(a.distance_to(Geometry2D.get_closest_point_to_segment(a,c,d)),b.distance_to(Geometry2D.get_closest_point_to_segment(b,c,d))),minf(c.distance_to(Geometry2D.get_closest_point_to_segment(c,a,b)),d.distance_to(Geometry2D.get_closest_point_to_segment(d,a,b))))


func _triangle_clearance(a: Vector2, b: Vector2, c: Vector2, start: Vector2, finish: Vector2) -> float:
	var polygon: PackedVector2Array = PackedVector2Array([a,b,c])
	if Geometry2D.is_point_in_polygon(start,polygon) or Geometry2D.is_point_in_polygon(finish,polygon): return 0.0
	return minf(_segment_distance(a,b,start,finish),minf(_segment_distance(b,c,start,finish),_segment_distance(c,a,start,finish)))


func test_real_faces_preserve_route_and_feet_contact() -> void:
	assert_eq(_triangle_clearance(Vector2(-6,20),Vector2(5,10),Vector2(5,30),Vector2(0,18),Vector2(-4,10)),0.0,"Calibração: interior do triângulo pode cruzar rota com cantos afastados")
	if not ResourceLoader.exists(ARRIVAL_PATH): return
	var node: Node3D = (load(ARRIVAL_PATH) as Script).new() as Node3D
	add_child_autofree(node)
	var terrain: Script = load("res://gameplay/environment/lunar_terrain.gd") as Script
	var route: Array[Vector2] = [Vector2(0,18),Vector2(-4,10),Vector2(3,3),Vector2(-4,-5),Vector2(0,-15)]
	var clearance: float = INF
	for group_name: String in ["Rocket","Generator","Supplies"]:
		var group: Node3D = node.get_node(group_name) as Node3D
		var points: PackedVector3Array = PackedVector3Array()
		var rocket_faces: PackedVector3Array = PackedVector3Array()
		var lowest: float = INF
		for child: Node in group.find_children("*","MeshInstance3D",true,false):
			var mesh: MeshInstance3D = child as MeshInstance3D
			for vertex: Vector3 in mesh.mesh.get_faces():
				var world: Vector3 = mesh.global_transform * vertex
				points.append(world)
				lowest = minf(lowest,world.y)
				if group_name == "Rocket": rocket_faces.append(group.global_transform.affine_inverse()*world)
		for i: int in range(0,points.size(),3):
			for segment: int in route.size()-1:
				clearance = minf(clearance,_triangle_clearance(Vector2(points[i].x,points[i].z),Vector2(points[i+1].x,points[i+1].z),Vector2(points[i+2].x,points[i+2].z),route[segment],route[segment+1]))
		var gap: float = 0.0
		var contacts: int = 0
		for point: Vector3 in points:
			if point.y < lowest+0.02:
				contacts += 1
				gap = maxf(gap,absf(point.y-float(terrain.height_at(point.x,point.z))))
		assert_gt(contacts,0,group_name+" tem pontos reais de apoio")
		assert_lt(gap,0.15,group_name+" mantém apoio dos vértices inferiores")
		if group_name == "Rocket":
			var collision: CollisionShape3D = group.get_node("Body/Collision") as CollisionShape3D
			var shape: ConcavePolygonShape3D = collision.shape as ConcavePolygonShape3D
			assert_eq(shape.get_faces().size(),rocket_faces.size())
			var error: float = 0.0
			for i: int in rocket_faces.size(): error = maxf(error,rocket_faces[i].distance_to(shape.get_faces()[i]))
			assert_lt(error,0.00001,"Faces físicas correspondem às visuais após escala")
	assert_gt(clearance,2.4,"Interior e arestas dos triângulos ficam fora do corredor")
