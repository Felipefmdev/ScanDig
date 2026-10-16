@tool
class_name CraterStructure
extends Node3D

## Estruturas e peças de cenário da Cratera (#44).
## Modelos procedimentais low-poly toon com colisão StaticBody3D na layer 1 (grupo spot_blockers):
##   - CRYSTAL_SPIRE: Agulhas/cachos de cristais extraterrestres violeta e ciano brilhantes;
##   - CRATER_ARCH: Arco colossal de basalto e rocha de impacto;
##   - METEOR_BOULDER: Rocha de meteorito facetada escura com fissuras roxas (fiel a fragmento_meteorito.jpg);
##   - RESEARCH_MODULE: Módulo laboratório da estação de pesquisa da Dra. Vega com cúpula e painel solar;
##   - ANTENNA_TOWER: Torre de comunicações com antena zig-zag e prato parabólico;
##   - CRATER_PILLAR: Pilar alto de basalto columnar com marcas alienígenas (para a relíquia no topo);
##   - ALIEN_RUIN_WALL: Muro de ruína alienígena em obsidiana facetada com glifos violeta.
##
## Regra (#47): os filhos gerados não têm owner (o editor nunca os grava no .tscn).

const ToolMesh = preload("res://gameplay/weapons/tool_mesh.gd")

enum Kind {
	CRYSTAL_SPIRE,
	CRATER_ARCH,
	METEOR_BOULDER,
	RESEARCH_MODULE,
	ANTENNA_TOWER,
	CRATER_PILLAR,
	ALIEN_RUIN_WALL
}

const BASALT_ROCK: Color = Color(0.20, 0.18, 0.24)
const BASALT_DARK: Color = Color(0.14, 0.12, 0.16)
const METEOR_CRUST: Color = Color(0.22, 0.20, 0.22)
const METEOR_RUST: Color = Color(0.50, 0.32, 0.18)
const FISSURE_VIOLET: Color = Color(0.72, 0.28, 0.95)
const CRYSTAL_PURPLE: Color = Color(0.65, 0.35, 0.85)
const CRYSTAL_CYAN: Color = Color(0.25, 0.92, 0.88)
const MODULE_WHITE: Color = Color(0.85, 0.88, 0.92)
const MODULE_ORANGE: Color = Color(0.85, 0.45, 0.15)
const METAL_GRAY: Color = Color(0.45, 0.48, 0.52)
const SOLAR_BLUE: Color = Color(0.18, 0.35, 0.65)

@export var kind: Kind = Kind.CRYSTAL_SPIRE:
	set(v):
		kind = v
		if is_inside_tree():
			rebuild()

@export var size: Vector3 = Vector3(1.0, 3.5, 1.0):
	set(v):
		size = v
		if is_inside_tree():
			rebuild()

@export var seed_value: int = 1
@export var collide: bool = true

static var _material: ShaderMaterial = null


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	for c: Node in get_children():
		if c.owner == null:
			c.free()

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shapes: Array = []  # [Shape3D, Transform3D]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value

	match kind:
		Kind.CRYSTAL_SPIRE:
			_crystal_spire(st, shapes, size.x, size.y, rng)
		Kind.CRATER_ARCH:
			_crater_arch(st, shapes, size, rng)
		Kind.METEOR_BOULDER:
			_meteor_boulder(st, shapes, size, rng)
		Kind.RESEARCH_MODULE:
			_research_module(st, shapes)
		Kind.ANTENNA_TOWER:
			_antenna_tower(st, shapes, size.y)
		Kind.CRATER_PILLAR:
			_crater_pillar(st, shapes, size)
		Kind.ALIEN_RUIN_WALL:
			_alien_ruin_wall(st, shapes, size)

	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = ToonKit.commit(st)
	mi.material_override = _shared_material()
	add_child(mi)

	if collide and not shapes.is_empty():
		var body: StaticBody3D = StaticBody3D.new()
		body.name = "Body"
		body.add_to_group(&"spot_blockers")
		for s: Array in shapes:
			var cs: CollisionShape3D = CollisionShape3D.new()
			cs.shape = s[0]
			cs.transform = s[1]
			body.add_child(cs)
		add_child(body)


static func _shared_material() -> ShaderMaterial:
	if _material == null:
		_material = ToonKit.vertex_material(true, true)
		_material.set_shader_parameter(&"chip_amount", 0.12)
		_material.set_shader_parameter(&"chip_color", Color(0.8, 0.7, 0.95))
		_material.set_shader_parameter(&"chip_scale", 4.0)
	return _material


# ---------------------------------------------------------------------------
# Construtores procedimentais de modelos
# ---------------------------------------------------------------------------

## Cacho de cristais alienígenas violeta e ciano
func _crystal_spire(st: SurfaceTool, shapes: Array, radius: float, height: float, rng: RandomNumberGenerator) -> void:
	# Cristal central maior
	var tip_y: float = height * rng.randf_range(0.9, 1.1)
	var main_p0: Vector3 = Vector3(0.0, 0.0, 0.0)
	var main_p1: Vector3 = Vector3(rng.randf_range(-0.1, 0.1) * radius, tip_y * 0.75, rng.randf_range(-0.1, 0.1) * radius)
	var main_tip: Vector3 = Vector3(main_p1.x, tip_y, main_p1.z)
	LowPolyMesh.prism(st, main_p0, main_p1, radius * 0.45, radius * 0.35, 6, CRYSTAL_PURPLE)
	LowPolyMesh.prism(st, main_p1, main_tip, radius * 0.35, 0.02, 6, CRYSTAL_CYAN)

	# Cristais secundários inclinados à volta
	var count: int = rng.randi_range(3, 5)
	for i: int in count:
		var ang: float = TAU * float(i) / float(count) + rng.randf_range(-0.2, 0.2)
		var r_sub: float = radius * rng.randf_range(0.25, 0.4)
		var h_sub: float = height * rng.randf_range(0.45, 0.7)
		var b_pos: Vector3 = Vector3(cos(ang) * radius * 0.4, 0.0, sin(ang) * radius * 0.4)
		var t_pos: Vector3 = b_pos + Vector3(cos(ang) * 0.35 * radius, h_sub, sin(ang) * 0.35 * radius)
		var col: Color = CRYSTAL_CYAN if i % 2 == 0 else CRYSTAL_PURPLE
		LowPolyMesh.prism(st, b_pos, t_pos * 0.8, r_sub, r_sub * 0.7, 5, col)
		LowPolyMesh.prism(st, t_pos * 0.8, t_pos, r_sub * 0.7, 0.015, 5, CRYSTAL_CYAN)

	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = radius * 0.75
	shape.height = height
	shapes.append([shape, Transform3D(Basis.IDENTITY, Vector3(0.0, height * 0.5, 0.0))])


## Arco monumental de basalto vulcânico
func _crater_arch(st: SurfaceTool, shapes: Array, arch_size: Vector3, _rng: RandomNumberGenerator) -> void:
	var span: float = arch_size.x
	var h: float = arch_size.y
	var thick: float = arch_size.z
	var segs: int = 7

	for sx: float in [-1.0, 1.0]:
		var leg_shape: BoxShape3D = BoxShape3D.new()
		leg_shape.size = Vector3(thick * 1.3, h * 0.7, thick * 1.3)
		shapes.append([leg_shape, Transform3D(Basis.IDENTITY, Vector3(sx * (span * 0.5 - thick * 0.5), h * 0.35, 0.0))])

	var prev: Vector3 = Vector3(-span * 0.5, 0.0, 0.0)
	for i: int in range(1, segs + 1):
		var t: float = float(i) / float(segs)
		var ang: float = PI * t
		var curr: Vector3 = Vector3(-cos(ang) * span * 0.5, sin(ang) * h, 0.0)
		LowPolyMesh.prism(st, prev, curr, thick * 0.55, thick * 0.55, 6, BASALT_ROCK)
		prev = curr


## Rocha de meteorito facetada com fissuras roxas (fiel a fragmento_meteorito.jpg)
func _meteor_boulder(st: SurfaceTool, shapes: Array, b_size: Vector3, rng: RandomNumberGenerator) -> void:
	var w: float = b_size.x
	var h: float = b_size.y
	var d: float = b_size.z

	# Bloco principal de meteorito com crosta escura e facetas
	LowPolyMesh.box(st, Vector3(0.0, h * 0.5, 0.0), Vector3(w, h, d), Basis.IDENTITY, METEOR_CRUST)

	# Fissuras violetas incrustadas
	for i: int in range(3):
		var fy: float = h * (0.25 + float(i) * 0.25)
		var f_p0: Vector3 = Vector3(-w * 0.52, fy, rng.randf_range(-d * 0.3, d * 0.3))
		var f_p1: Vector3 = Vector3(w * 0.52, fy + rng.randf_range(-0.1, 0.1), rng.randf_range(-d * 0.3, d * 0.3))
		LowPolyMesh.prism(st, f_p0, f_p1, 0.035, 0.035, 4, FISSURE_VIOLET)

	# Manchas de ferrugem cósmica
	var rust_pos: Vector3 = Vector3(w * 0.35, h * 0.6, d * 0.35)
	LowPolyMesh.box(st, rust_pos, Vector3(w * 0.35, h * 0.3, d * 0.35), Basis.IDENTITY, METEOR_RUST)

	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = b_size
	shapes.append([shape, Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5, 0.0))])


## Módulo da estação de pesquisa da Dra. Vega
func _research_module(st: SurfaceTool, shapes: Array) -> void:
	var body_size: Vector3 = Vector3(3.6, 2.2, 4.2)
	# Corpo branco pressurizado com pernas de apoio
	LowPolyMesh.box(st, Vector3(0.0, 1.4, 0.0), body_size, Basis.IDENTITY, MODULE_WHITE)
	# Faixa laranja científica
	LowPolyMesh.box(st, Vector3(0.0, 1.4, 0.0), Vector3(body_size.x + 0.02, 0.45, body_size.z + 0.02), Basis.IDENTITY, MODULE_ORANGE)

	# Pernas de apoio telescópicas nos 4 cantos
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var leg_p0: Vector3 = Vector3(sx * 1.6, 0.8, sz * 1.8)
			var leg_p1: Vector3 = Vector3(sx * 1.9, 0.0, sz * 2.1)
			LowPolyMesh.prism(st, leg_p0, leg_p1, 0.08, 0.12, 6, METAL_GRAY)

	# Cúpula de observação translúcida no teto
	var dome_p0: Vector3 = Vector3(0.0, 2.5, 0.0)
	var dome_p1: Vector3 = Vector3(0.0, 3.1, 0.0)
	LowPolyMesh.prism(st, dome_p0, dome_p1, 0.9, 0.3, 8, Color(0.35, 0.75, 0.85, 0.8))

	# Painel solar no tejadilho inclinado
	var panel_c: Vector3 = Vector3(1.2, 2.7, -0.6)
	LowPolyMesh.box(st, panel_c, Vector3(1.4, 0.06, 2.0), Basis(Vector3.RIGHT, deg_to_rad(-20.0)), SOLAR_BLUE)

	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(body_size.x + 0.6, body_size.y + 1.2, body_size.z + 0.6)
	shapes.append([shape, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.7, 0.0))])


## Torre de antenas com mastro e prato parabólico
func _antenna_tower(st: SurfaceTool, shapes: Array, height: float) -> void:
	# Mastro de treliça metálica
	var mast_p0: Vector3 = Vector3(0.0, 0.0, 0.0)
	var mast_p1: Vector3 = Vector3(0.0, height, 0.0)
	LowPolyMesh.prism(st, mast_p0, mast_p1, 0.22, 0.08, 4, METAL_GRAY)

	# Prato parabólico virado para cima/sul
	var dish_c: Vector3 = Vector3(0.0, height * 0.75, 0.2)
	LowPolyMesh.prism(st, dish_c, dish_c + Vector3(0.0, 0.2, 0.3), 0.65, 0.2, 8, MODULE_WHITE)

	# Antena pontiaguda no topo
	LowPolyMesh.prism(st, mast_p1, mast_p1 + Vector3(0.0, 1.2, 0.0), 0.04, 0.005, 4, FISSURE_VIOLET)

	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = 0.5
	shape.height = height + 1.0
	shapes.append([shape, Transform3D(Basis.IDENTITY, Vector3(0.0, height * 0.5, 0.0))])


## Pilar alto de basalto com topo plano (onde repousa a relíquia com baixa gravidade)
func _crater_pillar(st: SurfaceTool, shapes: Array, p_size: Vector3) -> void:
	var r: float = p_size.x * 0.5
	var h: float = p_size.y
	# Pilar columnar hexagonal
	LowPolyMesh.prism(st, Vector3.ZERO, Vector3(0.0, h, 0.0), r, r * 0.88, 6, BASALT_ROCK)
	# Anéis decorativos esculpidos com energia violeta
	LowPolyMesh.prism(st, Vector3(0.0, h * 0.3, 0.0), Vector3(0.0, h * 0.35, 0.0), r * 1.06, r * 1.06, 6, FISSURE_VIOLET)
	LowPolyMesh.prism(st, Vector3(0.0, h * 0.7, 0.0), Vector3(0.0, h * 0.75, 0.0), r * 1.06, r * 1.06, 6, FISSURE_VIOLET)
	# Topo plano
	LowPolyMesh.prism(st, Vector3(0.0, h, 0.0), Vector3(0.0, h + 0.05, 0.0), r * 0.95, r * 0.95, 6, METEOR_RUST)

	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = r
	shape.height = h
	shapes.append([shape, Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5, 0.0))])


## Muro de ruínas alienígenas em obsidiana
func _alien_ruin_wall(st: SurfaceTool, shapes: Array, wall_size: Vector3) -> void:
	var w: float = wall_size.x
	var h: float = wall_size.y
	var thick: float = wall_size.z

	LowPolyMesh.box(st, Vector3(0.0, h * 0.5, 0.0), Vector3(w, h, thick), Basis.IDENTITY, BASALT_DARK)
	# Glifos esculpidos brilhantes
	for i: int in range(3):
		var gx: float = -w * 0.35 + float(i) * (w * 0.35)
		LowPolyMesh.box(st, Vector3(gx, h * 0.5, thick * 0.51), Vector3(0.2, 0.5, 0.02), Basis.IDENTITY, FISSURE_VIOLET)

	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = wall_size
	shapes.append([shape, Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5, 0.0))])
