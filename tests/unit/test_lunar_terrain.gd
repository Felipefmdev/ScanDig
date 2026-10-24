extends GutTest

const ROUTE: Array[Vector2] = [Vector2(0,18), Vector2(-4,10), Vector2(3,3), Vector2(-4,-5), Vector2(0,-15)]

func _source() -> Script:
	var path: String = "res://gameplay/environment/lunar_terrain.gd"
	assert_true(ResourceLoader.exists(path), "#120 lunar terrain is absent: " + path)
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Script

func _height(source: Script, at: Vector2) -> float:
	return float(source.call("height_at", at.x, at.y))

func test_mesh_contract_determinism_and_global_rng() -> void:
	var source: Script = _source()
	if source == null: return
	seed(120)
	var expected: int = randi()
	seed(120)
	var mesh: ArrayMesh = source.call("build_mesh") as ArrayMesh
	assert_eq(randi(), expected, "Terrain generation must not consume global RNG")
	assert_not_null(mesh)
	if mesh == null: return
	assert_eq(mesh.get_surface_count(), 1)
	assert_eq(mesh.surface_get_primitive_type(0), Mesh.PRIMITIVE_TRIANGLES)
	var faces: PackedVector3Array = mesh.get_faces()
	assert_gt(faces.size(), 10000, "Terrain must cover the full lunar area")
	assert_lte(faces.size(), 120000, "Bounded full terrain mesh budget")
	var repeated: ArrayMesh = source.call("build_mesh") as ArrayMesh
	for channel: int in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR, Mesh.ARRAY_INDEX]:
		assert_eq(mesh.surface_get_arrays(0)[channel], repeated.surface_get_arrays(0)[channel])
	var invalid: int = 0
	for i: int in range(0, faces.size(), 3):
		if not faces[i].is_finite() or not faces[i+1].is_finite() or not faces[i+2].is_finite():
			invalid += 1
		elif (faces[i+1]-faces[i]).cross(faces[i+2]-faces[i]).length_squared() < 0.000001:
			invalid += 1
	assert_eq(invalid, 0, "No degenerate or non-finite terrain triangles")
	var bounds: AABB = mesh.get_aabb()
	assert_almost_eq(bounds.position.x, -70.0, 0.001)
	assert_almost_eq(bounds.position.z, -70.0, 0.001)
	assert_almost_eq(bounds.end.x, 70.0, 0.001)
	assert_almost_eq(bounds.end.z, 70.0, 0.001)

func test_height_at_matches_real_triangles_between_grid_vertices() -> void:
	var source: Script = _source()
	if source == null: return
	var mesh: ArrayMesh = source.call("build_mesh") as ArrayMesh
	var faces: PackedVector3Array = mesh.get_faces()
	# Deliberately non-grid points on both halves of cells, crater/ramp/rim included.
	for at: Vector2 in [Vector2(.17,18.63),Vector2(-3.21,10.47),Vector2(3.61,2.73),Vector2(-4.13,-5.37),Vector2(.41,-15.59),Vector2(-18.37,9.21),Vector2(14.73,10.19),Vector2(-15.31,-17.79),Vector2(18.27,-12.43),Vector2(30.31,8.63),Vector2(47.81,-41.39),Vector2(-69.67,69.13)]:
		var highest: float = -INF
		for i: int in range(0, faces.size(), 3):
			var hit: Variant = Geometry3D.segment_intersects_triangle(Vector3(at.x,100,at.y),Vector3(at.x,-100,at.y),faces[i],faces[i+1],faces[i+2])
			if hit != null: highest = maxf(highest,(hit as Vector3).y)
		assert_true(is_finite(highest), "Continuous ground beneath " + str(at))
		assert_almost_eq(_height(source,at),highest,0.0001,"Analytic support equals collision triangle at " + str(at))

func test_arrival_and_arena_are_flat_clear_ground() -> void:
	var source: Script = _source()
	if source == null: return
	for zone: Vector3 in [Vector3(0,18,4),Vector3(0,-15,7.5)]:
		var center: Vector2 = Vector2(zone.x,zone.y)
		var expected: float = 0.0 if zone.y == 18 else -0.8
		for i: int in 16:
			var at: Vector2 = center + Vector2(cos(TAU*i/16.0),sin(TAU*i/16.0))*zone.z
			assert_almost_eq(_height(source,at),expected,0.001,"No unstable arrival/arena support")

func test_full_width_main_route_walkable_without_jump() -> void:
	var source: Script = _source()
	if source == null: return
	var steepest: float = 0.0
	for i: int in ROUTE.size()-1:
		var direction: Vector2 = (ROUTE[i+1]-ROUTE[i]).normalized()
		var side: Vector2 = Vector2(-direction.y,direction.x)
		var steps: int = int(ceil(ROUTE[i].distance_to(ROUTE[i+1])/.25))
		for j: int in steps+1:
			var center: Vector2 = ROUTE[i].lerp(ROUTE[i+1],float(j)/steps)
			for lateral: float in [-2.4,-1.8,-.9,0.0,.9,1.8,2.4]:
				var at: Vector2 = center+side*lateral
				var dx: float = (_height(source,at+Vector2(.02,0))-_height(source,at-Vector2(.02,0)))/.04
				var dz: float = (_height(source,at+Vector2(0,.02))-_height(source,at-Vector2(0,.02)))/.04
				steepest = maxf(steepest,rad_to_deg(atan(Vector2(dx,dz).length())))
	assert_lte(steepest,20.0,"Entire 4.8m route stays below 20deg; actual Player walking still requires bot")

func test_external_ground_continues_beyond_play_bounds() -> void:
	var source: Script = _source()
	if source == null: return
	for direction: Vector2 in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		assert_gt(_height(source,direction*70),_height(source,direction*30)+4.0,"External relief closes horizon without a mesh seam at bounds")

func test_full_authored_flat_disks_and_irregular_horizon() -> void:
	var source: Script = _source()
	if source == null: return
	for zone: Vector3 in [Vector3(0,18,5),Vector3(0,-15,9)]:
		var expected: float = 0.0 if zone.y == 18 else -0.8
		for i: int in 48:
			var at: Vector2 = Vector2(zone.x,zone.y) + Vector2.from_angle(TAU*i/48.0)*zone.z
			assert_almost_eq(_height(source,at),expected,0.001,"Disco inteiro com apoio plano")
	var highest: float = -INF
	var lowest: float = INF
	for x: float in [-60.0,-40.0,-20.0,0.0,20.0,40.0,60.0]:
		for z: float in [-70.0,70.0]:
			var h: float = _height(source,Vector2(x,z))
			highest = maxf(highest,h)
			lowest = minf(lowest,h)
	assert_gt(highest-lowest,3.0,"Horizonte precisa variar em altura, sem paredão uniforme")

func test_ground_material_does_not_draw_outlines_between_ground_faces() -> void:
	var source: Script = _source()
	if source == null: return
	var terrain: Node = source.new()
	add_child_autofree(terrain)
	var meshes: Array[Node] = terrain.find_children("*","MeshInstance3D",true,false)
	assert_eq(meshes.size(),1)
	if meshes.size() == 1:
		assert_null((meshes[0] as MeshInstance3D).material_override.next_pass,"Sem contorno expandido nas faces do chão")

func test_runtime_collision_matches_mesh_and_rebuild_is_idempotent() -> void:
	var source: Script = _source()
	if source == null: return
	var terrain: Node = source.new()
	assert_true(terrain is StaticBody3D)
	if not terrain is StaticBody3D:
		terrain.free()
		return
	add_child_autofree(terrain)
	var authored: Node3D = Node3D.new()
	authored.name = "AuthoredFixture"
	terrain.add_child(authored)
	authored.owner = terrain
	terrain.call("rebuild")
	terrain.call("rebuild")
	var meshes: Array[Node] = terrain.find_children("*","MeshInstance3D",true,false)
	var shapes: Array[Node] = terrain.find_children("*","CollisionShape3D",true,false)
	assert_eq(meshes.size(),1)
	assert_eq(shapes.size(),1)
	assert_true(is_instance_valid(authored),"Rebuild only replaces generated terrain")
	assert_eq((terrain as StaticBody3D).collision_layer,1)
	if meshes.size()!=1 or shapes.size()!=1: return
	var mesh: MeshInstance3D = meshes[0] as MeshInstance3D
	var shape: CollisionShape3D = shapes[0] as CollisionShape3D
	assert_true(shape.shape is ConcavePolygonShape3D)
	if shape.shape is ConcavePolygonShape3D:
		assert_eq((shape.shape as ConcavePolygonShape3D).get_faces(),mesh.mesh.get_faces(),"Visible and physical terrain share exact triangles")
	assert_null(mesh.owner)
	assert_null(shape.owner)
