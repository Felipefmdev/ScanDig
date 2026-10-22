extends RefCounted
## #161. Cosmetic interior work areas, positions already approved.
## One surface, world-space coordinates, no nodes/materials/collision/gameplay state.
## Caller supplies an sRGB vertex-color material and disables shadows.
## References: arqueologa_ines.jpg, velho_bjorn.jpg, dra_vega.jpg; existing
## ruins_structure/glacier_structure/crater_structure box/prism construction grammar.

const TERRAIN: Dictionary = {
	"ruinas": preload("res://gameplay/environment/ruins_terrain.gd"),
	"geleira": preload("res://gameplay/environment/glacier_terrain.gd"),
	"cratera": preload("res://gameplay/environment/crater_terrain.gd"),
}
const GEO: Script = preload("res://gameplay/enemies/lowpoly_mesh.gd")
const WOOD: Color = Color("#896343")
const WOOD_DARK: Color = Color("#5d4230")
const END_GRAIN: Color = Color("#b09063")
const IRON: Color = Color("#788286")
const LEATHER: Color = Color("#76523b")
const CANVAS: Color = Color("#aaa181")
const PAPER: Color = Color("#d8cba8")
const STONE: Color = Color("#b0a084")
const MOSS: Color = Color("#616a40")
const SNOW: Color = Color("#e1e9ed")
const MODULE: Color = Color("#d2d9df")
const ORANGE: Color = Color("#c67b48")
const PANEL: Color = Color("#424d57")
const PANEL_INSET: Color = Color("#596b75")


static func build(theme: String) -> Mesh:
	if not TERRAIN.has(theme):
		return null
	var raw: SurfaceTool = SurfaceTool.new()
	raw.begin(Mesh.PRIMITIVE_TRIANGLES)
	match theme:
		"ruinas":
			_ruins(raw)
		"geleira":
			_glacier(raw)
		"cratera":
			_crater(raw)
	return _bake(raw, theme)


static func _ruins(st: SurfaceTool) -> void:
	var study: Vector3 = Vector3(8.2, 0, -2.5)
	var angle: float = -18.0
	# Broad plank bench and independent terrain-bearing legs. No symbols or rewards.
	for x: float in [-0.71, 0.71]:
		for z: float in [-0.26, 0.26]:
			_box(st, study, angle, Vector3(x, 0.34, z), Vector3(0.12, 0.76, 0.12), WOOD_DARK)
		_box(st, study, angle, Vector3(x, 0.15, 0), Vector3(0.16, 0.13, 0.74), WOOD)
	_box(st, study, angle, Vector3(0, 0.29, 0), Vector3(1.55, 0.12, 0.11), WOOD_DARK)
	for z: float in [-0.27, 0.0, 0.27]:
		_box(st, study, angle, Vector3(0, 0.78, z), Vector3(1.9, 0.12, 0.255), WOOD)
	# The blank notebook and leather equipment follow Ines's reference accessories.
	_box(st, study, angle + 9, Vector3(-0.25, 0.855, -0.03), Vector3(0.43, 0.035, 0.32), LEATHER)
	_box(st, study, angle + 9, Vector3(-0.25, 0.88, -0.03), Vector3(0.36, 0.016, 0.27), PAPER)
	_beam(st, study, angle, Vector3(0.37, 0.86, -0.12), Vector3(0.65, 0.86, 0.1), 0.022, WOOD_DARK)
	_box(st, study, angle, Vector3(0.65, 0.875, 0.1), Vector3(0.1, 0.025, 0.09), CANVAS)
	_bag(st, study, angle + 12, Vector3(-0.85, 0, 0.74), Vector3(0.44, 0.38, 0.32))
	# Lower, subdued surveyed stones, away from the crypt and tablet.
	var remains: Vector3 = Vector3(-18, 0, 10.5)
	_stone(st, remains + Vector3(-0.48, 0, -0.14), 0.38, 0.33, 13, STONE)
	_stone(st, remains + Vector3(0.25, 0, 0.18), 0.29, 0.43, -24, STONE.darkened(0.1))
	_stone(st, remains + Vector3(0.67, 0, -0.36), 0.22, 0.25, 42, STONE.lightened(0.05))
	_box(st, remains, 17, Vector3(-0.15, 0.025, 0.73), Vector3(1.35, 0.09, 0.15), WOOD_DARK)
	_box(st, remains, -13, Vector3(-0.55, 0.15, -0.22), Vector3(0.31, 0.09, 0.22), MOSS)
	_beam(st, remains, 0, Vector3(-0.9, -0.04, -0.55), Vector3(-0.72, 0.34, -0.5), 0.045, MOSS)


static func _glacier(st: SurfaceTool) -> void:
	var cabin: Vector3 = Vector3(-14, 0, 8)
	var yaw: float = 30.0
	# Side rack: local x=-2.65, z=.3. Outside chimney x>=-2.114 and clear of -Z door.
	# Roof stops at x=-2.20; no new doorway or traversable platform.
	for z: float in [-0.92, 1.52]:
		for x: float in [-3.0, -2.3]:
			_box(st, cabin, yaw, Vector3(x, 0.65, z), Vector3(0.1, 1.4, 0.1), WOOD_DARK)
		_box(st, cabin, yaw, Vector3(-2.65, 0.17, z), Vector3(0.84, 0.13, 0.14), WOOD)
	_box(st, cabin, yaw, Vector3(-2.65, 0.22, 0.3), Vector3(0.84, 0.12, 2.62), WOOD_DARK)
	# Unequal lengths and staggered ends give the stacked logs a used silhouette.
	for row: int in range(3):
		for column: int in range(2):
			var x: float = -2.84 + float(column) * 0.34 + float(row % 2) * 0.035
			var y: float = 0.39 + float(row) * 0.27
			var start: float = -0.81 + float((row + column) % 3) * 0.09
			var end: float = 1.35 - float((row * 2 + column) % 3) * 0.11
			_beam(st, cabin, yaw, Vector3(x, y, start), Vector3(x, y, end), 0.155, WOOD)
			_beam(st, cabin, yaw, Vector3(x, y, start - 0.012), Vector3(x, y, start + 0.015), 0.13, END_GRAIN)
	_beam(st, cabin, yaw, Vector3(-3.0, 0.22, -0.83), Vector3(-3.0, 1.31, 1.45), 0.045, WOOD_DARK)
	_box(st, cabin, yaw, Vector3(-2.65, 1.38, 0.3), Vector3(0.9, 0.1, 2.8), WOOD)
	_box(st, cabin, yaw, Vector3(-2.66, 1.445, 0.4), Vector3(0.72, 0.055, 2.35), SNOW)
	# Provision bag and closed timber container on the landward side, not lake markers.
	var supplies: Vector3 = Vector3(-19.5, 0, 8)
	_closed_case(st, supplies, -23, Vector3(-0.15, 0, 0.03), Vector3(0.9, 0.55, 0.58), WOOD, WOOD_DARK)
	_bag(st, supplies, 13, Vector3(0.49, 0, -0.27), Vector3(0.33, 0.43, 0.36))
	_box(st, supplies, -23, Vector3(-0.15, 0.59, 0.03), Vector3(0.68, 0.055, 0.42), CANVAS)
	_box(st, supplies, -23, Vector3(-0.15, 0.63, 0.03), Vector3(0.12, 0.03, 0.44), LEATHER)


static func _crater(st: SurfaceTool) -> void:
	var module: Vector3 = Vector3(-14, 0, 10)
	var yaw: float = 15.0
	# Recessed-looking, opaque service panel against existing west wall, no screen glow.
	# Wall is x=-1.80; maximum new protrusion .09m inside existing collider envelope.
	_box(st, module, yaw, Vector3(-1.835, 1.28, 0.2), Vector3(0.07, 1.22, 1.52), IRON)
	_box(st, module, yaw, Vector3(-1.878, 1.28, 0.2), Vector3(0.016, 1.04, 1.34), PANEL)
	_box(st, module, yaw, Vector3(-1.89, 1.34, 0.48), Vector3(0.012, 0.77, 0.52), PANEL_INSET)
	for y: float in [1.0, 1.16, 1.32, 1.48]:
		_box(st, module, yaw, Vector3(-1.89, y, -0.23), Vector3(0.012, 0.045, 0.36), IRON)
	# Narrow frame joints give the wall a maintained equipment identity, not another door.
	_box(st, module, yaw, Vector3(-1.825, 1.3, 1.28), Vector3(0.035, 1.9, 0.065), MODULE.darkened(0.14))
	_box(st, module, yaw, Vector3(-1.825, 1.3, -1.12), Vector3(0.035, 1.9, 0.065), MODULE.darkened(0.14))
	# Asymmetric maintenance cases adjacent to existing Beta/Gama antenna destinations.
	var beta: Vector3 = Vector3(-8.5, 0, -24)
	_closed_case(st, beta, 21, Vector3(-0.13, 0, 0.04), Vector3(1.05, 0.67, 0.68), MODULE, ORANGE)
	_box(st, beta, 21, Vector3(-0.13, 0.72, 0.04), Vector3(0.72, 0.09, 0.44), PANEL)
	_box(st, beta, -8, Vector3(0.6, 0.17, -0.32), Vector3(0.25, 0.42, 0.36), IRON)
	var gama: Vector3 = Vector3(-23, 0, -4)
	_closed_case(st, gama, -31, Vector3(-0.13, 0, -0.1), Vector3(0.7, 0.5, 0.58), PANEL_INSET, ORANGE)
	_closed_case(st, gama, 14, Vector3(0.48, 0, 0.26), Vector3(0.46, 0.35, 0.42), MODULE, IRON)
	_beam(st, gama, -31, Vector3(-0.36, 0.59, -0.1), Vector3(0.1, 0.59, -0.1), 0.035, IRON)


static func _closed_case(st: SurfaceTool, origin: Vector3, yaw: float, offset: Vector3, size: Vector3, body: Color, strap: Color) -> void:
	_box(st, origin, yaw, offset + Vector3(0, size.y * 0.5 - 0.035, 0), size, body)
	_box(st, origin, yaw, offset + Vector3(0, size.y - 0.015, 0), Vector3(size.x * 1.03, 0.075, size.z * 1.03), body.lightened(0.07))
	for x: float in [-size.x * 0.29, size.x * 0.29]:
		_box(st, origin, yaw, offset + Vector3(x, size.y * 0.5, -size.z * 0.505), Vector3(0.065, size.y * 0.8, 0.025), strap)
		_box(st, origin, yaw, offset + Vector3(x, size.y + 0.029, 0), Vector3(0.065, 0.018, size.z), strap)


static func _bag(st: SurfaceTool, origin: Vector3, yaw: float, offset: Vector3, size: Vector3) -> void:
	_box(st, origin, yaw, offset + Vector3(0, size.y * 0.5 - 0.03, 0), size, LEATHER)
	_box(st, origin, yaw, offset + Vector3(0, size.y - 0.025, 0), Vector3(size.x * 0.92, 0.07, size.z * 1.08), CANVAS)
	_box(st, origin, yaw, offset + Vector3(0.04, size.y * 0.68, -size.z * 0.52), Vector3(0.06, size.y * 0.55, 0.025), WOOD_DARK)
	_box(st, origin, yaw, offset + Vector3(0.04, size.y * 0.56, -size.z * 0.57), Vector3(0.09, 0.065, 0.025), IRON)


static func _stone(st: SurfaceTool, origin: Vector3, radius: float, height: float, angle: float, color: Color) -> void:
	# Existing broken-pillar prism language, squat and weathered, not a new artefact.
	var basis: Basis = Basis(Vector3.UP, deg_to_rad(angle))
	GEO.prism(st, origin + basis * Vector3(0, -0.06, 0), origin + basis * Vector3(0.055, height, -0.025), radius, radius * 0.73, 7, color)


static func _box(st: SurfaceTool, origin: Vector3, angle: float, offset: Vector3, size: Vector3, color: Color) -> void:
	var basis: Basis = Basis(Vector3.UP, deg_to_rad(angle))
	GEO.box(st, origin + basis * offset, size, basis, color)


static func _beam(st: SurfaceTool, origin: Vector3, angle: float, a: Vector3, b: Vector3, radius: float, color: Color) -> void:
	var basis: Basis = Basis(Vector3.UP, deg_to_rad(angle))
	GEO.prism(st, origin + basis * a, origin + basis * b, radius, radius, 6, color)


static func _bake(raw: SurfaceTool, theme: String) -> Mesh:
	var source: ArrayMesh = raw.commit()
	var arrays: Array = source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var output: SurfaceTool = SurfaceTool.new()
	output.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(0, vertices.size(), 3):
		var points: Array[Vector3] = []
		for j: int in range(3):
			var p: Vector3 = vertices[i + j]
			p.y += TERRAIN[theme].call("height_at", p.x, p.z)
			points.append(p)
		var normal: Vector3 = -(points[1] - points[0]).cross(points[2] - points[0]).normalized()
		for j: int in range(3):
			output.set_normal(normal)
			output.set_color(colors[i + j])
			output.add_vertex(points[j])
	return ToonKit.commit(output)
