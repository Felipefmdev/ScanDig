@tool
class_name GlacierStructure
extends Node3D

## Estruturas e peças de cenário da Geleira Eterna (#43).
## Modelos procedimentais low-poly toon com colisão StaticBody3D na layer 1 (grupo spot_blockers):
##   - ICE_SPIRE: Agulhas/pináculos de gelo translúcido pontiagudo;
##   - ICE_ARCH: Arco colossal de gelo glacial;
##   - ICE_BLOCK: Blocos e rochedos de gelo facetados;
##   - SNOW_PINE: Pinheiro ártico com ramos cobertos de neve;
##   - CABIN: Cabana de madeira rústica do Velho Björn com chaminé de pedra e teto nevado;
##   - IGLOO: Iglu de blocos de neve facetados com túnel de entrada;
##   - ICE_CAVE_ARCH: Boca de gruta de gelo (gruta do Yeti).
##
## Regra (#47): os filhos gerados não têm owner (o editor nunca os grava no .tscn).

enum Kind {
	ICE_SPIRE,
	ICE_ARCH,
	ICE_BLOCK,
	SNOW_PINE,
	CABIN,
	IGLOO,
	ICE_CAVE_ARCH
}

const ICE_COLOR: Color = Color(0.55, 0.78, 0.90)
const ICE_DEEP: Color = Color(0.35, 0.60, 0.76)
const SNOW_WHITE: Color = Color(0.94, 0.96, 0.98)
const WOOD_LOG: Color = Color(0.40, 0.25, 0.15)
const WOOD_DARK: Color = Color(0.28, 0.17, 0.10)
const STONE_CHIMNEY: Color = Color(0.50, 0.52, 0.56)
const PINE_NEEDLE: Color = Color(0.16, 0.32, 0.18)

const ToolMesh = preload("res://gameplay/weapons/tool_mesh.gd")

@export var kind: Kind = Kind.ICE_SPIRE:
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
		Kind.ICE_SPIRE:
			_ice_spire(st, shapes, size.x, size.y, rng)
		Kind.ICE_ARCH:
			_ice_arch(st, shapes, size, rng)
		Kind.ICE_BLOCK:
			_ice_block(st, shapes, size, rng)
		Kind.SNOW_PINE:
			_snow_pine(st, shapes, size.y, rng)
		Kind.CABIN:
			_cabin(st, shapes)
		Kind.IGLOO:
			_igloo(st, shapes, size.x)
		Kind.ICE_CAVE_ARCH:
			_ice_cave_arch(st, shapes, size)

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
		_material.set_shader_parameter(&"chip_amount", 0.15)
		_material.set_shader_parameter(&"chip_color", Color(0.85, 0.92, 0.98))
		_material.set_shader_parameter(&"chip_scale", 4.0)
	return _material


# ---------------------------------------------------------------------------
# Construtores procedimentais de modelos
# ---------------------------------------------------------------------------

## Pináculo de gelo afunilado com facetas cristalinas
func _ice_spire(st: SurfaceTool, shapes: Array, radius: float, height: float, rng: RandomNumberGenerator) -> void:
	var base_r: float = radius * rng.randf_range(0.85, 1.2)
	var mid_y: float = height * rng.randf_range(0.4, 0.6)
	var mid_r: float = base_r * rng.randf_range(0.55, 0.75)
	var mid_c: Vector3 = Vector3(rng.randf_range(-0.1, 0.1) * radius, mid_y, rng.randf_range(-0.1, 0.1) * radius)
	var tip_c: Vector3 = Vector3(rng.randf_range(-0.15, 0.15) * radius, height, rng.randf_range(-0.15, 0.15) * radius)

	LowPolyMesh.prism(st, Vector3.ZERO, mid_c, base_r, mid_r, 6, ICE_DEEP)
	LowPolyMesh.prism(st, mid_c, tip_c, mid_r, 0.02, 5, ICE_COLOR)

	var cyl: CylinderShape3D = CylinderShape3D.new()
	cyl.height = height
	cyl.radius = base_r * 0.8
	shapes.append([cyl, Transform3D(Basis.IDENTITY, Vector3(0.0, height * 0.5, 0.0))])


## Arco maciço de gelo
func _ice_arch(st: SurfaceTool, shapes: Array, arch_size: Vector3, _rng: RandomNumberGenerator) -> void:
	var span: float = arch_size.x
	var height: float = arch_size.y
	var thick: float = arch_size.z if arch_size.z > 0.1 else 1.2
	var half_span: float = span * 0.5

	# Pilar esquerdo
	var p_left_top: Vector3 = Vector3(-half_span, height * 0.7, 0.0)
	LowPolyMesh.prism(st, Vector3(-half_span, 0.0, 0.0), p_left_top, thick * 0.55, thick * 0.45, 6, ICE_DEEP)
	# Pilar direito
	var p_right_top: Vector3 = Vector3(half_span, height * 0.7, 0.0)
	LowPolyMesh.prism(st, Vector3(half_span, 0.0, 0.0), p_right_top, thick * 0.55, thick * 0.45, 6, ICE_DEEP)
	# Arco superior central
	var arch_top: Vector3 = Vector3(0.0, height, 0.0)
	LowPolyMesh.prism(st, p_left_top, arch_top, thick * 0.45, thick * 0.40, 5, ICE_COLOR)
	LowPolyMesh.prism(st, arch_top, p_right_top, thick * 0.40, thick * 0.45, 5, ICE_COLOR)

	var left_box: BoxShape3D = BoxShape3D.new()
	left_box.size = Vector3(thick, height * 0.8, thick)
	shapes.append([left_box, Transform3D(Basis.IDENTITY, Vector3(-half_span, height * 0.4, 0.0))])

	var right_box: BoxShape3D = BoxShape3D.new()
	right_box.size = Vector3(thick, height * 0.8, thick)
	shapes.append([right_box, Transform3D(Basis.IDENTITY, Vector3(half_span, height * 0.4, 0.0))])


## Bloco facetado de gelo e rocha
func _ice_block(st: SurfaceTool, shapes: Array, block_size: Vector3, rng: RandomNumberGenerator) -> void:
	var h: float = block_size.y
	var w: float = block_size.x
	var d: float = block_size.z if block_size.z > 0.1 else w
	LowPolyMesh.box(st, Vector3.ZERO, Vector3(w, h, d), Basis.IDENTITY, ICE_COLOR)

	# Cobertura de neve no topo do bloco
	var snow_box_size: Vector3 = Vector3(w * 0.9, h * 0.25, d * 0.9)
	LowPolyMesh.box(st, Vector3(0.0, h * 0.5 + snow_box_size.y * 0.4, 0.0), snow_box_size,
		Basis(Vector3.UP, rng.randf_range(-0.1, 0.1)), SNOW_WHITE)

	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(w, h + snow_box_size.y * 0.5, d)
	shapes.append([box, Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5, 0.0))])


## Pinheiro coberto de neve
func _snow_pine(st: SurfaceTool, shapes: Array, tree_height: float, rng: RandomNumberGenerator) -> void:
	var trunk_h: float = tree_height * 0.35
	var trunk_r: float = 0.18
	LowPolyMesh.prism(st, Vector3.ZERO, Vector3(0.0, trunk_h, 0.0), trunk_r, trunk_r * 0.85, 6, WOOD_LOG)

	# 3 camadas de copa verde-escura encimadas com neve
	var tiers: int = 3
	for i: int in tiers:
		var y0: float = trunk_h * 0.8 + float(i) * (tree_height * 0.22)
		var y1: float = y0 + tree_height * 0.32
		var tier_r: float = (tree_height * 0.45) * (1.0 - float(i) * 0.25)

		# Folhagem verde escura
		LowPolyMesh.prism(st, Vector3(0.0, y0, 0.0), Vector3(0.0, y1, 0.0), tier_r, 0.02, 6, PINE_NEEDLE)
		# Capa de neve sobre a camada
		var snow_y: float = y0 + (y1 - y0) * 0.4
		LowPolyMesh.prism(st, Vector3(0.0, snow_y, 0.0), Vector3(0.0, y1 + 0.05, 0.0), tier_r * 0.88, 0.01, 6, SNOW_WHITE)

	var cyl: CylinderShape3D = CylinderShape3D.new()
	cyl.height = tree_height * 0.85
	cyl.radius = trunk_r * 2.2
	shapes.append([cyl, Transform3D(Basis.IDENTITY, Vector3(0.0, tree_height * 0.42, 0.0))])


## Cabana rústica com chaminé de pedra e teto de duas águas
func _cabin(st: SurfaceTool, shapes: Array) -> void:
	var width: float = 4.2
	var depth: float = 3.6
	var wall_h: float = 2.4
	var roof_h: float = 1.3

	# #167: hollow cabin with an actual -Z entry, not a solid box with a painted door.
	# Same footprint/roof/chimney, standard .8m player capsule fits a 1.55 x 2.10m opening.
	var wall_t: float = 0.18
	var door_w: float = 1.55
	var door_h: float = 2.10
	var front_w: float = (width - door_w) * 0.5
	for side: float in [-1.0, 1.0]:
		_cabin_wall(st, shapes, Vector3(side * (width - wall_t) * 0.5, wall_h * 0.5, 0), Vector3(wall_t, wall_h, depth), WOOD_LOG)
		_cabin_wall(st, shapes, Vector3(side * (door_w + front_w) * 0.5, wall_h * 0.5, -depth * 0.5 + wall_t * 0.5), Vector3(front_w, wall_h, wall_t), WOOD_LOG)
	_cabin_wall(st, shapes, Vector3(0, wall_h * 0.5, depth * 0.5 - wall_t * 0.5), Vector3(width, wall_h, wall_t), WOOD_LOG)
	_cabin_wall(st, shapes, Vector3(0, door_h + (wall_h - door_h) * 0.5, -depth * 0.5 + wall_t * 0.5), Vector3(door_w, wall_h - door_h, wall_t), WOOD_DARK)
	# A grounded .10m floor supplies readable interior support and a conservative threshold.
	var floor_size: Vector3 = Vector3(width - wall_t * 2, 0.10, depth - wall_t * 2)
	var floor_shape: BoxShape3D = BoxShape3D.new()
	floor_shape.size = floor_size
	shapes.append([floor_shape, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0))])
	for plank: int in range(8):
		var plank_w: float = floor_size.x / 8.0
		var plank_x: float = -floor_size.x * 0.5 + (float(plank) + 0.5) * plank_w
		LowPolyMesh.box(st, Vector3(plank_x, 0.05, 0), Vector3(plank_w - 0.012, 0.1, floor_size.z), Basis.IDENTITY, WOOD_LOG.lightened(0.08 if plank % 3 == 0 else 0.0))
	# Narrow jambs outside the clear opening, never a panel across the passage.
	for side: float in [-1.0, 1.0]:
		LowPolyMesh.box(st, Vector3(side * (door_w * 0.5 + 0.04), door_h * 0.5, -depth * 0.5 - 0.015), Vector3(0.08, door_h, 0.08), Basis.IDENTITY, WOOD_DARK)

	# Teto de duas águas inclinado com camada espessa de neve
	var roof_peak: Vector3 = Vector3(0.0, wall_h + roof_h, 0.0)
	var eave_l: Vector3 = Vector3(-width * 0.55, wall_h - 0.1, 0.0)
	var eave_r: Vector3 = Vector3(width * 0.55, wall_h - 0.1, 0.0)

	# Painéis do teto
	var roof_left_pts: PackedVector3Array = PackedVector3Array([
		roof_peak + Vector3(0.0, 0.0, depth * 0.58),
		roof_peak - Vector3(0.0, 0.0, depth * 0.58),
		eave_l - Vector3(0.0, 0.0, depth * 0.58),
		eave_l + Vector3(0.0, 0.0, depth * 0.58)
	])
	ToolMesh.slab(st, roof_left_pts, Vector3(-1.0, 1.0, 0.0).normalized(), 0.16, SNOW_WHITE)

	var roof_right_pts: PackedVector3Array = PackedVector3Array([
		roof_peak + Vector3(0.0, 0.0, depth * 0.58),
		eave_r + Vector3(0.0, 0.0, depth * 0.58),
		eave_r - Vector3(0.0, 0.0, depth * 0.58),
		roof_peak - Vector3(0.0, 0.0, depth * 0.58)
	])
	ToolMesh.slab(st, roof_right_pts, Vector3(1.0, 1.0, 0.0).normalized(), 0.16, SNOW_WHITE)

	# Chaminé de pedra lateral
	var chimney_pos: Vector3 = Vector3(-width * 0.42, (wall_h + roof_h) * 0.55, -depth * 0.25)
	var chimney_size: Vector3 = Vector3(0.7, wall_h + roof_h + 0.5, 0.7)
	LowPolyMesh.box(st, chimney_pos, chimney_size, Basis.IDENTITY, STONE_CHIMNEY)
	var chim_shape: BoxShape3D = BoxShape3D.new()
	chim_shape.size = chimney_size
	shapes.append([chim_shape, Transform3D(Basis.IDENTITY, chimney_pos)])

	# Close only the gables above wall height; the doorway/interior remain genuinely open.
	for side: float in [-1.0, 1.0]:
		var gable_z: float = side * depth * 0.5
		LowPolyMesh.tri(st, Vector3(-width * 0.5, wall_h, gable_z), Vector3(0, wall_h + roof_h, gable_z), Vector3(width * 0.5, wall_h, gable_z), Vector3(0, wall_h + roof_h * 0.3, 0), WOOD_LOG)


func _cabin_wall(st: SurfaceTool, shapes: Array, center: Vector3, dimensions: Vector3, color: Color) -> void:
	LowPolyMesh.box(st, center, dimensions, Basis.IDENTITY, color)
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = dimensions
	shapes.append([shape, Transform3D(Basis.IDENTITY, center)])


## Iglu esférico facetado de blocos de neve
func _igloo(st: SurfaceTool, shapes: Array, radius: float) -> void:
	var igloo_r: float = radius if radius > 1.0 else 2.6
	var rings: int = 4
	for r: int in rings:
		var lat0: float = (PI * 0.5) * float(r) / float(rings)
		var lat1: float = (PI * 0.5) * float(r + 1) / float(rings)
		var y0: float = sin(lat0) * igloo_r
		var y1: float = sin(lat1) * igloo_r
		var rad0: float = cos(lat0) * igloo_r
		var rad1: float = cos(lat1) * igloo_r
		var segs: int = 8
		for s: int in segs:
			var a0: float = TAU * float(s) / float(segs)
			var a1: float = TAU * float(s + 1) / float(segs)
			var v0: Vector3 = Vector3(cos(a0) * rad0, y0, sin(a0) * rad0)
			var v1: Vector3 = Vector3(cos(a1) * rad0, y0, sin(a1) * rad0)
			var v2: Vector3 = Vector3(cos(a1) * rad1, y1, sin(a1) * rad1)
			var v3: Vector3 = Vector3(cos(a0) * rad1, y1, sin(a0) * rad1)
			LowPolyMesh.quad(st, v0, v1, v2, v3, Vector3(0.0, igloo_r * 0.5, 0.0), SNOW_WHITE)

	# Túnel de entrada arqueado virado para -Z
	var tunnel_len: float = 1.4
	var tunnel_r: float = 0.8
	var tunnel_c: Vector3 = Vector3(0.0, 0.0, -igloo_r)
	LowPolyMesh.prism(st, tunnel_c, tunnel_c - Vector3(0.0, 0.0, tunnel_len), tunnel_r, tunnel_r * 0.9, 5, SNOW_WHITE)

	var dome_shape: SphereShape3D = SphereShape3D.new()
	dome_shape.radius = igloo_r * 0.95
	shapes.append([dome_shape, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.4, 0.0))])


## Boca da gruta de gelo (gruta do Yeti)
func _ice_cave_arch(st: SurfaceTool, shapes: Array, cave_size: Vector3) -> void:
	var span: float = cave_size.x if cave_size.x > 2.0 else 5.0
	var h: float = cave_size.y if cave_size.y > 2.0 else 4.2
	var depth: float = 3.0

	# Arco rochoso e de gelo azul
	var left_side: Vector3 = Vector3(-span * 0.5, 0.0, 0.0)
	var right_side: Vector3 = Vector3(span * 0.5, 0.0, 0.0)
	var apex: Vector3 = Vector3(0.0, h, 0.0)

	LowPolyMesh.prism(st, left_side, apex, 1.2, 0.9, 5, ICE_DEEP)
	LowPolyMesh.prism(st, right_side, apex, 1.2, 0.9, 5, ICE_DEEP)

	# Estalactites suspensas na arcada
	for i: int in 4:
		var x_pos: float = -span * 0.35 + float(i) * (span * 0.23)
		var start_p: Vector3 = Vector3(x_pos, h * 0.85 - float(absf(x_pos)) * 0.3, -0.2)
		var end_p: Vector3 = start_p - Vector3(0.0, 1.1 + float(i % 2) * 0.4, 0.0)
		LowPolyMesh.prism(st, start_p, end_p, 0.16, 0.01, 4, ICE_COLOR)

	var box_l: BoxShape3D = BoxShape3D.new()
	box_l.size = Vector3(1.5, h, depth)
	shapes.append([box_l, Transform3D(Basis.IDENTITY, Vector3(-span * 0.5, h * 0.5, 0.0))])

	var box_r: BoxShape3D = BoxShape3D.new()
	box_r.size = Vector3(1.5, h, depth)
	shapes.append([box_r, Transform3D(Basis.IDENTITY, Vector3(span * 0.5, h * 0.5, 0.0))])
