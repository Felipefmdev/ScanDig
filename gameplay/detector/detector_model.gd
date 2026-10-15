@tool
class_name DetectorModel
extends Node3D

## Modelo low-poly facetado do detector (estilo "How to Fish"): malhas geradas com SurfaceTool,
## normais por face, cores sólidas por vértice e sem texturas. Espaço local: +Z = para o jogador,
## -Z = para a frente, Y = cima. A bobina fica centrada em COIL_CENTER (onde está a CoilTip).

const NAVY: Color = Color(0.07, 0.11, 0.24)
const NAVY_DARK: Color = Color(0.04, 0.06, 0.13)
const CYAN: Color = Color(0.32, 0.8, 1.0)
const COIL_BLACK: Color = Color(0.06, 0.06, 0.07)
const RIM_YELLOW: Color = Color(1.0, 0.78, 0.08)
const GRIP_BLACK: Color = Color(0.1, 0.1, 0.12)
const SCREEN_BEZEL: Color = Color(0.02, 0.1, 0.06)

const COIL_CENTER: Vector3 = Vector3(0.0, -0.7, -0.7)
## Pega (por baixo da haste superior): extremidades do eixo.
const GRIP_TOP: Vector3 = Vector3(0.0, -0.038, 0.075)
const GRIP_BOTTOM: Vector3 = Vector3(0.0, -0.14, 0.04)

## Caixa de controlo: centro, tamanho e inclinação (o topo vira-se para o jogador).
const BOX_CENTER: Vector3 = Vector3(0.0, 0.05, -0.08)
const BOX_SIZE: Vector3 = Vector3(0.15, 0.05, 0.21)
const BOX_TILT_DEG: float = 45.0
## Tamanho do ecrã (proporção igual à do SubViewport do radar: 256x368).
const SCREEN_SIZE: Vector2 = Vector2(0.125, 0.1797)

## Mão direita a segurar a pega (desligar no modelo pousado no chão).
@export var show_hand: bool = true

## MeshInstance3D do ecrã (QuadMesh). O MetalDetector aplica-lhe a textura do radar.
var screen_mesh: MeshInstance3D = null
var _body: MeshInstance3D = null


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	for child: Node in get_children():
		child.queue_free()

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_build_body(st)

	# Toon + contorno preto (#36), cores lineares como antes; tinta lascada e ferrugem leves
	# (nada parece novo, docs/GAME_DESIGN.md §2)
	var mat: ShaderMaterial = ToonKit.vertex_material(true, false)
	mat.set_shader_parameter(&"chip_amount", 0.22)
	mat.set_shader_parameter(&"chip_scale", 22.0)
	mat.set_shader_parameter(&"rust_amount", 0.12)
	mat.set_shader_parameter(&"rust_scale", 14.0)
	mat.set_shader_parameter(&"specular_amount", 0.2)

	_body = MeshInstance3D.new()
	_body.name = "Body"
	_body.mesh = ToonKit.commit(st)
	_body.material_override = mat
	add_child(_body)

	_build_screen()
	if show_hand:
		_build_hand()


# ---------------------------------------------------------------------------
# Partes
# ---------------------------------------------------------------------------

func _build_body(st: SurfaceTool) -> void:
	var box_basis: Basis = Basis(Vector3.RIGHT, deg_to_rad(BOX_TILT_DEG))

	# Apoio de braço (cuff em U) na traseira
	var cuff_c: Vector3 = Vector3(0.0, -0.075, 0.15)
	_box(st, cuff_c, Vector3(0.07, 0.01, 0.07), Basis.IDENTITY, NAVY)
	_box(st, cuff_c + Vector3(-0.037, 0.022, 0.0), Vector3(0.01, 0.04, 0.07), Basis.IDENTITY, NAVY)
	_box(st, cuff_c + Vector3(0.037, 0.022, 0.0), Vector3(0.01, 0.04, 0.07), Basis.IDENTITY, NAVY)
	_box(st, cuff_c + Vector3(0.0, 0.006, 0.0), Vector3(0.078, 0.004, 0.025), Basis.IDENTITY, CYAN)

	# Haste superior (do apoio até à caixa)
	_prism(st, Vector3(0.0, -0.08, 0.18), Vector3(0.0, 0.005, -0.05), 0.014, 0.014, 8, NAVY)

	# Pega por baixo da haste, com tampa ciano
	_prism(st, GRIP_TOP, GRIP_BOTTOM, 0.017, 0.015, 6, GRIP_BLACK)
	_prism(st, GRIP_BOTTOM, GRIP_BOTTOM + (GRIP_BOTTOM - GRIP_TOP).normalized() * 0.016, 0.019, 0.017, 6, CYAN)

	# Caixa de controlo com faixa ciano e moldura do ecrã
	_box(st, BOX_CENTER, BOX_SIZE, box_basis, NAVY)
	_box(st, BOX_CENTER, Vector3(BOX_SIZE.x + 0.006, 0.01, BOX_SIZE.z + 0.006), box_basis, CYAN)
	var top: Vector3 = BOX_CENTER + box_basis * Vector3(0.0, BOX_SIZE.y * 0.5, 0.0)
	_box(st, top, Vector3(SCREEN_SIZE.x + 0.01, 0.004, SCREEN_SIZE.y + 0.01), box_basis, SCREEN_BEZEL)
	# Botões
	for i: int in range(3):
		var bx: float = -0.03 + 0.03 * float(i)
		var bpos: Vector3 = BOX_CENTER + box_basis * Vector3(bx, BOX_SIZE.y * 0.5, BOX_SIZE.z * 0.5 - 0.006)
		_box(st, bpos, Vector3(0.016, 0.01, 0.008), box_basis, CYAN if i == 1 else NAVY_DARK)

	# Haste inferior em dois segmentos com abraçadeira ciano
	var joint: Vector3 = Vector3(0.0, -0.3, -0.36)
	var shaft_end: Vector3 = COIL_CENTER + Vector3(0.0, 0.045, 0.05)
	_prism(st, Vector3(0.0, 0.0, -0.1), joint, 0.013, 0.013, 8, NAVY)
	var dir: Vector3 = (shaft_end - joint).normalized()
	_prism(st, joint - dir * 0.03, joint + dir * 0.03, 0.019, 0.019, 8, CYAN)
	_prism(st, joint, shaft_end, 0.011, 0.011, 8, NAVY)

	# Garfo (yoke) que liga a haste à bobina
	_box(st, shaft_end + Vector3(-0.02, -0.02, -0.01), Vector3(0.008, 0.05, 0.05), Basis.IDENTITY, CYAN)
	_box(st, shaft_end + Vector3(0.02, -0.02, -0.01), Vector3(0.008, 0.05, 0.05), Basis.IDENTITY, CYAN)

	# Bobina: disco preto com aro amarelo
	var up: Vector3 = Vector3(0.0, 1.0, 0.0)
	_prism(st, COIL_CENTER - up * 0.01, COIL_CENTER + up * 0.01, 0.178, 0.178, 10, RIM_YELLOW)
	_prism(st, COIL_CENTER - up * 0.016, COIL_CENTER + up * 0.016, 0.166, 0.166, 10, COIL_BLACK)
	_prism(st, COIL_CENTER + up * 0.016, COIL_CENTER + up * 0.02, 0.06, 0.06, 10, NAVY)



## Mão direita (HandModel do Dev_Player) em pose GRIP à volta da pega; o detector fica
## no lado direito do ecrã. HandModel: eixo do cabo = X local, costas da mão = +Y,
## pulso = +Z, cabo na origem. A base tem de ser direita (X × Y = Z) para não espelhar.
func _build_hand() -> void:
	var grip_axis: Vector3 = (GRIP_BOTTOM - GRIP_TOP).normalized()  # para baixo, ao longo da pega
	var back_of_hand: Vector3 = Vector3.RIGHT                         # nós dos dedos para fora (direita)
	var wrist: Vector3 = grip_axis.cross(back_of_hand).normalized()   # para o jogador
	var hand: HandModel = HandModel.new()
	hand.name = "Hand"
	hand.is_left = false
	hand.pose = HandModel.Pose.GRIP
	hand.transform = Transform3D(Basis(grip_axis, back_of_hand, wrist), (GRIP_TOP + GRIP_BOTTOM) * 0.5)
	add_child(hand)


func _build_screen() -> void:
	var box_basis: Basis = Basis(Vector3.RIGHT, deg_to_rad(BOX_TILT_DEG))
	var quad: QuadMesh = QuadMesh.new()
	quad.size = SCREEN_SIZE

	screen_mesh = MeshInstance3D.new()
	screen_mesh.name = "Screen"
	screen_mesh.mesh = quad
	screen_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Ecrã apagado por omissão (modelo no chão); o MetalDetector substitui pelo radar.
	var off_mat: StandardMaterial3D = StandardMaterial3D.new()
	off_mat.albedo_color = Color(0.03, 0.12, 0.07)
	off_mat.roughness = 0.25
	screen_mesh.material_override = off_mat
	# QuadMesh olha para +Z; rodamos para olhar para +Y da caixa (topo de textura para a frente)
	var top: Vector3 = BOX_CENTER + box_basis * Vector3(0.0, BOX_SIZE.y * 0.5 + 0.0025, 0.0)
	screen_mesh.transform = Transform3D(box_basis * Basis(Vector3.RIGHT, -PI * 0.5), top)
	add_child(screen_mesh)


# ---------------------------------------------------------------------------
# Geradores facetados (normais por face, winding horário = face da frente no Godot)
# ---------------------------------------------------------------------------

## Triângulo orientado para fora de 'inside' (ponto interior da peça convexa).
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
	st.set_color(color)
	st.set_normal(n)
	st.add_vertex(a)
	st.set_color(color)
	st.set_normal(n)
	st.add_vertex(b)
	st.set_color(color)
	st.set_normal(n)
	st.add_vertex(c)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, inside: Vector3, color: Color) -> void:
	_tri(st, a, b, c, inside, color)
	_tri(st, a, c, d, inside, color)


## Prisma/tronco de cone entre p0 e p1 com 'sides' faces laterais e tampas.
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
	_quad(st, c[0], c[1], c[3], c[2], center, color)  # -Z
	_quad(st, c[4], c[5], c[7], c[6], center, color)  # +Z
	_quad(st, c[0], c[1], c[5], c[4], center, color)  # -Y
	_quad(st, c[2], c[3], c[7], c[6], center, color)  # +Y
	_quad(st, c[0], c[2], c[6], c[4], center, color)  # -X
	_quad(st, c[1], c[3], c[7], c[5], center, color)  # +X
