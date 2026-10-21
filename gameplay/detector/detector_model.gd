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
## #61 (detetor_metais.jpg; cores em sRGB): azul gasto, aço galvanizado, fita adesiva.
const BLUE: Color = Color(0.36, 0.52, 0.66)
const BLUE_DARK: Color = Color(0.26, 0.38, 0.5)
const STEEL: Color = Color(0.66, 0.67, 0.66)
const STEEL_DARK: Color = Color(0.44, 0.45, 0.45)
const TAPE: Color = Color(0.72, 0.72, 0.68)
const TAPE_DARK: Color = Color(0.22, 0.22, 0.22)
const BUTTON_RED: Color = Color(0.82, 0.2, 0.16)

const COIL_CENTER: Vector3 = Vector3(0.0, -0.7, -0.7)
## Pega (por baixo da haste superior): extremidades do eixo.
const GRIP_TOP: Vector3 = Vector3(0.0, -0.038, 0.075)
const GRIP_BOTTOM: Vector3 = Vector3(0.0, -0.14, 0.04)

## Caixa de controlo: centro, tamanho e inclinação (o topo vira-se para o jogador).
const BOX_CENTER: Vector3 = Vector3(0.0, 0.085, -0.105)
const BOX_SIZE: Vector3 = Vector3(0.15, 0.05, 0.21)
const BOX_TILT_DEG: float = 57.0
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
	# #47: só os filhos gerados (sem owner).
	for child: Node in get_children():
		if child.owner == null:
			child.queue_free()

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_build_body(st)

	# Toon + contorno preto (#36), cores lineares como antes; tinta lascada e ferrugem leves
	# (nada parece novo, docs/GAME_DESIGN.md §2)
	var mat: ShaderMaterial = ToonKit.vertex_material(true, true)
	mat.set_shader_parameter(&"chip_amount", 0.35)
	mat.set_shader_parameter(&"chip_color", Color(0.5, 0.3, 0.16))
	mat.set_shader_parameter(&"chip_scale", 14.0)
	mat.set_shader_parameter(&"rust_amount", 0.3)
	mat.set_shader_parameter(&"rust_scale", 10.0)
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
	# #61, fiel a detetor_metais.jpg: haste de tubo galvanizado grosso com uniões sextavadas e
	# fita adesiva cinzenta, curva com punho de fita escura, caixa de controlo azul gasta com fita
	# nos cantos, botão rodado e dois botões vermelhos, apoio de braço azul em U com correia e
	# bobina em anel azul (com travessa e suporte aparafusado). Ferrugem por cima de tudo.
	var box_basis: Basis = Basis(Vector3.RIGHT, deg_to_rad(BOX_TILT_DEG))

	# Apoio de braço em U (azul) com correia de fita por cima
	var cuff_c: Vector3 = Vector3(0.0, -0.08, 0.145)
	_box(st, cuff_c, Vector3(0.085, 0.012, 0.075), Basis.IDENTITY, BLUE)
	for sx: float in [-1.0, 1.0]:
		_box(st, cuff_c + Vector3(sx * 0.048, 0.03, 0.0), Vector3(0.012, 0.052, 0.075), Basis(Vector3.FORWARD, sx * 0.12), BLUE)
	_box(st, cuff_c + Vector3(0.0, 0.068, 0.0), Vector3(0.1, 0.006, 0.03), Basis.IDENTITY, TAPE)
	_box(st, cuff_c + Vector3(0.0, -0.025, -0.02), Vector3(0.03, 0.04, 0.05), Basis(Vector3.RIGHT, 0.4), BLUE_DARK)

	# Haste superior (apoio -> curva) com fita escura e curva para baixo até à caixa
	_prism(st, Vector3(0.0, -0.08, 0.2), Vector3(0.0, -0.06, 0.08), 0.016, 0.016, 8, STEEL)
	for k: int in 3:
		var z: float = 0.18 - 0.03 * float(k)
		_prism(st, Vector3(0.0, -0.078 + 0.003 * float(k), z), Vector3(0.0, -0.077 + 0.003 * float(k), z - 0.022), 0.019, 0.019, 8, TAPE_DARK)
	_prism(st, Vector3(0.0, -0.06, 0.08), Vector3(0.0, 0.005, -0.05), 0.017, 0.017, 8, STEEL)

	# Pega por baixo da haste: fita escura enrolada
	_prism(st, GRIP_TOP, GRIP_BOTTOM, 0.02, 0.018, 7, TAPE_DARK)
	_prism(st, GRIP_BOTTOM, GRIP_BOTTOM + (GRIP_BOTTOM - GRIP_TOP).normalized() * 0.016, 0.021, 0.019, 7, STEEL)

	# Caixa de controlo azul, cantos com fita, botão rodado e botões vermelhos, cabo
	_prism(st, Vector3(0.0, 0.005, -0.05), BOX_CENTER + box_basis * Vector3(0.0, -BOX_SIZE.y * 0.5, 0.0), 0.014, 0.014, 8, STEEL)
	_box(st, BOX_CENTER, BOX_SIZE, box_basis, BLUE)
	_box(st, BOX_CENTER + box_basis * Vector3(0.0, -BOX_SIZE.y * 0.5 - 0.004, 0.0), Vector3(BOX_SIZE.x - 0.02, 0.008, BOX_SIZE.z - 0.02), box_basis, BLUE_DARK)
	for c: Vector3 in [Vector3(0.06, 0.0, 0.09), Vector3(-0.065, 0.0, -0.08), Vector3(0.07, 0.0, -0.05)]:
		_box(st, BOX_CENTER + box_basis * c, Vector3(0.035, BOX_SIZE.y + 0.004, 0.03), box_basis * Basis(Vector3.UP, 0.5), TAPE)
	var top: Vector3 = BOX_CENTER + box_basis * Vector3(0.0, BOX_SIZE.y * 0.5, 0.0)
	_box(st, top, Vector3(SCREEN_SIZE.x + 0.012, 0.004, SCREEN_SIZE.y + 0.012), box_basis, SCREEN_BEZEL)
	var knob: Vector3 = BOX_CENTER + box_basis * Vector3(-0.045, BOX_SIZE.y * 0.5, -BOX_SIZE.z * 0.5 + 0.004)
	_prism(st, knob, knob + box_basis * Vector3(0.0, 0.018, 0.0), 0.012, 0.011, 8, STEEL_DARK)
	for i: int in 2:
		var bpos: Vector3 = BOX_CENTER + box_basis * Vector3(0.01 + 0.025 * float(i), BOX_SIZE.y * 0.5 + 0.003, -BOX_SIZE.z * 0.5 + 0.006)
		_box(st, bpos, Vector3(0.016, 0.01, 0.01), box_basis, BUTTON_RED)
	_prism(st, BOX_CENTER + box_basis * Vector3(-0.07, -0.01, 0.05), Vector3(-0.03, -0.06, 0.06), 0.004, 0.004, 4, STEEL_DARK)

	# Haste inferior: tubo galvanizado com uniões sextavadas e voltas de fita cinzenta
	var shaft_end: Vector3 = COIL_CENTER + Vector3(0.0, 0.055, 0.05)
	var a: Vector3 = Vector3(0.0, 0.0, -0.1)
	var dir: Vector3 = (shaft_end - a).normalized()
	var length: float = (shaft_end - a).length()
	_prism(st, a, shaft_end, 0.016, 0.014, 8, STEEL)
	for f: float in [0.08, 0.5]:
		var p: Vector3 = a + dir * length * f
		_prism(st, p - dir * 0.025, p + dir * 0.025, 0.026, 0.026, 6, STEEL_DARK)
	for f: float in [0.28, 0.33, 0.7]:
		var p: Vector3 = a + dir * length * f
		_prism(st, p - dir * 0.018, p + dir * 0.018, 0.02, 0.02, 8, TAPE)

	# Suporte (garfo) aparafusado à bobina
	for sx: float in [-1.0, 1.0]:
		_box(st, shaft_end + Vector3(sx * 0.024, -0.026, -0.01), Vector3(0.01, 0.06, 0.06), Basis(Vector3.RIGHT, 0.5), BLUE_DARK)
	_prism(st, shaft_end + Vector3(-0.034, -0.01, -0.01), shaft_end + Vector3(0.034, -0.01, -0.01), 0.009, 0.009, 6, STEEL_DARK)
	_prism(st, shaft_end + Vector3(0.034, -0.01, -0.01), shaft_end + Vector3(0.044, -0.01, -0.01), 0.014, 0.014, 6, STEEL_DARK)

	# Bobina: anel azul grosso (com furo) e travessa ao meio onde aperta o suporte
	var up: Vector3 = Vector3(0.0, 1.0, 0.0)
	var r_out: float = 0.18
	var r_in: float = 0.105
	var segs: int = 14
	for i: int in segs:
		var a0: float = TAU * float(i) / float(segs)
		var a1: float = TAU * float(i + 1) / float(segs)
		var p0: Vector3 = Vector3(cos(a0), 0.0, sin(a0))
		var p1: Vector3 = Vector3(cos(a1), 0.0, sin(a1))
		var c: Vector3 = COIL_CENTER + (p0 + p1).normalized() * (r_out + r_in) * 0.5
		var ring_inside: Vector3 = c
		for y: float in [-0.018, 0.018]:
			var n: Vector3 = up * signf(y)
			var q0: Vector3 = COIL_CENTER + p0 * r_in + up * y
			var q1: Vector3 = COIL_CENTER + p1 * r_in + up * y
			var q2: Vector3 = COIL_CENTER + p1 * r_out + up * y
			var q3: Vector3 = COIL_CENTER + p0 * r_out + up * y
			_quad(st, q0, q1, q2, q3, ring_inside - n * 0.05, BLUE)
		_quad(st, COIL_CENTER + p0 * r_out - up * 0.018, COIL_CENTER + p1 * r_out - up * 0.018,
			COIL_CENTER + p1 * r_out + up * 0.018, COIL_CENTER + p0 * r_out + up * 0.018, COIL_CENTER, BLUE_DARK)
		_quad(st, COIL_CENTER + p0 * r_in - up * 0.018, COIL_CENTER + p1 * r_in - up * 0.018,
			COIL_CENTER + p1 * r_in + up * 0.018, COIL_CENTER + p0 * r_in + up * 0.018, COIL_CENTER + (p0 + p1) * r_out, BLUE_DARK)
	_box(st, COIL_CENTER, Vector3(0.05, 0.034, r_in * 2.0 + 0.02), Basis.IDENTITY, BLUE)


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
