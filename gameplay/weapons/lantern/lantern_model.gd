@tool
extends Node3D

## Lanterna de Magnésio low-poly (#61, fiel a lanterna_magnesio.jpg): corpo cilíndrico de latão
## com ferrugem, tampa em cúpula com tampão, refletor em funil largo (interior prateado e lente
## escura) virado para -Z (para a frente, na mão), manivela de ferro ao lado com punho, braçadeiras com rebites, asa de
## ferro por cima e correia de couro gasta. Origem no centro da base; ~0,26 × 0,30 × 0,24 m.

const ToolMesh = preload("res://gameplay/weapons/tool_mesh.gd")

const BRASS: Color = Color(0.62, 0.5, 0.28)
const BRASS_DARK: Color = Color(0.52, 0.39, 0.16)
const SILVER: Color = Color(0.72, 0.72, 0.7)
const LENS: Color = Color(0.32, 0.34, 0.36)
const IRON: Color = Color(0.36, 0.3, 0.26)
const LEATHER: Color = Color(0.32, 0.2, 0.14)


func _ready() -> void:
	ToolMesh.clear(self)
	var st: SurfaceTool = ToolMesh.begin()
	var r: float = 0.075
	# Corpo: cilindro facetado com aros na base e no topo
	ToolMesh.y_prism(st, Vector3.ZERO, 0.0, 0.2, r, r, 10, 0.0, BRASS)
	ToolMesh.y_prism(st, Vector3.ZERO, 0.0, 0.018, r + 0.006, r + 0.006, 10, 0.0, BRASS_DARK)
	ToolMesh.y_prism(st, Vector3.ZERO, 0.19, 0.212, r + 0.008, r + 0.008, 10, 0.0, BRASS_DARK)
	# Tampa em cúpula e tampão
	ToolMesh.y_prism(st, Vector3.ZERO, 0.212, 0.245, r + 0.004, 0.048, 10, 0.0, BRASS)
	ToolMesh.y_prism(st, Vector3.ZERO, 0.245, 0.265, 0.045, 0.045, 10, 0.0, BRASS_DARK)
	# Refletor em funil à frente (+Z): gargalo, cone largo, aro, interior prateado e lente
	var fc: Vector3 = Vector3(0.0, 0.11, -r + 0.005)
	LowPolyMesh.prism(st, fc, fc + Vector3(0, 0, -0.03), 0.045, 0.05, 10, BRASS_DARK)
	LowPolyMesh.prism(st, fc + Vector3(0, 0, -0.03), fc + Vector3(0, 0, -0.11), 0.05, 0.1, 12, BRASS)
	LowPolyMesh.prism(st, fc + Vector3(0, 0, -0.105), fc + Vector3(0, 0, -0.12), 0.104, 0.104, 12, BRASS_DARK)
	LowPolyMesh.prism(st, fc + Vector3(0, 0, -0.12), fc + Vector3(0, 0, -0.124), 0.094, 0.094, 12, ToolMesh.clean(SILVER))
	LowPolyMesh.prism(st, fc + Vector3(0, 0, -0.124), fc + Vector3(0, 0, -0.14), 0.036, 0.03, 10, ToolMesh.clean(LENS))
	# Raios do refletor (gomos) no interior prateado
	for i: int in 10:
		var ang: float = TAU * float(i) / 10.0
		LowPolyMesh.prism(st, fc + Vector3(cos(ang) * 0.04, sin(ang) * 0.04, -0.125), fc + Vector3(cos(ang) * 0.09, sin(ang) * 0.09, -0.125),
			0.003, 0.003, 3, ToolMesh.clean(Color(0.5, 0.5, 0.5)))
	# Manivela na lateral (+X): eixo, cubo sextavado, braço e punho
	var mc: Vector3 = Vector3(r, 0.09, 0.01)
	LowPolyMesh.prism(st, mc, mc + Vector3(0.02, 0, 0), 0.022, 0.022, 6, IRON)
	LowPolyMesh.prism(st, mc + Vector3(0.02, 0, 0), mc + Vector3(0.028, -0.06, 0.0), 0.009, 0.009, 4, IRON)
	LowPolyMesh.prism(st, mc + Vector3(0.028, -0.06, 0.0), mc + Vector3(0.065, -0.06, 0.0), 0.012, 0.012, 6, IRON)
	# Braçadeiras com rebites e asa de ferro em arco por cima
	for sx: float in [-1.0, 1.0]:
		LowPolyMesh.box(st, Vector3(sx * (r + 0.004), 0.2, 0.0), Vector3(0.012, 0.05, 0.026), Basis.IDENTITY, IRON)
		LowPolyMesh.prism(st, Vector3(sx * (r + 0.01), 0.205, 0.0), Vector3(sx * (r + 0.016), 0.205, 0.0), 0.006, 0.006, 5, BRASS_DARK)
	var prev: Vector3 = Vector3(-r - 0.008, 0.22, 0.0)
	for k: int in 8:
		var a: float = PI * float(k + 1) / 8.0
		var p: Vector3 = Vector3(-cos(a) * (r + 0.008), 0.22 + sin(a) * 0.11, 0.0)
		LowPolyMesh.prism(st, prev, p, 0.01, 0.01, 4, IRON)
		prev = p
	# Correia de couro gasta: desce do lado de trás e faz um laço no chão
	var pts: Array[Vector3] = [Vector3(r + 0.01, 0.2, 0.02), Vector3(0.11, 0.14, 0.08), Vector3(0.13, 0.05, 0.12),
		Vector3(0.1, 0.01, 0.16), Vector3(0.03, 0.01, 0.15)]
	for k: int in pts.size() - 1:
		var d: Vector3 = pts[k + 1] - pts[k]
		var b: Basis = Basis.looking_at(d.normalized(), Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.FORWARD)
		LowPolyMesh.box(st, (pts[k] + pts[k + 1]) * 0.5, Vector3(0.022, 0.006, d.length()), b, LEATHER)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "LanternMesh"
	mi.mesh = ToonKit.commit(st)
	mi.material_override = _material()
	add_child(mi)


func _material() -> ShaderMaterial:
	var mat: ShaderMaterial = ToonKit.vertex_material(true, true)
	mat.set_shader_parameter(&"chip_amount", 0.65)
	mat.set_shader_parameter(&"chip_color", Color(0.5, 0.27, 0.12))
	mat.set_shader_parameter(&"chip_scale", 7.0)
	return mat
