class_name LowPolyMesh
extends RefCounted

## Geradores de malhas low-poly facetadas (estilo "How to Fish") para inimigos: normais por face,
## cores por vértice e winding horário (face da frente no Godot). Peças convexas: cada triângulo
## é orientado para fora de um ponto interior.


static func tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, inside: Vector3, color: Color) -> void:
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


static func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, inside: Vector3, color: Color) -> void:
	tri(st, a, b, c, inside, color)
	tri(st, a, c, d, inside, color)


## Prisma/tronco de cone entre p0 e p1 (r1 = 0 dá um cone).
static func prism(st: SurfaceTool, p0: Vector3, p1: Vector3, r0: float, r1: float, sides: int, color: Color) -> void:
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
		if r1 > 0.0001:
			quad(st, ring0[i], ring0[j], ring1[j], ring1[i], mid, color)
			tri(st, p1, ring1[j], ring1[i], mid, color)
		else:
			tri(st, ring0[i], ring0[j], p1, mid, color)
		if r0 > 0.0001:
			tri(st, p0, ring0[i], ring0[j], mid, color)


static func box(st: SurfaceTool, center: Vector3, size: Vector3, basis: Basis, color: Color) -> void:
	var h: Vector3 = size * 0.5
	var c: Array[Vector3] = []
	for k: int in range(8):
		var local: Vector3 = Vector3(
			h.x if (k & 1) != 0 else -h.x,
			h.y if (k & 2) != 0 else -h.y,
			h.z if (k & 4) != 0 else -h.z
		)
		c.append(center + basis * local)
	quad(st, c[0], c[1], c[3], c[2], center, color)
	quad(st, c[4], c[5], c[7], c[6], center, color)
	quad(st, c[0], c[1], c[5], c[4], center, color)
	quad(st, c[2], c[3], c[7], c[6], center, color)
	quad(st, c[0], c[2], c[6], c[4], center, color)
	quad(st, c[1], c[3], c[7], c[5], center, color)


## Material toon (#36) para malhas com cor por vértice, com contorno preto em next_pass.
## As cores destes modelos foram afinadas em linear (vertex_color_srgb = false). O flash de
## dano anima o parâmetro flash_amount (EnemyBase._flash).
static func make_material() -> ShaderMaterial:
	return ToonKit.vertex_material(true, false)


## Cria um MeshInstance3D a partir de um SurfaceTool já preenchido (com as normais do contorno).
static func commit(st: SurfaceTool, name: String, mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = name
	mi.mesh = ToonKit.commit(st)
	mi.material_override = mat
	return mi
