extends GutTest

const ROCKET_PATH: String = "res://assets/models/scandig_space/lunar_rocket.glb"
const SITE: Vector2 = Vector2(-23,21)
const FEET: Array[Rect2] = [
	Rect2(-24.8,20.886,.2,.228), Rect2(-21.4,20.886,.2,.228),
	Rect2(-23.114,19.2,.228,.2), Rect2(-23.114,22.6,.228,.2),
]
var ground_faces: PackedVector3Array = PackedVector3Array()

func _source() -> Script:
	var path: String = "res://gameplay/environment/crater_rocket.gd"
	assert_true(ResourceLoader.exists(path), "Crater rocket placement helper absent: " + path)
	if not ResourceLoader.exists(path): return null
	return load(path) as Script

func _fixture() -> Dictionary:
	var source: Script = _source()
	if source == null: return {}
	var placement: Node3D = source.new() as Node3D
	assert_not_null(placement)
	if placement == null: return {}
	placement.position = Vector3(SITE.x,0,SITE.y)
	add_child_autofree(placement)
	var rocket: Node3D = placement.call("build") as Node3D
	assert_not_null(rocket, "build returns the single Rocket instance")
	return {"placement":placement,"rocket":rocket}

func _ground() -> PackedVector3Array:
	if ground_faces.is_empty():
		var terrain: StaticBody3D = load("res://gameplay/environment/crater_terrain.gd").new() as StaticBody3D
		add_child_autofree(terrain)
		ground_faces = (terrain.get_node(^"Mesh") as MeshInstance3D).mesh.get_faces()
	return ground_faces

func _ray(faces: PackedVector3Array, at: Vector2, ceiling: float = 50.0) -> float:
	var highest: float = -INF
	for i: int in range(0,faces.size(),3):
		var point: Variant = Geometry3D.segment_intersects_triangle(Vector3(at.x,ceiling,at.y),Vector3(at.x,-50,at.y),faces[i],faces[i+1],faces[i+2])
		if point != null: highest = maxf(highest,(point as Vector3).y)
	return highest

func _visual_faces(root: Node3D) -> PackedVector3Array:
	var result: PackedVector3Array = PackedVector3Array()
	for child: Node in root.find_children("*","MeshInstance3D",true,false):
		var mesh: MeshInstance3D = child as MeshInstance3D
		for p: Vector3 in mesh.mesh.get_faces(): result.append(mesh.global_transform*p)
	return result

func _collision_faces(root: Node3D) -> PackedVector3Array:
	var result: PackedVector3Array = PackedVector3Array()
	for child: Node in root.find_children("*","CollisionShape3D",true,false):
		var shape: CollisionShape3D = child as CollisionShape3D
		assert_true(shape.shape is ConcavePolygonShape3D, "Deformed supports use exact mesh collision")
		if shape.shape is ConcavePolygonShape3D:
			for p: Vector3 in (shape.shape as ConcavePolygonShape3D).get_faces(): result.append(shape.global_transform*p)
	return result

func _corners(foot: Rect2) -> Array[Vector2]:
	return [foot.position,foot.position+Vector2(foot.size.x,0),foot.end,foot.position+Vector2(0,foot.size.y)]

func test_original_proposed_route_rejected_by_existing_rotated_meteorite() -> void:
	# Independent fixture from CraterLayout.PIECES and CraterStructure's BoxShape.
	var a: Vector2 = (Vector2(-17.5,16.5)-Vector2(-18,18)).rotated(-deg_to_rad(20.0))
	var b: Vector2 = (Vector2(-20,19.5)-Vector2(-18,18)).rotated(-deg_to_rad(20.0))
	var corners: Array[Vector2] = [Vector2(-1.05,-.9),Vector2(1.05,-.9),Vector2(1.05,.9),Vector2(-1.05,.9)]
	var blocked: bool = false
	for i: int in 4:
		if Geometry2D.segment_intersects_segment(a,b,corners[i],corners[(i+1)%4]) != null: blocked = true
	assert_true(blocked,"Original route crosses the solid meteorite and cannot count as a successful walk")

func test_existing_asset_single_instance_and_idempotent_build() -> void:
	var fixture: Dictionary = _fixture()
	if fixture.is_empty() or fixture.rocket == null: return
	var placement: Node3D = fixture.placement
	placement.call("build")
	var instances: int = 0
	for child: Node in placement.find_children("*","Node3D",true,false):
		if child.scene_file_path == ROCKET_PATH: instances += 1
	assert_eq(instances,1,"Reuse the exported GLB once, no duplicate/procedural replacement")
	assert_eq(placement.position,Vector3(-23,0,21))
	assert_eq(placement.rotation,Vector3.ZERO)
	assert_eq(placement.scale,Vector3.ONE)
	var authored: Node3D = Node3D.new()
	placement.add_child(authored)
	authored.owner = placement
	placement.call("build")
	assert_true(is_instance_valid(authored),"Preserve authored children")

func test_actual_footprint_boarding_bounds_and_objective_clearance() -> void:
	var fixture: Dictionary = _fixture()
	if fixture.is_empty() or fixture.rocket == null: return
	var faces: PackedVector3Array = _visual_faces(fixture.rocket)
	assert_gt(faces.size(),0)
	var min_x: float = INF
	var max_x: float = -INF
	var min_z: float = INF
	var max_z: float = -INF
	for p: Vector3 in faces:
		assert_true(p.is_finite())
		min_x = minf(min_x,p.x)
		max_x = maxf(max_x,p.x)
		min_z = minf(min_z,p.z)
		max_z = maxf(max_z,p.z)
	assert_almost_eq(min_x,-24.8,.002)
	assert_almost_eq(max_x,-21.2,.002)
	assert_almost_eq(min_z,19.2,.002)
	assert_almost_eq(max_z,22.8,.002)
	assert_gte(SITE.x-5,-30.0)
	assert_lte(SITE.y+5,30.0)
	assert_gt(SITE.distance_to(Vector2(-12.5,8.5)),14.0,"R5 boarding outside Vega event spawn R9")
	assert_gt(SITE.distance_to(Vector2(-22,14)),5.0,"Probe root outside boarding; full probe mesh still needs integration check")
	assert_gt(SITE.distance_to(Vector2(18,18)),14.0)

func test_four_supports_bottom_corners_follow_actual_terrain_triangles() -> void:
	var fixture: Dictionary = _fixture()
	if fixture.is_empty(): return
	var supports: Node3D = fixture.placement.get_node_or_null(^"Supports") as Node3D
	assert_not_null(supports,"Measured .22834m spread requires four individual supports")
	if supports == null: return
	assert_eq(supports.get_child_count(),4)
	var visual: PackedVector3Array = _visual_faces(supports)
	var physical: PackedVector3Array = _collision_faces(supports)
	assert_gt(visual.size(),0)
	assert_gt(physical.size(),0)
	var low: float = INF
	var high: float = -INF
	for foot: Rect2 in FEET:
		for at: Vector2 in _corners(foot):
			var expected: float = _ray(_ground(),at)
			low = minf(low,expected)
			high = maxf(high,expected)
			var visual_gap: float = INF
			var collision_gap: float = INF
			for p: Vector3 in visual:
				if Vector2(p.x,p.z).distance_to(at)<.002: visual_gap = minf(visual_gap,absf(p.y-expected))
			for p: Vector3 in physical:
				if Vector2(p.x,p.z).distance_to(at)<.002: collision_gap = minf(collision_gap,absf(p.y-expected))
			assert_lte(visual_gap,.005,"Visible support lower corner follows physical terrain at "+str(at))
			assert_lte(collision_gap,.005,"Collision lower corner follows physical terrain at "+str(at))
	assert_almost_eq(high-low,.2283401489,.002,"Fixture samples the exact measured rectangles, not conservative squares")

func test_support_tops_common_and_touch_all_rocket_feet_visually_and_physically() -> void:
	var fixture: Dictionary = _fixture()
	if fixture.is_empty() or fixture.rocket == null: return
	var supports: Node3D = fixture.placement.get_node_or_null(^"Supports") as Node3D
	assert_not_null(supports)
	if supports == null: return
	var visual: PackedVector3Array = _visual_faces(supports)
	var physical: PackedVector3Array = _collision_faces(supports)
	var rocket: Node3D = fixture.rocket
	var sole_y: float = rocket.global_position.y
	assert_eq(rocket.global_rotation,Vector3.ZERO,"Keep rocket vertical, no tilt to hide gaps")
	assert_almost_eq(rocket.global_basis.x.length(),2.0,.001)
	assert_gte(sole_y,-.2946891785)
	assert_lte(sole_y,-.2946891785+.15,"Support top has bounded clearance above highest terrain corner")
	for foot: Rect2 in FEET:
		# Slight inset avoids numerical misses exactly on a triangle edge.
		for corner: Vector2 in _corners(foot):
			var at: Vector2 = corner.lerp(foot.get_center(),.01)
			assert_almost_eq(_ray(visual,at,sole_y+.02),sole_y,.003,"Each visual top reaches the common sole plane")
			assert_almost_eq(_ray(physical,at,sole_y+.02),sole_y,.003,"Each physical top reaches the common sole plane")
