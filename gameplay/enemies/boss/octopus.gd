class_name Octopus
extends EnemyBase

## Polvo do Naufrágio (#40): chefe escondido da Praia. Acorda pelo BossTrigger quando as 3
## conchas tocam pela ordem certa e sai da água junto ao navio. Não anda: vira-se para o
## jogador mais próximo e ataca com tentáculos que rebentam do chão onde o jogador está
## (círculo vermelho telegrafado, SLAM_RADIUS). Depois de cada golpe o tentáculo fica preso e a
## cabeça fica exposta (dano a dobrar). Fase 2 (vida < 50 %): golpes mais rápidos, dois de cada
## vez, e chama caranguejos ao chegar a 66 % e 33 %. Ao morrer larga o Olho do Polvo.
## Caos (#57), intercalado com os golpes: HÉLICE (abre os 8 tentáculos e sai a rodar pela
## praia como um pião/helicóptero, atira quem apanha; acaba tonto e volta ao sítio), AGARRÃO
## (círculo; quem lá ficar é agarrado e atirado ao mar) e TINTA (faixa à frente; quem apanha
## fica com manchas de tinta no ecrã, Player.apply_ink) e ESCUDO DE TÁBUAS (ergue 3 tábuas do
## navio à frente: golpes de frente quase não contam; depois atira-as em leque, 3 faixas).
## Coop (#24): IA no host; o ponto do golpe (net_attack_point) e o estado vão para os clientes,
## que desenham o aviso e o tentáculo.

signal boss_defeated(boss_id: StringName)
signal health_changed(current: float, max_value: float)

enum State { EMERGE, IDLE, TELEGRAPH, SLAM, STUCK, DYING, SPIN_TELEGRAPH, SPIN, RETURN, GRAB_TELEGRAPH, GRAB, INK_TELEGRAPH, INK, SHIELD, PLANK_TELEGRAPH, PLANK_THROW }

const CrabModel := preload("res://gameplay/enemies/crab/crab_model.gd")
const BOSS_ID: StringName = &"octopus"
const BOSS_NAME: String = "POLVO DO NAUFRÁGIO"
const GROUP_BOSSES: StringName = &"bosses"
const TROPHY_ITEM_ID: String = "olho_do_polvo"
const SLAM_RADIUS: float = 1.9
const WEAK_POINT_MULTIPLIER: float = 2.0
const REINFORCE_THRESHOLDS: Array[float] = [0.66, 0.33]
const PHASE_TWO_RATIO: float = 0.5
const NET_STUN_CAP: float = 1.2
## #57: hélice, agarrão e tinta. A ordem dos ataques repete ATTACK_CYCLE.
const SPIN_RADIUS: float = 3.2
const SPIN_SPEED: float = 6.5
const GRAB_RADIUS: float = 1.8
const INK_LENGTH: float = 11.0
const INK_WIDTH: float = 3.0
const INK_SECONDS: float = 2.5
const ATTACK_CYCLE: Array[int] = [State.TELEGRAPH, State.SPIN_TELEGRAPH, State.TELEGRAPH, State.GRAB_TELEGRAPH, State.INK_TELEGRAPH, State.SHIELD]
## Tábuas do navio: escudo e leque atirado.
const PLANK_COUNT: int = 3
const PLANK_SPREAD: float = 0.38
const PLANK_LENGTH: float = 13.0
const PLANK_SPEED: float = 16.0
const PLANK_HIT_RADIUS: float = 1.0
const SHIELD_TIME: float = 3.0
## Fração do dano que passa pelo escudo (golpes de frente).
const SHIELD_FACTOR: float = 0.2
const WOOD: Color = Color(0.50, 0.33, 0.18)
const WOOD_DARK: Color = Color(0.36, 0.22, 0.12)
const WOOD_LIGHT: Color = Color(0.62, 0.44, 0.26)
const IRON: Color = Color(0.40, 0.42, 0.45)
const IRON_DARK: Color = Color(0.24, 0.25, 0.28)

const SKIN: Color = Color(0.70, 0.22, 0.42)
const SKIN_DARK: Color = Color(0.48, 0.12, 0.30)
const SUCKER: Color = Color(0.96, 0.84, 0.80)
const SUCKER_RIM: Color = Color(0.86, 0.70, 0.68)
const EYE_WHITE: Color = Color(0.98, 0.98, 0.94)
const EYE_LID: Color = Color(0.60, 0.18, 0.36)
const PUPIL: Color = Color(0.06, 0.06, 0.08)

const ANCHOR_RUST: Color = Color(0.74, 0.38, 0.16)
const ANCHOR_DARK: Color = Color(0.44, 0.22, 0.12)
const CHAIN_IRON: Color = Color(0.32, 0.30, 0.28)
const BARNACLE: Color = Color(0.88, 0.85, 0.74)
const BARNACLE_DARK: Color = Color(0.28, 0.25, 0.20)
const SPOT_CREAM: Color = Color(0.95, 0.88, 0.80)

@export var slam_damage: float = 18.0
@export var telegraph_time: float = 1.1
@export var stuck_time: float = 1.8
@export var idle_time: float = 1.4
@export var emerge_time: float = 2.2
@export var turn_speed: float = 2.0
## Distância máxima a que procura jogadores para atacar.
@export var attack_range: float = 14.0
@export var spin_damage: float = 12.0
@export var spin_time: float = 3.2
@export var grab_damage: float = 10.0
@export var ink_damage: float = 6.0
@export var plank_damage: float = 12.0

var state: State = State.EMERGE
var phase: int = 1
var net_attack_point: Vector3 = Vector3.ZERO:
	set(value):
		net_attack_point = value
		# O synchronizer aplica-o ao nascer, antes do _ready (avisos ainda por criar).
		if not has_simulation_authority() and is_node_ready():
			_refresh_remote_visuals()
var net_attack_dir: Vector3 = Vector3.FORWARD

var _state_time: float = 0.0
var _surface_y: float = 0.0
var _reinforce_index: int = 0
var _attack_points: Array[Vector3] = []
var _hit_done: bool = false
var _body_root: Node3D = null
var _tentacles: Array[Node3D] = []
var _slam_tentacles: Array[Node3D] = []
var _warnings: Array[GroundWarning] = []
var _hud: BossHud = null
var _health_bar: ProgressBar = null
var _anim_time: float = 0.0
var _home: Vector3 = Vector3.ZERO
var _cycle_index: int = 0
var _hit_list: Array[Node] = []
var _spin_dir: Vector3 = Vector3.ZERO
var _ink_fx: CPUParticles3D = null
var _planks: Array[Node3D] = []
var _plank_hit: Array[Node] = []
var _plank_warnings: Array[GroundWarning] = []


func _ready() -> void:
	super._ready()
	add_to_group(GROUP_BOSSES)
	stun_fx_height = 3.0
	death_color = SKIN
	_build_model()
	_build_hud()
	_build_planks()
	for i: int in 2:
		var w: GroundWarning = GroundWarning.new()
		add_child(w)
		_warnings.append(w)
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
	match state:
		State.EMERGE:
			_process_emerge()
		State.IDLE:
			_face_target(delta)
			if _state_time >= idle_time * (0.6 if phase == 2 else 1.0):
				_start_attack()
		State.TELEGRAPH:
			_pulse_warnings(delta)
			if _state_time >= telegraph_time * (0.8 if phase == 2 else 1.0):
				_enter_state(State.SLAM)
		State.SLAM:
			if not _hit_done and _state_time >= 0.12:
				_hit_done = true
				_do_slam_damage()
			if _state_time >= 0.35:
				_enter_state(State.STUCK)
		State.STUCK:
			if _state_time >= stuck_time:
				_enter_state(State.RETURN if _away_from_home() else State.IDLE)
		State.SPIN_TELEGRAPH, State.GRAB_TELEGRAPH, State.INK_TELEGRAPH:
			_pulse_warnings(delta)
			_face_point(net_attack_point, delta)
			if _state_time >= telegraph_time * (0.8 if phase == 2 else 1.0):
				_enter_state((state + 1) as State)
		State.SPIN:
			_process_spin(delta)
		State.RETURN:
			_process_return(delta)
		State.GRAB:
			if not _hit_done and _state_time >= 0.15:
				_hit_done = true
				_do_grab()
			if _state_time >= 0.6:
				_enter_state(State.STUCK)
		State.INK:
			if not _hit_done and _state_time >= 0.2:
				_hit_done = true
				_do_ink()
			if _state_time >= 0.9:
				_enter_state(State.IDLE)
		State.SHIELD:
			_face_target(delta)
			if _state_time >= SHIELD_TIME:
				var t: Node3D = _update_target(0.0)
				var to: Vector3 = (t.global_position - global_position) if t != null else -global_transform.basis.z
				to.y = 0.0
				net_attack_dir = to.normalized() if to.length_squared() > 0.01 else -global_transform.basis.z
				_enter_state(State.PLANK_TELEGRAPH)
		State.PLANK_TELEGRAPH:
			_pulse_warnings(delta)
			for w: GroundWarning in _plank_warnings:
				w.pulse(delta)
			_face_point(global_position + net_attack_dir, delta)
			if _state_time >= telegraph_time * (0.8 if phase == 2 else 1.0):
				_enter_state(State.PLANK_THROW)
		State.PLANK_THROW:
			_process_plank_throw()


func _process(delta: float) -> void:
	_anim_time += delta
	_animate(delta)
	_animate_planks(delta)
	if state == State.DYING and _dead:
		_state_time += delta
		_process_dying(delta)
	elif not has_simulation_authority():
		_health_bar.value = health
		_state_time += delta
		if state in [State.TELEGRAPH, State.SPIN_TELEGRAPH, State.GRAB_TELEGRAPH, State.INK_TELEGRAPH]:
			_pulse_warnings(delta)


# ---------------------------------------------------------------------------
# Estados
# ---------------------------------------------------------------------------

func _enter_state(s: State) -> void:
	state = s
	_state_time = 0.0
	match s:
		State.EMERGE:
			_surface_y = global_position.y
			_home = global_position
			global_position.y = _surface_y - 3.0
			SFX.play_at(SFX.EMERGE_SAND, global_position, 6.0)
		State.TELEGRAPH:
			_show_warnings()
		State.SLAM:
			_hit_done = false
			_hide_warnings()
			SFX.play_at(SFX.EMERGE_SAND, net_attack_point, 4.0)
		State.IDLE, State.RETURN:
			_hide_warnings()
		State.SPIN_TELEGRAPH:
			net_attack_point = _ground_point(global_position)
			_show_warnings()
		State.SPIN:
			_hide_warnings()
			_hit_list.clear()
			_attack_points.clear()
			var to_t: Vector3 = net_attack_dir
			_spin_dir = Vector3(to_t.x, 0.0, to_t.z).normalized()
			SFX.play_at(SFX.EMERGE_SAND, global_position, 4.0)
		State.GRAB_TELEGRAPH, State.INK_TELEGRAPH:
			_show_warnings()
		State.GRAB, State.INK:
			_hit_done = false
			_hide_warnings()
		State.SHIELD:
			_hide_warnings()
			SFX.play_at(SFX.SHELL_KNOCK, global_position, 3.0)
		State.PLANK_THROW:
			_plank_hit.clear()
			SFX.play_at(SFX.EMERGE_SAND, global_position, 4.0)
	_refresh_plank_warnings()
	_refresh_slam_tentacles()


func _process_emerge() -> void:
	var t: float = clampf(_state_time / emerge_time, 0.0, 1.0)
	global_position.y = _surface_y - 3.0 * (1.0 - (1.0 - pow(1.0 - t, 3.0)))
	if t >= 1.0:
		global_position.y = _surface_y
		_hud.visible = true
		_enter_state(State.IDLE)


## Próximo ataque do ciclo (#57); público para os testes.
func next_attack() -> State:
	var s: State = ATTACK_CYCLE[_cycle_index % ATTACK_CYCLE.size()] as State
	_cycle_index += 1
	return s


func _start_attack() -> void:
	var target: Node3D = _update_target(0.0)
	if target == null or target.global_position.distance_to(global_position) > attack_range:
		_state_time = 0.0
		return
	var kind: State = next_attack()
	if kind != State.TELEGRAPH:
		var to: Vector3 = target.global_position - global_position
		to.y = 0.0
		net_attack_dir = to.normalized() if to.length_squared() > 0.01 else -global_transform.basis.z
		_attack_points = [target.global_position]
		net_attack_point = target.global_position
		_enter_state(kind)
		return
	_attack_points.clear()
	# Os pés do jogador (um raio ao chão bateria no próprio jogador, que está na camada 1).
	_attack_points.append(target.global_position)
	if phase == 2:
		# Segundo golpe a cortar a fuga: um pouco à frente do jogador, para o lado.
		var side: Vector3 = (target.global_position - global_position).cross(Vector3.UP).normalized()
		_attack_points.append(_ground_point(target.global_position + side * 2.4))
	net_attack_point = _attack_points[0]
	_enter_state(State.TELEGRAPH)


func _do_slam_damage() -> void:
	for p: Vector3 in _attack_points:
		spawn_particles(p + Vector3.UP * 0.1, Color(0.85, 0.74, 0.5), 18, 3.0)
		# "players" = todos (coop); sem ele (testes antigos), o jogador local em "player".
		var players: Array[Node] = get_tree().get_nodes_in_group(&"players")
		if players.is_empty():
			players = get_tree().get_nodes_in_group(&"player")
		for n: Node in players:
			var pl: Node3D = n as Node3D
			if pl == null:
				continue
			var d: Vector3 = pl.global_position - p
			d.y = 0.0
			if d.length() <= SLAM_RADIUS:
				_deal_damage(pl, slam_damage)


func _process_dying(delta: float) -> void:
	var t: float = clampf(_state_time / 2.5, 0.0, 1.0)
	global_position.y = _surface_y - 3.0 * t * t
	if _state_time >= 1.0 and _state_time - delta < 1.0:
		_drop_trophy()
	if _state_time >= 2.6:
		spawn_particles(global_position + Vector3.UP * 1.5, death_color, 40, 4.0)
		queue_free()


# ---------------------------------------------------------------------------
# Regras de combate
# ---------------------------------------------------------------------------

func is_phase_two() -> bool:
	return health < max_health * PHASE_TWO_RATIO


func is_weak_point_exposed() -> bool:
	return state == State.STUCK


func _can_take_damage() -> bool:
	return state != State.EMERGE and state != State.DYING


func _can_be_stunned() -> bool:
	return state != State.EMERGE and state != State.DYING


func _modify_damage(amount: float, from: Vector3) -> float:
	if is_shielded_from(from):
		return amount * SHIELD_FACTOR
	return amount * WEAK_POINT_MULTIPLIER if is_weak_point_exposed() else amount


## Escudo de tábuas: só tapa a frente (cone de ~120°); por trás/pelos lados entra tudo.
func is_shielded_from(from: Vector3) -> bool:
	if state != State.SHIELD and state != State.PLANK_TELEGRAPH:
		return false
	if not from.is_finite():
		return true
	var d: Vector3 = from - global_position
	d.y = 0.0
	if d.length_squared() < 0.01:
		return true
	return d.normalized().dot(-global_transform.basis.z) > 0.5


func stun(seconds: float) -> void:
	super.stun(minf(seconds, NET_STUN_CAP))


## O repelente não afeta o polvo.
func flee_from(_origin: Vector3, _seconds: float) -> void:
	pass


func take_damage(amount: float, from: Vector3 = Vector3.INF) -> void:
	super.take_damage(amount, from)
	if _dead or not has_simulation_authority():
		return
	_health_bar.value = health
	health_changed.emit(health, max_health)
	var ratio: float = health / max_health
	while _reinforce_index < REINFORCE_THRESHOLDS.size() and ratio <= REINFORCE_THRESHOLDS[_reinforce_index]:
		_reinforce_index += 1
		_call_reinforcements()
	if phase == 1 and is_phase_two():
		phase = 2


## Começa já acordado (testes / debug).
func wake_immediately() -> void:
	if state == State.EMERGE:
		global_position.y = _surface_y
		_hud.visible = true
		_enter_state(State.IDLE)


func _call_reinforcements() -> void:
	for i: int in 2:
		var ang: float = randf() * TAU
		var pos: Vector3 = Vector3(global_position.x, _surface_y, global_position.z) + Vector3(cos(ang), 0.0, sin(ang)) * 4.0
		pos = _ground_point(pos)
		if _spawn_minion(&"crab", pos) == null:
			var scene: PackedScene = EnemySpawner.scene_for_kind(&"crab")
			if scene != null and get_parent() != null:
				var crab: Node3D = scene.instantiate() as Node3D
				get_parent().add_child(crab)
				crab.global_position = pos


func _on_died() -> void:
	_health_bar.value = 0.0
	_set_stun_fx(false)
	_enter_state(State.DYING)
	set_physics_process(false)


func _drop_trophy() -> void:
	_hud.visible = false
	if has_simulation_authority():
		QuestRewards.drop_item(get_tree(), TROPHY_ITEM_ID, Vector3(global_position.x, _surface_y + 1.5, global_position.z),
			Vector3(randf_range(-0.6, 0.6), 3.0, randf_range(-0.6, 0.6)) - global_transform.basis.z * 2.0)
	boss_defeated.emit(BOSS_ID)


## O core aceita "octopus" (EXTRA_BOSSES, #45); só o host reporta.
func _report_defeat_to_core(boss_id: StringName) -> void:
	if has_simulation_authority() and GameState.instance != null:
		GameState.instance.request_report_boss_defeated(String(boss_id))


func _face_target(delta: float) -> void:
	var t: Node3D = _update_target(delta)
	if t == null:
		return
	var to: Vector3 = t.global_position - global_position
	to.y = 0.0
	if to.length_squared() > 0.01:
		_turn_towards(to.normalized(), 0.0, turn_speed, delta)


func _ground_point(p: Vector3) -> Vector3:
	return Vector3(p.x, _ground_height(p, _surface_y), p.z)


## Cliente: estado chegou pelo synchronizer.
func _on_remote_state(new_state: int) -> void:
	_state_time = 0.0
	if new_state != State.EMERGE:
		_hud.visible = new_state != State.DYING
	_refresh_remote_visuals()


func _refresh_remote_visuals() -> void:
	_attack_points = [net_attack_point]
	_refresh_plank_warnings()
	if state in [State.TELEGRAPH, State.SPIN_TELEGRAPH, State.GRAB_TELEGRAPH, State.INK_TELEGRAPH]:
		_show_warnings()
	else:
		_hide_warnings()
	_refresh_slam_tentacles()


# ---------------------------------------------------------------------------
# Avisos e tentáculos de golpe
# ---------------------------------------------------------------------------

func _show_warnings() -> void:
	match state:
		State.SPIN_TELEGRAPH:
			_warnings[0].show_circle(net_attack_point, SPIN_RADIUS)
			_warnings[1].show_line(net_attack_point, net_attack_dir, 9.0, SPIN_RADIUS * 2.0)
			return
		State.GRAB_TELEGRAPH:
			_warnings[0].show_circle(net_attack_point, GRAB_RADIUS)
			_warnings[1].hide_warning()
			return
		State.INK_TELEGRAPH:
			_warnings[0].show_line(_ground_point(global_position), net_attack_dir, INK_LENGTH, INK_WIDTH)
			_warnings[1].hide_warning()
			return
	for i: int in _warnings.size():
		if i < _attack_points.size():
			_warnings[i].show_circle(_attack_points[i], SLAM_RADIUS)
		else:
			_warnings[i].hide_warning()


func _hide_warnings() -> void:
	for w: GroundWarning in _warnings:
		w.hide_warning()


func _pulse_warnings(delta: float) -> void:
	for w: GroundWarning in _warnings:
		if w.visible:
			w.pulse(delta)


## O tentáculo do golpe sai do chão no ponto atacado (SLAM: cai; STUCK: fica preso).
func _refresh_slam_tentacles() -> void:
	for i: int in _slam_tentacles.size():
		var t: Node3D = _slam_tentacles[i]
		var grabbing: bool = i == 0 and (state == State.GRAB_TELEGRAPH or state == State.GRAB)
		var on: bool = grabbing or ((state == State.SLAM or state == State.STUCK) and i < _attack_points.size())
		t.visible = on
		if on:
			var p: Vector3 = net_attack_point if grabbing else _attack_points[i]
			var away: Vector3 = p - global_position
			away.y = 0.0
			var yaw: float = atan2(away.x, away.z) if away.length_squared() > 0.01 else 0.0
			t.global_transform = Transform3D(Basis(Vector3.UP, yaw), p)
			t.scale = Vector3.ONE * 0.2 if state == State.SLAM or state == State.GRAB_TELEGRAPH else Vector3.ONE


func _animate(delta: float) -> void:
	if _body_root == null:
		return
	# Respira e abana os tentáculos à volta da cabeça
	var breathe: float = 1.0 + sin(_anim_time * 2.0) * 0.03
	_body_root.scale = Vector3(breathe, 1.0 / breathe, breathe)
	var spinning: bool = state == State.SPIN or state == State.SPIN_TELEGRAPH
	for i: int in _tentacles.size():
		var tt: Node3D = _tentacles[i]
		var rest: float = -0.35 + sin(_anim_time * 2.2 + float(i) * 1.1) * 0.25
		# Hélice: tentáculos esticados na horizontal (+ ondulação), o corpo a rodar.
		var target_x: float = 0.25 + sin(_anim_time * 20.0 + float(i)) * 0.08 if spinning else rest
		tt.rotation.x = lerpf(tt.rotation.x, target_x, clampf(delta * 10.0, 0.0, 1.0))
	if state == State.SPIN:
		_body_root.rotation.y += delta * 16.0
	elif state == State.SPIN_TELEGRAPH:
		_body_root.rotation.y += delta * 5.0 * clampf(_state_time / telegraph_time, 0.0, 1.0)
	elif state == State.STUCK and _away_from_home():
		_body_root.rotation.z = sin(_anim_time * 9.0) * 0.18
	else:
		_body_root.rotation.y = lerp_angle(_body_root.rotation.y, 0.0, clampf(delta * 4.0, 0.0, 1.0))
		_body_root.rotation.z = lerpf(_body_root.rotation.z, 0.0, clampf(delta * 4.0, 0.0, 1.0))
	if state == State.INK_TELEGRAPH:
		# Incha antes de cuspir
		_body_root.scale *= 1.0 + clampf(_state_time / telegraph_time, 0.0, 1.0) * 0.15
	for t: Node3D in _slam_tentacles:
		if t.visible and t.scale.x < 1.0:
			t.scale = t.scale.lerp(Vector3.ONE, minf(delta * 18.0, 1.0))


# ---------------------------------------------------------------------------
# Modelo low-poly toon e HUD
# ---------------------------------------------------------------------------

func _build_model() -> void:
	var mat: ShaderMaterial = ToonKit.vertex_material(true, true)
	mat.set_shader_parameter(&"spots_amount", 0.5)
	mat.set_shader_parameter(&"spots_color", Color(0.86, 0.48, 0.62))
	mat.set_shader_parameter(&"spots_scale", 4.0)
	mat.set_shader_parameter(&"spots_size", 0.2)
	_register_flash_material(mat)
	_body_root = Node3D.new()
	_body_root.name = "BodyRoot"
	add_child(_body_root)

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_build_shipwreck(st)
	_build_head_and_eyes(st)
	_build_anchor(st)
	_body_root.add_child(_commit(st, "HeadAndWreckage", mat))

	# 8 tentáculos à volta (cada um num nó pivot para abanar)
	for i: int in 8:
		var ang: float = TAU * float(i) / 8.0 + 0.2
		var pivot: Node3D = Node3D.new()
		pivot.position = Vector3(cos(ang) * 0.95, 1.05, sin(ang) * 0.95)
		pivot.rotation.y = -ang + PI * 0.5
		_body_root.add_child(pivot)
		var mode: int = 0
		# Tentáculo no bordo de bombordo (+X) erguido sobre a amurada como na referência
		if i == 1:
			mode = 1
		elif i == 5:
			mode = 2
		pivot.add_child(_commit(_tentacle_mesh(2.6, 0.38, false, mode), "Mesh", mat))
		_tentacles.append(pivot)

	# Tentáculos de golpe (saem do chão no ponto atacado)
	for i: int in 2:
		var slam: Node3D = Node3D.new()
		slam.name = "SlamTentacle%d" % i
		slam.top_level = true
		slam.visible = false
		add_child(slam)
		var m: MeshInstance3D = _commit(_tentacle_mesh(2.8, 0.40, true), "Mesh", mat)
		slam.add_child(m)
		_slam_tentacles.append(slam)

	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(2.6, 3.2, 2.6)
	shape.shape = box
	shape.position = Vector3(0.0, 1.8, 0.0)
	add_child(shape)


func _build_shipwreck(st: SurfaceTool) -> void:
	# O casco do barco rodeia o polvo, com a proa partida erguida à esquerda (vista frontal = +X)
	# e o mastro partido à direita (-X) como na referência polvo_naufragio.jpg
	var plank_count: int = 16
	for i: int in range(plank_count):
		var a0: float = -2.7 + float(i) * 0.34
		var a1: float = a0 + 0.30
		# Raio assimétrico em forma de casco de navio (mais alongado no comprimento)
		var rx: float = 2.45 + (0.5 if cos(a0) > 0.0 else -0.1)
		var rz: float = 2.05 + sin(a0) * 0.35
		# Proa erguida no lado esquerdo (+X, -Z)
		var bow_lift: float = maxf(0.0, cos(a0) * 1.2 - sin(a0) * 0.5)
		var p0: Vector3 = Vector3(cos(a0) * rx, 0.2 + bow_lift * 0.9, sin(a0) * rz)
		var p1: Vector3 = Vector3(cos(a1) * rx, 0.2 + bow_lift * 0.9, sin(a1) * rz)
		var p_mid: Vector3 = (p0 + p1) * 0.5
		var plank_len: float = (p1 - p0).length() + 0.08
		var plank_basis: Basis = Basis(Vector3.UP, atan2(p1.x - p0.x, p1.z - p0.z))
		var timber_col: Color = WOOD if i % 2 == 0 else (WOOD_DARK if i % 3 == 0 else WOOD_LIGHT)

		# Costado / tábua principal
		LowPolyMesh.box(st, p_mid, Vector3(0.14, 0.55, plank_len), plank_basis, timber_col)
		# Tábua inferior do casco
		LowPolyMesh.box(st, p_mid - Vector3(0.0, 0.38, 0.0), Vector3(0.12, 0.42, plank_len), plank_basis, WOOD_DARK)
		# Tábua superior irregular / lascada
		LowPolyMesh.box(st, p_mid + Vector3(0.0, 0.42, 0.0), Vector3(0.11, 0.32, plank_len * 0.88), plank_basis, WOOD_LIGHT)
		# Braçadeiras metálicas / pregos
		if i % 3 == 0:
			LowPolyMesh.box(st, p_mid + Vector3(0.0, 0.06, 0.0), Vector3(0.18, 1.15, 0.12), plank_basis, IRON)

	# Proa saliente e vigas partidas no lado esquerdo (+X, como em polvo_naufragio.jpg)
	var bow_tip: Vector3 = Vector3(2.55, 1.85, -0.45)
	LowPolyMesh.prism(st, Vector3(2.1, 0.5, -0.2), bow_tip, 0.20, 0.06, 5, WOOD)
	LowPolyMesh.prism(st, Vector3(2.35, 0.4, 0.2), bow_tip + Vector3(0.1, 0.2, -0.1), 0.16, 0.04, 4, WOOD_LIGHT)
	# Vigas de trave quebrada
	LowPolyMesh.prism(st, bow_tip, bow_tip + Vector3(0.4, 0.25, -0.3), 0.08, 0.02, 4, WOOD_DARK)

	# Mastro grosso partido erguido a estibordo (-X, atrás/lado como na referência)
	var mast_base: Vector3 = Vector3(-1.85, 0.3, 0.55)
	var mast_mid: Vector3 = Vector3(-2.05, 1.85, 0.35)
	var mast_top: Vector3 = Vector3(-2.25, 3.15, 0.15)
	LowPolyMesh.prism(st, mast_base, mast_mid, 0.18, 0.15, 6, WOOD)
	LowPolyMesh.prism(st, mast_mid - Vector3(0.0, 0.12, 0.0), mast_mid + Vector3(0.0, 0.12, 0.0), 0.20, 0.20, 6, IRON)
	LowPolyMesh.prism(st, mast_mid, mast_top, 0.15, 0.03, 5, WOOD_LIGHT)
	# Corda pendurada do topo do mastro descendo até aos destroços
	var rope_pts: Array[Vector3] = [
		mast_top - Vector3(0.05, 0.1, 0.0),
		mast_mid + Vector3(0.15, -0.3, -0.1),
		Vector3(-1.6, 0.9, -0.4),
		Vector3(-1.3, 0.4, -0.9)
	]
	for ri: int in rope_pts.size() - 1:
		LowPolyMesh.prism(st, rope_pts[ri], rope_pts[ri + 1], 0.035, 0.03, 4, BARNACLE)

	# Trave transversal frontal sobre a qual os tentáculos descansam
	var spar_left: Vector3 = Vector3(1.65, 0.85, -1.15)
	var spar_mid: Vector3 = Vector3(0.15, 0.52, -1.55)
	var spar_right: Vector3 = Vector3(-1.25, 0.40, -1.35)
	LowPolyMesh.prism(st, spar_left, spar_mid, 0.14, 0.11, 5, WOOD)
	LowPolyMesh.prism(st, spar_mid, spar_right, 0.11, 0.04, 5, WOOD_DARK)
	# Anel de ferro na trave
	LowPolyMesh.prism(st, spar_mid - Vector3(0.1, 0.0, 0.0), spar_mid + Vector3(0.1, 0.0, 0.0), 0.14, 0.14, 6, IRON)

	# Piso do barco com tábuas partidas
	for k: int in range(7):
		var b_pos: Vector3 = Vector3(-1.2 + float(k) * 0.4, 0.18, 0.2 + float(k % 2) * 0.3)
		LowPolyMesh.box(st, b_pos, Vector3(0.34, 0.08, 1.8), Basis(Vector3.UP, 0.10 * float(k - 3)), WOOD_DARK)


func _build_anchor(st: SurfaceTool) -> void:
	# Grande âncora de ferro enferrujada cravada no topo-direito do polvo (na vista frontal fica à direita = -X)
	var a_base: Vector3 = Vector3(-0.65, 3.45, 0.15)
	var a_top: Vector3 = Vector3(-1.15, 4.95, -0.05)
	var shank_vec: Vector3 = (a_top - a_base).normalized()

	# Haste principal imponente
	LowPolyMesh.prism(st, a_base, a_top, 0.11, 0.09, 6, ANCHOR_RUST)

	# Travessão perpendicular longo (stock)
	var stock_pos: Vector3 = a_top - shank_vec * 0.42
	var stock_basis: Basis = Basis(Vector3.FORWARD, deg_to_rad(35.0)).rotated(Vector3.UP, deg_to_rad(-25.0))
	LowPolyMesh.box(st, stock_pos, Vector3(1.10, 0.085, 0.085), stock_basis, ANCHOR_RUST)
	var stock_end: Vector3 = stock_basis.x * 0.55
	LowPolyMesh.prism(st, stock_pos + stock_end, stock_pos + stock_end * 1.15, 0.08, 0.02, 6, ANCHOR_DARK)
	LowPolyMesh.prism(st, stock_pos - stock_end, stock_pos - stock_end * 1.15, 0.08, 0.02, 6, ANCHOR_DARK)

	# Grande argola / olhal superior
	var ring_center: Vector3 = a_top + shank_vec * 0.18
	LowPolyMesh.prism(st, a_top, ring_center + shank_vec * 0.16, 0.15, 0.15, 8, ANCHOR_DARK)
	LowPolyMesh.prism(st, ring_center - Vector3(0.0, 0.02, 0.0), ring_center + Vector3(0.0, 0.02, 0.0), 0.075, 0.075, 6, Color(0, 0, 0, 0))

	# Braços curvos e unhas pontiagudas (flukes) na base cravada
	# Braço 1: crava-se no crânio do polvo
	var fluke1_mid: Vector3 = a_base + Vector3(0.35, -0.15, 0.15)
	var fluke1_tip: Vector3 = a_base + Vector3(0.60, 0.25, 0.10)
	LowPolyMesh.prism(st, a_base, fluke1_mid, 0.10, 0.08, 5, ANCHOR_RUST)
	LowPolyMesh.prism(st, fluke1_mid, fluke1_tip, 0.08, 0.02, 4, ANCHOR_DARK)

	# Braço 2: curva-se para fora de forma bem saliente
	var fluke2_mid: Vector3 = a_base + Vector3(-0.45, -0.10, -0.15)
	var fluke2_tip: Vector3 = a_base + Vector3(-0.75, 0.55, -0.20)
	var palm_tip: Vector3 = fluke2_tip + Vector3(-0.15, 0.18, 0.05)
	LowPolyMesh.prism(st, a_base, fluke2_mid, 0.11, 0.09, 5, ANCHOR_RUST)
	LowPolyMesh.prism(st, fluke2_mid, fluke2_tip, 0.09, 0.06, 5, ANCHOR_RUST)
	LowPolyMesh.prism(st, fluke2_tip, palm_tip, 0.12, 0.015, 4, ANCHOR_DARK)

	# Corrente de elos grossos pendurada do olhal caindo pelo lado do polvo
	var chain_points: Array[Vector3] = [
		ring_center,
		stock_pos + Vector3(0.05, -0.20, 0.10),
		a_base + Vector3(-0.25, 0.15, 0.20),
		a_base + Vector3(-0.55, -0.50, 0.25),
		Vector3(-1.3, 2.2, 0.35)
	]
	for idx: int in chain_points.size() - 1:
		var cp_a: Vector3 = chain_points[idx]
		var cp_b: Vector3 = chain_points[idx + 1]
		var c_mid: Vector3 = (cp_a + cp_b) * 0.5
		LowPolyMesh.prism(st, cp_a, cp_b, 0.05, 0.05, 6, CHAIN_IRON)
		LowPolyMesh.box(st, c_mid, Vector3(0.12, 0.12, 0.045), Basis.IDENTITY, CHAIN_IRON)


func _build_head_and_eyes(st: SurfaceTool) -> void:
	var head_basis: Basis = Basis(Vector3.RIGHT, 0.18)
	# Manto bulboso do polvo com anéis poligonais
	CrabModel.gem(st, Transform3D.IDENTITY, Vector3(0.0, 2.35, 0.15), head_basis, [
		Vector3(-1.05, 1.20, 1.15), Vector3(-0.25, 1.55, 1.50), Vector3(0.70, 1.45, 1.40), Vector3(1.50, 0.90, 0.90),
	], 8, -1.3, 1.85, SKIN, 0.05, 71)

	# Manchas poligonais claras (creme/bege) grandes como em polvo_naufragio.jpg
	var spot_positions: Array[Vector3] = [
		Vector3(-0.45, 3.25, -0.85), Vector3(0.20, 3.45, -0.75), Vector3(-0.70, 2.95, -0.65),
		Vector3(0.55, 2.95, -0.65), Vector3(0.0, 3.75, -0.35), Vector3(-0.55, 3.65, -0.15),
		Vector3(0.65, 3.55, -0.15), Vector3(-0.85, 2.55, -0.45), Vector3(0.85, 2.55, -0.45),
		Vector3(0.0, 3.85, 0.25), Vector3(-0.55, 3.45, 0.65), Vector3(0.55, 3.45, 0.65)
	]
	for sp: Vector3 in spot_positions:
		var norm: Vector3 = (sp - Vector3(0.0, 2.35, 0.15)).normalized()
		LowPolyMesh.prism(st, sp, sp + norm * 0.06, 0.18, 0.14, 6, SPOT_CREAM)

	# Cracas (barnacles) espalhadas pelo manto
	var barnacle_positions: Array[Vector3] = [
		Vector3(-0.15, 3.05, -0.95), Vector3(0.45, 2.65, -0.85), Vector3(-0.75, 2.35, -0.75),
		Vector3(0.75, 2.35, -0.75), Vector3(-0.25, 3.80, -0.15), Vector3(0.35, 3.75, 0.05)
	]
	for bp: Vector3 in barnacle_positions:
		var b_norm: Vector3 = (bp - Vector3(0.0, 2.35, 0.15)).normalized()
		var b_tip: Vector3 = bp + b_norm * 0.14
		LowPolyMesh.prism(st, bp, b_tip, 0.13, 0.045, 5, BARNACLE)
		LowPolyMesh.prism(st, bp + b_norm * 0.10, b_tip + b_norm * 0.03, 0.05, 0.0, 5, BARNACLE_DARK)

	# Olhos esféricos enormes saltados para a frente/lados com pupilas vivas
	for side: float in [-1.0, 1.0]:
		var eye_center: Vector3 = Vector3(0.72 * side, 2.25, -0.75)
		# Anel da pálpebra em redor do olho
		LowPolyMesh.prism(st, eye_center + Vector3(0.0, 0.0, 0.16), eye_center - Vector3(0.0, 0.0, 0.06), 0.50, 0.46, 8, EYE_LID)
		# Globo ocular branco esférico
		CrabModel.gem(st, Transform3D.IDENTITY, eye_center, Basis.IDENTITY, [
			Vector3(-0.32, 0.42, 0.42), Vector3(0.0, 0.46, 0.46), Vector3(0.32, 0.42, 0.42),
		], 8, -0.42, 0.42, Color(EYE_WHITE.r, EYE_WHITE.g, EYE_WHITE.b, 0.0), 0.0, 72)
		# Pupila preta viva circular
		var pupil_pos: Vector3 = eye_center + Vector3(0.04 * side, 0.02, -0.44)
		LowPolyMesh.prism(st, pupil_pos + Vector3(0.0, 0.0, 0.05), pupil_pos, 0.22, 0.21, 8, Color(PUPIL.r, PUPIL.g, PUPIL.b, 0.0))
		# Brilho branco na pupila
		var glint_pos: Vector3 = pupil_pos + Vector3(-0.07 * side, 0.09, -0.02)
		LowPolyMesh.box(st, glint_pos, Vector3(0.07, 0.07, 0.02), Basis.IDENTITY, Color(1.0, 1.0, 1.0, 0.0))

	# Sifão / boca
	LowPolyMesh.prism(st, Vector3(0.0, 1.60, -0.95), Vector3(0.0, 1.45, -1.45), 0.32, 0.22, 6, SKIN_DARK)


func _tentacle_mesh(length: float, radius: float, upright: bool = false, mode: int = 0) -> SurfaceTool:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs: int = 8
	var prev: Vector3 = Vector3.ZERO
	for s: int in segs:
		var t: float = float(s + 1) / float(segs)
		var p: Vector3
		if upright:
			p = Vector3(0.0, length * t, -sin(t * PI * 0.9) * 0.6 * t)
		elif mode == 1:
			# Erguido alto e curvado sobre a amurada do barco (+X) como na referência
			p = Vector3(sin(t * PI) * 0.55, sin(t * PI * 0.75) * 1.7 + t * 0.4, length * t * 0.72)
		elif mode == 2:
			# Curvado para a frente enroscando na trave frontal
			p = Vector3(-sin(t * PI) * 0.35, -0.15 + sin(t * PI) * 0.55, length * t * 0.92)
		else:
			p = Vector3(0.0, -length * 0.35 * t * t, length * t)
		var r0: float = radius * (1.0 - float(s) / float(segs) * 0.85)
		var r1: float = radius * (1.0 - t * 0.85)
		LowPolyMesh.prism(st, prev, p, r0, r1 if s < segs - 1 else 0.0, 7, SKIN if s % 2 == 0 else SKIN_DARK)
		var mid: Vector3 = (prev + p) * 0.5
		var under_dir: Vector3
		if upright:
			under_dir = Vector3(0.0, 0.0, 1.0)
		elif mode == 1:
			under_dir = Vector3(-0.6, -0.8, 0.0).normalized()
		else:
			under_dir = Vector3(0.0, -1.0, 0.0)
		var under_pos: Vector3 = mid + under_dir * (r0 * 0.85)
		LowPolyMesh.prism(st, mid, under_pos, r0 * 0.75, r0 * 0.65, 5, SUCKER)

		if s < segs - 1:
			for vx: float in [-0.4, 0.4]:
				var v_offset: Vector3 = Vector3(r0 * vx, 0.0, 0.0)
				var v_base: Vector3 = under_pos + v_offset
				var v_tip: Vector3 = v_base + under_dir * (r0 * 0.35)
				LowPolyMesh.prism(st, v_base, v_tip, r0 * 0.38, r0 * 0.32, 6, SUCKER_RIM)
				LowPolyMesh.prism(st, v_tip, v_tip + under_dir * 0.01, r0 * 0.22, 0.0, 6, SUCKER)

		if s == 2 or s == 4:
			var dorsal_dir: Vector3 = -under_dir
			var b_pos: Vector3 = mid + dorsal_dir * (r0 * 0.95)
			LowPolyMesh.prism(st, b_pos, b_pos + dorsal_dir * 0.10, 0.09, 0.03, 5, BARNACLE)
			LowPolyMesh.prism(st, b_pos + dorsal_dir * 0.08, b_pos + dorsal_dir * 0.11, 0.04, 0.0, 5, BARNACLE_DARK)

		prev = p
	return st


func _commit(st: SurfaceTool, part_name: String, mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = part_name
	mi.mesh = ToonKit.commit(st)
	mi.material_override = mat
	return mi


# ---------------------------------------------------------------------------
# #57: hélice, agarrão e tinta
# ---------------------------------------------------------------------------

func _away_from_home() -> bool:
	return Vector2(global_position.x - _home.x, global_position.z - _home.z).length() > 1.0


func _face_point(p: Vector3, delta: float) -> void:
	var to: Vector3 = p - global_position
	to.y = 0.0
	if to.length_squared() > 0.01:
		_turn_towards(to.normalized(), 0.0, turn_speed * 2.0, delta)


## Sai a rodar pela praia: segue a direção marcada, curva devagar para o alvo e atira quem
## apanhar. No fim fica tonto (STUCK) longe da água e depois volta ao sítio.
func _process_spin(delta: float) -> void:
	var target: Node3D = _update_target(delta)
	if target != null:
		var to: Vector3 = target.global_position - global_position
		to.y = 0.0
		if to.length_squared() > 0.01:
			_spin_dir = _spin_dir.slerp(to.normalized(), clampf(0.7 * delta, 0.0, 1.0)).normalized()
	var next: Vector3 = global_position + _spin_dir * SPIN_SPEED * (1.2 if phase == 2 else 1.0) * delta
	# Trela: não se afasta mais de attack_range do sítio onde saiu da água.
	if Vector2(next.x - _home.x, next.z - _home.z).length() > attack_range:
		_spin_dir = (_home - global_position)
		_spin_dir.y = 0.0
		_spin_dir = _spin_dir.normalized()
	else:
		global_position = Vector3(next.x, _ground_height(next, _surface_y), next.z)
	if int(_state_time * 10.0) % 2 == 0:
		spawn_particles(global_position + Vector3.UP * 0.2, Color(0.85, 0.74, 0.5), 4, 3.0)
	for p: Node3D in _players_within(global_position, SPIN_RADIUS):
		if _hit_list.has(p):
			continue
		_hit_list.append(p)
		_deal_damage(p, spin_damage)
		var out: Vector3 = p.global_position - global_position
		out.y = 0.0
		out = out.normalized() if out.length_squared() > 0.01 else _spin_dir
		_knockback(p, (out + out.cross(Vector3.UP) * 1.2) * 10.0 + Vector3.UP * 8.0, 0.09)
	if fmod(_state_time, 0.7) < delta:
		_hit_list.clear()
	if _state_time >= spin_time:
		_enter_state(State.STUCK)


## Volta para o sítio de onde saiu (a deslizar nos tentáculos).
func _process_return(delta: float) -> void:
	var to: Vector3 = _home - global_position
	to.y = 0.0
	if to.length() < 0.3 or _state_time > 6.0:
		global_position = _home
		_enter_state(State.IDLE)
		return
	var next: Vector3 = global_position + to.normalized() * minf(4.0 * delta, to.length())
	global_position = Vector3(next.x, _ground_height(next, _surface_y), next.z)
	_turn_towards(to.normalized(), 0.0, turn_speed * 2.0, delta)


## Agarra quem estiver no círculo e atira-o ao mar (por cima do polvo, para o lado da água).
func _do_grab() -> void:
	SFX.play_at(SFX.EMERGE_SAND, net_attack_point, 4.0)
	spawn_particles(net_attack_point + Vector3.UP * 0.2, Color(0.85, 0.74, 0.5), 18, 3.5)
	for p: Node3D in _players_within(net_attack_point, GRAB_RADIUS):
		_deal_damage(p, grab_damage)
		_knockback(p, sea_direction(p.global_position) * 13.0 + Vector3.UP * 11.0, 0.12)


## Para onde fica o mar visto de `from`: do jogador para o polvo (que vive junto à água).
func sea_direction(from: Vector3) -> Vector3:
	var d: Vector3 = _home - from
	d.y = 0.0
	return d.normalized() if d.length_squared() > 0.01 else global_transform.basis.z


## Jato de tinta em faixa à frente: o ecrã de quem apanha fica meio preto.
func _do_ink() -> void:
	var origin: Vector3 = _ground_point(global_position)
	var dir: Vector3 = Vector3(net_attack_dir.x, 0.0, net_attack_dir.z).normalized()
	_spray_ink(origin, dir)
	for p: Node3D in _all_players():
		var d: Vector3 = p.global_position - origin
		d.y = 0.0
		var along: float = d.dot(dir)
		var side: float = absf(d.dot(dir.cross(Vector3.UP)))
		if along >= 0.0 and along <= INK_LENGTH and side <= INK_WIDTH * 0.5:
			_deal_damage(p, ink_damage)
			_player_effect(p, &"apply_ink", [INK_SECONDS])
			_knockback(p, dir * 4.0 + Vector3.UP * 2.0, 0.05)


func _spray_ink(origin: Vector3, dir: Vector3) -> void:
	if _ink_fx == null:
		_ink_fx = CPUParticles3D.new()
		_ink_fx.name = "InkSpray"
		_ink_fx.top_level = true
		_ink_fx.one_shot = true
		_ink_fx.emitting = false
		_ink_fx.explosiveness = 0.6
		_ink_fx.amount = 60
		_ink_fx.lifetime = 0.9
		_ink_fx.spread = 12.0
		_ink_fx.initial_velocity_min = 9.0
		_ink_fx.initial_velocity_max = 14.0
		_ink_fx.gravity = Vector3(0.0, -6.0, 0.0)
		_ink_fx.scale_amount_min = 1.0
		_ink_fx.scale_amount_max = 2.5
		var mesh: SphereMesh = SphereMesh.new()
		mesh.radius = 0.12
		mesh.height = 0.24
		mesh.radial_segments = 6
		mesh.rings = 3
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color(0.05, 0.03, 0.08)
		mat.roughness = 0.2
		mesh.material = mat
		_ink_fx.mesh = mesh
		add_child(_ink_fx)
	_ink_fx.global_transform = Transform3D(Basis.looking_at(-dir + Vector3.UP * 0.15, Vector3.UP), origin + Vector3.UP * 1.6 + dir * 1.2)
	_ink_fx.direction = Vector3(0.0, 0.0, 1.0)
	_ink_fx.restart()


# ---------------------------------------------------------------------------
# #57: escudo de tábuas do navio e leque atirado
# ---------------------------------------------------------------------------

func plank_dirs() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var base: Vector3 = Vector3(net_attack_dir.x, 0.0, net_attack_dir.z).normalized()
	if base.length_squared() < 0.01:
		base = Vector3.FORWARD
	for i: int in PLANK_COUNT:
		out.append(base.rotated(Vector3.UP, (float(i) - float(PLANK_COUNT - 1) * 0.5) * PLANK_SPREAD))
	return out


func _plank_origin() -> Vector3:
	return _ground_point(global_position) + Vector3.UP * 1.2


func _refresh_plank_warnings() -> void:
	if _plank_warnings.is_empty():
		return
	var on: bool = state == State.PLANK_TELEGRAPH or state == State.PLANK_THROW
	var dirs: Array[Vector3] = plank_dirs()
	for i: int in _plank_warnings.size():
		if on:
			_plank_warnings[i].show_line(_ground_point(global_position) + dirs[i] * 1.5, dirs[i], PLANK_LENGTH, PLANK_HIT_RADIUS * 2.0)
		else:
			_plank_warnings[i].hide_warning()


## As tábuas voam a rodopiar pelas faixas; cada uma bate uma vez em cada jogador.
func _process_plank_throw() -> void:
	var d: float = _state_time * PLANK_SPEED
	var dirs: Array[Vector3] = plank_dirs()
	for i: int in dirs.size():
		var p: Vector3 = _plank_origin() + dirs[i] * (1.5 + d)
		for pl: Node3D in _players_within(p, PLANK_HIT_RADIUS):
			if _plank_hit.has(pl):
				continue
			_plank_hit.append(pl)
			_deal_damage(pl, plank_damage)
			_knockback(pl, dirs[i] * 10.0 + Vector3.UP * 6.0, 0.08)
	if d >= PLANK_LENGTH:
		for i: int in dirs.size():
			spawn_particles(_plank_origin() + dirs[i] * (1.5 + PLANK_LENGTH), WOOD, 14, 3.0)
		_enter_state(State.IDLE)


## Posição/rotação das tábuas (host e clientes, a partir do estado replicado).
func _animate_planks(delta: float) -> void:
	if _planks.is_empty():
		return
	var shown: bool = state in [State.SHIELD, State.PLANK_TELEGRAPH, State.PLANK_THROW]
	var dirs: Array[Vector3] = plank_dirs()
	var fwd: Vector3 = -global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length_squared() > 0.01 else Vector3.FORWARD
	var side: Vector3 = fwd.cross(Vector3.UP)
	for i: int in _planks.size():
		var pk: Node3D = _planks[i]
		pk.visible = shown
		if not shown:
			continue
		var off: float = float(i) - float(PLANK_COUNT - 1) * 0.5
		match state:
			State.SHIELD:
				# Muralha à frente, seguras pelos tentáculos, a abanar
				var p: Vector3 = global_position + fwd * 2.2 + side * off * 0.95 + Vector3.UP * (1.4 + sin(_anim_time * 3.0 + off) * 0.08)
				pk.global_transform = Transform3D(Basis.looking_at(fwd, Vector3.UP) * Basis(Vector3.FORWARD, off * 0.12), p)
			State.PLANK_TELEGRAPH:
				var t: float = clampf(_state_time / telegraph_time, 0.0, 1.0)
				var p: Vector3 = global_position + Vector3.UP * (2.0 + 1.6 * t) + side * off * 1.2 - fwd * 0.6 * t
				pk.global_transform = Transform3D(Basis.looking_at(fwd, Vector3.UP) * Basis(Vector3.RIGHT, -0.8 * t), p)
			State.PLANK_THROW:
				var p: Vector3 = _plank_origin() + dirs[i] * (1.5 + minf(_state_time * PLANK_SPEED, PLANK_LENGTH))
				pk.global_transform = Transform3D(Basis(Vector3.UP, atan2(dirs[i].x, dirs[i].z)) * Basis(Vector3.RIGHT, _state_time * 18.0), p)
	if state == State.SHIELD:
		# Dois tentáculos da frente esticados a segurar as tábuas
		for k: int in [0, 7]:
			if k < _tentacles.size():
				_tentacles[k].rotation.x = lerpf(_tentacles[k].rotation.x, 0.5, clampf(delta * 8.0, 0.0, 1.0))


## Tábua do navio (polvo_naufragio.jpg): três ripas castanhas gastas, pregadas por duas cintas
## de ferro cinzento, uma ponta partida em bico.
func _build_planks() -> void:
	var mat: ShaderMaterial = ToonKit.vertex_material(true, true)
	mat.set_shader_parameter(&"chip_amount", 0.3)
	mat.set_shader_parameter(&"chip_color", Color(0.28, 0.18, 0.1))
	for i: int in PLANK_COUNT:
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for k: int in 3:
			var x: float = (float(k) - 1.0) * 0.27
			var h: float = 1.5 - 0.18 * float((k + i) % 3)
			var c: Color = WOOD if (k + i) % 2 == 0 else WOOD_DARK
			LowPolyMesh.box(st, Vector3(x, h * 0.5 - 0.75, 0.0), Vector3(0.25, h, 0.07), Basis(Vector3.FORWARD, 0.02 * float(k - 1)), c)
			# Ponta partida (bico de lascas)
			LowPolyMesh.prism(st, Vector3(x, h - 0.75, 0.0), Vector3(x + 0.04, h - 0.75 + 0.2, 0.0), 0.08, 0.0, 3, c)
		for y: float in [-0.45, 0.3]:
			var iron: Color = Color(IRON.r, IRON.g, IRON.b, 0.0)
			LowPolyMesh.box(st, Vector3(0.0, y, -0.05), Vector3(0.86, 0.09, 0.03), Basis.IDENTITY, iron)
			for k: int in 3:
				LowPolyMesh.box(st, Vector3((float(k) - 1.0) * 0.27, y, -0.07), Vector3(0.04, 0.04, 0.02), Basis.IDENTITY, Color(0.2, 0.2, 0.22, 0.0))
		var mi: MeshInstance3D = _commit(st, "Plank%d" % i, mat)
		mi.top_level = true
		mi.visible = false
		add_child(mi)
		_planks.append(mi)
	for i: int in PLANK_COUNT:
		var w: GroundWarning = GroundWarning.new()
		add_child(w)
		_plank_warnings.append(w)


func _build_hud() -> void:
	_hud = BossHud.create("🐙 " + BOSS_NAME, max_health, Color(0.62, 0.22, 0.48))
	_health_bar = _hud.bar
	add_child(_hud)

