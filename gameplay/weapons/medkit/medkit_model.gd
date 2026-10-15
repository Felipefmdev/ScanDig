@tool
extends Node3D

## Kit médico low-poly (docs/art/reference/kit_medico.jpg, #37): caixa de metal pintada de
## vermelho (tinta lascada e ferrugem), tampa com junta, cantoneiras, dois fechos e pega de metal
## escuro, disco branco com cruz vermelha e pontas de ligadura a sair pela junta.
## Origem no centro da base; frente (cruz) em +Z. ~0,30 × 0,24 × 0,16 m.

const ToolMesh = preload("res://gameplay/weapons/tool_mesh.gd")

const HALF_X: float = 0.15
const HALF_Z: float = 0.075
const CHAMFER: float = 0.022
const BODY_TOP: float = 0.125
const LID_Y0: float = 0.135
const LID_TOP: float = 0.185

const RED: Color = Color(0.86, 0.86, 0.86)
const SEAM: Color = Color(0.55, 0.5, 0.5)
const CORNER: Color = Color(0.82, 0.78, 0.78)
const IRON: Color = Color(1.0, 1.0, 1.0)
const DECAL_WHITE: Color = Color(0.93, 0.9, 0.84)
const DECAL_RED: Color = Color(0.8, 0.12, 0.08)
const BANDAGE: Color = Color(0.95, 0.93, 0.86)


func _ready() -> void:
	ToolMesh.clear(self)
	_build_case()
	_build_iron()
	_build_decals()


func _build_case() -> void:
	var st: SurfaceTool = ToolMesh.begin()
	_chamfer_box(st, 0.012, BODY_TOP, HALF_X, HALF_Z, CHAMFER, 0.0, RED)
	_chamfer_box(st, BODY_TOP - 0.004, LID_Y0 + 0.004, HALF_X + 0.005, HALF_Z + 0.005, CHAMFER, 0.0, SEAM)
	_chamfer_box(st, LID_Y0, LID_TOP, HALF_X, HALF_Z, CHAMFER, 0.014, RED)
	# Cantoneiras pintadas nos 8 cantos: para-choques chanfrados que abraçam o canto (3 faces).
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var corner: Vector3 = Vector3(sx * (HALF_X - 0.014), 0.0, sz * (HALF_Z - 0.014))
			_chamfer_box(st, 0.0, 0.036, 0.02, 0.02, 0.008, 0.0, CORNER, corner)
			_chamfer_box(st, LID_TOP - 0.026, LID_TOP + 0.002, 0.019, 0.019, 0.008, 0.005, CORNER,
				corner - Vector3(sx, 0.0, sz) * 0.004)
	var mat: ShaderMaterial = ToolMesh.prop_material(&"paint_red", Color(0.66, 0.1, 0.07))
	mat.set_shader_parameter(&"chip_amount", 0.5)
	ToolMesh.part(self, "Case", st, mat)


func _build_iron() -> void:
	var st: SurfaceTool = ToolMesh.begin()
	# Fechos na frente: chapa na tampa, alavanca e chapa no corpo.
	var front: float = HALF_Z
	for sx: float in [-1.0, 1.0]:
		var x: float = sx * 0.092
		LowPolyMesh.box(st, Vector3(x, LID_Y0 + 0.018, front + 0.003), Vector3(0.03, 0.022, 0.006), Basis.IDENTITY, IRON)
		LowPolyMesh.box(st, Vector3(x, BODY_TOP - 0.008, front + 0.007), Vector3(0.022, 0.04, 0.008), Basis(Vector3.RIGHT, 0.12), IRON)
		LowPolyMesh.box(st, Vector3(x, BODY_TOP - 0.038, front + 0.004), Vector3(0.028, 0.02, 0.006), Basis.IDENTITY, IRON)
	# Pega: dois pés e a barra em ponte.
	for sx: float in [-1.0, 1.0]:
		LowPolyMesh.box(st, Vector3(sx * 0.07, LID_TOP + 0.006, 0.0), Vector3(0.034, 0.012, 0.03), Basis.IDENTITY, IRON)
		LowPolyMesh.box(st, Vector3(sx * 0.066, LID_TOP + 0.026, 0.0), Vector3(0.016, 0.038, 0.02), Basis(Vector3.FORWARD, sx * 0.12), IRON)
	LowPolyMesh.box(st, Vector3(0.0, LID_TOP + 0.047, 0.0), Vector3(0.15, 0.016, 0.022), Basis.IDENTITY, IRON)
	ToolMesh.part(self, "Iron", st, ToolMesh.prop_material(&"metal_rust", Color(0.2, 0.18, 0.17)))


func _build_decals() -> void:
	var st: SurfaceTool = ToolMesh.begin()
	var z: float = HALF_Z + 0.002
	var center: Vector3 = Vector3(0.0, 0.07, z)
	# Disco branco (12 lados) e a cruz vermelha por cima.
	var disc: PackedVector3Array = PackedVector3Array()
	for i: int in 12:
		var a: float = TAU * float(i) / 12.0
		disc.append(center + Vector3(cos(a), sin(a), 0.0) * 0.044)
	ToolMesh.slab(st, disc, Vector3.BACK, 0.003, ToolMesh.clean(DECAL_WHITE))
	var cross_c: Vector3 = center + Vector3(0.0, 0.0, 0.0028)
	LowPolyMesh.box(st, cross_c, Vector3(0.058, 0.02, 0.002), Basis.IDENTITY, ToolMesh.clean(DECAL_RED))
	LowPolyMesh.box(st, cross_c, Vector3(0.02, 0.058, 0.002), Basis.IDENTITY, ToolMesh.clean(DECAL_RED))
	# Pontas de ligadura entaladas na junta (lado esquerdo e traseira direita).
	LowPolyMesh.box(st, Vector3(-HALF_X - 0.012, BODY_TOP - 0.004, 0.04), Vector3(0.04, 0.036, 0.003),
		Basis(Vector3.UP, 1.2) * Basis(Vector3.FORWARD, 0.4), ToolMesh.clean(BANDAGE))
	LowPolyMesh.box(st, Vector3(HALF_X - 0.01, BODY_TOP + 0.004, -HALF_Z - 0.006), Vector3(0.03, 0.022, 0.003),
		Basis(Vector3.FORWARD, -0.25), ToolMesh.clean(BANDAGE))
	ToolMesh.part(self, "Decals", st, ToonKit.vertex_material())


## Caixa com as arestas verticais chanfradas (secção octogonal) entre y0 e y1; `inset` estreita
## o topo (tampa abaulada).
func _chamfer_box(st: SurfaceTool, y0: float, y1: float, hx: float, hz: float, ch: float, inset: float, color: Color,
		at: Vector3 = Vector3.ZERO) -> void:
	var bottom: PackedVector3Array = _ring(y0, hx, hz, ch)
	var top: PackedVector3Array = _ring(y1, hx - inset, hz - inset, ch)
	var inside: Vector3 = at + Vector3(0.0, (y0 + y1) * 0.5, 0.0)
	for i: int in bottom.size():
		var j: int = (i + 1) % bottom.size()
		LowPolyMesh.quad(st, at + bottom[i], at + bottom[j], at + top[j], at + top[i], inside, color)
		LowPolyMesh.tri(st, at + Vector3(0.0, y0, 0.0), at + bottom[i], at + bottom[j], inside, color)
		LowPolyMesh.tri(st, at + Vector3(0.0, y1, 0.0), at + top[j], at + top[i], inside, color)


func _ring(y: float, hx: float, hz: float, ch: float) -> PackedVector3Array:
	return PackedVector3Array([
		Vector3(hx - ch, y, hz), Vector3(hx, y, hz - ch), Vector3(hx, y, -hz + ch), Vector3(hx - ch, y, -hz),
		Vector3(-hx + ch, y, -hz), Vector3(-hx, y, -hz + ch), Vector3(-hx, y, hz - ch), Vector3(-hx + ch, y, hz),
	])
