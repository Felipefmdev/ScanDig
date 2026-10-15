class_name CrowKing
extends EnemyBase

## Corvo-Rei (#41): chefe adicional da missão da Dona Lurdes, sobre a lavoura do Campo.
## Voa em círculos alto à volta do sítio onde nasceu (só o estilingue lhe chega), escolhe o
## jogador mais próximo, paira por cima dele com um círculo vermelho no chão e mergulha
## (DIVE_RADIUS). Depois do mergulho fica no chão GROUNDED_TIME s, atordoado: é aí que a pá
## lhe chega e o dano conta a dobrar. Chama corvos aos 66 % e 33 %; na fase 2 (vida < 50 %)
## circula menos tempo. Ao morrer cai e larga a Pena do Corvo-Rei.
## Coop (#24): IA no host; ponto do mergulho (net_attack_point) e estado vão para os clientes.

signal boss_defeated(boss_id: StringName)
signal health_changed(current: float, max_value: float)

enum State { ARRIVE, CIRCLE, TELEGRAPH, DIVE, GROUNDED, TAKEOFF, DYING }

const BOSS_ID: StringName = &"crow_king"
const BOSS_NAME: String = "CORVO-REI"
const GROUP_BOSSES: StringName = &"bosses"
const TROPHY_ITEM_ID: String = "pena_corvo_rei"
const DIVE_RADIUS: float = 2.2
const WEAK_POINT_MULTIPLIER: float = 2.0
const REINFORCE_THRESHOLDS: Array[float] = [0.66, 0.33]
const PHASE_TWO_RATIO: float = 0.5
const MODEL_SCALE: float = 3.2

const BLACK: Color = Color(0.1, 0.1, 0.13)
const BLUE_BLACK: Color = Color(0.17, 0.19, 0.3)
const TIP: Color = Color(0.05, 0.05, 0.07)
const BEAK: Color = Color(0.3, 0.29, 0.28)
const GOLD: Color = Color(1.0, 0.78, 0.18)
const EYE_RED: Color = Color(0.95, 0.15, 0.1)

@export var dive_damage: float = 20.0
@export var circle_radius: float = 7.0
@export var circle_height: float = 7.0
@export var circle_time: float = 3.5
@export var telegraph_time: float = 1.2
@export var grounded_time: float = 2.0
@export var fly_speed: float = 7.0
@export var attack_range: float = 22.0

var state: State = State.ARRIVE
var phase: int = 1
var net_attack_point: Vector3 = Vector3.ZERO:
	set(value):
		net_attack_point = value
		if not has_simulation_authority():
			_refresh_remote_visuals()

var _state_time: float = 0.0
var _home: Vector3 = Vector3.ZERO
var _ground_y: float = 0.0
var _orbit: float = 0.0
var _dive_from: Vector3 = Vector3.ZERO
var _hit_done: bool = false
var _reinforce_index: int = 0
var _hud: BossHud = null
var _warning: GroundWarning = null
var _wing_left: Node3D = null
var _wing_right: Node3D = null
var _flap: float = 0.0


func _ready() -> void:
	super._ready()
	add_to_group(GROUP_BOSSES)
	stun_fx_height = 1.6
	death_color = BLACK
	_home = global_position
	_ground_y = _ground_height(global_position, global_position.y)
	_build_model()
	_hud = BossHud.create("👑 " + BOSS_NAME, max_health, Color(0.35, 0.3, 0.55))
	add_child(_hud)
	_warning = GroundWarning.new()
	add_child(_warning)
	boss_defeated.connect(_report_defeat_to_core)
	if has_simulation_authority():
		# Chega do alto, a voar para o círculo.
		global_position = _home + Vector3(0.0, circle_height + 10.0, 18.0)
	_enter_state(State.ARRIVE)


func setup_network() -> void:
	super.setup_network()
	_add_synced_property(".:net_attack_point")


func _enemy_physics(delta: float) -> void:
	_state_time += delta
	match state:
		State.ARRIVE:
			var goal: Vector3 = _orbit_point()
			_fly_to(goal, fly_speed * 1.6, delta)
			if global_position.distance_to(goal) < 1.0 or _state_time > 6.0:
				_hud.visible = true
				_enter_state(State.CIRCLE)
		State.CIRCLE:
			_orbit += delta * (fly_speed / circle_radius)
			_fly_to(_orbit_point(), fly_speed, delta)
			if _state_time >= circle_time * (0.65 if phase == 2 else 1.0):
				_start_dive()
		State.TELEGRAPH:
			_fly_to(net_attack_point + Vector3.UP * 5.0, fly_speed * 1.4, delta)
			_warning.pulse(delta)
			if _state_time >= telegraph_time:
				_dive_from = global_position
				_enter_state(State.DIVE)
		State.DIVE:
			var t: float = clampf(_state_time / 0.4, 0.0, 1.0)
			global_position = _dive_from.lerp(net_attack_point + Vector3.UP * 0.3, t * t)
			if t >= 1.0 and not _hit_done:
				_hit_done = true
				_dive_impact()
				_enter_state(State.GROUNDED)
		State.GROUNDED:
			if _state_time >= grounded_time:
				_enter_state(State.TAKEOFF)
		State.TAKEOFF:
			_fly_to(_orbit_point(), fly_speed, delta)
			if _state_time >= 1.4:
				_enter_state(State.CIRCLE)


func _process(delta: float) -> void:
	_animate(delta)
	if state == State.DYING and _dead:
		_state_time += delta
		_process_dying(delta)
	elif not has_simulation_authority():
		_hud.set_health(health)
		if state == State.TELEGRAPH:
			_warning.pulse(delta)


func _enter_state(s: State) -> void:
	state = s
	_state_time = 0.0
	match s:
		State.TELEGRAPH:
			_warning.show_circle(net_attack_point, DIVE_RADIUS)
		State.DIVE:
			_hit_done = false
			_warning.hide_warning()
		State.CIRCLE, State.TAKEOFF, State.GROUNDED:
			_warning.hide_warning()


func _orbit_point() -> Vector3:
	return _home + Vector3(cos(_orbit) * circle_radius, circle_height, sin(_orbit) * circle_radius)


func _start_dive() -> void:
	var target: Node3D = _update_target(0.0)
	if target == null or target.global_position.distance_to(_home) > attack_range:
		_state_time = 0.0
		return
	# Os pés do jogador (um raio ao chão bateria no próprio jogador, que está na camada 1).
	net_attack_point = target.global_position
	SFX.play_at(SFX.SEAGULL_DIVE, global_position, 4.0)
	_enter_state(State.TELEGRAPH)


func _dive_impact() -> void:
	spawn_particles(net_attack_point + Vector3.UP * 0.1, Color(0.4, 0.3, 0.2), 22, 3.5)
	SFX.play_at(SFX.EMERGE_SAND, net_attack_point, 4.0)
	var players: Array[Node] = get_tree().get_nodes_in_group(&"players")
	if players.is_empty():
		players = get_tree().get_nodes_in_group(&"player")
	for n: Node in players:
		var pl: Node3D = n as Node3D
		if pl == null:
			continue
		var d: Vector3 = pl.global_position - net_attack_point
		d.y = 0.0
		if d.length() <= DIVE_RADIUS:
			_deal_damage(pl, dive_damage)


func _fly_to(goal: Vector3, speed: float, delta: float) -> void:
	var to: Vector3 = goal - global_position
	if to.length() > 0.05:
		global_position += to.normalized() * minf(speed * delta, to.length())
	var flat: Vector3 = Vector3(to.x, 0.0, to.z)
	if flat.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-flat.x, -flat.z), clampf(4.0 * delta, 0.0, 1.0))


# ---------------------------------------------------------------------------
# Regras de combate
# ---------------------------------------------------------------------------

func is_phase_two() -> bool:
	return health < max_health * PHASE_TWO_RATIO


func is_weak_point_exposed() -> bool:
	return state == State.GROUNDED


func _can_take_damage() -> bool:
	return state != State.ARRIVE and state != State.DYING


func _can_be_stunned() -> bool:
	return state == State.GROUNDED


func _modify_damage(amount: float, _from: Vector3) -> float:
	return amount * WEAK_POINT_MULTIPLIER if is_weak_point_exposed() else amount


## O repelente não afeta o rei.
func flee_from(_origin: Vector3, _seconds: float) -> void:
	pass


func take_damage(amount: float, from: Vector3 = Vector3.INF) -> void:
	super.take_damage(amount, from)
	if _dead or not has_simulation_authority():
		return
	_hud.set_health(health)
	health_changed.emit(health, max_health)
	var ratio: float = health / max_health
	while _reinforce_index < REINFORCE_THRESHOLDS.size() and ratio <= REINFORCE_THRESHOLDS[_reinforce_index]:
		_reinforce_index += 1
		for i: int in 2:
			var ang: float = randf() * TAU
			var pos: Vector3 = _home + Vector3(cos(ang) * 6.0, 0.0, sin(ang) * 6.0)
			_spawn_minion(&"crow", Vector3(pos.x, _ground_height(pos, _ground_y) + 4.0, pos.z))
	if phase == 1 and is_phase_two():
		phase = 2


## Testes/debug: começa já a circular.
func wake_immediately() -> void:
	if state == State.ARRIVE:
		global_position = _orbit_point()
		_hud.visible = true
		_enter_state(State.CIRCLE)


func _on_died() -> void:
	_hud.set_health(0.0)
	_set_stun_fx(false)
	_warning.hide_warning()
	_enter_state(State.DYING)
	set_physics_process(false)


func _process_dying(delta: float) -> void:
	if global_position.y > _ground_y + 0.4:
		global_position.y = maxf(global_position.y - 9.0 * delta, _ground_y + 0.4)
	rotation.z = lerpf(rotation.z, 1.3, clampf(3.0 * delta, 0.0, 1.0))
	if _state_time >= 1.2 and _state_time - delta < 1.2:
		_hud.visible = false
		if has_simulation_authority():
			QuestRewards.drop_item(get_tree(), TROPHY_ITEM_ID, Vector3(global_position.x, _ground_y + 1.2, global_position.z))
		boss_defeated.emit(BOSS_ID)
	if _state_time >= 2.6:
		spawn_particles(global_position + Vector3.UP * 0.5, death_color, 40, 4.0)
		queue_free()


func _report_defeat_to_core(boss_id: StringName) -> void:
	if has_simulation_authority() and GameState.instance != null:
		GameState.instance.request_report_boss_defeated(String(boss_id))


## Cliente: estado/ponto replicados.
func _on_remote_state(new_state: int) -> void:
	_state_time = 0.0
	_hud.visible = new_state != State.ARRIVE and new_state != State.DYING
	_refresh_remote_visuals()


func _refresh_remote_visuals() -> void:
	if state == State.TELEGRAPH:
		_warning.show_circle(net_attack_point, DIVE_RADIUS)
	else:
		_warning.hide_warning()


# ---------------------------------------------------------------------------
# Modelo e animação
# ---------------------------------------------------------------------------

func _animate(delta: float) -> void:
	if _wing_left == null:
		return
	var freq: float = 6.0
	var amp: float = 0.35
	match state as State:
		State.DIVE:
			freq = 0.0
			amp = 0.0
		State.GROUNDED:
			freq = 14.0
			amp = 0.15
		State.TELEGRAPH, State.TAKEOFF:
			freq = 10.0
			amp = 0.5
		State.DYING:
			freq = 18.0
			amp = 0.2
	_flap += delta * freq
	var f: float = sin(_flap) * amp
	var tuck: float = 0.7 if state == State.DIVE else 0.0
	_wing_left.rotation = Vector3(0.0, -tuck, f)
	_wing_right.rotation = Vector3(0.0, tuck, -f)


func _build_model() -> void:
	var mat: ShaderMaterial = LowPolyMesh.make_material()
	_register_flash_material(mat)
	var s: float = MODEL_SCALE
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyMesh.prism(st, Vector3(0.0, 0.0, 0.26) * s, Vector3(0.0, 0.03, -0.2) * s, 0.12 * s, 0.14 * s, 7, BLACK)
	for k: int in 5:
		var a: float = (float(k) - 2.0) * 0.22
		LowPolyMesh.box(st, Vector3(sin(a) * 0.1, 0.02, 0.42) * s, Vector3(0.07, 0.02, 0.26) * s, Basis(Vector3.UP, a), TIP)
	LowPolyMesh.box(st, Vector3(0.0, 0.11, -0.28) * s, Vector3(0.17, 0.16, 0.17) * s, Basis.IDENTITY, BLUE_BLACK)
	# Olhos vermelhos esbugalhados e bico grosso
	for side: float in [-1.0, 1.0]:
		LowPolyMesh.box(st, Vector3(0.088 * side, 0.14, -0.31) * s, Vector3(0.02, 0.07, 0.07) * s, Basis.IDENTITY,
			Color(EYE_RED.r, EYE_RED.g, EYE_RED.b, 0.0))
	LowPolyMesh.prism(st, Vector3(0.0, 0.09, -0.36) * s, Vector3(0.0, 0.06, -0.55) * s, 0.05 * s, 0.0, 4, BEAK)
	# Coroa dourada
	var crown: Vector3 = Vector3(0.0, 0.2, -0.27) * s
	var g: Color = Color(GOLD.r, GOLD.g, GOLD.b, 0.0)
	LowPolyMesh.prism(st, crown, crown + Vector3(0.0, 0.05 * s, 0.0), 0.08 * s, 0.09 * s, 6, g)
	for k: int in 5:
		var ang: float = TAU * float(k) / 5.0
		var b: Vector3 = crown + Vector3(cos(ang) * 0.075 * s, 0.05 * s, sin(ang) * 0.075 * s)
		LowPolyMesh.prism(st, b, b + Vector3(0.0, 0.07 * s, 0.0), 0.022 * s, 0.0, 4, g)
	# Patas com garras
	for side: float in [-1.0, 1.0]:
		LowPolyMesh.prism(st, Vector3(0.05 * side, -0.08, 0.1) * s, Vector3(0.06 * side, -0.2, 0.08) * s, 0.012 * s, 0.01 * s, 4, BEAK)
		LowPolyMesh.box(st, Vector3(0.06 * side, -0.21, 0.04) * s, Vector3(0.06, 0.015, 0.08) * s, Basis.IDENTITY, BEAK)
	var body: MeshInstance3D = LowPolyMesh.commit(st, "Body", mat)
	add_child(body)
	_wing_left = _build_wing(-1.0, mat)
	_wing_right = _build_wing(1.0, mat)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(1.6, 1.2, 2.2)
	shape.shape = box
	shape.position = Vector3(0.0, 0.1, 0.0)
	add_child(shape)


func _build_wing(side: float, mat: Material) -> Node3D:
	var s: float = MODEL_SCALE
	var pivot: Node3D = Node3D.new()
	pivot.name = "WingLeft" if side < 0.0 else "WingRight"
	pivot.position = Vector3(0.1 * side, 0.06, -0.02) * s
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyMesh.box(st, Vector3(0.22 * side, 0.0, 0.0) * s, Vector3(0.44, 0.03, 0.26) * s, Basis.IDENTITY, BLUE_BLACK)
	for k: int in 4:
		LowPolyMesh.box(st, Vector3((0.52 + 0.03 * k) * side, 0.0, -0.08 + 0.07 * k) * s, Vector3(0.24, 0.02, 0.06) * s,
			Basis(Vector3.UP, (0.08 + 0.12 * k) * side), TIP)
	pivot.add_child(LowPolyMesh.commit(st, "Mesh", mat))
	add_child(pivot)
	return pivot
