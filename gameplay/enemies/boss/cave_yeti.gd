class_name CaveYeti
extends EnemyBase

## Yeti da Gruta (#43, #57): chefe escondido da Geleira Eterna.
## Inspirado fielmente na referência visual yeti.jpg:
##  - Pelagem branca e ciano-gelo farfalhante com tufos pontiagudos;
##  - Pele azul-acinzentada na face, mãos e pés grandes;
##  - Dois dentes inferiores salientes cómicos e olhos arregalados;
##  - Guarda uma garrafa térmica vermelha com tampa prateada;
##  - Ataques caóticos e telegrafados estilo "How to Fish":
##      * BOWLING: arremessa bolas de neve gigantes a rolar pelo corredor como pinos;
##      * SALTO DE BARRIGA: salta alto e cai de barriga estrondosa esmagando o chão;
##      * HÉLICE (HELICOPTER): gira os braços a grande velocidade como pás de helicóptero,
##        perseguindo os jogadores; no fim PÁRA TONTO (DIZZY, dano a 2,5x e guarda aberta);
##  - Troféu ao morrer: 'fossil_gelo'.

signal boss_defeated(boss_id: StringName)
signal health_changed(current: float, max_value: float)

enum State { EMERGE, WALK, BOWLING_TELE, BOWLING, BELLY_JUMP_TELE, BELLY_JUMP, HELICOPTER_TELE, HELICOPTER, DIZZY, DYING }

const BOSS_ID: StringName = &"cave_yeti"
const BOSS_NAME: String = "YETI DA GRUTA"
const GROUP_BOSSES: StringName = &"bosses"
const TROPHY_ITEM_ID: String = "fossil_gelo"

const FUR_WHITE: Color = Color("#c8e4f2")
const FUR_SHADOW: Color = Color("#8cb8d8")
const SKIN_BLUE: Color = Color("#4a6a94")
const SKIN_DARK: Color = Color("#34507a")
const EYE_WHITE: Color = Color(0.96, 0.96, 0.96)
const EYE_PUPIL: Color = Color(0.10, 0.10, 0.12)
const TOOTH_WHITE: Color = Color(0.95, 0.95, 0.90)
const THERMOS_RED: Color = Color("#c02a2a")
const THERMOS_SILVER: Color = Color("#a0a4ac")
const SNOW_BALL: Color = Color(0.92, 0.96, 1.0)

const WEAK_POINT_FACTOR: float = 2.5
const JUMP_RADIUS: float = 4.0
const BOWLING_SPEED: float = 12.0
const HELICOPTER_RADIUS: float = 2.6
const PHASE_TWO_RATIO: float = 0.5

@export var move_speed: float = 2.0
@export var turn_speed: float = 4.0
@export var bowling_damage: float = 18.0
@export var jump_damage: float = 22.0
@export var helicopter_damage: float = 14.0
@export var bowling_tele_time: float = 1.0
@export var jump_tele_time: float = 0.9
@export var helicopter_tele_time: float = 0.8
@export var helicopter_time: float = 3.6
@export var helicopter_speed: float = 4.5
@export var dizzy_time: float = 3.2
@export var emerge_time: float = 2.0

var state: State = State.EMERGE
var phase: int = 1
var net_attack_dir: Vector3 = Vector3.FORWARD:
	set(value):
		net_attack_dir = value
		if not has_simulation_authority() and is_node_ready():
			_refresh_remote_visuals()

var net_attack_point: Vector3 = Vector3.ZERO:
	set(value):
		net_attack_point = value
		if not has_simulation_authority() and is_node_ready():
			_refresh_remote_visuals()

var _state_time: float = 0.0
var _surface_y: float = 0.0
var _hit_done: bool = false
var _hit_targets: Array[Node] = []
var _attack_cycle: int = 0
var _anim_time: float = 0.0

var _hud: BossHud = null
var _warning: GroundWarning = null
var _body: Node3D = null
var _arm_left: Node3D = null
var _arm_right: Node3D = null
var _head: Node3D = null
var _thermos: Node3D = null
var _bowling_balls: Array[MeshInstance3D] = []
var _ball_dirs: Array[Vector3] = []
var _mat: ShaderMaterial = null


func _ready() -> void:
	super._ready()
	add_to_group(GROUP_BOSSES)
	max_health = 1200.0
	health = 1200.0
	death_color = FUR_WHITE
	stun_fx_height = 2.8
	_surface_y = global_position.y
	_build_model()
	_hud = BossHud.create("❄️ " + BOSS_NAME, max_health, Color(0.65, 0.85, 0.95))
	add_child(_hud)
	_warning = GroundWarning.new()
	add_child(_warning)
	boss_defeated.connect(_report_defeat_to_core)
	_enter_state(State.EMERGE)


func setup_network() -> void:
	super.setup_network()
	_add_synced_property(".:net_attack_dir")
	_add_synced_property(".:net_attack_point")


func _enemy_physics(delta: float) -> void:
	_state_time += delta
	_anim_time += delta

	_update_bowling_balls(delta)

	var speed_k: float = 0.8 if phase == 2 else 1.0

	match state:
		State.EMERGE:
			var t: float = clampf(_state_time / emerge_time, 0.0, 1.0)
			global_position.y = _surface_y - 2.5 * (1.0 - t)
			if t >= 1.0:
				_hud.visible = true
				_enter_state(State.WALK)
		State.WALK:
			_process_walk(delta)
		State.BOWLING_TELE:
			_warning.pulse(delta)
			_turn_towards(net_attack_dir, 0.0, turn_speed * 1.5, delta)
			if _state_time >= bowling_tele_time * speed_k:
				_enter_state(State.BOWLING)
		State.BOWLING:
			_process_bowling(delta)
		State.BELLY_JUMP_TELE:
			_warning.pulse(delta)
			if _state_time >= jump_tele_time * speed_k:
				_enter_state(State.BELLY_JUMP)
		State.BELLY_JUMP:
			_process_belly_jump(delta)
		State.HELICOPTER_TELE:
			if _state_time >= helicopter_tele_time * speed_k:
				_enter_state(State.HELICOPTER)
		State.HELICOPTER:
			_process_helicopter(delta)
		State.DIZZY:
			_process_dizzy(delta)

	_animate(delta)


func _process(delta: float) -> void:
	if not has_simulation_authority() and state != State.DYING:
		_state_time += delta
		_hud.set_health(health)
		if _warning.visible:
			_warning.pulse(delta)
	elif state == State.DYING and _dead:
		_process_dying(delta)


func _enter_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	_hit_done = false
	_hit_targets.clear()

	match state:
		State.EMERGE:
			global_position.y = _surface_y - 2.5
		State.WALK:
			_warning.hide_warning()
		State.BOWLING_TELE:
			velocity = Vector3.ZERO
			net_attack_point = global_position
			var target: Node3D = _update_target(0.0)
			if target != null:
				var to: Vector3 = target.global_position - global_position
				to.y = 0.0
				net_attack_dir = to.normalized() if to.length() > 0.1 else -transform.basis.z
			else:
				net_attack_dir = -transform.basis.z
			_warning.show_line(global_position, net_attack_dir, 18.0, 2.0)
		State.BOWLING:
			_warning.hide_warning()
		State.BELLY_JUMP_TELE:
			velocity = Vector3.ZERO
			var target: Node3D = _update_target(0.0)
			net_attack_point = target.global_position if target != null else global_position
			_warning.show_circle(net_attack_point, JUMP_RADIUS)
		State.BELLY_JUMP:
			_warning.hide_warning()
			var to: Vector3 = net_attack_point - global_position
			to.y = 0.0
			var dist: float = to.length()
			var j_dir: Vector3 = to.normalized() if dist > 0.1 else Vector3.ZERO
			velocity = j_dir * (dist / 0.8) + Vector3.UP * 7.5
			SFX.play_at(SFX.EMERGE_SAND, global_position, 4.0)
		State.HELICOPTER_TELE:
			velocity = Vector3.ZERO
			_warning.hide_warning()
		State.HELICOPTER:
			_warning.hide_warning()
			SFX.play_at(SFX.SPRAY, global_position, 3.0)
		State.DIZZY:
			_warning.hide_warning()
			velocity = Vector3.ZERO
			SFX.play_at(SFX.SHELL_KNOCK, global_position, 5.0)


func _process_walk(delta: float) -> void:
	_apply_gravity(delta)
	var target: Node3D = _update_target(delta)
	if target == null:
		velocity.x = move_toward(velocity.x, 0.0, delta * 4.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 4.0)
		move_and_slide()
		return

	var to: Vector3 = target.global_position - global_position
	to.y = 0.0
	var dist: float = to.length()
	var dir: Vector3 = to.normalized() if dist > 0.1 else Vector3.ZERO

	_turn_towards(dir, 0.0, turn_speed, delta)

	# Ciclo de 3 ataques cómicos
	if _state_time >= 2.0:
		_attack_cycle += 1
		match _attack_cycle % 3:
			1:
				_enter_state(State.BOWLING_TELE)
			2:
				_enter_state(State.BELLY_JUMP_TELE)
			0:
				_enter_state(State.HELICOPTER_TELE)
		return

	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	move_and_slide()


func _process_bowling(delta: float) -> void:
	_apply_gravity(delta)
	move_and_slide()

	if not _hit_done and _state_time >= 0.1:
		_hit_done = true
		_execute_bowling()

	if _state_time >= 0.7:
		_enter_state(State.WALK)


func _execute_bowling() -> void:
	SFX.play_at(SFX.STONE_IMPACT, global_position, 6.0)
	var count: int = 2 if phase == 2 else 1
	for i: int in count:
		var ang: float = 0.0 if count == 1 else (-0.25 + float(i) * 0.5)
		var b_dir: Vector3 = net_attack_dir.rotated(Vector3.UP, ang).normalized()
		_spawn_bowling_ball(global_position + Vector3.UP * 0.5 + b_dir * 1.5, b_dir)


func _spawn_bowling_ball(spawn_pos: Vector3, dir: Vector3) -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyMesh.prism(st, Vector3(0.0, -0.6, 0.0), Vector3(0.0, 0.6, 0.0), 0.75, 0.75, 8, SNOW_BALL)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = ToonKit.commit(st)
	mi.material_override = _mat
	mi.top_level = true
	mi.global_position = spawn_pos
	add_child(mi)

	_bowling_balls.append(mi)
	_ball_dirs.append(dir)


func _update_bowling_balls(delta: float) -> void:
	for i: int in range(_bowling_balls.size() - 1, -1, -1):
		var ball: MeshInstance3D = _bowling_balls[i]
		if not is_instance_valid(ball):
			_bowling_balls.remove_at(i)
			_ball_dirs.remove_at(i)
			continue

		var dir: Vector3 = _ball_dirs[i]
		ball.global_position += dir * BOWLING_SPEED * delta
		ball.rotate(dir.cross(Vector3.UP).normalized(), 12.0 * delta)

		for p: Node3D in _all_players():
			if p.global_position.distance_squared_to(ball.global_position) <= 2.25:
				_deal_damage(p, bowling_damage)
				_knockback(p, dir * 14.0 + Vector3.UP * 5.0, 0.2)
				spawn_particles(ball.global_position, SNOW_BALL, 18, 4.0)

		if ball.global_position.distance_squared_to(global_position) > 600.0:
			ball.queue_free()
			_bowling_balls.remove_at(i)
			_ball_dirs.remove_at(i)


func _process_belly_jump(delta: float) -> void:
	_apply_gravity(delta)
	move_and_slide()

	if is_on_floor() and _state_time > 0.2 and not _hit_done:
		_hit_done = true
		SFX.play_at(SFX.EMERGE_SAND, global_position, 8.0)
		spawn_particles(global_position, SNOW_BALL, 30, 6.0)

		for p: Node3D in _players_within(global_position, JUMP_RADIUS):
			_deal_damage(p, jump_damage)
			var away: Vector3 = p.global_position - global_position
			away.y = 0.0
			var push: Vector3 = away.normalized() if away.length() > 0.1 else Vector3.FORWARD
			_knockback(p, push * 10.0 + Vector3.UP * 8.0, 0.25)

	if _state_time >= 1.2:
		_enter_state(State.WALK)


func _process_helicopter(delta: float) -> void:
	_apply_gravity(delta)
	var target: Node3D = _update_target(delta)
	var spd: float = helicopter_speed * (1.25 if phase == 2 else 1.0)
	if target != null:
		var to: Vector3 = target.global_position - global_position
		to.y = 0.0
		var dir: Vector3 = to.normalized() if to.length() > 0.1 else Vector3.ZERO
		_turn_towards(dir, 0.0, turn_speed * 1.5, delta)
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd

	move_and_slide()

	# Dano por contacto com os braços giratórios
	for p: Node3D in _all_players():
		if _hit_targets.has(p):
			continue
		var d: Vector3 = p.global_position - global_position
		d.y = 0.0
		if d.length() <= HELICOPTER_RADIUS:
			_hit_targets.append(p)
			_deal_damage(p, helicopter_damage)
			var out: Vector3 = d.normalized() if d.length() > 0.1 else transform.basis.z
			var side: Vector3 = out.cross(Vector3.UP)
			_knockback(p, (out + side * 0.8).normalized() * 12.0 + Vector3.UP * 4.0, 0.1)

	# Limpa lista de alvos periodicamente para poder bater de novo durante o giro
	if fmod(_state_time, 0.6) < delta:
		_hit_targets.clear()

	if _state_time >= helicopter_time:
		_enter_state(State.DIZZY)


func _process_dizzy(delta: float) -> void:
	_apply_gravity(delta)
	velocity = Vector3.ZERO
	move_and_slide()
	if _state_time >= dizzy_time:
		_enter_state(State.WALK)


func is_weak_point_exposed() -> bool:
	return state == State.DIZZY


func _modify_damage(amount: float, _from: Vector3) -> float:
	if is_weak_point_exposed():
		return amount * WEAK_POINT_FACTOR
	return amount


func _can_take_damage() -> bool:
	return state != State.EMERGE and state != State.DYING


func _can_be_stunned() -> bool:
	return state == State.WALK or state == State.DIZZY


func flee_from(_origin: Vector3, _seconds: float) -> void:
	pass


func take_damage(amount: float, from: Vector3 = Vector3.INF) -> void:
	super.take_damage(amount, from)
	if _dead or not has_simulation_authority():
		return
	_hud.set_health(health)
	health_changed.emit(health, max_health)

	if phase == 1 and health < max_health * PHASE_TWO_RATIO:
		phase = 2
		spawn_particles(global_position + Vector3.UP * 1.5, FUR_SHADOW, 30, 5.0)


func wake_immediately() -> void:
	if state == State.EMERGE:
		global_position.y = _surface_y
		_hud.visible = true
		_enter_state(State.WALK)


func _on_died() -> void:
	_hud.set_health(0.0)
	_enter_state(State.DYING)
	set_physics_process(false)


func _process_dying(_delta: float) -> void:
	var t: float = clampf(_state_time / 2.5, 0.0, 1.0)
	_body.position.y = -2.0 * t * t
	_body.rotation.z = lerpf(0.0, 0.4, t)

	if _state_time >= 1.2 and _state_time - get_process_delta_time() < 1.2:
		_hud.visible = false
		spawn_particles(global_position + Vector3.UP * 1.5, FUR_WHITE, 50, 6.0)
		if has_simulation_authority():
			QuestRewards.drop_item(get_tree(), TROPHY_ITEM_ID, global_position + Vector3.UP * 1.5)
		boss_defeated.emit(BOSS_ID)

	if _state_time >= 3.0:
		for b: MeshInstance3D in _bowling_balls:
			if is_instance_valid(b):
				b.queue_free()
		queue_free()


func _report_defeat_to_core(boss_id: StringName) -> void:
	if has_simulation_authority() and GameState.instance != null:
		GameState.instance.request_report_boss_defeated(String(boss_id))


func _refresh_remote_visuals() -> void:
	if _warning == null:
		return
	match state:
		State.BOWLING_TELE:
			_warning.show_line(global_position, net_attack_dir, 18.0, 2.0)
		State.BELLY_JUMP_TELE:
			_warning.show_circle(net_attack_point, JUMP_RADIUS)
		_:
			_warning.hide_warning()


func _on_remote_state(new_state: int) -> void:
	state = new_state as State
	_state_time = 0.0
	_hud.visible = state != State.EMERGE and state != State.DYING
	_refresh_remote_visuals()


# ---------------------------------------------------------------------------
# Modelo 3D Low-Poly + ToonKit (referência: yeti.jpg)
# ---------------------------------------------------------------------------

func _build_model() -> void:
	_mat = ToonKit.vertex_material(true, true)
	_register_flash_material(_mat)

	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Tronco volumoso e corcunda com pelos brancos
	LowPolyMesh.prism(st, Vector3(0.0, 0.6, 0.0), Vector3(0.0, 1.45, 0.0), 0.72, 0.88, 7, FUR_WHITE)
	# Corcunda dorsal
	LowPolyMesh.box(st, Vector3(0.0, 1.35, 0.35), Vector3(1.1, 0.8, 0.6), Basis.IDENTITY, FUR_SHADOW)

	# Ombros largos e peludos
	LowPolyMesh.box(st, Vector3(0.0, 1.5, 0.0), Vector3(1.7, 0.6, 0.8), Basis.IDENTITY, FUR_WHITE)

	# Cabeça com pelos espetados
	LowPolyMesh.prism(st, Vector3(0.0, 1.65, -0.2), Vector3(0.0, 2.15, -0.2), 0.55, 0.40, 6, FUR_WHITE)

	# Rosto azul-acinzentado (referência: yeti.jpg)
	LowPolyMesh.box(st, Vector3(0.0, 1.82, -0.58), Vector3(0.55, 0.48, 0.15), Basis.IDENTITY, SKIN_BLUE)

	# Dois dentes inferiores salientes cómicos
	LowPolyMesh.prism(st, Vector3(-0.10, 1.66, -0.66), Vector3(-0.10, 1.76, -0.66), 0.04, 0.01, 3, TOOTH_WHITE)
	LowPolyMesh.prism(st, Vector3(0.10, 1.66, -0.66), Vector3(0.10, 1.76, -0.66), 0.04, 0.01, 3, TOOTH_WHITE)

	# Olhos arregalados "How to Fish"
	LowPolyMesh.box(st, Vector3(-0.16, 1.95, -0.66), Vector3(0.14, 0.14, 0.05), Basis.IDENTITY, EYE_WHITE)
	LowPolyMesh.box(st, Vector3(0.16, 1.95, -0.66), Vector3(0.14, 0.14, 0.05), Basis.IDENTITY, EYE_WHITE)
	LowPolyMesh.box(st, Vector3(-0.16, 1.95, -0.69), Vector3(0.06, 0.06, 0.02), Basis.IDENTITY, EYE_PUPIL)
	LowPolyMesh.box(st, Vector3(0.16, 1.95, -0.69), Vector3(0.06, 0.06, 0.02), Basis.IDENTITY, EYE_PUPIL)

	# Pernas peludas curtas e pés largos azuis
	for s: float in [-1.0, 1.0]:
		LowPolyMesh.prism(st, Vector3(0.42 * s, 0.6, 0.0), Vector3(0.42 * s, 0.15, 0.0), 0.28, 0.22, 5, FUR_WHITE)
		LowPolyMesh.box(st, Vector3(0.42 * s, 0.08, -0.15), Vector3(0.35, 0.14, 0.52), Basis.IDENTITY, SKIN_BLUE)

	_body.add_child(LowPolyMesh.commit(st, "MainMesh", _mat))

	# Braços longos articulados
	_arm_left = _build_arm(-0.95, "ArmL")
	_arm_right = _build_arm(0.95, "ArmR")

	# Garrafa térmica vermelha icónica com tampa prateada presa ao cinto/mão
	_thermos = Node3D.new()
	_thermos.name = "Thermos"
	_thermos.position = Vector3(0.35, 0.95, -0.55)
	var st_th: SurfaceTool = SurfaceTool.new()
	st_th.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Corpo vermelho
	LowPolyMesh.prism(st_th, Vector3(0.0, -0.22, 0.0), Vector3(0.0, 0.15, 0.0), 0.12, 0.12, 6, THERMOS_RED)
	# Tampa prateada
	LowPolyMesh.prism(st_th, Vector3(0.0, 0.15, 0.0), Vector3(0.0, 0.28, 0.0), 0.10, 0.09, 6, THERMOS_SILVER)
	_thermos.add_child(LowPolyMesh.commit(st_th, "ThermosMesh", _mat))
	_body.add_child(_thermos)

	# Collision Shape
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(1.8, 2.2, 1.5)
	cs.shape = box
	cs.position = Vector3(0.0, 1.1, 0.0)
	add_child(cs)


func _build_arm(x: float, arm_name: String) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.name = arm_name
	pivot.position = Vector3(x, 1.45, 0.0)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s: float = -1.0 if x < 0.0 else 1.0
	# Braço peludo
	LowPolyMesh.prism(st, Vector3(0.0, 0.0, 0.0), Vector3(s * 0.15, -0.65, 0.0), 0.25, 0.20, 5, FUR_WHITE)
	# Antebraço e mão azul
	LowPolyMesh.prism(st, Vector3(s * 0.15, -0.65, 0.0), Vector3(s * 0.2, -1.15, 0.0), 0.20, 0.16, 5, SKIN_BLUE)
	LowPolyMesh.box(st, Vector3(s * 0.22, -1.25, -0.05), Vector3(0.28, 0.22, 0.32), Basis.IDENTITY, SKIN_BLUE)
	pivot.add_child(LowPolyMesh.commit(st, "ArmMesh", _mat))
	_body.add_child(pivot)
	return pivot


func _animate(delta: float) -> void:
	if _body == null:
		return

	if state == State.WALK:
		var step: float = sin(_anim_time * 5.0)
		_body.rotation.z = step * 0.08
		_body.rotation.x = lerp_angle(_body.rotation.x, 0.15, clampf(6.0 * delta, 0.0, 1.0))
		_body.position.y = absf(sin(_anim_time * 5.0)) * 0.08
		if _arm_left != null:
			_arm_left.rotation.x = step * 0.6
		if _arm_right != null:
			_arm_right.rotation.x = -step * 0.6
	elif state == State.BOWLING_TELE:
		# Puxa o braço direito para trás em pose de bowling
		_body.rotation.x = 0.2
		if _arm_right != null:
			_arm_right.rotation.x = -1.5
		if _arm_left != null:
			_arm_left.rotation.x = 0.5
	elif state == State.BOWLING:
		# Lança a bola para a frente
		_body.rotation.x = -0.1
		if _arm_right != null:
			_arm_right.rotation.x = 0.8
	elif state == State.BELLY_JUMP_TELE:
		# Agacha para o salto
		_body.position.y = -0.3
		_body.rotation.x = 0.25
	elif state == State.BELLY_JUMP:
		# No ar com braços e pernas abertos
		_body.rotation.x = -0.4
		if _arm_left != null:
			_arm_left.rotation.z = -1.2
		if _arm_right != null:
			_arm_right.rotation.z = 1.2
	elif state == State.HELICOPTER_TELE:
		# Abre os braços
		if _arm_left != null:
			_arm_left.rotation.z = -1.57
		if _arm_right != null:
			_arm_right.rotation.z = 1.57
	elif state == State.HELICOPTER:
		# Gira o corpo todo ou os braços como hélice desgovernada!
		_body.rotation.y += 18.0 * delta
		if _arm_left != null:
			_arm_left.rotation.z = -1.57
		if _arm_right != null:
			_arm_right.rotation.z = 1.57
	elif state == State.DIZZY:
		# Tonto, oscilando de um lado para o outro com a cabeça caída
		_body.rotation.x = 0.25
		_body.rotation.z = sin(_anim_time * 5.0) * 0.35
		_body.rotation.y = lerp_angle(_body.rotation.y, 0.0, clampf(4.0 * delta, 0.0, 1.0))
		if _arm_left != null:
			_arm_left.rotation.z = sin(_anim_time * 4.0) * 0.2
			_arm_left.rotation.x = 0.0
		if _arm_right != null:
			_arm_right.rotation.z = -sin(_anim_time * 4.0) * 0.2
			_arm_right.rotation.x = 0.0
