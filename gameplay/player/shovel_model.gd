@tool
extends Node3D

## Pá low-poly facetada (docs/art/reference/pa.jpg, #37): lâmina de metal ferrugento em
## bico com nervura central e degraus para o pé, casquilho, cabo de madeira e punho em D
## (estribos de metal com travessa de madeira). Shader toon com contorno (ToonKit).
## Espaço local igual ao rig da ShovelDigAnimator: origem na ponta da lâmina, +Y ao longo
## do cabo, a face da lâmina olha para +Z. Comprimento total ~1,04 m.

const ToolMesh = preload("res://gameplay/weapons/tool_mesh.gd")

const METAL: Color = Color(1.0, 1.0, 1.0)
const METAL_DARK: Color = Color(0.62, 0.62, 0.66)
const WOOD: Color = Color(1.0, 1.0, 1.0)

## Lâmina: ponta, largura máxima e ombros.
const BLADE_HALF_WIDTH: float = 0.125
const BLADE_SHOULDER_Y: float = 0.30
const BLADE_THICKNESS: float = 0.012
## Cabo de madeira (entre o casquilho e a virola do punho).
const SHAFT_Y0: float = 0.36
const SHAFT_Y1: float = 0.86
const SHAFT_RADIUS: float = 0.022
## Punho em D.
const GRIP_Y: float = 1.0
const GRIP_HALF_WIDTH: float = 0.072


func _ready() -> void:
	ToolMesh.clear(self)
	_build_metal()
	_build_wood()


func _build_metal() -> void:
	var st: SurfaceTool = ToolMesh.begin()
	var z: float = BLADE_THICKNESS * 0.5
	var w: float = BLADE_HALF_WIDTH
	# Contorno da lâmina (convexo): bico, lados que alargam e ombros direitos.
	var outline: PackedVector3Array = PackedVector3Array([
		Vector3(0.0, 0.0, 0.0),
		Vector3(w * 0.72, 0.06, 0.0),
		Vector3(w, 0.15, 0.0),
		Vector3(w, BLADE_SHOULDER_Y, 0.0),
		Vector3(-w, BLADE_SHOULDER_Y, 0.0),
		Vector3(-w, 0.15, 0.0),
		Vector3(-w * 0.72, 0.06, 0.0),
	])
	# Frente: leque a partir de dois pontos da nervura (levantados) → facetas como na referência.
	var ridge_lo: Vector3 = Vector3(0.0, 0.11, z + 0.016)
	var ridge_hi: Vector3 = Vector3(0.0, 0.26, z + 0.02)
	var inside: Vector3 = Vector3(0.0, 0.16, -0.05)
	var front: PackedVector3Array = PackedVector3Array()
	for p: Vector3 in outline:
		front.append(p + Vector3(0.0, 0.0, z))
	# Metade direita (x >= 0) e esquerda, cada uma em leque das duas pontas da nervura.
	LowPolyMesh.tri(st, front[0], front[1], ridge_lo, inside, METAL)
	LowPolyMesh.tri(st, front[1], front[2], ridge_lo, inside, METAL)
	LowPolyMesh.tri(st, front[2], ridge_hi, ridge_lo, inside, METAL)
	LowPolyMesh.tri(st, front[2], front[3], ridge_hi, inside, METAL)
	LowPolyMesh.tri(st, front[3], Vector3(0.0, BLADE_SHOULDER_Y, z), ridge_hi, inside, METAL)
	LowPolyMesh.tri(st, front[0], front[6], ridge_lo, inside, METAL)
	LowPolyMesh.tri(st, front[6], front[5], ridge_lo, inside, METAL)
	LowPolyMesh.tri(st, front[5], ridge_hi, ridge_lo, inside, METAL)
	LowPolyMesh.tri(st, front[5], front[4], ridge_hi, inside, METAL)
	LowPolyMesh.tri(st, front[4], Vector3(0.0, BLADE_SHOULDER_Y, z), ridge_hi, inside, METAL)
	# Verso plano e orla.
	var back_c: Vector3 = Vector3(0.0, 0.16, -z)
	for i: int in outline.size():
		var a: Vector3 = outline[i]
		var b: Vector3 = outline[(i + 1) % outline.size()]
		LowPolyMesh.tri(st, back_c, a - Vector3(0, 0, z), b - Vector3(0, 0, z), Vector3(0.0, 0.16, 0.05), METAL)
		LowPolyMesh.quad(st, a + Vector3(0, 0, z), b + Vector3(0, 0, z), b - Vector3(0, 0, z), a - Vector3(0, 0, z),
			Vector3(0.0, 0.16, 0.0), METAL)
	# Degraus para o pé: abas dobradas para trás em cima de cada ombro.
	for sx: float in [-1.0, 1.0]:
		LowPolyMesh.box(st, Vector3(sx * (w - 0.045), BLADE_SHOULDER_Y + 0.004, -0.012),
			Vector3(0.085, 0.01, 0.034), Basis(Vector3.RIGHT, -0.25), METAL_DARK)
	# Casquilho: língua sobre a nervura e o tubo que abraça o cabo.
	LowPolyMesh.box(st, Vector3(0.0, 0.27, z + 0.012), Vector3(0.03, 0.09, 0.014), Basis.IDENTITY, METAL_DARK)
	ToolMesh.y_prism(st, Vector3.ZERO, BLADE_SHOULDER_Y - 0.01, SHAFT_Y0 + 0.02, 0.03, 0.023, 6, 0.0, METAL_DARK)
	# Virola do punho e estribos do D.
	ToolMesh.y_prism(st, Vector3.ZERO, SHAFT_Y1 - 0.01, SHAFT_Y1 + 0.04, 0.024, 0.024, 6, 0.0, METAL_DARK)
	for sx: float in [-1.0, 1.0]:
		var base: Vector3 = Vector3(sx * 0.012, SHAFT_Y1 + 0.035, 0.0)
		var top: Vector3 = Vector3(sx * GRIP_HALF_WIDTH, GRIP_Y, 0.0)
		LowPolyMesh.prism(st, base, top, 0.009, 0.009, 4, METAL_DARK)
		LowPolyMesh.prism(st, top, top + Vector3(0.0, 0.03, 0.0), 0.009, 0.009, 4, METAL_DARK)
		# Parafuso na ponta da travessa.
		LowPolyMesh.prism(st, top + Vector3(sx * 0.008, 0.012, 0.0), top + Vector3(sx * 0.02, 0.012, 0.0),
			0.008, 0.006, 6, METAL_DARK)
	var mat: ShaderMaterial = ToolMesh.prop_material(&"metal_rust", Color(0.33, 0.35, 0.38))
	mat.set_shader_parameter(&"rust_amount", 0.6)
	mat.set_shader_parameter(&"rust_color", Color(0.42, 0.18, 0.08))
	ToolMesh.part(self, "Metal", st, mat)


func _build_wood() -> void:
	var st: SurfaceTool = ToolMesh.begin()
	# Cabo com um ligeiro afunilamento e um nó a meio (facetas de 6 lados).
	ToolMesh.y_prism(st, Vector3.ZERO, SHAFT_Y0, 0.6, SHAFT_RADIUS * 1.08, SHAFT_RADIUS, 6, 0.0, WOOD)
	ToolMesh.y_prism(st, Vector3.ZERO, 0.6, SHAFT_Y1, SHAFT_RADIUS, SHAFT_RADIUS * 0.94, 6, 0.0, WOOD)
	LowPolyMesh.box(st, Vector3(0.0, 0.55, SHAFT_RADIUS * 0.8), Vector3(0.012, 0.03, 0.01), Basis.IDENTITY, WOOD * 0.85)
	# Travessa do punho.
	LowPolyMesh.prism(st, Vector3(-GRIP_HALF_WIDTH, GRIP_Y + 0.012, 0.0), Vector3(GRIP_HALF_WIDTH, GRIP_Y + 0.012, 0.0),
		0.017, 0.017, 6, WOOD)
	var mat: ShaderMaterial = ToolMesh.prop_material(&"wood", Color(0.34, 0.2, 0.11))
	mat.set_shader_parameter(&"grain_scale", 22.0)
	ToolMesh.part(self, "Wood", st, mat)
