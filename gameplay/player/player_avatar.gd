class_name PlayerAvatar
extends Node3D

## Corpo low-poly do jogador visto pelos OUTROS (o jogador local só vê as mãos em 1.ª
## pessoa): pernas, tronco com camisa da cor do peer, braços, cabeça com chapéu de
## explorador e um nome por cima. A cabeça acompanha o pitch replicado (Head.rotation.x)
## e a mão direita mostra que há uma ferramenta na mão (held_tool_id).
## Construído com malhas primitivas em _ready; a origem fica nos pés.

const SKIN: Color = Color(0.93, 0.76, 0.6)
const PANTS: Color = Color(0.3, 0.27, 0.22)
const BOOTS: Color = Color(0.25, 0.17, 0.11)
const HAT: Color = Color(0.78, 0.66, 0.42)
const HAT_BAND: Color = Color(0.36, 0.24, 0.14)
const TOOL_COLOR: Color = Color(0.55, 0.57, 0.6)
## Camisas por peer (o host fica sempre com a primeira).
const SHIRTS: Array[Color] = [
	Color(0.93, 0.45, 0.2), Color(0.25, 0.55, 0.9), Color(0.35, 0.72, 0.3), Color(0.82, 0.3, 0.6),
]

var _head_pivot: Node3D = null
var _tool: MeshInstance3D = null
var _label: Label3D = null


func _ready() -> void:
	var legs: Node3D = Node3D.new()
	legs.name = "Legs"
	add_child(legs)
	for side: float in [-1.0, 1.0]:
		_box(legs, Vector3(0.17, 0.78, 0.2), Vector3(0.12 * side, 0.45, 0.0), PANTS)
		_box(legs, Vector3(0.19, 0.12, 0.28), Vector3(0.12 * side, 0.06, -0.03), BOOTS)
	var shirt: Color = SHIRTS[0]
	_box(self, Vector3(0.5, 0.62, 0.28), Vector3(0, 1.13, 0), shirt, "Torso")
	for side: float in [-1.0, 1.0]:
		_box(self, Vector3(0.13, 0.55, 0.15), Vector3(0.33 * side, 1.12, 0.0), shirt.darkened(0.1),
			"ArmL" if side < 0.0 else "ArmR")
		_box(self, Vector3(0.11, 0.12, 0.12), Vector3(0.33 * side, 0.8, 0.0), SKIN)
	_tool = _box(self, Vector3(0.05, 0.05, 0.55), Vector3(0.33, 0.85, -0.25), TOOL_COLOR, "Tool")
	_tool.visible = false

	_head_pivot = Node3D.new()
	_head_pivot.name = "HeadPivot"
	_head_pivot.position = Vector3(0, 1.48, 0)
	add_child(_head_pivot)
	_box(_head_pivot, Vector3(0.3, 0.32, 0.3), Vector3(0, 0.12, 0), SKIN, "Head")
	_box(_head_pivot, Vector3(0.06, 0.05, 0.02), Vector3(-0.07, 0.15, -0.155), Color(0.1, 0.1, 0.1))
	_box(_head_pivot, Vector3(0.06, 0.05, 0.02), Vector3(0.07, 0.15, -0.155), Color(0.1, 0.1, 0.1))
	_cylinder(_head_pivot, 0.34, 0.03, Vector3(0, 0.3, 0), HAT)
	_cylinder(_head_pivot, 0.19, 0.16, Vector3(0, 0.39, 0), HAT)
	_cylinder(_head_pivot, 0.195, 0.04, Vector3(0, 0.34, 0), HAT_BAND)

	_label = Label3D.new()
	_label.name = "NameLabel"
	_label.position = Vector3(0, 2.2, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.0035
	_label.font_size = 40
	_label.outline_size = 10
	_label.no_depth_test = true
	add_child(_label)


## Cor da camisa e nome a partir do peer dono deste jogador.
func setup(peer_id: int, display_name: String) -> void:
	var shirt: Color = SHIRTS[0] if peer_id == 1 else SHIRTS[1 + absi(peer_id) % (SHIRTS.size() - 1)]
	var torso: MeshInstance3D = get_node_or_null(^"Torso") as MeshInstance3D
	if torso != null:
		(torso.material_override as StandardMaterial3D).albedo_color = shirt
	for child: Node in get_children():
		var mi: MeshInstance3D = child as MeshInstance3D
		if mi != null and mi.name.begins_with("Arm"):
			(mi.material_override as StandardMaterial3D).albedo_color = shirt.darkened(0.1)
	if _label != null:
		_label.text = display_name
		_label.modulate = shirt.lightened(0.35)


func set_pitch(pitch: float) -> void:
	if _head_pivot != null:
		_head_pivot.rotation.x = clampf(pitch, -0.9, 0.9)


func set_tool(tool_id: StringName) -> void:
	if _tool != null:
		_tool.visible = tool_id != &""


func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, node_name: String = "") -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return _add_mesh(parent, mesh, pos, color, node_name)


func _cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 1
	return _add_mesh(parent, mesh, pos, color, "")


func _add_mesh(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, node_name: String) -> MeshInstance3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	var mi: MeshInstance3D = MeshInstance3D.new()
	if not node_name.is_empty():
		mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi
