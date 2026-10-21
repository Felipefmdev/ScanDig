extends RefCounted
## Staged #157. Malha única, sem nós, colisão, owner ou alterações no terreno.
## A costura quadrada usa a mesma grade de 1 m do terreno em ±46.
## O bordo distante desce a -6, base enterrada das silhuetas de Backdrop.

const TERRAINS: Dictionary = {
	"ruinas": preload("res://gameplay/environment/ruins_terrain.gd"),
	"geleira": preload("res://gameplay/environment/glacier_terrain.gd"),
	"cratera": preload("res://gameplay/environment/crater_terrain.gd"),
}
const RADII: Array[float] = [46.0, 49.0, 52.0, 54.0, 58.0, 61.0, 65.0, 70.0, 75.0]
const PROFILES: Dictionary = {
	"ruinas": [0.0, 1.5, 5.0, 5.0, 5.5, 8.0, 6.0, 3.0, 0.0],
	"geleira": [0.0, 3.0, 9.0, 13.0, 6.0, 16.0, 11.0, 5.0, 0.0],
	"cratera": [0.0, 2.0, 5.0, 5.2, 9.0, 9.2, 6.0, 3.0, 0.0],
}
const COLORS: Dictionary = {
	"ruinas": [Color("#78644b"), Color("#b29369"), Color("#c3a87b")],
	"geleira": [Color("#426e89"), Color("#91becb"), Color("#e3eef1")],
	"cratera": [Color("#28232f"), Color("#514052"), Color("#846659")],
}
const SAMPLES_PER_SIDE: int = 92
const SEED: int = 157
static var _glacial_noise: FastNoiseLite = null


static func build(theme: String) -> Mesh:
	if not TERRAINS.has(theme):
		return null
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var samples: int = SAMPLES_PER_SIDE * 4
	for ring: int in RADII.size() - 1:
		for k: int in samples:
			var next: int = (k + 1) % samples
			var a: Vector3 = _ridge(theme, ring, k)
			var b: Vector3 = _ridge(theme, ring, next)
			var c: Vector3 = _ridge(theme, ring + 1, next)
			var d: Vector3 = _ridge(theme, ring + 1, k)
			var color: Color = _color(theme, ring, k, a, b, c)
			# Ponto interior sob cada face garante winding visível de cima.
			var inside: Vector3 = (a + b + c + d) * 0.25 + Vector3.DOWN * 50.0
			LowPolyMesh.quad(st, a, b, c, d, inside, color)
	_build_near_formations(st, theme)
	# Material deixado ao integrador: ToonKit.vertex_material(false, true).
	# Normais facetadas já são escritas por LowPolyMesh; uma única superfície.
	return st.commit()


static func _square(sample: int) -> Vector2:
	var side: int = sample / SAMPLES_PER_SIDE
	var t: float = float(sample % SAMPLES_PER_SIDE) / float(SAMPLES_PER_SIDE)
	match side:
		0: return Vector2(1.0, -1.0 + 2.0 * t)
		1: return Vector2(1.0 - 2.0 * t, 1.0)
		2: return Vector2(-1.0, 1.0 - 2.0 * t)
		_: return Vector2(-1.0 + 2.0 * t, -1.0)


static func _ridge(theme: String, ring: int, sample: int) -> Vector3:
	var unit: Vector2 = _square(sample)
	var radius: float = RADII[ring]
	var noise: float = 0.0
	if theme == "geleira" and ring >= 2 and ring <= 7:
		noise = _noise().get_noise_2d(unit.x * 24.0 + float(ring) * 9.1, unit.y * 24.0 - float(ring) * 5.7)
		# 0.65 m < metade da menor distância entre anéis: sem cruzamento.
		radius += noise * 0.65
	var p: Vector2 = unit * radius
	var support: Vector2 = unit * 46.0
	var at_edge: float = TERRAINS[theme].height_at(support.x, support.y)
	var t: float = (radius - 46.0) / 29.0
	var base: float = lerpf(at_edge, -6.0, smoothstep(0.0, 1.0, t))
	var angle: float = TAU * float(sample) / float(SAMPLES_PER_SIDE * 4)
	var variation: float = 0.75 + 0.21 * sin(angle * 5.0 + float(SEED) * 0.013) + 0.12 * cos(angle * 11.0)
	var ridge_height: float = float(PROFILES[theme][ring]) * variation
	if theme == "geleira" and ring >= 2 and ring <= 7:
		ridge_height = maxf(0.0, ridge_height * (1.0 + noise * 0.35) + noise * 2.4)
	return Vector3(p.x, base + ridge_height, p.y)


static func _noise() -> FastNoiseLite:
	if _glacial_noise == null:
		_glacial_noise = FastNoiseLite.new()
		_glacial_noise.seed = SEED
		_glacial_noise.frequency = 0.12
		_glacial_noise.fractal_octaves = 2
	return _glacial_noise


static func _color(theme: String, ring: int, sample: int, a: Vector3, b: Vector3, c: Vector3) -> Color:
	var palette: Array = COLORS[theme]
	var color: Color = palette[ring % 3]
	if theme == "geleira":
		var center: Vector3 = (a + b + c) / 3.0
		var patch: float = _noise().get_noise_2d(center.x * 0.85, center.z * 0.85)
		color = (palette[0] as Color).lerp(palette[1], clampf(0.55 + patch * 0.35, 0.3, 0.8))
		var slope: float = absf((b - a).cross(c - a).normalized().y)
		# Neve em faces altas favoráveis, sem alternar a cor de anéis inteiros.
		if center.y > 10.5 and slope > 0.45 and patch > -0.02:
			color = (palette[1] as Color).lerp(palette[2], 0.85)
		return color
	# Faixas largas evitam ruído de cor por triângulo na paisagem.
	return color.darkened(0.035 * float((sample / 12) % 3))


static func _build_near_formations(st: SurfaceTool, theme: String) -> void:
	# Grupos desiguais com intervalos largos; sem repetição de três por lado.
	var anchors: Array[Vector2] = [Vector2(-40, 14), Vector2(-39, 22), Vector2(-40, -21), Vector2(13, -41), Vector2(22, -39), Vector2(40, -12), Vector2(-10, 40)]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED + 907
	for group: int in anchors.size():
		var count: int = 1 + group % 3
		for member: int in count:
			var center: Vector2 = anchors[group] + Vector2(rng.randf_range(-0.9, 0.9), rng.randf_range(-0.9, 0.9))
			var height: float = rng.randf_range(1.5, 4.0) * (1.35 if theme == "geleira" else 1.0)
			var half: Vector2 = Vector2(rng.randf_range(1.7, 2.8), rng.randf_range(1.3, 2.5))
			_formation(st, theme, center, height, half, rng, 6 + (group + member) % 2)


static func _formation(st: SurfaceTool, theme: String, center: Vector2, height: float, half: Vector2, rng: RandomNumberGenerator, sides: int) -> void:
	var bottom: PackedVector3Array = PackedVector3Array()
	var middle: PackedVector3Array = PackedVector3Array()
	var top: PackedVector3Array = PackedVector3Array()
	var phase: float = rng.randf_range(0.0, TAU)
	var lean: Vector2 = Vector2(rng.randf_range(-0.35, 0.35), rng.randf_range(-0.35, 0.35))
	for corner: int in sides:
		var angle: float = phase + TAU * (float(corner) + rng.randf_range(-0.12, 0.12)) / float(sides)
		var offset: Vector2 = Vector2(cos(angle), sin(angle)) * half * rng.randf_range(0.82, 1.12)
		var p: Vector2 = center + offset
		bottom.append(Vector3(p.x, TERRAINS[theme].height_at(p.x, p.y) - 0.12, p.y))
		var mid: Vector2 = center + offset * 0.86 + lean * 0.4
		middle.append(Vector3(mid.x, TERRAINS[theme].height_at(mid.x, mid.y) + height * rng.randf_range(0.44, 0.62), mid.y))
		var cap: Vector2 = center + offset * rng.randf_range(0.38, 0.63) + lean
		top.append(Vector3(cap.x, TERRAINS[theme].height_at(cap.x, cap.y) + height * rng.randf_range(0.78, 1.08), cap.y))
	var inside: Vector3 = Vector3(center.x, TERRAINS[theme].height_at(center.x, center.y) + height * 0.35, center.y)
	var tip: Vector3 = Vector3(center.x + lean.x, TERRAINS[theme].height_at(center.x + lean.x, center.y + lean.y) + height * 1.08, center.y + lean.y)
	var palette: Array = COLORS[theme]
	for corner: int in sides:
		var next: int = (corner + 1) % sides
		var shade: Color = (palette[0] as Color).lerp(palette[1], rng.randf_range(0.12, 0.38))
		LowPolyMesh.quad(st, bottom[corner], bottom[next], middle[next], middle[corner], inside, shade)
		LowPolyMesh.quad(st, middle[corner], middle[next], top[next], top[corner], inside, shade.lightened(0.08))
		var cap_color: Color = palette[2] if theme == "geleira" and corner % 3 != 0 else palette[1]
		LowPolyMesh.tri(st, top[corner], top[next], tip, inside, cap_color)
