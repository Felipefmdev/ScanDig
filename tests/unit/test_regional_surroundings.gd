extends GutTest

const GENERATOR: String = "res://gameplay/environment/regional_surroundings.gd"
const THEMES: Array[String] = ["ruinas", "geleira", "cratera"]


func test_intermediate_band_exists_for_each_region() -> void:
	assert_true(FileAccess.file_exists(GENERATOR), "Faixa intermediária regional ainda inexistente")
	if not FileAccess.file_exists(GENERATOR):
		return
	var generator: Script = load(GENERATOR)
	for theme: String in THEMES:
		var mesh: Mesh = generator.call("build", theme)
		assert_not_null(mesh)
		assert_eq(mesh.get_surface_count(), 1, "Uma superfície por região")
		var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var inside: int = 0
		var outside: int = 0
		var invalid: int = 0
		var unsupported: int = 0
		var buried_roots: int = 0
		for p: Vector3 in vertices:
			var edge: float = maxf(absf(p.x), absf(p.z))
			if edge < 32.999 or edge > 75.001 or not p.is_finite():
				invalid += 1
			if edge <= 46.0:
				inside += 1
				var support: float = _terrain(theme).call("height_at", p.x, p.z)
				if p.y < support - 0.121:
					unsupported += 1
				if is_equal_approx(p.y, support - 0.12):
					buried_roots += 1
			else:
				outside += 1
		assert_eq(invalid, 0, "Todos os vértices entre 33 e 75 m")
		assert_gt(inside, 30, "Formações apoiadas no relevo existente")
		assert_gt(outside, 100, "Continuidade até o horizonte")
		assert_eq(unsupported, 0, "Sem formações abaixo do apoio analítico")
		assert_gt(buried_roots, 30, "Raízes de formações realmente enterradas no terreno")


func test_seam_matches_terrain_and_outer_base_is_continuous() -> void:
	if not FileAccess.file_exists(GENERATOR):
		pending("Gerador ausente: coberto pelo teste de existência")
		return
	var generator: Script = load(GENERATOR)
	for theme: String in THEMES:
		var mesh: Mesh = generator.call("build", theme)
		var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var seams: int = 0
		var outer: int = 0
		var worst: float = 0.0
		for p: Vector3 in vertices:
			var edge: float = maxf(absf(p.x), absf(p.z))
			if is_equal_approx(edge, 46.0):
				worst = maxf(worst, absf(p.y - _terrain(theme).call("height_at", p.x, p.z)))
				seams += 1
			if is_equal_approx(edge, 75.0):
				worst = maxf(worst, absf(p.y + 6.0))
				outer += 1
		assert_gt(seams, 30)
		assert_gt(outer, 30)
		assert_lt(worst, 0.001, "Costura coincide com terreno; fim enterrado na base do horizonte -6")


func test_determinism_valid_faces_and_distinct_profiles() -> void:
	if not FileAccess.file_exists(GENERATOR):
		pending("Gerador ausente")
		return
	var generator: Script = load(GENERATOR)
	var previous: PackedVector3Array = PackedVector3Array()
	for theme: String in THEMES:
		var a: Mesh = generator.call("build", theme)
		var b: Mesh = generator.call("build", theme)
		var vertices: PackedVector3Array = a.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		assert_eq(vertices, b.surface_get_arrays(0)[Mesh.ARRAY_VERTEX], "Determinismo completo")
		assert_eq(a.surface_get_arrays(0)[Mesh.ARRAY_COLOR], b.surface_get_arrays(0)[Mesh.ARRAY_COLOR])
		assert_ne(vertices, previous, "Perfis regionais distintos")
		previous = vertices
		var degenerate: int = 0
		for i: int in range(0, vertices.size(), 3):
			if (vertices[i + 1] - vertices[i]).cross(vertices[i + 2] - vertices[i]).length_squared() < 0.000001:
				degenerate += 1
		assert_eq(degenerate, 0)
	assert_null(generator.call("build", "campo"), "Temas fora do escopo não recebem malha")


func _terrain(theme: String) -> Script:
	var names: Dictionary = {"ruinas": "ruins", "geleira": "glacier", "cratera": "crater"}
	return load("res://gameplay/environment/%s_terrain.gd" % names[theme])
