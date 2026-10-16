class_name Bat
extends Crow

## Morcego das Ruínas (#42): como o corvo (círculos + mergulho que morde), mas voa baixo, rápido
## e às voltas, e foge da luz: o flash da Lanterna de Magnésio põe-no a fugir (grupo
## LanternFlash.GROUP_FLEES).

const FUR: Color = Color(0.25, 0.2, 0.22)
const WING: Color = Color(0.35, 0.25, 0.3)
const EAR_PINK: Color = Color(0.85, 0.5, 0.55)
const FANG: Color = Color(0.98, 0.97, 0.92)


func _ready() -> void:
	super._ready()
	add_to_group(LanternFlash.GROUP_FLEES)


func _build_model() -> void:
	var mat: ShaderMaterial = LowPolyMesh.make_material()
	_register_flash_material(mat)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyMesh.prism(st, Vector3(0.0, 0.0, 0.12), Vector3(0.0, 0.02, -0.1), 0.08, 0.09, 6, FUR)
	LowPolyMesh.box(st, Vector3(0.0, 0.06, -0.15), Vector3(0.13, 0.12, 0.12), Basis.IDENTITY, FUR)
	for side: float in [-1.0, 1.0]:
		LowPolyMesh.prism(st, Vector3(0.05 * side, 0.1, -0.15), Vector3(0.08 * side, 0.22, -0.14), 0.035, 0.0, 4, EAR_PINK)
		LowPolyMesh.box(st, Vector3(0.04 * side, 0.08, -0.215), Vector3(0.035, 0.035, 0.02), Basis.IDENTITY, Color(0.98, 0.9, 0.3, 0.0))
		LowPolyMesh.prism(st, Vector3(0.02 * side, 0.02, -0.21), Vector3(0.02 * side, -0.02, -0.21), 0.01, 0.0, 3, Color(FANG.r, FANG.g, FANG.b, 0.0))
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
