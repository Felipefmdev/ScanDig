extends Node3D

## Montra das ferramentas (#37): fundo bege e sol como a montra de arte (art_showcase.gd) e um
## plano por ferramenta, com o ângulo das referências de docs/art/reference/. O bot tira as
## capturas: tools/run_bot.sh <godot> tools/bot/tools_showcase.json.

const SHOT_TIME: float = 1.2
const BG: Color = Color(0.88, 0.86, 0.8)

## [script do modelo, posição, rotação (euler)]
const SUBJECTS: Array = [
	["res://gameplay/player/shovel_model.gd", Vector3(0.48, 0.012, -0.22), Vector3(-PI * 0.5, 2.09, 0.0)],
	["res://gameplay/weapons/medkit/medkit_model.gd", Vector3(2.0, 0.0, 0.0), Vector3(0.0, -0.45, 0.0)],
	["res://gameplay/weapons/repellent/repellent_model.gd", Vector3(4.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0)],
	["res://gameplay/weapons/slingshot/slingshot_model.gd", Vector3(6.0, 0.1, 0.0), Vector3(0.0, -0.5, 0.0)],
]

## Ferramentas no chão: ItemPickup reais (o mesmo caminho de quando se larga/morre).
const GROUND_TOOLS: Array[String] = [
	"res://items/tools/estilingue.tres", "res://items/tools/repelente.tres", "res://items/tools/kit_medico.tres",
]

## [posição da câmara, ponto para onde olha, fov]
const SHOTS: Array = [
	[Vector3(0.05, 0.78, 0.62), Vector3(0.05, 0.0, 0.03), 52.0],
	[Vector3(2.16, 0.27, 0.36), Vector3(2.0, 0.11, 0.0), 42.0],
	[Vector3(4.08, 0.24, 0.4), Vector3(4.0, 0.13, 0.0), 38.0],
	[Vector3(6.06, 0.2, 0.42), Vector3(6.0, 0.14, 0.0), 42.0],
	[Vector3(8.0, 0.75, 1.0), Vector3(8.0, 0.05, 0.0), 45.0],
]

var _cam: Camera3D = null
var _shot: int = -1
var _time: float = 0.0


func _ready() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BG
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.8, 0.9)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation = Vector3(-0.872665, -0.610865, 0.0)
	sun.light_color = Color(1.0, 0.97, 0.9)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)

	var floor_mi: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(40.0, 40.0)
	floor_mi.mesh = plane
	var floor_mat: StandardMaterial3D = StandardMaterial3D.new()
	floor_mat.albedo_color = BG
	floor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	floor_mi.material_override = floor_mat
	floor_mi.position = Vector3(3.0, 0.0, 0.0)
	add_child(floor_mi)

	for s: Array in SUBJECTS:
		var model: Node3D = Node3D.new()
		model.set_script(load(s[0]) as Script)
		model.position = s[1]
		model.rotation = s[2]
		add_child(model)

	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var floor_box: BoxShape3D = BoxShape3D.new()
	floor_box.size = Vector3(40.0, 0.2, 40.0)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(3.0, -0.1, 0.0)
	add_child(floor_body)
	for i: int in GROUND_TOOLS.size():
		var td: ToolData = load(GROUND_TOOLS[i]) as ToolData
		var pickup: ItemPickup = ItemPickup.create(CarriedItem.create_from_tool_data(td))
		add_child(pickup)
		pickup.global_position = Vector3(7.55 + 0.45 * float(i), 0.3, 0.0)

	_cam = Camera3D.new()
	_cam.current = true
	add_child(_cam)
	_next_shot()


func _process(delta: float) -> void:
	_time += delta
	if _time >= SHOT_TIME:
		_time = 0.0
		_next_shot()


func _next_shot() -> void:
	_shot = (_shot + 1) % SHOTS.size()
	var s: Array = SHOTS[_shot]
	_cam.fov = s[2]
	_cam.look_at_from_position(s[0], s[1])
