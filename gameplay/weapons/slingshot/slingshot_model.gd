@tool
class_name SlingshotModel
extends Node3D

## Estilingue low-poly facetado (docs/art/reference/estilingue.jpg, #37): forquilha em Y de um
## ramo com nós (madeira toon), pega enrolada em tiras de couro, elásticos amarelos atados nas
## pontas e bolsa de couro. Espaço local: o cabo vai ao longo de Y com o centro da pega na
## origem (onde a HandModel agarra); a forquilha abre para cima; -Z = para onde dispara; o
## elástico fica em +Z.

const ToolMesh = preload("res://gameplay/weapons/tool_mesh.gd")

const WOOD: Color = Color(1.0, 1.0, 1.0)
const WOOD_KNOT: Color = Color(0.78, 0.72, 0.68)
const LEATHER: Color = Color(0.34, 0.21, 0.13)
const LEATHER_DARK: Color = Color(0.26, 0.16, 0.1)
const RUBBER: Color = Color(0.72, 0.58, 0.22)
const RUBBER_DARK: Color = Color(0.56, 0.43, 0.14)

## Topo das duas pontas da forquilha (o elástico prende aqui).
const TIP_LEFT: Vector3 = Vector3(-0.055, 0.15, 0.0)
const TIP_RIGHT: Vector3 = Vector3(0.055, 0.15, 0.0)
const FORK: Vector3 = Vector3(0.0, 0.03, 0.0)

## 0 = elástico em repouso, 1 = puxado ao máximo (animação de tiro).
@export_range(0.0, 1.0) var pull: float = 0.0:
	set(value):
		pull = value
		if is_inside_tree():
			_rebuild_band()

var _band: MeshInstance3D = null


func _ready() -> void:
	ToolMesh.clear(self)
	_build_wood()
	_build_wraps()
	_band = MeshInstance3D.new()
	_band.name = "Band"
	_band.material_override = ToonKit.vertex_material()
	add_child(_band)
	_rebuild_band()


func _build_wood() -> void:
	var st: SurfaceTool = ToolMesh.begin()
	# Cabo: um pouco mais grosso em baixo, ponta mais escura.
	LowPolyMesh.prism(st, Vector3(0.0, -0.09, 0.0), Vector3(0.0, FORK.y + 0.008, 0.0), 0.021, 0.022, 7, WOOD)
	LowPolyMesh.prism(st, Vector3(0.0, -0.1, 0.0), Vector3(0.0, -0.09, 0.0), 0.017, 0.021, 7, WOOD_KNOT)
	# Braços da forquilha (o esquerdo mais direito, o direito mais aberto, como um ramo).
	var left_bend: Vector3 = Vector3(-0.03, 0.085, 0.0)
	var right_bend: Vector3 = Vector3(0.034, 0.08, 0.0)
	LowPolyMesh.prism(st, FORK, left_bend, 0.02, 0.017, 6, WOOD)
	LowPolyMesh.prism(st, left_bend, TIP_LEFT + Vector3(0.0, 0.014, 0.0), 0.017, 0.014, 6, WOOD)
	LowPolyMesh.prism(st, FORK, right_bend, 0.02, 0.017, 6, WOOD)
	LowPolyMesh.prism(st, right_bend, TIP_RIGHT + Vector3(0.0, 0.014, 0.0), 0.017, 0.014, 6, WOOD)
	# Nós do ramo.
	LowPolyMesh.prism(st, left_bend + Vector3(-0.008, -0.01, 0.0), left_bend + Vector3(-0.022, -0.016, 0.0), 0.008, 0.004, 5, WOOD_KNOT)
	LowPolyMesh.prism(st, right_bend + Vector3(0.008, -0.012, 0.004), right_bend + Vector3(0.02, -0.02, 0.01), 0.008, 0.004, 5, WOOD_KNOT)
	var mat: ShaderMaterial = ToolMesh.prop_material(&"wood", Color(0.38, 0.23, 0.13))
	mat.set_shader_parameter(&"grain_scale", 30.0)
	ToolMesh.part(self, "Body", st, mat)


func _build_wraps() -> void:
	var st: SurfaceTool = ToolMesh.begin()
	# Tiras de couro enroladas na pega: anéis ligeiramente inclinados, alternando o tom.
	for i: int in 6:
		var y: float = -0.072 + float(i) * 0.016
		var tilt: Basis = Basis(Vector3.BACK, 0.28 if i % 2 == 0 else -0.18)
		var axis: Vector3 = tilt * Vector3.UP
		var c: Vector3 = Vector3(0.0, y, 0.0)
		LowPolyMesh.prism(st, c - axis * 0.0065, c + axis * 0.0065, 0.0255, 0.0255, 7,
			LEATHER if i % 2 == 0 else LEATHER_DARK)
	# Nós do elástico à volta de cada ponta.
	for tip: Vector3 in [TIP_LEFT, TIP_RIGHT]:
		LowPolyMesh.prism(st, tip + Vector3(0.0, -0.012, 0.0), tip + Vector3(0.0, 0.002, 0.0), 0.0185, 0.0185, 6, RUBBER)
		LowPolyMesh.box(st, tip + Vector3(0.0, -0.005, 0.016), Vector3(0.012, 0.012, 0.01), Basis(Vector3.BACK, 0.6), RUBBER_DARK)
	ToolMesh.part(self, "Wraps", st, ToonKit.vertex_material())


func _rebuild_band() -> void:
	if _band == null:
		return
	var st: SurfaceTool = ToolMesh.begin()
	var pouch: Vector3 = Vector3(0.0, 0.135, 0.035 + pull * 0.16)
	for tip: Vector3 in [TIP_LEFT, TIP_RIGHT]:
		var start: Vector3 = tip + Vector3(0.0, -0.005, 0.016)
		var end: Vector3 = pouch + Vector3(signf(tip.x) * 0.016, 0.0, 0.0)
		# Elástico achatado (4 lados) com uma atadura perto da bolsa.
		LowPolyMesh.prism(st, start, end, 0.0055, 0.005, 4, RUBBER)
		LowPolyMesh.prism(st, end.lerp(start, 0.18), end.lerp(start, 0.1), 0.0075, 0.0075, 4, RUBBER_DARK)
	LowPolyMesh.box(st, pouch, Vector3(0.036, 0.024, 0.012), Basis.IDENTITY, LEATHER)
	LowPolyMesh.box(st, pouch + Vector3(0.0, 0.0, 0.004), Vector3(0.026, 0.016, 0.008), Basis.IDENTITY, LEATHER_DARK)
	_band.mesh = ToonKit.commit(st)
