class_name RopeAnchor
extends StaticBody3D

## Poste de ancoragem para atalhos construídos com o arpão (#105).
## Postes são cravados no chão em pares nas Ruínas e na Geleira.
## Disparar o Arpão de Corda entre dois postes interligados estica
## uma Tirolesa (se desnível acentuado) ou Ponte de Corda (se vão plano).

const GROUP: StringName = &"rope_anchors"

@export var anchor_id: String = ""
@export var pair_anchor_id: String = ""
@export var shortcut_id: String = ""
@export var shortcut_name: String = ""
@export var shortcut_type: String = "zipline" # "zipline" ou "rope_bridge"

const WOOD_DARK: Color = Color(0.38, 0.25, 0.14)
const WOOD_GRAIN: Color = Color(0.52, 0.36, 0.22)
const IRON_RUST: Color = Color(0.28, 0.28, 0.30)
const ROPE_COLOR: Color = Color(0.76, 0.64, 0.44)
const GLOW_TARGET: Color = Color(1.0, 0.88, 0.35)

var is_hooked: bool = false
var _model_root: Node3D = null
var _ring_mesh: MeshInstance3D = null
var _highlight_mesh: MeshInstance3D = null


func _enter_tree() -> void:
	add_to_group(GROUP)
	add_to_group(&"interactive")


func _ready() -> void:
	collision_layer = 1 | (1 << 2) # mundo e objetos interativos
	collision_mask = 1

	var col: CollisionShape3D = CollisionShape3D.new()
	col.name = "Collision"
	var cyl: CylinderShape3D = CylinderShape3D.new()
	cyl.height = 1.6
	cyl.radius = 0.25
	col.shape = cyl
	col.position = Vector3(0.0, 0.8, 0.0)
	add_child(col)

	_build_visuals()


func get_hook_point() -> Vector3:
	return global_position + Vector3(0.0, 1.35, 0.0)


func is_shortcut_built() -> bool:
	if GameState.instance != null and not shortcut_id.is_empty():
		return GameState.instance.is_shortcut_built(shortcut_id)
	return false


func set_hooked(active: bool) -> void:
	is_hooked = active
	if _highlight_mesh != null:
		_highlight_mesh.visible = is_hooked


func set_targeted(active: bool) -> void:
	if _ring_mesh != null and not is_hooked:
		var mat: StandardMaterial3D = _ring_mesh.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color = GLOW_TARGET if active else IRON_RUST


func _build_visuals() -> void:
	_model_root = Node3D.new()
	_model_root.name = "ModelRoot"
	add_child(_model_root)

	var st_wood: SurfaceTool = SurfaceTool.new()
	st_wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_metal: SurfaceTool = SurfaceTool.new()
	st_metal.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 1. Tronco vertical de madeira chanfrada com 8 lados
	LowPolyMesh.prism(st_wood, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 1.45, 0.0), 0.18, 0.14, 8, WOOD_DARK)
	# Topo chanfrado arredondado
	LowPolyMesh.prism(st_wood, Vector3(0.0, 1.45, 0.0), Vector3(0.0, 1.55, 0.0), 0.14, 0.06, 6, WOOD_GRAIN)

	# 2. Base reforçada com pedras e cunhas de madeira
	for i: int in 5:
		var ang: float = float(i) * (TAU / 5.0)
		var b_pos: Vector3 = Vector3(cos(ang) * 0.22, 0.08, sin(ang) * 0.22)
		LowPolyMesh.box(st_wood, b_pos, Vector3(0.12, 0.16, 0.12), Basis(Vector3.UP, ang), WOOD_GRAIN)

	# 3. Abraçadeiras de ferro forjado e corda enrolada
	LowPolyMesh.prism(st_metal, Vector3(0.0, 0.40, 0.0), Vector3(0.0, 0.48, 0.0), 0.19, 0.19, 8, IRON_RUST)
	LowPolyMesh.prism(st_metal, Vector3(0.0, 1.25, 0.0), Vector3(0.0, 1.32, 0.0), 0.16, 0.16, 8, IRON_RUST)

	# Corda enrolada acima da base
	for k: int in 4:
		var y_off: float = 0.52 + float(k) * 0.05
		LowPolyMesh.prism(st_wood, Vector3(0.0, y_off, 0.0), Vector3(0.0, y_off + 0.04, 0.0), 0.185, 0.185, 8, ROPE_COLOR)

	var mat_wood: ShaderMaterial = ToonKit.vertex_material(true, true)
	_model_root.add_child(LowPolyMesh.commit(st_wood, "WoodPost", mat_wood))

	var mat_metal: StandardMaterial3D = StandardMaterial3D.new()
	mat_metal.albedo_color = IRON_RUST
	mat_metal.roughness = 0.7
	var metal_inst: MeshInstance3D = LowPolyMesh.commit(st_metal, "MetalStraps", mat_metal)
	_model_root.add_child(metal_inst)

	# 4. Argola de amarração de ferro forjado no topo
	_ring_mesh = MeshInstance3D.new()
	_ring_mesh.name = "AnchorRing"
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.09
	torus.outer_radius = 0.16
	torus.rings = 10
	torus.ring_segments = 6
	_ring_mesh.mesh = torus
	_ring_mesh.material_override = mat_metal.duplicate()
	_ring_mesh.position = Vector3(0.0, 1.35, 0.14)
	_ring_mesh.rotation = Vector3(deg_to_rad(45.0), 0.0, 0.0)
	_model_root.add_child(_ring_mesh)

	# 5. Indicador de gancho cravado (visível quando is_hooked)
	_highlight_mesh = MeshInstance3D.new()
	_highlight_mesh.name = "HookIndicator"
	var h_box: BoxMesh = BoxMesh.new()
	h_box.size = Vector3(0.08, 0.22, 0.08)
	_highlight_mesh.mesh = h_box
	var h_mat: StandardMaterial3D = StandardMaterial3D.new()
	h_mat.albedo_color = Color(1.0, 0.85, 0.25)
	h_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_highlight_mesh.material_override = h_mat
	_highlight_mesh.position = Vector3(0.0, 1.48, 0.14)
	_highlight_mesh.visible = false
	_model_root.add_child(_highlight_mesh)
