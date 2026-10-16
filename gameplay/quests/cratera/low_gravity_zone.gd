class_name LowGravityZone
extends Area3D

## Zona de Gravidade Baixa (#44):
## Campo de distorção gravitacional alienígena.
## Reduz a gravidade do espaço e amplifica o salto e flutuação do jogador.

@export var low_gravity: float = 3.2
@export var boosted_jump: float = 7.2
@export var zone_radius: float = 4.5
@export var zone_height: float = 8.0

var _original_jumps: Dictionary = {}


func _ready() -> void:
	gravity_space_override = Area3D.SPACE_OVERRIDE_REPLACE
	gravity_point = false
	gravity_direction = Vector3.DOWN
	gravity = low_gravity

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if get_node_or_null(^"Collision") == null:
		var col := CollisionShape3D.new()
		col.name = "Collision"
		var cyl := CylinderShape3D.new()
		cyl.radius = zone_radius
		cyl.height = zone_height
		col.shape = cyl
		col.position.y = zone_height * 0.5
		add_child(col)

	_build_visuals()


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		var current_jump: float = 4.2
		var val: Variant = body.get("jump_velocity")
		if val != null:
			current_jump = float(val)
		_original_jumps[body.get_instance_id()] = current_jump
		body.set("jump_velocity", boosted_jump)
		if body.has_method("_show_temporary_message"):
			body.call("_show_temporary_message", "🌌 Gravidade Baixa Ativa! Salto amplificado!", Color(0.75, 0.5, 1.0), 1.2)


func _on_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		var id: int = body.get_instance_id()
		var orig_jump: float = float(_original_jumps.get(id, 4.2))
		body.set("jump_velocity", orig_jump)
		_original_jumps.erase(id)


func _build_visuals() -> void:
	# Anel de cristais flutuantes e partículas no perímetro da zona (sem owner, regra #47)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var ring_col: Color = Color(0.65, 0.35, 0.95, 0.8)
	var glow_cyan: Color = Color(0.3, 0.9, 0.95, 0.9)

	for k: int in range(6):
		var ang: float = TAU * float(k) / 6.0
		var pos: Vector3 = Vector3(cos(ang) * zone_radius, 0.05, sin(ang) * zone_radius)
		# Marcadores nos cantos da zona
		LowPolyMesh.prism(st, pos, pos + Vector3(0.0, 0.5, 0.0), 0.12, 0.02, 5, ring_col)
		# Fragmentos flutuantes a meia altura
		var float_p: Vector3 = pos * 0.85 + Vector3(0.0, 2.0 + float(k % 2) * 1.5, 0.0)
		LowPolyMesh.prism(st, float_p, float_p + Vector3(0.0, 0.25, 0.0), 0.08, 0.015, 4, glow_cyan)

	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "ZoneVisual"
	mi.mesh = ToonKit.commit(st)
	mi.material_override = ToonKit.vertex_material(true, true)
	add_child(mi)
