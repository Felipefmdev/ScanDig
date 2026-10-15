class_name KingCrab
extends EnemyBase

## Chefe da Praia (issue #6). Acorda quando o jogador cava o BossAltar; nunca aparece por acaso.
## Ataques lentos e telegrafados (marca vermelha no chão ~0.9 s antes):
##   - ESMAGAR: levanta a pinça gigante e bate no chão (círculo de SLAM_RADIUS, slam_damage).
##     Depois fica stuck_time s com a pinça presa na areia e leva dano x WEAK_POINT_MULTIPLIER.
##   - INVESTIDA: carrega de lado numa linha marcada (charge_damage); repete 2x na fase 2.
##   - REFORÇOS: a 66% e 33% de vida chama 2-3 caranguejos.
##   - FASE 2 abaixo de 50%: mais rápido e com menos pausa entre ataques.
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
const CRAB_SCENE: PackedScene = preload("res://gameplay/enemies/crab/crab.tscn")

const SHELL_RED: Color = Color(0.86, 0.27, 0.12)
const SHELL_DARK: Color = Color(0.62, 0.16, 0.08)
const CLAW_RED: Color = Color(0.93, 0.36, 0.16)
const GOLD: Color = Color(1.0, 0.78, 0.12)
const GEM_RED: Color = Color(0.85, 0.08, 0.2)
const EYE_BLACK: Color = Color(0.04, 0.04, 0.05)
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


func _enter_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	_set_warning_visible(false)
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

	# Escolhe o ataque: perto → esmagar; longe → investida. Alterna para não repetir.
	if dist <= slam_trigger_distance and not _last_attack_was_slam:
		_last_attack_was_slam = true
		_enter_state(State.SLAM_TELEGRAPH)
		return
	if (dist > slam_trigger_distance or _last_attack_was_slam) and _state_time > 1.0:
		_last_attack_was_slam = false
		_charges_left = get_charge_repeats()
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
		spawn_particles(global_position + Vector3.UP * 0.6, SHELL_RED, 40, 4.0)
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
	return state == State.SLAM_STUCK


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
# Modelo low-poly facetado (~3x o caranguejo): carapaça, coroa dourada, pinça gigante
# ---------------------------------------------------------------------------

func _build_model() -> void:
	var mat: StandardMaterial3D = LowPolyMesh.make_material()
	_register_flash_material(mat)

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Carapaça larga e achatada, com picos
	LowPolyMesh.prism(st, Vector3(0, 0.35, 0), Vector3(0, 0.85, 0), 1.05, 0.95, 8, SHELL_RED)
	LowPolyMesh.prism(st, Vector3(0, 0.85, 0), Vector3(0, 1.1, 0), 0.95, 0.6, 8, SHELL_DARK)
	for k: int in range(6):
		var ang: float = TAU * float(k) / 6.0 + 0.3
		var base: Vector3 = Vector3(cos(ang) * 0.8, 0.88, sin(ang) * 0.8)
		LowPolyMesh.prism(st, base, base + Vector3(cos(ang) * 0.12, 0.28, sin(ang) * 0.12), 0.11, 0.0, 4, SHELL_DARK)
	# Olhos em pedúnculos
	for side: float in [-1.0, 1.0]:
		var stalk: Vector3 = Vector3(0.28 * side, 1.0, -0.7)
		LowPolyMesh.prism(st, stalk, stalk + Vector3(0, 0.35, -0.05), 0.05, 0.05, 6, SHELL_RED)
		LowPolyMesh.box(st, stalk + Vector3(0, 0.4, -0.06), Vector3(0.14, 0.14, 0.14), Basis.IDENTITY, EYE_BLACK)
	# Coroa dourada: aro + 5 pontas + gemas
	LowPolyMesh.prism(st, Vector3(0, 1.1, 0.1), Vector3(0, 1.28, 0.1), 0.38, 0.4, 8, GOLD)
	for k: int in range(5):
		var ang: float = TAU * float(k) / 5.0
		var b: Vector3 = Vector3(cos(ang) * 0.34, 1.28, 0.1 + sin(ang) * 0.34)
		LowPolyMesh.prism(st, b, b + Vector3(0, 0.26, 0), 0.08, 0.0, 4, GOLD)
		LowPolyMesh.box(st, Vector3(cos(ang) * 0.4, 1.19, 0.1 + sin(ang) * 0.4), Vector3(0.07, 0.07, 0.07), Basis(Vector3.UP, ang), GEM_RED)
	# Patas: 3 de cada lado
	for side: float in [-1.0, 1.0]:
		for k: int in range(3):
			var z: float = -0.35 + 0.4 * float(k)
			var hip: Vector3 = Vector3(0.95 * side, 0.55, z)
			var knee: Vector3 = Vector3(1.45 * side, 0.75, z + 0.05)
			var foot: Vector3 = Vector3(1.75 * side, 0.0, z + 0.1)
			LowPolyMesh.prism(st, hip, knee, 0.09, 0.08, 5, CLAW_RED)
			LowPolyMesh.prism(st, knee, foot, 0.08, 0.03, 5, CLAW_RED)
	# Pinça pequena (esquerda)
	var arm_l: Vector3 = Vector3(-0.75, 0.6, -0.75)
	LowPolyMesh.prism(st, Vector3(-0.6, 0.6, -0.5), arm_l, 0.12, 0.1, 6, CLAW_RED)
	LowPolyMesh.box(st, arm_l + Vector3(-0.05, 0.0, -0.25), Vector3(0.3, 0.22, 0.4), Basis.IDENTITY, CLAW_RED)
	body_root.add_child(LowPolyMesh.commit(st, "Body", mat))

	# Pinça gigante (direita): nó próprio para levantar/esmagar
	var cst: SurfaceTool = SurfaceTool.new()
	cst.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyMesh.prism(cst, Vector3(0, 0, 0), Vector3(0.25, 0.1, -0.6), 0.2, 0.17, 6, CLAW_RED)
	LowPolyMesh.prism(cst, Vector3(0.25, 0.1, -0.6), Vector3(0.35, 0.05, -1.5), 0.48, 0.32, 7, CLAW_RED)
	LowPolyMesh.prism(cst, Vector3(0.35, 0.2, -1.5), Vector3(0.4, 0.15, -2.15), 0.2, 0.0, 5, SHELL_DARK)
	LowPolyMesh.prism(cst, Vector3(0.3, -0.18, -1.45), Vector3(0.35, -0.2, -1.95), 0.14, 0.0, 5, SHELL_DARK)
	big_claw.add_child(LowPolyMesh.commit(cst, "Mesh", mat))
