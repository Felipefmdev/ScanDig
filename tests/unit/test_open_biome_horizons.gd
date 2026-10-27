extends GutTest

## #186 geometric budgets only. Rendered images/player approach decide visual acceptance.
const TERRAINS: Dictionary = {
	"ruinas": preload("res://gameplay/environment/ruins_terrain.gd"),
	"geleira": preload("res://gameplay/environment/glacier_terrain.gd"),
	"cratera": preload("res://gameplay/environment/crater_terrain.gd"),
}
const BACKDROP: Script = preload("res://gameplay/environment/backdrop.gd")
const REGIONAL: Script = preload("res://gameplay/environment/regional_surroundings.gd")
const LUNAR: Script = preload("res://gameplay/environment/lunar_terrain.gd")
const BEACH_DRESSING: Script = preload("res://gameplay/environment/beach_dressing.gd")
## Frozen against lunar_terrain SHA C1250F33D27DECAB62EB7950E36B5323E82481902CFB4E1AFB3ADFB3D313C016.
## Explicit old numeric values; never recomputed from the live source in this test.
const LUNAR_INTERIOR: Array[Vector3] = [
	Vector3(0,0,18), Vector3(5,0,18), Vector3(0,0,23),
	Vector3(0,-.8,-15), Vector3(9,-.8,-15), Vector3(0,-.8,-24),
	Vector3(-4,-.0279147014,10), Vector3(-2,-.0984424913,8),
	Vector3(-.5,-.1210391942,6.5), Vector3(0,-.1285714286,6),
	Vector3(2,-.1428571429,4), Vector3(3,-.1475347661,3),
	Vector3(0,-.3206162058,0), Vector3(-2,-.6872677830,-2), Vector3(-4,-.8,-5),
]


func test_terrestrial_outer_terrain_stays_below_three_metres() -> void:
	for theme: String in TERRAINS:
		var highest: float = -INF
		var count: int = 0
		for edge: float in [-46.0,-44.0,-42.0,-40.0,40.0,42.0,44.0,46.0]:
			for along: int in range(-46,47,2):
				for p: Vector2 in [Vector2(edge,along),Vector2(along,edge)]:
					var height: float = float(TERRAINS[theme].call("height_at",p.x,p.y))
					assert_true(is_finite(height),theme+" finite exterior")
					highest = maxf(highest,height)
					count += 1
		assert_gt(count,500)
		assert_lte(highest,3.0,theme+" outer40..46m height budget, not visual approval")


func _surface_y(mesh: Mesh, at: Vector2) -> Variant:
	var faces: PackedVector3Array = mesh.get_faces()
	var highest: Variant = null
	for i: int in range(0,faces.size(),3):
		var hit: Variant = Geometry3D.segment_intersects_triangle(Vector3(at.x,30,at.y),Vector3(at.x,-20,at.y),faces[i],faces[i+1],faces[i+2])
		if hit != null and (highest == null or (hit as Vector3).y > float(highest)):
			highest = (hit as Vector3).y
	return highest


func test_praia_actual_coast_mesh_is_low_in_its_exterior_strips() -> void:
	# BeachTerrain ends at X[-31,38]/Z[-31,31]. Do NOT extrapolate it as real support40..46.
	var dressing: Node3D = BEACH_DRESSING.new()
	autofree(dressing)
	# This geometry-only builder works outside tree; no full-map props/ready workaround.
	dressing.call("_build_headlands")
	var coast: MeshInstance3D = dressing.get_node_or_null("ContinuidadeCosta") as MeshInstance3D
	assert_not_null(coast)
	if coast == null: return
	assert_not_null(coast.mesh)
	if coast.mesh == null: return
	var count: int = 0
	for edge: float in [40.0,42.0,44.0,46.0]:
		for along: float in [-24.0,-8.0,8.0,24.0]:
			for p: Vector2 in [Vector2(-edge,along),Vector2(along,-edge),Vector2(along,edge)]:
				var height: Variant = _surface_y(coast.mesh,p)
				assert_not_null(height,"Real coast triangles cover "+str(p))
				if height != null:
					assert_lte(float(height),3.0,"Low coastal continuation, not a physical terrain extension")
					count += 1
	assert_eq(count,48)


func _open_rays(mesh: Mesh) -> int:
	# Clip actual triangles to horizontal eye planeY1.6, then test32 radial segments.
	# A long/wide mesh cannot masquerade as a gap merely because its vertices miss a bin.
	var cuts: Array[PackedVector2Array] = []
	var faces: PackedVector3Array = mesh.get_faces()
	for i: int in range(0,faces.size(),3):
		var points: PackedVector2Array = PackedVector2Array()
		for k: int in range(3):
			var a: Vector3 = faces[i+k]
			var b: Vector3 = faces[i+(k+1)%3]
			if absf(a.y-1.6) < .00001:
				points.append(Vector2(a.x,a.z))
			if (a.y-1.6)*(b.y-1.6) < 0.0:
				var p: Vector3 = a.lerp(b,(1.6-a.y)/(b.y-a.y))
				points.append(Vector2(p.x,p.z))
		if points.size() >= 2: cuts.append(points)
	var open: int = 0
	for i: int in range(32):
		var end: Vector2 = Vector2.from_angle(TAU*float(i)/32.0)*1000.0
		var blocked: bool = false
		for cut: PackedVector2Array in cuts:
			for k: int in range(cut.size()-1):
				if Geometry2D.segment_intersects_segment(Vector2.ZERO,end,cut[k],cut[k+1]) != null:
					blocked = true
					break
			if blocked: break
		if not blocked: open += 1
	return open


func test_distant_landforms_are_limited_low_and_have_geometric_gaps() -> void:
	for theme: String in ["praia","ruinas","geleira","cratera"]:
		for seed_value: int in [3,9,161]:
			var backdrop: Node3D = BACKDROP.new()
			backdrop.set("theme",theme)
			backdrop.set("seed_value",seed_value)
			autofree(backdrop)
			var count: int = int(backdrop.call("build"))
			assert_gt(count,4,theme+" retains existing minimum landscape population")
			assert_lte(count,10,theme+" at most10 actual generated silhouettes")
			var hills: MeshInstance3D = backdrop.get_node_or_null("Hills") as MeshInstance3D
			assert_not_null(hills)
			if hills == null: continue
			assert_not_null(hills.mesh)
			if hills.mesh == null: continue
			assert_lte(hills.mesh.get_aabb().end.y,10.0,theme+" actual mesh top budget")
			assert_gte(_open_rays(hills.mesh),8,theme+" at least8/32 eye-level rays miss distant mesh")


func test_regional_continuation_is_low_and_keeps_actual_terrain_seam() -> void:
	for theme: String in TERRAINS:
		var mesh: Mesh = REGIONAL.call("build",theme) as Mesh
		assert_not_null(mesh)
		if mesh == null: continue
		assert_eq(mesh.get_surface_count(),1)
		assert_lte(mesh.get_aabb().end.y,8.0,theme+" regional mesh maxY<=8")
		var count: int = 0
		var worst: float = 0.0
		for p: Vector3 in mesh.get_faces():
			if absf(maxf(absf(p.x),absf(p.z))-46.0) < .0001:
				var support: float = float(TERRAINS[theme].call("height_at",p.x,p.z))
				worst = maxf(worst,absf(p.y-support))
				count += 1
		assert_gt(count,100,theme+" seam actually sampled")
		assert_lte(worst,.001,theme+" lowering does not open a seam gap")


func test_lunar_exterior_is_low_and_contains_low_radial_sectors() -> void:
	var mesh: Mesh = LUNAR.call("build_mesh") as Mesh
	assert_not_null(mesh)
	if mesh == null: return
	var highest: float = -INF
	var count: int = 0
	for p: Vector3 in mesh.get_faces():
		if maxf(absf(p.x),absf(p.z)) >= 32.0:
			highest = maxf(highest,p.y)
			count += 1
	assert_gt(count,1000)
	assert_lte(highest,4.0,"All exterior mesh vertices beyond playable30m+onecell are low")
	var low_sectors: int = 0
	for i: int in range(16):
		var direction: Vector2 = Vector2.from_angle(TAU*float(i)/16.0)
		var sector_high: float = -INF
		for radius: float in [40.0,46.0,54.0,62.0,70.0]:
			var p: Vector2 = direction*radius
			sector_high = maxf(sector_high,float(LUNAR.call("height_at",p.x,p.y)))
		if sector_high <= 1.5: low_sectors += 1
	assert_gte(low_sectors,4,"At least4/16 sampled exterior directions remain<=1.5m across radii")


func test_lunar_arrival_arena_and_route_keep_frozen_numeric_heights() -> void:
	for sample: Vector3 in LUNAR_INTERIOR:
		var actual: float = float(LUNAR.call("height_at",sample.x,sample.z))
		assert_almost_eq(actual,sample.y,.0005,"Frozen interior XZ "+str(Vector2(sample.x,sample.z)))
