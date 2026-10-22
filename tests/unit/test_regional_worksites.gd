extends GutTest
## #161. Contracts protect play space rather than exact prop geometry.

const SOURCE: String = "res://gameplay/environment/regional_worksites.gd"
const THEMES: Array[String] = ["ruinas", "geleira", "cratera"]
const TERRAINS: Dictionary = {
	"ruinas": preload("res://gameplay/environment/ruins_terrain.gd"),
	"geleira": preload("res://gameplay/environment/glacier_terrain.gd"),
	"cratera": preload("res://gameplay/environment/crater_terrain.gd"),
}
const SITES: Dictionary = {
	"ruinas": [Vector2(8.2, -2.5), Vector2(-18.0, 10.5)],
	"geleira": [Vector2(-16.15, 9.59), Vector2(-19.5, 8.0)],
	"cratera": [Vector2(-15.7, 10.7), Vector2(-8.5, -24.0), Vector2(-23.0, -4.0)],
}
# [center, clearance]. Main boss/wave arenas, quest objects and NPC approach space.
const CLEARANCES: Dictionary = {
	"ruinas": [
		[Vector2(0, -24), 7.5], [Vector2(20, -15), 7.0],
		[Vector2(5.5, 1.5), 2.6], [Vector2(8.5, 6), 4.0],
		[Vector2(-22, -6), 4.0], [Vector2(-14, 14), 2.0],
		[Vector2(10, 13), 2.5], [Vector2(-11.6, -20), 2.5],
	],
	"geleira": [
		[Vector2(-13.5, 7.5), 2.0], [Vector2(-14, 9.8), 1.3],
		[Vector2(18, 18), 8.0], [Vector2(0, -28.5), 6.0],
		[Vector2(-4, 18), 2.5], [Vector2(8.5, 6), 4.0],
		[Vector2(14, -8), 10.0],
	],
	"cratera": [
		[Vector2(-12.5, 8.5), 9.0], [Vector2(18, 18), 8.0],
		[Vector2(-22, 14), 2.5], [Vector2(-16, -14), 3.5],
		[Vector2(-4, -23), 2.5], [Vector2(-18, -2), 2.5],
		[Vector2(14, 16), 3.5], [Vector2(8, -8), 4.0],
		[Vector2(7, 3), 3.0], [Vector2(13, 7), 2.5],
	],
}
# [from, to, half width]. No apparent cosmetic obstacles across these routes.
const CORRIDORS: Dictionary = {
	"ruinas": [
		[Vector2(0, 0), Vector2(0, -16), 1.8],
		[Vector2(0, 0), Vector2(-16.4, -6), 1.8],
		[Vector2(0, 0), Vector2(5.5, 1.5), 1.6],
	],
	"geleira": [
		[Vector2(-14.92, 6.41), Vector2(-16.5, 3.7), 1.0],
		[Vector2(0, 0), Vector2(-13.5, 7.5), 1.6],
		[Vector2(-13.5, 7.5), Vector2(4, -16), 1.6],
	],
	"cratera": [
		[Vector2(0, 0), Vector2(-12.5, 8.5), 1.8],
		[Vector2(-12.5, 8.5), Vector2(14, 16), 1.8],
		[Vector2(-18, -2), Vector2(-4, -23), 1.6],
	],
}


func test_build_contract_one_surface_and_unsupported_null() -> void:
	var generator: Script = _generator()
	if generator == null:
		return
	for theme: String in THEMES:
		var mesh: Mesh = generator.call("build", theme)
		assert_not_null(mesh, theme)
		if mesh != null:
			assert_eq(mesh.get_surface_count(), 1, theme + " single cosmetic batch")
	for unsupported: String in ["", "campo", "praia", "RUINAS"]:
		assert_null(generator.call("build", unsupported), "Unsupported: " + unsupported)


func test_determinism_budget_and_finite_non_degenerate_faces() -> void:
	var generator: Script = _generator()
	if generator == null:
		return
	for theme: String in THEMES:
		var mesh: Mesh = generator.call("build", theme)
		var repeated: Mesh = generator.call("build", theme)
		var arrays: Array = mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = _triangles(mesh)
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		assert_eq(arrays[Mesh.ARRAY_VERTEX], repeated.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
		assert_eq(colors, repeated.surface_get_arrays(0)[Mesh.ARRAY_COLOR])
		assert_eq(normals, repeated.surface_get_arrays(0)[Mesh.ARRAY_NORMAL])
		assert_gt(vertices.size(), 90, theme + " readable worksite rather than a marker")
		assert_lte(vertices.size(), 12000, theme + " <=4000 triangles")
		assert_eq(normals.size(), arrays[Mesh.ARRAY_VERTEX].size())
		assert_eq(colors.size(), normals.size())
		assert_not_null(arrays[Mesh.ARRAY_CUSTOM0], theme + " outline directions required by shared ToonKit material")
		print("#161 %s: %d triangles, %d vertices" % [theme, vertices.size() / 3, arrays[Mesh.ARRAY_VERTEX].size()])
		var invalid: int = 0
		for p: Vector3 in vertices:
			if not p.is_finite() or maxf(absf(p.x), absf(p.z)) > 30.0:
				invalid += 1
		for normal: Vector3 in normals:
			if not normal.is_finite() or absf(normal.length() - 1.0) > 0.01:
				invalid += 1
		for i: int in range(0, vertices.size(), 3):
			if (vertices[i + 1] - vertices[i]).cross(vertices[i + 2] - vertices[i]).length_squared() < 1e-12:
				invalid += 1
		for color: Color in colors:
			if not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b) or color.a < 0.999:
				invalid += 1
		assert_eq(invalid, 0, theme + " finite solid geometry, no degenerate faces")


func test_ground_support_and_two_or_three_readable_groups() -> void:
	var generator: Script = _generator()
	if generator == null:
		return
	for theme: String in THEMES:
		var vertices: PackedVector3Array = _triangles(generator.call("build", theme))
		var invalid: int = 0
		for p: Vector3 in vertices:
			var relative_y: float = p.y - _height(theme, p)
			if relative_y < -0.13 or relative_y > 2.25:
				invalid += 1
			var nearest_site: float = INF
			for site: Vector2 in SITES[theme]:
				nearest_site = minf(nearest_site, Vector2(p.x, p.z).distance_to(site))
			if nearest_site > 2.1:
				invalid += 1
		assert_eq(invalid, 0, theme + " baked terrain support, conservative height")
		for site: Vector2 in SITES[theme]:
			var contacts: Array[Vector2] = []
			var count: int = 0
			var high: float = 0.0
			for p: Vector3 in vertices:
				var flat: Vector2 = Vector2(p.x, p.z)
				if flat.distance_to(site) > 2.1:
					continue
				count += 1
				high = maxf(high, p.y - _height(theme, p))
				if absf(p.y - _height(theme, p)) <= 0.13 and not contacts.has(flat):
					contacts.append(flat)
			assert_gt(count, 30, theme + " site " + str(site) + " is legible")
			assert_gt(high, 0.3, theme + " has readable volume")
			if theme == "cratera" and site == SITES[theme][0]:
				var flush_error: int = 0
				var root_height: float = TERRAINS[theme].call("height_at", -14.0, 10.0)
				for p: Vector3 in vertices:
					if Vector2(p.x, p.z).distance_to(site) > 2.1:
						continue
					var local: Vector3 = Basis(Vector3.UP, deg_to_rad(15.0)).inverse() * Vector3(p.x + 14, p.y - root_height, p.z - 10)
					if local.x < -1.91 or local.x > -1.79 or absf(_height(theme, p) - root_height) > 0.001:
						flush_error += 1
				assert_eq(flush_error, 0, "Panel and joints remain flush to actual flat module wall")
				continue # Flush panel is supported by the existing module, not new terrain legs.
			assert_gte(contacts.size(), 3, theme + " site has multiple terrain supports")
			var span: float = 0.0
			for a: Vector2 in contacts:
				for b: Vector2 in contacts:
					span = maxf(span, a.distance_to(b))
			assert_gt(span, 0.4, theme + " support footprint cannot be one floating pin")


func test_triangles_preserve_routes_objectives_and_arenas() -> void:
	var generator: Script = _generator()
	if generator == null:
		return
	for theme: String in THEMES:
		var vertices: PackedVector3Array = _triangles(generator.call("build", theme))
		var blocked: int = 0
		for i: int in range(0, vertices.size(), 3):
			# Sampling triangle interiors catches broad faces bridging a clear corridor.
			var divisions: int = maxi(1, int(ceil(maxf(vertices[i].distance_to(vertices[i + 1]), vertices[i].distance_to(vertices[i + 2])) / 0.12)))
			for u: int in range(divisions + 1):
				for v: int in range(divisions - u + 1):
					var point: Vector3 = vertices[i] + (vertices[i + 1] - vertices[i]) * float(u) / divisions + (vertices[i + 2] - vertices[i]) * float(v) / divisions
					if _blocks_play_space(theme, point):
						blocked += 1
		assert_eq(blocked, 0, theme + " routes, interaction approaches and arenas remain clear")


func test_glacier_keeps_existing_pines_and_door_clear() -> void:
	var generator: Script = _generator()
	if generator == null:
		return
	var vertices: PackedVector3Array = _triangles(generator.call("build", "geleira"))
	var blocked: int = 0
	var cabin_basis: Basis = Basis(Vector3.UP, deg_to_rad(30.0))
	for p: Vector3 in vertices:
		for pine: Vector2 in [Vector2(-10, 12), Vector2(-18, 11), Vector2(-16, 4), Vector2(-8, 5)]:
			if Vector2(p.x, p.z).distance_to(pine) < 1.15:
				blocked += 1
		var local: Vector3 = cabin_basis.inverse() * Vector3(p.x + 14, 0, p.z - 8)
		if absf(local.x) < 0.95 and local.z < -1.75 and local.z > -4.5:
			blocked += 1
	assert_eq(blocked, 0, "No tree trunk overlap or obstruction at existing -Z cabin door")


func _generator() -> Script:
	assert_true(FileAccess.file_exists(SOURCE), "#161 regional interior worksite generator is absent")
	if not FileAccess.file_exists(SOURCE):
		return null
	return load(SOURCE)


func _triangles(mesh: Mesh) -> PackedVector3Array:
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: Variant = arrays[Mesh.ARRAY_INDEX]
	if indices == null or indices.size() == 0:
		return vertices
	var expanded: PackedVector3Array = PackedVector3Array()
	for index: int in indices:
		expanded.append(vertices[index])
	return expanded


func _height(theme: String, p: Vector3) -> float:
	return TERRAINS[theme].call("height_at", p.x, p.z)


func _blocks_play_space(theme: String, p: Vector3) -> bool:
	if theme == "cratera":
		var local: Vector3 = Basis(Vector3.UP, deg_to_rad(15.0)).inverse() * Vector3(p.x + 14, 0, p.z - 10)
		if absf(local.x) <= 2.1 and absf(local.z) <= 2.4:
			return false # Existing module collision envelope: flush facade adds no occupied ground.
	var flat: Vector2 = Vector2(p.x, p.z)
	for protected: Array in CLEARANCES[theme]:
		if flat.distance_to(protected[0]) < protected[1]:
			return true
	for corridor: Array in CORRIDORS[theme]:
		if flat.distance_to(Geometry2D.get_closest_point_to_segment(flat, corridor[0], corridor[1])) < corridor[2]:
			return true
	return false
