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
const NpcBody := preload("res://gameplay/quests/npc_body.gd")

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
const METAL_GRAY: Color = Color(0.45, 0.48, 0.52)
const MODULE_ORANGE: Color = Color(0.85, 0.45, 0.15)
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
	mi.material_override = NpcBody.cloth_material(0.45, Color(0.5, 0.38, 0.24)) if kind == Kind.DRA_VEGA else ToonKit.vertex_material(true, true)
	add_child(mi)


## NPC Dra. Vega (#61, fiel a dra_vega.jpg): afro enorme castanho, auscultadores laranja de
## arco escuro, bata branca suja e rasgada até aos joelhos por cima do macacão laranja com
## arnês e fivela, botas pretas de atacadores, tablet de radar verde na mão esquerda (a direita
## aponta para o ecrã), mochila-rádio cinzenta com mostrador, cabos vermelhos e antena em
## zigue-zague, crachá "DRA. VEGA". Cara para -Z (para o jogador).
func _build_dra_vega(st: SurfaceTool) -> void:
	var skin: Color = Color(0.62, 0.4, 0.27, 0.0)
	var skin_dark: Color = Color(0.5, 0.31, 0.2, 0.0)
	var hair: Color = Color(0.33, 0.2, 0.13)
	var hair_dark: Color = Color(0.22, 0.13, 0.08)
	var coat: Color = Color(0.9, 0.88, 0.82)
	var coat_shadow: Color = Color(0.78, 0.75, 0.68)
	var suit: Color = Color(0.82, 0.42, 0.16)
	var suit_dark: Color = Color(0.66, 0.32, 0.12)
	var strap: Color = Color(0.36, 0.3, 0.22)
	var boot_c: Color = Color(0.17, 0.16, 0.15)
	var metal: Color = Color(0.5, 0.5, 0.47, 0.0)
	var pack: Color = Color(0.52, 0.5, 0.42)
	var cable: Color = Color(0.7, 0.16, 0.12, 0.0)
	var screen: Color = Color(0.3, 0.85, 0.45, 0.0)
	var screen_dark: Color = Color(0.08, 0.26, 0.15, 0.0)
	# Botas de atacadores (bem pesadas)
	for sx: float in [-1.0, 1.0]:
		NpcBody.boot(st, Vector3(sx * 0.13, 0.0, 0.0), boot_c, Color(0.08, 0.08, 0.08, 0.0), 1.1, 0.24)
	# Pernas do macacão (largas, joelho dobrado) com tiras do arnês nas coxas
	for sx: float in [-1.0, 1.0]:
		NpcBody.limb(st, Vector3(sx * 0.13, 0.24, 0.0), Vector3(sx * 0.14, 0.48, -0.03), 0.1, 0.11, suit)
		NpcBody.limb(st, Vector3(sx * 0.14, 0.48, -0.03), Vector3(sx * 0.12, 0.76, 0.0), 0.11, 0.13, suit)
		LowPolyMesh.box(st, Vector3(sx * 0.13, 0.48, -0.03), Vector3(0.24, 0.05, 0.24), Basis.IDENTITY, suit_dark)
		LowPolyMesh.box(st, Vector3(sx * 0.13, 0.62, -0.01), Vector3(0.26, 0.045, 0.26), Basis(Vector3.FORWARD, sx * 0.25), strap)
	# Tronco do macacão (camisola clara no decote) e cinto com fivela
	NpcBody.blob(st, Vector3(0.0, 0.98, 0.0), Vector3(0.22, 0.27, 0.15), suit, 8)
	LowPolyMesh.box(st, Vector3(0.0, 1.13, -0.13), Vector3(0.2, 0.12, 0.03), Basis.IDENTITY, Color(0.84, 0.8, 0.72))
	LowPolyMesh.box(st, Vector3(0.0, 0.78, 0.0), Vector3(0.44, 0.07, 0.3), Basis.IDENTITY, strap)
	LowPolyMesh.box(st, Vector3(0.0, 0.78, -0.155), Vector3(0.1, 0.075, 0.02), Basis.IDENTITY, metal)
	# Bata branca aberta: dois painéis da frente até aos joelhos (bainha rasgada) + costas
	for sx: float in [-1.0, 1.0]:
		LowPolyMesh.box(st, Vector3(sx * 0.19, 0.82, -0.08), Vector3(0.13, 0.66, 0.06), Basis(Vector3.FORWARD, sx * 0.08), coat)
		LowPolyMesh.box(st, Vector3(sx * 0.25, 0.82, 0.04), Vector3(0.05, 0.66, 0.22), Basis(Vector3.FORWARD, sx * 0.1), coat_shadow)
		# Lapela e bolso
		LowPolyMesh.box(st, Vector3(sx * 0.13, 1.14, -0.15), Vector3(0.07, 0.14, 0.02), Basis(Vector3.FORWARD, -sx * 0.4), coat_shadow)
		LowPolyMesh.box(st, Vector3(sx * 0.2, 0.68, -0.115), Vector3(0.1, 0.09, 0.015), Basis.IDENTITY, coat_shadow)
		# Rasgões em bico na bainha
		for k: int in 2:
			var bx: float = sx * (0.14 + 0.08 * float(k))
			LowPolyMesh.prism(st, Vector3(bx, 0.5, -0.08), Vector3(bx + sx * 0.01, 0.42 - 0.04 * float(k), -0.08), 0.04, 0.0, 3, coat)
	LowPolyMesh.box(st, Vector3(0.0, 0.84, 0.13), Vector3(0.5, 0.7, 0.05), Basis.IDENTITY, coat)
	for k: int in 3:
		var bx: float = -0.16 + 0.16 * float(k)
		LowPolyMesh.prism(st, Vector3(bx, 0.5, 0.13), Vector3(bx + 0.02, 0.42, 0.13), 0.05, 0.0, 3, coat)
	# Ombros da bata
	NpcBody.blob(st, Vector3(0.0, 1.18, 0.0), Vector3(0.27, 0.08, 0.16), coat, 8)
	# Crachá "DRA. VEGA" ao peito (cartão + faixa escura de texto)
	LowPolyMesh.box(st, Vector3(-0.15, 1.04, -0.12), Vector3(0.09, 0.055, 0.012), Basis.IDENTITY, Color(0.95, 0.95, 0.92, 0.0))
	LowPolyMesh.box(st, Vector3(-0.15, 1.04, -0.128), Vector3(0.07, 0.015, 0.006), Basis.IDENTITY, Color(0.15, 0.15, 0.15, 0.0))
	# Braços: mangas arregaçadas, antebraços de pele; esquerda segura o tablet, direita aponta
	var tab_c: Vector3 = Vector3(0.1, 1.06, -0.38)
	var tab_b: Basis = Basis(Vector3.UP, deg_to_rad(-25.0)) * Basis(Vector3.RIGHT, deg_to_rad(-25.0))
	NpcBody.limb(st, Vector3(0.27, 1.16, 0.0), Vector3(0.3, 0.98, -0.12), 0.075, 0.07, coat)
	LowPolyMesh.prism(st, Vector3(0.3, 0.98, -0.12), Vector3(0.29, 0.97, -0.15), 0.08, 0.08, 6, coat_shadow)
	NpcBody.limb(st, Vector3(0.29, 0.97, -0.15), Vector3(0.18, 0.98, -0.34), 0.05, 0.045, skin)
	NpcBody.hand(st, Vector3(0.17, 0.98, -0.36), 0.045, skin, 1.0)
	NpcBody.limb(st, Vector3(-0.27, 1.16, 0.0), Vector3(-0.28, 1.0, -0.14), 0.075, 0.07, coat)
	LowPolyMesh.prism(st, Vector3(-0.28, 1.0, -0.14), Vector3(-0.27, 1.0, -0.17), 0.08, 0.08, 6, coat_shadow)
	NpcBody.limb(st, Vector3(-0.27, 1.0, -0.17), Vector3(-0.02, 1.05, -0.38), 0.05, 0.04, skin)
	LowPolyMesh.prism(st, Vector3(-0.02, 1.05, -0.38), Vector3(0.04, 1.04, -0.42), 0.022, 0.012, 4, skin)
	# Tablet de radar: moldura cinzenta grossa, ecrã verde com cruz, anéis e varrimento
	LowPolyMesh.box(st, tab_c, Vector3(0.32, 0.22, 0.05), tab_b, metal)
	var face_n: Vector3 = tab_b * Vector3(0, 0, -1)
	LowPolyMesh.box(st, tab_c + face_n * 0.022, Vector3(0.24, 0.16, 0.008), tab_b, screen_dark)
	for r: float in [0.055, 0.035]:
		LowPolyMesh.box(st, tab_c + face_n * 0.028, Vector3(r * 2.0, 0.008, 0.006), tab_b, screen)
		LowPolyMesh.box(st, tab_c + face_n * 0.028, Vector3(0.008, r * 2.0, 0.006), tab_b, screen)
	LowPolyMesh.box(st, tab_c + face_n * 0.03 + tab_b * Vector3(0.025, 0.02, 0), Vector3(0.06, 0.008, 0.006),
		tab_b * Basis(Vector3.FORWARD, 0.7), screen)
	# Mochila-rádio: caixa gasta, mostrador redondo, caixa lateral, cabos vermelhos
	var pc: Vector3 = Vector3(0.02, 1.02, 0.26)
	LowPolyMesh.box(st, pc, Vector3(0.36, 0.5, 0.2), Basis(Vector3.UP, 0.05), pack)
	LowPolyMesh.box(st, pc + Vector3(0.0, 0.0, 0.11), Vector3(0.26, 0.36, 0.03), Basis.IDENTITY, Color(0.42, 0.4, 0.34))
	LowPolyMesh.prism(st, pc + Vector3(0.1, 0.14, 0.12), pc + Vector3(0.1, 0.14, 0.17), 0.06, 0.055, 8, metal)
	LowPolyMesh.box(st, pc + Vector3(-0.21, -0.08, 0.02), Vector3(0.08, 0.22, 0.14), Basis.IDENTITY, Color(0.3, 0.3, 0.28))
	LowPolyMesh.box(st, pc + Vector3(0.0, -0.27, 0.0), Vector3(0.3, 0.06, 0.18), Basis.IDENTITY, strap)
	NpcBody.limb(st, pc + Vector3(0.18, 0.1, 0.05), pc + Vector3(0.22, -0.12, -0.06), 0.012, 0.012, cable, 4)
	NpcBody.limb(st, pc + Vector3(0.22, -0.12, -0.06), pc + Vector3(0.12, -0.3, -0.18), 0.012, 0.012, cable, 4)
	# Alças da mochila por cima dos ombros
	for sx: float in [-1.0, 1.0]:
		LowPolyMesh.box(st, Vector3(sx * 0.13, 1.17, -0.02), Vector3(0.06, 0.04, 0.34), Basis.IDENTITY, strap)
	# Antena em zigue-zague a sair do canto da mochila
	var pts: Array[Vector3] = [pc + Vector3(0.14, 0.25, 0.04)]
	for k: int in 5:
		pts.append(pts[-1] + Vector3(0.11 if k % 2 == 0 else -0.1, 0.1, 0.0))
	for k: int in pts.size() - 1:
		NpcBody.limb(st, pts[k], pts[k + 1], 0.02, 0.018, Color(0.55, 0.57, 0.6, 0.0), 4)
	# Pescoço, cabeça e cara (sorriso aberto)
	NpcBody.limb(st, Vector3(0.0, 1.18, 0.0), Vector3(0.0, 1.28, 0.0), 0.06, 0.06, skin)
	var head: Vector3 = Vector3(0.0, 1.4, -0.01)
	NpcBody.blob(st, head, Vector3(0.15, 0.17, 0.15), skin, 8)
	NpcBody.blob(st, head + Vector3(0, -0.1, -0.03), Vector3(0.1, 0.06, 0.1), skin, 6)
	NpcBody.nose(st, head, 0.15, skin_dark, 0.9)
	NpcBody.face(st, head, 0.15, hair_dark, 1)
	# Afro enorme: nuvem de caracóis facetados à volta e por cima (deixa a cara livre)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for k: int in 34:
		var u: float = rng.randf_range(-0.2, 1.0)  # altura (-0.2 = nuca, 1 = topo)
		var ang: float = rng.randf_range(0.0, TAU)
		var ring: float = sqrt(maxf(1.0 - u * u, 0.0))
		var dir: Vector3 = Vector3(cos(ang) * ring, u, sin(ang) * ring)
		if dir.z < -0.45 and dir.y < 0.55:
			continue  # não tapar a cara
		var c: Vector3 = head + Vector3(0, 0.1, 0.04) + dir * Vector3(0.27, 0.22, 0.24)
		NpcBody.blob(st, c, Vector3.ONE * rng.randf_range(0.075, 0.1), hair if k % 3 != 0 else hair_dark, 6, 0.012, k)
	NpcBody.blob(st, head + Vector3(0, 0.12, 0.06), Vector3(0.24, 0.2, 0.22), hair_dark, 8)
	# Auscultadores: conchas laranja grandes e arco escuro por cima do cabelo
	for sx: float in [-1.0, 1.0]:
		LowPolyMesh.prism(st, head + Vector3(sx * 0.15, -0.01, 0.0), head + Vector3(sx * 0.23, -0.01, 0.0), 0.085, 0.075, 8, HEADPHONE_ORANGE)
		LowPolyMesh.prism(st, head + Vector3(sx * 0.13, -0.01, 0.0), head + Vector3(sx * 0.16, -0.01, 0.0), 0.075, 0.075, 8, HEADPHONE_BAND)
	var arc_prev: Vector3 = head + Vector3(-0.21, 0.06, 0.0)
	for k: int in 6:
		var a: float = PI * float(k + 1) / 6.0
		var p: Vector3 = head + Vector3(-cos(a) * 0.21, 0.06 + sin(a) * 0.36, 0.0)
		NpcBody.limb(st, arc_prev, p, 0.025, 0.025, HEADPHONE_BAND, 5)
		arc_prev = p


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
