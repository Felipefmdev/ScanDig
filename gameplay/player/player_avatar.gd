class_name PlayerAvatar
extends Node3D

## Corpo low-poly do jogador visto pelos OUTROS (o jogador local só vê as mãos em 1.ª
## pessoa): pernas, tronco com camisa da cor do peer, braços, cabeça com chapéu de
## explorador e um nome por cima. A cabeça acompanha o pitch replicado (Head.rotation.x)
## e a mão direita mostra que há uma ferramenta na mão (held_tool_id). Pitch grande (a olhar
## para o chão, ex.: a cavar) divide-se entre a cabeça (até ±HEAD_PITCH_MAX, pivô na base do
## pescoço) e uma inclinação do tronco à cintura, para a cabeça nunca parecer solta (#35).
## Construído com malhas primitivas em _ready; a origem fica nos pés.

const SKIN: Color = Color(0.93, 0.76, 0.6)
const PANTS: Color = Color(0.3, 0.27, 0.22)
const BOOTS: Color = Color(0.25, 0.17, 0.11)
const HAT: Color = Color(0.78, 0.66, 0.42)
const HAT_BAND: Color = Color(0.36, 0.24, 0.14)
const TOOL_COLOR: Color = Color(0.55, 0.57, 0.6)
## Camisas por peer (o host fica sempre com a primeira).
## Rotação máxima da cabeça (rad); o resto do pitch inclina o tronco (até TORSO_LEAN_MAX).
const HEAD_PITCH_MAX: float = 0.45
const TORSO_LEAN_MAX: float = 0.3
## Parte do pitch que vai para o tronco.
const TORSO_LEAN_SHARE: float = 0.5
## Cintura (pivô do tronco) e base do pescoço, a partir dos pés.
const WAIST_Y: float = 0.84
const NECK_Y: float = 1.44
const SHIRTS: Array[Color] = [
	Color(0.93, 0.45, 0.2), Color(0.25, 0.55, 0.9), Color(0.35, 0.72, 0.3), Color(0.82, 0.3, 0.6),
]

var _head_pivot: Node3D = null
var _upper_body: Node3D = null
var _tool: MeshInstance3D = null
var _label: Label3D = null
var _is_downed: bool = false
var _base_display_name: String = ""


func _ready() -> void:
	var legs: Node3D = Node3D.new()
	legs.name = "Legs"
	add_child(legs)
	for side: float in [-1.0, 1.0]:
		_box(legs, Vector3(0.17, 0.78, 0.2), Vector3(0.12 * side, 0.45, 0.0), PANTS)
		_box(legs, Vector3(0.19, 0.12, 0.28), Vector3(0.12 * side, 0.06, -0.03), BOOTS)
	var shirt: Color = SHIRTS[0]
	# Tronco, braços, ferramenta e cabeça rodam juntos à volta da cintura (inclinação).
	_upper_body = Node3D.new()
	_upper_body.name = "UpperBody"
	_upper_body.position = Vector3(0, WAIST_Y, 0)
	add_child(_upper_body)
	_box(_upper_body, Vector3(0.5, 0.62, 0.28), Vector3(0, 1.13 - WAIST_Y, 0), shirt, "Torso")
	for side: float in [-1.0, 1.0]:
		_box(_upper_body, Vector3(0.13, 0.55, 0.15), Vector3(0.33 * side, 1.12 - WAIST_Y, 0.0), shirt.darkened(0.1),
			"ArmL" if side < 0.0 else "ArmR")
		_box(_upper_body, Vector3(0.11, 0.12, 0.12), Vector3(0.33 * side, 0.8 - WAIST_Y, 0.0), SKIN)
	_tool = _box(_upper_body, Vector3(0.05, 0.05, 0.55), Vector3(0.33, 0.85 - WAIST_Y, -0.25), TOOL_COLOR, "Tool")
	_tool.visible = false

	# Pivô na base do pescoço (topo do tronco): a cabeça roda sem se descolar.
	_head_pivot = Node3D.new()
	_head_pivot.name = "HeadPivot"
	_head_pivot.position = Vector3(0, NECK_Y - WAIST_Y, 0)
	_upper_body.add_child(_head_pivot)
	_box(_head_pivot, Vector3(0.3, 0.32, 0.3), Vector3(0, 0.16, 0), SKIN, "Head")
	_box(_head_pivot, Vector3(0.06, 0.05, 0.02), Vector3(-0.07, 0.19, -0.155), Color(0.1, 0.1, 0.1))
	_box(_head_pivot, Vector3(0.06, 0.05, 0.02), Vector3(0.07, 0.19, -0.155), Color(0.1, 0.1, 0.1))
	_cylinder(_head_pivot, 0.34, 0.03, Vector3(0, 0.34, 0), HAT)
	_cylinder(_head_pivot, 0.19, 0.16, Vector3(0, 0.43, 0), HAT)
	_cylinder(_head_pivot, 0.195, 0.04, Vector3(0, 0.38, 0), HAT_BAND)

	_label = Label3D.new()
	_label.name = "NameLabel"
	_label.position = Vector3(0, 2.2, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.0035
	_label.font_size = 40
	_label.outline_size = 10
	_label.no_depth_test = true
	add_child(_label)
	_update_label()


## Cor da camisa e nome a partir do peer dono deste jogador.
func setup(peer_id: int, display_name: String) -> void:
	_base_display_name = display_name
	var shirt: Color = SHIRTS[0] if peer_id == 1 else SHIRTS[1 + absi(peer_id) % (SHIRTS.size() - 1)]
	var torso: MeshInstance3D = get_node_or_null(^"UpperBody/Torso") as MeshInstance3D
	if torso != null:
		(torso.material_override as StandardMaterial3D).albedo_color = shirt
	var body: Node = _upper_body if _upper_body != null else self
	for child: Node in body.get_children():
		var mi: MeshInstance3D = child as MeshInstance3D
		if mi != null and mi.name.begins_with("Arm"):
			(mi.material_override as StandardMaterial3D).albedo_color = shirt.darkened(0.1)
	if _label != null:
		_label.modulate = shirt.lightened(0.35)
	_update_label()


func set_downed(downed: bool) -> void:
	_is_downed = downed
	if downed:
		rotation.x = deg_to_rad(-90.0)
		position.y = 0.2
		if _upper_body != null:
			_upper_body.rotation.x = 0.0
		if _head_pivot != null:
			_head_pivot.rotation.x = 0.0
		if _tool != null:
			_tool.visible = false
	else:
		rotation.x = 0.0
		position.y = 0.0
	_update_label()


func is_downed() -> bool:
	return _is_downed


func _update_label() -> void:
	if _label == null:
		return
	if _is_downed:
		var txt: String = tr(_base_display_name) if not _base_display_name.is_empty() else tr("Jogador")
		_label.text = tr("💀 %s (Caído)") % txt
		_label.position = Vector3(0, 0.6, 0)
	else:
		_label.text = _base_display_name
		_label.position = Vector3(0, 2.2, 0)


func set_pitch(pitch: float) -> void:
	if _is_downed:
		return
	var lean: float = get_torso_lean(pitch)
	if _upper_body != null:
		_upper_body.rotation.x = lean
	if _head_pivot != null:
		_head_pivot.rotation.x = get_head_pitch(pitch, lean)


## Inclinação do tronco para um pitch da câmara: só o que passa do limite da cabeça, a meias.
static func get_torso_lean(pitch: float) -> float:
	var excess: float = signf(pitch) * maxf(absf(pitch) - HEAD_PITCH_MAX, 0.0)
	return clampf(excess * TORSO_LEAN_SHARE, -TORSO_LEAN_MAX, TORSO_LEAN_MAX)


## Rotação da cabeça (relativa ao tronco já inclinado), sempre dentro de ±HEAD_PITCH_MAX.
static func get_head_pitch(pitch: float, lean: float) -> float:
	return clampf(pitch - lean, -HEAD_PITCH_MAX, HEAD_PITCH_MAX)


func set_tool(tool_id: StringName) -> void:
	if _tool != null:
		_tool.visible = (tool_id != &"" and not _is_downed)


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
