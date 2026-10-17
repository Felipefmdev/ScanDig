extends Node3D

## Vida ambiente (estudo How to Fish: BirdManager, pássaros a voar pela ilha). Partículas leves
## por mapa à volta da câmara: neve na Geleira, borboletas no Campo, poeira nas Ruínas,
## brasas na Cratera, maresia na Praia. Só cosmético e local (cada peer tem as suas).

@export var theme: String = "praia"

const BOX: Vector3 = Vector3(36, 14, 36)

var particles: CPUParticles3D = null


func _ready() -> void:
	particles = CPUParticles3D.new()
	particles.name = "Ambient"
	particles.local_coords = false
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = BOX * 0.5
	particles.mesh = _mesh()
	_configure(particles)
	add_child(particles)


func _process(_delta: float) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam != null:
		global_position = cam.global_position + Vector3(0.0, 2.0, 0.0)


func _mesh() -> Mesh:
	var m: QuadMesh = QuadMesh.new()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	m.material = mat
	m.size = Vector2(0.06, 0.06)
	return m


func _configure(p: CPUParticles3D) -> void:
	p.amount = 80
	p.lifetime = 8.0
	p.gravity = Vector3.ZERO
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.25
	p.preprocess = 8.0
	match theme:
		"geleira":
			p.amount = 500
			p.gravity = Vector3(0.3, -0.9, 0.1)
			p.color = Color(1, 1, 1, 1)
			(p.mesh as QuadMesh).size = Vector2(0.11, 0.11)
		"campo":
			p.amount = 26
			p.gravity = Vector3(0, 0.05, 0)
			p.initial_velocity_min = 0.4
			p.initial_velocity_max = 0.9
			p.emission_box_extents = Vector3(BOX.x * 0.5, 1.2, BOX.z * 0.5)
			p.color = Color(1.0, 0.85, 0.3, 1.0)
			(p.mesh as QuadMesh).size = Vector2(0.12, 0.09)
			p.color_ramp = _ramp([Color(1.0, 0.9, 0.3, 0), Color(1.0, 0.95, 0.95, 1), Color(0.95, 0.6, 0.3, 1), Color(1, 1, 1, 0)])
		"ruinas":
			p.amount = 110
			p.color = Color(0.95, 0.9, 0.75, 0.45)
		"cratera":
			p.amount = 140
			p.gravity = Vector3(0, 0.35, 0)
			p.color_ramp = _ramp([Color(1.0, 0.5, 0.15, 0), Color(1.0, 0.55, 0.2, 1), Color(0.75, 0.4, 1.0, 1), Color(0.6, 0.3, 1.0, 0)])
		_:
			p.amount = 60
			p.color = Color(1, 1, 1, 0.35)


static func _ramp(colors: Array) -> Gradient:
	var g: Gradient = Gradient.new()
	var offs: PackedFloat32Array = PackedFloat32Array()
	var cols: PackedColorArray = PackedColorArray()
	for i: int in colors.size():
		offs.append(float(i) / float(colors.size() - 1))
		cols.append(colors[i])
	g.offsets = offs
	g.colors = cols
	return g
