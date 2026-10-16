extends RefCounted

## Ajudas para os modelos procedurais das ferramentas (pá, kit médico, repelente, estilingue, forcado, arpão, pulso magnético; #37, #38, #43, #44).
## As primitivas facetadas são as do LowPolyMesh; aqui ficam as que só as ferramentas usam.
##
## Regra (#47): tudo o que é gerado entra na árvore SEM owner, por isso o editor nunca grava as
## malhas no .tscn (os scripts são @tool só para se verem no editor).


## Cor por vértice: alfa = máscara do desgaste do shader toon (0 = limpo, ex.: autocolantes).
static func clean(color: Color) -> Color:
	return Color(color.r, color.g, color.b, 0.0)


## Prisma vertical (eixo Y, de y0 a y1) com `sides` lados; `phase` roda os vértices (rad).
## Com phase = PI / sides uma face fica virada para +Z (útil para colar rótulos planos).
static func y_prism(st: SurfaceTool, center: Vector3, y0: float, y1: float, r0: float, r1: float,
		sides: int, phase: float, color: Color, caps: bool = true) -> void:
	var inside: Vector3 = Vector3(center.x, (y0 + y1) * 0.5, center.z)
	var bottom: Vector3 = Vector3(center.x, y0, center.z)
	var top: Vector3 = Vector3(center.x, y1, center.z)
	for i: int in sides:
		var a0: float = phase + TAU * float(i) / float(sides)
		var a1: float = phase + TAU * float(i + 1) / float(sides)
		var d0: Vector3 = Vector3(sin(a0), 0.0, cos(a0))
		var d1: Vector3 = Vector3(sin(a1), 0.0, cos(a1))
		var b0: Vector3 = bottom + d0 * r0
		var b1: Vector3 = bottom + d1 * r0
		var t0: Vector3 = top + d0 * r1
		var t1: Vector3 = top + d1 * r1
		LowPolyMesh.quad(st, b0, b1, t1, t0, inside, color)
		if caps:
			LowPolyMesh.tri(st, bottom, b0, b1, inside, color)
			LowPolyMesh.tri(st, top, t1, t0, inside, color)


## Polígono plano (convexo) com espessura: frente em +normal, verso em -normal.
static func slab(st: SurfaceTool, points: PackedVector3Array, normal: Vector3, thickness: float, color: Color) -> void:
	var n: Vector3 = normal.normalized() * thickness * 0.5
	var c: Vector3 = Vector3.ZERO
	for p: Vector3 in points:
		c += p
	c /= float(points.size())
	for i: int in points.size():
		var a: Vector3 = points[i]
		var b: Vector3 = points[(i + 1) % points.size()]
		LowPolyMesh.tri(st, c + n, a + n, b + n, c, color)
		LowPolyMesh.tri(st, c - n, b - n, a - n, c, color)
		LowPolyMesh.quad(st, a + n, b + n, b - n, a - n, c, color)


## Faixa curva (anel achatado) em volta do eixo Y: rótulos e ligaduras que abraçam a peça.
static func y_band(st: SurfaceTool, center: Vector3, y0: float, y1: float, radius: float, sides: int,
		phase: float, from_side: int, to_side: int, color: Color) -> void:
	var inside: Vector3 = Vector3(center.x, (y0 + y1) * 0.5, center.z)
	for i: int in range(from_side, to_side):
		var a0: float = phase + TAU * float(i) / float(sides)
		var a1: float = phase + TAU * float(i + 1) / float(sides)
		var d0: Vector3 = Vector3(sin(a0), 0.0, cos(a0)) * radius
		var d1: Vector3 = Vector3(sin(a1), 0.0, cos(a1)) * radius
		LowPolyMesh.quad(st, center + d0 + Vector3.UP * y0, center + d1 + Vector3.UP * y0,
			center + d1 + Vector3.UP * y1, center + d0 + Vector3.UP * y1, inside, color)


## Junta uma peça (malha + material toon) a `parent`, sem owner (#47).
static func part(parent: Node3D, part_name: String, st: SurfaceTool, mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = part_name
	mi.mesh = ToonKit.commit(st)
	mi.material_override = mat
	parent.add_child(mi)
	return mi


static func begin() -> SurfaceTool:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


## Os materiais do kit foram afinados para peças de ~1 m; numa ferramenta (10-30 cm) a mesma
## escala daria uma única mancha a cobrir a peça toda. Ferrugem e tinta lascada ficam mais finas.
const WEAR_SCALE: float = 4.0


## Material do kit para uma ferramenta: desgaste à escala de um objeto pequeno e, opcionalmente,
## outra cor de base (ex.: metal escuro dos fechos). albedo com alfa 0 = manter a do kit.
static func prop_material(kind: StringName, albedo: Color = Color(0.0, 0.0, 0.0, 0.0)) -> ShaderMaterial:
	var mat: ShaderMaterial = ToonKit.material(kind)
	for param: StringName in [&"rust_scale", &"chip_scale"]:
		var value: Variant = mat.get_shader_parameter(param)
		if value != null:
			mat.set_shader_parameter(param, float(value) * WEAR_SCALE)
	if albedo.a > 0.0:
		mat.set_shader_parameter(&"albedo_color", albedo)
	return mat


## Apaga os filhos gerados por um _ready anterior (no editor o _ready corre de novo ao recarregar).
static func clear(node: Node) -> void:
	for child: Node in node.get_children():
		if child.owner == null:
			child.queue_free()
