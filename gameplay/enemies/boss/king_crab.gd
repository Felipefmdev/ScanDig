class_name KingCrab
extends EnemyBase

## Chefe da Praia (issue #6). Acorda quando o jogador cava o BossAltar; nunca aparece por acaso.
## Ataques lentos e telegrafados (marca vermelha no chão ~0.9 s antes):
##   - ESMAGAR: levanta a pinça gigante e bate no chão (círculo de SLAM_RADIUS, slam_damage).
##     Depois fica stuck_time s com a pinça presa na areia e leva dano x WEAK_POINT_MULTIPLIER.
##   - INVESTIDA: carrega de lado numa linha marcada (charge_damage); repete 2x na fase 2.
##   - REFORÇOS: a 66% e 33% de vida chama 2-3 caranguejos.
##   - FASE 2 abaixo de 50%: mais rápido e com menos pausa entre ataques.
##   - CAOS (#57, alterna com os de cima): PIÃO (gira de pinças abertas e ricocheteia nas
##     palmeiras), BARRIGADA (salta e aterra de barriga com onda de areia) e ATIRAR
##     CARANGUEJOS (3 círculos; os pequenos caem lá e ficam a lutar). Depois do pião e da
##     barrigada fica TONTO (dano x2). Todos empurram o jogador (EnemyBase._knockback).
## A rede atordoa no máximo NET_STUN_CAP s; o repelente (flee_from) não o afeta.
## IA: máquina de estados simples (ver State) — o ciclo é linear (aproximar → telegrafar →
## atacar → recuperar), por isso uma behaviour tree (Beehave) só acrescentava uma dependência.

signal boss_defeated(boss_id: StringName)
signal phase_changed(phase: int)
signal reinforcements_called(count: int)
signal health_changed(current: float, max_value: float)

enum State {
	EMERGE,
	APPROACH,
	SLAM_TELEGRAPH,
	SLAM_STUCK,
	CHARGE_TELEGRAPH,
	CHARGE,
	RECOVER,
	SUMMON,
	DYING,
	SPIN_TELEGRAPH,
	SPIN,
	BELLY_TELEGRAPH,
	BELLY,
	THROW_TELEGRAPH,
	THROW,
	DIZZY,
}

const BOSS_ID: StringName = &"king_crab"
const BOSS_NAME: String = "CARANGUEJO-REI"
const GROUP_BOSSES: StringName = &"bosses"
const WEAK_POINT_MULTIPLIER: float = 2.0
const NET_STUN_CAP: float = 1.5
const SLAM_RADIUS: float = 3.0
const CHARGE_HIT_RADIUS: float = 1.6
const REINFORCE_THRESHOLDS: Array[float] = [0.66, 0.33]
const PHASE_TWO_RATIO: float = 0.5
const CROWN_ITEM: ItemData = preload("res://items/catalog/coroa_caranguejo_rei.tres")
## #57: pião, barrigada e caranguejos atirados.
const SPIN_RADIUS: float = 2.4
const SPIN_SPEED: float = 7.5
const BELLY_RADIUS: float = 3.6
const BELLY_HEIGHT: float = 4.5
const BELLY_AIR_TIME: float = 0.85
const THROW_COUNT: int = 3
const THROW_RADIUS: float = 1.3
const THROW_SPREAD: float = 2.2
const THROW_AIR_TIME: float = 0.7
## Não atira mais se já houver tantos caranguejos na cena.
const THROW_MAX_CRABS: int = 8
const CHAOS_ATTACKS: Array[int] = [State.SPIN_TELEGRAPH, State.BELLY_TELEGRAPH, State.THROW_TELEGRAPH]
const CRAB_SCENE: PackedScene = preload("res://gameplay/enemies/crab/crab.tscn")

const GOLD: Color = Color(1.0, 0.78, 0.12)
const GEM_RED: Color = Color(0.85, 0.08, 0.2)
const WARN_COLOR: Color = Color(1.0, 0.12, 0.08, 0.45)

@export var move_speed: float = 1.3
@export var phase_two_speed_multiplier: float = 1.5
@export var turn_speed: float = 2.5
@export var slam_damage: float = 25.0
@export var charge_damage: float = 20.0
@export var charge_speed: float = 8.0
@export var charge_length: float = 12.0
@export var telegraph_time: float = 0.9
@export var stuck_time: float = 2.0
@export var recover_time: float = 1.6
@export var phase_two_recover_time: float = 1.0
@export var emerge_time: float = 2.0
@export var slam_trigger_distance: float = 4.0
@export var spin_damage: float = 14.0
@export var spin_time: float = 3.6
@export var belly_damage: float = 22.0
@export var throw_damage: float = 8.0
@export var dizzy_time: float = 2.2

@onready var body_root: Node3D = $BodyRoot
@onready var big_claw: Node3D = $BodyRoot/BigClaw
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var hud: CanvasLayer = $BossHud
@onready var health_bar: ProgressBar = $BossHud/Panel/HealthBar

var state: State = State.EMERGE
var phase: int = 1
## Replicados (#31): onde vai cair o ataque telegrafado. Esmagar = centro do círculo;
## investida = início da linha + direção. Num cliente redesenham o aviso ao chegar.
var net_attack_point: Vector3 = Vector3.ZERO:
	set(value):
		net_attack_point = value
		if is_node_ready() and not has_simulation_authority():
			_refresh_remote_warning()
var net_attack_dir: Vector3 = Vector3.ZERO:
	set(value):
		net_attack_dir = value
		if is_node_ready() and not has_simulation_authority():
			_refresh_remote_warning()

var _state_time: float = 0.0
var _reinforce_index: int = 0
var _slam_point: Vector3 = Vector3.ZERO
var _charge_dir: Vector3 = Vector3.ZERO
var _charge_start: Vector3 = Vector3.ZERO
var _charges_left: int = 0
var _charge_hit: bool = false
var _last_attack_was_slam: bool = false
var _surface_y: float = 0.0
var _warn: MeshInstance3D = null
var _warn_mat: StandardMaterial3D = null
var _walk_time: float = 0.0
var _attack_count: int = 0
var _chaos_index: int = 0
var _hit_list: Array[Node] = []
var _spin_dir: Vector3 = Vector3.ZERO
var _belly_from: Vector3 = Vector3.ZERO
var _hit_done: bool = false
var _warns_extra: Array[GroundWarning] = []
var _flying_crabs: Array[Node3D] = []


func _ready() -> void:
	super._ready()
	add_to_group(GROUP_BOSSES)
	stun_fx_height = 2.4
	_build_model()
	_build_warning_marker()
	health_bar.max_value = max_health
	health_bar.value = health
	boss_defeated.connect(_report_defeat_to_core)
	_enter_state(State.EMERGE)


func _enemy_physics(delta: float) -> void:
	_state_time += delta
	match state:
		State.EMERGE:
			_process_emerge()
		State.APPROACH:
			_process_approach(delta)
		State.SLAM_TELEGRAPH:
			_process_slam_telegraph(delta)
		State.SLAM_STUCK:
			_process_stuck(delta)
		State.CHARGE_TELEGRAPH:
			_process_charge_telegraph(delta)
		State.CHARGE:
			_process_charge(delta)
		State.RECOVER:
			_process_recover(delta)
		State.SUMMON:
			_process_summon(delta)
		State.DYING:
			_process_dying(delta)
		State.SPIN_TELEGRAPH, State.BELLY_TELEGRAPH, State.THROW_TELEGRAPH:
			_process_chaos_telegraph(delta)
		State.SPIN:
			_process_spin(delta)
		State.BELLY:
			_process_belly()
		State.THROW:
			_process_throw(delta)
		State.DIZZY:
			_process_dizzy(delta)


func _enter_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	_set_warning_visible(false)
	for w: GroundWarning in _warns_extra:
		w.hide_warning()
	_hit_done = false
	_hit_list.clear()
	body_root.rotation.y = 0.0
	match new_state:
		State.EMERGE:
			_surface_y = global_position.y
			SFX.play_at(SFX.EMERGE_SAND, global_position, 6.0)
			global_position.y = _surface_y - 1.6
			collision_shape.disabled = true
		State.SLAM_TELEGRAPH:
			collision_shape.disabled = false
			velocity = Vector3.ZERO
			var target: Node3D = _update_target(1.0)
			_slam_point = global_position - global_transform.basis.z * 1.6
			if target != null:
				var to_t: Vector3 = target.global_position - global_position
				to_t.y = 0.0
				_slam_point = global_position + to_t.limit_length(2.6)
			_slam_point.y = global_position.y
			net_attack_point = _slam_point
			_show_circle_warning(_slam_point, SLAM_RADIUS)
		State.SLAM_STUCK:
			_do_slam_impact()
		State.CHARGE_TELEGRAPH:
			velocity = Vector3.ZERO
			var target: Node3D = _update_target(1.0)
			var to_t: Vector3 = (target.global_position - global_position) if target != null else -global_transform.basis.z
			to_t.y = 0.0
			_charge_dir = to_t.normalized() if to_t.length_squared() > 0.01 else Vector3.FORWARD
			net_attack_point = global_position
			net_attack_dir = _charge_dir
			_show_line_warning(global_position, _charge_dir, charge_length)
		State.CHARGE:
			_charge_start = global_position
			_charge_hit = false
		State.SUMMON:
			velocity = Vector3.ZERO
		State.DYING:
			collision_shape.disabled = true
			velocity = Vector3.ZERO
		State.SPIN_TELEGRAPH:
			collision_shape.disabled = false
			velocity = Vector3.ZERO
			net_attack_point = global_position
			_show_circle_warning(global_position, SPIN_RADIUS)
		State.SPIN:
			var target: Node3D = _update_target(1.0)
			var to_t: Vector3 = (target.global_position - global_position) if target != null else -global_transform.basis.z
			to_t.y = 0.0
			_spin_dir = to_t.normalized() if to_t.length_squared() > 0.01 else Vector3.FORWARD
			SFX.play_at(SFX.CRAB_PINCH, global_position, 4.0)
		State.BELLY_TELEGRAPH:
			collision_shape.disabled = false
			velocity = Vector3.ZERO
			var target: Node3D = _update_target(1.0)
			var p: Vector3 = target.global_position if target != null else global_position
			net_attack_point = Vector3(p.x, _surface_y, p.z)
			_show_circle_warning(net_attack_point, BELLY_RADIUS)
		State.BELLY:
			_belly_from = global_position
			collision_shape.disabled = true
		State.THROW_TELEGRAPH:
			collision_shape.disabled = false
			velocity = Vector3.ZERO
			var target: Node3D = _update_target(1.0)
			var p: Vector3 = target.global_position if target != null else global_position - global_transform.basis.z * 5.0
			net_attack_point = Vector3(p.x, _surface_y, p.z)
			_show_throw_warnings()
		State.THROW:
			_show_throw_warnings()
		State.DIZZY:
			collision_shape.disabled = false
			velocity = Vector3.ZERO
			SFX.play_at(SFX.SHELL_KNOCK, global_position, 3.0)
		_:
			collision_shape.disabled = false


# ---------------------------------------------------------------------------
# Estados
# ---------------------------------------------------------------------------

func _process_emerge() -> void:
	var t: float = clampf(_state_time / emerge_time, 0.0, 1.0)
	global_position.y = _surface_y - 1.6 * (1.0 - (1.0 - pow(1.0 - t, 3.0)))
	body_root.rotation.z = sin(_state_time * 25.0) * 0.08 * (1.0 - t)
	if int(_state_time * 10.0) % 3 == 0:
		spawn_particles(global_position + Vector3(randf_range(-1, 1), 1.6, randf_range(-1, 1)), Color(0.85, 0.74, 0.5), 6, 3.0)
	if t >= 1.0:
		global_position.y = _surface_y
		body_root.rotation.z = 0.0
		_enter_state(State.RECOVER)


func _process_approach(delta: float) -> void:
	var target: Node3D = _update_target(delta)
	_apply_gravity(delta)
	if target == null:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	var to_t: Vector3 = target.global_position - global_position
	to_t.y = 0.0
	var dist: float = to_t.length()
	var dir: Vector3 = to_t / dist if dist > 0.01 else Vector3.ZERO

	# #57: um ataque em cada dois é caótico (pião → barrigada → caranguejos, em roda).
	if _attack_count % 2 == 1 and _state_time > 0.8:
		_attack_count += 1
		_enter_state(next_chaos_attack())
		return
	# Escolhe o ataque: perto → esmagar; longe → investida. Alterna para não repetir.
	if dist <= slam_trigger_distance and not _last_attack_was_slam:
		_last_attack_was_slam = true
		_attack_count += 1
		_enter_state(State.SLAM_TELEGRAPH)
		return
	if (dist > slam_trigger_distance or _last_attack_was_slam) and _state_time > 1.0:
		_last_attack_was_slam = false
		_charges_left = get_charge_repeats()
		_attack_count += 1
		_enter_state(State.CHARGE_TELEGRAPH)
		return

	var speed: float = get_move_speed()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	move_and_slide()
	_turn_towards(dir, 0.0, turn_speed, delta)
	_animate_walk(delta)


func _process_slam_telegraph(delta: float) -> void:
	_apply_gravity(delta)
	move_and_slide()
	var to_p: Vector3 = _slam_point - global_position
	_turn_towards(Vector3(to_p.x, 0.0, to_p.z), 0.0, turn_speed * 2.0, delta)
	# Levanta a pinça gigante
	var t: float = clampf(_state_time / telegraph_time, 0.0, 1.0)
	big_claw.rotation.x = lerpf(0.0, -1.3, t)
	_pulse_warning()
	if _state_time >= telegraph_time:
		_enter_state(State.SLAM_STUCK)


func _do_slam_impact() -> void:
	big_claw.rotation.x = 0.35
	var thud: AudioStreamPlayer3D = SFX.play_at(SFX.CRAB_PINCH, _slam_point, 4.0)
	if thud != null:
		thud.pitch_scale *= 0.7
	SFX.play_at(SFX.EMERGE_SAND, _slam_point, 6.0)
	spawn_particles(_slam_point + Vector3.UP * 0.1, Color(0.85, 0.74, 0.5), 40, 5.0)
	for n: Node3D in _players_within(_slam_point, SLAM_RADIUS):
		_deal_damage(n, slam_damage)
		_knockback(n, _away(_slam_point, n) * 7.0 + Vector3.UP * 6.0, 0.08)


## Ponto fraco: pinça presa na areia, sem se mexer, leva dano x2.
func _process_stuck(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()
	big_claw.rotation.z = sin(_state_time * 30.0) * 0.05
	if _state_time >= stuck_time:
		big_claw.rotation = Vector3.ZERO
		_enter_state(State.RECOVER)


func _process_charge_telegraph(delta: float) -> void:
	_apply_gravity(delta)
	move_and_slide()
	# Investida de lado: o corpo fica perpendicular à linha
	_turn_towards(_charge_dir, PI * 0.5, turn_speed * 2.0, delta)
	body_root.position.x = sin(_state_time * 40.0) * 0.04
	_pulse_warning()
	if _state_time >= telegraph_time:
		body_root.position.x = 0.0
		_enter_state(State.CHARGE)


func _process_charge(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = _charge_dir.x * charge_speed
	velocity.z = _charge_dir.z * charge_speed
	move_and_slide()
	_animate_walk(delta * 2.5)
	if not _charge_hit:
		for n: Node3D in _players_within(global_position, CHARGE_HIT_RADIUS):
			_deal_damage(n, charge_damage)
			_knockback(n, _charge_dir * 12.0 + Vector3.UP * 5.0, 0.07)
			_charge_hit = true
	var travelled: float = Vector2(global_position.x - _charge_start.x, global_position.z - _charge_start.z).length()
	if travelled >= charge_length or (is_on_wall() and _state_time > 0.2):
		_charges_left -= 1
		if _charges_left > 0:
			_enter_state(State.CHARGE_TELEGRAPH)
		else:
			_enter_state(State.RECOVER)


func _process_recover(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()
	var wait: float = phase_two_recover_time if phase == 2 else recover_time
	if _state_time >= wait:
		_enter_state(State.APPROACH)


func _process_summon(delta: float) -> void:
	_apply_gravity(delta)
	move_and_slide()
	body_root.rotation.x = -sin(clampf(_state_time / 1.2, 0.0, 1.0) * PI) * 0.25
	if _state_time >= 1.2:
		body_root.rotation.x = 0.0
		_enter_state(State.RECOVER)


## Queda: tomba de lado, afunda um pouco e larga a coroa.
func _process_dying(_delta: float) -> void:
	var t: float = clampf(_state_time / 1.8, 0.0, 1.0)
	body_root.rotation.z = lerpf(0.0, 1.35, t * t)
	body_root.position.y = -0.4 * t
	if _state_time >= 1.8 and _state_time - get_physics_process_delta_time() < 1.8:
		_drop_crown()
	if _state_time >= 3.0:
		spawn_particles(global_position + Vector3.UP * 0.6, death_color, 40, 4.0)
		queue_free()


# ---------------------------------------------------------------------------
# Regras de combate (públicas para os testes)
# ---------------------------------------------------------------------------

func is_phase_two() -> bool:
	return health < max_health * PHASE_TWO_RATIO


func get_move_speed() -> float:
	return move_speed * (phase_two_speed_multiplier if phase == 2 else 1.0)


func get_charge_repeats() -> int:
	return 2 if phase == 2 else 1


func is_weak_point_exposed() -> bool:
	return state == State.SLAM_STUCK or state == State.DIZZY


## Começa já acordado (testes / debug), sem a animação de sair da areia.
func wake_immediately() -> void:
	if state == State.EMERGE:
		global_position.y = _surface_y
		_enter_state(State.RECOVER)


func _can_take_damage() -> bool:
	return state != State.EMERGE and state != State.DYING


func _can_be_stunned() -> bool:
	return state != State.EMERGE and state != State.DYING


func _modify_damage(amount: float, _from: Vector3) -> float:
	return amount * WEAK_POINT_MULTIPLIER if is_weak_point_exposed() else amount


## A rede só o prende NET_STUN_CAP s.
func stun(seconds: float) -> void:
	super.stun(minf(seconds, NET_STUN_CAP))


## O repelente não afeta o rei.
func flee_from(_origin: Vector3, _seconds: float) -> void:
	pass


func take_damage(amount: float, from: Vector3 = Vector3.INF) -> void:
	super.take_damage(amount, from)
	if _dead or not has_simulation_authority():
		return
	health_bar.value = health
	health_changed.emit(health, max_health)
	_check_thresholds()


func _check_thresholds() -> void:
	var ratio: float = health / max_health
	while _reinforce_index < REINFORCE_THRESHOLDS.size() and ratio <= REINFORCE_THRESHOLDS[_reinforce_index]:
		_reinforce_index += 1
		_call_reinforcements()
	if phase == 1 and is_phase_two():
		phase = 2
		phase_changed.emit(2)


func _call_reinforcements() -> void:
	var count: int = randi_range(2, 3)
	var parent: Node = get_parent()
	if parent == null:
		return
	for i: int in range(count):
		var ang: float = TAU * float(i) / float(count) + randf() * 0.5
		var pos: Vector3 = Vector3(global_position.x, _surface_y, global_position.z) + Vector3(cos(ang), 0.0, sin(ang)) * 3.5
		if _spawn_minion(&"crab", pos) != null:
			continue
		var crab: Crab = CRAB_SCENE.instantiate() as Crab
		crab.spawn_level = 0
		parent.add_child(crab)
		crab.global_position = pos
	reinforcements_called.emit(count)
	# Rugido (só se não estiver a meio de um ataque)
	if state == State.APPROACH or state == State.RECOVER:
		_enter_state(State.SUMMON)


func _on_died() -> void:
	health_bar.value = 0.0
	_set_stun_fx(false)
	_enter_state(State.DYING)
	# _dead bloqueia _enemy_physics; a queda corre no _process
	set_physics_process(false)


func _process(delta: float) -> void:
	_animate_chaos(delta)
	if state == State.DYING and _dead:
		_state_time += delta
		_process_dying(delta)
	elif not has_simulation_authority():
		# Cliente: barra de vida e aviso a partir do estado replicado.
		health_bar.value = health
		if _warn != null and _warn.visible:
			_state_time += delta
			_pulse_warning()


## Cliente: avisos no chão e HUD a partir do estado do host (posição aproximada: à frente).
func _on_remote_state(new_state: int) -> void:
	_state_time = 0.0
	collision_shape.disabled = new_state == State.EMERGE or new_state == State.DYING
	if new_state == State.DYING:
		hud.visible = false
	_refresh_remote_warning()


## Cliente: aviso no ponto replicado (estado e ponto podem chegar por qualquer ordem).
func _refresh_remote_warning() -> void:
	_set_warning_visible(false)
	match state:
		State.SLAM_TELEGRAPH:
			_show_circle_warning(net_attack_point, SLAM_RADIUS)
		State.CHARGE_TELEGRAPH:
			var dir: Vector3 = net_attack_dir if net_attack_dir.length_squared() > 0.01 else global_transform.basis.x
			_show_line_warning(net_attack_point, dir.normalized(), charge_length)
		State.SPIN_TELEGRAPH:
			_show_circle_warning(net_attack_point, SPIN_RADIUS)
		State.BELLY_TELEGRAPH, State.BELLY:
			if state == State.BELLY_TELEGRAPH:
				_show_circle_warning(net_attack_point, BELLY_RADIUS)
			_belly_from = global_position
	if state == State.THROW_TELEGRAPH or state == State.THROW:
		_show_throw_warnings()
	else:
		for w: GroundWarning in _warns_extra:
			w.hide_warning()


func setup_network() -> void:
	super.setup_network()
	_add_synced_property(".:net_attack_point")
	_add_synced_property(".:net_attack_dir")


## Cliente: anda/patas conforme a velocidade replicada.
func _animate_remote(delta: float, speed: float) -> void:
	if speed > 0.15 and state != State.DYING:
		_animate_walk(delta * clampf(speed / move_speed, 0.5, 3.0))


func _drop_crown() -> void:
	var parent: Node = get_parent()
	if parent != null:
		ItemPickup.spawn(parent, CarriedItem.create(CROWN_ITEM, CROWN_ITEM.base_value, 1.0, false),
			global_position + Vector3.UP * 1.5, Vector3(randf_range(-0.5, 0.5), 3.0, randf_range(-0.5, 0.5)))
	hud.visible = false
	boss_defeated.emit(BOSS_ID)


## Avisa o core (o host valida, ignora repetidos e sincroniza defeated_bosses; desbloqueia
## a compra do Campo Antigo). Qualquer peer pode reportar.
func _report_defeat_to_core(boss_id: StringName) -> void:
	if has_simulation_authority() and GameState.instance != null:
		GameState.instance.request_report_boss_defeated(String(boss_id))


# ---------------------------------------------------------------------------
# Avisos no chão
# ---------------------------------------------------------------------------

func _build_warning_marker() -> void:
	for i: int in THROW_COUNT:
		var w: GroundWarning = GroundWarning.new()
		add_child(w)
		_warns_extra.append(w)
	_build_flying_crabs()
	_warn = MeshInstance3D.new()
	_warn.name = "Warning"
	_warn.top_level = true
	_warn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_warn_mat = StandardMaterial3D.new()
	_warn_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_warn_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_warn_mat.albedo_color = WARN_COLOR
	_warn_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_warn.material_override = _warn_mat
	_warn.visible = false
	add_child(_warn)


func _show_circle_warning(center: Vector3, radius: float) -> void:
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.02
	disc.radial_segments = 24
	_warn.mesh = disc
	_warn.global_transform = Transform3D(Basis.IDENTITY, center + Vector3.UP * 0.03)
	_set_warning_visible(true)


func _show_line_warning(start: Vector3, dir: Vector3, length: float) -> void:
	var strip: BoxMesh = BoxMesh.new()
	strip.size = Vector3(CHARGE_HIT_RADIUS * 2.0, 0.02, length)
	_warn.mesh = strip
	var basis: Basis = Basis.looking_at(dir, Vector3.UP)
	_warn.global_transform = Transform3D(basis, start + dir * length * 0.5 + Vector3.UP * 0.03)
	_set_warning_visible(true)


func _set_warning_visible(on: bool) -> void:
	if _warn != null:
		_warn.visible = on


func _pulse_warning() -> void:
	var a: float = 0.3 + 0.3 * (0.5 + 0.5 * sin(_state_time * 18.0))
	_warn_mat.albedo_color = Color(WARN_COLOR.r, WARN_COLOR.g, WARN_COLOR.b, a)


func _animate_walk(delta: float) -> void:
	_walk_time += delta * 6.0
	body_root.position.y = absf(sin(_walk_time)) * 0.06
	body_root.rotation.z = sin(_walk_time) * 0.03


# ---------------------------------------------------------------------------
# Modelo low-poly facetado (#37): as peças do caranguejo (CrabModel) a ~2,8x, coroa dourada,
# picos na carapaça e a pinça gigante virada para a frente (nó BigClaw, anima o esmagamento)
# ---------------------------------------------------------------------------

const CrabModel := preload("res://gameplay/enemies/crab/crab_model.gd")
const MODEL_SCALE: float = 2.8


func _build_model() -> void:
	var mat: ShaderMaterial = CrabModel.make_material(7.0)
	_register_flash_material(mat)
	var pal: Dictionary = CrabModel.PALETTE_KING
	var sc: Basis = Basis.from_scale(Vector3.ONE * MODEL_SCALE)

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	CrabModel.body(st, Transform3D(sc, Vector3.ZERO), pal)
	for side: float in [-1.0, 1.0]:
		var pivot: Vector3 = CrabModel.PIVOT_LEGS_LEFT if side < 0.0 else CrabModel.PIVOT_LEGS_RIGHT
		CrabModel.legs(st, Transform3D(sc, pivot * MODEL_SCALE), side, pal)
	# Pinça pequena à esquerda (a gigante é o nó BigClaw, à direita)
	CrabModel.small_claw(st, Transform3D(sc, Vector3(-0.24, 0.2, -0.15) * MODEL_SCALE), pal)
	# Picos escuros nos bicos da carapaça
	var dark: Color = pal["leg"]
	for k: int in range(6):
		var ang: float = TAU * float(k) / 6.0
		var base: Vector3 = Vector3(cos(ang) * 0.3, 0.27, sin(ang) * 0.2) * MODEL_SCALE
		var tip: Vector3 = base + Vector3(cos(ang) * 0.16, 0.22, sin(ang) * 0.12)
		LowPolyMesh.prism(st, base, tip, 0.1, 0.0, 4, dark)
	# Coroa dourada: aro + 5 pontas + gemas (sem pintas: alfa 0)
	var gold: Color = Color(GOLD.r, GOLD.g, GOLD.b, 0.0)
	var gem_red: Color = Color(GEM_RED.r, GEM_RED.g, GEM_RED.b, 0.0)
	var crown_c: Vector3 = Vector3(0.0, 1.0, 0.18)
	LowPolyMesh.prism(st, crown_c, crown_c + Vector3(0, 0.2, 0), 0.36, 0.4, 8, gold)
	for k: int in range(5):
		var ang: float = TAU * float(k) / 5.0 + 0.3
		var b: Vector3 = crown_c + Vector3(cos(ang) * 0.34, 0.2, sin(ang) * 0.34)
		LowPolyMesh.prism(st, b, b + Vector3(0, 0.28, 0), 0.09, 0.0, 4, gold)
		LowPolyMesh.box(st, crown_c + Vector3(cos(ang) * 0.4, 0.1, sin(ang) * 0.4), Vector3(0.08, 0.08, 0.08), Basis(Vector3.UP, ang), gem_red)
	body_root.add_child(LowPolyMesh.commit(st, "Body", mat))

	# Pinça gigante: a da referência, deitada para a frente (+Y do desenho -> frente e cima)
	var cst: SurfaceTool = SurfaceTool.new()
	cst.begin(Mesh.PRIMITIVE_TRIANGLES)
	var claw_basis: Basis = Basis(Vector3.RIGHT, -1.05) * Basis(Vector3.UP, -0.35) * sc
	CrabModel.big_claw(cst, Transform3D(claw_basis, Vector3(-0.25, -0.2, 0.0)), pal)
	big_claw.add_child(LowPolyMesh.commit(cst, "Mesh", mat))


# ---------------------------------------------------------------------------
# #57: pião, barrigada e caranguejos atirados (estilo How to Fish)
# ---------------------------------------------------------------------------

## Próximo ataque caótico (roda pela lista; público para os testes).
func next_chaos_attack() -> State:
	var s: State = CHAOS_ATTACKS[_chaos_index % CHAOS_ATTACKS.size()] as State
	_chaos_index += 1
	# Sem espaço para mais caranguejos: salta o atirar.
	if s == State.THROW_TELEGRAPH and _crab_count() >= THROW_MAX_CRABS:
		return State.SPIN_TELEGRAPH
	return s


## Onde caem os caranguejos atirados: um no alvo e dois à volta (os clientes refazem-nos a
## partir do net_attack_point).
func throw_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i: int in THROW_COUNT:
		var ang: float = TAU * float(i) / float(THROW_COUNT) + 0.4
		out.append(net_attack_point + Vector3(cos(ang), 0.0, sin(ang)) * (THROW_SPREAD if i > 0 else 0.0))
	return out


func _process_chaos_telegraph(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()
	var to_p: Vector3 = net_attack_point - global_position
	if state != State.SPIN_TELEGRAPH:
		_turn_towards(Vector3(to_p.x, 0.0, to_p.z), 0.0, turn_speed * 2.0, delta)
	_pulse_warning()
	for w: GroundWarning in _warns_extra:
		if w.visible:
			w.pulse(delta)
	if _state_time < telegraph_time * (0.8 if phase == 2 else 1.0):
		return
	match state:
		State.SPIN_TELEGRAPH:
			_enter_state(State.SPIN)
		State.BELLY_TELEGRAPH:
			_enter_state(State.BELLY)
		State.THROW_TELEGRAPH:
			_enter_state(State.THROW)


## Pião: gira de pinças abertas e ricocheteia nas paredes/palmeiras; bate a cada volta.
func _process_spin(delta: float) -> void:
	_apply_gravity(delta)
	var speed: float = SPIN_SPEED * (1.2 if phase == 2 else 1.0)
	velocity.x = _spin_dir.x * speed
	velocity.z = _spin_dir.z * speed
	move_and_slide()
	if is_on_wall():
		var n: Vector3 = get_wall_normal()
		n.y = 0.0
		if n.length_squared() > 0.01:
			_spin_dir = _spin_dir.bounce(n.normalized()).normalized()
			spawn_particles(global_position + Vector3.UP * 0.8, Color(0.85, 0.74, 0.5), 10, 3.0)
			SFX.play_at(SFX.SHELL_KNOCK, global_position, 2.0)
	# Puxa a direção um pouco para o alvo (para não fugir da arena).
	var target: Node3D = _update_target(delta)
	if target != null:
		var to_t: Vector3 = target.global_position - global_position
		to_t.y = 0.0
		if to_t.length_squared() > 0.01:
			_spin_dir = _spin_dir.slerp(to_t.normalized(), clampf(0.6 * delta, 0.0, 1.0)).normalized()
	for p: Node3D in _players_within(global_position, SPIN_RADIUS):
		if _hit_list.has(p):
			continue
		_hit_list.append(p)
		_deal_damage(p, spin_damage)
		var out: Vector3 = _away(global_position, p)
		_knockback(p, (out + out.cross(Vector3.UP)) * 9.0 + Vector3.UP * 7.0, 0.08)
	if fmod(_state_time, 0.8) < delta:
		_hit_list.clear()
	if _state_time >= spin_time:
		_enter_state(State.DIZZY)


## Barrigada: arco até ao ponto marcado e aterra de barriga com onda de areia.
func _process_belly() -> void:
	var t: float = clampf(_state_time / BELLY_AIR_TIME, 0.0, 1.0)
	var p: Vector3 = _belly_from.lerp(net_attack_point, t)
	p.y = lerpf(_belly_from.y, _surface_y, t) + sin(t * PI) * BELLY_HEIGHT
	global_position = p
	if t >= 1.0 and not _hit_done:
		_hit_done = true
		_belly_impact()
		_enter_state(State.DIZZY)


func _belly_impact() -> void:
	SFX.play_at(SFX.EMERGE_SAND, net_attack_point, 8.0)
	var thud: AudioStreamPlayer3D = SFX.play_at(SFX.SHELL_KNOCK, net_attack_point, 6.0)
	if thud != null:
		thud.pitch_scale *= 0.6
	# Onda de areia: anel de partículas à volta do impacto.
	for k: int in 10:
		var ang: float = TAU * float(k) / 10.0
		spawn_particles(net_attack_point + Vector3(cos(ang), 0.1, sin(ang)) * BELLY_RADIUS * 0.7, Color(0.85, 0.74, 0.5), 8, 5.0)
	for n: Node3D in _players_within(net_attack_point, BELLY_RADIUS):
		_deal_damage(n, belly_damage)
		_knockback(n, _away(net_attack_point, n) * 10.0 + Vector3.UP * 9.0, 0.12)


## Atira THROW_COUNT caranguejos: voam em arco da pinça e ficam a lutar onde caem.
func _process_throw(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()
	for w: GroundWarning in _warns_extra:
		if w.visible:
			w.pulse(delta)
	if _state_time >= THROW_AIR_TIME and not _hit_done:
		_hit_done = true
		for p: Vector3 in throw_points():
			spawn_particles(p + Vector3.UP * 0.1, Color(0.85, 0.74, 0.5), 10, 3.0)
			for n: Node3D in _players_within(p, THROW_RADIUS):
				_deal_damage(n, throw_damage)
				_knockback(n, _away(p, n) * 6.0 + Vector3.UP * 5.0, 0.05)
			_land_thrown_crab(p)
		_enter_state(State.RECOVER)


func _land_thrown_crab(pos: Vector3) -> void:
	if _crab_count() >= THROW_MAX_CRABS:
		return
	if _spawn_minion(&"crab", pos) != null:
		return
	var parent: Node = get_parent()
	if parent == null:
		return
	var crab: Crab = CRAB_SCENE.instantiate() as Crab
	crab.spawn_level = 0
	parent.add_child(crab)
	crab.global_position = pos


func _crab_count() -> int:
	var n: int = 0
	if not is_inside_tree():
		return 0
	for e: Node in get_tree().get_nodes_in_group(GROUP):
		if e is Crab and not e.is_queued_for_deletion():
			n += 1
	return n


## Tonto (a espernear): ponto fraco, dano x2.
func _process_dizzy(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()
	if _state_time >= dizzy_time * (0.75 if phase == 2 else 1.0):
		_enter_state(State.RECOVER)


func _away(from: Vector3, n: Node3D) -> Vector3:
	var d: Vector3 = n.global_position - from
	d.y = 0.0
	return d.normalized() if d.length_squared() > 0.01 else -global_transform.basis.z


func _show_throw_warnings() -> void:
	var pts: Array[Vector3] = throw_points()
	for i: int in _warns_extra.size():
		_warns_extra[i].show_circle(pts[i], THROW_RADIUS)


## Animação (host e clientes) a partir do estado: gira, encolhe para saltar, espernea.
func _animate_chaos(delta: float) -> void:
	if body_root == null:
		return
	var remote: bool = not has_simulation_authority()
	if remote and state in [State.THROW_TELEGRAPH, State.THROW, State.DIZZY, State.SPIN, State.BELLY]:
		_state_time += delta
	match state:
		State.SPIN_TELEGRAPH:
			body_root.rotation.y += delta * 6.0 * clampf(_state_time / telegraph_time, 0.0, 1.0)
			big_claw.rotation.z = -0.6
		State.SPIN:
			body_root.rotation.y += delta * 20.0
			big_claw.rotation.z = -0.6
		State.BELLY_TELEGRAPH:
			body_root.position.y = -0.35 * clampf(_state_time / telegraph_time, 0.0, 1.0)
			body_root.position.x = sin(_state_time * 40.0) * 0.05
		State.BELLY:
			body_root.position = Vector3.ZERO
			body_root.rotation.x = lerpf(body_root.rotation.x, -1.2, clampf(delta * 8.0, 0.0, 1.0))
		State.THROW_TELEGRAPH:
			big_claw.rotation.x = lerpf(0.0, -1.5, clampf(_state_time / telegraph_time, 0.0, 1.0))
		State.DIZZY:
			body_root.rotation.x = lerpf(body_root.rotation.x, 0.0, clampf(delta * 6.0, 0.0, 1.0))
			body_root.rotation.z = sin(_state_time * 16.0) * 0.22
			body_root.position = Vector3.ZERO
		State.DYING:
			pass
		_:
			body_root.rotation.x = lerpf(body_root.rotation.x, 0.0, clampf(delta * 6.0, 0.0, 1.0))
			big_claw.rotation.z = lerpf(big_claw.rotation.z, 0.0, clampf(delta * 6.0, 0.0, 1.0))
	_animate_flying_crabs()


## Caranguejos pequenos a voar da pinça para os círculos (só visual; os reais nascem ao cair).
func _animate_flying_crabs() -> void:
	var flying: bool = state == State.THROW and _state_time < THROW_AIR_TIME
	var pts: Array[Vector3] = throw_points()
	var from: Vector3 = big_claw.global_position + Vector3.UP * 0.8
	for i: int in _flying_crabs.size():
		var c: Node3D = _flying_crabs[i]
		c.visible = flying
		if not flying:
			continue
		var t: float = clampf(_state_time / THROW_AIR_TIME + float(i) * 0.04, 0.0, 1.0)
		var p: Vector3 = from.lerp(pts[i], t)
		p.y += sin(t * PI) * 3.5
		c.global_position = p
		c.rotation = Vector3(t * TAU * 2.0, float(i), t * TAU)


## Caranguejos atirados: as mesmas peças do Caranguejo (CrabModel, referência gaivota/caranguejo).
func _build_flying_crabs() -> void:
	var mat: ShaderMaterial = CrabModel.make_material()
	var pal: Dictionary = CrabModel.PALETTE_CRAB
	for i: int in THROW_COUNT:
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		CrabModel.body(st, Transform3D.IDENTITY, pal)
		for side: float in [-1.0, 1.0]:
			var pivot: Vector3 = CrabModel.PIVOT_LEGS_LEFT if side < 0.0 else CrabModel.PIVOT_LEGS_RIGHT
			CrabModel.legs(st, Transform3D(Basis.IDENTITY, pivot), side, pal)
			CrabModel.small_claw(st, Transform3D(Basis.IDENTITY, Vector3(0.24 * side, 0.2, -0.15)), pal)
		var mi: MeshInstance3D = LowPolyMesh.commit(st, "FlyingCrab%d" % i, mat)
		mi.top_level = true
		mi.visible = false
		add_child(mi)
		_flying_crabs.append(mi)
