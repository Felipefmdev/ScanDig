@tool
class_name GeleiraProp
extends Node3D

## Modelos low-poly toon dos objetos de missão, relíquias e segredos da Geleira Eterna (#43).
## Fiel às imagens de referência:
##   - BJORN: Velho Björn (velho_bjorn.jpg) com casaco forrado a pelo, gorro com pompom,
##            barba trançada, caneca fumegante e picareta de gelo;
##   - HEARTH_FIREPLACE: Lareira de pedra com fogo acolhedor que cura lentamente;
##   - EXPEDITION_DIARY: Diário da expedição perdido na neve;
##   - EXPEDITION_SLED: Trenó de carga ártico quebrado;
##   - THIN_ICE: Placa de gelo fino rachado sobre o lago;
##   - STALACTITE: Agrupamento de estalactites de gelo pontiagudas;
##   - AURORA_TRACKS: Pegadas luminescentes que revelam o caminho para o Yeti;
##   - BABY_MAMMOTH_ICE: Mamute bebé congelado num bloco de gelo translúcido;
##   - FOSSIL_GELO: Bloco de gelo facetado com fóssil espiral (fossil_gelo.jpg);
##   - MACHADO_VIKING: Machado de batalha nórdico com runas e cabo entalhado (machado_viking.jpg);
##   - BUSSOLA_ANTIGA: Bússola antiga de expedição em caixa com cristais de gelo (bussola_antiga.jpg);
##   - SNOWMAN_GOLD_CARROT: Boneco de neve com cenoura de ouro facetada (cenoura_ouro.jpg);
##   - PARTY_PENGUIN: Pinguim com chapéu de festa cónico colorido.
##
## Regra (#47): os filhos gerados não têm owner (o editor nunca os grava no .tscn).

enum Kind {
	BJORN,
	HEARTH_FIREPLACE,
	EXPEDITION_DIARY,
	EXPEDITION_SLED,
	THIN_ICE,
	STALACTITE,
	AURORA_TRACKS,
	BABY_MAMMOTH_ICE,
	FOSSIL_GELO,
	MACHADO_VIKING,
	BUSSOLA_ANTIGA,
	SNOWMAN_GOLD_CARROT,
	PARTY_PENGUIN
}

const ToolMesh = preload("res://gameplay/weapons/tool_mesh.gd")

# Paleta Geleira
const SNOW_WHITE: Color = Color(0.95, 0.97, 1.0)
const ICE_BLUE: Color = Color(0.60, 0.82, 0.94)
const ICE_DEEP: Color = Color(0.38, 0.65, 0.82)
const ICE_TRANSLUCENT: Color = Color(0.70, 0.88, 0.96)
const BROWN_LEATHER: Color = Color(0.44, 0.28, 0.16)
const BROWN_DARK: Color = Color(0.28, 0.18, 0.11)
const FUR_WHITE: Color = Color(0.92, 0.90, 0.86)
const SKIN_TONE: Color = Color(0.92, 0.70, 0.58)
const CHEEK_RED: Color = Color(0.92, 0.45, 0.42)
const BEARD_WHITE: Color = Color(0.96, 0.96, 0.98)
const HAT_WOOL: Color = Color(0.55, 0.52, 0.48)
const STONE_GREY: Color = Color(0.52, 0.54, 0.58)
const FIRE_YELLOW: Color = Color(1.0, 0.85, 0.25)
const FIRE_ORANGE: Color = Color(1.0, 0.45, 0.12)
const GOLD_METALLIC: Color = Color(0.98, 0.80, 0.20)
const GOLD_DARK: Color = Color(0.75, 0.55, 0.15)
const IRON_STEEL: Color = Color(0.48, 0.50, 0.54)
const IRON_RUST: Color = Color(0.52, 0.28, 0.16)
const AURORA_CYAN: Color = Color(0.25, 0.95, 0.85)

@export var kind: Kind = Kind.BJORN:
	set(v):
		kind = v
		if is_inside_tree():
			rebuild()

static var _material: ShaderMaterial = null


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	for c: Node in get_children():
		if c.owner == null:
			c.free()

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	match kind:
		Kind.BJORN:
			_bjorn(st)
		Kind.HEARTH_FIREPLACE:
			_hearth_fireplace(st)
		Kind.EXPEDITION_DIARY:
			_expedition_diary(st)
		Kind.EXPEDITION_SLED:
			_expedition_sled(st)
		Kind.THIN_ICE:
			_thin_ice(st)
		Kind.STALACTITE:
			_stalactite(st)
		Kind.AURORA_TRACKS:
			_aurora_tracks(st)
		Kind.BABY_MAMMOTH_ICE:
			_baby_mammoth_ice(st)
		Kind.FOSSIL_GELO:
			_fossil_gelo(st)
		Kind.MACHADO_VIKING:
			_machado_viking(st)
		Kind.BUSSOLA_ANTIGA:
			_bussola_antiga(st)
		Kind.SNOWMAN_GOLD_CARROT:
			_snowman_gold_carrot(st)
		Kind.PARTY_PENGUIN:
			_party_penguin(st)

	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = ToonKit.commit(st)
	mi.material_override = _shared_material()
	add_child(mi)

	if kind == Kind.HEARTH_FIREPLACE:
		var light: OmniLight3D = OmniLight3D.new()
		light.name = "FireLight"
		light.light_color = FIRE_ORANGE
		light.light_energy = 2.0
		light.omni_range = 6.0
		light.position = Vector3(0.0, 0.5, 0.0)
		add_child(light)


static func _shared_material() -> ShaderMaterial:
	if _material == null:
		_material = ToonKit.vertex_material(true, true)
		_material.set_shader_parameter(&"chip_amount", 0.18)
		_material.set_shader_parameter(&"chip_color", Color(0.85, 0.92, 0.98))
		_material.set_shader_parameter(&"chip_scale", 6.0)
	return _material


# ---------------------------------------------------------------------------
# Construtores procedimentais de modelos 3D
# ---------------------------------------------------------------------------

## NPC Velho Björn (fiel a velho_bjorn.jpg)
func _bjorn(st: SurfaceTool) -> void:
	# Botas com orla de pelo branco
	for sx: float in [-1.0, 1.0]:
		LowPolyMesh.box(st, Vector3(sx * 0.16, 0.06, -0.04), Vector3(0.14, 0.12, 0.22), Basis.IDENTITY, BROWN_DARK)
		LowPolyMesh.prism(st, Vector3(sx * 0.16, 0.12, 0.0), Vector3(sx * 0.16, 0.16, 0.0), 0.10, 0.10, 6, FUR_WHITE)
		LowPolyMesh.prism(st, Vector3(sx * 0.16, 0.16, 0.0), Vector3(sx * 0.16, 0.40, 0.0), 0.09, 0.11, 6, Color(0.32, 0.35, 0.34))

	# Tronco robusto e casacão de couro com orla de pele branca
	LowPolyMesh.prism(st, Vector3(0.0, 0.40, 0.0), Vector3(0.0, 0.88, 0.0), 0.28, 0.25, 7, BROWN_LEATHER)
	# Barra de pelo na base do casaco
	LowPolyMesh.prism(st, Vector3(0.0, 0.38, 0.0), Vector3(0.0, 0.45, 0.0), 0.30, 0.29, 7, FUR_WHITE)
	# Gola larga de pele branca em volta do pescoço
	LowPolyMesh.prism(st, Vector3(0.0, 0.84, 0.0), Vector3(0.0, 0.98, 0.0), 0.30, 0.26, 7, FUR_WHITE)

	# Cabeça, bochechas rosadas e nariz redondo avermelhado
	LowPolyMesh.prism(st, Vector3(0.0, 0.92, 0.0), Vector3(0.0, 1.15, 0.0), 0.18, 0.16, 7, SKIN_TONE)
	# Bochechas e nariz
	LowPolyMesh.prism(st, Vector3(0.0, 1.03, -0.17), Vector3(0.0, 1.03, -0.22), 0.045, 0.02, 5, CHEEK_RED)
	LowPolyMesh.prism(st, Vector3(-0.09, 1.04, -0.14), Vector3(-0.09, 1.04, -0.17), 0.035, 0.01, 4, CHEEK_RED)
	LowPolyMesh.prism(st, Vector3(0.09, 1.04, -0.14), Vector3(0.09, 1.04, -0.17), 0.035, 0.01, 4, CHEEK_RED)

	# Barba branca volumosa e bigode
	LowPolyMesh.prism(st, Vector3(0.0, 1.0, -0.10), Vector3(0.0, 0.52, -0.14), 0.20, 0.05, 5, BEARD_WHITE)
	# Duas tranças laterais com anéis decorativos (castanho e turquesa)
	for sx: float in [-1.0, 1.0]:
		var braid_start: Vector3 = Vector3(sx * 0.12, 0.94, -0.10)
		var braid_mid: Vector3 = Vector3(sx * 0.13, 0.72, -0.12)
		var braid_end: Vector3 = Vector3(sx * 0.13, 0.56, -0.10)
		LowPolyMesh.prism(st, braid_start, braid_mid, 0.042, 0.035, 5, BEARD_WHITE)
		LowPolyMesh.prism(st, braid_mid, braid_mid - Vector3(0.0, 0.025, 0.0), 0.040, 0.040, 5, Color(0.20, 0.65, 0.60))
		LowPolyMesh.prism(st, braid_mid - Vector3(0.0, 0.025, 0.0), braid_end, 0.032, 0.012, 5, BEARD_WHITE)

	# Gorro de lã de inverno com pompom no topo
	LowPolyMesh.prism(st, Vector3(0.0, 1.12, 0.0), Vector3(0.0, 1.30, 0.0), 0.19, 0.12, 7, HAT_WOOL)
	LowPolyMesh.prism(st, Vector3(0.0, 1.30, 0.0), Vector3(0.0, 1.37, 0.0), 0.05, 0.02, 6, FUR_WHITE)

	# Braço direito a segurar a caneca fumegante
	var r_shoulder: Vector3 = Vector3(0.26, 0.82, 0.0)
	var r_elbow: Vector3 = Vector3(0.38, 0.68, -0.06)
	var r_hand: Vector3 = Vector3(0.32, 0.72, -0.22)
	LowPolyMesh.prism(st, r_shoulder, r_elbow, 0.11, 0.09, 6, BROWN_LEATHER)
	LowPolyMesh.prism(st, r_elbow, r_hand, 0.09, 0.08, 6, BROWN_LEATHER)
	LowPolyMesh.prism(st, r_hand, r_hand + Vector3(0.0, 0.0, -0.04), 0.07, 0.06, 5, FUR_WHITE)
	# Luva / manápula
	LowPolyMesh.prism(st, r_hand + Vector3(0.0, 0.0, -0.04), r_hand + Vector3(0.0, 0.0, -0.10), 0.06, 0.05, 5, Color(0.55, 0.45, 0.28))
	# Caneca de madeira com aros metálicos e vapor
	var mug_c: Vector3 = r_hand + Vector3(0.02, 0.03, -0.15)
	LowPolyMesh.prism(st, mug_c - Vector3(0.0, 0.07, 0.0), mug_c + Vector3(0.0, 0.07, 0.0), 0.065, 0.065, 7, BROWN_LEATHER)
	LowPolyMesh.prism(st, mug_c + Vector3(0.0, 0.07, 0.0), mug_c + Vector3(0.0, 0.20, 0.0), 0.04, 0.01, 4, Color(0.95, 0.95, 0.98, 0.6))

	# Braço esquerdo a segurar a picareta de gelo
	var l_shoulder: Vector3 = Vector3(-0.26, 0.82, 0.0)
	var l_elbow: Vector3 = Vector3(-0.36, 0.65, -0.04)
	var l_hand: Vector3 = Vector3(-0.30, 0.45, -0.12)
	LowPolyMesh.prism(st, l_shoulder, l_elbow, 0.11, 0.09, 6, BROWN_LEATHER)
	LowPolyMesh.prism(st, l_elbow, l_hand, 0.09, 0.08, 6, BROWN_LEATHER)
	LowPolyMesh.prism(st, l_hand, l_hand - Vector3(0.0, 0.04, 0.0), 0.07, 0.06, 5, FUR_WHITE)
	# Cabo e cabeça da picareta
	LowPolyMesh.prism(st, l_hand + Vector3(0.0, 0.22, 0.0), l_hand - Vector3(0.0, 0.35, 0.0), 0.018, 0.016, 5, BROWN_DARK)
	var pick_head_c: Vector3 = l_hand + Vector3(0.0, 0.20, 0.0)
	LowPolyMesh.prism(st, pick_head_c - Vector3(0.14, 0.0, 0.0), pick_head_c + Vector3(0.14, 0.0, 0.0), 0.025, 0.005, 4, IRON_STEEL)


## Lareira acolhedora com braseiro de pedra e fogo que cura devagar
func _hearth_fireplace(st: SurfaceTool) -> void:
	# Base circular de pedras
	for k: int in 8:
		var a: float = TAU * float(k) / 8.0
		var pos: Vector3 = Vector3(cos(a) * 0.6, 0.12, sin(a) * 0.6)
		LowPolyMesh.prism(st, pos - Vector3(0.0, 0.12, 0.0), pos + Vector3(0.0, 0.12, 0.0), 0.16, 0.12, 5, STONE_GREY)

	# Toros de lenha cruzados
	LowPolyMesh.prism(st, Vector3(-0.35, 0.14, -0.2), Vector3(0.35, 0.14, 0.2), 0.07, 0.06, 5, BROWN_DARK)
	LowPolyMesh.prism(st, Vector3(-0.25, 0.16, 0.3), Vector3(0.25, 0.16, -0.3), 0.07, 0.06, 5, BROWN_DARK)

	# Labaredas de fogo facetadas
	LowPolyMesh.prism(st, Vector3(0.0, 0.15, 0.0), Vector3(0.0, 0.65, 0.0), 0.22, 0.01, 5, FIRE_YELLOW)
	LowPolyMesh.prism(st, Vector3(0.08, 0.15, 0.05), Vector3(0.05, 0.50, 0.02), 0.18, 0.01, 4, FIRE_ORANGE)
	LowPolyMesh.prism(st, Vector3(-0.06, 0.15, -0.04), Vector3(-0.04, 0.48, -0.02), 0.17, 0.01, 4, FIRE_ORANGE)


## Diário da Expedição Perdida
func _expedition_diary(st: SurfaceTool) -> void:
	# Livro de capa grossa de couro com fecho metálico e marcas de gelo
	LowPolyMesh.box(st, Vector3(0.0, 0.04, 0.0), Vector3(0.32, 0.08, 0.42), Basis.IDENTITY, BROWN_DARK)
	# Folhas douradas / amareladas
	LowPolyMesh.box(st, Vector3(0.01, 0.04, 0.0), Vector3(0.30, 0.06, 0.39), Basis.IDENTITY, Color(0.90, 0.86, 0.72))
	# Fivela de latão
	LowPolyMesh.prism(st, Vector3(0.16, 0.04, -0.05), Vector3(0.18, 0.04, 0.05), 0.02, 0.02, 4, GOLD_METALLIC)
	# Cristais de geada
	LowPolyMesh.prism(st, Vector3(-0.12, 0.08, -0.16), Vector3(-0.10, 0.12, -0.14), 0.04, 0.005, 4, ICE_TRANSLUCENT)


## Trenó quebrado da expedição
func _expedition_sled(st: SurfaceTool) -> void:
	# Lâminas de deslizamento inferiores (patins de madeira e metal)
	for sx: float in [-1.0, 1.0]:
		var r_pos: Vector3 = Vector3(sx * 0.45, 0.08, 0.0)
		LowPolyMesh.prism(st, r_pos - Vector3(0.0, 0.0, 0.9), r_pos + Vector3(0.0, 0.0, 0.8), 0.035, 0.035, 4, BROWN_DARK)
		# Ponta curvada frontal do patim
		LowPolyMesh.prism(st, r_pos - Vector3(0.0, 0.0, 0.9), r_pos + Vector3(0.0, 0.22, -1.15), 0.035, 0.025, 4, BROWN_DARK)

	# Travessas e prancha do trenó
	LowPolyMesh.box(st, Vector3(0.0, 0.22, 0.0), Vector3(0.85, 0.05, 1.6), Basis.IDENTITY, BROWN_LEATHER)
	# Caixote / fardos de carga amarrados
	LowPolyMesh.box(st, Vector3(0.0, 0.45, 0.2), Vector3(0.65, 0.40, 0.70), Basis.IDENTITY, Color(0.55, 0.42, 0.28))


## Placa de gelo fino rachado
func _thin_ice(st: SurfaceTool) -> void:
	var r: float = 2.2
	LowPolyMesh.prism(st, Vector3(0.0, -0.05, 0.0), Vector3(0.0, 0.02, 0.0), r, r * 0.98, 8, ICE_TRANSLUCENT)
	# Fissuras e rachaduras (linhas de gelo branco em teia de aranha)
	for i: int in 6:
		var a: float = TAU * float(i) / 6.0
		var crack_end: Vector3 = Vector3(cos(a) * r * 0.85, 0.025, sin(a) * r * 0.85)
		LowPolyMesh.prism(st, Vector3(0.0, 0.025, 0.0), crack_end, 0.025, 0.005, 3, SNOW_WHITE)


## Estalactites pontiagudas
func _stalactite(st: SurfaceTool) -> void:
	# Conjunto de 3 estalactites penduradas
	LowPolyMesh.prism(st, Vector3(0.0, 1.8, 0.0), Vector3(0.0, 0.2, 0.0), 0.22, 0.01, 5, ICE_BLUE)
	LowPolyMesh.prism(st, Vector3(0.22, 1.6, 0.1), Vector3(0.20, 0.5, 0.1), 0.14, 0.01, 4, ICE_TRANSLUCENT)
	LowPolyMesh.prism(st, Vector3(-0.18, 1.7, -0.15), Vector3(-0.16, 0.6, -0.12), 0.16, 0.01, 4, ICE_DEEP)


## Pegadas luminosas da Aurora
func _aurora_tracks(st: SurfaceTool) -> void:
	for step: int in 4:
		var z_step: float = -float(step) * 1.4
		var x_step: float = 0.25 if step % 2 == 0 else -0.25
		var pos: Vector3 = Vector3(x_step, 0.02, z_step)
		# Pegada grande com almofada e garras
		LowPolyMesh.prism(st, pos, pos + Vector3(0.0, 0.02, 0.0), 0.18, 0.16, 6, AURORA_CYAN)
		for claw: int in 3:
			var ca: float = -0.5 + float(claw) * 0.5
			var c_pos: Vector3 = pos + Vector3(sin(ca) * 0.22, 0.02, -cos(ca) * 0.22)
			LowPolyMesh.prism(st, c_pos, c_pos + Vector3(0.0, 0.015, 0.0), 0.05, 0.01, 4, AURORA_CYAN)


## Mamute bebé congelado em bloco de gelo
func _baby_mammoth_ice(st: SurfaceTool) -> void:
	# Bloco de gelo cúbico facetado e translúcido
	LowPolyMesh.box(st, Vector3(0.0, 0.65, 0.0), Vector3(1.4, 1.3, 1.4), Basis.IDENTITY, ICE_TRANSLUCENT)
	# Silhueta de mamute peludo castanho lá dentro
	LowPolyMesh.prism(st, Vector3(0.0, 0.40, 0.2), Vector3(0.0, 0.85, 0.1), 0.38, 0.32, 6, BROWN_DARK)
	# Cabeça e tromba
	LowPolyMesh.prism(st, Vector3(0.0, 0.80, -0.15), Vector3(0.0, 0.95, -0.25), 0.24, 0.20, 5, BROWN_DARK)
	LowPolyMesh.prism(st, Vector3(0.0, 0.80, -0.32), Vector3(0.0, 0.42, -0.36), 0.08, 0.05, 4, BROWN_DARK)
	# Pequenas presas de marfim
	for sx: float in [-1.0, 1.0]:
		LowPolyMesh.prism(st, Vector3(sx * 0.14, 0.70, -0.25), Vector3(sx * 0.24, 0.80, -0.40), 0.035, 0.008, 4, FUR_WHITE)


## Fóssil no gelo milenar (fiel a fossil_gelo.jpg)
func _fossil_gelo(st: SurfaceTool) -> void:
	# Cubo de gelo translúcido chanfrado com cantos facetados
	LowPolyMesh.box(st, Vector3(0.0, 0.30, 0.0), Vector3(0.60, 0.60, 0.60), Basis.IDENTITY, ICE_TRANSLUCENT)
	# Fóssil de amonite / concha espiralizada ocre no centro
	var fossil_c: Vector3 = Vector3(0.0, 0.30, 0.0)
	var shell_segs: int = 10
	for i: int in shell_segs:
		var a: float = TAU * float(i) / float(shell_segs) * 1.5
		var rad: float = 0.04 + float(i) * 0.016
		var p_seg: Vector3 = fossil_c + Vector3(cos(a) * rad, sin(a) * rad, 0.0)
		LowPolyMesh.prism(st, p_seg - Vector3(0.0, 0.0, 0.04), p_seg + Vector3(0.0, 0.0, 0.04),
			0.025 + float(i) * 0.008, 0.02 + float(i) * 0.008, 5, Color(0.72, 0.58, 0.36))


## Machado Viking Ancestral (fiel a machado_viking.jpg)
func _machado_viking(st: SurfaceTool) -> void:
	# Cabo ergonómico curvo de madeira com nós nórdicos
	var handle_base: Vector3 = Vector3(0.0, 0.05, 0.18)
	var handle_mid: Vector3 = Vector3(0.0, 0.35, 0.06)
	var handle_top: Vector3 = Vector3(0.0, 0.65, -0.08)
	LowPolyMesh.prism(st, handle_base, handle_mid, 0.032, 0.028, 6, BROWN_LEATHER)
	LowPolyMesh.prism(st, handle_mid, handle_top, 0.028, 0.032, 6, BROWN_LEATHER)

	# Fita de couro enrolada na empunhadura inferior
	LowPolyMesh.prism(st, handle_base, handle_base + Vector3(0.0, 0.16, -0.06), 0.036, 0.036, 6, BROWN_DARK)

	# Lâmina larga em meia-lua com barba curva e gume serrilhado de batalha
	var eye_c: Vector3 = handle_top - Vector3(0.0, 0.08, 0.0)
	var blade_top: Vector3 = eye_c + Vector3(0.0, 0.18, -0.16)
	var blade_edge: Vector3 = eye_c + Vector3(0.0, 0.02, -0.32)
	var blade_beard: Vector3 = eye_c + Vector3(0.0, -0.22, -0.22)

	var blade_pts: PackedVector3Array = PackedVector3Array([
		eye_c + Vector3(0.0, 0.10, 0.04),
		blade_top,
		blade_edge,
		blade_beard,
		eye_c - Vector3(0.0, 0.10, 0.02)
	])
	ToolMesh.slab(st, blade_pts, Vector3.RIGHT, 0.035, IRON_STEEL)

	# Cruzamento de fitas de couro no topo da lâmina
	LowPolyMesh.prism(st, eye_c - Vector3(0.02, 0.05, 0.02), eye_c + Vector3(0.02, 0.05, -0.02), 0.04, 0.04, 4, BROWN_DARK)


## Bússola Antiga da Expedição (fiel a bussola_antiga.jpg)
func _bussola_antiga(st: SurfaceTool) -> void:
	# Estojo de couro e madeira aberto com fecho de fivela
	LowPolyMesh.box(st, Vector3(0.0, 0.06, 0.0), Vector3(0.38, 0.12, 0.38), Basis.IDENTITY, BROWN_DARK)
	# Tampa aberta inclinada para trás (+Z)
	var lid_box: Vector3 = Vector3(0.38, 0.06, 0.38)
	var lid_basis: Basis = Basis(Vector3.RIGHT, deg_to_rad(-65.0))
	LowPolyMesh.box(st, Vector3(0.0, 0.22, 0.24), lid_box, lid_basis, BROWN_DARK)

	# Fivela de metal frontal
	LowPolyMesh.prism(st, Vector3(0.0, 0.05, -0.20), Vector3(0.0, 0.02, -0.24), 0.04, 0.03, 4, GOLD_METALLIC)

	# Cristais pontiagudos de gelo agarrados às bordas do estojo
	for sx: float in [-1.0, 1.0]:
		LowPolyMesh.prism(st, Vector3(sx * 0.18, 0.12, -0.16), Vector3(sx * 0.22, 0.18, -0.18), 0.04, 0.005, 4, ICE_TRANSLUCENT)
		LowPolyMesh.prism(st, Vector3(sx * 0.18, 0.12, 0.12), Vector3(sx * 0.22, 0.19, 0.14), 0.045, 0.005, 4, ICE_TRANSLUCENT)

	# Caixa circular de latão da bússola com mostrador
	var compass_c: Vector3 = Vector3(0.0, 0.13, 0.0)
	LowPolyMesh.prism(st, compass_c - Vector3(0.0, 0.05, 0.0), compass_c + Vector3(0.0, 0.03, 0.0), 0.14, 0.14, 8, GOLD_METALLIC)
	# Mostrador claro
	LowPolyMesh.prism(st, compass_c + Vector3(0.0, 0.02, 0.0), compass_c + Vector3(0.0, 0.035, 0.0), 0.12, 0.12, 8, Color(0.92, 0.88, 0.78))
	# Agulha magnética dupla pontiaguda (azul/vermelha e bronze)
	LowPolyMesh.prism(st, compass_c + Vector3(0.0, 0.04, -0.09), compass_c + Vector3(0.0, 0.04, 0.09), 0.02, 0.002, 4, IRON_STEEL)


## Boneco de Neve com Cenoura de Ouro (fiel a cenoura_ouro.jpg)
func _snowman_gold_carrot(st: SurfaceTool) -> void:
	# 3 esferas de neve sobrepostas
	LowPolyMesh.prism(st, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.65, 0.0), 0.55, 0.48, 8, SNOW_WHITE)
	LowPolyMesh.prism(st, Vector3(0.0, 0.60, 0.0), Vector3(0.0, 1.20, 0.0), 0.42, 0.36, 8, SNOW_WHITE)
	LowPolyMesh.prism(st, Vector3(0.0, 1.15, 0.0), Vector3(0.0, 1.65, 0.0), 0.30, 0.24, 7, SNOW_WHITE)

	# Olhos de carvão e sorriso de pedrinhas
	LowPolyMesh.prism(st, Vector3(-0.09, 1.45, -0.26), Vector3(-0.09, 1.45, -0.29), 0.025, 0.015, 4, Color.BLACK)
	LowPolyMesh.prism(st, Vector3(0.09, 1.45, -0.26), Vector3(0.09, 1.45, -0.29), 0.025, 0.015, 4, Color.BLACK)
	for s: int in 5:
		var ang: float = -0.6 + float(s) * 0.3
		var sm_pos: Vector3 = Vector3(sin(ang) * 0.12, 1.34 - cos(ang) * 0.04, -0.27)
		LowPolyMesh.prism(st, sm_pos, sm_pos + Vector3(0.0, 0.0, -0.02), 0.018, 0.010, 4, Color.BLACK)

	# Braços de galho de madeira
	LowPolyMesh.prism(st, Vector3(0.38, 0.95, 0.0), Vector3(0.85, 1.20, -0.1), 0.022, 0.012, 4, BROWN_DARK)
	LowPolyMesh.prism(st, Vector3(-0.38, 0.95, 0.0), Vector3(-0.85, 1.15, -0.1), 0.022, 0.012, 4, BROWN_DARK)

	# Nariz de Cenoura de Ouro (fiel a cenoura_ouro.jpg: cónica, facetada, entalhes)
	var nose_base: Vector3 = Vector3(0.0, 1.40, -0.28)
	var nose_tip: Vector3 = Vector3(0.0, 1.38, -0.62)
	LowPolyMesh.prism(st, nose_base, nose_tip, 0.055, 0.008, 6, GOLD_METALLIC)
	# Anéis / entalhes na cenoura de ouro
	for notch: int in 3:
		var z_notch: float = -0.36 - float(notch) * 0.08
		LowPolyMesh.prism(st, Vector3(0.0, 1.39, z_notch - 0.01), Vector3(0.0, 1.39, z_notch + 0.01),
			0.048 - float(notch) * 0.01, 0.048 - float(notch) * 0.01, 6, GOLD_DARK)


## Pinguim com Chapéu de Festa
func _party_penguin(st: SurfaceTool) -> void:
	# Corpo em smoking preto e barriga branca
	LowPolyMesh.prism(st, Vector3(0.0, 0.06, 0.0), Vector3(0.0, 0.65, 0.0), 0.22, 0.16, 7, Color(0.12, 0.14, 0.16))
	# Barriga branca frontal
	LowPolyMesh.prism(st, Vector3(0.0, 0.08, -0.08), Vector3(0.0, 0.58, -0.06), 0.16, 0.12, 5, SNOW_WHITE)
	# Patas cor-de-laranja espalmadas
	for sx: float in [-1.0, 1.0]:
		LowPolyMesh.box(st, Vector3(sx * 0.11, 0.03, -0.10), Vector3(0.12, 0.04, 0.18), Basis.IDENTITY, Color(0.95, 0.55, 0.15))

	# Asas laterais
	for sx: float in [-1.0, 1.0]:
		var wing_top: Vector3 = Vector3(sx * 0.20, 0.50, 0.0)
		var wing_tip: Vector3 = Vector3(sx * 0.26, 0.24, 0.04)
		LowPolyMesh.prism(st, wing_top, wing_tip, 0.06, 0.015, 4, Color(0.12, 0.14, 0.16))

	# Bico laranja cónico
	LowPolyMesh.prism(st, Vector3(0.0, 0.55, -0.15), Vector3(0.0, 0.53, -0.28), 0.04, 0.005, 4, Color(0.95, 0.55, 0.15))
	# Olhinhos
	LowPolyMesh.prism(st, Vector3(-0.06, 0.58, -0.14), Vector3(-0.06, 0.58, -0.16), 0.015, 0.01, 4, Color.BLACK)
	LowPolyMesh.prism(st, Vector3(0.06, 0.58, -0.14), Vector3(0.06, 0.58, -0.16), 0.015, 0.01, 4, Color.BLACK)

	# Chapéu cónico festivo com riscas e pompom colorido
	var hat_base: Vector3 = Vector3(0.0, 0.65, 0.0)
	var hat_tip: Vector3 = Vector3(0.0, 0.95, 0.0)
	LowPolyMesh.prism(st, hat_base, hat_tip, 0.14, 0.01, 6, Color(0.92, 0.22, 0.35))
	# Pompom no topo do chapéu
	LowPolyMesh.prism(st, hat_tip, hat_tip + Vector3(0.0, 0.06, 0.0), 0.04, 0.01, 5, GOLD_METALLIC)
