extends Node3D

## Arena de capturas da #57 (caos estilo How to Fish): chão de areia, palmeiras-poste para o
## pião ricochetear, o jogador real (o empurrão é o Player.apply_knockback de verdade, com o
## avatar visível) e UM chefe — ou os inimigos — escolhido pelo nome do roteiro do bot
## (tools/bot/chaos_<id>.json). Câmara externa que segue o meio entre o chefe e o jogador.
## A cada STEP_TIME s força o próximo ataque caótico (sempre telegrafado) para o bot fotografar.
## Uso: tools/run_bot.sh <godot> tools/bot/chaos_king_crab.json

const STEP_TIME: float = 6.0
const SAND: Color = Color(0.86, 0.76, 0.52)
const GRASS: Color = Color(0.45, 0.6, 0.28)
const PLAYER_SCENE: PackedScene = preload("res://gameplay/player/player.tscn")

## id -> [cena, ataques (estado a forçar, por ordem), chão de erva?]
const BOSSES: Dictionary = {
	"king_crab": ["res://gameplay/enemies/boss/king_crab.tscn", ["SPIN_TELEGRAPH", "BELLY_TELEGRAPH", "THROW_TELEGRAPH"], false],
	"octopus": ["res://gameplay/enemies/boss/octopus.tscn", ["SPIN_TELEGRAPH", "GRAB_TELEGRAPH", "INK_TELEGRAPH"], false],
	"giant_mole": ["res://gameplay/enemies/boss/giant_mole.tscn", ["BURROW", "ROCK_TELEGRAPH", "BURROW"], true],
	"crow_king": ["res://gameplay/enemies/boss/crow_king.tscn", ["STEAL_TELEGRAPH", "TELEGRAPH", "TORNADO_TELEGRAPH"], true],
	"scarecrow": ["res://gameplay/enemies/boss/scarecrow.tscn", ["STRAW_OUT", "THROW_TELEGRAPH", "WHIRL_TELEGRAPH"], true],
}
const MOBS: Array = [
	["res://gameplay/enemies/crab/crab.tscn", Vector3(-4.0, 0.0, -3.0)],
	["res://gameplay/enemies/crab/crab.tscn", Vector3(4.0, 0.0, -3.0)],
	["res://gameplay/enemies/seagull/seagull.tscn", Vector3(0.0, 6.0, -6.0)],
	["res://gameplay/enemies/snake/snake.tscn", Vector3(-3.0, 0.0, 3.5)],
	["res://gameplay/enemies/mole/mole.tscn", Vector3(3.0, 0.0, 3.0)],
	["res://gameplay/enemies/crow/crow.tscn", Vector3(5.0, 3.0, 0.0)],
	["res://gameplay/enemies/crow/crow.tscn", Vector3(-5.0, 3.0, 0.0)],
]

var boss_id: String = "king_crab"
var _boss: EnemyBase = null
var _player: Node3D = null
var _cam: Camera3D = null
var _attack: int = 0
var _timer: float = 1.5
var _mobs: Array[EnemyBase] = []


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--bot=") and arg.get_file().begins_with("chaos_"):
			boss_id = arg.get_file().get_basename().trim_prefix("chaos_")
	var grass: bool = BOSSES.has(boss_id) and bool(BOSSES[boss_id][2])
	_build_world(grass)
	_player = PLAYER_SCENE.instantiate() as Node3D
	_player.name = "Player"
	add_child(_player)
	_player.global_position = Vector3(0.0, 0.2, 6.0)
	_player.rotation.y = 0.0
	# Vista externa: o avatar aparece, a câmara de 1.ª pessoa e as mãos não.
	var avatar: Node3D = _player.get_node_or_null(^"Avatar") as Node3D
	if avatar != null:
		avatar.visible = true
	var fp: Camera3D = _player.get_node_or_null(^"Head/Camera3D") as Camera3D
	if fp != null:
		fp.visible = false
		fp.current = false
	_cam = Camera3D.new()
	_cam.fov = 50.0
	add_child(_cam)
	_cam.current = true
	if boss_id == "mobs":
		for m: Array in MOBS:
			var e: EnemyBase = (load(m[0]) as PackedScene).instantiate() as EnemyBase
			add_child(e)
			e.global_position = m[1]
			_mobs.append(e)
	else:
		var scene: PackedScene = load(BOSSES[boss_id][0]) as PackedScene
		_boss = scene.instantiate() as EnemyBase
		add_child(_boss)
		_boss.global_position = Vector3.ZERO
		if _boss.has_method(&"wake_immediately"):
			_boss.call(&"wake_immediately")


func _process(delta: float) -> void:
	_follow_camera(delta)
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = STEP_TIME
	if boss_id == "mobs":
		_force_mobs()
	else:
		_force_boss()


## Força o próximo ataque caótico do chefe (todos começam por um aviso no chão).
func _force_boss() -> void:
	if _boss == null or not is_instance_valid(_boss) or not _boss.is_alive():
		return
	var list: Array = BOSSES[boss_id][1]
	var state_name: String = list[_attack % list.size()]
	_attack += 1
	var target_pos: Vector3 = _player.global_position
	if "net_attack_point" in _boss:
		_boss.set(&"net_attack_point", Vector3(target_pos.x, 0.0, target_pos.z))
	if "net_attack_dir" in _boss:
		var d: Vector3 = target_pos - _boss.global_position
		d.y = 0.0
		_boss.set(&"net_attack_dir", d.normalized() if d.length_squared() > 0.01 else Vector3.FORWARD)
	match boss_id:
		"crow_king":
			# O roubo e o tornado começam pelo _start_attack (calcula a faixa/ponto).
			_boss.set(&"_cycle_index", ["TELEGRAPH", "STEAL_TELEGRAPH", "TELEGRAPH", "TORNADO_TELEGRAPH"].find(state_name))
			_boss.call(&"_start_attack")
			return
		"giant_mole":
			_boss.set(&"_erupts_left", 1)
	var value: int = int(_boss_state_value(state_name))
	if value >= 0:
		_boss.call(&"_enter_state", value)


func _boss_state_value(state_name: String) -> int:
	var script: Script = _boss.get_script() as Script
	var consts: Dictionary = script.get_script_constant_map() if script != null else {}
	var states: Variant = consts.get("State", null)
	if states is Dictionary and (states as Dictionary).has(state_name):
		return int(states[state_name])
	return -1


## Inimigos: corrida de lado, kamikaze, mola, toupeira por baixo e espiral, todos de uma vez.
func _force_mobs() -> void:
	var p: Vector3 = _player.global_position
	for e: EnemyBase in _mobs:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		if e is Crab:
			var d: Vector3 = p - e.global_position
			(e as Crab).start_rush(Vector3(d.x, 0.0, d.z).normalized())
		elif e is Crow:
			e.set(&"net_dive_point", Vector3(p.x, 0.0, p.z))
			e.call(&"_update_target", 1.0)
			e.call(&"_enter_state", Seagull.State.SPIRAL_TELEGRAPH)
		elif e is Seagull:
			e.set(&"net_dive_point", Vector3(p.x + 3.0, 0.0, p.z))
			e.call(&"_enter_state", Seagull.State.KAMIKAZE_TELEGRAPH)
		elif e is Snake:
			(e as Snake).start_spring(p)
		elif e is Mole:
			e.global_position = Vector3(p.x, e.global_position.y, p.z)
			e.call(&"_enter_state", Mole.State.TELEGRAPH)


func _follow_camera(delta: float) -> void:
	if _cam == null or _player == null:
		return
	var focus: Vector3 = _player.global_position
	if _boss != null and is_instance_valid(_boss):
		focus = focus.lerp(_boss.global_position, 0.5)
	var goal: Vector3 = focus + Vector3(6.0, 6.5, 8.5)
	_cam.global_position = _cam.global_position.lerp(goal, clampf(delta * 3.0, 0.0, 1.0)) if _cam.global_position.length() > 0.1 else goal
	_cam.look_at(focus + Vector3.UP * 0.8, Vector3.UP)


func _build_world(grass: bool) -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.62, 0.8, 0.95)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.75, 0.8)
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(35.0), 0.0)
	sun.shadow_enabled = true
	add_child(sun)
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.name = "Floor"
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(60.0, 1.0, 60.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(shape)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(60.0, 60.0)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = GRASS if grass else SAND
	mat.roughness = 1.0
	plane.material = mat
	mesh.mesh = plane
	floor_body.add_child(mesh)
	add_child(floor_body)
	# Postes (palmeiras/menires) para o pião ricochetear
	for k: int in 6:
		var ang: float = TAU * float(k) / 6.0
		var post: StaticBody3D = StaticBody3D.new()
		var cs: CollisionShape3D = CollisionShape3D.new()
		var cyl: CylinderShape3D = CylinderShape3D.new()
		cyl.radius = 0.35
		cyl.height = 4.0
		cs.shape = cyl
		cs.position = Vector3(0.0, 2.0, 0.0)
		post.add_child(cs)
		var pm: MeshInstance3D = MeshInstance3D.new()
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = 0.25
		cm.bottom_radius = 0.35
		cm.height = 4.0
		var pmat: StandardMaterial3D = StandardMaterial3D.new()
		pmat.albedo_color = Color(0.55, 0.4, 0.25)
		cm.material = pmat
		pm.mesh = cm
		pm.position = Vector3(0.0, 2.0, 0.0)
		post.add_child(pm)
		add_child(post)
		post.global_position = Vector3(cos(ang) * 11.0, 0.0, sin(ang) * 11.0)
