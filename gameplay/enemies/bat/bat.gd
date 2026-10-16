class_name Bat
extends Crow

## Morcego das Ruínas (#42): como o corvo (círculos + mergulho que morde), mas voa baixo, rápido
## e às voltas, e foge da luz: o flash da Lanterna de Magnésio põe-no a fugir (grupo
## LanternFlash.GROUP_FLEES).

const FUR: Color = Color("#4a2f33")
const WING: Color = Color("#8a3a2a")
const EAR_PINK: Color = Color("#c9884a")
const FANG: Color = Color(0.98, 0.97, 0.92)
const BAT_EYE: Color = Color("#f2ecd2")
const PUPIL: Color = Color(0.08, 0.07, 0.06)
const ROCK: Color = Color("#7a6a58")


func _ready() -> void:
	super._ready()
	add_to_group(LanternFlash.GROUP_FLEES)
	circle_height = 4.2
	circle_radius = 4.8
	circle_time_min = 5.0
	circle_time_max = 8.0
	peck_damage = 5.0


func _build_model() -> void:
	var mat: ShaderMaterial = ToonKit.vertex_material(true, true)
	_register_flash_material(mat)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyMesh.prism(st, Vector3(0.0, 0.0, 0.12), Vector3(0.0, 0.02, -0.1), 0.08, 0.09, 6, FUR)
	LowPolyMesh.box(st, Vector3(0.0, 0.06, -0.15), Vector3(0.13, 0.12, 0.12), Basis.IDENTITY, FUR)
	for side: float in [-1.0, 1.0]:
		# Orelhas enormes (referência morcego.jpg): exterior de pelo, interior laranja
		LowPolyMesh.prism(st, Vector3(0.05 * side, 0.1, -0.14), Vector3(0.13 * side, 0.32, -0.13), 0.06, 0.0, 4, FUR)
		LowPolyMesh.prism(st, Vector3(0.05 * side, 0.11, -0.155), Vector3(0.125 * side, 0.29, -0.145), 0.042, 0.0, 4, EAR_PINK)
		# Olhos esbugalhados, brancos com pupila
		LowPolyMesh.prism(st, Vector3(0.042 * side, 0.09, -0.205), Vector3(0.042 * side, 0.09, -0.235), 0.034, 0.034, 8, BAT_EYE)
		LowPolyMesh.box(st, Vector3(0.042 * side, 0.095, -0.237), Vector3(0.018, 0.018, 0.006), Basis.IDENTITY, PUPIL)
		LowPolyMesh.prism(st, Vector3(0.02 * side, 0.02, -0.21), Vector3(0.02 * side, -0.02, -0.21), 0.01, 0.0, 3, Color(FANG.r, FANG.g, FANG.b, 0.0))
	# Pedra segura por cima da cabeça, como na referência
	LowPolyMesh.prism(st, Vector3(0.0, 0.13, 0.0), Vector3(0.0, 0.23, 0.0), 0.06, 0.05, 6, ROCK)
	add_child(LowPolyMesh.commit(st, "Body", mat))
	_wing_left = _build_bat_wing(-1.0, mat)
	_wing_right = _build_bat_wing(1.0, mat)


func _build_bat_wing(side: float, mat: Material) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.name = "WingLeft" if side < 0.0 else "WingRight"
	pivot.position = Vector3(0.07 * side, 0.04, 0.0)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Asa membranosa em três "dedos" serrilhados
	for k: int in 3:
		var z0: float = -0.06 + 0.07 * float(k)
		LowPolyMesh.box(st, Vector3((0.13 + 0.05 * k) * side, 0.0, z0), Vector3(0.24, 0.015, 0.09), Basis(Vector3.UP, (0.2 * k - 0.2) * side), WING)
	pivot.add_child(LowPolyMesh.commit(st, "Mesh", mat))
	add_child(pivot)
	return pivot
