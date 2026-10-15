@tool
extends Node3D

## Repelente "CRAB OFF!" (docs/art/reference/repelente.jpg, #37): lata de spray octogonal
## verde (tinta lascada, ferrugem nos aros), aros de metal em baixo e em cima, ombro cónico,
## gola branca, botão vermelho com orifício e rótulo creme com caranguejo riscado.
## Origem no centro da base; o rótulo olha para +Z. ~0,26 m de altura.

const ToolMesh = preload("res://gameplay/weapons/tool_mesh.gd")

const SIDES: int = 8
## Com esta fase uma face do octógono fica virada para +Z (o rótulo é plano nela).
const PHASE: float = PI / 8.0
const RADIUS: float = 0.048
const BODY_TOP: float = 0.168
const LABEL_Y0: float = 0.058
const LABEL_Y1: float = 0.146
const LABEL_RADIUS: float = 0.0505

const WHITE: Color = Color(1.0, 1.0, 1.0)
const LABEL: Color = Color(0.93, 0.86, 0.62)
const CRAB: Color = Color(0.88, 0.32, 0.2)
const INK: Color = Color(0.08, 0.07, 0.06)
const NOZZLE: Color = Color(0.85, 0.16, 0.1)
const COLLAR: Color = Color(0.94, 0.94, 0.92)


func _ready() -> void:
	ToolMesh.clear(self)
	_build_can()
	_build_rims()
	_build_top_and_label()


func _build_can() -> void:
	var st: SurfaceTool = ToolMesh.begin()
	var c: Vector3 = Vector3.ZERO
	# Corpo em três troços com raios ligeiramente diferentes (lata amolgada).
	ToolMesh.y_prism(st, c, 0.012, 0.06, RADIUS, RADIUS * 1.02, SIDES, PHASE, WHITE)
	ToolMesh.y_prism(st, c, 0.06, 0.12, RADIUS * 1.02, RADIUS * 0.98, SIDES, PHASE, WHITE)
	ToolMesh.y_prism(st, c, 0.12, BODY_TOP, RADIUS * 0.98, RADIUS, SIDES, PHASE, WHITE)
	# Ombro cónico até ao gargalo.
	ToolMesh.y_prism(st, c, BODY_TOP + 0.012, 0.205, RADIUS * 0.98, 0.026, SIDES, PHASE, WHITE)
	var mat: ShaderMaterial = ToolMesh.prop_material(&"paint_green", Color(0.1, 0.5, 0.24))
	mat.set_shader_parameter(&"chip_amount", 0.45)
	mat.set_shader_parameter(&"rust_amount", 0.45)
	ToolMesh.part(self, "Can", st, mat)


func _build_rims() -> void:
	var st: SurfaceTool = ToolMesh.begin()
	var c: Vector3 = Vector3.ZERO
	ToolMesh.y_prism(st, c, 0.0, 0.014, RADIUS * 1.1, RADIUS * 1.1, SIDES, PHASE, WHITE)
	ToolMesh.y_prism(st, c, BODY_TOP - 0.002, BODY_TOP + 0.013, RADIUS * 1.1, RADIUS * 1.08, SIDES, PHASE, WHITE)
	ToolMesh.y_prism(st, c, 0.204, 0.213, 0.029, 0.029, SIDES, PHASE, WHITE)
	var mat: ShaderMaterial = ToolMesh.prop_material(&"metal_rust", Color(0.66, 0.67, 0.7))
	mat.set_shader_parameter(&"rust_amount", 0.85)
	mat.set_shader_parameter(&"rust_scale", 40.0)
	ToolMesh.part(self, "Rims", st, mat)


func _build_top_and_label() -> void:
	var st: SurfaceTool = ToolMesh.begin()
	var c: Vector3 = Vector3.ZERO
	# Gola branca e botão vermelho com o orifício virado para a frente.
	ToolMesh.y_prism(st, c, 0.213, 0.232, 0.018, 0.017, SIDES, PHASE, ToolMesh.clean(COLLAR))
	ToolMesh.y_prism(st, c, 0.232, 0.258, 0.012, 0.014, 6, 0.0, ToolMesh.clean(NOZZLE))
	LowPolyMesh.box(st, Vector3(0.0, 0.248, 0.0128), Vector3(0.006, 0.006, 0.003), Basis.IDENTITY, ToolMesh.clean(INK))
	# Rótulo: abraça as 3 faces da frente (facetas 6, 7 e 8 = 0).
	ToolMesh.y_band(st, c, LABEL_Y0, LABEL_Y1, LABEL_RADIUS, SIDES, PHASE, 6, 9, ToolMesh.clean(LABEL))
	# Caranguejo riscado na face da frente (plano z = apótema do rótulo).
	var z: float = LABEL_RADIUS * cos(PI / float(SIDES)) + 0.0012
	var icon: Vector3 = Vector3(0.0, 0.11, z)
	var body: PackedVector3Array = PackedVector3Array()
	for i: int in 8:
		var a: float = TAU * float(i) / 8.0
		body.append(icon + Vector3(cos(a) * 0.013, sin(a) * 0.0095, 0.0))
	ToolMesh.slab(st, body, Vector3.BACK, 0.0015, ToolMesh.clean(CRAB))
	for sx: float in [-1.0, 1.0]:
		# Braço, pinça aberta em cima e três patas de cada lado.
		LowPolyMesh.box(st, icon + Vector3(sx * 0.012, 0.009, 0.0), Vector3(0.0035, 0.012, 0.0015),
			Basis(Vector3.BACK, sx * 0.35), ToolMesh.clean(CRAB))
		LowPolyMesh.box(st, icon + Vector3(sx * 0.016, 0.018, 0.0), Vector3(0.008, 0.007, 0.0015),
			Basis(Vector3.BACK, sx * -0.3), ToolMesh.clean(CRAB))
		for k: int in 3:
			LowPolyMesh.box(st, icon + Vector3(sx * 0.014, -0.002 - 0.0035 * float(k), 0.0), Vector3(0.011, 0.0022, 0.0015),
				Basis(Vector3.BACK, sx * (-0.35 - 0.25 * float(k))), ToolMesh.clean(CRAB))
	for r: float in [PI * 0.25, -PI * 0.25]:
		LowPolyMesh.box(st, icon + Vector3(0.0, 0.002, 0.0012), Vector3(0.046, 0.0028, 0.0015),
			Basis(Vector3.BACK, r), ToolMesh.clean(INK))
	ToolMesh.part(self, "Label", st, ToonKit.vertex_material())

	var text: Label3D = Label3D.new()
	text.name = "LabelText"
	text.text = "CRAB OFF!"
	text.font_size = 48
	text.pixel_size = 0.0002
	text.outline_size = 0
	text.modulate = Color(0.12, 0.1, 0.08)
	text.position = Vector3(0.0, 0.075, z + 0.0006)
	add_child(text)
