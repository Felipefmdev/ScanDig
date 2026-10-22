extends RefCounted

## #161: três conjuntos baixos de trabalho; vértices em mundo e uma única superfície.
## Apenas ripas, cavaletes e corda da linguagem existente. Nenhum nó/interação/colisor.
const WOOD: Color = Color("#8c6240")
const WOOD_DARK: Color = Color("#624932")
const ROPE: Color = Color("#c7ab79")
const CREAM: Color = Color("#f2dfb6")
const TEAL: Color = Color("#398c87")

static func build() -> Mesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Posto: apoio aberto com pano gasto, separado da banca e da mesa já existente.
	var center: Vector2 = Vector2(10.8, -3.8)
	var top: float = _frame(st, center, 0.41)
	_slats(st, center, top, 7, WOOD)
	LowPolyMesh.box(st, Vector3(center.x - 0.10, top + 0.035, center.y), Vector3(0.94, 0.015, 0.48), Basis.IDENTITY, TEAL)
	for x: float in [-0.35, 0.03]:
		LowPolyMesh.box(st, Vector3(center.x + x, top + 0.045, center.y), Vector3(0.09, 0.012, 0.48), Basis.IDENTITY, CREAM)
	_coil(st, Vector3(center.x + 0.49, top + 0.05, center.y + 0.03), 0.105)
	# Cais: madeiras em reparo, recuadas também da reta banca -> cais (não usar 14,4).
	center = Vector2(13.5, 1.0)
	top = _frame(st, center, 0.35)
	_slats(st, center, top, 5, WOOD_DARK)
	for i: int in 3:
		LowPolyMesh.box(st, Vector3(center.x, top + 0.055 + float(i) * 0.045, center.y - 0.20 + float(i) * 0.18), Vector3(1.34 - float(i) * 0.13, 0.055, 0.12), Basis.IDENTITY, WOOD.lightened(float(i) * 0.06))
	for x: float in [-0.40, 0.34]:
		LowPolyMesh.box(st, Vector3(center.x + x, top + 0.145, center.y), Vector3(0.045, 0.035, 0.53), Basis.IDENTITY, ROPE)
	# Baixio: grade de secagem vazia no seco; sem peixes, garrafas, brilho ou pista falsa.
	center = Vector2(23.0, -0.4)
	top = _frame(st, center, 0.42)
	_slats(st, center, top, 5, WOOD.lightened(0.14))
	for z: float in [-0.32, 0.32]:
		LowPolyMesh.box(st, Vector3(center.x, top + 0.06, center.y + z), Vector3(1.4, 0.07, 0.07), Basis.IDENTITY, WOOD_DARK)
	for x: float in [-0.56, 0.56]:
		LowPolyMesh.box(st, Vector3(center.x + x, top + 0.06, center.y), Vector3(0.06, 0.07, 0.64), Basis.IDENTITY, ROPE)
	return ToonKit.commit(st)

static func _frame(st: SurfaceTool, center: Vector2, rise: float) -> float:
	var ground_max: float = -INF
	for x: float in [-0.70, 0.70]:
		for z: float in [-0.36, 0.36]:
			ground_max = maxf(ground_max, BeachTerrain.height_at(center.x + x, center.y + z))
	var top: float = ground_max + rise
	for x: float in [-0.55, 0.55]:
		for z: float in [-0.25, 0.25]:
			_leg(st, center + Vector2(x, z), top)
	for x: float in [-0.55, 0.55]:
		LowPolyMesh.box(st, Vector3(center.x + x, top - 0.025, center.y), Vector3(0.10, 0.07, 0.72), Basis.IDENTITY, WOOD_DARK)
	return top

static func _leg(st: SurfaceTool, at: Vector2, top: float) -> void:
	var bottom: Array[Vector3] = []
	var upper: Array[Vector3] = []
	for offset: Vector2 in [Vector2(-0.04, -0.04), Vector2(0.04, -0.04), Vector2(0.04, 0.04), Vector2(-0.04, 0.04)]:
		var p: Vector2 = at + offset
		bottom.append(Vector3(p.x, BeachTerrain.height_at(p.x, p.y) - 0.01, p.y))
		upper.append(Vector3(p.x, top, p.y))
	var inside: Vector3 = Vector3(at.x, (bottom[0].y + top) * 0.5, at.y)
	for i: int in 4:
		var j: int = (i + 1) % 4
		LowPolyMesh.quad(st, bottom[i], bottom[j], upper[j], upper[i], inside, WOOD)
	LowPolyMesh.quad(st, bottom[3], bottom[2], bottom[1], bottom[0], inside, WOOD_DARK)
	LowPolyMesh.quad(st, upper[0], upper[1], upper[2], upper[3], inside, WOOD)

static func _slats(st: SurfaceTool, center: Vector2, top: float, count: int, color: Color) -> void:
	var width: float = 1.4 / float(count)
	for i: int in count:
		LowPolyMesh.box(st, Vector3(center.x - 0.7 + width * (float(i) + 0.5), top, center.y), Vector3(width - 0.018, 0.055, 0.68), Basis.IDENTITY, color.lightened(float(i % 2) * 0.06))

static func _coil(st: SurfaceTool, center: Vector3, radius: float) -> void:
	for i: int in 16:
		var a: float = float(i) * TAU / 16.0
		var b: float = float(i + 1) * TAU / 16.0
		LowPolyMesh.prism(st, center + Vector3(cos(a), 0, sin(a)) * radius, center + Vector3(cos(b), 0, sin(b)) * radius, 0.014, 0.014, 4, ROPE)
