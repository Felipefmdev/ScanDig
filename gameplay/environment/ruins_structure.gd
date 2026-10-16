@tool
extends Node3D

## Peças do templo das Ruínas (#42), low-poly toon com contorno e desgaste (musgo/manchas),
## geradas em código com colisão própria (StaticBody na layer 1, grupo spot_blockers).
## Os filhos gerados não têm owner (o editor não os grava) e o rebuild só apaga esses.
## Base na origem, frente = -Z. `size` muda conforme o tipo (ver cada função).

enum Kind { PILLAR, BROKEN_PILLAR, WALL, ARCH, THRONE, STATUE, OBELISK, BLOCK, TORCH, STEP_BLOCK }

const CrabModel := preload("res://gameplay/enemies/crab/crab_model.gd")

const STONE: Color = Color(0.72, 0.66, 0.56)
const STONE_DARK: Color = Color(0.56, 0.51, 0.44)
const STONE_LIGHT: Color = Color(0.82, 0.77, 0.66)
const GOLD: Color = Color(0.95, 0.75, 0.25)
const JADE: Color = Color(0.25, 0.65, 0.5)
const WOOD: Color = Color(0.4, 0.26, 0.15)
const FIRE: Color = Color(1.0, 0.6, 0.15)
const RED: Color = Color(0.65, 0.18, 0.12)

@export var kind: Kind = Kind.PILLAR:
	set(v):
		kind = v
		if is_inside_tree():
			rebuild()
## Medidas: PILLAR/BROKEN_PILLAR (raio, altura, -), WALL/STEP_BLOCK/BLOCK (largura, altura, espessura),
## ARCH (vão, altura, espessura), OBELISK (base, altura, -).
@export var size: Vector3 = Vector3(0.45, 3.2, 0.0):
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
		Kind.PILLAR:
			_pillar(st, shapes, size.x, size.y, rng, false)
		Kind.BROKEN_PILLAR:
			_pillar(st, shapes, size.x, size.y, rng, true)
		Kind.WALL:
			_wall(st, shapes, size, rng)
		Kind.ARCH:
			_arch(st, shapes, size, rng)
		Kind.THRONE:
			_throne(st, shapes)
		Kind.STATUE:
			_statue(st, shapes)
		Kind.OBELISK:
			_obelisk(st, shapes, size, rng)
		Kind.BLOCK, Kind.STEP_BLOCK:
			_block(st, shapes, size, rng)
		Kind.TORCH:
			_torch(st, shapes)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = ToonKit.commit(st)
	mi.material_override = _shared_material()
	add_child(mi)
	if kind == Kind.TORCH:
		var light: OmniLight3D = OmniLight3D.new()
		light.light_color = FIRE
		light.light_energy = 1.6
		light.omni_range = 5.0
		light.position = Vector3(0.0, 1.55, 0.0)
		add_child(light)
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
		_material.set_shader_parameter(&"spots_amount", 0.5)
		_material.set_shader_parameter(&"spots_color", Color(0.4, 0.52, 0.25))
		_material.set_shader_parameter(&"spots_scale", 2.5)
		_material.set_shader_parameter(&"spots_size", 0.25)
		_material.set_shader_parameter(&"chip_amount", 0.25)
		_material.set_shader_parameter(&"chip_color", Color(0.45, 0.4, 0.34))
		_material.set_shader_parameter(&"chip_scale", 2.0)
	return _material


static func _c(c: Color) -> Color:
	return Color(c.r, c.g, c.b, 0.0)


static func _box_shape(size3: Vector3, center: Vector3) -> Array:
	var b: BoxShape3D = BoxShape3D.new()
	b.size = size3
	return [b, Transform3D(Basis.IDENTITY, center)]


# ---------------------------------------------------------------------------
# Peças
# ---------------------------------------------------------------------------

## Pilar canelado em tambores, com base e capitel; partido = tambores a menos e topo irregular.
func _pillar(st: SurfaceTool, shapes: Array, r: float, h: float, rng: RandomNumberGenerator, broken: bool) -> void:
	LowPolyMesh.box(st, Vector3(0.0, 0.15, 0.0), Vector3(r * 2.6, 0.3, r * 2.6), Basis.IDENTITY, STONE_DARK)
	var top: float = h - 0.35
	if broken:
		top = h * rng.randf_range(0.35, 0.6)
	var drums: int = maxi(int(top / 0.7), 1)
	for k: int in drums:
		var y0: float = 0.3 + (top - 0.3) * float(k) / float(drums)
		var y1: float = 0.3 + (top - 0.3) * float(k + 1) / float(drums)
		var tilt: Vector3 = Vector3(rng.randf_range(-0.03, 0.03), 0.0, rng.randf_range(-0.03, 0.03))
		LowPolyMesh.prism(st, Vector3(0.0, y0, 0.0) + tilt, Vector3(0.0, y1 - 0.02, 0.0) + tilt, r, r * 0.96, 8,
			STONE if k % 2 == 0 else STONE_LIGHT)
	if broken:
		# topo partido em bicos
		for k: int in 3:
			var a: float = TAU * float(k) / 3.0 + rng.randf()
			var b: Vector3 = Vector3(cos(a) * r * 0.5, top, sin(a) * r * 0.5)
			LowPolyMesh.prism(st, b, b + Vector3(0.0, rng.randf_range(0.15, 0.35), 0.0), r * 0.45, 0.0, 4, STONE)
	else:
		LowPolyMesh.box(st, Vector3(0.0, h - 0.2, 0.0), Vector3(r * 2.8, 0.4, r * 2.8), Basis.IDENTITY, STONE_DARK)
	shapes.append(_box_shape(Vector3(r * 2.0, top + 0.2, r * 2.0), Vector3(0.0, (top + 0.2) * 0.5, 0.0)))


## Muro de blocos (alguns a faltar no topo), largura em X.
func _wall(st: SurfaceTool, shapes: Array, s: Vector3, rng: RandomNumberGenerator) -> void:
	var rows: int = maxi(int(s.y / 0.55), 1)
	var bw: float = 1.1
	var cols: int = maxi(int(s.x / bw), 1)
	for r: int in rows:
		var off: float = 0.0 if r % 2 == 0 else bw * 0.5
		for c: int in cols:
			if r == rows - 1 and rng.randf() < 0.35:
				continue
			var x: float = -s.x * 0.5 + bw * 0.5 + bw * float(c) + off
			if x > s.x * 0.5 - bw * 0.3:
				continue
			var y: float = 0.275 + 0.55 * float(r)
			var col: Color = STONE if (r + c) % 3 != 0 else STONE_DARK
			LowPolyMesh.box(st, Vector3(x, y, rng.randf_range(-0.03, 0.03)), Vector3(bw - 0.04, 0.52, s.z),
				Basis(Vector3.UP, rng.randf_range(-0.03, 0.03)), col)
	shapes.append(_box_shape(Vector3(s.x, s.y, s.z), Vector3(0.0, s.y * 0.5, 0.0)))


## Arco: dois pilares quadrados e uma verga com aduelas.
func _arch(st: SurfaceTool, shapes: Array, s: Vector3, rng: RandomNumberGenerator) -> void:
	var half: float = s.x * 0.5
	for side: float in [-1.0, 1.0]:
		LowPolyMesh.box(st, Vector3((half + 0.35) * side, s.y * 0.5, 0.0), Vector3(0.7, s.y, s.z), Basis.IDENTITY, STONE)
		shapes.append(_box_shape(Vector3(0.7, s.y, s.z), Vector3((half + 0.35) * side, s.y * 0.5, 0.0)))
	var stones: int = 7
	for k: int in stones:
		var a0: float = PI * float(k) / float(stones)
		var a1: float = PI * float(k + 1) / float(stones)
		var am: float = (a0 + a1) * 0.5
		var c: Vector3 = Vector3(cos(am) * half, s.y + sin(am) * half * 0.7, 0.0)
		LowPolyMesh.box(st, c, Vector3(half * 0.48, 0.5, s.z), Basis(Vector3.FORWARD, -am + PI * 0.5),
			STONE_LIGHT if k == stones / 2 else STONE)
	LowPolyMesh.box(st, Vector3(0.0, s.y + half * 0.7 + 0.35, 0.0), Vector3(s.x + 1.6, 0.4, s.z + 0.1), Basis.IDENTITY, STONE_DARK)
	var _unused: float = rng.randf()


## Trono de pedra com espaldar alto e jade.
func _throne(st: SurfaceTool, shapes: Array) -> void:
	LowPolyMesh.box(st, Vector3(0.0, 0.2, 0.0), Vector3(2.4, 0.4, 1.8), Basis.IDENTITY, STONE_DARK)
	LowPolyMesh.box(st, Vector3(0.0, 0.65, 0.1), Vector3(1.4, 0.5, 1.0), Basis.IDENTITY, STONE)
	LowPolyMesh.box(st, Vector3(0.0, 1.6, 0.55), Vector3(1.4, 2.4, 0.3), Basis.IDENTITY, STONE_LIGHT)
	for side: float in [-1.0, 1.0]:
		LowPolyMesh.box(st, Vector3(0.8 * side, 0.95, 0.1), Vector3(0.25, 0.4, 1.0), Basis.IDENTITY, STONE)
		LowPolyMesh.prism(st, Vector3(0.75 * side, 2.8, 0.55), Vector3(0.75 * side, 3.3, 0.55), 0.15, 0.0, 4, _c(GOLD))
	LowPolyMesh.box(st, Vector3(0.0, 2.3, 0.38), Vector3(0.5, 0.5, 0.06), Basis(Vector3.FORWARD, PI * 0.25), _c(JADE))
	shapes.append(_box_shape(Vector3(2.4, 1.2, 1.8), Vector3(0.0, 0.6, 0.0)))
	shapes.append(_box_shape(Vector3(1.4, 3.0, 0.4), Vector3(0.0, 1.5, 0.55)))


## Estátua de guardião (decoração; o inimigo é outra cena): tronco largo, cabeça de máscara.
func _statue(st: SurfaceTool, shapes: Array) -> void:
	LowPolyMesh.box(st, Vector3(0.0, 0.3, 0.0), Vector3(1.4, 0.6, 1.4), Basis.IDENTITY, STONE_DARK)
	LowPolyMesh.prism(st, Vector3(0.0, 0.6, 0.0), Vector3(0.0, 1.9, 0.0), 0.55, 0.65, 6, STONE)
	for side: float in [-1.0, 1.0]:
		LowPolyMesh.box(st, Vector3(0.7 * side, 1.4, 0.0), Vector3(0.35, 1.0, 0.45), Basis.IDENTITY, STONE_LIGHT)
	CrabModel.gem(st, Transform3D.IDENTITY, Vector3(0.0, 2.25, 0.0), Basis.IDENTITY, [
		Vector3(-0.2, 0.32, 0.3), Vector3(0.05, 0.38, 0.36), Vector3(0.25, 0.3, 0.28)], 6, -0.35, 0.4, STONE, 0.02, 9)
	for side: float in [-1.0, 1.0]:
		LowPolyMesh.box(st, Vector3(0.13 * side, 2.3, -0.33), Vector3(0.12, 0.06, 0.05), Basis.IDENTITY, _c(JADE))
	shapes.append(_box_shape(Vector3(1.4, 2.6, 1.4), Vector3(0.0, 1.3, 0.0)))


## Obelisco com topo em pirâmide (às vezes partido ao meio).
func _obelisk(st: SurfaceTool, shapes: Array, s: Vector3, rng: RandomNumberGenerator) -> void:
	var b: float = s.x
	var h: float = s.y
	LowPolyMesh.box(st, Vector3(0.0, 0.2, 0.0), Vector3(b * 1.6, 0.4, b * 1.6), Basis.IDENTITY, STONE_DARK)
	LowPolyMesh.prism(st, Vector3(0.0, 0.4, 0.0), Vector3(0.0, h, 0.0), b * 0.7, b * 0.5, 4, STONE)
	LowPolyMesh.prism(st, Vector3(0.0, h, 0.0), Vector3(0.0, h + b * 0.6, 0.0), b * 0.5, 0.0, 4, STONE_LIGHT)
	for k: int in 3:
		LowPolyMesh.box(st, Vector3(0.0, 0.9 + 0.6 * float(k), -b * 0.6 + 0.01), Vector3(b * 0.5, 0.12, 0.05), Basis.IDENTITY, STONE_DARK)
	shapes.append(_box_shape(Vector3(b * 1.4, h, b * 1.4), Vector3(0.0, h * 0.5, 0.0)))
	var _unused: float = rng.randf()


## Bloco de pedra (caído ou degrau para escalar).
func _block(st: SurfaceTool, shapes: Array, s: Vector3, rng: RandomNumberGenerator) -> void:
	var b: Basis = Basis(Vector3.UP, rng.randf_range(-0.15, 0.15)) if kind == Kind.BLOCK else Basis.IDENTITY
	LowPolyMesh.box(st, Vector3(0.0, s.y * 0.5, 0.0), s, b, STONE if seed_value % 2 == 0 else STONE_DARK)
	LowPolyMesh.box(st, Vector3(0.0, s.y + 0.02, 0.0), Vector3(s.x * 0.8, 0.04, s.z * 0.8), b, STONE_LIGHT)
	shapes.append(_box_shape(s, Vector3(0.0, s.y * 0.5, 0.0)))


## Suporte de tocha (a chama e a luz são acesas pelo jogo nas tochas interativas).
func _torch(st: SurfaceTool, shapes: Array) -> void:
	LowPolyMesh.prism(st, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 1.3, 0.0), 0.08, 0.06, 6, WOOD)
	LowPolyMesh.prism(st, Vector3(0.0, 1.3, 0.0), Vector3(0.0, 1.45, 0.0), 0.12, 0.18, 6, STONE_DARK)
	LowPolyMesh.prism(st, Vector3(0.0, 1.42, 0.0), Vector3(0.0, 1.75, 0.0), 0.13, 0.0, 6, _c(FIRE))
	shapes.append(_box_shape(Vector3(0.25, 1.5, 0.25), Vector3(0.0, 0.75, 0.0)))
