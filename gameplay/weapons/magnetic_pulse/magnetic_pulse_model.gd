@tool
class_name MagneticPulseModel
extends Node3D

## Pulso Magnético low-poly facetado (fiel a pulso_magnetico.jpg, #44).
## Dispositivo retro-futurista de emissão magnética:
##   - Corpo principal em metal pintado de verde-azulado/petróleo com pontos de ferrugem;
##   - Fita adesiva/tecido reforçado enrolado na coronha e no corpo;
##   - Câmara central com núcleo de energia brilhante azul-ciano translúcido protegido por grelha metálica;
##   - Anéis/bobinas eletromagnéticas facetadas em cobre/bronze;
##   - Forcado/garfo frontal em íman clássico vermelho vivo com pontas prateadas de polaridade;
##   - Pega de pistola angular com guarda-mato, gatilho, cilindro inferior e cabos laterais.
##
## Espaço local: origem na pega principal (onde a mão direita agarra); cano estende-se para a frente (-Z),
## corpo central e núcleo na zona intermédia, íman vermelho na ponta dianteira (-Z).
##
## Regra (#47): tudo o que é gerado entra na árvore SEM owner (o editor nunca grava as malhas no .tscn).

const ToolMesh = preload("res://gameplay/weapons/tool_mesh.gd")

# Cores fiéis a pulso_magnetico.jpg
const BODY_TEAL: Color = Color(0.24, 0.48, 0.46)
const BODY_DARK: Color = Color(0.16, 0.32, 0.30)
const BODY_RUST: Color = Color(0.55, 0.30, 0.18)
const TAPE_GRAY: Color = Color(0.72, 0.70, 0.66)
const TAPE_DARK: Color = Color(0.58, 0.56, 0.52)
const METAL_GRAY: Color = Color(0.45, 0.48, 0.50)
const METAL_DARK: Color = Color(0.26, 0.28, 0.30)
const COPPER_COIL: Color = Color(0.78, 0.45, 0.25)
const COPPER_DARK: Color = Color(0.55, 0.30, 0.15)
const CORE_CYAN: Color = Color(0.20, 0.95, 0.90)
const CORE_GLOW: Color = Color(0.40, 1.0, 0.95)
const MAGNET_RED: Color = Color(0.82, 0.22, 0.20)
const MAGNET_TIP: Color = Color(0.9, 0.9, 0.88)
const BRASS_ACCENT: Color = Color(0.70, 0.55, 0.25)

## Dimensões principais da arma
const BODY_WIDTH: float = 0.082
const BODY_HEIGHT: float = 0.095
const BODY_BACK_Z: float = 0.14
const BODY_FRONT_Z: float = -0.16
const BODY_Y: float = 0.04

const CORE_CENTER_Z: float = -0.06
const CORE_SIZE: Vector3 = Vector3(0.068, 0.075, 0.11)

const BARREL_RADIUS: float = 0.034
const BARREL_FRONT_Z: float = -0.32
const BARREL_Y: float = 0.04

const MAGNET_TIP_Z: float = -0.44
const MAGNET_SPREAD: float = 0.065

@export var show_left_hand: bool = false:
	set(value):
		show_left_hand = value
		if is_inside_tree():
			_rebuild()

@export var pulse_glow: float = 1.0:
	set(value):
		pulse_glow = value
		if is_inside_tree():
			_rebuild()


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	ToolMesh.clear(self)

	_build_body()
	_build_grip_and_tape()
	_build_energy_core()
	_build_coils_and_barrel()
	_build_magnet_fork()

	if show_left_hand:
		_build_left_hand()


func _commit_part(st: SurfaceTool, part_name: String, kind: StringName, color: Color) -> void:
	var mat: ShaderMaterial = ToolMesh.prop_material(kind, color)
	ToolMesh.part(self, part_name, st, mat)


## 1. Bloco traseiro e caixa metálica principal
func _build_body() -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Caixa metálica traseira (receptor da arma)
	var rear_center: Vector3 = Vector3(0.0, BODY_Y + 0.005, (BODY_BACK_Z + CORE_CENTER_Z + CORE_SIZE.z * 0.5) * 0.5)
	var rear_len: float = BODY_BACK_Z - (CORE_CENTER_Z + CORE_SIZE.z * 0.5)
	LowPolyMesh.box(st, rear_center, Vector3(BODY_WIDTH, BODY_HEIGHT, rear_len), Basis.IDENTITY, BODY_TEAL)

	# Manípulos e parafusos na tampa traseira
	var knob_pos: Vector3 = Vector3(BODY_WIDTH * 0.42, BODY_Y + BODY_HEIGHT * 0.35, BODY_BACK_Z - 0.02)
	LowPolyMesh.prism(st, knob_pos, knob_pos + Vector3(0.015, 0.0, 0.0), 0.018, 0.018, 6, METAL_DARK)
	var bolt_pos: Vector3 = Vector3(BODY_WIDTH * 0.42, BODY_Y - BODY_HEIGHT * 0.25, BODY_BACK_Z - 0.03)
	LowPolyMesh.box(st, bolt_pos, Vector3(0.02, 0.02, 0.02), Basis.IDENTITY, METAL_GRAY)

	# Tubo de suporte inferior com reforço de latão
	var low_tube_c: Vector3 = Vector3(0.0, BODY_Y - BODY_HEIGHT * 0.65, -0.12)
	LowPolyMesh.box(st, low_tube_c, Vector3(0.05, 0.038, 0.14), Basis.IDENTITY, BODY_TEAL)
	var strut_pos: Vector3 = Vector3(0.0, BODY_Y - BODY_HEIGHT * 0.45, -0.21)
	LowPolyMesh.prism(st, strut_pos, strut_pos + Vector3(0.0, -0.04, 0.0), 0.012, 0.012, 6, BRASS_ACCENT)

	# Detalhes de ferrugem/desgaste na carcaça
	var rust_pos1: Vector3 = rear_center + Vector3(BODY_WIDTH * 0.45, 0.01, 0.02)
	LowPolyMesh.box(st, rust_pos1, Vector3(0.015, 0.035, 0.04), Basis.IDENTITY, BODY_RUST)

	# Fios elétricos laterais conectando a câmara à traseira
	for k: int in range(2):
		var wy: float = BODY_Y - 0.01 + float(k) * 0.02
		var p0: Vector3 = Vector3(BODY_WIDTH * 0.48, wy, CORE_CENTER_Z + 0.04)
		var p1: Vector3 = Vector3(BODY_WIDTH * 0.52, wy - 0.01, (CORE_CENTER_Z + BODY_BACK_Z) * 0.5)
		var p2: Vector3 = Vector3(BODY_WIDTH * 0.48, wy, BODY_BACK_Z - 0.04)
		LowPolyMesh.prism(st, p0, p1, 0.006, 0.006, 4, BODY_RUST if k == 0 else BRASS_ACCENT)
		LowPolyMesh.prism(st, p1, p2, 0.006, 0.006, 4, BODY_RUST if k == 0 else BRASS_ACCENT)

	_commit_part(st, "Body", &"metal_rust", BODY_TEAL)


## 2. Pega de pistola com fita adesiva cinzenta e gatilho
func _build_grip_and_tape() -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Punho angular de pistola
	var grip_top: Vector3 = Vector3(0.0, BODY_Y - BODY_HEIGHT * 0.4, 0.06)
	var grip_bottom: Vector3 = Vector3(0.0, -0.16, 0.09)
	var grip_basis: Basis = Basis(Vector3.RIGHT, deg_to_rad(-12.0))
	var grip_center: Vector3 = (grip_top + grip_bottom) * 0.5
	LowPolyMesh.box(st, grip_center, Vector3(0.048, 0.14, 0.06), grip_basis, BODY_TEAL)

	# Fita isoladora cinzenta enrolada na pega (camadas diagonais)
	for i: int in range(3):
		var ty: float = -0.04 - float(i) * 0.04
		var tz: float = 0.07 + float(i) * 0.01
		LowPolyMesh.box(st, Vector3(0.0, ty, tz), Vector3(0.052, 0.022, 0.064), grip_basis, TAPE_GRAY)

	# Faixa de fita no corpo traseiro
	var body_tape_c: Vector3 = Vector3(0.0, BODY_Y, 0.04)
	LowPolyMesh.box(st, body_tape_c, Vector3(BODY_WIDTH + 0.008, BODY_HEIGHT + 0.008, 0.035), Basis.IDENTITY, TAPE_GRAY)
	# Faixa de fita no bloco inferior
	LowPolyMesh.box(st, Vector3(0.0, BODY_Y - BODY_HEIGHT * 0.65, -0.09), Vector3(0.056, 0.044, 0.03), Basis.IDENTITY, TAPE_GRAY)

	# Guarda-mato e gatilho metálico
	var guard_f: Vector3 = Vector3(0.0, -0.05, 0.02)
	LowPolyMesh.box(st, guard_f, Vector3(0.016, 0.06, 0.012), Basis.IDENTITY, METAL_DARK)
	var guard_b: Vector3 = Vector3(0.0, -0.08, 0.045)
	LowPolyMesh.box(st, guard_b, Vector3(0.016, 0.012, 0.05), Basis.IDENTITY, METAL_DARK)
	var trigger_c: Vector3 = Vector3(0.0, -0.04, 0.04)
	LowPolyMesh.box(st, trigger_c, Vector3(0.012, 0.032, 0.015), Basis(Vector3.RIGHT, deg_to_rad(15.0)), METAL_GRAY)

	_commit_part(st, "Grip", &"metal_rust", BODY_DARK)


## 3. Câmara de energia fluorescente e grelha protetora
func _build_energy_core() -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Núcleo interior brilhante ciano
	var core_pos: Vector3 = Vector3(0.0, BODY_Y, CORE_CENTER_Z)
	var glow_color: Color = CORE_CYAN.lerp(CORE_GLOW, clampf(pulse_glow * 0.5, 0.0, 1.0))
	# #61: o núcleo é uma peça à parte com cor por vértice limpa e emissão (com o material de
	# ferrugem da gaiola ficava baço e esverdeado, longe do ciano a brilhar da referência).
	var core_st: SurfaceTool = ToolMesh.begin()
	LowPolyMesh.box(core_st, core_pos, CORE_SIZE * 0.88, Basis.IDENTITY, ToolMesh.clean(glow_color))
	var core_mat: ShaderMaterial = ToonKit.vertex_material(true, true)
	core_mat.set_shader_parameter(&"emission_color", Color(0.1, 0.55, 0.52))
	ToolMesh.part(self, "CoreGlow", core_st, core_mat)

	# Estrutura metálica da gaiola protetora com barras diagonais
	var cage_half_w: float = CORE_SIZE.x * 0.52
	var cage_half_h: float = CORE_SIZE.y * 0.52
	var cage_back: float = CORE_CENTER_Z + CORE_SIZE.z * 0.5
	var cage_front: float = CORE_CENTER_Z - CORE_SIZE.z * 0.5

	# Moldura dianteira e traseira da gaiola
	for z_pos: float in [cage_back, cage_front]:
		LowPolyMesh.box(st, Vector3(0.0, BODY_Y + cage_half_h, z_pos), Vector3(CORE_SIZE.x + 0.02, 0.015, 0.015), Basis.IDENTITY, METAL_DARK)
		LowPolyMesh.box(st, Vector3(0.0, BODY_Y - cage_half_h, z_pos), Vector3(CORE_SIZE.x + 0.02, 0.015, 0.015), Basis.IDENTITY, METAL_DARK)
		LowPolyMesh.box(st, Vector3(-cage_half_w, BODY_Y, z_pos), Vector3(0.015, CORE_SIZE.y + 0.02, 0.015), Basis.IDENTITY, METAL_DARK)
		LowPolyMesh.box(st, Vector3(cage_half_w, BODY_Y, z_pos), Vector3(0.015, CORE_SIZE.y + 0.02, 0.015), Basis.IDENTITY, METAL_DARK)

	# Barras longitudinais nos 4 cantos
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var corner_c: Vector3 = Vector3(cage_half_w * sx, BODY_Y + cage_half_h * sy, CORE_CENTER_Z)
			LowPolyMesh.box(st, corner_c, Vector3(0.014, 0.014, CORE_SIZE.z), Basis.IDENTITY, METAL_GRAY)

	# Barras diagonais em "X" nas laterais (visíveis em pulso_magnetico.jpg)
	for sx: float in [-1.0, 1.0]:
		var p_start: Vector3 = Vector3(cage_half_w * sx, BODY_Y - cage_half_h, cage_back)
		var p_end: Vector3 = Vector3(cage_half_w * sx, BODY_Y + cage_half_h, cage_front)
		LowPolyMesh.prism(st, p_start, p_end, 0.008, 0.008, 4, METAL_GRAY)

	_commit_part(st, "EnergyCore", &"metal_rust", METAL_GRAY)


## 4. Cano central e bobinas eletromagnéticas de cobre
func _build_coils_and_barrel() -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Cano cilíndrico metálico central
	var barrel_start: Vector3 = Vector3(0.0, BARREL_Y, CORE_CENTER_Z - CORE_SIZE.z * 0.5)
	var barrel_end: Vector3 = Vector3(0.0, BARREL_Y, BARREL_FRONT_Z)
	LowPolyMesh.prism(st, barrel_start, barrel_end, BARREL_RADIUS, BARREL_RADIUS, 8, METAL_GRAY)

	# Bobinas eletromagnéticas facetadas em cobre/bronze (anéis grossos)
	var coil1_z: float = -0.19
	var coil2_z: float = -0.245
	for cz: float in [coil1_z, coil2_z]:
		var coil_p0: Vector3 = Vector3(0.0, BARREL_Y, cz + 0.018)
		var coil_p1: Vector3 = Vector3(0.0, BARREL_Y, cz - 0.018)
		LowPolyMesh.prism(st, coil_p0, coil_p1, BARREL_RADIUS * 1.85, BARREL_RADIUS * 1.85, 10, COPPER_COIL)
		# Sulco central mais escuro da bobina
		LowPolyMesh.prism(st, coil_p0, coil_p1, BARREL_RADIUS * 1.5, BARREL_RADIUS * 1.5, 8, COPPER_DARK)

	# Anel de fixação dianteiro em latão antes do garfo do íman
	var collar_p0: Vector3 = Vector3(0.0, BARREL_Y, BARREL_FRONT_Z + 0.02)
	var collar_p1: Vector3 = Vector3(0.0, BARREL_Y, BARREL_FRONT_Z)
	LowPolyMesh.prism(st, collar_p0, collar_p1, BARREL_RADIUS * 1.45, BARREL_RADIUS * 1.45, 8, BRASS_ACCENT)

	# Braço de suporte vertical em latão ligando o cano ao tubo inferior
	var vert_strut: Vector3 = Vector3(0.0, BODY_Y - 0.04, BARREL_FRONT_Z + 0.01)
	LowPolyMesh.box(st, vert_strut, Vector3(0.025, 0.08, 0.02), Basis.IDENTITY, BRASS_ACCENT)

	_commit_part(st, "Coils", &"metal_rust", COPPER_COIL)


## 5. Garfo de íman em ferradura vermelho com pontas prateadas
func _build_magnet_fork() -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Base transversal curvada do íman
	var fork_base_c: Vector3 = Vector3(0.0, BARREL_Y, BARREL_FRONT_Z - 0.015)
	LowPolyMesh.box(st, fork_base_c, Vector3(MAGNET_SPREAD * 0.9, 0.045, 0.035), Basis.IDENTITY, MAGNET_RED)

	# As duas pontas do íman em ferradura (esquerda e direita)
	for sx: float in [-1.0, 1.0]:
		var arm_start: Vector3 = Vector3(MAGNET_SPREAD * 0.45 * sx, BARREL_Y, BARREL_FRONT_Z - 0.02)
		var arm_mid: Vector3 = Vector3(MAGNET_SPREAD * 0.75 * sx, BARREL_Y, BARREL_FRONT_Z - 0.07)
		var arm_end: Vector3 = Vector3(MAGNET_SPREAD * 0.75 * sx, BARREL_Y, MAGNET_TIP_Z)

		# Segmento vermelho angulado para fora
		LowPolyMesh.prism(st, arm_start, arm_mid, 0.024, 0.024, 5, MAGNET_RED)
		# Segmento vermelho reto para a frente
		var red_tip: Vector3 = Vector3(arm_end.x, BARREL_Y, MAGNET_TIP_Z + 0.035)
		LowPolyMesh.prism(st, arm_mid, red_tip, 0.022, 0.022, 5, MAGNET_RED)
		# Ponta prateada/metálica (polo magnético)
		LowPolyMesh.prism(st, red_tip, arm_end, 0.022, 0.020, 5, MAGNET_TIP)
		# Tampa frontal da ponta prateada
		LowPolyMesh.box(st, arm_end, Vector3(0.035, 0.035, 0.005), Basis.IDENTITY, MAGNET_TIP)

	# Abertura cilíndrica central do cano por onde sai a onda de pulso
	var nozzle_start: Vector3 = Vector3(0.0, BARREL_Y, BARREL_FRONT_Z)
	var nozzle_end: Vector3 = Vector3(0.0, BARREL_Y, BARREL_FRONT_Z - 0.04)
	LowPolyMesh.prism(st, nozzle_start, nozzle_end, BARREL_RADIUS * 0.9, BARREL_RADIUS * 0.8, 8, METAL_DARK)

	# Cores por vértice (vermelho + pontas prateadas): o albedo do kit pintava tudo de vermelho.
	var fork_mat: ShaderMaterial = ToonKit.vertex_material(true, true)
	fork_mat.set_shader_parameter(&"chip_amount", 0.3)
	fork_mat.set_shader_parameter(&"chip_color", BODY_RUST)
	ToolMesh.part(self, "MagnetFork", st, fork_mat)


## Mão esquerda do explorador segurando por baixo das bobinas
func _build_left_hand() -> void:
	var hand_script: Script = load("res://gameplay/player/hand_model.gd") as Script
	if hand_script == null:
		return
	var hand: Node3D = Node3D.new()
	hand.set_script(hand_script)
	hand.name = "LeftHand"
	hand.set("is_left", true)
	hand.set("pose", 1)  # Pose.GRIP
	hand.transform = Transform3D(Basis(Vector3.UP, PI * 0.9).rotated(Vector3.FORWARD, deg_to_rad(80.0)),
		Vector3(-0.03, BODY_Y - 0.05, -0.20))
	add_child(hand)
