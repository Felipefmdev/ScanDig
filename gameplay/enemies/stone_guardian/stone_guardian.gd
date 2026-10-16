class_name StoneGuardian
extends EnemyBase

## Guardião de pedra (#42): estátua das Ruínas que desperta do chão, anda devagar e esmaga à
## frente com os dois braços (golpe telegrafado: levanta os braços WINDUP_TIME s). É de pedra:
## os golpes só fazem ARMOR_FACTOR do dano, salvo se estiver atordoado (o flash da Lanterna de
## Magnésio abre-lhe a guarda) ou a recuperar depois de um golpe falhado.
## #57 (caos): de vez em quando enrola-se numa pedra e ROLA em linha reta para o jogador
## (faixa vermelha no chão ROLL_WINDUP s antes); quem apanha voa. No fim fica tonto (guarda
## aberta). Coop (#24): IA no host; estado e direção do rolar (net_roll_dir) replicados.

enum State { EMERGE, WALK, WINDUP, SMASH, RECOVER, ROLL_WINDUP, ROLL, DIZZY }

const CrabModel := preload("res://gameplay/enemies/crab/crab_model.gd")
const ARMOR_FACTOR: float = 0.4
const SMASH_RANGE: float = 1.8
const STONE: Color = Color("#a39b74")
const STONE_DARK: Color = Color("#6b6650")
const MOSS: Color = Color("#6f8a2a")
const JADE: Color = Color("#ffb030")

@export var move_speed: float = 1.3
@export var turn_speed: float = 4.0
@export var smash_damage: float = 18.0
@export var windup_time: float = 0.8
@export var recover_time: float = 1.3
@export var emerge_time: float = 1.2
@export var attack_range: float = 1.6
## 0 = nasceu por ambiente; >0 = nível de ameaça que o acordou.
@export var spawn_level: int = 0
@export var roll_speed: float = 9.0
@export var roll_length: float = 11.0
@export var roll_windup: float = 0.9
@export var roll_damage: float = 14.0
## Probabilidade de rolar em vez de andar quando o jogador está longe (por avaliação).
@export var roll_chance: float = 0.35

var net_roll_dir: Vector3 = Vector3.ZERO:
	set(value):
		net_roll_dir = value
		if not has_simulation_authority() and is_node_ready():
			_refresh_roll_warning()

var state: State = State.EMERGE
var _state_time: float = 0.0
var _surface_y: float = 0.0
var _hit_done: bool = false
var _body: Node3D = null
var _arm_left: Node3D = null
var _arm_right: Node3D = null
var _walk_time: float = 0.0
var _roll_from: Vector3 = Vector3.ZERO
var _roll_hit: Array[Node] = []
var _roll_check: float = 2.0
var _warning: GroundWarning = null
var _boulder: MeshInstance3D = null


func _ready() -> void:
	super._ready()
	stun_fx_height = 2.2
	death_color = STONE
	_build_model()
	_warning = GroundWarning.new()
	add_child(_warning)
	_enter_state(State.EMERGE)


func setup_network() -> void:
	super.setup_network()
	_add_synced_property(".:net_roll_dir")


func _enemy_physics(delta: float) -> void:
	_state_time += delta
	match state:
		State.EMERGE:
			var t: float = clampf(_state_time / emerge_time, 0.0, 1.0)
			global_position.y = _surface_y - 1.6 * (1.0 - t)
			if t >= 1.0:
				_enter_state(State.WALK)
		State.WALK:
			_process_walk(delta)
		State.WINDUP:
			_warning.pulse(delta)
			if _state_time >= windup_time:
				_enter_state(State.SMASH)
		State.SMASH:
			if not _hit_done and _state_time >= 0.1:
				_hit_done = true
				_smash()
			if _state_time >= 0.35:
				_enter_state(State.RECOVER)
		State.RECOVER:
			if _state_time >= recover_time:
				_enter_state(State.WALK)
		State.ROLL_WINDUP:
			_warning.pulse(delta)
			if _state_time >= roll_windup:
				_enter_state(State.ROLL)
		State.ROLL:
			_process_roll(delta)
		State.DIZZY:
			if _state_time >= recover_time * 1.4:
				_enter_state(State.WALK)
	_animate(delta)


func _process_walk(delta: float) -> void:
	_apply_gravity(delta)
	var target: Node3D = _update_target(delta)
	if target == null:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	var to: Vector3 = target.global_position - global_position
	to.y = 0.0
	var dist: float = to.length()
	var dir: Vector3 = to / dist if dist > 0.01 else Vector3.ZERO
	_turn_towards(dir, 0.0, turn_speed, delta)
	if dist <= attack_range:
		_enter_state(State.WINDUP)
		return
	_roll_check -= delta
	if _roll_check <= 0.0:
		_roll_check = 2.5
		if dist > 4.0 and dist < roll_length and randf() < roll_chance:
			net_roll_dir = dir
			_enter_state(State.ROLL_WINDUP)
			return
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	move_and_slide()
	_walk_time += delta


func _enter_state(s: State) -> void:
	state = s
	_state_time = 0.0
	match s:
		State.EMERGE:
			_surface_y = global_position.y
			global_position.y = _surface_y - 1.6
		State.WINDUP:
			var target: Node3D = _update_target(0.0)
			var fwd: Vector3 = (target.global_position - global_position).normalized() if target != null else -global_transform.basis.z
			fwd.y = 0.0
			_warning.show_circle(global_position + fwd * 1.0, SMASH_RANGE)
		State.SMASH:
			_hit_done = false
			_warning.hide_warning()
			SFX.play_at(SFX.EMERGE_SAND, global_position, 3.0)
		State.ROLL_WINDUP:
			_warning.show_line(global_position, net_roll_dir, roll_length)
		State.ROLL:
			_warning.hide_warning()
			_roll_from = global_position
			_roll_hit.clear()
		State.WALK, State.DIZZY, State.RECOVER:
			_warning.hide_warning()
	_set_boulder(s == State.ROLL_WINDUP or s == State.ROLL)


func _process_roll(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = net_roll_dir.x * roll_speed
	velocity.z = net_roll_dir.z * roll_speed
	move_and_slide()
	for p: Node3D in _all_players():
		if _roll_hit.has(p):
			continue
		var d: Vector3 = p.global_position - global_position
		d.y = 0.0
		if d.length() <= 1.2:
			_roll_hit.append(p)
			_deal_damage(p, roll_damage)
			var side: Vector3 = d.normalized() if d.length() > 0.05 else net_roll_dir
			_knockback(p, (side + net_roll_dir).normalized() * 9.0 + Vector3.UP * 6.0, 0.07)
	var travelled: float = Vector2(global_position.x - _roll_from.x, global_position.z - _roll_from.z).length()
	# Pára ao fim do percurso ou se bateu numa parede (quase não avançou).
	if travelled >= roll_length or (_state_time > 0.4 and get_real_velocity().length() < 1.0):
		spawn_particles(global_position + Vector3.UP * 0.5, STONE_DARK, 18, 3.0)
		SFX.play_at(SFX.EMERGE_SAND, global_position, 4.0)
		velocity = Vector3.ZERO
		_enter_state(State.DIZZY)


func _refresh_roll_warning() -> void:
	if state == State.ROLL_WINDUP:
		_warning.show_line(global_position, net_roll_dir, roll_length)
	elif state == State.WINDUP:
		_warning.show_circle(global_position - transform.basis.z * 1.0, SMASH_RANGE)
	else:
		_warning.hide_warning()


## Rolar: o corpo esconde-se e aparece um pedregulho a girar.
func _set_boulder(on: bool) -> void:
	if _boulder == null:
		return
	_boulder.visible = on
	_body.visible = not on


func _smash() -> void:
	var fwd: Vector3 = -global_transform.basis.z
	var center: Vector3 = global_position + fwd * 1.0
	spawn_particles(center, STONE_DARK, 14, 2.5)
	for p: Node3D in _all_players():
		var d: Vector3 = p.global_position - center
		d.y = 0.0
		if d.length() <= SMASH_RANGE:
			_deal_damage(p, smash_damage)
			# Bofetada de pedra: atira o jogador para trás e para cima (#57)
			_knockback(p, fwd * 8.0 + Vector3.UP * 5.0, 0.12)


# ---------------------------------------------------------------------------
# Regras
# ---------------------------------------------------------------------------

func is_armor_open() -> bool:
	return is_stunned() or state == State.RECOVER or state == State.DIZZY


func _can_take_damage() -> bool:
	return state != State.EMERGE


func _can_be_stunned() -> bool:
	return state != State.EMERGE


func _modify_damage(amount: float, _from: Vector3) -> float:
	if is_armor_open():
		return amount
	spawn_particles(global_position + Vector3.UP * 1.2, Color(0.85, 0.85, 0.8), 6, 2.0)
	SFX.play_at(SFX.SHELL_KNOCK, global_position)
	return amount * ARMOR_FACTOR


## A pedra não foge do repelente.
func flee_from(_origin: Vector3, _seconds: float) -> void:
	pass


func _on_remote_state(new_state: int) -> void:
	_state_time = 0.0
	_set_boulder(new_state == State.ROLL_WINDUP or new_state == State.ROLL)
	_refresh_roll_warning()


func _animate_remote(delta: float, speed: float) -> void:
	if speed > 0.2:
		_walk_time += delta
	_animate(delta)


func _animate(delta: float) -> void:
	if _arm_left == null:
		return
	var target_arm: float = 0.0
	match state:
		State.WINDUP:
			target_arm = -2.4
		State.SMASH:
			target_arm = 0.4
		State.RECOVER:
			target_arm = 0.25
		State.WALK:
			target_arm = sin(_walk_time * 3.0) * 0.25
	_arm_left.rotation.x = lerpf(_arm_left.rotation.x, target_arm, clampf(12.0 * delta, 0.0, 1.0))
	_arm_right.rotation.x = lerpf(_arm_right.rotation.x, target_arm if state != State.WALK else -target_arm, clampf(12.0 * delta, 0.0, 1.0))
	_body.position.y = absf(sin(_walk_time * 3.0)) * 0.05 if state == State.WALK else 0.0
	if _boulder != null and _boulder.visible:
		_boulder.rotation.x -= delta * (14.0 if state == State.ROLL else 3.0)
	if state == State.DIZZY:
		_body.rotation.z = sin(_state_time * 8.0) * 0.15
	else:
		_body.rotation.z = 0.0


func _build_model() -> void:
	var mat: ShaderMaterial = ToonKit.vertex_material(true, true)
	mat.set_shader_parameter(&"spots_amount", 0.5)
	mat.set_shader_parameter(&"spots_color", MOSS)
	mat.set_shader_parameter(&"spots_scale", 3.0)
	mat.set_shader_parameter(&"spots_size", 0.25)
	mat.set_shader_parameter(&"chip_amount", 0.3)
	mat.set_shader_parameter(&"chip_color", STONE_DARK)
	mat.set_shader_parameter(&"chip_scale", 3.0)
	_register_flash_material(mat)
	_body = Node3D.new()
	_body.name = "BodyRoot"
	add_child(_body)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-1.0, 1.0]:
		LowPolyMesh.box(st, Vector3(0.22 * side, 0.35, 0.0), Vector3(0.32, 0.7, 0.4), Basis.IDENTITY, STONE_DARK)
	LowPolyMesh.prism(st, Vector3(0.0, 0.7, 0.0), Vector3(0.0, 1.55, 0.0), 0.5, 0.62, 6, STONE)
	LowPolyMesh.box(st, Vector3(0.0, 1.15, -0.5), Vector3(0.5, 0.45, 0.08), Basis.IDENTITY, STONE_DARK)
	# Runas a brilhar no peito (guardiao_pedra.jpg)
	for k: int in 3:
		LowPolyMesh.box(st, Vector3(-0.15 + 0.15 * float(k), 1.15, -0.545), Vector3(0.05, 0.22, 0.02), Basis(Vector3.FORWARD, 0.35 * float(k - 1)), Color(JADE.r, JADE.g, JADE.b, 0.0))
	# Cabeça-máscara com olhos de jade
	LowPolyMesh.box(st, Vector3(0.0, 1.85, 0.0), Vector3(0.6, 0.55, 0.55), Basis.IDENTITY, STONE)
	LowPolyMesh.box(st, Vector3(0.0, 2.15, 0.0), Vector3(0.64, 0.08, 0.58), Basis.IDENTITY, MOSS)
	var jade: Color = Color(JADE.r, JADE.g, JADE.b, 0.0)
	for side: float in [-1.0, 1.0]:
		LowPolyMesh.box(st, Vector3(0.14 * side, 1.9, -0.28), Vector3(0.14, 0.07, 0.04), Basis.IDENTITY, jade)
	LowPolyMesh.box(st, Vector3(0.0, 1.7, -0.28), Vector3(0.3, 0.05, 0.04), Basis.IDENTITY, Color(0.1, 0.08, 0.08, 0.0))
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = ToonKit.commit(st)
	mi.material_override = mat
	_body.add_child(mi)
	_arm_left = _build_arm(-1.0, mat)
	_arm_right = _build_arm(1.0, mat)
	# Pedregulho (visível só a rolar)
	var bst: SurfaceTool = SurfaceTool.new()
	bst.begin(Mesh.PRIMITIVE_TRIANGLES)
	CrabModel.gem(bst, Transform3D.IDENTITY, Vector3.ZERO, Basis.IDENTITY, [
		Vector3(-0.45, 0.6, 0.6), Vector3(0.0, 0.8, 0.8), Vector3(0.45, 0.62, 0.62)], 7, -0.8, 0.8, STONE, 0.05, 13)
	LowPolyMesh.box(bst, Vector3(0.0, 0.1, -0.78), Vector3(0.3, 0.07, 0.05), Basis.IDENTITY, Color(JADE.r, JADE.g, JADE.b, 0.0))
	_boulder = MeshInstance3D.new()
	_boulder.name = "Boulder"
	_boulder.mesh = ToonKit.commit(bst)
	_boulder.material_override = mat
	_boulder.position = Vector3(0.0, 0.8, 0.0)
	_boulder.visible = false
	add_child(_boulder)


func _build_arm(side: float, mat: Material) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.position = Vector3(0.72 * side, 1.45, 0.0)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyMesh.box(st, Vector3(0.0, -0.1, 0.0), Vector3(0.36, 0.36, 0.4), Basis.IDENTITY, STONE_DARK)
	LowPolyMesh.box(st, Vector3(0.0, -0.55, -0.05), Vector3(0.3, 0.7, 0.32), Basis.IDENTITY, STONE)
	LowPolyMesh.box(st, Vector3(0.0, -1.0, -0.1), Vector3(0.42, 0.32, 0.42), Basis.IDENTITY, STONE_DARK)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = ToonKit.commit(st)
	mi.material_override = mat
	pivot.add_child(mi)
	_body.add_child(pivot)
	return pivot
