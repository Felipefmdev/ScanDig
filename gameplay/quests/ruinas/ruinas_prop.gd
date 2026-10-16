@tool
class_name RuinasProp
extends Node3D

## Modelos low-poly toon dos objetos de missão e segredos das Ruínas (#42), no estilo da #36.
## Filho "Model" de um Interactable (ou solto). Gerados em código; os filhos gerados não têm
## owner (o editor não os grava) e o rebuild só apaga esses. Frente = -Z, base na origem.

enum Kind {
	INES,
	TABLET,
	PEDESTAL,
	FALSE_WALL,
	GOLD_MASK,
	SILVER_CHALICE,
	CEREMONIAL_DAGGER,
	DETECTOR_MURAL,
	SKELETON_EXPLORER,
	TORCH_ALTAR
}

const CrabModel := preload("res://gameplay/enemies/crab/crab_model.gd")
const NpcBody := preload("res://gameplay/quests/npc_body.gd")

const KHAKI: Color = Color(0.82, 0.76, 0.60)
const KHAKI_DARK: Color = Color(0.64, 0.58, 0.44)
const BROWN: Color = Color(0.42, 0.28, 0.16)
const LEATHER: Color = Color(0.32, 0.20, 0.12)
const SKIN: Color = Color(0.92, 0.72, 0.58)
const HAIR: Color = Color(0.32, 0.22, 0.16)
const GOLD: Color = Color(1.0, 0.80, 0.18)
const GOLD_DARK: Color = Color(0.78, 0.58, 0.12)
const JADE: Color = Color(0.28, 0.88, 0.58)
const SILVER: Color = Color(0.86, 0.89, 0.93)
const SILVER_DARK: Color = Color(0.62, 0.66, 0.72)
const STONE: Color = Color(0.68, 0.64, 0.56)
const STONE_DARK: Color = Color(0.50, 0.46, 0.40)
const BONE: Color = Color(0.92, 0.90, 0.82)
const BONE_DARK: Color = Color(0.72, 0.70, 0.62)
const FIRE_ORANGE: Color = Color(1.0, 0.52, 0.12)
const FIRE_YELLOW: Color = Color(1.0, 0.88, 0.22)
const MOSS: Color = Color(0.35, 0.48, 0.22)
const BLACK: Color = Color(0.04, 0.04, 0.05)
const RED_OCHRE: Color = Color(0.78, 0.26, 0.16)
const IRON: Color = Color(0.38, 0.40, 0.44)

@export var kind: Kind = Kind.INES:
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
		Kind.INES:
			_ines(st)
		Kind.TABLET:
			_tablet(st)
		Kind.PEDESTAL:
			_pedestal(st)
		Kind.FALSE_WALL:
			_false_wall(st)
		Kind.GOLD_MASK:
			_gold_mask(st)
		Kind.SILVER_CHALICE:
			_silver_chalice(st)
		Kind.CEREMONIAL_DAGGER:
			_ceremonial_dagger(st)
		Kind.DETECTOR_MURAL:
			_detector_mural(st)
		Kind.SKELETON_EXPLORER:
			_skeleton_explorer(st)
		Kind.TORCH_ALTAR:
			_torch_altar(st)

	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = ToonKit.commit(st)
	mi.material_override = NpcBody.cloth_material(0.25) if kind == Kind.INES else _shared_material()
	add_child(mi)


static func _shared_material() -> ShaderMaterial:
	if _material == null:
		_material = ToonKit.vertex_material(true, true)
		_material.set_shader_parameter(&"chip_amount", 0.22)
		_material.set_shader_parameter(&"chip_color", Color(0.42, 0.36, 0.30))
		_material.set_shader_parameter(&"chip_scale", 6.0)
		_material.set_shader_parameter(&"spots_amount", 0.18)
		_material.set_shader_parameter(&"spots_color", MOSS)
		_material.set_shader_parameter(&"spots_scale", 8.0)
	return _material


static func _c(c: Color) -> Color:
	return Color(c.r, c.g, c.b, 0.0)


# ---------------------------------------------------------------------------
# Construtores de modelos procedimentais
# ---------------------------------------------------------------------------

## Arqueóloga Inês (#61, fiel a arqueologa_ines.jpg): chapéu colonial cáqui com óculos de
## proteção na fita, cabelo castanho apanhado, lenço vermelho-tijolo ao pescoço, camisa cáqui
## de mangas arregaçadas, calças cargo verde-oliva, botas de couro castanhas, cinto com bolsas e
## cantil, bolsa de couro a tiracolo (com rolos de papel) e um pincel e um caderno nas mãos.
## Cara para -Z.
func _ines(st: SurfaceTool) -> void:
	var shirt: Color = Color(0.7, 0.62, 0.42)
	var shirt_dark: Color = Color(0.56, 0.49, 0.32)
	var pants: Color = Color(0.36, 0.38, 0.24)
	var pants_dark: Color = Color(0.28, 0.3, 0.18)
	var leather: Color = Color(0.5, 0.3, 0.16)
	var leather_dark: Color = Color(0.36, 0.2, 0.1)
	var hat: Color = Color(0.74, 0.66, 0.46)
	var hat_band: Color = Color(0.46, 0.38, 0.24)
	var scarf: Color = Color(0.68, 0.3, 0.18)
	var skin: Color = Color(0.9, 0.68, 0.54, 0.0)
	var skin_dark: Color = Color(0.78, 0.55, 0.42, 0.0)
	var hair: Color = Color(0.4, 0.26, 0.15)
	var metal: Color = Color(0.5, 0.5, 0.48, 0.0)
	var lens: Color = Color(0.45, 0.62, 0.62, 0.0)
	var paper: Color = Color(0.92, 0.88, 0.76, 0.0)
	# Botas de couro com atacadores e pernas cargo (bolsos laterais)
	for sx: float in [-1.0, 1.0]:
		NpcBody.boot(st, Vector3(sx * 0.12, 0.0, 0.0), leather, Color(0.2, 0.12, 0.07, 0.0), 1.05, 0.28)
		LowPolyMesh.prism(st, Vector3(sx * 0.12, 0.25, 0.02), Vector3(sx * 0.12, 0.3, 0.02), 0.1, 0.1, 7, leather_dark)
		NpcBody.limb(st, Vector3(sx * 0.12, 0.28, 0.02), Vector3(sx * 0.12, 0.78, 0.0), 0.085, 0.11, pants)
		LowPolyMesh.box(st, Vector3(sx * 0.21, 0.5, 0.0), Vector3(0.04, 0.12, 0.1), Basis.IDENTITY, pants_dark)
	# Cinto de couro com fivela, bolsas e cantil
	LowPolyMesh.box(st, Vector3(0.0, 0.8, 0.0), Vector3(0.36, 0.06, 0.24), Basis.IDENTITY, leather_dark)
	LowPolyMesh.box(st, Vector3(0.0, 0.8, -0.125), Vector3(0.07, 0.06, 0.02), Basis.IDENTITY, metal)
	LowPolyMesh.box(st, Vector3(-0.12, 0.74, -0.12), Vector3(0.07, 0.08, 0.05), Basis.IDENTITY, pants_dark)
	LowPolyMesh.prism(st, Vector3(-0.21, 0.66, 0.0), Vector3(-0.21, 0.8, 0.0), 0.05, 0.045, 7, pants_dark)
	# Camisa cáqui (tronco) com bolsos ao peito e botões
	NpcBody.blob(st, Vector3(0.0, 1.0, 0.0), Vector3(0.2, 0.24, 0.13), shirt, 8)
	for sx: float in [-1.0, 1.0]:
		LowPolyMesh.box(st, Vector3(sx * 0.09, 1.06, -0.12), Vector3(0.08, 0.07, 0.02), Basis.IDENTITY, shirt_dark)
	LowPolyMesh.box(st, Vector3(0.0, 0.98, -0.125), Vector3(0.015, 0.26, 0.012), Basis.IDENTITY, shirt_dark)
	# Correia a tiracolo (ombro -X -> anca +X) e bolsa de couro grande à anca +X com rolos
	LowPolyMesh.box(st, Vector3(0.0, 1.0, -0.13), Vector3(0.05, 0.5, 0.02), Basis(Vector3.FORWARD, 0.7), leather_dark)
	var bag: Vector3 = Vector3(0.27, 0.72, -0.04)
	LowPolyMesh.box(st, bag, Vector3(0.12, 0.22, 0.28), Basis(Vector3.UP, 0.15), leather)
	LowPolyMesh.box(st, bag + Vector3(0.0, 0.07, -0.02), Vector3(0.13, 0.1, 0.29), Basis(Vector3.UP, 0.15), leather_dark)
	LowPolyMesh.box(st, bag + Vector3(0.065, 0.0, -0.06), Vector3(0.015, 0.05, 0.04), Basis.IDENTITY, metal)
	for k: int in 2:
		NpcBody.limb(st, bag + Vector3(-0.02, 0.1, 0.05 + 0.06 * float(k)), bag + Vector3(-0.06, 0.32, 0.1 + 0.05 * float(k)),
			0.025, 0.025, paper, 5)
	# Braço -X: segura o caderno à frente; braço +X: o pincel
	NpcBody.limb(st, Vector3(-0.21, 1.15, 0.0), Vector3(-0.27, 0.95, -0.04), 0.065, 0.06, shirt)
	LowPolyMesh.prism(st, Vector3(-0.27, 0.95, -0.04), Vector3(-0.27, 0.93, -0.07), 0.07, 0.07, 6, shirt_dark)
	NpcBody.limb(st, Vector3(-0.27, 0.93, -0.07), Vector3(-0.22, 1.0, -0.26), 0.045, 0.04, skin)
	NpcBody.hand(st, Vector3(-0.21, 1.01, -0.28), 0.04, skin, -1.0)
	LowPolyMesh.box(st, Vector3(-0.21, 1.08, -0.3), Vector3(-0.12, 0.16, 0.03), Basis(Vector3.RIGHT, -0.3), Color(0.34, 0.26, 0.2))
	LowPolyMesh.box(st, Vector3(-0.21, 1.08, -0.318), Vector3(-0.1, 0.14, 0.008), Basis(Vector3.RIGHT, -0.3), paper)
	NpcBody.limb(st, Vector3(0.21, 1.15, 0.0), Vector3(0.27, 0.95, -0.03), 0.065, 0.06, shirt)
	LowPolyMesh.prism(st, Vector3(0.27, 0.95, -0.03), Vector3(0.27, 0.93, -0.06), 0.07, 0.07, 6, shirt_dark)
	NpcBody.limb(st, Vector3(0.27, 0.93, -0.06), Vector3(0.18, 0.92, -0.24), 0.045, 0.04, skin)
	NpcBody.hand(st, Vector3(0.17, 0.93, -0.26), 0.04, skin, 1.0)
	NpcBody.limb(st, Vector3(0.17, 0.88, -0.27), Vector3(0.15, 1.08, -0.3), 0.012, 0.012, Color(0.6, 0.4, 0.2), 4)
	LowPolyMesh.prism(st, Vector3(0.15, 1.08, -0.3), Vector3(0.145, 1.15, -0.31), 0.025, 0.03, 5, Color(0.3, 0.24, 0.18))
	# Lenço ao pescoço (nó à frente com pontas)
	LowPolyMesh.prism(st, Vector3(0.0, 1.16, 0.0), Vector3(0.0, 1.22, 0.0), 0.11, 0.09, 8, scarf)
	LowPolyMesh.prism(st, Vector3(0.0, 1.17, -0.08), Vector3(0.03, 1.06, -0.12), 0.05, 0.0, 4, scarf)
	# Cabeça, cara e cabelo (rabo de cavalo atrás)
	var head: Vector3 = Vector3(0.0, 1.36, -0.01)
	NpcBody.blob(st, head, Vector3(0.14, 0.16, 0.14), skin, 8)
	NpcBody.nose(st, head, 0.14, skin_dark, 0.8)
	NpcBody.face(st, head, 0.14, hair, 2)
	NpcBody.blob(st, head + Vector3(0, 0.04, 0.03), Vector3(0.15, 0.15, 0.14), hair, 8)
	for sx: float in [-1.0, 1.0]:
		LowPolyMesh.box(st, head + Vector3(sx * 0.13, -0.02, -0.06), Vector3(0.04, 0.16, 0.08), Basis(Vector3.FORWARD, sx * 0.1), hair)
	NpcBody.limb(st, head + Vector3(0, -0.02, 0.15), head + Vector3(0, -0.2, 0.19), 0.05, 0.025, hair, 5)
	# Chapéu colonial: copa arredondada, aba larga, fita escura e óculos de proteção na fita
	LowPolyMesh.prism(st, head + Vector3(0, 0.1, 0.0), head + Vector3(0, 0.13, 0.0), 0.3, 0.27, 12, hat)
	NpcBody.blob(st, head + Vector3(0, 0.2, 0.0), Vector3(0.16, 0.1, 0.15), hat, 9)
	LowPolyMesh.prism(st, head + Vector3(0, 0.12, 0.0), head + Vector3(0, 0.17, 0.0), 0.165, 0.16, 9, hat_band)
	for sx: float in [-1.0, 1.0]:
		LowPolyMesh.prism(st, head + Vector3(sx * 0.055, 0.16, -0.14), head + Vector3(sx * 0.055, 0.15, -0.18), 0.045, 0.04, 8, metal)
		LowPolyMesh.prism(st, head + Vector3(sx * 0.055, 0.15, -0.18), head + Vector3(sx * 0.055, 0.148, -0.185), 0.032, 0.032, 8, lens)


## Tábua com glifos: laje retangular desgastada com runas gravadas a jade e ouro.
func _tablet(st: SurfaceTool) -> void:
	LowPolyMesh.box(st, Vector3(0.0, 0.35, 0.0), Vector3(0.55, 0.7, 0.12), Basis.IDENTITY, STONE)
	LowPolyMesh.box(st, Vector3(0.0, 0.35, 0.0), Vector3(0.48, 0.62, 0.14), Basis.IDENTITY, STONE_DARK)
	# Glifos esculpidos (frente)
	LowPolyMesh.box(st, Vector3(0.0, 0.52, -0.07), Vector3(0.24, 0.04, 0.02), Basis.IDENTITY, _c(JADE))
	LowPolyMesh.box(st, Vector3(0.0, 0.44, -0.07), Vector3(0.04, 0.14, 0.02), Basis.IDENTITY, _c(GOLD))
	LowPolyMesh.box(st, Vector3(-0.08, 0.36, -0.07), Vector3(0.14, 0.04, 0.02), Basis.IDENTITY, _c(JADE))
	LowPolyMesh.box(st, Vector3(0.08, 0.36, -0.07), Vector3(0.14, 0.04, 0.02), Basis.IDENTITY, _c(JADE))
	LowPolyMesh.box(st, Vector3(0.0, 0.24, -0.07), Vector3(0.28, 0.05, 0.02), Basis.IDENTITY, _c(GOLD))
	LowPolyMesh.prism(st, Vector3(0.0, 0.14, -0.07), Vector3(0.0, 0.20, -0.07), 0.06, 0.0, 3, _c(JADE))


## Pedestal na cripta: pilar de pedra trabalhado com encaixe talhado para o Ídolo de Jade.
func _pedestal(st: SurfaceTool) -> void:
	# Base quadrada pesada
	LowPolyMesh.box(st, Vector3(0.0, 0.15, 0.0), Vector3(0.9, 0.3, 0.9), Basis.IDENTITY, STONE_DARK)
	LowPolyMesh.box(st, Vector3(0.0, 0.35, 0.0), Vector3(0.75, 0.12, 0.75), Basis.IDENTITY, STONE)
	# Coluna canelada
	LowPolyMesh.prism(st, Vector3(0.0, 0.4, 0.0), Vector3(0.0, 1.05, 0.0), 0.32, 0.30, 8, STONE)
	# Ranhuras rúnicas na coluna
	for i: int in 4:
		var ang: float = float(i) * PI * 0.5
		var off: Vector3 = Vector3(cos(ang) * 0.29, 0.72, sin(ang) * 0.29)
		LowPolyMesh.box(st, off, Vector3(0.04, 0.45, 0.04), Basis.IDENTITY, _c(JADE))
	# Capitel com encaixe talhado
	LowPolyMesh.box(st, Vector3(0.0, 1.12, 0.0), Vector3(0.8, 0.15, 0.8), Basis.IDENTITY, STONE_DARK)
	LowPolyMesh.box(st, Vector3(0.0, 1.22, 0.0), Vector3(0.85, 0.08, 0.85), Basis.IDENTITY, STONE)
	# Encaixe no centro (reentrância)
	LowPolyMesh.box(st, Vector3(0.0, 1.25, 0.0), Vector3(0.35, 0.04, 0.35), Basis.IDENTITY, _c(GOLD))


## Parede falsa: bloco de alvenaria antiga com fendas evidentes para arrombar com a pá.
func _false_wall(st: SurfaceTool) -> void:
	LowPolyMesh.box(st, Vector3(0.0, 1.1, 0.0), Vector3(2.4, 2.2, 0.55), Basis.IDENTITY, STONE)
	# Tijolos desalinhados e rachaduras
	LowPolyMesh.box(st, Vector3(-0.4, 1.4, -0.03), Vector3(0.7, 0.35, 0.58), Basis.IDENTITY, STONE_DARK)
	LowPolyMesh.box(st, Vector3(0.5, 0.8, -0.02), Vector3(0.65, 0.32, 0.58), Basis.IDENTITY, STONE_DARK)
	LowPolyMesh.box(st, Vector3(-0.2, 0.5, 0.02), Vector3(0.6, 0.3, 0.58), Basis.IDENTITY, STONE_DARK)
	# Fenda profunda diagonal
	LowPolyMesh.box(st, Vector3(0.0, 1.1, -0.28), Vector3(0.06, 1.4, 0.08), Basis(Vector3.FORWARD, 0.35), _c(BLACK))
	LowPolyMesh.box(st, Vector3(0.2, 1.0, -0.28), Vector3(0.05, 0.8, 0.08), Basis(Vector3.FORWARD, -0.4), _c(BLACK))
	# Manchas de musgo nas juntas
	LowPolyMesh.box(st, Vector3(-0.7, 0.3, -0.28), Vector3(0.4, 0.25, 0.04), Basis.IDENTITY, MOSS)
	LowPolyMesh.box(st, Vector3(0.6, 1.7, -0.28), Vector3(0.35, 0.2, 0.04), Basis.IDENTITY, MOSS)


## Máscara de ouro: tesouro régio funerário com olhos de pedra e pedraria de jade.
func _gold_mask(st: SurfaceTool) -> void:
	# Rosto dourado facetado
	LowPolyMesh.prism(st, Vector3(0.0, 0.05, 0.0), Vector3(0.0, 0.45, 0.0), 0.2, 0.26, 7, _c(GOLD))
	LowPolyMesh.box(st, Vector3(0.0, 0.24, -0.15), Vector3(0.05, 0.12, 0.08), Basis.IDENTITY, _c(GOLD_DARK))
	LowPolyMesh.box(st, Vector3(0.0, 0.12, -0.14), Vector3(0.12, 0.04, 0.04), Basis.IDENTITY, _c(GOLD_DARK))
	# Olhos esculpidos
	for side: float in [-1.0, 1.0]:
		LowPolyMesh.box(st, Vector3(0.09 * side, 0.26, -0.16), Vector3(0.06, 0.035, 0.03), Basis.IDENTITY, _c(BLACK))
		LowPolyMesh.box(st, Vector3(0.09 * side, 0.26, -0.17), Vector3(0.025, 0.02, 0.02), Basis.IDENTITY, _c(SILVER))
	# Adorno régio na fronte (pedra de jade)
	LowPolyMesh.prism(st, Vector3(0.0, 0.42, 0.0), Vector3(0.0, 0.58, 0.0), 0.28, 0.24, 7, _c(GOLD_DARK))
	LowPolyMesh.box(st, Vector3(0.0, 0.45, -0.18), Vector3(0.07, 0.09, 0.05), Basis.IDENTITY, _c(JADE))


## Cálice de prata: taça cerimonial brilhante em liga argêntea.
func _silver_chalice(st: SurfaceTool) -> void:
	# Pé largo
	LowPolyMesh.prism(st, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.06, 0.0), 0.18, 0.15, 8, _c(SILVER_DARK))
	# Haste estreita com anel decorativo
	LowPolyMesh.prism(st, Vector3(0.0, 0.06, 0.0), Vector3(0.0, 0.28, 0.0), 0.045, 0.05, 7, _c(SILVER))
	LowPolyMesh.prism(st, Vector3(0.0, 0.16, 0.0), Vector3(0.0, 0.19, 0.0), 0.08, 0.08, 8, _c(SILVER_DARK))
	# Copa aberta
	LowPolyMesh.prism(st, Vector3(0.0, 0.28, 0.0), Vector3(0.0, 0.54, 0.0), 0.06, 0.22, 9, _c(SILVER))
	LowPolyMesh.prism(st, Vector3(0.0, 0.52, 0.0), Vector3(0.0, 0.55, 0.0), 0.23, 0.23, 9, _c(GOLD))


## Adaga cerimonial: lâmina sinuosa com guarda de ouro e cabo incrustado.
func _ceremonial_dagger(st: SurfaceTool) -> void:
	# Pomo e cabo
	LowPolyMesh.box(st, Vector3(0.0, 0.04, 0.0), Vector3(0.08, 0.08, 0.08), Basis.IDENTITY, _c(GOLD))
	LowPolyMesh.box(st, Vector3(0.0, 0.04, 0.0), Vector3(0.05, 0.05, 0.09), Basis.IDENTITY, _c(JADE))
	LowPolyMesh.prism(st, Vector3(0.0, 0.08, 0.0), Vector3(0.0, 0.26, 0.0), 0.04, 0.045, 6, LEATHER)
	# Guarda recurvada
	LowPolyMesh.box(st, Vector3(0.0, 0.28, 0.0), Vector3(0.3, 0.04, 0.07), Basis.IDENTITY, _c(GOLD_DARK))
	for side: float in [-1.0, 1.0]:
		LowPolyMesh.prism(st, Vector3(0.14 * side, 0.28, 0.0), Vector3(0.18 * side, 0.33, 0.0), 0.03, 0.01, 4, _c(GOLD))
	# Lâmina sinuosa pontiaguda
	LowPolyMesh.box(st, Vector3(0.0, 0.42, 0.0), Vector3(0.07, 0.24, 0.02), Basis.IDENTITY, _c(SILVER))
	LowPolyMesh.prism(st, Vector3(0.0, 0.54, 0.0), Vector3(0.0, 0.72, 0.0), 0.045, 0.0, 3, _c(SILVER))


## Pintura rupestre do detetor: gravura na pedra com caçadores e um detetor de metais.
func _detector_mural(st: SurfaceTool) -> void:
	# Placa de parede rochosa
	LowPolyMesh.box(st, Vector3(0.0, 1.1, 0.0), Vector3(2.0, 1.8, 0.16), Basis.IDENTITY, STONE_DARK)
	# Pinturas a ocre vermelho
	# Figura humana (palito primitivo)
	LowPolyMesh.prism(st, Vector3(-0.35, 1.45, -0.09), Vector3(-0.35, 1.55, -0.09), 0.06, 0.06, 6, _c(RED_OCHRE))
	LowPolyMesh.box(st, Vector3(-0.35, 1.25, -0.09), Vector3(0.04, 0.32, 0.02), Basis.IDENTITY, _c(RED_OCHRE))
	LowPolyMesh.box(st, Vector3(-0.42, 0.98, -0.09), Vector3(0.04, 0.24, 0.02), Basis(Vector3.FORWARD, 0.25), _c(RED_OCHRE))
	LowPolyMesh.box(st, Vector3(-0.28, 0.98, -0.09), Vector3(0.04, 0.24, 0.02), Basis(Vector3.FORWARD, -0.25), _c(RED_OCHRE))
	# Braço estendido segurando haste do detetor!
	LowPolyMesh.box(st, Vector3(-0.2, 1.28, -0.09), Vector3(0.26, 0.035, 0.02), Basis(Vector3.FORWARD, -0.2), _c(RED_OCHRE))
	# Haste do detetor inclinada até ao chão
	LowPolyMesh.box(st, Vector3(0.05, 1.05, -0.09), Vector3(0.03, 0.55, 0.02), Basis(Vector3.FORWARD, -0.55), _c(RED_OCHRE))
	# Prato / bobina circular no chão
	LowPolyMesh.prism(st, Vector3(0.25, 0.82, -0.09), Vector3(0.25, 0.85, -0.09), 0.11, 0.11, 8, _c(RED_OCHRE))
	# Ondas concêntricas no subsolo indicando sinal de metal!
	LowPolyMesh.box(st, Vector3(0.25, 0.68, -0.09), Vector3(0.18, 0.03, 0.02), Basis.IDENTITY, _c(RED_OCHRE))
	LowPolyMesh.box(st, Vector3(0.25, 0.58, -0.09), Vector3(0.12, 0.03, 0.02), Basis.IDENTITY, _c(RED_OCHRE))
	# Pequeno tesouro subterrâneo
	LowPolyMesh.box(st, Vector3(0.25, 0.48, -0.09), Vector3(0.07, 0.07, 0.02), Basis.IDENTITY, _c(GOLD))


## Esqueleto de explorador com chapéu de safari apoiado na pedra.
func _skeleton_explorer(st: SurfaceTool) -> void:
	# Costelas e coluna
	LowPolyMesh.prism(st, Vector3(0.0, 0.2, 0.0), Vector3(0.0, 0.68, 0.0), 0.12, 0.18, 6, BONE)
	for k: int in 4:
		LowPolyMesh.box(st, Vector3(0.0, 0.32 + float(k) * 0.09, 0.0), Vector3(0.32, 0.03, 0.18), Basis.IDENTITY, BONE_DARK)
	# Bacia e pernas caídas
	LowPolyMesh.box(st, Vector3(0.0, 0.18, 0.0), Vector3(0.28, 0.1, 0.16), Basis.IDENTITY, BONE_DARK)
	for side: float in [-1.0, 1.0]:
		LowPolyMesh.prism(st, Vector3(0.12 * side, 0.16, 0.0), Vector3(0.18 * side, 0.08, 0.35), 0.04, 0.035, 5, BONE)
		LowPolyMesh.prism(st, Vector3(0.18 * side, 0.08, 0.35), Vector3(0.16 * side, 0.04, 0.65), 0.035, 0.03, 5, BONE)
		# Braços caídos
		LowPolyMesh.prism(st, Vector3(0.2 * side, 0.62, 0.0), Vector3(0.24 * side, 0.32, 0.12), 0.035, 0.03, 5, BONE)
	# Crânio
	LowPolyMesh.box(st, Vector3(0.0, 0.82, 0.0), Vector3(0.2, 0.22, 0.22), Basis.IDENTITY, BONE)
	# Órbitas oculares vazias
	for side: float in [-1.0, 1.0]:
		LowPolyMesh.box(st, Vector3(0.055 * side, 0.82, -0.11), Vector3(0.045, 0.05, 0.02), Basis.IDENTITY, _c(BLACK))
	# Chapéu de explorador colonial (pith helmet) desgastado, ligeiramente de lado
	var hat_basis: Basis = Basis(Vector3.FORWARD, 0.18) * Basis(Vector3.RIGHT, -0.1)
	LowPolyMesh.box(st, Vector3(0.02, 0.96, 0.0), Vector3(0.38, 0.03, 0.42), hat_basis, KHAKI_DARK)
	LowPolyMesh.prism(st, Vector3(0.02, 0.96, 0.0), Vector3(0.02, 1.08, 0.0), 0.18, 0.12, 8, KHAKI)
	LowPolyMesh.prism(st, Vector3(0.02, 0.97, 0.0), Vector3(0.02, 0.99, 0.0), 0.185, 0.185, 8, LEATHER)


## Altar com tochas acesas: mesa de rituais com chamas low-poly.
func _torch_altar(st: SurfaceTool) -> void:
	# Mesa do altar
	LowPolyMesh.box(st, Vector3(0.0, 0.25, 0.0), Vector3(1.6, 0.5, 0.9), Basis.IDENTITY, STONE_DARK)
	LowPolyMesh.box(st, Vector3(0.0, 0.55, 0.0), Vector3(1.7, 0.12, 1.0), Basis.IDENTITY, STONE)
	# Tocheiros nas pontas
	for side: float in [-1.0, 1.0]:
		LowPolyMesh.prism(st, Vector3(0.68 * side, 0.6, 0.0), Vector3(0.68 * side, 1.15, 0.0), 0.08, 0.06, 6, IRON)
		LowPolyMesh.prism(st, Vector3(0.68 * side, 1.15, 0.0), Vector3(0.68 * side, 1.3, 0.0), 0.15, 0.18, 7, _c(GOLD_DARK))
		# Chamas estilizadas
		LowPolyMesh.prism(st, Vector3(0.68 * side, 1.28, 0.0), Vector3(0.68 * side, 1.58, 0.0), 0.12, 0.0, 5, _c(FIRE_ORANGE))
		LowPolyMesh.prism(st, Vector3(0.68 * side, 1.32, 0.0), Vector3(0.68 * side, 1.52, 0.0), 0.08, 0.0, 4, _c(FIRE_YELLOW))
