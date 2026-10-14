@tool
class_name SlingshotModel
extends Node3D

## Estilingue low-poly facetado (SurfaceTool, normais por face, cores por vértice).
## Espaço local: o cabo vai ao longo de Y com o centro da pega na origem (onde a HandModel
## agarra); a forquilha abre para cima; -Z = para onde dispara; o elástico fica em +Z.

const WOOD: Color = Color(0.55, 0.35, 0.2)
const WOOD_DARK: Color = Color(0.42, 0.26, 0.15)
const RUBBER: Color = Color(0.85, 0.2, 0.15)
const LEATHER: Color = Color(0.3, 0.2, 0.14)

## Topo das duas pontas da forquilha (o elástico prende aqui).
const TIP_LEFT: Vector3 = Vector3(-0.055, 0.15, 0.0)
const TIP_RIGHT: Vector3 = Vector3(0.055, 0.15, 0.0)

## 0 = elástico em repouso, 1 = puxado ao máximo (animação de tiro).
@export_range(0.0, 1.0) var pull: float = 0.0:
	set(value):
		pull = value
		if is_inside_tree():
			_rebuild_band()

var _band: MeshInstance3D = null


func _ready() -> void:
	for child: Node in get_children():
		child.queue_free()
	var mat: StandardMaterial3D = _make_material()

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Cabo (pega) e base da forquilha
	_prism(st, Vector3(0.0, -0.075, 0.0), Vector3(0.0, 0.035, 0.0), 0.017, 0.019, 6, WOOD)
	_prism(st, Vector3(0.0, -0.085, 0.0), Vector3(0.0, -0.075, 0.0), 0.012, 0.017, 6, WOOD_DARK)
	# Braços da forquilha
	_prism(st, Vector3(0.0, 0.03, 0.0), TIP_LEFT + Vector3(0.0, -0.01, 0.0), 0.016, 0.012, 6, WOOD)
	_prism(st, Vector3(0.0, 0.03, 0.0), TIP_RIGHT + Vector3(0.0, -0.01, 0.0), 0.016, 0.012, 6, WOOD)
	# Pontas mais escuras (onde o elástico prende)
	_prism(st, TIP_LEFT + Vector3(0.0, -0.015, 0.0), TIP_LEFT + Vector3(0.0, 0.008, 0.0), 0.014, 0.012, 6, WOOD_DARK)
	_prism(st, TIP_RIGHT + Vector3(0.0, -0.015, 0.0), TIP_RIGHT + Vector3(0.0, 0.008, 0.0), 0.014, 0.012, 6, WOOD_DARK)
	var body: MeshInstance3D = MeshInstance3D.new()
	body.name = "Body"
	body.mesh = st.commit()
	body.material_override = mat
	add_child(body)

	_band = MeshInstance3D.new()
	_band.name = "Band"
	_band.material_override = mat
	add_child(_band)
	_rebuild_band()


func _rebuild_band() -> void:
	if _band == null:
		return
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pouch: Vector3 = Vector3(0.0, 0.135, 0.035 + pull * 0.16)
	_prism(st, TIP_LEFT, pouch + Vector3(-0.014, 0.0, 0.0), 0.005, 0.005, 4, RUBBER)
	_prism(st, TIP_RIGHT, pouch + Vector3(0.014, 0.0, 0.0), 0.005, 0.005, 4, RUBBER)
	_box(st, pouch, Vector3(0.032, 0.02, 0.016), Basis.IDENTITY, LEATHER)
	_band.mesh = st.commit()


func _make_material() -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.85
	return mat


# --- Primitivas (iguais às da HandModel/DetectorModel) ----------------------

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, inside: Vector3, color: Color) -> void:
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
