@tool
extends Node3D

## Modelos low-poly toon dos objetos de missão/segredos do Campo (#41), no estilo da #36.
## Filho "Model" de um Interactable (ou solto). Gerados em código; os filhos gerados não têm
## owner (o editor não os grava) e o rebuild só apaga esses. Frente = -Z, base na origem.

enum Kind { LURDES, BELL, WELL, BUCKET, KEY, HAY_ROLL, LOOSE_STONE, CROP_CIRCLE, SHEEP, HAY_BALE }

const CrabModel := preload("res://gameplay/enemies/crab/crab_model.gd")

const DRESS: Color = Color(0.36, 0.5, 0.72)
const DRESS_DARK: Color = Color(0.26, 0.37, 0.56)
const APRON: Color = Color(0.95, 0.92, 0.82)
const SCARF: Color = Color(0.85, 0.25, 0.22)
const SKIN: Color = Color(0.92, 0.72, 0.58)
const HAIR: Color = Color(0.88, 0.88, 0.9)
const BLACK: Color = Color(0.04, 0.04, 0.05)
const SHOE: Color = Color(0.25, 0.17, 0.12)
const WOOD: Color = Color(0.5, 0.31, 0.17)
const WOOD_DARK: Color = Color(0.34, 0.2, 0.1)
const BRONZE: Color = Color(0.78, 0.55, 0.22)
const STONE: Color = Color(0.6, 0.58, 0.55)
const STONE_DARK: Color = Color(0.45, 0.43, 0.42)
const ROOF: Color = Color(0.6, 0.25, 0.18)
const WATER: Color = Color(0.15, 0.25, 0.35)
const GOLD: Color = Color(1.0, 0.8, 0.2)
const STRAW: Color = Color(0.93, 0.8, 0.38)
const STRAW_DARK: Color = Color(0.78, 0.63, 0.25)
const CROP_LIGHT: Color = Color(0.9, 0.82, 0.42)
const WOOL: Color = Color(0.96, 0.95, 0.9)
const SHEEP_FACE: Color = Color(0.2, 0.18, 0.18)
const IRON: Color = Color(0.4, 0.42, 0.46)

@export var kind: Kind = Kind.BELL:
	set(v):
		kind = v
		if is_inside_tree():
			rebuild()

static var _material: ShaderMaterial = null


func _ready() -> void:
	rebuild()


## Os filhos gerados não têm owner (o editor não os grava na cena); só esses são apagados.
func rebuild() -> void:
	for c: Node in get_children():
		if c.owner == null:
			c.free()
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		Kind.LURDES:
			_lurdes(st)
		Kind.BELL:
			_bell(st)
		Kind.WELL:
			_well(st)
		Kind.BUCKET:
			_bucket(st)
		Kind.KEY:
			_key(st)
		Kind.HAY_ROLL:
			_hay_roll(st)
		Kind.LOOSE_STONE:
			_loose_stone(st)
		Kind.CROP_CIRCLE:
			_crop_circle(st)
		Kind.SHEEP:
			_sheep(st)
		Kind.HAY_BALE:
			_hay_bale(st)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	# O círculo nas searas é desenhado no chão: sem contorno.
	mi.mesh = ToonKit.commit(st)
	mi.material_override = _shared_material() if kind != Kind.CROP_CIRCLE else ToonKit.vertex_material(false, true)
	if kind == Kind.CROP_CIRCLE:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


static func _shared_material() -> ShaderMaterial:
	if _material == null:
		_material = ToonKit.vertex_material(true, true)
		_material.set_shader_parameter(&"chip_amount", 0.2)
		_material.set_shader_parameter(&"chip_color", Color(0.45, 0.38, 0.3))
		_material.set_shader_parameter(&"chip_scale", 6.0)
		_material.set_shader_parameter(&"rust_amount", 0.15)
		_material.set_shader_parameter(&"rust_scale", 7.0)
	return _material


## Sem desgaste (olhos, ouro, água): alfa 0.
static func _c(c: Color) -> Color:
	return Color(c.r, c.g, c.b, 0.0)


static func _gem(st: SurfaceTool, center: Vector3, radius: Vector3, color: Color, sides: int = 7, seed_value: int = 1) -> void:
	CrabModel.gem(st, Transform3D.IDENTITY, center, Basis.IDENTITY, [
		Vector3(-radius.y * 0.55, radius.x * 0.75, radius.z * 0.75),
		Vector3(0.0, radius.x, radius.z),
		Vector3(radius.y * 0.55, radius.x * 0.8, radius.z * 0.8),
	], sides, -radius.y, radius.y, color, minf(radius.x, radius.z) * 0.06, seed_value)


# ---------------------------------------------------------------------------
# Modelos
# ---------------------------------------------------------------------------

## Dona Lurdes: velhota de vestido azul, avental, lenço vermelho na cabeça, cesta no braço.
func _lurdes(st: SurfaceTool) -> void:
	for side: float in [-1.0, 1.0]:
		LowPolyMesh.box(st, Vector3(0.09 * side, 0.05, -0.04), Vector3(0.1, 0.1, 0.18), Basis.IDENTITY, SHOE)
	# Saia larga, tronco e avental
	LowPolyMesh.prism(st, Vector3(0.0, 0.08, 0.0), Vector3(0.0, 0.75, 0.0), 0.34, 0.22, 9, DRESS)
	LowPolyMesh.prism(st, Vector3(0.0, 0.75, 0.0), Vector3(0.0, 1.18, 0.0), 0.22, 0.18, 8, DRESS_DARK)
	LowPolyMesh.box(st, Vector3(0.0, 0.5, -0.22), Vector3(0.3, 0.6, 0.04), Basis(Vector3.RIGHT, 0.12), APRON)
	# Braços: um na cintura, outro com a cesta
	LowPolyMesh.prism(st, Vector3(-0.2, 1.1, 0.0), Vector3(-0.3, 0.85, -0.05), 0.065, 0.06, 6, DRESS_DARK)
	LowPolyMesh.prism(st, Vector3(-0.3, 0.85, -0.05), Vector3(-0.18, 0.72, -0.08), 0.06, 0.05, 6, DRESS_DARK)
	LowPolyMesh.prism(st, Vector3(0.2, 1.1, 0.0), Vector3(0.28, 0.88, -0.12), 0.065, 0.06, 6, DRESS_DARK)
	_gem(st, Vector3(0.3, 0.84, -0.16), Vector3(0.05, 0.04, 0.05), SKIN, 6, 3)
	LowPolyMesh.prism(st, Vector3(0.32, 0.62, -0.2), Vector3(0.32, 0.78, -0.2), 0.16, 0.19, 8, WOOD)
	LowPolyMesh.prism(st, Vector3(0.18, 0.78, -0.2), Vector3(0.46, 0.78, -0.2), 0.012, 0.012, 4, WOOD_DARK)
	# Cabeça, nariz, olhos, óculos redondos, lenço com nó
	_gem(st, Vector3(0.0, 1.36, 0.0), Vector3(0.16, 0.17, 0.15), SKIN, 8, 5)
	LowPolyMesh.box(st, Vector3(0.0, 1.34, -0.16), Vector3(0.06, 0.07, 0.07), Basis.IDENTITY, Color(0.86, 0.58, 0.48))
	for side: float in [-1.0, 1.0]:
		LowPolyMesh.box(st, Vector3(0.06 * side, 1.4, -0.145), Vector3(0.03, 0.04, 0.02), Basis.IDENTITY, _c(BLACK))
		LowPolyMesh.prism(st, Vector3(0.06 * side, 1.4, -0.15), Vector3(0.06 * side, 1.4, -0.16), 0.045, 0.045, 7, _c(IRON))
	_gem(st, Vector3(0.0, 1.47, 0.03), Vector3(0.17, 0.12, 0.16), SCARF, 8, 6)
	LowPolyMesh.prism(st, Vector3(0.0, 1.3, 0.12), Vector3(0.0, 1.18, 0.2), 0.06, 0.02, 5, SCARF)
	LowPolyMesh.box(st, Vector3(0.0, 1.38, 0.13), Vector3(0.22, 0.1, 0.05), Basis.IDENTITY, HAIR)


## Sino da quinta: pórtico de madeira com telhadinho e sino de bronze.
func _bell(st: SurfaceTool) -> void:
	for side: float in [-1.0, 1.0]:
		LowPolyMesh.box(st, Vector3(0.6 * side, 1.1, 0.0), Vector3(0.14, 2.2, 0.14), Basis.IDENTITY, WOOD)
	LowPolyMesh.box(st, Vector3(0.0, 2.15, 0.0), Vector3(1.5, 0.14, 0.18), Basis.IDENTITY, WOOD_DARK)
	LowPolyMesh.box(st, Vector3(0.0, 2.38, -0.2), Vector3(1.7, 0.06, 0.5), Basis(Vector3.RIGHT, 0.45), ROOF)
	LowPolyMesh.box(st, Vector3(0.0, 2.38, 0.2), Vector3(1.7, 0.06, 0.5), Basis(Vector3.RIGHT, -0.45), ROOF)
	LowPolyMesh.prism(st, Vector3(0.0, 2.08, 0.0), Vector3(0.0, 1.95, 0.0), 0.05, 0.08, 6, IRON)
	LowPolyMesh.prism(st, Vector3(0.0, 1.95, 0.0), Vector3(0.0, 1.55, 0.0), 0.14, 0.3, 9, BRONZE)
	LowPolyMesh.prism(st, Vector3(0.0, 1.58, 0.0), Vector3(0.0, 1.5, 0.0), 0.31, 0.33, 9, BRONZE.darkened(0.2))
	_gem(st, Vector3(0.0, 1.47, 0.0), Vector3(0.06, 0.06, 0.06), IRON, 6, 7)
	# Corda
	LowPolyMesh.prism(st, Vector3(0.0, 1.47, 0.0), Vector3(0.1, 0.9, -0.1), 0.015, 0.015, 4, STRAW_DARK)


## Poço de pedra com telhado, sarilho e água escura lá no fundo.
func _well(st: SurfaceTool) -> void:
	for k: int in 10:
		var a0: float = TAU * float(k) / 10.0
		var c: Vector3 = Vector3(cos(a0) * 0.75, 0.38, sin(a0) * 0.75)
		LowPolyMesh.box(st, c, Vector3(0.42, 0.76, 0.26), Basis(Vector3.UP, -a0 + PI * 0.5), STONE if k % 2 == 0 else STONE_DARK)
	LowPolyMesh.prism(st, Vector3(0.0, 0.25, 0.0), Vector3(0.0, 0.3, 0.0), 0.62, 0.62, 10, _c(WATER))
	for side: float in [-1.0, 1.0]:
		LowPolyMesh.box(st, Vector3(0.78 * side, 1.15, 0.0), Vector3(0.12, 1.6, 0.12), Basis.IDENTITY, WOOD)
	LowPolyMesh.prism(st, Vector3(-0.8, 1.35, 0.0), Vector3(0.8, 1.35, 0.0), 0.06, 0.06, 6, WOOD_DARK)
	LowPolyMesh.box(st, Vector3(0.0, 2.05, -0.35), Vector3(1.9, 0.07, 0.85), Basis(Vector3.RIGHT, 0.5), ROOF)
	LowPolyMesh.box(st, Vector3(0.0, 2.05, 0.35), Vector3(1.9, 0.07, 0.85), Basis(Vector3.RIGHT, -0.5), ROOF)
	LowPolyMesh.prism(st, Vector3(0.0, 1.35, 0.0), Vector3(0.0, 0.85, 0.0), 0.012, 0.012, 4, STRAW_DARK)


## Balde de madeira com aros de ferro.
func _bucket(st: SurfaceTool) -> void:
	LowPolyMesh.prism(st, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.3, 0.0), 0.14, 0.18, 8, WOOD)
	for y: float in [0.06, 0.24]:
		LowPolyMesh.prism(st, Vector3(0.0, y, 0.0), Vector3(0.0, y + 0.03, 0.0), 0.16 + y * 0.14, 0.165 + y * 0.14, 8, IRON)
	LowPolyMesh.prism(st, Vector3(-0.18, 0.3, 0.0), Vector3(0.0, 0.45, 0.0), 0.012, 0.012, 4, IRON)
	LowPolyMesh.prism(st, Vector3(0.0, 0.45, 0.0), Vector3(0.18, 0.3, 0.0), 0.012, 0.012, 4, IRON)


## Chave antiga dourada (grande, para se ver no chão), com um laço vermelho.
func _key(st: SurfaceTool) -> void:
	var g: Color = _c(GOLD)
	LowPolyMesh.prism(st, Vector3(-0.2, 0.05, 0.0), Vector3(0.12, 0.05, 0.0), 0.025, 0.025, 5, g)
	LowPolyMesh.box(st, Vector3(-0.15, 0.05, 0.05), Vector3(0.05, 0.03, 0.08), Basis.IDENTITY, g)
	LowPolyMesh.box(st, Vector3(-0.08, 0.05, 0.04), Vector3(0.04, 0.03, 0.06), Basis.IDENTITY, g)
	for k: int in 6:
		var a0: float = TAU * float(k) / 6.0
		var a1: float = TAU * float(k + 1) / 6.0
		LowPolyMesh.prism(st, Vector3(0.18 + cos(a0) * 0.07, 0.05, sin(a0) * 0.07),
			Vector3(0.18 + cos(a1) * 0.07, 0.05, sin(a1) * 0.07), 0.02, 0.02, 4, g)
	LowPolyMesh.box(st, Vector3(0.1, 0.07, 0.0), Vector3(0.05, 0.05, 0.12), Basis.IDENTITY, SCARF)


## Fardo de palha redondo (rola), deitado com o eixo em X.
func _hay_roll(st: SurfaceTool) -> void:
	LowPolyMesh.prism(st, Vector3(-0.6, 0.7, 0.0), Vector3(0.6, 0.7, 0.0), 0.7, 0.7, 10, STRAW)
	for x: float in [-0.25, 0.25]:
		LowPolyMesh.prism(st, Vector3(x - 0.03, 0.7, 0.0), Vector3(x + 0.03, 0.7, 0.0), 0.715, 0.715, 10, STRAW_DARK)
	LowPolyMesh.prism(st, Vector3(0.6, 0.7, 0.0), Vector3(0.62, 0.7, 0.0), 0.55, 0.3, 10, STRAW_DARK)


## Fardo quadrado (para a torre de onde se vê o círculo).
func _hay_bale(st: SurfaceTool) -> void:
	LowPolyMesh.box(st, Vector3(0.0, 0.3, 0.0), Vector3(1.2, 0.6, 0.8), Basis.IDENTITY, STRAW)
	for x: float in [-0.3, 0.3]:
		LowPolyMesh.box(st, Vector3(x, 0.3, 0.0), Vector3(0.05, 0.62, 0.82), Basis.IDENTITY, STRAW_DARK)


## Pedra solta do muro em ruína (ligeiramente mais clara, com uma fresta).
func _loose_stone(st: SurfaceTool) -> void:
	LowPolyMesh.box(st, Vector3(0.0, 0.0, 0.0), Vector3(0.4, 0.26, 0.3), Basis(Vector3.UP, 0.1), STONE.lightened(0.08))
	LowPolyMesh.box(st, Vector3(0.0, 0.0, -0.16), Vector3(0.3, 0.04, 0.02), Basis.IDENTITY, _c(BLACK))


## Círculo nas searas: anéis de trigo calcado (mais claro), visto do alto. Cada vértice segue o
## relevo da lavoura (sulcos), para não ficar enterrado.
func _crop_circle(st: SurfaceTool) -> void:
	var col: Color = _c(CROP_LIGHT)
	var o: Vector3 = global_position if is_inside_tree() else position
	var rings: Array[Vector2] = [Vector2(0.0, 1.0), Vector2(2.0, 2.5), Vector2(3.6, 4.0)]
	var below: Vector3 = Vector3.DOWN * 10.0
	for r: Vector2 in rings:
		var seg: int = 28
		for k: int in seg:
			var a0: float = TAU * float(k) / float(seg)
			var a1: float = TAU * float(k + 1) / float(seg)
			var p0: Vector3 = Vector3(cos(a0), 0.0, sin(a0))
			var p1: Vector3 = Vector3(cos(a1), 0.0, sin(a1))
			if r.x <= 0.0:
				LowPolyMesh.tri(st, _on_field(o, Vector3.ZERO), _on_field(o, p0 * r.y), _on_field(o, p1 * r.y), below, col)
			else:
				LowPolyMesh.quad(st, _on_field(o, p0 * r.x), _on_field(o, p1 * r.x), _on_field(o, p1 * r.y),
					_on_field(o, p0 * r.y), below, col)
	# Três "pétalas" entre os anéis
	for k: int in 3:
		var a: float = TAU * float(k) / 3.0
		var c: Vector3 = Vector3(cos(a), 0.0, sin(a)) * 3.0
		for j: int in 10:
			var b0: float = TAU * float(j) / 10.0
			var b1: float = TAU * float(j + 1) / 10.0
			LowPolyMesh.tri(st, _on_field(o, c), _on_field(o, c + Vector3(cos(b0), 0.0, sin(b0)) * 0.5),
				_on_field(o, c + Vector3(cos(b1), 0.0, sin(b1)) * 0.5), below, col)


## Ponto local `p` assente no relevo do Campo (+5 cm), com o nó em `origin`.
static func _on_field(origin: Vector3, p: Vector3) -> Vector3:
	var h: float = FieldTerrain.height_at(origin.x + p.x, origin.z + p.z)
	return Vector3(p.x, h - origin.y + 0.05, p.z)


## Ovelha fofa (lã em bolhas facetadas, cara preta).
func _sheep(st: SurfaceTool) -> void:
	for k: int in 5:
		var off: Vector3 = Vector3((float(k % 3) - 1.0) * 0.18, 0.55 + 0.08 * floorf(float(k) / 3.0), (float(k) - 2.0) * 0.12)
		_gem(st, off, Vector3(0.24, 0.2, 0.24), WOOL, 7, 30 + k)
	_gem(st, Vector3(0.0, 0.62, -0.42), Vector3(0.13, 0.14, 0.15), SHEEP_FACE, 7, 40)
	for side: float in [-1.0, 1.0]:
		LowPolyMesh.box(st, Vector3(0.05 * side, 0.67, -0.55), Vector3(0.03, 0.03, 0.02), Basis.IDENTITY, _c(WOOL))
		LowPolyMesh.box(st, Vector3(0.15 * side, 0.68, -0.4), Vector3(0.12, 0.04, 0.06), Basis(Vector3.FORWARD, 0.4 * side), SHEEP_FACE)
		for z: float in [-0.2, 0.22]:
			LowPolyMesh.prism(st, Vector3(0.13 * side, 0.4, z), Vector3(0.13 * side, 0.0, z), 0.04, 0.035, 5, SHEEP_FACE)
