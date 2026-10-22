extends RefCounted

## #161: apoios rurais baixos em um batch, sem modificar caminhos ou objetivos.
## Palha/ripas seguem a linguagem dos fardos existentes; nenhum item remodelado.
const WOOD: Color = Color("#795539")
const WOOD_DARK: Color = Color("#503d2e")
const STRAW: Color = Color("#c7a95c")
const STRAW_DARK: Color = Color("#8e713c")
const CREAM: Color = Color("#e1d0a3")

static func build() -> Mesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Quintal: bancada baixa, longe dos três fardos e do acesso à árvore reativa.
	var center: Vector2 = Vector2(-10.5, 11.5)
	var top: float = _frame(st, center, 0.38)
	_slats(st, center, top, WOOD)
	for z: float in [-0.31, 0.31]:
		LowPolyMesh.box(st, Vector3(center.x, top + 0.065, center.y + z), Vector3(1.4, 0.09, 0.065), Basis.IDENTITY, WOOD_DARK)
	LowPolyMesh.box(st, Vector3(center.x - 0.12, top + 0.04, center.y), Vector3(0.58, 0.025, 0.44), Basis.IDENTITY, CREAM)
	for x: float in [-0.32, -0.20, -0.08, 0.04]:
		LowPolyMesh.box(st, Vector3(center.x + x, top + 0.057, center.y), Vector3(0.025, 0.012, 0.44), Basis.IDENTITY, STRAW_DARK)
	# Poço: reserva de madeira gasta ao lado de fora da clareira, sem outro balde/relíquia.
	center = Vector2(-10.0, -3.7)
	top = _frame(st, center, 0.27)
	_slats(st, center, top, WOOD_DARK)
	for i: int in 4:
		LowPolyMesh.box(st, Vector3(center.x, top + 0.06 + float(i) * 0.055, center.y - 0.23 + float(i) * 0.14), Vector3(1.34 - float(i % 2) * 0.20, 0.065, 0.14), Basis.IDENTITY, WOOD.lightened(float(i % 2) * 0.10))
	for x: float in [-0.38, 0.38]:
		LowPolyMesh.box(st, Vector3(center.x + x, top + 0.235, center.y), Vector3(0.04, 0.025, 0.62), Basis.IDENTITY, CREAM)
	# Margem da lavoura: feixe de palha amarrado sobre estrado, sem aumentar torre/círculo.
	center = Vector2(8.0, -20.0)
	top = _frame(st, center, 0.18)
	_slats(st, center, top, WOOD_DARK)
	LowPolyMesh.box(st, Vector3(center.x, top + 0.17, center.y), Vector3(1.32, 0.28, 0.57), Basis.IDENTITY, STRAW)
	for x: float in [-0.38, 0.38]:
		LowPolyMesh.box(st, Vector3(center.x + x, top + 0.17, center.y), Vector3(0.05, 0.30, 0.59), Basis.IDENTITY, STRAW_DARK)
	for z: float in [-0.20, -0.07, 0.08, 0.21]:
		LowPolyMesh.box(st, Vector3(center.x, top + 0.315, center.y + z), Vector3(1.25, 0.014, 0.025), Basis.IDENTITY, CREAM)
	return ToonKit.commit(st)

static func _frame(st: SurfaceTool, center: Vector2, rise: float) -> float:
	var ground_max: float = -INF
	for x: float in [-0.70, 0.70]:
		for z: float in [-0.36, 0.36]:
			ground_max = maxf(ground_max, FieldTerrain.height_at(center.x + x, center.y + z))
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
		bottom.append(Vector3(p.x, FieldTerrain.height_at(p.x, p.y) - 0.01, p.y))
		upper.append(Vector3(p.x, top, p.y))
	var inside: Vector3 = Vector3(at.x, (bottom[0].y + top) * 0.5, at.y)
	for i: int in 4:
		var j: int = (i + 1) % 4
		LowPolyMesh.quad(st, bottom[i], bottom[j], upper[j], upper[i], inside, WOOD)
	LowPolyMesh.quad(st, bottom[3], bottom[2], bottom[1], bottom[0], inside, WOOD_DARK)
	LowPolyMesh.quad(st, upper[0], upper[1], upper[2], upper[3], inside, WOOD)

static func _slats(st: SurfaceTool, center: Vector2, top: float, color: Color) -> void:
	for i: int in 7:
		LowPolyMesh.box(st, Vector3(center.x - 0.6 + float(i) * 0.20, top, center.y), Vector3(0.182, 0.055, 0.68), Basis.IDENTITY, color.lightened(float(i % 2) * 0.08))
