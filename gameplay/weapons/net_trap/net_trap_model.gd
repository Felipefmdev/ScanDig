@tool
extends Node3D

## Armadilha de Rede low-poly (#61, fiel a armadilha_rede.jpg): rolo de rede de malha escura
## deitado (eixo X) entre aros duplos de madeira gasta, cordas enroladas e atadas com pontas
## soltas, boias de cortiça laranja-ferrugem penduradas em cordéis e um peso de ferro
## enferrujado em forma de sino. Origem no centro da base; ~0,46 × 0,36 × 0,36 m.

const ToolMesh = preload("res://gameplay/weapons/tool_mesh.gd")

const LENGTH: float = 0.44
const RADIUS: float = 0.17
const NET: Color = Color(0.36, 0.33, 0.2)
const NET_INNER: Color = Color(0.17, 0.17, 0.1)
const HOOP: Color = Color(0.56, 0.47, 0.3)
const HOOP_DARK: Color = Color(0.42, 0.34, 0.2)
const ROPE: Color = Color(0.62, 0.55, 0.38)
const CORK: Color = Color(0.74, 0.42, 0.2)
const CORK_DARK: Color = Color(0.58, 0.3, 0.14)
const IRON: Color = Color(0.4, 0.36, 0.34)


func _ready() -> void:
	ToolMesh.clear(self)
	var st: SurfaceTool = ToolMesh.begin()
	var c: Vector3 = Vector3(0.0, RADIUS, 0.0)
	var hx: float = LENGTH * 0.5
	# Miolo escuro (a rede enrolada vista pela malha)
	LowPolyMesh.prism(st, c + Vector3(-hx + 0.02, 0, 0), c + Vector3(hx - 0.02, 0, 0), RADIUS * 0.86, RADIUS * 0.86, 9, NET_INNER)
	# Malha: fios ao comprido e em diagonal por fora do miolo
	var sides: int = 14
	for i: int in sides:
		var a: float = TAU * float(i) / float(sides)
		var a2: float = a + TAU / float(sides) * 1.5
		var p0: Vector3 = c + Vector3(-hx, cos(a) * RADIUS * 0.94, sin(a) * RADIUS * 0.94)
		var p1: Vector3 = c + Vector3(hx, cos(a2) * RADIUS * 0.94, sin(a2) * RADIUS * 0.94)
		var p2: Vector3 = c + Vector3(hx, cos(a - TAU / float(sides) * 1.5) * RADIUS * 0.94, sin(a - TAU / float(sides) * 1.5) * RADIUS * 0.94)
		LowPolyMesh.prism(st, p0, p1, 0.005, 0.005, 3, NET)
		LowPolyMesh.prism(st, p0, p2, 0.005, 0.005, 3, NET)
	for k: int in 6:
		var x: float = -hx + LENGTH * float(k + 1) / 7.0
		_ring(st, c + Vector3(x, 0, 0), RADIUS * 0.95, 0.005, 12, NET)
	# Pontas: a rede fecha em funil (cone escuro com fios radiais)
	for sx: float in [-1.0, 1.0]:
		var e: Vector3 = c + Vector3(sx * (hx - 0.01), 0, 0)
		LowPolyMesh.prism(st, e, e - Vector3(sx * 0.12, 0, 0), RADIUS * 0.92, 0.02, 12, NET_INNER)
		for i: int in 10:
			var a: float = TAU * float(i) / 10.0
			LowPolyMesh.prism(st, e + Vector3(0, cos(a), sin(a)) * RADIUS * 0.92, e - Vector3(sx * 0.11, 0, 0), 0.005, 0.003, 3, NET)
	# Aros duplos de madeira nas pontas
	for sx: float in [-1.0, 1.0]:
		_ring(st, c + Vector3(sx * hx, 0, 0), RADIUS, 0.018, 12, HOOP)
		_ring(st, c + Vector3(sx * (hx - 0.035), 0, 0), RADIUS * 0.98, 0.014, 12, HOOP_DARK)
		# Nós de corda nos aros com pontas soltas
		for a: float in [0.6, 2.4, 4.4]:
			var p: Vector3 = c + Vector3(sx * hx, cos(a) * RADIUS, sin(a) * RADIUS)
			LowPolyMesh.prism(st, p - Vector3(0.012, 0, 0), p + Vector3(0.012, 0, 0), 0.02, 0.02, 5, ROPE)
			LowPolyMesh.prism(st, p, p + Vector3(sx * 0.05, cos(a) * 0.05, sin(a) * 0.05), 0.006, 0.002, 3, ROPE)
			LowPolyMesh.prism(st, p, p + Vector3(sx * 0.04, cos(a + 0.6) * 0.05, sin(a + 0.6) * 0.05), 0.006, 0.002, 3, ROPE)
	# Cordas enroladas à volta (duas voltas ao comprido e uma a meio)
	_ring(st, c + Vector3(0.06, 0, 0), RADIUS * 1.02, 0.01, 12, ROPE)
	_ring(st, c + Vector3(0.09, 0, 0), RADIUS * 1.02, 0.01, 12, ROPE)
	for z: float in [-RADIUS * 1.02, RADIUS * 1.02]:
		LowPolyMesh.prism(st, c + Vector3(-hx - 0.02, 0.0, z), c + Vector3(hx + 0.02, 0.0, z), 0.009, 0.009, 4, ROPE)
	# Boias de cortiça (prismas octogonais) penduradas em cordéis, à frente (+Z)
	var floats: Array = [[Vector3(-0.02, 0.27, -0.16), 0.0], [Vector3(0.1, 0.25, -0.17), 0.4], [Vector3(-0.08, 0.08, -0.2), 0.2], [Vector3(0.2, 0.12, -0.18), -0.3]]
	for f: Array in floats:
		var p: Vector3 = f[0]
		var b: Basis = Basis(Vector3.FORWARD, float(f[1]))
		LowPolyMesh.prism(st, p - b.y * 0.035, p + b.y * 0.035, 0.032, 0.032, 8, CORK)
		LowPolyMesh.prism(st, p + b.y * 0.035, p + b.y * 0.045, 0.028, 0.02, 8, CORK_DARK)
		LowPolyMesh.prism(st, p + b.y * 0.045, p + b.y * 0.08, 0.004, 0.004, 3, ROPE)
	# Peso de ferro enferrujado (sino) com argola
	var w: Vector3 = Vector3(0.08, 0.045, -0.2)
	LowPolyMesh.prism(st, w + Vector3(0, -0.04, 0), w + Vector3(0, 0.035, 0), 0.042, 0.032, 6, IRON)
	_ring(st, w + Vector3(0, 0.055, 0), 0.016, 0.005, 6, IRON, Vector3.FORWARD)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "NetTrapMesh"
	mi.mesh = ToonKit.commit(st)
	var mat: ShaderMaterial = ToonKit.vertex_material(true, true)
	mat.set_shader_parameter(&"chip_amount", 0.35)
	mat.set_shader_parameter(&"chip_color", Color(0.45, 0.25, 0.12))
	mat.set_shader_parameter(&"chip_scale", 9.0)
	mi.material_override = mat
	add_child(mi)


## Anel de `sides` prismas à volta do eixo `axis` (X por omissão).
func _ring(st: SurfaceTool, center: Vector3, r: float, thick: float, sides: int, color: Color, axis: Vector3 = Vector3.RIGHT) -> void:
	var u: Vector3 = Vector3.UP if absf(axis.dot(Vector3.UP)) < 0.9 else Vector3.FORWARD
	var v: Vector3 = axis.cross(u).normalized()
	u = v.cross(axis).normalized()
	for i: int in sides:
		var a0: float = TAU * float(i) / float(sides)
		var a1: float = TAU * float(i + 1) / float(sides)
		LowPolyMesh.prism(st, center + (u * cos(a0) + v * sin(a0)) * r, center + (u * cos(a1) + v * sin(a1)) * r, thick, thick, 4, color)
