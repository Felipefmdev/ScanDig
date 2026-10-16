class_name IdolMummy
extends EnemyBase

## Múmia do Ídolo (#42, #57): chefe escondido das Ruínas, desperta na cripta ao colocar
## o Ídolo de Jade no pedestal antigo. Estilo How to Fish (caos cómico, tudo telegrafado):
##   - PUXÃO DE LIGADURAS: estende faixas compridas que agarram e arrastam o jogador até ela;
##   - ENXAME / INVOCAÇÃO: estremece e solta morcegos das sombras acompanhados de escaravelhos;
##   - TORNADO DE LIGADURAS: gira feito um pião desgovernado, varrendo a sala; no fim fica TONTA
##     e exposta com ligaduras a desfraldar (DIZZY_TIME s, dano a 2,5x).
## Fase 2 (vida < 50 %): movimentos acelerados, puxão mais voraz e morcegos adicionais.
## Troféu ao morrer: 'ligaduras_mumia'.
## Coop (#24): IA no host; estado, ponto e direção do ataque replicados.

signal boss_defeated(boss_id: StringName)
signal health_changed(current: float, max_value: float)

enum State { EMERGE, WALK, PULL_TELE, PULL, SUMMON_TELE, SUMMON, TORNADO_TELE, TORNADO, DIZZY, DYING }

const BOSS_ID: StringName = &"idol_mummy"
const BOSS_NAME: String = "MÚMIA DO ÍDOLO"
const GROUP_BOSSES: StringName = &"bosses"
const TROPHY_ITEM_ID: String = "ligaduras_mumia"

const WEAK_POINT_MULTIPLIER: float = 2.5
const PHASE_TWO_RATIO: float = 0.5
const PULL_RANGE: float = 16.0
const PULL_WIDTH: float = 2.2
const TORNADO_RADIUS: float = 2.8
const SUMMON_RADIUS: float = 4.0

const LINEN: Color = Color("#b8945a")
const LINEN_MID: Color = Color("#a07a44")
const LINEN_DARK: Color = Color("#7a5a30")
const GOLD: Color = Color("#e8b830")
const GOLD_DARK: Color = Color("#a87818")
const JADE: Color = Color("#3ad070")
const JADE_DARK: Color = Color("#1a7a3a")
const EYE_GREEN: Color = Color("#c8f070")
## Brilho do ídolo: sempre aceso como na referência, mais forte quando a múmia fica tonta.
const AMULET_GLOW: Color = Color(0.15, 0.65, 0.25)
const AMULET_GLOW_EXPOSED: Color = Color(0.5, 1.0, 0.6)
## Pose de descanso do braço direito: garra levantada à frente da cara.
const CLAW_REST: Vector3 = Vector3(0.25, 0.0, 0.2)
const SCARAB_BLUE: Color = Color(0.18, 0.38, 0.78)

@export var move_speed: float = 1.9
@export var turn_speed: float = 3.5
@export var pull_damage: float = 16.0
@export var pull_force: float = 16.0
@export var tornado_damage: float = 22.0
@export var tornado_speed: float = 5.2
@export var summon_damage: float = 10.0
@export var pull_telegraph: float = 1.1
@export var summon_telegraph: float = 1.2
@export var tornado_telegraph: float = 1.0
@export var tornado_time: float = 3.4
@export var dizzy_time: float = 3.2
@export var emerge_time: float = 2.2
@export var attack_cooldown: float = 1.4

var state: State = State.EMERGE
var phase: int = 1
var net_attack_point: Vector3 = Vector3.ZERO:
	set(value):
		net_attack_point = value
		# O synchronizer aplica as props ao nascer, antes do _ready (sem _warning ainda)
		if not has_simulation_authority() and is_node_ready():
			_refresh_remote_visuals()

var net_attack_dir: Vector3 = Vector3.FORWARD:
	set(value):
		net_attack_dir = value
		# O synchronizer aplica as props ao nascer, antes do _ready (sem _warning ainda)
		if not has_simulation_authority() and is_node_ready():
			_refresh_remote_visuals()

var _state_time: float = 0.0
var _cooldown: float = 0.8
var _summon_timer: float = 4.0
var _attack_cycle: int = 0
var _surface_y: float = 0.0
var _hit_done: bool = false
var _hit_list: Array[Node] = []
var _anim_time: float = 0.0

var _hud: BossHud = null
var _warning: GroundWarning = null
var _body_root: Node3D = null
var _torso: Node3D = null
var _arm_left: Node3D = null
var _arm_right: Node3D = null
var _head: Node3D = null
var _ribbons: Array[Node3D] = []
var _pull_bandages: Node3D = null
var _amulet_mat: ShaderMaterial = null
var _glow_mat: ShaderMaterial = null


func _ready() -> void:
	super._ready()
	add_to_group(GROUP_BOSSES)
	stun_fx_height = 2.5
	death_color = LINEN
	_surface_y = global_position.y
	_build_model()
	_hud = BossHud.create("📜 " + BOSS_NAME, max_health, Color(0.92, 0.78, 0.42))
	add_child(_hud)
	_warning = GroundWarning.new()
	add_child(_warning)
	boss_defeated.connect(_report_defeat_to_core)
	_enter_state(State.EMERGE)
	if not has_simulation_authority():
		_refresh_remote_visuals()


func setup_network() -> void:
	super.setup_network()
	_add_synced_property(".:net_attack_point")
	_add_synced_property(".:net_attack_dir")


func _enemy_physics(delta: float) -> void:
	_state_time += delta
	var speed_k: float = 0.8 if phase == 2 else 1.0
	match state:
		State.EMERGE:
			var t: float = clampf(_state_time / emerge_time, 0.0, 1.0)
			global_position.y = _surface_y - 3.0 * (1.0 - t)
			if t >= 1.0:
				_hud.visible = true
				_enter_state(State.WALK)
		State.WALK:
			_process_walk(delta)
		State.PULL_TELE:
			_warning.pulse(delta)
			_face(net_attack_dir, delta)
			if _state_time >= pull_telegraph * speed_k:
				_enter_state(State.PULL)
		State.PULL:
			if not _hit_done and _state_time >= 0.15:
				_hit_done = true
				_execute_pull()
			if _state_time >= 0.7:
				_enter_state(State.WALK)
		State.SUMMON_TELE:
			_warning.pulse(delta)
			if _state_time >= summon_telegraph * speed_k:
				_enter_state(State.SUMMON)
		State.SUMMON:
			if not _hit_done and _state_time >= 0.1:
				_hit_done = true
				_execute_summon()
			if _state_time >= 0.8:
				_enter_state(State.WALK)
		State.TORNADO_TELE:
			_warning.pulse(delta)
			if _state_time >= tornado_telegraph * speed_k:
				_enter_state(State.TORNADO)
		State.TORNADO:
			_process_tornado(delta)
		State.DIZZY:
			if _state_time >= dizzy_time:
				_cooldown = attack_cooldown
				_enter_state(State.WALK)


func _process(delta: float) -> void:
	_anim_time += delta
	_animate(delta)
	if state == State.DYING and _dead:
		_state_time += delta
		_process_dying()
	elif not has_simulation_authority():
		_state_time += delta
		_hud.set_health(health)
		if _warning.visible:
			_warning.pulse(delta)


# ---------------------------------------------------------------------------
# Estados e Ataques
# ---------------------------------------------------------------------------

func _enter_state(s: State) -> void:
	state = s
	_state_time = 0.0
	_hit_done = false
	_hit_list.clear()
	match s:
		State.EMERGE:
			_surface_y = global_position.y
			global_position.y = _surface_y - 3.0
			collision_layer = 0
		State.WALK:
			collision_layer = 8
			_warning.hide_warning()
			if _pull_bandages != null:
				_pull_bandages.visible = false
		State.PULL_TELE:
			_warning.show_line(global_position, net_attack_dir, PULL_RANGE, PULL_WIDTH)
		State.PULL:
			_warning.hide_warning()
			if _pull_bandages != null:
				_pull_bandages.visible = true
			SFX.play_at(SFX.SHELL_KNOCK, global_position, 6.0)
		State.SUMMON_TELE:
			_warning.show_circle(global_position, SUMMON_RADIUS)
		State.SUMMON:
			_warning.hide_warning()
			SFX.play_at(SFX.EMERGE_SAND, global_position, 7.0)
		State.TORNADO_TELE:
			_warning.show_circle(global_position, TORNADO_RADIUS)
		State.TORNADO:
			_warning.hide_warning()
		State.DIZZY:
			_warning.hide_warning()
			SFX.play_at(SFX.SHELL_KNOCK, global_position, 5.0)
	_refresh_visuals()


func _process_walk(delta: float) -> void:
	_apply_gravity(delta)
	var target: Node3D = _update_target(delta)
	_cooldown -= delta
	_summon_timer -= delta
	if target == null:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	var to: Vector3 = target.global_position - global_position
	to.y = 0.0
	var dist: float = to.length()
	var dir: Vector3 = to / dist if dist > 0.01 else Vector3.FORWARD
	_face(dir, delta)
	if _cooldown <= 0.0:
		_attack_cycle += 1
		net_attack_dir = dir
		net_attack_point = global_position
		if _summon_timer <= 0.0:
			_summon_timer = 12.0 if phase == 1 else 9.0
			_enter_state(State.SUMMON_TELE)
			return
		if _attack_cycle % 3 == 0:
			_enter_state(State.TORNADO_TELE)
			return
		if dist <= PULL_RANGE:
			_enter_state(State.PULL_TELE)
			return
	var spd: float = move_speed * (1.25 if phase == 2 else 1.0)
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	move_and_slide()


func _execute_pull() -> void:
	spawn_particles(global_position + Vector3.UP * 1.2, LINEN, 20, 4.0)
	for p: Node3D in _all_players():
		var to: Vector3 = p.global_position - global_position
		to.y = 0.0
		var dist: float = to.length()
		if dist <= PULL_RANGE:
			var forward_dot: float = to.normalized().dot(net_attack_dir)
			if forward_dot > 0.7:
				_deal_damage(p, pull_damage)
				var drag_dir: Vector3 = (global_position - p.global_position).normalized()
				_knockback(p, drag_dir * pull_force + Vector3.UP * 4.5, 0.12)
				spawn_particles(p.global_position + Vector3.UP * 0.8, LINEN, 15, 3.0)


func _execute_summon() -> void:
	spawn_particles(global_position + Vector3.UP * 0.5, SCARAB_BLUE, 30, 4.5)
	var count: int = 3 if phase == 2 else 2
	for i: int in count:
		var ang: float = randf() * TAU
		var offset: Vector3 = Vector3(cos(ang) * 4.0, 2.5, sin(ang) * 4.0)
		_spawn_minion(&"bat", global_position + offset)
	for p: Node3D in _all_players():
		var d: Vector3 = p.global_position - global_position
		d.y = 0.0
		if d.length() <= SUMMON_RADIUS:
			_deal_damage(p, summon_damage)
			_knockback(p, d.normalized() * 6.0 + Vector3.UP * 3.0, 0.06)


func _process_tornado(delta: float) -> void:
	_apply_gravity(delta)
	var target: Node3D = _update_target(delta)
	var spd: float = tornado_speed * (1.25 if phase == 2 else 1.0)
	if target != null:
		var to: Vector3 = target.global_position - global_position
		to.y = 0.0
		var dir: Vector3 = to.normalized() if to.length() > 0.1 else Vector3.ZERO
		velocity.x = dir.x * spd
		velocity.z = dir.z * spd
	move_and_slide()
	for p: Node3D in _all_players():
		var d: Vector3 = p.global_position - global_position
		d.y = 0.0
		if d.length() <= TORNADO_RADIUS and not _hit_list.has(p):
			_hit_list.append(p)
			_deal_damage(p, tornado_damage)
			var out: Vector3 = d.normalized() if d.length() > 0.1 else Vector3.FORWARD
			var side: Vector3 = out.cross(Vector3.UP)
			_knockback(p, (out + side * 0.7).normalized() * 15.0 + Vector3.UP * 7.0, 0.1)
	if fmod(_state_time, 0.7) < delta:
		_hit_list.clear()
	if _state_time >= tornado_time:
		velocity = Vector3.ZERO
		_enter_state(State.DIZZY)


func _face(dir: Vector3, delta: float) -> void:
	_turn_towards(dir, 0.0, turn_speed, delta)


func _spawn_minion(kind: StringName, pos: Vector3) -> Node3D:
	return super._spawn_minion(kind, pos)


# ---------------------------------------------------------------------------
# Regras de combate
# ---------------------------------------------------------------------------

func is_phase_two() -> bool:
	return health < max_health * PHASE_TWO_RATIO


func is_weak_point_exposed() -> bool:
	return state == State.DIZZY


func _can_take_damage() -> bool:
	return state != State.EMERGE and state != State.DYING


func _can_be_stunned() -> bool:
	return state == State.WALK or state == State.DIZZY


func _modify_damage(amount: float, _from: Vector3) -> float:
	return amount * WEAK_POINT_MULTIPLIER if is_weak_point_exposed() else amount


func flee_from(_origin: Vector3, _seconds: float) -> void:
	pass


func take_damage(amount: float, from: Vector3 = Vector3.INF) -> void:
	super.take_damage(amount, from)
	if _dead or not has_simulation_authority():
		return
	_hud.set_health(health)
	health_changed.emit(health, max_health)
	if phase == 1 and is_phase_two():
		phase = 2
		spawn_particles(global_position + Vector3.UP * 1.5, GOLD, 25, 4.0)


func wake_immediately() -> void:
	if state == State.EMERGE:
		global_position.y = _surface_y
		_hud.visible = true
		_enter_state(State.WALK)


func _on_died() -> void:
	_hud.set_health(0.0)
	_set_stun_fx(false)
	_warning.hide_warning()
	_enter_state(State.DYING)
	set_physics_process(false)


var _death_done: bool = false


func _process_dying() -> void:
	var t: float = clampf(_state_time / 2.0, 0.0, 1.0)
	_body_root.position.y = lerpf(0.0, -1.8, t * t)
	_body_root.rotation.x = lerpf(0.0, -1.2, t)
	if not _death_done and _state_time >= 1.0:
		_death_done = true
		_hud.visible = false
		spawn_particles(global_position + Vector3.UP * 1.0, LINEN, 45, 4.5)
		if has_simulation_authority():
			QuestRewards.drop_item(get_tree(), TROPHY_ITEM_ID, global_position + Vector3.UP * 1.5)
		boss_defeated.emit(BOSS_ID)
	if _state_time >= 2.5:
		queue_free()


func _report_defeat_to_core(boss_id: StringName) -> void:
	if has_simulation_authority() and GameState.instance != null:
		GameState.instance.request_report_boss_defeated(String(boss_id))


func _on_remote_state(new_state: int) -> void:
	_state_time = 0.0
	_hud.visible = new_state != State.EMERGE and new_state != State.DYING
	_refresh_remote_visuals()


func _refresh_visuals() -> void:
	match state:
		State.PULL_TELE:
			_warning.show_line(global_position, net_attack_dir, PULL_RANGE, PULL_WIDTH)
		State.SUMMON_TELE:
			_warning.show_circle(global_position, SUMMON_RADIUS)
		State.TORNADO_TELE:
			_warning.show_circle(global_position, TORNADO_RADIUS)
		_:
			_warning.hide_warning()
	if _amulet_mat != null:
		var exposed: bool = state == State.DIZZY
		_amulet_mat.set_shader_parameter(&"emission_color", AMULET_GLOW_EXPOSED if exposed else AMULET_GLOW)


func _refresh_remote_visuals() -> void:
	_refresh_visuals()


# ---------------------------------------------------------------------------
# Animação e modelo procedimental
# ---------------------------------------------------------------------------

func _animate(delta: float) -> void:
	if _body_root == null:
		return
	var arm_x: float = 0.0
	var arm_z: float = 0.0
	var spin_speed: float = 0.0
	match state:
		State.WALK:
			arm_x = sin(_anim_time * 3.0) * 0.4
			_body_root.position.y = absf(sin(_anim_time * 5.0)) * 0.08
			_body_root.rotation.z = sin(_anim_time * 2.5) * 0.06
		State.PULL_TELE:
			arm_x = 1.57
			arm_z = 0.2
		State.PULL:
			arm_x = 1.7
			arm_z = 0.1
		State.SUMMON_TELE, State.SUMMON:
			arm_x = -2.6
			arm_z = 0.5
			_body_root.rotation.x = sin(_anim_time * 18.0) * 0.1
		State.TORNADO_TELE:
			arm_x = -1.4
			arm_z = 0.8
			spin_speed = 3.0
		State.TORNADO:
			arm_x = -1.57
			arm_z = 1.1
			spin_speed = 18.0
		State.DIZZY:
			arm_x = 0.3
			arm_z = 0.3
			_body_root.rotation.z = sin(_anim_time * 6.5) * 0.25
			_body_root.position.y = -0.3
			if _head != null:
				_head.rotation.x = 0.4
				_head.rotation.y = sin(_anim_time * 5.0) * 0.4
	_body_root.rotation.y += spin_speed * delta
	if spin_speed == 0.0 and state != State.DIZZY and state != State.DYING:
		_body_root.rotation.y = lerp_angle(_body_root.rotation.y, 0.0, clampf(6.0 * delta, 0.0, 1.0))
		_body_root.rotation.z = lerpf(_body_root.rotation.z, 0.0, clampf(6.0 * delta, 0.0, 1.0))
	if _arm_left != null and _arm_right != null:
		_arm_left.rotation = Vector3(arm_x, 0.0, arm_z)
		_arm_right.rotation = Vector3(arm_x, 0.0, -arm_z)
		if state == State.EMERGE or state == State.WALK:
			_arm_right.rotation = CLAW_REST + Vector3(sin(_anim_time * 2.0) * 0.1, 0.0, 0.0)
	for i: int in _ribbons.size():
		var r: Node3D = _ribbons[i]
		if state == State.TORNADO:
			r.rotation.z = 1.3 * (1.0 if i % 2 == 0 else -1.0)
			r.rotation.x = sin(_anim_time * 15.0 + float(i)) * 0.4
		elif state == State.DIZZY:
			r.rotation.z = sin(_anim_time * 4.0 + float(i)) * 0.2
		else:
			r.rotation.x = sin(_anim_time * 4.0 + float(i)) * 0.25
	if _pull_bandages != null and _pull_bandages.visible:
		_pull_bandages.scale.z = lerpf(_pull_bandages.scale.z, PULL_RANGE * 0.5, clampf(14.0 * delta, 0.0, 1.0))


func _build_model() -> void:
	var mat: ShaderMaterial = ToonKit.vertex_material(true, true)
	_register_flash_material(mat)
	_glow_mat = ToonKit.vertex_material(true, true)
	_glow_mat.set_shader_parameter(&"emission_color", Color(0.25, 0.9, 0.35))

	var col: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.55
	cap.height = 2.2
	col.shape = cap
	col.position = Vector3(0.0, 1.1, 0.0)
	add_child(col)

	_body_root = Node3D.new()
	_body_root.name = "BodyRoot"
	add_child(_body_root)

	# Referência mumia_idolo.jpg: corcunda, ombros largos, braços enormes, tudo enrolado em
	# ligaduras às riscas (3 tons) com pontas soltas.
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Pernas curtas e afastadas
	for side: float in [-1.0, 1.0]:
		_wrap(st, Vector3(0.26 * side, 0.08, 0.02), Vector3(0.22 * side, 0.8, 0.0), 0.15, 0.19, 5, 1)
		LowPolyMesh.box(st, Vector3(0.27 * side, 0.07, -0.08), Vector3(0.24, 0.14, 0.34), Basis(Vector3.UP, 0.15 * side), LINEN_DARK)

	# Anca + tronco dobrado para a frente (corcunda)
	_torso = Node3D.new()
	_torso.name = "Torso"
	_body_root.add_child(_torso)
	_wrap(st, Vector3(0.0, 0.72, 0.02), Vector3(0.0, 1.05, -0.04), 0.34, 0.33, 2, 0)
	_wrap(st, Vector3(0.0, 1.0, -0.04), Vector3(0.0, 1.62, -0.3), 0.34, 0.46, 5, 2)
	# Bossa das costas
	_wrap(st, Vector3(0.0, 1.3, 0.12), Vector3(0.0, 1.62, 0.0), 0.3, 0.28, 2, 1)
	# Tanga de ligaduras rasgadas à frente
	for k: int in 3:
		var x: float = (float(k) - 1.0) * 0.14
		LowPolyMesh.prism(st, Vector3(x, 0.8, -0.3), Vector3(x + 0.02, 0.45 - 0.06 * float(k % 2), -0.34), 0.07, 0.02, 4, LINEN_MID if k == 1 else LINEN_DARK)
	# Faixas diagonais por cima das riscas
	for k: int in 4:
		var y: float = 0.9 + 0.17 * float(k)
		var z: float = -0.3 - 0.07 * float(k)
		LowPolyMesh.box(st, Vector3(0.0, y, z), Vector3(0.62, 0.05, 0.03), Basis(Vector3.FORWARD, 0.35 if k % 2 == 0 else -0.3), LINEN_DARK)

	# Cabeça baixa e projetada à frente
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0.0, 1.6, -0.42)
	_body_root.add_child(_head)
	var hst: SurfaceTool = SurfaceTool.new()
	hst.begin(Mesh.PRIMITIVE_TRIANGLES)
	_wrap(hst, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.42, 0.02), 0.2, 0.19, 3, 0)
	# Boca aberta com um dente
	LowPolyMesh.box(hst, Vector3(0.0, 0.1, -0.19), Vector3(0.18, 0.09, 0.02), Basis.IDENTITY, Color(0.2, 0.1, 0.08))
	LowPolyMesh.box(hst, Vector3(-0.03, 0.135, -0.2), Vector3(0.04, 0.035, 0.02), Basis.IDENTITY, Color(0.95, 0.92, 0.8))
	# Coroa de ouro com pontas
	LowPolyMesh.prism(hst, Vector3(0.0, 0.38, 0.02), Vector3(0.0, 0.47, 0.02), 0.21, 0.22, 8, GOLD)
	for k: int in 5:
		var a: float = TAU * float(k) / 5.0
		var base: Vector3 = Vector3(sin(a) * 0.17, 0.46, 0.02 + cos(a) * 0.17)
		LowPolyMesh.prism(hst, base, base + Vector3(0.0, 0.15, 0.0), 0.06, 0.0, 4, GOLD)
	_head.add_child(LowPolyMesh.commit(hst, "HeadMesh", mat))
	# Olhos grandes, verdes e brilhantes (material próprio com emissão)
	var est: SurfaceTool = SurfaceTool.new()
	est.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-1.0, 1.0]:
		LowPolyMesh.prism(est, Vector3(0.085 * side, 0.27, -0.15), Vector3(0.085 * side, 0.27, -0.24), 0.07, 0.07, 8, EYE_GREEN)
		LowPolyMesh.box(est, Vector3(0.085 * side, 0.27, -0.245), Vector3(0.035, 0.035, 0.01), Basis.IDENTITY, Color(0.04, 0.05, 0.03))
	_head.add_child(LowPolyMesh.commit(est, "Eyes", _glow_mat))

	# Braços grandes (pendem até aos joelhos): esquerdo de punho, direito em garra levantada
	_arm_left = _build_arm(-1.0, mat)
	_arm_right = _build_arm(1.0, mat)
	_arm_right.rotation = CLAW_REST

	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "BodyMesh"
	mi.mesh = ToonKit.commit(st)
	mi.material_override = mat
	_body_root.add_child(mi)

	# Ídolo de jade no peito, com cara esculpida, a brilhar (mais forte quando tonta)
	var ast: SurfaceTool = SurfaceTool.new()
	ast.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ip: Vector3 = Vector3(0.0, 1.36, -0.66)
	var tilt: Basis = Basis(Vector3.RIGHT, 0.4)
	LowPolyMesh.box(ast, ip, Vector3(0.28, 0.34, 0.1), tilt, JADE)
	LowPolyMesh.box(ast, ip + tilt * Vector3(0.0, 0.17, 0.0), Vector3(0.28, 0.06, 0.07), tilt, JADE)
	for side: float in [-1.0, 1.0]:
		LowPolyMesh.box(ast, ip + tilt * Vector3(0.05 * side, 0.06, -0.04), Vector3(0.06, 0.04, 0.02), tilt, JADE_DARK)
	LowPolyMesh.box(ast, ip + tilt * Vector3(0.0, -0.01, -0.04), Vector3(0.03, 0.07, 0.02), tilt, JADE_DARK)
	LowPolyMesh.box(ast, ip + tilt * Vector3(0.0, -0.08, -0.04), Vector3(0.11, 0.03, 0.02), tilt, JADE_DARK)
	_amulet_mat = ToonKit.vertex_material(true, true)
	_amulet_mat.set_shader_parameter(&"emission_color", AMULET_GLOW)
	var amulet_mi: MeshInstance3D = MeshInstance3D.new()
	amulet_mi.name = "JadeAmulet"
	amulet_mi.mesh = ToonKit.commit(ast)
	amulet_mi.material_override = _amulet_mat
	_body_root.add_child(amulet_mi)

	# Pontas de ligadura soltas a pender da cintura e dos braços
	var anchors: Array[Vector3] = [
		Vector3(-0.3, 0.86, -0.22), Vector3(0.32, 0.84, -0.18), Vector3(0.05, 0.82, 0.3),
		Vector3(-0.2, 0.86, 0.26),
	]
	for i: int in anchors.size():
		_ribbons.append(_build_ribbon(_body_root, anchors[i], 0.45 + 0.1 * float(i % 2), mat, i))
	for arm: Node3D in [_arm_left, _arm_right]:
		_ribbons.append(_build_ribbon(arm, Vector3(0.1, -0.5, 0.05), 0.4, mat, _ribbons.size()))

	# Faixas estendidas no ataque PULL
	_pull_bandages = Node3D.new()
	_pull_bandages.name = "PullBandages"
	_pull_bandages.visible = false
	var pst: SurfaceTool = SurfaceTool.new()
	pst.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k: int in 3:
		var off_x: float = (float(k) - 1.0) * 0.35
		LowPolyMesh.box(pst, Vector3(off_x, 1.3, -1.0), Vector3(0.12, 0.04, 2.0), Basis.IDENTITY, LINEN)
	var pmi: MeshInstance3D = MeshInstance3D.new()
	pmi.mesh = ToonKit.commit(pst)
	pmi.material_override = mat
	_pull_bandages.add_child(pmi)
	_body_root.add_child(_pull_bandages)


## Membro enrolado em ligaduras: `bands` faixas alternando 3 tons, com o rebordo de cada uma
## ligeiramente mais largo (ar de tecido sobreposto). `phase` desfasa os tons entre peças.
func _wrap(st: SurfaceTool, p0: Vector3, p1: Vector3, r0: float, r1: float, bands: int, phase: int) -> void:
	var tones: Array[Color] = [LINEN, LINEN_MID, LINEN_DARK]
	for i: int in bands:
		var t0: float = float(i) / float(bands)
		var t1: float = float(i + 1) / float(bands)
		var c: Color = tones[(i + phase) % tones.size()]
		LowPolyMesh.prism(st, p0.lerp(p1, t0), p0.lerp(p1, t1), lerpf(r0, r1, t0) * 1.06, lerpf(r0, r1, t1), 7, c)


func _build_ribbon(parent: Node3D, at: Vector3, length: float, mat: Material, index: int) -> Node3D:
	var rib: Node3D = Node3D.new()
	rib.name = "Ribbon%d" % index
	rib.position = at
	var rst: SurfaceTool = SurfaceTool.new()
	rst.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Tira rasgada: dois troços e ponta em bico
	LowPolyMesh.box(rst, Vector3(0.0, -length * 0.3, 0.0), Vector3(0.09, length * 0.6, 0.025), Basis.IDENTITY, LINEN_MID)
	LowPolyMesh.box(rst, Vector3(0.015, -length * 0.75, 0.0), Vector3(0.07, length * 0.3, 0.025), Basis(Vector3.FORWARD, 0.15), LINEN_DARK)
	LowPolyMesh.prism(rst, Vector3(0.025, -length * 0.9, 0.0), Vector3(0.03, -length * 1.05, 0.0), 0.035, 0.0, 3, LINEN_DARK)
	var rmi: MeshInstance3D = MeshInstance3D.new()
	rmi.mesh = ToonKit.commit(rst)
	rmi.material_override = mat
	rib.add_child(rmi)
	parent.add_child(rib)
	return rib


func _build_arm(side: float, mat: Material) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.name = "ArmLeft" if side < 0.0 else "ArmRight"
	pivot.position = Vector3(0.5 * side, 1.52, -0.22)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyMesh.prism(st, Vector3(0.0, 0.08, 0.0), Vector3(0.0, -0.1, 0.0), 0.2, 0.2, 7, LINEN_DARK)
	if side < 0.0:
		# Braço esquerdo pendente até ao joelho, de punho fechado
		var elbow: Vector3 = Vector3(-0.04, -0.48, 0.0)
		var wrist: Vector3 = Vector3(-0.05, -0.95, -0.06)
		_wrap(st, Vector3.ZERO, elbow, 0.16, 0.15, 3, 1)
		_wrap(st, elbow, wrist, 0.17, 0.19, 3, 0)
		LowPolyMesh.prism(st, wrist + Vector3(0.0, 0.09, 0.01), wrist - Vector3(0.0, 0.03, 0.005), 0.215, 0.215, 8, GOLD)
		var hand: Vector3 = wrist + Vector3(0.0, -0.15, -0.01)
		LowPolyMesh.box(st, hand, Vector3(0.26, 0.24, 0.26), Basis.IDENTITY, LINEN_MID)
		LowPolyMesh.box(st, hand + Vector3(0.0, -0.06, -0.13), Vector3(0.24, 0.1, 0.05), Basis.IDENTITY, LINEN_DARK)
	else:
		# Braço direito dobrado: antebraço para cima, garra à altura da cara
		var elbow: Vector3 = Vector3(0.2, -0.42, -0.08)
		var wrist: Vector3 = Vector3(0.22, 0.02, -0.34)
		_wrap(st, Vector3.ZERO, elbow, 0.16, 0.15, 3, 1)
		_wrap(st, elbow, wrist, 0.17, 0.18, 3, 0)
		var up: Vector3 = (wrist - elbow).normalized()
		LowPolyMesh.prism(st, wrist - up * 0.1, wrist + up * 0.02, 0.21, 0.21, 8, GOLD)
		var hand: Vector3 = wrist + up * 0.12
		LowPolyMesh.box(st, hand, Vector3(0.22, 0.18, 0.12), Basis(Vector3.RIGHT, -0.8), LINEN_MID)
		for k: int in 4:
			var knuckle: Vector3 = hand + Vector3((float(k) - 1.5) * 0.055, 0.08, -0.02)
			var mid: Vector3 = knuckle + Vector3(0.0, 0.12, -0.03)
			LowPolyMesh.prism(st, knuckle, mid, 0.03, 0.026, 4, LINEN)
			LowPolyMesh.prism(st, mid, mid + Vector3(0.0, 0.04, -0.09), 0.026, 0.008, 4, LINEN_DARK)
		LowPolyMesh.prism(st, hand + Vector3(-0.12, 0.0, -0.02), hand + Vector3(-0.2, 0.08, -0.08), 0.03, 0.01, 4, LINEN)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = ToonKit.commit(st)
	mi.material_override = mat
	pivot.add_child(mi)
	_body_root.add_child(pivot)
	return pivot
