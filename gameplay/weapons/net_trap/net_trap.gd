class_name NetTrap
extends Area3D

## Armadilha de rede colocada no chão: o primeiro inimigo que a pisar fica atordoado
## (stun) e leva dano; a rede fecha-se à volta dele e desaparece.

signal triggered(enemy: Node3D)

const ENEMY_LAYER_MASK: int = 1 << 3  # layer 4
const ROPE: Color = Color(0.78, 0.7, 0.5)
const WEIGHT: Color = Color(0.25, 0.25, 0.28)

@export var stun_seconds: float = 5.0
@export var damage: float = 15.0
@export var radius: float = 0.75
## Tempo até ficar armada (evita disparar no instante em que é pousada).
@export var arm_delay: float = 0.4

var _armed: bool = false
var _sprung: bool = false
var _visual: Node3D = null


static func place(parent: Node, ground_point: Vector3, facing_y: float = 0.0) -> NetTrap:
	var trap: NetTrap = NetTrap.new()
	parent.add_child(trap)
	trap.global_position = ground_point
	trap.rotation.y = facing_y
	return trap


func _ready() -> void:
	collision_layer = 0
	collision_mask = ENEMY_LAYER_MASK
	monitoring = true
	monitorable = false
	var shape: CollisionShape3D = CollisionShape3D.new()
	var cyl: CylinderShape3D = CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = 0.6
	shape.shape = cyl
	shape.position.y = 0.3
	add_child(shape)
	body_entered.connect(_on_body_entered)

	_visual = _build_visual()
	add_child(_visual)
	_visual.scale = Vector3.ONE * 0.2
	var t: Tween = create_tween()
	t.tween_property(_visual, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(arm_delay).timeout.connect(_arm)


func _arm() -> void:
	_armed = true
	for body: Node3D in get_overlapping_bodies():
		_on_body_entered(body)


func _on_body_entered(body: Node3D) -> void:
	if not _armed or _sprung or not body.is_in_group("enemies"):
		return
	if body.has_method("is_alive") and not body.call("is_alive"):
		return
	_sprung = true
	if body.has_method("stun"):
		body.call("stun", stun_seconds)
	if body.has_method("take_damage"):
		body.call("take_damage", damage, global_position)
	SFX.play_at(SFX.NET_CLOSE, global_position, 2.0)
	triggered.emit(body)
	# A rede fecha-se para cima à volta do inimigo e some.
	var t: Tween = create_tween()
	t.tween_property(_visual, "scale", Vector3(0.45, 2.2, 0.45), 0.2).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.6)
	t.tween_property(_visual, "scale", Vector3.ZERO, 0.3)
	t.tween_callback(queue_free)


## Rede em grelha de cordas finas + 4 pesos nos cantos (low-poly, cores por vértice).
func _build_visual() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Net"
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lines: int = 6
	var size: float = radius * 1.8
	for i: int in lines + 1:
		var f: float = -size * 0.5 + size * float(i) / float(lines)
		_box(st, Vector3(f, 0.02, 0.0), Vector3(0.018, 0.012, size), ROPE)
		_box(st, Vector3(0.0, 0.025, f), Vector3(size, 0.012, 0.018), ROPE)
	for corner: Vector3 in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, 1)]:
		_box(st, corner * size * 0.5 + Vector3(0, 0.035, 0), Vector3(0.07, 0.07, 0.07), WEIGHT)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mi.material_override = mat
	root.add_child(mi)
	return root


func _box(st: SurfaceTool, center: Vector3, size: Vector3, color: Color) -> void:
	var h: Vector3 = size * 0.5
	var c: Array[Vector3] = []
	for k: int in range(8):
		c.append(center + Vector3(
			h.x if (k & 1) != 0 else -h.x,
			h.y if (k & 2) != 0 else -h.y,
			h.z if (k & 4) != 0 else -h.z
		))
	var faces: Array = [[0, 1, 3, 2, Vector3.FORWARD], [4, 5, 7, 6, Vector3.BACK], [0, 1, 5, 4, Vector3.DOWN],
		[2, 3, 7, 6, Vector3.UP], [0, 2, 6, 4, Vector3.LEFT], [1, 3, 7, 5, Vector3.RIGHT]]
	for f: Array in faces:
		var n: Vector3 = f[4]
		var a: Vector3 = c[f[0]]
		var b: Vector3 = c[f[1]]
		var cc: Vector3 = c[f[2]]
		var d: Vector3 = c[f[3]]
		# Ordem dos vértices (sentido horário visto de fora) para cada triângulo.
		for tri: Array in [[a, b, cc], [a, cc, d]]:
			var p0: Vector3 = tri[0]
			var p1: Vector3 = tri[1]
			var p2: Vector3 = tri[2]
			if (p1 - p0).cross(p2 - p0).dot(n) > 0.0:
				var tmp: Vector3 = p1
				p1 = p2
				p2 = tmp
			for v: Vector3 in [p0, p1, p2]:
				st.set_color(color)
				st.set_normal(n)
				st.add_vertex(v)
