extends GutTest

const BEACH: String = "res://gameplay/environment/beach_worksites.gd"
const FIELD: String = "res://gameplay/environment/field_worksites.gd"
const BEACH_SITES: Array[Vector2] = [Vector2(10.8, -3.8), Vector2(13.5, 1), Vector2(23, -0.4)]
const FIELD_SITES: Array[Vector2] = [Vector2(-10.5, 11.5), Vector2(-10, -3.7), Vector2(8, -20)]
var BEACH_ROUTES: Array[PackedVector2Array] = [
	PackedVector2Array([Vector2(0, 0), Vector2(25, 12)]),
	PackedVector2Array([Vector2(7, 0.5), Vector2(25, 12)]),
	PackedVector2Array([Vector2(3.5, 3.5), Vector2(27.2, 4)]),
	PackedVector2Array([Vector2(22.5, 16.5), Vector2(27.2, 4)]),
]
var FIELD_ROUTES: Array[PackedVector2Array] = [
	PackedVector2Array([Vector2(3.5, 3.5), Vector2(-2, -3), Vector2(-8, -8.5), Vector2(-11, -11)]),
	PackedVector2Array([Vector2(3.5, 3.5), Vector2(5, -5), Vector2(6, -11.5)]),
	PackedVector2Array([Vector2(5, -5), Vector2(10, -6), Vector2(24, -6)]),
	PackedVector2Array([Vector2(0, 1), Vector2(-2.5, 6.5)]),
	PackedVector2Array([Vector2(-6, -5), Vector2(6.4, -15)]),
	PackedVector2Array([Vector2(6.4, -15), Vector2(17.5, -17)]),
]
const BEACH_CLEAR: Array[Vector3] = [
	Vector3(0, 0, 3.5), Vector3(3.5, 3.5, 4), Vector3(7, 0.5, 3.5),
	Vector3(-22, -22, 9), Vector3(18.5, 15, 10), Vector3(22.5, 16.5, 3.4),
	Vector3(-4, -8, 3), Vector3(-8, 18, 3), Vector3(13, 9, 2.5),
	Vector3(16.5, -17.5, 2.5), Vector3(20, -8, 2), Vector3(21.5, -10.5, 2),
	Vector3(19.5, -13, 2), Vector3(27.2, 4, 2),
]
const FIELD_CLEAR: Array[Vector3] = [
	Vector3(0, 0, 3), Vector3(3.5, 3.5, 4.5), Vector3(7.5, 1, 3.5),
	Vector3(-2.5, 6.5, 2.5), Vector3(-6, -5, 2.7), Vector3(-4.9, -5, 2),
	Vector3(20.5, -4.5, 3.5), Vector3(-21.4, 8.5, 2.5), Vector3(-15, 19, 3),
	Vector3(-18, -18, 8.5), Vector3(5.2, -15, 3), Vector3(17.5, -17, 5),
	Vector3(-7.8818, 7.9862, 3.2),
	Vector3(-6, 9, 1.5), Vector3(-4.8, 9.6, 1.5), Vector3(-5.4, 8.8, 1.5),
]

func _build(path: String) -> Mesh:
	assert_true(ResourceLoader.exists(path), "Builder de composição ainda ausente: %s" % path)
	if not ResourceLoader.exists(path):
		return null
	var source: Script = load(path) as Script
	var instance: Object = source.new()
	assert_true(instance is RefCounted and not instance is Node, "Builder puro, sem nós cosméticos/colisão")
	var mesh: Mesh = source.call("build") as Mesh
	assert_not_null(mesh)
	return mesh

func test_beach_single_surface_budget_and_determinism() -> void:
	_contract(BEACH, BEACH_SITES, false)

func test_field_single_surface_budget_and_determinism() -> void:
	_contract(FIELD, FIELD_SITES, true)

func _contract(path: String, sites: Array[Vector2], field: bool) -> void:
	var mesh: Mesh = _build(path)
	if mesh == null:
		return
	assert_eq(mesh.get_surface_count(), 1, "Um batch/material por mapa")
	if mesh.get_surface_count() != 1:
		return
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_gt(vertices.size(), 300, "Conjuntos legíveis, não poucos microdetritos")
	assert_lte(vertices.size(), 6000, "Budget cosmético por mapa")
	assert_eq(mesh.surface_get_primitive_type(0), Mesh.PRIMITIVE_TRIANGLES)
	assert_eq((arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).size(), vertices.size())
	assert_eq((arrays[Mesh.ARRAY_COLOR] as PackedColorArray).size(), vertices.size())
	var repeated: Mesh = (load(path) as Script).call("build") as Mesh
	var again: Array = repeated.surface_get_arrays(0)
	for channel: int in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_COLOR, Mesh.ARRAY_INDEX]:
		assert_eq(arrays[channel], again[channel], "Determinismo do canal %d" % channel)
	for center: Vector2 in sites:
		var min_x: float = INF
		var max_x: float = -INF
		var max_height: float = -INF
		for vertex: Vector3 in vertices:
			if Vector2(vertex.x, vertex.z).distance_to(center) < 1.2:
				min_x = minf(min_x, vertex.x)
				max_x = maxf(max_x, vertex.x)
				max_height = maxf(max_height, vertex.y - _height(vertex.x, vertex.z, field))
		assert_gte(max_x - min_x, 1.3, "Comprimento reconhecível em cada conjunto")
		assert_gte(max_height, 0.4, "Silhueta sobressai dos detritos baixos")
		assert_lte(max_height, 0.65 + 0.001, "Não tapar marcos")

func test_beach_keeps_both_dock_routes_and_clearings() -> void:
	_space(BEACH, BEACH_ROUTES, BEACH_CLEAR, false)

func test_field_keeps_routes_orchard_and_tower_view() -> void:
	_space(FIELD, FIELD_ROUTES, FIELD_CLEAR, true)

func _space(path: String, routes: Array[PackedVector2Array], zones: Array[Vector3], field: bool) -> void:
	var mesh: Mesh = _build(path)
	if mesh == null:
		return
	var faces: PackedVector3Array = mesh.get_faces()
	for route: PackedVector2Array in routes:
		for j: int in route.size() - 1:
			var clearance: float = INF
			for i: int in range(0, faces.size(), 3):
				clearance = minf(clearance, _triangle_segment(_xz(faces[i]), _xz(faces[i + 1]), _xz(faces[i + 2]), route[j], route[j + 1]))
			assert_gte(clearance, 1.8, "Corredor 3.6m livre %s -> %s" % [route[j], route[j + 1]])
	for zone: Vector3 in zones:
		var clearance: float = INF
		for i: int in range(0, faces.size(), 3):
			clearance = minf(clearance, _point_triangle(Vector2(zone.x, zone.y), _xz(faces[i]), _xz(faces[i + 1]), _xz(faces[i + 2])))
		assert_gte(clearance, zone.z, "Clareira preservada: %s" % zone)
	for vertex: Vector3 in faces:
		if not field:
			assert_lt(vertex.x, 25.0, "Faixa molhada/mar sem composição nova")
		assert_true(is_finite(vertex.x) and is_finite(vertex.y) and is_finite(vertex.z))

func test_beach_every_leg_corner_has_independent_terrain_support() -> void:
	_support(BEACH, BEACH_SITES, false)

func test_field_every_leg_corner_has_independent_terrain_support() -> void:
	_support(FIELD, FIELD_SITES, true)

func _support(path: String, sites: Array[Vector2], field: bool) -> void:
	var mesh: Mesh = _build(path)
	if mesh == null:
		return
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var deepest: float = INF
	for vertex: Vector3 in vertices:
		deepest = minf(deepest, vertex.y - _height(vertex.x, vertex.z, field))
	assert_gte(deepest, -0.021, "Não enterrar partes no relevo")
	# Fixtures geométricas independentes: quatro pernas .08x.08, afastadas .55/.25 do centro.
	# Cada um dos 16 cantos inferiores deve tocar o height_at local, não só o centro do prop.
	for center: Vector2 in sites:
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				for corner_x: float in [-0.04, 0.04]:
					for corner_z: float in [-0.04, 0.04]:
						var p: Vector2 = center + Vector2(sx * 0.55 + corner_x, sz * 0.25 + corner_z)
						var nearest: float = INF
						for vertex: Vector3 in vertices:
							if _xz(vertex).distance_to(p) < 0.0001:
								nearest = minf(nearest, absf(vertex.y - _height(p.x, p.y, field)))
						assert_lte(nearest, 0.02, "Canto apoiado: %s" % p)

func test_corridor_checker_catches_old_repair_site_but_accepts_recess() -> void:
	var from: Vector2 = Vector2(7, 0.5)
	var to: Vector2 = Vector2(25, 12)
	assert_lt(_triangle_segment(Vector2(13.9, 3.9), Vector2(14.1, 3.9), Vector2(14, 4.1), from, to), 1.8, "Antigo (14,4) deve ser rejeitado")
	assert_gt(_triangle_segment(Vector2(13.4, 0.9), Vector2(13.6, 0.9), Vector2(13.5, 1.1), from, to), 1.8, "Recuo proposto fica fora da passagem")
	assert_almost_eq(_triangle_segment(Vector2(-3, -3), Vector2(3, -3), Vector2(0, 3), Vector2(-1, 0), Vector2(1, 0)), 0.0, 0.0001, "Triângulo grande cruzando passagem é detectado mesmo com vértices longe")

func _height(x: float, z: float, field: bool) -> float:
	return FieldTerrain.height_at(x, z) if field else BeachTerrain.height_at(x, z)

func _xz(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)

func _inside(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	if absf((b - a).cross(c - a)) < 0.0000001:
		return false
	var s0: float = (b - a).cross(p - a)
	var s1: float = (c - b).cross(p - b)
	var s2: float = (a - c).cross(p - c)
	return (s0 >= 0 and s1 >= 0 and s2 >= 0) or (s0 <= 0 and s1 <= 0 and s2 <= 0)

func _point_triangle(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> float:
	if _inside(p, a, b, c):
		return 0.0
	return minf(p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)), minf(p.distance_to(Geometry2D.get_closest_point_to_segment(p, b, c)), p.distance_to(Geometry2D.get_closest_point_to_segment(p, c, a))))

func _segment_distance(a: Vector2, b: Vector2, p: Vector2, q: Vector2) -> float:
	if Geometry2D.segment_intersects_segment(a, b, p, q) != null:
		return 0.0
	return minf(minf(a.distance_to(Geometry2D.get_closest_point_to_segment(a, p, q)), b.distance_to(Geometry2D.get_closest_point_to_segment(b, p, q))), minf(p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)), q.distance_to(Geometry2D.get_closest_point_to_segment(q, a, b))))

func _triangle_segment(a: Vector2, b: Vector2, c: Vector2, p: Vector2, q: Vector2) -> float:
	if _inside(p, a, b, c) or _inside(q, a, b, c):
		return 0.0
	return minf(_segment_distance(a, b, p, q), minf(_segment_distance(b, c, p, q), _segment_distance(c, a, p, q)))
