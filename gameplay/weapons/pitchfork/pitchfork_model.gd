@tool
class_name PitchforkModel
extends Node3D

## Forcado low-poly facetado (docs/art/reference/, #38): arma corpo a corpo de alcance médio.
## Cabo longo de madeira toon com anel de reforço e ligaduras de couro, casquilho de metal
## ferrugento e cabeça com 3 dentes curvados para a frente em leque.
## Espaço local: origem no ponto de pega principal (onde a ToolHand agarra); o cabo estende-se
## para baixo (-Y) até ao calcanhar e para cima (+Y) até aos dentes. Frente para -Z.
##
## Regra (#47): malhas geradas entram na árvore sem owner (o editor nunca as grava no .tscn).

const ToolMesh = preload("res://gameplay/weapons/tool_mesh.gd")

const WOOD: Color = Color(1.0, 1.0, 1.0)
const WOOD_DARK: Color = Color(0.72, 0.65, 0.58)
const LEATHER: Color = Color(0.35, 0.22, 0.13)
const METAL: Color = Color(1.0, 1.0, 1.0)
const METAL_DARK: Color = Color(0.55, 0.55, 0.58)

## Dimensões do forcado
const SHAFT_BOTTOM_Y: float = -0.45
const SHAFT_TOP_Y: float = 0.54
const SHAFT_RADIUS: float = 0.018

const SOCKET_Y0: float = 0.52
const SOCKET_Y1: float = 0.62
const CROWN_Y: float = 0.64
const TINE_TIP_Y: float = 0.98
const TINE_SPREAD_X: float = 0.11

@export var show_left_hand: bool = false:
	set(value):
		show_left_hand = value
		if is_inside_tree():
			_rebuild()


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	ToolMesh.clear(self)
	_build_wood()
	_build_metal()
	if show_left_hand:
		_build_left_hand()


func _build_wood() -> void:
	var st: SurfaceTool = ToolMesh.begin()
	# Cabo principal de madeira: 6 lados, leve afunilamento em direção ao topo
	ToolMesh.y_prism(st, Vector3.ZERO, SHAFT_BOTTOM_Y + 0.04, 0.0, SHAFT_RADIUS * 1.05, SHAFT_RADIUS, 6, 0.0, WOOD)
	ToolMesh.y_prism(st, Vector3.ZERO, 0.0, SHAFT_TOP_Y, SHAFT_RADIUS, SHAFT_RADIUS * 0.92, 6, 0.0, WOOD)
	
	# Faixa de couro enrolada junto à pega superior (guia da mão esquerda)
	for i: int in 4:
		var y: float = 0.18 + float(i) * 0.018
		var tilt: Basis = Basis(Vector3.BACK, 0.2 if i % 2 == 0 else -0.15)
		var axis: Vector3 = tilt * Vector3.UP
		var c: Vector3 = Vector3(0.0, y, 0.0)
		LowPolyMesh.prism(st, c - axis * 0.007, c + axis * 0.007, SHAFT_RADIUS * 1.15, SHAFT_RADIUS * 1.15, 6, LEATHER)

	var mat: ShaderMaterial = ToolMesh.prop_material(&"wood", Color(0.36, 0.22, 0.12))
	mat.set_shader_parameter(&"grain_scale", 24.0)
	ToolMesh.part(self, "Wood", st, mat)


func _build_metal() -> void:
	var st: SurfaceTool = ToolMesh.begin()
	
	# Casquilho cónico que abraça a madeira
	ToolMesh.y_prism(st, Vector3.ZERO, SOCKET_Y0, SOCKET_Y1, SHAFT_RADIUS * 1.12, SHAFT_RADIUS * 1.35, 6, 0.0, METAL_DARK)
	# Rebites no casquilho
	for sx: float in [-1.0, 1.0]:
		LowPolyMesh.prism(st, Vector3(sx * SHAFT_RADIUS * 1.1, SOCKET_Y0 + 0.04, 0.0),
			Vector3(sx * (SHAFT_RADIUS * 1.1 + 0.008), SOCKET_Y0 + 0.04, 0.0), 0.005, 0.003, 5, METAL)

	# Travessa / coroa curvada na base dos 3 dentes
	var crown_center: Vector3 = Vector3(0.0, CROWN_Y, -0.01)
	var crown_left: Vector3 = Vector3(-TINE_SPREAD_X, CROWN_Y - 0.01, 0.0)
	var crown_right: Vector3 = Vector3(TINE_SPREAD_X, CROWN_Y - 0.01, 0.0)
	LowPolyMesh.prism(st, Vector3(0.0, SOCKET_Y1, 0.0), crown_center, 0.016, 0.014, 5, METAL)
	LowPolyMesh.prism(st, crown_center, crown_left, 0.014, 0.011, 5, METAL)
	LowPolyMesh.prism(st, crown_center, crown_right, 0.014, 0.011, 5, METAL)

	# 3 Dentes (tines) facetados e pontiagudos curvando levemente para a frente (-Z)
	_build_tine(st, crown_center + Vector3(0.0, 0.01, 0.0), Vector3(0.0, 0.82, -0.03), Vector3(0.0, TINE_TIP_Y, -0.05), 0.009, 0.006, 0.0015)
	_build_tine(st, crown_left, Vector3(-TINE_SPREAD_X * 0.95, 0.80, -0.035), Vector3(-TINE_SPREAD_X * 0.88, TINE_TIP_Y - 0.03, -0.055), 0.0085, 0.0055, 0.0015)
	_build_tine(st, crown_right, Vector3(TINE_SPREAD_X * 0.95, 0.80, -0.035), Vector3(TINE_SPREAD_X * 0.88, TINE_TIP_Y - 0.03, -0.055), 0.0085, 0.0055, 0.0015)

	# Ponteira metálica no calcanhar do cabo
	ToolMesh.y_prism(st, Vector3.ZERO, SHAFT_BOTTOM_Y, SHAFT_BOTTOM_Y + 0.045, SHAFT_RADIUS * 1.08, SHAFT_RADIUS * 1.08, 6, 0.0, METAL_DARK)
	LowPolyMesh.prism(st, Vector3(0.0, SHAFT_BOTTOM_Y, 0.0), Vector3(0.0, SHAFT_BOTTOM_Y - 0.02, 0.0), SHAFT_RADIUS * 1.08, 0.005, 6, METAL_DARK)

	var mat: ShaderMaterial = ToolMesh.prop_material(&"metal_rust", Color(0.42, 0.44, 0.46))
	mat.set_shader_parameter(&"rust_amount", 0.6)
	mat.set_shader_parameter(&"rust_color", Color(0.44, 0.20, 0.09))
	ToolMesh.part(self, "Metal", st, mat)


func _build_tine(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, r0: float, r1: float, r2: float) -> void:
	LowPolyMesh.prism(st, p0, p1, r0, r1, 5, METAL)
	LowPolyMesh.prism(st, p1, p2, r1, r2, 4, METAL)


func _build_left_hand() -> void:
	var hand_script: Script = load("res://gameplay/player/hand_model.gd") as Script
	if hand_script == null:
		return
	var hand: Node3D = Node3D.new()
	hand.set_script(hand_script)
	hand.name = "LeftHand"
	hand.set("is_left", true)
	hand.set("pose", 1)  # Pose.GRIP
	# Mão esquerda segura o cabo mais à frente (em torno de y = 0.22)
	hand.transform = Transform3D(Basis(Vector3.UP, PI).rotated(Vector3.FORWARD, deg_to_rad(90.0)), Vector3(0.0, 0.22, 0.0))
	add_child(hand)
