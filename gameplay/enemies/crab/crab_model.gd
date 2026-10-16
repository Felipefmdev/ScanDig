extends RefCounted

## Modelo low-poly facetado do caranguejo (#37, docs/art/reference/caranguejo.jpg), partilhado
## pelo Caranguejo, Ermitão e Caranguejo-Rei: carapaça hexagonal facetada com pintas (shader
## toon, material "carapace"), boca vermelho-escura, olhos esbugalhados em pedúnculos, UMA pinça
## gigante levantada (lado esquerdo, -X, como na referência), uma pinça pequena e 4 patas
## finas e pontiagudas de cada lado.
## Frente = -Z, cima = +Y; medidas do caranguejo normal (~0,6 m de carapaça).
## O alfa da cor dos vértices é a máscara do desgaste: 0 = sem pintas (olhos, boca).
##
## Uso: const CrabModel = preload("res://gameplay/enemies/crab/crab_model.gd")
##   var m: Dictionary = CrabModel.meshes(CrabModel.PALETTE_CRAB)   # cache por paleta
##   m.body / m.legs_left / m.legs_right / m.claw_small / m.claw_big (ArrayMesh)
## Pivôs (onde pôr os nós que animam): PIVOT_LEGS_LEFT/RIGHT, PIVOT_CLAW_SMALL, PIVOT_CLAW_BIG.

const PIVOT_LEGS_LEFT: Vector3 = Vector3(-0.2, 0.2, 0.02)
const PIVOT_LEGS_RIGHT: Vector3 = Vector3(0.2, 0.2, 0.02)
const PIVOT_CLAW_SMALL: Vector3 = Vector3(0.24, 0.2, -0.15)
const PIVOT_CLAW_BIG: Vector3 = Vector3(-0.25, 0.22, -0.1)
## As pinças são desenhadas para +X/-X e espelhadas para o lado certo.
const MIRROR_X: Transform3D = Transform3D(Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)), Vector3.ZERO)

## Cores em sRGB (o material usa vertex_color_srgb = true).
const PALETTE_CRAB: Dictionary = {
	"name": "crab",
	"shell": Color(0.9, 0.42, 0.16),
	"leg": Color(0.84, 0.36, 0.13),
	"claw": Color(0.92, 0.45, 0.17),
	"mouth": Color(0.6, 0.1, 0.08),
	"mouth_dark": Color(0.36, 0.04, 0.04),
	"eye": Color(0.98, 0.97, 0.93),
	"pupil": Color(0.04, 0.04, 0.05),
}
const PALETTE_HERMIT: Dictionary = {
	"name": "hermit",
	"shell": Color(0.78, 0.44, 0.56),
	"leg": Color(0.58, 0.36, 0.52),
	"claw": Color(0.82, 0.48, 0.58),
	"mouth": Color(0.55, 0.1, 0.12),
	"mouth_dark": Color(0.3, 0.04, 0.06),
	"eye": Color(0.98, 0.97, 0.93),
	"pupil": Color(0.04, 0.04, 0.05),
}
const PALETTE_KING: Dictionary = {
	"name": "king",
	"shell": Color(0.86, 0.36, 0.1),
	"leg": Color(0.78, 0.3, 0.08),
	"claw": Color(0.9, 0.42, 0.13),
	"mouth": Color(0.5, 0.06, 0.06),
	"mouth_dark": Color(0.28, 0.02, 0.03),
	"eye": Color(0.98, 0.97, 0.93),
	"pupil": Color(0.04, 0.04, 0.05),
}

static var _cache: Dictionary = {}


## Malhas (com normais do contorno) de uma paleta; construídas uma vez e partilhadas.
static func meshes(palette: Dictionary) -> Dictionary:
	var key: String = palette["name"]
	if _cache.has(key):
		return _cache[key]
	var out: Dictionary = {}
	var st: SurfaceTool = _begin()
	body(st, Transform3D.IDENTITY, palette)
	out["body"] = ToonKit.commit(st)
	for side: float in [-1.0, 1.0]:
		st = _begin()
		legs(st, Transform3D.IDENTITY, side, palette)
		out["legs_left" if side < 0.0 else "legs_right"] = ToonKit.commit(st)
	st = _begin()
	small_claw(st, MIRROR_X, palette)
	out["claw_small"] = ToonKit.commit(st)
	st = _begin()
	big_claw(st, MIRROR_X, palette)
	out["claw_big"] = ToonKit.commit(st)
	_cache[key] = out
	return out


## Material toon da carapaça (pintas) para cores por vértice. Um por instância (flash de dano).
## spots_scale maior = pintas mais pequenas (o rei, 3x maior, usa ~6).
static func make_material(spots_scale: float = 20.0) -> ShaderMaterial:
	var mat: ShaderMaterial = ToonKit.material(&"carapace")
	mat.set_shader_parameter(&"albedo_color", Color.WHITE)
	mat.set_shader_parameter(&"spots_scale", spots_scale)
	return mat


static func _begin() -> SurfaceTool:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


# ---------------------------------------------------------------------------
# Peças (xf = transformação aplicada a todos os pontos, relativa ao pivô da peça)
# ---------------------------------------------------------------------------

## Carapaça + boca + olhos.
static func body(st: SurfaceTool, xf: Transform3D, p: Dictionary) -> void:
	var shell: Color = p["shell"]
	# Carapaça hexagonal (bico nos lados ±X, aresta plana à frente para a boca)
	gem(st, xf, Vector3(0.0, 0.0, 0.0), Basis.IDENTITY, [
		Vector3(0.14, 0.24, 0.17),
		Vector3(0.24, 0.34, 0.235),
		Vector3(0.32, 0.25, 0.17),
	], 6, 0.1, 0.37, shell, 0.012, 11)
	# Boca vermelho-escura: lábio de cima, duas placas e o fundo
	var mouth: Color = _clean(p["mouth"])
	var mouth_dark: Color = _clean(p["mouth_dark"])
	var face: Basis = Basis(Vector3.RIGHT, -PI * 0.5)
	gem(st, xf, Vector3(0.0, 0.2, -0.19), face, [
		Vector3(0.0, 0.125, 0.07),
	], 6, -0.02, 0.035, mouth_dark, 0.006, 41)
	for side: float in [-1.0, 1.0]:
		gem(st, xf, Vector3(0.05 * side, 0.19, -0.207), face * Basis(Vector3.UP, 0.25 * side), [
			Vector3(0.0, 0.062, 0.058),
		], 5, -0.012, 0.03, mouth, 0.005, 43 + int(side))
	gem(st, xf, Vector3(0.0, 0.25, -0.207), face, [
		Vector3(0.0, 0.12, 0.03),
	], 6, -0.012, 0.028, mouth, 0.005, 47)
	# Olhos esbugalhados em pedúnculos
	for side: float in [-1.0, 1.0]:
		var base: Vector3 = Vector3(0.075 * side, 0.32, -0.1)
		var top: Vector3 = Vector3(0.1 * side, 0.47, -0.13)
		_prism(st, xf, base, top, 0.017, 0.014, 5, shell)
		var eye_c: Vector3 = top + Vector3(0.0, 0.04, 0.0)
		gem(st, xf, eye_c, Basis.IDENTITY, [
			Vector3(-0.034, 0.036, 0.036),
			Vector3(0.0, 0.052, 0.052),
			Vector3(0.034, 0.036, 0.036),
		], 7, -0.052, 0.052, _clean(p["eye"]), 0.0, 3)
		# Pupila: disco virado para a frente, um pouco para dentro (olhar vesgo)
		gem(st, xf, eye_c + Vector3(-0.008 * side, 0.006, -0.042), Basis(Vector3.RIGHT, -PI * 0.5), [
			Vector3(-0.006, 0.021, 0.021),
			Vector3(0.004, 0.023, 0.023),
		], 6, -0.012, 0.012, _clean(p["pupil"]), 0.0, 5)


## 4 patas finas de um lado, relativas ao pivô (PIVOT_LEGS_*): sobem até ao joelho e descem
## em ponta até ao chão (y = -0.2 relativo ao pivô).
## thick: multiplica a grossura (o rei tem patas mais grossas, #61).
static func legs(st: SurfaceTool, xf: Transform3D, side: float, p: Dictionary, thick: float = 1.0) -> void:
	var leg: Color = p["leg"]
	var zs: Array[float] = [-0.1, 0.0, 0.09, 0.18]
	var yaws: Array[float] = [-0.55, -0.18, 0.18, 0.55]
	for k: int in zs.size():
		var d: Vector3 = Vector3(side * cos(yaws[k]), 0.0, sin(yaws[k]))
		var hip: Vector3 = Vector3(0.0, 0.0, zs[k])
		var knee: Vector3 = hip + d * 0.2 + Vector3(0.0, 0.13, 0.0)
		var foot: Vector3 = hip + d * 0.38 + Vector3(0.0, -0.2, 0.0)
		_prism(st, xf, hip, knee, 0.024 * thick, 0.02 * thick, 5, leg)
		_prism(st, xf, knee, foot, 0.021 * thick, 0.0, 5, leg)


## Pinça pequena, baixa e à frente, relativa ao pivô (desenhada para -X; o modelo espelha-a).
static func small_claw(st: SurfaceTool, xf: Transform3D, p: Dictionary) -> void:
	var claw: Color = p["claw"]
	var wrist: Vector3 = Vector3(-0.07, -0.04, -0.1)
	_prism(st, xf, Vector3.ZERO, wrist, 0.03, 0.026, 5, claw)
	var palm_c: Vector3 = Vector3(-0.08, -0.05, -0.16)
	gem(st, xf, palm_c, Basis(Vector3.RIGHT, -PI * 0.5), [
		Vector3(-0.03, 0.04, 0.034),
		Vector3(0.02, 0.048, 0.04),
	], 5, -0.06, 0.06, claw, 0.004, 21)
	_prism(st, xf, palm_c + Vector3(0.02, 0.02, -0.05), palm_c + Vector3(0.045, 0.03, -0.14), 0.024, 0.0, 4, claw)
	_prism(st, xf, palm_c + Vector3(-0.015, -0.015, -0.05), palm_c + Vector3(0.01, -0.03, -0.12), 0.02, 0.0, 4, claw)


## Pinça gigante levantada, relativa ao pivô (desenhada para +X; o modelo espelha-a): braço,
## mão facetada e dois dedos para cima, abertos, com dentes no lado de dentro.
static func big_claw(st: SurfaceTool, xf: Transform3D, p: Dictionary) -> void:
	var claw: Color = p["claw"]
	var elbow: Vector3 = Vector3(0.14, 0.06, -0.04)
	var wrist: Vector3 = Vector3(0.2, 0.24, -0.06)
	_prism(st, xf, Vector3.ZERO, elbow, 0.042, 0.04, 6, claw)
	_prism(st, xf, elbow, wrist, 0.042, 0.05, 6, claw)
	var palm: Vector3 = Vector3(0.22, 0.37, -0.06)
	gem(st, xf, palm, Basis(Vector3.FORWARD, -0.12), [
		Vector3(-0.09, 0.085, 0.06),
		Vector3(0.0, 0.115, 0.078),
		Vector3(0.08, 0.1, 0.068),
	], 6, -0.135, 0.11, claw, 0.008, 31)
	# Dedo fixo (fora) e dedo móvel (dentro), em dois troços a curvar para dentro
	var o0: Vector3 = Vector3(0.29, 0.45, -0.06)
	var o1: Vector3 = Vector3(0.31, 0.6, -0.06)
	var o2: Vector3 = Vector3(0.25, 0.73, -0.06)
	_prism(st, xf, o0, o1, 0.055, 0.04, 5, claw)
	_prism(st, xf, o1, o2, 0.04, 0.0, 5, claw)
	var i0: Vector3 = Vector3(0.15, 0.45, -0.06)
	var i1: Vector3 = Vector3(0.11, 0.57, -0.06)
	var i2: Vector3 = Vector3(0.16, 0.67, -0.06)
	_prism(st, xf, i0, i1, 0.045, 0.032, 5, claw)
	_prism(st, xf, i1, i2, 0.032, 0.0, 5, claw)
	# Dentes (serrilha) virados para o meio
	for t: float in [0.3, 0.65]:
		var a: Vector3 = o0.lerp(o1, t) if t < 0.5 else o1.lerp(o2, t - 0.4)
		_prism(st, xf, a, a + Vector3(-0.055, 0.015, 0.0), 0.016, 0.0, 4, claw)
		var b: Vector3 = i0.lerp(i1, t) if t < 0.5 else i1.lerp(i2, t - 0.4)
		_prism(st, xf, b, b + Vector3(0.05, 0.02, 0.0), 0.014, 0.0, 4, claw)


# ---------------------------------------------------------------------------
# Primitivas
# ---------------------------------------------------------------------------

## Sólido convexo facetado: anéis (y, raio x, raio z) no eixo local Y de `basis`, com bicos em
## y_bottom e y_top. jitter (m) desalinha os vértices para as facetas não ficarem regulares.
static func gem(st: SurfaceTool, xf: Transform3D, center: Vector3, basis: Basis, rings: Array,
		sides: int, y_bottom: float, y_top: float, color: Color, jitter: float, seed_value: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var pts: Array[PackedVector3Array] = []
	for r: Vector3 in rings:
		var ring: PackedVector3Array = PackedVector3Array()
		for i: int in sides:
			var ang: float = TAU * float(i) / float(sides)
			var j: float = rng.randf_range(-jitter, jitter)
			var local: Vector3 = Vector3(cos(ang) * (r.y + j), r.x + rng.randf_range(-jitter, jitter) * 0.5, sin(ang) * (r.z + j))
			ring.append(xf * (center + basis * local))
		pts.append(ring)
	var bottom: Vector3 = xf * (center + basis * Vector3(0.0, y_bottom, 0.0))
	var top: Vector3 = xf * (center + basis * Vector3(0.0, y_top, 0.0))
	var inside: Vector3 = xf * center
	for i: int in sides:
		var j: int = (i + 1) % sides
		LowPolyMesh.tri(st, bottom, pts[0][i], pts[0][j], inside, color)
		for k: int in pts.size() - 1:
			LowPolyMesh.quad(st, pts[k][i], pts[k][j], pts[k + 1][j], pts[k + 1][i], inside, color)
		LowPolyMesh.tri(st, top, pts[pts.size() - 1][j], pts[pts.size() - 1][i], inside, color)


static func _prism(st: SurfaceTool, xf: Transform3D, a: Vector3, b: Vector3, r0: float, r1: float, sides: int, color: Color) -> void:
	var s: float = absf(xf.basis.get_scale().x)
	LowPolyMesh.prism(st, xf * a, xf * b, r0 * s, r1 * s, sides, color)


static func _box(st: SurfaceTool, xf: Transform3D, center: Vector3, size: Vector3, basis: Basis, color: Color) -> void:
	var s: float = absf(xf.basis.get_scale().x)
	LowPolyMesh.box(st, xf * center, size * s, xf.basis.orthonormalized() * basis, color)


## Cor sem desgaste (alfa 0 = o shader não lhe põe pintas).
static func _clean(c: Color) -> Color:
	return Color(c.r, c.g, c.b, 0.0)
