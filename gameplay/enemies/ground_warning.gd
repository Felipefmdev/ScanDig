class_name GroundWarning
extends MeshInstance3D

## Marca vermelha no chão para ataques telegrafados (círculo). top_level: não segue o dono.

const COLOR: Color = Color(1.0, 0.12, 0.08, 0.45)

var _mat: StandardMaterial3D = null
var _time: float = 0.0


func _init() -> void:
	name = "Warning"
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = COLOR
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = _mat
	visible = false


func show_circle(center: Vector3, radius: float) -> void:
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.02
	disc.radial_segments = 24
	mesh = disc
	global_transform = Transform3D(Basis.IDENTITY, center + Vector3.UP * 0.04)
	_time = 0.0
	visible = true


## Faixa retangular de `start` ao longo de `dir` (investidas, rolar).
func show_line(start: Vector3, dir: Vector3, length: float, width: float = 1.4) -> void:
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(width, 0.02, length)
	mesh = box
	var d: Vector3 = Vector3(dir.x, 0.0, dir.z).normalized()
	var basis: Basis = Basis.looking_at(d, Vector3.UP) if d.length_squared() > 0.001 else Basis.IDENTITY
	global_transform = Transform3D(basis, start + d * length * 0.5 + Vector3.UP * 0.04)
	_time = 0.0
	visible = true


func hide_warning() -> void:
	visible = false


## Pisca mais depressa à medida que o ataque se aproxima.
func pulse(delta: float) -> void:
	_time += delta
	var a: float = 0.3 + 0.3 * (0.5 + 0.5 * sin(_time * 18.0))
	_mat.albedo_color = Color(COLOR.r, COLOR.g, COLOR.b, a)
