@tool
class_name CrateraProp
extends Node3D

## Props e modelos procedurais para os segredos e missões da Cratera (#44).
## Reproduz com fidelidade as referências visuais em C:\Users\felip\Pictures\scandig\:
##   - dra_vega.jpg
##   - orbe_vibrante.jpg
##   - engrenagem_alienigena.jpg
##   - fragmento_meteorito.jpg
##
## Regra (#47): tudo o que é gerado entra na árvore SEM owner.

const ToolMesh = preload("res://gameplay/weapons/tool_mesh.gd")

enum Kind {
	DRA_VEGA,
	ANTENNA_RELAY,
	RESONANT_CRYSTAL,
	METEORITE_ROCK,
	GEODE_ROCK,
	ORB_VIBRANTE,
	CRYSTAL_CURTAIN,
	ENGRENAGEM_ALIENIGENA,
	SPACE_PROBE,
	VINYL_RECORD
}

# Paleta de cores fiéis às referências
const SKIN_TONE: Color = Color(0.78, 0.52, 0.38)
const AFRO_HAIR: Color = Color(0.28, 0.18, 0.12)
const HEADPHONE_ORANGE: Color = Color(0.88, 0.46, 0.14)
const HEADPHONE_BAND: Color = Color(0.20, 0.20, 0.22)
const LAB_COAT: Color = Color(0.88, 0.90, 0.92)
const JUMPSUIT_ORANGE: Color = Color(0.84, 0.44, 0.16)
const BOOTS_DARK: Color = Color(0.22, 0.20, 0.18)
const RADAR_SCREEN: Color = Color(0.25, 0.88, 0.38)
const RADAR_BODY: Color = Color(0.45, 0.48, 0.45)
const BACKPACK_RIG: Color = Color(0.50, 0.48, 0.44)
const ANTENNA_ROD: Color = Color(0.75, 0.78, 0.80)

const METEOR_CRUST: Color = Color(0.22, 0.20, 0.22)
const METEOR_RUST: Color = Color(0.50, 0.32, 0.18)
const FISSURE_VIOLET: Color = Color(0.72, 0.28, 0.95)
const CRYSTAL_PURPLE: Color = Color(0.65, 0.35, 0.85)
const CRYSTAL_CYAN: Color = Color(0.25, 0.95, 0.90)

const GOLD_CORE: Color = Color(0.94, 0.76, 0.22)
const GOLD_RING: Color = Color(0.96, 0.82, 0.35)
const CAGE_BRONZE: Color = Color(0.48, 0.36, 0.28)
const GEAR_BRONZE: Color = Color(0.55, 0.38, 0.28)

@export var kind: Kind = Kind.DRA_VEGA:
	set(v):
		kind = v
		if is_inside_tree():
			rebuild()

@export var seed_value: int = 1


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	ToolMesh.clear(self)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value

	match kind:
		Kind.DRA_VEGA:
			_build_dra_vega(st)
		Kind.ANTENNA_RELAY:
			_build_antenna_relay(st)
		Kind.RESONANT_CRYSTAL:
			_build_resonant_crystal(st, rng)
		Kind.METEORITE_ROCK:
			_build_meteorite_rock(st, rng)
		Kind.GEODE_ROCK:
			_build_geode_rock(st, rng)
		Kind.ORB_VIBRANTE:
			_build_orb_vibrante(st)
		Kind.CRYSTAL_CURTAIN:
			_build_crystal_curtain(st, rng)
		Kind.ENGRENAGEM_ALIENIGENA:
			_build_engrenagem_alienigena(st)
		Kind.SPACE_PROBE:
			_build_space_probe(st)
		Kind.VINYL_RECORD:
			_build_vinyl_record(st)

	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "ModelMesh"
	mi.mesh = ToonKit.commit(st)
	mi.material_override = ToonKit.vertex_material(true, true)
	add_child(mi)


## NPC Dra. Vega (fiel a dra_vega.jpg)
func _build_dra_vega(st: SurfaceTool) -> void:
	# Botas pesadas
	for sx: float in [-1.0, 1.0]:
		var boot_pos: Vector3 = Vector3(sx * 0.14, 0.1, 0.0)
		LowPolyMesh.box(st, boot_pos, Vector3(0.16, 0.2, 0.26), Basis.IDENTITY, BOOTS_DARK)

	# Pernas de macacão laranja com faixas utilitárias
	for sx: float in [-1.0, 1.0]:
		var leg_p0: Vector3 = Vector3(sx * 0.14, 0.2, 0.0)
		var leg_p1: Vector3 = Vector3(sx * 0.12, 0.75, 0.0)
		LowPolyMesh.prism(st, leg_p0, leg_p1, 0.12, 0.14, 6, JUMPSUIT_ORANGE)
		# Tiras de arnês nas coxas
		LowPolyMesh.box(st, Vector3(sx * 0.13, 0.5, 0.0), Vector3(0.14, 0.04, 0.15), Basis.IDENTITY, BOOTS_DARK)

	# Tronco: macacão laranja com cinto e fivela
	var torso_c: Vector3 = Vector3(0.0, 1.05, 0.0)
	LowPolyMesh.box(st, torso_c, Vector3(0.36, 0.55, 0.24), Basis.IDENTITY, JUMPSUIT_ORANGE)
	LowPolyMesh.box(st, Vector3(0.0, 0.8, 0.0), Vector3(0.38, 0.08, 0.26), Basis.IDENTITY, BOOTS_DARK)
	LowPolyMesh.box(st, Vector3(0.0, 0.8, 0.13), Vector3(0.1, 0.09, 0.02), Basis.IDENTITY, METAL_GRAY)

	# Bata branca de cientista por cima do macacão (aberta à frente)
	LowPolyMesh.box(st, Vector3(-0.16, 0.95, 0.0), Vector3(0.12, 0.72, 0.28), Basis.IDENTITY, LAB_COAT)
	LowPolyMesh.box(st, Vector3(0.16, 0.95, 0.0), Vector3(0.12, 0.72, 0.28), Basis.IDENTITY, LAB_COAT)
	LowPolyMesh.box(st, Vector3(0.0, 1.05, -0.11), Vector3(0.38, 0.55, 0.08), Basis.IDENTITY, LAB_COAT)

	# Crachá "DRA. VEGA" no peito
	LowPolyMesh.box(st, Vector3(0.12, 1.18, 0.13), Vector3(0.08, 0.05, 0.01), Basis.IDENTITY, LAB_COAT)
	LowPolyMesh.box(st, Vector3(0.12, 1.18, 0.136), Vector3(0.06, 0.03, 0.005), Basis.IDENTITY, Color(0.2, 0.2, 0.2))

	# Mochila com equipamento de rádio nas costas
	var pack_c: Vector3 = Vector3(0.0, 1.1, -0.2)
	LowPolyMesh.box(st, pack_c, Vector3(0.32, 0.42, 0.16), Basis.IDENTITY, BACKPACK_RIG)
	# Dials e caixas na mochila
	LowPolyMesh.box(st, pack_c + Vector3(0.1, 0.1, -0.09), Vector3(0.08, 0.08, 0.04), Basis.IDENTITY, METAL_GRAY)
	# Antena em zig-zag subindo da mochila
	var a0: Vector3 = pack_c + Vector3(0.12, 0.22, 0.0)
	var a1: Vector3 = a0 + Vector3(0.04, 0.15, 0.0)
	var a2: Vector3 = a1 + Vector3(-0.06, 0.15, 0.0)
	var a3: Vector3 = a2 + Vector3(0.04, 0.15, 0.0)
	LowPolyMesh.prism(st, a0, a1, 0.012, 0.012, 4, ANTENNA_ROD)
	LowPolyMesh.prism(st, a1, a2, 0.012, 0.012, 4, ANTENNA_ROD)
	LowPolyMesh.prism(st, a2, a3, 0.012, 0.008, 4, ANTENNA_ROD)

	# Braços com mangas arregaçadas segurando o tablet
	var arm_l0: Vector3 = Vector3(-0.22, 1.25, 0.0)
	var hand_l: Vector3 = Vector3(-0.08, 1.05, 0.28)
	LowPolyMesh.prism(st, arm_l0, hand_l, 0.08, 0.05, 5, LAB_COAT)
	var arm_r0: Vector3 = Vector3(0.22, 1.25, 0.0)
	var hand_r: Vector3 = Vector3(0.02, 1.08, 0.26)
	LowPolyMesh.prism(st, arm_r0, hand_r, 0.08, 0.05, 5, LAB_COAT)

	# Tablet / Scanner com tela verde de radar
	var pad_c: Vector3 = Vector3(-0.05, 1.05, 0.3)
	var pad_basis: Basis = Basis(Vector3.RIGHT, deg_to_rad(-30.0)).rotated(Vector3.UP, deg_to_rad(15.0))
	LowPolyMesh.box(st, pad_c, Vector3(0.22, 0.16, 0.03), pad_basis, RADAR_BODY)
	LowPolyMesh.box(st, pad_c + Vector3(0.0, 0.01, 0.02), Vector3(0.17, 0.12, 0.01), pad_basis, RADAR_SCREEN)

	# Cabeça, pescoço e rosto
	LowPolyMesh.prism(st, Vector3(0.0, 1.3, 0.0), Vector3(0.0, 1.4, 0.0), 0.08, 0.08, 6, SKIN_TONE)
	var head_c: Vector3 = Vector3(0.0, 1.5, 0.0)
	LowPolyMesh.box(st, head_c, Vector3(0.24, 0.25, 0.22), Basis.IDENTITY, SKIN_TONE)
	# Sorriso e olhos expressivos
	LowPolyMesh.box(st, head_c + Vector3(-0.05, 0.02, 0.115), Vector3(0.03, 0.03, 0.01), Basis.IDENTITY, Color(0.1, 0.1, 0.1))
	LowPolyMesh.box(st, head_c + Vector3(0.05, 0.02, 0.115), Vector3(0.03, 0.03, 0.01), Basis.IDENTITY, Color(0.1, 0.1, 0.1))
	LowPolyMesh.box(st, head_c + Vector3(0.0, -0.06, 0.115), Vector3(0.08, 0.025, 0.01), Basis.IDENTITY, Color(0.85, 0.35, 0.35))

	# Auscultadores grandes laranjas sobre as orelhas
	for sx: float in [-1.0, 1.0]:
		var phone_c: Vector3 = Vector3(sx * 0.15, 1.5, 0.0)
		LowPolyMesh.box(st, phone_c, Vector3(0.06, 0.12, 0.12), Basis.IDENTITY, HEADPHONE_ORANGE)
	# Arco superior dos auscultadores
	LowPolyMesh.prism(st, Vector3(-0.15, 1.58, 0.0), Vector3(0.15, 1.58, 0.0), 0.03, 0.03, 4, HEADPHONE_BAND)

	# Cabelo afro/encaracolado volumoso castanho facetado
	for i: int in range(12):
		var ang: float = TAU * float(i) / 12.0
		var curl_p: Vector3 = head_c + Vector3(cos(ang) * 0.16, sin(ang) * 0.14 + 0.06, -0.04)
		LowPolyMesh.prism(st, curl_p, curl_p + Vector3(cos(ang) * 0.08, sin(ang) * 0.08, -0.04), 0.08, 0.03, 5, AFRO_HAIR)


## Antena repetidora para calibração na missão "Sinal no fundo"
func _build_antenna_relay(st: SurfaceTool) -> void:
	# Tripé metálico
	for k: int in range(3):
		var ang: float = TAU * float(k) / 3.0
		var foot: Vector3 = Vector3(cos(ang) * 0.7, 0.0, sin(ang) * 0.7)
		var apex: Vector3 = Vector3(0.0, 1.1, 0.0)
		LowPolyMesh.prism(st, foot, apex, 0.06, 0.04, 4, METAL_GRAY)

	# Mastro vertical
	LowPolyMesh.prism(st, Vector3(0.0, 1.1, 0.0), Vector3(0.0, 2.6, 0.0), 0.07, 0.04, 4, METAL_GRAY)
	# Caixa de controlo de calibração
	LowPolyMesh.box(st, Vector3(0.0, 1.0, 0.0), Vector3(0.35, 0.45, 0.35), Basis.IDENTITY, MODULE_ORANGE)
	# Luz de sinal no topo
	LowPolyMesh.prism(st, Vector3(0.0, 2.6, 0.0), Vector3(0.0, 2.85, 0.0), 0.06, 0.01, 5, CRYSTAL_CYAN)


## Cristal ressonante que emite frequência harmónica
func _build_resonant_crystal(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	# Base de rocha cósmica
	LowPolyMesh.prism(st, Vector3.ZERO, Vector3(0.0, 0.25, 0.0), 0.5, 0.4, 6, METEOR_CRUST)
	# Coluna de cristal principal
	var h: float = rng.randf_range(1.6, 2.1)
	LowPolyMesh.prism(st, Vector3(0.0, 0.2, 0.0), Vector3(0.0, h * 0.8, 0.0), 0.28, 0.22, 6, CRYSTAL_PURPLE)
	LowPolyMesh.prism(st, Vector3(0.0, h * 0.8, 0.0), Vector3(0.0, h, 0.0), 0.22, 0.015, 6, CRYSTAL_CYAN)


## Fragmento de meteorito com fendas roxas (fiel a fragmento_meteorito.jpg)
func _build_meteorite_rock(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	var h: float = 1.1
	LowPolyMesh.box(st, Vector3(0.0, h * 0.5, 0.0), Vector3(1.2, h, 1.0), Basis.IDENTITY, METEOR_CRUST)
	# Fissuras de energia
	for i: int in range(3):
		var y_crack: float = 0.25 + float(i) * 0.3
		var c0: Vector3 = Vector3(-0.62, y_crack, rng.randf_range(-0.3, 0.3))
		var c1: Vector3 = Vector3(0.62, y_crack + rng.randf_range(-0.1, 0.1), rng.randf_range(-0.3, 0.3))
		LowPolyMesh.prism(st, c0, c1, 0.035, 0.035, 4, FISSURE_VIOLET)


## Geodo estelar que racha com a pá
func _build_geode_rock(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	# Casca externa de rocha vulcânica escura
	LowPolyMesh.prism(st, Vector3.ZERO, Vector3(0.0, 0.9, 0.0), 0.65, 0.45, 7, METEOR_CRUST)
	# Abertura/fenda mostrando o brilho estelar interior
	LowPolyMesh.prism(st, Vector3(0.0, 0.2, 0.2), Vector3(0.0, 0.8, 0.2), 0.25, 0.1, 5, CRYSTAL_CYAN)


## Relíquia: Orbe Vibrante (fiel a orbe_vibrante.jpg)
func _build_orb_vibrante(st: SurfaceTool) -> void:
	var center: Vector3 = Vector3(0.0, 0.6, 0.0)
	# Núcleo icosaédrico dourado brilhante
	LowPolyMesh.prism(st, center - Vector3(0, 0.16, 0), center + Vector3(0, 0.16, 0), 0.18, 0.18, 8, GOLD_CORE)

	# Gaiola de bronze com arcos e rebites
	for ang_deg: float in [0.0, 60.0, 120.0]:
		var rot_b: Basis = Basis(Vector3.UP, deg_to_rad(ang_deg))
		LowPolyMesh.prism(st, center - Vector3(0, 0.22, 0), center + Vector3(0, 0.22, 0), 0.22, 0.22, 4, CAGE_BRONZE)

	# Anel equatorial de bronze com parafusos
	LowPolyMesh.prism(st, center - Vector3(0, 0.03, 0), center + Vector3(0, 0.03, 0), 0.24, 0.24, 8, CAGE_BRONZE)

	# Anéis orbitais dourados vibrantes
	var ring_b1: Basis = Basis(Vector3.RIGHT, deg_to_rad(35.0)).rotated(Vector3.UP, deg_to_rad(20.0))
	for k: int in range(12):
		var a0: float = TAU * float(k) / 12.0
		var a1: float = TAU * float(k + 1) / 12.0
		var p0: Vector3 = center + ring_b1 * (Vector3(cos(a0), 0.0, sin(a0)) * 0.38)
		var p1: Vector3 = center + ring_b1 * (Vector3(cos(a1), 0.0, sin(a1)) * 0.38)
		LowPolyMesh.prism(st, p0, p1, 0.016, 0.016, 4, GOLD_RING)


## Cortina de cristais translúcidos
func _build_crystal_curtain(st: SurfaceTool, rng: RandomNumberGenerator) -> void:
	for k: int in range(6):
		var x_pos: float = -1.2 + float(k) * 0.48
		var top_y: float = rng.randf_range(2.2, 2.6)
		var bot_y: float = rng.randf_range(0.3, 0.7)
		var p0: Vector3 = Vector3(x_pos, bot_y, 0.0)
		var p1: Vector3 = Vector3(x_pos, top_y, 0.0)
		var col: Color = CRYSTAL_CYAN if k % 2 == 0 else CRYSTAL_PURPLE
		LowPolyMesh.prism(st, p0, p1, 0.14, 0.08, 5, col)


## Relíquia: Engrenagem Alienígena (fiel a engrenagem_alienigena.jpg)
func _build_engrenagem_alienigena(st: SurfaceTool) -> void:
	var center: Vector3 = Vector3(0.0, 0.15, 0.0)
	var teeth: int = 10
	var outer_r: float = 0.42
	var inner_r: float = 0.32

	# Anel dentado de bronze
	for k: int in teeth:
		var a0: float = TAU * float(k) / float(teeth)
		var a1: float = TAU * (float(k) + 0.5) / float(teeth)
		var a2: float = TAU * float(k + 1) / float(teeth)
		var p_in0: Vector3 = center + Vector3(cos(a0) * inner_r, 0.0, sin(a0) * inner_r)
		var p_out: Vector3 = center + Vector3(cos(a1) * outer_r, 0.0, sin(a1) * outer_r)
		var p_in1: Vector3 = center + Vector3(cos(a2) * inner_r, 0.0, sin(a2) * inner_r)
		LowPolyMesh.prism(st, p_in0, p_out, 0.04, 0.03, 4, GEAR_BRONZE)
		LowPolyMesh.prism(st, p_out, p_in1, 0.04, 0.03, 4, GEAR_BRONZE)
		# Cristal embutido no dente
		var gem_pos: Vector3 = (p_in0 + p_out) * 0.5 + Vector3(0.0, 0.02, 0.0)
		LowPolyMesh.box(st, gem_pos, Vector3(0.05, 0.03, 0.05), Basis.IDENTITY, CRYSTAL_CYAN)

	# Cubo central com gema redonda ciano
	LowPolyMesh.prism(st, center - Vector3(0, 0.04, 0), center + Vector3(0, 0.04, 0), 0.16, 0.16, 8, GEAR_BRONZE)
	LowPolyMesh.prism(st, center + Vector3(0, 0.03, 0), center + Vector3(0, 0.08, 0), 0.09, 0.04, 8, CRYSTAL_CYAN)


## Easter Egg 1: Sonda espacial de pesquisa com bandeira
func _build_space_probe(st: SurfaceTool) -> void:
	var base_c: Vector3 = Vector3(0.0, 0.4, 0.0)
	# Corpo octogonal dourado com cobertura térmica foil
	LowPolyMesh.prism(st, base_c, base_c + Vector3(0.0, 0.5, 0.0), 0.32, 0.32, 8, GOLD_CORE)
	# Pernas de aterragem
	for k: int in range(4):
		var ang: float = TAU * float(k) / 4.0
		var leg_start: Vector3 = base_c + Vector3(cos(ang) * 0.25, 0.1, sin(ang) * 0.25)
		var foot: Vector3 = Vector3(cos(ang) * 0.55, 0.0, sin(ang) * 0.55)
		LowPolyMesh.prism(st, leg_start, foot, 0.04, 0.07, 4, METAL_GRAY)
	# Mastro de antena com bandeira ScanDig
	var mast_top: Vector3 = base_c + Vector3(0.0, 1.1, 0.0)
	LowPolyMesh.prism(st, base_c + Vector3(0.0, 0.5, 0.0), mast_top, 0.02, 0.01, 4, METAL_GRAY)
	LowPolyMesh.box(st, mast_top + Vector3(0.15, -0.08, 0.0), Vector3(0.28, 0.16, 0.01), Basis.IDENTITY, Color(0.2, 0.6, 0.95))


## Easter Egg 2: Disco de vinil dourado "Greatest Hits of Earth"
func _build_vinyl_record(st: SurfaceTool) -> void:
	# Pedestal de basalto alienígena
	var ped_top: Vector3 = Vector3(0.0, 0.6, 0.0)
	LowPolyMesh.prism(st, Vector3.ZERO, ped_top, 0.32, 0.26, 6, METEOR_CRUST)
	# Disco dourado de vinil/fonógrafo
	LowPolyMesh.prism(st, ped_top, ped_top + Vector3(0.0, 0.02, 0.0), 0.28, 0.28, 16, GOLD_CORE)
	# Rótulo central escuro com sulcos de reprodução
	LowPolyMesh.prism(st, ped_top + Vector3(0.0, 0.02, 0.0), ped_top + Vector3(0.0, 0.025, 0.0), 0.09, 0.09, 12, METEOR_CRUST)
