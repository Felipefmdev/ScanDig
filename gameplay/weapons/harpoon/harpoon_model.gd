@tool
class_name HarpoonModel
extends Node3D

## Arpão de Corda low-poly facetado (fiel a arpao_corda.jpg, #43).
## Lançador/espingarda de arpão com coronha de madeira rústica, reforço de corda na pega traseira,
## cano cilíndrico de metal enferrujado com anel pontiagudo na boca, carretel inferior com corda
## grossa enrolada e manivela, gatilho metálico e arpão com ponta dentada/serrilhada farpada.
##
## Espaço local: origem na pega principal (onde a mão direita agarra); cano estende-se para a frente (-Z),
## coronha para trás (+Z), cano e carretel para a frente e ligeiramente abaixo.
##
## Regra (#47): tudo o que é gerado entra na árvore SEM owner (o editor nunca grava as malhas no .tscn).

const ToolMesh = preload("res://gameplay/weapons/tool_mesh.gd")

const WOOD_BASE: Color = Color(0.42, 0.26, 0.14)
const WOOD_DARK: Color = Color(0.28, 0.17, 0.09)
const METAL_BASE: Color = Color(0.44, 0.46, 0.48)
const METAL_DARK: Color = Color(0.28, 0.29, 0.32)
const METAL_RUST: Color = Color(0.55, 0.26, 0.12)
const ROPE_COLOR: Color = Color(0.74, 0.64, 0.46)
const ROPE_DARK: Color = Color(0.58, 0.48, 0.32)

## Dimensões principais do arpão
const BARREL_RADIUS: float = 0.038
const BARREL_FRONT_Z: float = -0.42
const BARREL_BACK_Z: float = 0.05
const BARREL_Y: float = 0.05

const STOCK_BACK_Z: float = 0.34
const STOCK_DROP_Y: float = -0.07

const SPOOL_CENTER_Z: float = -0.16
const SPOOL_CENTER_Y: float = -0.04
const SPOOL_RADIUS: float = 0.052
const SPOOL_WIDTH: float = 0.075

const HARPOON_TIP_Z: float = -0.68
const HARPOON_SHAFT_RADIUS: float = 0.012

@export var show_left_hand: bool = false:
	set(value):
		show_left_hand = value
		if is_inside_tree():
			_rebuild()

@export var harpoon_loaded: bool = true:
	set(value):
		harpoon_loaded = value
		if is_inside_tree():
			_rebuild()


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	ToolMesh.clear(self)
	_build_wood_stock()
	_build_metal_barrel_and_frame()
	_build_rope_spool()
	if harpoon_loaded:
		_build_harpoon_spear()
	if show_left_hand:
		_build_left_hand()


func _build_wood_stock() -> void:
	var st: SurfaceTool = ToolMesh.begin()
	
	# Corpo central sob o cano (da pega até ao suporte frontal)
	var body_points: PackedVector3Array = PackedVector3Array([
		Vector3(0.0, BARREL_Y - 0.01, -0.26),
		Vector3(0.0, BARREL_Y - 0.01, 0.10),
		Vector3(0.0, -0.06, 0.08),
		Vector3(0.0, -0.07, -0.04),
		Vector3(0.0, -0.05, -0.24)
	])
	ToolMesh.slab(st, body_points, Vector3.RIGHT, 0.052, WOOD_BASE)

	# Coronha curvada para trás e para baixo (buttstock angular)
	var stock_points: PackedVector3Array = PackedVector3Array([
		Vector3(0.0, BARREL_Y - 0.02, 0.08),
		Vector3(0.0, 0.01, 0.20),
		Vector3(0.0, STOCK_DROP_Y + 0.03, STOCK_BACK_Z),
		Vector3(0.0, STOCK_DROP_Y - 0.08, STOCK_BACK_Z),
		Vector3(0.0, STOCK_DROP_Y - 0.05, 0.22),
		Vector3(0.0, -0.08, 0.08)
	])
	ToolMesh.slab(st, stock_points, Vector3.RIGHT, 0.048, WOOD_BASE)

	# Pega ergonómica para a mão direita (onde o jogador segura)
	LowPolyMesh.prism(st, Vector3(0.0, -0.01, 0.02), Vector3(0.0, -0.10, 0.06), 0.024, 0.020, 6, WOOD_DARK)

	var mat: ShaderMaterial = ToolMesh.prop_material(&"wood", WOOD_BASE)
	mat.set_shader_parameter(&"grain_scale", 20.0)
	ToolMesh.part(self, "WoodStock", st, mat)


func _build_metal_barrel_and_frame() -> void:
	var st: SurfaceTool = ToolMesh.begin()

	# Cano cilíndrico principal (de z = BARREL_BACK_Z até BARREL_FRONT_Z)
	LowPolyMesh.prism(st, Vector3(0.0, BARREL_Y, BARREL_BACK_Z), Vector3(0.0, BARREL_Y, BARREL_FRONT_Z),
		BARREL_RADIUS * 1.02, BARREL_RADIUS, 8, METAL_BASE)

	# Boca do cano reforçada com anel cilíndrico
	LowPolyMesh.prism(st, Vector3(0.0, BARREL_Y, BARREL_FRONT_Z), Vector3(0.0, BARREL_Y, BARREL_FRONT_Z - 0.03),
		BARREL_RADIUS * 1.25, BARREL_RADIUS * 1.25, 8, METAL_DARK)

	# Espigões / dentes metálicos em estrela à volta da boca do cano (como na referência)
	for i: int in 6:
		var ang: float = TAU * float(i) / 6.0
		var radial_dir: Vector3 = Vector3(cos(ang), sin(ang), 0.0)
		var base_p: Vector3 = Vector3(0.0, BARREL_Y, BARREL_FRONT_Z - 0.015) + radial_dir * (BARREL_RADIUS * 1.2)
		var spike_tip: Vector3 = base_p + radial_dir * 0.025 - Vector3(0.0, 0.0, 0.015)
		LowPolyMesh.prism(st, base_p, spike_tip, 0.010, 0.001, 4, METAL_DARK)

	# Abraçadeiras metálicas com rebites ao longo do cano
	for z_band: float in [-0.22, -0.05, 0.04]:
		LowPolyMesh.prism(st, Vector3(0.0, BARREL_Y, z_band - 0.012), Vector3(0.0, BARREL_Y, z_band + 0.012),
			BARREL_RADIUS * 1.15, BARREL_RADIUS * 1.15, 8, METAL_DARK)
		# Rebite na lateral da abraçadeira
		for sx: float in [-1.0, 1.0]:
			LowPolyMesh.prism(st, Vector3(sx * (BARREL_RADIUS * 1.12), BARREL_Y, z_band),
				Vector3(sx * (BARREL_RADIUS * 1.12 + 0.006), BARREL_Y, z_band), 0.005, 0.003, 5, METAL_BASE)

	# Guarda-mato do gatilho e alavanca inferior
	var trigger_c: Vector3 = Vector3(0.0, -0.05, 0.02)
	LowPolyMesh.prism(st, trigger_c, trigger_c + Vector3(0.0, -0.04, 0.0), 0.006, 0.006, 4, METAL_DARK)
	LowPolyMesh.prism(st, trigger_c + Vector3(0.0, -0.04, 0.0), trigger_c + Vector3(0.0, -0.02, 0.04), 0.005, 0.005, 4, METAL_DARK)
	# Gatilho
	LowPolyMesh.prism(st, Vector3(0.0, -0.03, 0.03), Vector3(0.0, -0.055, 0.025), 0.004, 0.002, 4, METAL_DARK)

	# Suportes e flanges laterais do carretel de corda
	var spool_c: Vector3 = Vector3(0.0, SPOOL_CENTER_Y, SPOOL_CENTER_Z)
	for sx: float in [-1.0, 1.0]:
		var flange_pos: Vector3 = spool_c + Vector3(sx * (SPOOL_WIDTH * 0.5 + 0.006), 0.0, 0.0)
		# Suporte vindo do cano
		LowPolyMesh.prism(st, Vector3(sx * (BARREL_RADIUS + 0.004), BARREL_Y, SPOOL_CENTER_Z),
			flange_pos, 0.012, 0.010, 5, METAL_DARK)
		# Disco / flange lateral do carretel
		LowPolyMesh.prism(st, flange_pos - Vector3(sx * 0.004, 0.0, 0.0), flange_pos + Vector3(sx * 0.004, 0.0, 0.0),
			SPOOL_RADIUS * 1.08, SPOOL_RADIUS * 1.08, 8, METAL_BASE)

	# Manivela do carretel (no lado direito)
	var crank_base: Vector3 = spool_c + Vector3(SPOOL_WIDTH * 0.5 + 0.015, 0.0, 0.0)
	var crank_arm: Vector3 = crank_base + Vector3(0.0, -0.045, -0.015)
	var crank_handle: Vector3 = crank_arm + Vector3(0.035, 0.0, 0.0)
	LowPolyMesh.prism(st, crank_base, crank_arm, 0.006, 0.005, 4, METAL_DARK)
	LowPolyMesh.prism(st, crank_arm, crank_handle, 0.007, 0.007, 5, WOOD_DARK)

	# Chapa de reforço na soleira da coronha (butt plate) com anel de amarração
	var butt_c: Vector3 = Vector3(0.0, STOCK_DROP_Y - 0.025, STOCK_BACK_Z)
	LowPolyMesh.prism(st, butt_c - Vector3(0.0, 0.0, 0.01), butt_c + Vector3(0.0, 0.0, 0.015),
		0.05, 0.052, 6, METAL_DARK)
	# Anel de metal inferior na coronha (sling mount)
	var ring_c: Vector3 = butt_c + Vector3(0.0, -0.05, -0.01)
	LowPolyMesh.prism(st, butt_c + Vector3(0.0, -0.03, -0.01), ring_c, 0.005, 0.005, 4, METAL_DARK)
	for k: int in 6:
		var a0: float = TAU * float(k) / 6.0
		var a1: float = TAU * float(k + 1) / 6.0
		var r_pos0: Vector3 = ring_c + Vector3(0.0, sin(a0) * 0.016, cos(a0) * 0.016)
		var r_pos1: Vector3 = ring_c + Vector3(0.0, sin(a1) * 0.016, cos(a1) * 0.016)
		LowPolyMesh.prism(st, r_pos0, r_pos1, 0.003, 0.003, 4, METAL_BASE)

	var mat: ShaderMaterial = ToolMesh.prop_material(&"metal_rust", METAL_BASE)
	mat.set_shader_parameter(&"rust_amount", 0.65)
	mat.set_shader_parameter(&"rust_color", METAL_RUST)
	ToolMesh.part(self, "MetalParts", st, mat)


func _build_rope_spool() -> void:
	var st: SurfaceTool = ToolMesh.begin()

	# Cilindro central do carretel com corda enrolada
	var spool_c: Vector3 = Vector3(0.0, SPOOL_CENTER_Y, SPOOL_CENTER_Z)
	var p_left: Vector3 = spool_c - Vector3(SPOOL_WIDTH * 0.5, 0.0, 0.0)
	var p_right: Vector3 = spool_c + Vector3(SPOOL_WIDTH * 0.5, 0.0, 0.0)
	LowPolyMesh.prism(st, p_left, p_right, SPOOL_RADIUS * 0.96, SPOOL_RADIUS * 0.96, 10, ROPE_COLOR)

	# Fios / voltas de corda em espiral na bobina
	for i: int in 7:
		var x_step: float = -SPOOL_WIDTH * 0.45 + float(i) * (SPOOL_WIDTH * 0.15)
		var c_ring: Vector3 = spool_c + Vector3(x_step, 0.0, 0.0)
		for seg: int in 8:
			var a0: float = TAU * float(seg) / 8.0
			var a1: float = TAU * float(seg + 1) / 8.0
			var p0: Vector3 = c_ring + Vector3(0.0, sin(a0) * SPOOL_RADIUS, cos(a0) * SPOOL_RADIUS)
			var p1: Vector3 = c_ring + Vector3(0.0, sin(a1) * SPOOL_RADIUS, cos(a1) * SPOOL_RADIUS)
			LowPolyMesh.prism(st, p0, p1, 0.006, 0.006, 4, ROPE_COLOR if (i + seg) % 2 == 0 else ROPE_DARK)

	# Voltas de corda atadas ao redor da coronha (junto à soleira, como na referência)
	var stock_rope_c: Vector3 = Vector3(0.0, STOCK_DROP_Y - 0.015, STOCK_BACK_Z - 0.04)
	for j: int in 4:
		var z_offset: float = float(j) * 0.012
		var c_wrap: Vector3 = stock_rope_c - Vector3(0.0, 0.0, z_offset)
		for seg: int in 6:
			var a0: float = TAU * float(seg) / 6.0
			var a1: float = TAU * float(seg + 1) / 6.0
			var p0: Vector3 = c_wrap + Vector3(cos(a0) * 0.032, sin(a0) * 0.042, 0.0)
			var p1: Vector3 = c_wrap + Vector3(cos(a1) * 0.032, sin(a1) * 0.042, 0.0)
			LowPolyMesh.prism(st, p0, p1, 0.005, 0.005, 4, ROPE_COLOR)

	var mat: ShaderMaterial = ToolMesh.prop_material(&"wood", ROPE_COLOR)
	mat.set_shader_parameter(&"grain_scale", 30.0)
	ToolMesh.part(self, "RopeSpool", st, mat)


func _build_harpoon_spear() -> void:
	var st: SurfaceTool = ToolMesh.begin()

	# Haste metálica do arpão saindo do cano
	var shaft_start: Vector3 = Vector3(0.0, BARREL_Y, BARREL_FRONT_Z + 0.10)
	var shaft_head: Vector3 = Vector3(0.0, BARREL_Y, -0.56)
	LowPolyMesh.prism(st, shaft_start, shaft_head, HARPOON_SHAFT_RADIUS, HARPOON_SHAFT_RADIUS * 0.9, 6, METAL_BASE)

	# Ponta da flecha / arpão: ponta central alargada e farpada
	var tip: Vector3 = Vector3(0.0, BARREL_Y, HARPOON_TIP_Z)
	var barb_main_left: Vector3 = shaft_head + Vector3(-0.065, 0.0, 0.04)
	var barb_main_right: Vector3 = shaft_head + Vector3(0.065, 0.0, 0.04)

	# Triângulo central da ponta
	LowPolyMesh.prism(st, shaft_head, tip, 0.022, 0.002, 4, METAL_BASE)

	# Farpa primária larga (frente)
	var blade_pts: PackedVector3Array = PackedVector3Array([
		tip,
		barb_main_right,
		shaft_head + Vector3(0.02, 0.0, 0.01),
		shaft_head - Vector3(0.02, 0.0, -0.01),
		barb_main_left
	])
	ToolMesh.slab(st, blade_pts, Vector3.UP, 0.012, METAL_BASE)

	# Farpas serrilhadas secundárias (dentes de trás ao longo da lâmina, fiéis a arpao_corda.jpg)
	var barb_sec_l: Vector3 = shaft_head + Vector3(-0.045, 0.0, 0.08)
	var barb_sec_r: Vector3 = shaft_head + Vector3(0.045, 0.0, 0.08)
	var sec_blade_pts: PackedVector3Array = PackedVector3Array([
		shaft_head,
		barb_sec_r,
		shaft_head + Vector3(0.015, 0.0, 0.06),
		shaft_head - Vector3(0.015, 0.0, -0.06),
		barb_sec_l
	])
	ToolMesh.slab(st, sec_blade_pts, Vector3.UP, 0.010, METAL_DARK)

	var mat: ShaderMaterial = ToolMesh.prop_material(&"metal_rust", METAL_BASE)
	mat.set_shader_parameter(&"rust_amount", 0.55)
	mat.set_shader_parameter(&"rust_color", METAL_RUST)
	ToolMesh.part(self, "HarpoonSpear", st, mat)


func _build_left_hand() -> void:
	var hand_script: Script = load("res://gameplay/player/hand_model.gd") as Script
	if hand_script == null:
		return
	var hand: Node3D = Node3D.new()
	hand.set_script(hand_script)
	hand.name = "LeftHand"
	hand.set("is_left", true)
	hand.set("pose", 1)  # Pose.GRIP
	# Mão esquerda segura o corpo da arma por baixo/à frente do carretel
	hand.transform = Transform3D(Basis(Vector3.UP, PI * 0.9).rotated(Vector3.FORWARD, deg_to_rad(80.0)),
		Vector3(-0.03, -0.05, -0.20))
	add_child(hand)
