class_name PlayerAvatar
extends Node3D

## Corpo low-poly do jogador visto pelos OUTROS (o jogador local só vê as mãos em 1.ª
## pessoa): pernas, tronco com camisa da cor do peer, braços, cabeça com chapéu de
## explorador e um nome por cima. A cabeça acompanha o pitch replicado (Head.rotation.x)
## e a mão direita mostra que há uma ferramenta na mão (held_tool_id). Pitch grande (a olhar
## para o chão, ex.: a cavar) divide-se entre a cabeça (até ±HEAD_PITCH_MAX, pivô na base do
## pescoço) e uma inclinação do tronco à cintura, para a cabeça nunca parecer solta (#35).
## Geometria facetada cosmética, com ferramentas reais em cache; origem nos pés.

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
const NpcBody = preload("res://gameplay/quests/npc_body.gd")
const TOOL_MODELS: Dictionary = {
	&"detector": "res://gameplay/detector/detector_model.gd",
	&"pa": "res://gameplay/player/shovel_model.gd",
	&"estilingue": "res://gameplay/weapons/slingshot/slingshot_model.gd",
	&"forcado": "res://gameplay/weapons/pitchfork/pitchfork_model.gd",
	&"lanterna_magnesio": "res://gameplay/weapons/lantern/lantern_model.gd",
	&"arpao_corda": "res://gameplay/weapons/harpoon/harpoon_model.gd",
	&"pulso_magnetico": "res://gameplay/weapons/magnetic_pulse/magnetic_pulse_model.gd",
	&"repelente": "res://gameplay/weapons/repellent/repellent_model.gd",
	&"armadilha_rede": "res://gameplay/weapons/net_trap/net_trap_model.gd",
	&"kit_medico": "res://gameplay/weapons/medkit/medkit_model.gd",
	&"dinamite": "res://gameplay/weapons/dynamite/dynamite_model.gd",
	&"carne_crua": "res://gameplay/weapons/dynamite/raw_meat_model.gd",
}

var _tool: Node3D = null
var _tool_cache: Dictionary = {}
var _held_tool: StringName = &""
var _peer_slot: int = 0
var _marks: Node3D = null
var _label: Label3D = null
var _is_downed: bool = false
var _base_display_name: String = ""


func _ready() -> void:
	var legs: SurfaceTool = _begin()
	for side: float in [-1.0, 1.0]:
		NpcBody.limb(legs, Vector3(side * 0.13, 0.84, 0.0), Vector3(side * 0.145, 0.49, 0.0), 0.105, 0.085, PANTS)
		NpcBody.limb(legs, Vector3(side * 0.145, 0.49, 0.0), Vector3(side * 0.15, 0.19, 0.015), 0.085, 0.07, PANTS.darkened(0.08))
		NpcBody.boot(legs, Vector3(side * 0.15, 0.0, 0.0), BOOTS, BOOTS.darkened(0.5), 1.15)
		LowPolyMesh.box(legs, Vector3(side * 0.145, 0.47, -0.078), Vector3(0.11, 0.13, 0.017), Basis.IDENTITY, PANTS.lightened(0.14))
	_part(self, &"Legs", legs)
	_upper_body = Node3D.new()
	_upper_body.name = "UpperBody"
	_upper_body.position.y = WAIST_Y
	add_child(_upper_body)
	_build_shirt()
	var gear: SurfaceTool = _begin()
	LowPolyMesh.box(gear, Vector3(0, 0.025, 0), Vector3(0.47, 0.075, 0.30), Basis.IDENTITY, HAT_BAND)
	LowPolyMesh.box(gear, Vector3(0, 0.025, -0.16), Vector3(0.09, 0.055, 0.025), Basis.IDENTITY, Color(0.65, 0.53, 0.27))
	# Shoulder strap and a small finds satchel; no collision or interaction nodes.
	NpcBody.limb(gear, Vector3(0.19, 0.55, -0.15), Vector3(-0.21, 0.06, -0.17), 0.025, 0.025, HAT_BAND, 4)
	NpcBody.blob(gear, Vector3(-0.23, 0.15, 0.20), Vector3(0.14, 0.18, 0.085), HAT_BAND, 6)
	LowPolyMesh.box(gear, Vector3(-0.23, 0.21, 0.285), Vector3(0.19, 0.12, 0.025), Basis.IDENTITY, HAT_BAND.lightened(0.12))
	_part(_upper_body, "FieldGear", gear)
	_marks = Node3D.new()
	_marks.name = "PeerMarks"
	_upper_body.add_child(_marks)
	_build_marks()
	_tool = Node3D.new()
	_tool.name = "Tool"
	_tool.position = Vector3(0.37, 0.84 - WAIST_Y, -0.035)
	_upper_body.add_child(_tool)
	_head_pivot = Node3D.new()
	_head_pivot.name = "HeadPivot"
	_head_pivot.position.y = NECK_Y - WAIST_Y
	_upper_body.add_child(_head_pivot)
	var head: SurfaceTool = _begin()
	NpcBody.limb(head, Vector3(0, -0.03, 0), Vector3(0, 0.075, 0), 0.085, 0.085, SKIN, 7)
	NpcBody.blob(head, Vector3(0, 0.21, 0), Vector3(0.205, 0.215, 0.19), SKIN, 8, 0.02, 160)
	NpcBody.blob(head, Vector3(0, 0.195, -0.188), Vector3(0.042, 0.055, 0.05), SKIN.darkened(0.04), 5)
	for side: float in [-1.0, 1.0]:
		NpcBody.blob(head, Vector3(side * 0.195, 0.20, 0), Vector3(0.04, 0.065, 0.045), SKIN, 5)
	NpcBody.face(head, Vector3(0, 0.21, -0.006), 0.2, HAT_BAND, 2, 0.045, 0.40)
	# Broad, faceted brim; tapered crown and contrasting work-hat band.
	NpcBody.limb(head, Vector3(0, 0.395, 0), Vector3(0, 0.425, 0), 0.31, 0.30, HAT, 10)
	NpcBody.limb(head, Vector3(0, 0.42, 0), Vector3(0, 0.56, 0), 0.19, 0.155, HAT, 8)
	NpcBody.limb(head, Vector3(0, 0.425, 0), Vector3(0, 0.465, 0), 0.195, 0.187, HAT_BAND, 8)
	_part(_head_pivot, "Head", head)
	_label = Label3D.new()
	_label.name = "NameLabel"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.0035
	_label.font_size = 40
	_label.outline_size = 10
	_label.no_depth_test = true
	add_child(_label)
	_label.modulate = SHIRTS[_peer_slot].lightened(0.35)
	_update_label()
	_sync_tool()


func _build_shirt() -> void:
	for node_name: String in ["Torso", &"Arms"]:
		var old: Node = _upper_body.get_node_or_null(NodePath(node_name))
		if old != null:
			_upper_body.remove_child(old)
			old.free()
	var shirt: Color = SHIRTS[_peer_slot]
	var st: SurfaceTool = _begin()
	NpcBody.blob(st, Vector3.ZERO, Vector3(0.28, 0.31, 0.175), shirt, 8)
	LowPolyMesh.box(st, Vector3(0.12, 0.025, -0.16), Vector3(0.115, 0.13, 0.03), Basis.IDENTITY, shirt.darkened(0.16))
	LowPolyMesh.box(st, Vector3(0.12, 0.077, -0.18), Vector3(0.125, 0.025, 0.02), Basis.IDENTITY, shirt.lightened(0.12))
	NpcBody.limb(st, Vector3(0, -0.20, -0.16), Vector3(0, 0.23, -0.16), 0.012, 0.012, shirt.darkened(0.25), 4)
	_part(_upper_body, "Torso", st, Vector3(0, 1.13 - WAIST_Y, 0))
	var arms: SurfaceTool = _begin()
	for side: float in [-1.0, 1.0]:
		NpcBody.limb(arms, Vector3(side * 0.24, 0.49, 0), Vector3(side * 0.34, 0.24, 0), 0.11, 0.082, shirt.darkened(0.07))
		NpcBody.limb(arms, Vector3(side * 0.34, 0.24, 0), Vector3(side * 0.37, 0.07, -0.035), 0.075, 0.065, SKIN)
		NpcBody.hand(arms, Vector3(side * 0.37, 0.0, -0.035), 0.073, SKIN, side)
	_part(_upper_body, &"Arms", arms)


func _build_marks() -> void:
	for child: Node in _marks.get_children():
		_marks.remove_child(child)
		child.free()
	# One to four cream bars encode the existing peer color slots without color alone.
	for i: int in _peer_slot + 1:
		var st: SurfaceTool = _begin()
		LowPolyMesh.box(st, Vector3(-0.16 + float(i) * 0.031, 0.42, -0.16), Vector3(0.018, 0.065, 0.016), Basis.IDENTITY, Color(0.94, 0.87, 0.66))
		_part(_marks, "Bar%d" % i, st)


func _begin() -> SurfaceTool:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


func _part(parent: Node3D, node_name: String, st: SurfaceTool, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var part: MeshInstance3D = MeshInstance3D.new()
	part.name = node_name
	part.mesh = ToonKit.commit(st)
	part.material_override = NpcBody.cloth_material(0.12)
	part.position = pos
	parent.add_child(part)
	return part


## Cor da camisa e nome a partir do peer dono deste jogador.
func setup(peer_id: int, display_name: String) -> void:
	_base_display_name = display_name
	var next_slot: int = 0 if peer_id == 1 else 1 + absi(peer_id) % (SHIRTS.size() - 1)
	var changed: bool = next_slot != _peer_slot
	_peer_slot = next_slot
	if _upper_body != null and changed:
		_build_shirt()
		_build_marks()
	if _label != null:
		_label.modulate = SHIRTS[_peer_slot].lightened(0.35)
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
	_sync_tool()
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


## Player calls this every frame. Only first use of a known ID constructs a model.
func set_tool(tool_id: StringName) -> void:
	if _held_tool == tool_id:
		return
	_held_tool = tool_id
	_sync_tool()


func _sync_tool() -> void:
	if _tool == null:
		return
	_tool.visible = not _is_downed and TOOL_MODELS.has(_held_tool)
	for cached: Node3D in _tool_cache.values():
		cached.visible = false
	if not _tool.visible:
		return
	if not _tool_cache.has(_held_tool):
		var model: Node3D = (load(TOOL_MODELS[_held_tool]) as Script).new()
		model.name = String(_held_tool)
		if "show_hand" in model:
			model.set("show_hand", false)
		if "show_left_hand" in model:
			model.set("show_left_hand", false)
		match _held_tool:
			&"detector":
				model.scale = Vector3.ONE * 0.85
				model.position = Vector3(0, 0.0765, -0.051)
			&"pa":
				# D-handle crossbar at 1.012m; shorter remote model keeps blade clear of ground.
				model.scale = Vector3.ONE * 0.76
				model.position.y = -1.012 * 0.76
			&"forcado":
				model.rotation.z = -0.12
			&"lanterna_magnesio":
				model.position.y = -0.29
			&"kit_medico":
				# Model origin is the base; handle center is at .232m and cross faces +Z.
				model.position.y = -0.232
				model.rotation.y = PI
		_tool.add_child(model)
		_tool_cache[_held_tool] = model
	(_tool_cache[_held_tool] as Node3D).visible = true
