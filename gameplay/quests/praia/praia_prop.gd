@tool
extends Node3D

## Modelos low-poly toon dos objetos de missão/segredos da Praia (#40), no estilo da #36
## (facetado, contorno preto, cores quentes). Põe-se como filho "Model" de um Interactable;
## o modelo é gerado em código (SurfaceTool → ToonKit), sem ficheiros.
## Frente = -Z, base na origem.

enum Kind { FISHERMAN, SHELL_PINK, SHELL_BLUE, SHELL_GOLD, BOTTLE, GOLD_HOOK, BIG_ROCK, SAND_CASTLE, RUBBER_DUCK, CHEST }

const CrabModel := preload("res://gameplay/enemies/crab/crab_model.gd")
const NpcBody := preload("res://gameplay/quests/npc_body.gd")

const RAINCOAT: Color = Color(0.96, 0.74, 0.14)
const RAINCOAT_DARK: Color = Color(0.82, 0.56, 0.08)
const PANTS: Color = Color(0.2, 0.28, 0.45)
const SKIN: Color = Color(0.94, 0.72, 0.56)
const BEARD: Color = Color(0.92, 0.92, 0.9)
const BOOT: Color = Color(0.18, 0.16, 0.15)
const WOOD: Color = Color(0.5, 0.31, 0.17)
const WOOD_DARK: Color = Color(0.36, 0.21, 0.11)
const GOLD: Color = Color(1.0, 0.78, 0.18)
const GLASS: Color = Color(0.3, 0.68, 0.45)
const PAPER: Color = Color(0.95, 0.9, 0.74)
const CORK: Color = Color(0.7, 0.5, 0.3)
const ROCK: Color = Color(0.56, 0.56, 0.6)
const ROCK_DARK: Color = Color(0.42, 0.42, 0.47)
const SAND: Color = Color(0.93, 0.8, 0.55)
const SAND_DARK: Color = Color(0.8, 0.66, 0.42)
const DUCK: Color = Color(1.0, 0.86, 0.15)
const BEAK: Color = Color(1.0, 0.5, 0.12)
const BLACK: Color = Color(0.04, 0.04, 0.05)
const IRON: Color = Color(0.4, 0.42, 0.46)

@export var kind: Kind = Kind.SHELL_PINK:
	set(v):
		kind = v
		if is_inside_tree():
			rebuild()

static var _material: ShaderMaterial = null


var _time: float = 0.0


func _ready() -> void:
	rebuild()
	set_process(kind == Kind.RUBBER_DUCK and not Engine.is_editor_hint())


## Pato: balança na água.
func _process(delta: float) -> void:
	_time += delta
	position.y = sin(_time * 1.7) * 0.035
	rotation.z = sin(_time * 1.3) * 0.12
	rotation.x = sin(_time * 1.1 + 0.7) * 0.08


## Os filhos gerados não têm owner (o editor não os grava na cena); só esses são apagados.
func rebuild() -> void:
	for c: Node in get_children():
		if c.owner == null:
			c.free()
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		Kind.FISHERMAN:
			_fisherman(st)
		Kind.SHELL_PINK:
			_shell(st, Color(0.97, 0.56, 0.62))
		Kind.SHELL_BLUE:
			_shell(st, Color(0.42, 0.68, 0.95))
		Kind.SHELL_GOLD:
			_shell(st, Color(1.0, 0.8, 0.26))
		Kind.BOTTLE:
			_bottle(st)
		Kind.GOLD_HOOK:
			_hook(st)
		Kind.BIG_ROCK:
			_rock(st)
		Kind.SAND_CASTLE:
			_castle(st)
		Kind.RUBBER_DUCK:
			_duck(st)
		Kind.CHEST:
			_chest(st)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = ToonKit.commit(st)
	mi.material_override = NpcBody.cloth_material(0.25) if kind == Kind.FISHERMAN else _shared_material()
	add_child(mi)


static func _shared_material() -> ShaderMaterial:
	if _material == null:
		_material = ToonKit.vertex_material(true, true)
		_material.set_shader_parameter(&"spots_amount", 0.35)
		_material.set_shader_parameter(&"spots_color", Color(0.98, 0.95, 0.85))
		_material.set_shader_parameter(&"spots_scale", 18.0)
		_material.set_shader_parameter(&"spots_size", 0.12)
	return _material


## Sem desgaste (olhos, vidro, ouro): alfa 0.
static func _c(c: Color) -> Color:
	return Color(c.r, c.g, c.b, 0.0)


static func _gem(st: SurfaceTool, center: Vector3, radius: Vector3, color: Color, sides: int = 7, seed_value: int = 1, orient: Basis = Basis.IDENTITY) -> void:
	CrabModel.gem(st, Transform3D.IDENTITY, center, orient, [
		Vector3(-radius.y * 0.55, radius.x * 0.75, radius.z * 0.75),
		Vector3(0.0, radius.x, radius.z),
		Vector3(radius.y * 0.55, radius.x * 0.8, radius.z * 0.8),
	], sides, -radius.y, radius.y, color, minf(radius.x, radius.z) * 0.06, seed_value)


# ---------------------------------------------------------------------------
# Modelos
# ---------------------------------------------------------------------------

## Pescador Zé (#61, fiel a pescador_ze.jpg): sentado (no barco do mapa), oleado amarelo de
## gola escura, calças azul-escuras, botas de borracha verde-escuras, chapéu de balde
## verde-oliva, óculos de sol pretos, barba e bigode brancos fartos, cana curva com carreto e
## linha. Cara para -Z.
func _fisherman(st: SurfaceTool) -> void:
	var coat: Color = Color(0.82, 0.64, 0.22)
	var coat_dark: Color = Color(0.66, 0.48, 0.12)
	var pants: Color = Color(0.17, 0.2, 0.3)
	var boots: Color = Color(0.2, 0.28, 0.2)
	var hat: Color = Color(0.36, 0.38, 0.24)
	var hat_dark: Color = Color(0.26, 0.28, 0.17)
	var skin: Color = Color(0.85, 0.6, 0.46, 0.0)
	var beard: Color = Color(0.94, 0.93, 0.9, 0.0)
	var beard_shade: Color = Color(0.8, 0.79, 0.76, 0.0)
	var glasses: Color = Color(0.06, 0.06, 0.07, 0.0)
	var rod: Color = Color(0.42, 0.28, 0.16)
	var metal: Color = Color(0.55, 0.56, 0.58, 0.0)
	# Pernas dobradas (sentado num banco a y≈0.42) e botas de borracha
	for sx: float in [-1.0, 1.0]:
		NpcBody.limb(st, Vector3(sx * 0.12, 0.44, 0.02), Vector3(sx * 0.14, 0.42, -0.36), 0.1, 0.095, pants)
		NpcBody.limb(st, Vector3(sx * 0.14, 0.42, -0.36), Vector3(sx * 0.15, 0.16, -0.4), 0.09, 0.085, pants)
		NpcBody.boot(st, Vector3(sx * 0.15, 0.0, -0.42), boots, Color(0.1, 0.12, 0.1, 0.0), 1.05, 0.26)
	# Oleado amarelo: tronco largo e curvado para a frente, abas sobre as coxas, botões
	NpcBody.blob(st, Vector3(0.0, 0.78, 0.02), Vector3(0.27, 0.36, 0.22), coat, 8, 0.01, 3,
		Basis(Vector3.RIGHT, 0.12))
	for sx: float in [-1.0, 1.0]:
		LowPolyMesh.box(st, Vector3(sx * 0.13, 0.48, -0.16), Vector3(0.2, 0.1, 0.3), Basis(Vector3.RIGHT, 0.15), coat)
		LowPolyMesh.box(st, Vector3(sx * 0.17, 0.72, -0.2), Vector3(0.1, 0.08, 0.02), Basis.IDENTITY, coat_dark)
	for k: int in 3:
		LowPolyMesh.box(st, Vector3(0.0, 0.95 - 0.13 * float(k), -0.23), Vector3(0.03, 0.03, 0.02), Basis.IDENTITY, coat_dark)
	# Gola alta escura
	LowPolyMesh.prism(st, Vector3(0.0, 1.02, 0.0), Vector3(0.0, 1.12, 0.0), 0.2, 0.17, 8, coat_dark)
	# Braços para a frente a segurar a cana (mãos juntas no punho)
	var grip: Vector3 = Vector3(0.05, 0.78, -0.42)
	for sx: float in [-1.0, 1.0]:
		var sh: Vector3 = Vector3(0.26 * sx, 0.98, 0.0)
		var el: Vector3 = Vector3(0.3 * sx, 0.74, -0.18)
		var hd: Vector3 = grip + Vector3(sx * 0.07, sx * 0.05, 0.0)
		NpcBody.limb(st, sh, el, 0.1, 0.09, coat)
		NpcBody.limb(st, el, hd, 0.09, 0.08, coat)
		LowPolyMesh.prism(st, hd + (el - hd).normalized() * 0.06, hd, 0.085, 0.085, 6, coat_dark)
		NpcBody.hand(st, hd, 0.055, skin, sx)
	# Cabeça, nariz grande e bochechas
	var head: Vector3 = Vector3(0.0, 1.27, -0.04)
	var head_node: Node3D = Node3D.new()
	head_node.name = "NpcHead"
	head_node.position = head
	add_child(head_node)
	var mouth_node: Node3D = Node3D.new()
	mouth_node.name = "NpcMouth"
	mouth_node.position = Vector3(0.0, -0.08, -0.16)
	head_node.add_child(mouth_node)
	NpcBody.blob(st, head, Vector3(0.16, 0.17, 0.16), skin, 8)
	NpcBody.nose(st, head, 0.16, Color(0.82, 0.5, 0.4, 0.0), 1.3)
	# Óculos de sol: duas lentes pretas largas + ponte
	for sx: float in [-1.0, 1.0]:
		LowPolyMesh.box(st, head + Vector3(sx * 0.065, 0.035, -0.155), Vector3(0.1, 0.065, 0.02), Basis(Vector3.FORWARD, sx * 0.05), glasses)
		LowPolyMesh.box(st, head + Vector3(sx * 0.15, 0.04, -0.07), Vector3(0.015, 0.02, 0.16), Basis.IDENTITY, glasses)
	LowPolyMesh.box(st, head + Vector3(0.0, 0.045, -0.16), Vector3(0.04, 0.015, 0.015), Basis.IDENTITY, glasses)
	# Barba farta (bolhas brancas) e bigode por cima da boca
	NpcBody.blob(st, head + Vector3(0.0, -0.1, -0.08), Vector3(0.16, 0.12, 0.12), beard, 8, 0.01, 11)
	NpcBody.blob(st, head + Vector3(0.0, -0.2, -0.1), Vector3(0.11, 0.09, 0.09), beard_shade, 7, 0.01, 12)
	for sx: float in [-1.0, 1.0]:
		NpcBody.blob(st, head + Vector3(sx * 0.05, -0.04, -0.17), Vector3(0.06, 0.03, 0.03), beard, 6)
		NpcBody.blob(st, head + Vector3(sx * 0.15, 0.0, -0.02), Vector3(0.04, 0.07, 0.06), beard_shade, 6)
	# Chapéu de balde verde-oliva: copa + aba descaída
	LowPolyMesh.prism(st, head + Vector3(0, 0.07, 0.0), head + Vector3(0, 0.24, 0.0), 0.17, 0.14, 9, hat)
	LowPolyMesh.prism(st, head + Vector3(0, 0.05, 0.0), head + Vector3(0, 0.09, 0.0), 0.31, 0.22, 10, hat_dark)
	LowPolyMesh.prism(st, head + Vector3(0, 0.12, 0.0), head + Vector3(0, 0.15, 0.0), 0.175, 0.175, 9, hat_dark)
	# Cana curva (vergada pelo peixe): segmentos a subir e a dobrar, argolas e carreto
	var pts: Array[Vector3] = [grip + Vector3(-0.08, -0.06, 0.08)]
	var dir: Vector3 = Vector3(0.6, 0.72, -0.35).normalized()
	for k: int in 7:
		# Verga para baixo (peixe na linha): roda no plano da cana e da vertical
		dir = dir.rotated(dir.cross(Vector3.DOWN).normalized(), 0.15)
		pts.append(pts[-1] + dir * 0.24)
	for k: int in pts.size() - 1:
		var r: float = lerpf(0.028, 0.008, float(k) / float(pts.size() - 1))
		NpcBody.limb(st, pts[k], pts[k + 1], r, r * 0.85, rod, 5)
		if k >= 2:
			LowPolyMesh.box(st, pts[k + 1] + Vector3(0, -0.02, 0), Vector3(0.025, 0.03, 0.01), Basis.IDENTITY, metal)
	LowPolyMesh.prism(st, grip + Vector3(0.0, -0.08, 0.02), grip + Vector3(0.06, -0.08, 0.02), 0.05, 0.05, 8, metal)
	# Linha a cair da ponta da cana com chumbada
	var line_end: Vector3 = pts[-1] + Vector3(0.02, -0.42, -0.05)
	NpcBody.limb(st, pts[-1], line_end, 0.005, 0.005, Color(0.3, 0.3, 0.3, 0.0), 3)
	LowPolyMesh.prism(st, line_end, line_end + Vector3(0.0, -0.04, 0.0), 0.015, 0.005, 5, metal)


## Concha-vieira grande, de pé, em leque com nervuras alternadas.
func _shell(st: SurfaceTool, color: Color) -> void:
	var dark: Color = color.darkened(0.25)
	var hinge: Vector3 = Vector3(0.0, 0.06, 0.0)
	var ribs: int = 7
	for i: int in ribs:
		var a0: float = lerpf(-1.1, 1.1, float(i) / float(ribs))
		var a1: float = lerpf(-1.1, 1.1, float(i + 1) / float(ribs))
		var r: float = 0.42
		var p0: Vector3 = hinge + Vector3(sin(a0) * r, cos(a0) * r, 0.0)
		var p1: Vector3 = hinge + Vector3(sin(a1) * r, cos(a1) * r, 0.0)
		var mid: Vector3 = (p0 + p1) * 0.5 + Vector3(0.0, 0.0, -0.07)
		var inside: Vector3 = hinge + Vector3(0.0, 0.18, 0.06)
		var col: Color = color if i % 2 == 0 else dark
		LowPolyMesh.tri(st, hinge, p0, mid, inside, col)
		LowPolyMesh.tri(st, hinge, mid, p1, inside, col)
		LowPolyMesh.tri(st, hinge, p0, p1, hinge + Vector3(0.0, 0.18, -0.2), dark)
	# Orelhas da charneira e base de areia
	LowPolyMesh.box(st, hinge + Vector3(0.0, 0.0, -0.01), Vector3(0.22, 0.08, 0.06), Basis.IDENTITY, dark)
	LowPolyMesh.prism(st, Vector3(0.0, -0.04, 0.0), Vector3(0.0, 0.05, 0.0), 0.32, 0.22, 7, SAND_DARK)


## Garrafa de vidro verde deitada, com rolha e papel enrolado lá dentro.
func _bottle(st: SurfaceTool) -> void:
	var a: Vector3 = Vector3(-0.14, 0.075, 0.0)
	var b: Vector3 = Vector3(0.08, 0.075, 0.0)
	LowPolyMesh.prism(st, a, b, 0.075, 0.075, 7, _c(GLASS))
	LowPolyMesh.prism(st, b, b + Vector3(0.06, 0.0, 0.0), 0.075, 0.03, 7, _c(GLASS))
	LowPolyMesh.prism(st, b + Vector3(0.06, 0.0, 0.0), b + Vector3(0.12, 0.0, 0.0), 0.03, 0.03, 6, _c(GLASS))
	LowPolyMesh.prism(st, b + Vector3(0.12, 0.0, 0.0), b + Vector3(0.16, 0.0, 0.0), 0.034, 0.03, 6, CORK)
	LowPolyMesh.prism(st, a + Vector3(0.04, 0.0, 0.0), b - Vector3(0.02, 0.0, 0.0), 0.04, 0.04, 6, _c(PAPER))


## Anzol de ouro grande (J) com olhal, espetado na areia.
func _hook(st: SurfaceTool) -> void:
	var g: Color = _c(GOLD)
	var pts: Array[Vector3] = [
		Vector3(0.0, 0.5, 0.0), Vector3(0.0, 0.2, 0.0), Vector3(0.02, 0.1, 0.0), Vector3(0.08, 0.06, 0.0),
		Vector3(0.15, 0.09, 0.0), Vector3(0.18, 0.18, 0.0),
	]
	for i: int in pts.size() - 1:
		LowPolyMesh.prism(st, pts[i], pts[i + 1], 0.025, 0.025 if i < pts.size() - 2 else 0.0, 6, g)
	LowPolyMesh.prism(st, Vector3(0.18, 0.18, 0.0), Vector3(0.14, 0.13, 0.0), 0.03, 0.0, 4, g)
	# Olhal
	for k: int in 6:
		var a0: float = TAU * float(k) / 6.0
		var a1: float = TAU * float(k + 1) / 6.0
		LowPolyMesh.prism(st, Vector3(sin(a0) * 0.045, 0.55 + cos(a0) * 0.045, 0.0),
			Vector3(sin(a1) * 0.045, 0.55 + cos(a1) * 0.045, 0.0), 0.014, 0.014, 4, g)


## Pedra grande que se empurra (com manchas).
func _rock(st: SurfaceTool) -> void:
	_gem(st, Vector3(0.0, 0.45, 0.0), Vector3(0.8, 0.5, 0.7), ROCK, 7, 11)
	_gem(st, Vector3(0.3, 0.75, 0.15), Vector3(0.35, 0.25, 0.3), ROCK_DARK, 6, 12)


## Castelo de areia: base, 4 torres com ameias, torre central e bandeirinha.
func _castle(st: SurfaceTool) -> void:
	LowPolyMesh.box(st, Vector3(0.0, 0.12, 0.0), Vector3(0.8, 0.24, 0.8), Basis.IDENTITY, SAND)
	for cx: float in [-0.34, 0.34]:
		for cz: float in [-0.34, 0.34]:
			var c: Vector3 = Vector3(cx, 0.0, cz)
			LowPolyMesh.prism(st, c, c + Vector3(0.0, 0.48, 0.0), 0.13, 0.11, 7, SAND)
			for k: int in 4:
				var a: float = TAU * float(k) / 4.0
				LowPolyMesh.box(st, c + Vector3(cos(a) * 0.08, 0.53, sin(a) * 0.08), Vector3(0.05, 0.08, 0.05), Basis.IDENTITY, SAND_DARK)
	LowPolyMesh.prism(st, Vector3(0.0, 0.2, 0.0), Vector3(0.0, 0.7, 0.0), 0.18, 0.14, 8, SAND)
	LowPolyMesh.prism(st, Vector3(0.0, 0.7, 0.0), Vector3(0.0, 0.88, 0.0), 0.15, 0.0, 8, SAND_DARK)
	LowPolyMesh.prism(st, Vector3(0.0, 0.85, 0.0), Vector3(0.0, 1.15, 0.0), 0.01, 0.01, 4, WOOD_DARK)
	LowPolyMesh.box(st, Vector3(0.07, 1.1, 0.0), Vector3(0.13, 0.08, 0.01), Basis.IDENTITY, Color(0.85, 0.15, 0.12))
	# Porta escura
	LowPolyMesh.box(st, Vector3(0.0, 0.1, -0.4), Vector3(0.14, 0.18, 0.03), Basis.IDENTITY, SAND_DARK.darkened(0.3))


## Pato de borracha (flutua; o nó pai faz o balanço).
func _duck(st: SurfaceTool) -> void:
	_gem(st, Vector3(0.0, 0.1, 0.03), Vector3(0.17, 0.11, 0.21), _c(DUCK), 8, 21)
	_gem(st, Vector3(0.0, 0.29, -0.09), Vector3(0.1, 0.1, 0.1), _c(DUCK), 7, 22)
	LowPolyMesh.box(st, Vector3(0.0, 0.27, -0.21), Vector3(0.09, 0.04, 0.08), Basis.IDENTITY, _c(BEAK))
	for side: float in [-1.0, 1.0]:
		LowPolyMesh.box(st, Vector3(0.055 * side, 0.33, -0.17), Vector3(0.03, 0.04, 0.02), Basis.IDENTITY, _c(BLACK))
	LowPolyMesh.prism(st, Vector3(0.0, 0.14, 0.2), Vector3(0.0, 0.24, 0.28), 0.06, 0.0, 5, _c(DUCK))


## Baú de madeira com cintas de ferro (relíquia do navio).
func _chest(st: SurfaceTool) -> void:
	LowPolyMesh.box(st, Vector3(0.0, 0.2, 0.0), Vector3(0.7, 0.4, 0.45), Basis.IDENTITY, WOOD)
	LowPolyMesh.box(st, Vector3(0.0, 0.47, 0.0), Vector3(0.72, 0.14, 0.47), Basis.IDENTITY, WOOD_DARK)
	for x: float in [-0.25, 0.25]:
		LowPolyMesh.box(st, Vector3(x, 0.27, 0.0), Vector3(0.06, 0.56, 0.49), Basis.IDENTITY, IRON)
	LowPolyMesh.box(st, Vector3(0.0, 0.38, -0.24), Vector3(0.1, 0.12, 0.04), Basis.IDENTITY, _c(GOLD))
