extends Node3D

## Montra de arte (#36/#37): fundo bege como as referências de docs/art/reference/, um sol
## como o dos mapas e os modelos toon parados (IA desligada). Muda de plano a cada SHOT_TIME s;
## o bot tira as capturas: tools/run_bot.sh <godot> tools/bot/art_showcase.json.

const SHOT_TIME: float = 1.2
const BG: Color = Color(0.88, 0.86, 0.8)

## [cena, posição, rotação y]
const SUBJECTS: Array = [
	["res://gameplay/enemies/crab/crab.tscn", Vector3(0.0, 0.0, 0.0), 0.0],
	["res://gameplay/enemies/crab/hermit_crab.tscn", Vector3(4.0, 0.0, 0.0), 0.0],
	["res://gameplay/enemies/boss/king_crab.tscn", Vector3(10.0, 0.0, 0.0), 0.0],
	["res://gameplay/enemies/mole/mole.tscn", Vector3(16.0, 0.0, 0.0), 0.0],
	["res://gameplay/enemies/snake/snake.tscn", Vector3(18.0, 0.0, 0.0), 0.0],
	["res://gameplay/enemies/seagull/seagull.tscn", Vector3(20.0, 0.6, 0.0), 0.0],
	["res://gameplay/enemies/boss/giant_mole.tscn", Vector3(25.0, 0.0, 0.0), 0.0],
	["res://gameplay/enemies/stone_guardian/stone_guardian.tscn", Vector3(32.0, 0.0, 0.0), 0.0],
	["res://gameplay/enemies/bat/bat.tscn", Vector3(34.5, 1.2, 0.0), 0.0],
	["res://gameplay/enemies/crow/crow.tscn", Vector3(36.5, 1.2, 0.0), 0.0],
	["res://gameplay/enemies/boss/crow_king.tscn", Vector3(41.0, 1.0, 0.0), 0.0],
	["res://gameplay/enemies/boss/scarecrow.tscn", Vector3(46.0, 0.0, 0.0), 0.0],
]
const KIT: Array[StringName] = [&"metal_rust", &"wood", &"paint_red", &"paint_green", &"carapace", &"vertex"]

## [posição da câmara, ponto para onde olha, fov]
const SHOTS: Array = [
	[Vector3(-0.75, 0.8, -1.6), Vector3(-0.05, 0.34, 0.0), 40.0],
	[Vector3(3.0, 1.0, -1.9), Vector3(4.0, 0.45, 0.0), 40.0],
	[Vector3(7.0, 3.0, -6.0), Vector3(10.0, 1.0, 0.0), 45.0],
	[Vector3(12.5, 6.0, -21.0), Vector3(12.5, 0.6, 0.0), 45.0],
	[Vector3(5.0, 2.4, 1.0), Vector3(5.0, 0.5, 6.0), 45.0],
	[Vector3(-1.3, 0.9, 1.2), Vector3(0.0, 0.3, 0.0), 40.0],
	[Vector3(34.0, 2.2, -5.0), Vector3(33.0, 1.0, 0.0), 42.0],
	[Vector3(43.5, 3.5, -8.0), Vector3(43.5, 1.2, 0.0), 45.0],
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
	plane.size = Vector2(80.0, 80.0)
	floor_mi.mesh = plane
	var floor_mat: StandardMaterial3D = StandardMaterial3D.new()
	floor_mat.albedo_color = BG
	floor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	floor_mi.material_override = floor_mat
	floor_mi.position = Vector3(10.0, -0.01, 0.0)
	add_child(floor_mi)

	for s: Array in SUBJECTS:
		var scene: PackedScene = load(s[0]) as PackedScene
		var n: Node3D = scene.instantiate() as Node3D
		add_child(n)
		n.process_mode = Node.PROCESS_MODE_DISABLED
		n.global_position = s[1]
		n.rotation.y = s[2]
		var hud: CanvasLayer = n.get_node_or_null(^"BossHud") as CanvasLayer
		if hud != null:
			hud.visible = false

	_build_kit()

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


## Amostras do kit de materiais: uma coluna facetada + um cubo por material.
func _build_kit() -> void:
	for i: int in KIT.size():
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var c: Color = Color(0.95, 0.55, 0.25) if KIT[i] == &"vertex" else Color.WHITE
		LowPolyMesh.prism(st, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 1.1, 0.0), 0.32, 0.26, 8, c)
		LowPolyMesh.box(st, Vector3(0.0, 0.25, -0.55), Vector3(0.45, 0.5, 0.45), Basis(Vector3.UP, 0.5), c)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = String(KIT[i])
		mi.mesh = ToonKit.commit(st)
		mi.material_override = ToonKit.material(KIT[i])
		mi.position = Vector3(1.5 + 1.4 * float(i), 0.0, 6.0)
		add_child(mi)
		var label: Label3D = Label3D.new()
		label.text = String(KIT[i])
		label.font_size = 28
		label.modulate = Color(0.1, 0.1, 0.1)
		label.position = mi.position + Vector3(0.0, 1.45, 0.0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)
