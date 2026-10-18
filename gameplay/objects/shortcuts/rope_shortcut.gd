class_name RopeShortcut
extends Node3D

## Atalho físico de Tirolesa ou Ponte de Corda construído com o arpão (#105).
## Liga dois RopeAnchor no cenário.
## Persiste no save via GameState e sincroniza no coop para todos os jogadores.

signal shortcut_activated()

const GROUP: StringName = &"rope_shortcuts"
const ROPE_COLOR: Color = Color(0.74, 0.62, 0.44)
const WOOD_PLANK: Color = Color(0.50, 0.35, 0.20)
const METAL_PULLEY: Color = Color(0.30, 0.30, 0.34)

@export var shortcut_id: String = ""
@export var display_name: String = ""
@export var shortcut_type: String = "zipline" # "zipline" ou "rope_bridge"
@export var anchor_a_path: NodePath
@export var anchor_b_path: NodePath

var anchor_a: RopeAnchor = null
var anchor_b: RopeAnchor = null
var is_built: bool = false

var _visual_root: Node3D = null
var _bridge_body: StaticBody3D = null
var _zipline_trigger: Area3D = null
var _zipline_start: Vector3 = Vector3.ZERO
var _zipline_end: Vector3 = Vector3.ZERO
var _pulley_mesh: Node3D = null


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	_resolve_anchors()

	if GameState.instance != null:
		GameState.instance.shortcut_built.connect(_on_global_shortcut_built)
		if GameState.instance.is_shortcut_built(shortcut_id):
			setup_built()


func _resolve_anchors() -> void:
	if anchor_a == null and not anchor_a_path.is_empty():
		anchor_a = get_node_or_null(anchor_a_path) as RopeAnchor
	if anchor_b == null and not anchor_b_path.is_empty():
		anchor_b = get_node_or_null(anchor_b_path) as RopeAnchor

	# Se não foram fornecidos caminhos explícitos, busca pelos IDs no grupo
	if (anchor_a == null or anchor_b == null) and is_inside_tree():
		for node: Node in get_tree().get_nodes_in_group(RopeAnchor.GROUP):
			var a: RopeAnchor = node as RopeAnchor
			if a == null or not is_instance_valid(a):
				continue
			if a.shortcut_id == shortcut_id:
				if anchor_a == null:
					anchor_a = a
				elif anchor_b == null and a != anchor_a:
					anchor_b = a


func setup_built() -> void:
	if is_built:
		return
	is_built = true
	_resolve_anchors()
	if anchor_a != null:
		anchor_a.set_hooked(true)
	if anchor_b != null:
		anchor_b.set_hooked(true)

	_build_shortcut_visuals()
	shortcut_activated.emit()


func build() -> void:
	if is_built:
		return
	setup_built()
	if GameState.instance != null and not shortcut_id.is_empty():
		GameState.instance.build_shortcut(shortcut_id)


func _on_global_shortcut_built(s_id: String) -> void:
	if s_id == shortcut_id:
		setup_built()


func _build_shortcut_visuals() -> void:
	if _visual_root != null:
		_visual_root.queue_free()
	_visual_root = Node3D.new()
	_visual_root.name = "ShortcutVisuals"
	add_child(_visual_root)

	if anchor_a == null or anchor_b == null:
		return

	var pos_a: Vector3 = anchor_a.get_hook_point()
	var pos_b: Vector3 = anchor_b.get_hook_point()

	if shortcut_type == "zipline":
		_build_zipline(pos_a, pos_b)
	else:
		_build_rope_bridge(pos_a, pos_b)


func _build_zipline(pos_a: Vector3, pos_b: Vector3) -> void:
	# A tirolesa sempre desliza do ponto mais alto para o mais baixo
	if pos_a.y >= pos_b.y:
		_zipline_start = pos_a
		_zipline_end = pos_b
	else:
		_zipline_start = pos_b
		_zipline_end = pos_a

	var dir: Vector3 = _zipline_end - _zipline_start
	var dist: float = dir.length()
	if dist < 0.5:
		return

	# 1. Cabo de aço / corda trançada tensionado entre os postes
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.025
	cyl.bottom_radius = 0.025
	cyl.height = dist
	cyl.radial_segments = 6
	mi.mesh = cyl

	var mat_rope: StandardMaterial3D = StandardMaterial3D.new()
	mat_rope.albedo_color = ROPE_COLOR
	mat_rope.roughness = 0.8
	mi.material_override = mat_rope

	_visual_root.add_child(mi)
	mi.global_position = (_zipline_start + _zipline_end) * 0.5
	var up_vec: Vector3 = dir.normalized()
	var perp: Vector3 = Vector3.UP if absf(up_vec.y) < 0.9 else Vector3.FORWARD
	var right_vec: Vector3 = up_vec.cross(perp).normalized()
	var fwd_vec: Vector3 = right_vec.cross(up_vec).normalized()
	mi.global_transform.basis = Basis(right_vec, up_vec, fwd_vec)

	# 2. Roldana/gancho de metal posicionada no ponto inicial da tirolesa
	_pulley_mesh = Node3D.new()
	_pulley_mesh.name = "Pulley"
	_visual_root.add_child(_pulley_mesh)
	_pulley_mesh.global_position = _zipline_start + dir.normalized() * 0.4 - Vector3.UP * 0.15
	var st_pulley: SurfaceTool = SurfaceTool.new()
	st_pulley.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyMesh.box(st_pulley, Vector3.ZERO, Vector3(0.08, 0.16, 0.12), Basis.IDENTITY, METAL_PULLEY)
	LowPolyMesh.box(st_pulley, Vector3(0.0, -0.15, 0.0), Vector3(0.35, 0.04, 0.04), Basis.IDENTITY, WOOD_PLANK)
	var p_mesh: MeshInstance3D = LowPolyMesh.commit(st_pulley, "PulleyHandle", ToonKit.vertex_material(true, true))
	_pulley_mesh.add_child(p_mesh)

	# 3. Área de interação no topo para embarcar
	_zipline_trigger = Area3D.new()
	_zipline_trigger.name = "ZiplineTrigger"
	_zipline_trigger.collision_layer = 1 << 2 # camada de interações
	_zipline_trigger.collision_mask = 1 | (1 << 1)
	var trig_col: CollisionShape3D = CollisionShape3D.new()
	var trig_sphere: SphereShape3D = SphereShape3D.new()
	trig_sphere.radius = 2.4
	trig_col.shape = trig_sphere
	_zipline_trigger.add_child(trig_col)
	_visual_root.add_child(_zipline_trigger)
	_zipline_trigger.global_position = _zipline_start


func _build_rope_bridge(pos_a: Vector3, pos_b: Vector3) -> void:
	var delta_pos: Vector3 = pos_b - pos_a
	var dist: float = delta_pos.length()
	if dist < 0.8:
		return

	var center: Vector3 = (pos_a + pos_b) * 0.5
	var dir_norm: Vector3 = delta_pos.normalized()

	# 1. Corpo físico sólido para o passadiço da ponte
	_bridge_body = StaticBody3D.new()
	_bridge_body.name = "BridgeCollider"
	_bridge_body.collision_layer = 1 # camada de colisão do chão
	_bridge_body.collision_mask = 0

	var b_shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(1.15, 0.16, dist)
	b_shape.shape = box
	_bridge_body.add_child(b_shape)

	_visual_root.add_child(_bridge_body)
	_bridge_body.global_position = center - Vector3.UP * 0.08
	# Alinha Z com o vetor de comprimento da ponte
	var fwd: Vector3 = dir_norm
	var perp: Vector3 = Vector3.UP if absf(fwd.y) < 0.9 else Vector3.FORWARD
	var right: Vector3 = perp.cross(fwd).normalized()
	var up: Vector3 = fwd.cross(right).normalized()
	_bridge_body.global_transform.basis = Basis(right, up, fwd)

	# 2. Malha detalhada: cordas laterais de piso e corrimão, e tábuas transversais
	var st_wood: SurfaceTool = SurfaceTool.new()
	st_wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_rope: SurfaceTool = SurfaceTool.new()
	st_rope.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Corrimãos superiores contínuos nas duas laterais
	for side: float in [-0.50, 0.50]:
		var top_a: Vector3 = (pos_a - center) + right * side + up * 0.75
		var top_b: Vector3 = (pos_b - center) + right * side + up * 0.75
		LowPolyMesh.prism(st_rope, top_a, top_b, 0.024, 0.024, 4, ROPE_COLOR)

	# Número de tábuas de acordo com o comprimento
	var plank_count: int = maxi(int(dist / 0.48), 2)
	for i: int in range(plank_count + 1):
		var t: float = float(i) / float(plank_count)
		var p_pos: Vector3 = pos_a.lerp(pos_b, t) - center
		# Ligeira curvatura côncava no meio (balanço de ponte suspensa)
		var sag: float = sin(t * PI) * 0.15
		p_pos.y -= sag

		# Tábua transversal de madeira
		var p_basis: Basis = Basis(right, up, fwd)
		LowPolyMesh.box(st_wood, p_pos - up * 0.04, Vector3(1.12, 0.05, 0.32), p_basis, WOOD_PLANK)

		# Cordas verticais que unem o piso ao corrimão
		for side: float in [-0.50, 0.50]:
			var bottom_p: Vector3 = p_pos + right * side
			var top_p: Vector3 = bottom_p + up * 0.75
			LowPolyMesh.prism(st_rope, bottom_p, top_p, 0.018, 0.018, 4, ROPE_COLOR)

	var mat_wood: ShaderMaterial = ToonKit.vertex_material(true, true)
	var mat_rope: StandardMaterial3D = StandardMaterial3D.new()
	mat_rope.albedo_color = ROPE_COLOR
	mat_rope.roughness = 0.85

	var w_inst: MeshInstance3D = LowPolyMesh.commit(st_wood, "BridgePlanks", mat_wood)
	_visual_root.add_child(w_inst)
	w_inst.global_position = center

	var r_inst: MeshInstance3D = LowPolyMesh.commit(st_rope, "BridgeRopes", mat_rope)
	_visual_root.add_child(r_inst)
	r_inst.global_position = center


## Retorna se o jogador está em posição de embarque na tirolesa
func can_player_zipline(player: Player) -> bool:
	if not is_built or shortcut_type != "zipline" or player == null:
		return false
	var dist: float = player.global_position.distance_to(_zipline_start)
	return dist <= 3.2


func get_zipline_start() -> Vector3:
	return _zipline_start


func get_zipline_end() -> Vector3:
	return _zipline_end


## Cria e instancia programaticamente um par de ancoras e o atalho correspondente
static func create_shortcut(parent: Node, id: String, d_name: String, type: String, pos_a: Vector3, pos_b: Vector3) -> RopeShortcut:
	var anchor_script: Script = load("res://gameplay/objects/shortcuts/rope_anchor.gd")
	var sc_script: Script = load("res://gameplay/objects/shortcuts/rope_shortcut.gd")

	var a_id: String = id + "_anchor_a"
	var b_id: String = id + "_anchor_b"

	var a: RopeAnchor = anchor_script.new()
	a.name = "AnchorA_" + id
	a.anchor_id = a_id
	a.pair_anchor_id = b_id
	a.shortcut_id = id
	a.shortcut_name = d_name
	a.shortcut_type = type
	a.position = pos_a
	parent.add_child(a)

	var b: RopeAnchor = anchor_script.new()
	b.name = "AnchorB_" + id
	b.anchor_id = b_id
	b.pair_anchor_id = a_id
	b.shortcut_id = id
	b.shortcut_name = d_name
	b.shortcut_type = type
	b.position = pos_b
	parent.add_child(b)

	var sc: RopeShortcut = sc_script.new()
	sc.name = "Shortcut_" + id
	sc.shortcut_id = id
	sc.display_name = d_name
	sc.shortcut_type = type
	sc.anchor_a = a
	sc.anchor_b = b
	parent.add_child(sc)

	if GameState.instance != null and GameState.instance.is_shortcut_built(id):
		sc.setup_built()

	return sc

