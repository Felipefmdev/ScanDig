@tool
class_name HandModel
extends Node3D

## Mão + pulso low-poly bege (estilo "How to Fish"): dedos em blocos facetados, polegar,
## punho da manga opcional. Malha gerada com SurfaceTool, normais por face, cores por vértice.
##
## Espaço local (mão direita; is_left espelha em X):
##   - GRIP_AXIS (X local) = eixo do cabo agarrado; o cabo passa por GRIP_CENTER (origem)
##     com raio até GRIP_RADIUS.
##   - +Y = costas da mão (nós dos dedos); os dedos enrolam à frente (-Z) e por baixo do cabo.
##   - +Z = pulso / antebraço (para o jogador).
## Na pose OPEN os dedos ficam esticados para -Z, com a palma virada para -Y.

enum Pose { OPEN, GRIP }

const SKIN: Color = Color(0.93, 0.76, 0.6)
const SKIN_SHADE: Color = Color(0.86, 0.67, 0.52)
const SLEEVE: Color = Color(0.93, 0.45, 0.2)

const GRIP_AXIS: Vector3 = Vector3.RIGHT
const GRIP_CENTER: Vector3 = Vector3.ZERO
const GRIP_RADIUS: float = 0.02

@export var is_left: bool = false:
	set(value):
		is_left = value
		_queue_rebuild()
@export var pose: Pose = Pose.GRIP:
	set(value):
		pose = value
		_queue_rebuild()
@export var skin_color: Color = SKIN:
	set(value):
		skin_color = value
		_queue_rebuild()
@export var show_sleeve: bool = true:
	set(value):
		show_sleeve = value
		_queue_rebuild()
@export var sleeve_color: Color = SLEEVE:
	set(value):
		sleeve_color = value
		_queue_rebuild()

var _mesh_instance: MeshInstance3D = null
var _rebuild_queued: bool = false


func _ready() -> void:
	rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	rebuild.call_deferred()


func rebuild() -> void:
	_rebuild_queued = false
	if _mesh_instance == null or not is_instance_valid(_mesh_instance):
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "Mesh"
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 0.85
		mat.metallic_specular = 0.2
		_mesh_instance.material_override = mat
		add_child(_mesh_instance)

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_build_palm_and_wrist(st)
	if pose == Pose.GRIP:
		_build_grip_fingers(st)
	else:
		_build_open_fingers(st)
	_mesh_instance.mesh = st.commit()


# ---------------------------------------------------------------------------
# Partes
# ---------------------------------------------------------------------------

func _build_palm_and_wrist(st: SurfaceTool) -> void:
	var skin: Color = skin_color
	if pose == Pose.GRIP:
		# Palma por cima/atrás do cabo, ligeiramente inclinada para o pulso.
		_box(st, Vector3(0.0, 0.034, 0.03), Vector3(0.084, 0.03, 0.075), Basis(Vector3.RIGHT, deg_to_rad(12.0)), skin)
		# Base do polegar (eminência tenar) no lado de dentro
		_box(st, Vector3(-0.035, 0.018, 0.04), Vector3(0.026, 0.034, 0.05), Basis(Vector3.UP, deg_to_rad(-10.0)), _shade(skin))
		_prism(st, Vector3(0.0, 0.045, 0.06), Vector3(0.0, 0.06, 0.15), 0.031, 0.034, 6, skin)
		if show_sleeve:
			_prism(st, Vector3(0.0, 0.058, 0.14), Vector3(0.0, 0.075, 0.26), 0.042, 0.046, 7, sleeve_color)
	else:
		_box(st, Vector3(0.0, 0.0, 0.02), Vector3(0.086, 0.028, 0.085), Basis.IDENTITY, skin)
		_box(st, Vector3(-0.035, -0.005, 0.035), Vector3(0.026, 0.03, 0.05), Basis(Vector3.UP, deg_to_rad(-12.0)), _shade(skin))
		_prism(st, Vector3(0.0, 0.0, 0.05), Vector3(0.0, 0.005, 0.14), 0.03, 0.033, 6, skin)
		if show_sleeve:
			_prism(st, Vector3(0.0, 0.004, 0.13), Vector3(0.0, 0.01, 0.25), 0.041, 0.045, 7, sleeve_color)


## Quatro dedos enrolados à volta do cabo (eixo X) + polegar por cima, a fechar o punho.
func _build_grip_fingers(st: SurfaceTool) -> void:
	var skin: Color = skin_color
	var xs: Array[float] = [0.03, 0.01, -0.01, -0.03]  # mindinho → indicador (o indicador fica do lado do polegar)
	var lengths: Array[float] = [0.85, 1.0, 1.05, 0.95]
	for i: int in xs.size():
		var x: float = xs[i]
		var k: float = lengths[i]
		var w: float = 0.018 if i > 0 else 0.016
		# Falange proximal: dos nós dos dedos para a frente e para baixo
		_box(st, Vector3(x, 0.03, -0.012), Vector3(w, 0.022, 0.03 * k), Basis(Vector3.RIGHT, deg_to_rad(35.0)), skin)
		# Falange média: à frente do cabo, a descer
		_box(st, Vector3(x, 0.002, -0.033), Vector3(w * 0.96, 0.034 * k, 0.02), Basis.IDENTITY, skin)
		# Falange distal: por baixo do cabo, a voltar para o pulso
		_box(st, Vector3(x, -0.028, -0.016), Vector3(w * 0.92, 0.018, 0.026 * k), Basis(Vector3.RIGHT, deg_to_rad(-25.0)), _shade(skin))
	# Polegar: sai da base, passa por cima dos dedos médios/indicador
	_box(st, Vector3(-0.047, 0.03, 0.006), Vector3(0.022, 0.022, 0.04), Basis(Vector3.UP, deg_to_rad(-35.0)), skin)
	_box(st, Vector3(-0.028, 0.045, -0.02), Vector3(0.02, 0.019, 0.03), Basis(Vector3.UP, deg_to_rad(-70.0)), _shade(skin))


func _build_open_fingers(st: SurfaceTool) -> void:
	var skin: Color = skin_color
	var xs: Array[float] = [0.031, 0.011, -0.009, -0.029]
	var lengths: Array[float] = [0.75, 0.95, 1.0, 0.9]
	for i: int in xs.size():
		var x: float = xs[i]
		var k: float = lengths[i]
		var spread: float = deg_to_rad(float(i) * 3.0 - 4.5)
		var b: Basis = Basis(Vector3.UP, spread)
		var w: float = 0.018 if i > 0 else 0.016
		var z0: float = -0.022
		_box(st, Vector3(x, 0.002, z0 - 0.018 * k), Vector3(w, 0.02, 0.036 * k), b, skin)
		_box(st, Vector3(x, 0.0, z0 - 0.048 * k), Vector3(w * 0.95, 0.018, 0.026 * k), b, skin)
		_box(st, Vector3(x, -0.002, z0 - 0.07 * k), Vector3(w * 0.9, 0.016, 0.02 * k), b, _shade(skin))
	# Polegar aberto para o lado
	_box(st, Vector3(-0.058, -0.004, 0.005), Vector3(0.02, 0.02, 0.04), Basis(Vector3.UP, deg_to_rad(40.0)), skin)
	_box(st, Vector3(-0.072, -0.004, -0.022), Vector3(0.018, 0.018, 0.03), Basis(Vector3.UP, deg_to_rad(25.0)), _shade(skin))


func _shade(c: Color) -> Color:
	return c.darkened(0.08) if c != SKIN else SKIN_SHADE


# ---------------------------------------------------------------------------
# Primitivas (normais por face; is_left espelha em X)
# ---------------------------------------------------------------------------

func _m(p: Vector3) -> Vector3:
	return Vector3(-p.x, p.y, p.z) if is_left else p


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, inside: Vector3, color: Color) -> void:
	a = _m(a)
	b = _m(b)
	c = _m(c)
	inside = _m(inside)
	var cr: Vector3 = (b - a).cross(c - a)
	if cr.length_squared() < 1e-12:
		return
	var outward: Vector3 = (a + b + c) / 3.0 - inside
	if cr.dot(outward) > 0.0:
		var tmp: Vector3 = b
		b = c
		c = tmp
		cr = -cr
	var n: Vector3 = -cr.normalized()
	for v: Vector3 in [a, b, c]:
		st.set_color(color)
		st.set_normal(n)
		st.add_vertex(v)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, inside: Vector3, color: Color) -> void:
	_tri(st, a, b, c, inside, color)
	_tri(st, a, c, d, inside, color)


func _prism(st: SurfaceTool, p0: Vector3, p1: Vector3, r0: float, r1: float, sides: int, color: Color) -> void:
	var axis: Vector3 = p1 - p0
	if axis.length_squared() < 1e-10:
		return
	var n: Vector3 = axis.normalized()
	var ref: Vector3 = Vector3.UP if absf(n.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var u: Vector3 = n.cross(ref).normalized()
	var v: Vector3 = n.cross(u).normalized()
	var mid: Vector3 = (p0 + p1) * 0.5
	var ring0: PackedVector3Array = PackedVector3Array()
	var ring1: PackedVector3Array = PackedVector3Array()
	for i: int in range(sides):
		var ang: float = TAU * float(i) / float(sides)
		var off: Vector3 = u * cos(ang) + v * sin(ang)
		ring0.append(p0 + off * r0)
		ring1.append(p1 + off * r1)
	for i: int in range(sides):
		var j: int = (i + 1) % sides
		_quad(st, ring0[i], ring0[j], ring1[j], ring1[i], mid, color)
		_tri(st, p0, ring0[i], ring0[j], mid, color)
		_tri(st, p1, ring1[j], ring1[i], mid, color)


func _box(st: SurfaceTool, center: Vector3, size: Vector3, basis: Basis, color: Color) -> void:
	var h: Vector3 = size * 0.5
	var c: Array[Vector3] = []
	for k: int in range(8):
		var local: Vector3 = Vector3(
			h.x if (k & 1) != 0 else -h.x,
			h.y if (k & 2) != 0 else -h.y,
			h.z if (k & 4) != 0 else -h.z
		)
		c.append(center + basis * local)
	_quad(st, c[0], c[1], c[3], c[2], center, color)
	_quad(st, c[4], c[5], c[7], c[6], center, color)
	_quad(st, c[0], c[1], c[5], c[4], center, color)
	_quad(st, c[2], c[3], c[7], c[6], center, color)
	_quad(st, c[0], c[2], c[6], c[4], center, color)
	_quad(st, c[1], c[3], c[7], c[5], center, color)
