class_name GiantMole
extends EnemyBase

## Chefe do Campo Antigo (issue #20). Acorda quando o jogador cava o altar do círculo de pedras
## (MoleAltar); nunca aparece por acaso. Ataques lentos e telegrafados (marca vermelha no chão):
##   - GARRAS: à superfície, com o jogador perto, levanta as garras e varre um círculo à frente.
##   - TÚNEL: enterra-se (imune), viaja até debaixo do jogador, treme (marca ~1 s) e irrompe.
##     Depois fica TONTA dazed_time s e leva dano x WEAK_POINT_MULTIPLIER.
##   - REFORÇOS: a 66% e 33% de vida chama 2 toupeiras.
##   - FASE 2 abaixo de 50%: túnel mais rápido e irrompe duas vezes seguidas antes de ficar tonta.
##   - CAOS (#57): o túnel é um SURF debaixo da terra que levanta uma onda de terra atrás (atira
##     para o lado quem ela apanhar); ao irromper atira o jogador ao ar e fica ENTALADA no
##     buraco (meio corpo de fora, a esbracejar: é o DAZED); de longe atira ROCHAS que rolam
##     como bolas de bowling numa faixa marcada.
## Não se afasta mais de leash_radius do sítio onde acordou. A rede só a prende NET_STUN_CAP s;
## o repelente não a afeta. Coop (#5 F): boss_defeated só é reportado por quem simula (host).

signal boss_defeated(boss_id: StringName)
signal phase_changed(phase: int)
signal reinforcements_called(count: int)
signal health_changed(current: float, max_value: float)

enum State {
	EMERGE,
	RECOVER,
	APPROACH,
	SWIPE_TELEGRAPH,
	SWIPE,
	BURROW,
	TUNNEL,
	ERUPT_TELEGRAPH,
	ERUPT,
	DAZED,
	SUMMON,
	DYING,
	ROCK_TELEGRAPH,
	ROCK,
}

const BOSS_ID: StringName = &"giant_mole"
const BOSS_NAME: String = "TOUPEIRA GIGANTE"
const GROUP_BOSSES: StringName = &"bosses"
const WEAK_POINT_MULTIPLIER: float = 2.0
const NET_STUN_CAP: float = 1.5
const REINFORCE_THRESHOLDS: Array[float] = [0.66, 0.33]
const PHASE_TWO_RATIO: float = 0.5
const UNDERGROUND_DEPTH: float = 2.4
## #57: onda de terra do surf, entalada e rochas de bowling.
const WAVE_RADIUS: float = 1.8
const STUCK_SINK: float = 1.1
const ROCK_LENGTH: float = 16.0
const ROCK_SPEED: float = 10.0
const ROCK_RADIUS: float = 0.9
const MOLE_SCENE: PackedScene = preload("res://gameplay/enemies/mole/mole.tscn")

const FUR: Color = Color(0.24, 0.18, 0.15)
const FUR_DARK: Color = Color(0.16, 0.12, 0.10)
const FUR_BELLY: Color = Color(0.32, 0.24, 0.20)
const SNOUT_PINK: Color = Color(0.92, 0.58, 0.62)
const SNOUT_NOSTRIL: Color = Color(0.55, 0.25, 0.30)
const TOOTH_WHITE: Color = Color(0.96, 0.95, 0.90)

const HELMET_YELLOW: Color = Color(0.92, 0.72, 0.15)
const HELMET_DARK: Color = Color(0.72, 0.52, 0.10)
const HELMET_RIM: Color = Color(0.85, 0.64, 0.12)
const LANTERN_BEZEL: Color = Color(0.38, 0.38, 0.40)
const LANTERN_GLOW: Color = Color(0.98, 0.96, 0.78)

const GOGGLE_FRAME: Color = Color(0.32, 0.30, 0.28)
const GOGGLE_LENS: Color = Color(0.78, 0.85, 0.86)
const GOGGLE_STRAP: Color = Color(0.22, 0.18, 0.15)
const EYE_PUPIL: Color = Color(0.08, 0.08, 0.10)
const EYE_GLINT: Color = Color(0.98, 0.98, 0.98)

const CLAW_BASE: Color = Color(0.86, 0.72, 0.54)
const CLAW_TIP: Color = Color(0.70, 0.54, 0.38)
const DIRT: Color = Color(0.44, 0.32, 0.20)
const DIRT_DARK: Color = Color(0.32, 0.22, 0.14)
const STONE: Color = Color(0.55, 0.55, 0.52)
const MOSS: Color = Color(0.35, 0.5, 0.2)

@export var move_speed: float = 1.6
@export var turn_speed: float = 3.0
@export var tunnel_speed: float = 3.4
@export var phase_two_tunnel_multiplier: float = 1.4
@export var swipe_damage: float = 18.0
@export var swipe_radius: float = 2.6
@export var swipe_trigger_distance: float = 3.0
@export var erupt_damage: float = 25.0
@export var erupt_radius: float = 3.0
@export var telegraph_time: float = 0.9
@export var erupt_telegraph_time: float = 1.1
@export var phase_two_erupt_telegraph_time: float = 0.85
@export var dazed_time: float = 2.4
@export var phase_two_dazed_time: float = 1.7
@export var recover_time: float = 1.4
@export var phase_two_recover_time: float = 0.9
@export var emerge_time: float = 2.0
@export var burrow_time: float = 0.9
## Tempo máximo a viajar debaixo de terra antes de irromper onde estiver.
@export var max_tunnel_time: float = 5.0
@export var leash_radius: float = 13.0
@export var wave_damage: float = 8.0
@export var rock_damage: float = 15.0

@onready var body_root: Node3D = $BodyRoot
@onready var claws: Node3D = $BodyRoot/Claws
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var hud: CanvasLayer = $BossHud
@onready var health_bar: ProgressBar = $BossHud/Panel/HealthBar

var state: State = State.EMERGE
var phase: int = 1
## Replicado (#31): centro do círculo do ataque telegrafado (garras ou irromper).
var net_attack_point: Vector3 = Vector3.ZERO:
	set(value):
		net_attack_point = value
		if is_node_ready() and not has_simulation_authority():
			_refresh_remote_warning()

var _state_time: float = 0.0
var _ground_y: float = 0.0
var _home: Vector3 = Vector3.ZERO
var _attack_point: Vector3 = Vector3.ZERO
var _erupts_left: int = 0
var _last_attack_was_swipe: bool = false
var _reinforce_index: int = 0
var _walk_time: float = 0.0
var _warning: GroundWarning = null
var _mound: MeshInstance3D = null
## Replicada: direção da faixa da rocha.
var net_attack_dir: Vector3 = Vector3.FORWARD
var _wave_hit: Array[Node] = []
var _burrow_count: int = 0
var _rock: MeshInstance3D = null
var _rock_hit: bool = false


func _ready() -> void:
	super._ready()
	add_to_group(GROUP_BOSSES)
	stun_fx_height = 2.6
	_ground_y = global_position.y
	_home = global_position
	_build_model()
	_warning = GroundWarning.new()
	add_child(_warning)
	health_bar.max_value = max_health
	health_bar.value = health
	boss_defeated.connect(_report_defeat_to_core)
	_enter_state(State.EMERGE)


func _enemy_physics(delta: float) -> void:
	_state_time += delta
	match state:
		State.EMERGE:
			_process_emerge()
		State.RECOVER:
			_process_recover(delta)
		State.APPROACH:
			_process_approach(delta)
		State.SWIPE_TELEGRAPH:
			_process_swipe_telegraph(delta)
		State.SWIPE:
			_process_swipe(delta)
		State.BURROW:
			_process_burrow()
		State.TUNNEL:
			_process_tunnel(delta)
		State.ERUPT_TELEGRAPH:
			_process_erupt_telegraph(delta)
		State.ERUPT:
			_process_erupt()
		State.DAZED:
			_process_dazed(delta)
		State.SUMMON:
			_process_summon(delta)
		State.ROCK_TELEGRAPH:
			_process_rock_telegraph(delta)
		State.ROCK:
			_process_rock(delta)


func _enter_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	velocity = Vector3.ZERO
	if _warning != null:
		_warning.hide_warning()
	if _rock != null:
		_rock.visible = new_state == State.ROCK or new_state == State.ROCK_TELEGRAPH
	var underground: bool = new_state in [State.EMERGE, State.BURROW, State.TUNNEL, State.ERUPT_TELEGRAPH, State.DYING]
	collision_shape.disabled = underground
	if _mound != null:
		_mound.visible = new_state == State.TUNNEL or new_state == State.ERUPT_TELEGRAPH
	match new_state:
		State.EMERGE:
			SFX.play_at(SFX.EMERGE_SAND, global_position, 6.0)
			global_position.y = _ground_y - UNDERGROUND_DEPTH
		State.SWIPE_TELEGRAPH:
			var target: Node3D = _update_target(1.0)
			var to_t: Vector3 = (target.global_position - global_position) if target != null else -global_transform.basis.z
			to_t.y = 0.0
			_attack_point = global_position + to_t.limit_length(1.4)
			_attack_point.y = _ground_y
			net_attack_point = _attack_point
			_warning.show_circle(_attack_point, swipe_radius)
		State.SWIPE:
			_do_swipe_impact()
		State.BURROW:
			SFX.play_at(SFX.EMERGE_SAND, global_position, 4.0)
			spawn_particles(global_position + Vector3.UP * 0.2, DIRT, 30, 4.0)
		State.TUNNEL:
			body_root.visible = false
			global_position.y = _ground_y - UNDERGROUND_DEPTH
			_wave_hit.clear()
			_place_mound(0.0)
		State.ERUPT_TELEGRAPH:
			_attack_point = Vector3(global_position.x, _ground_y, global_position.z)
			net_attack_point = _attack_point
			_warning.show_circle(_attack_point, erupt_radius)
		State.ERUPT:
			body_root.visible = true
			_do_erupt_impact()
		State.DAZED:
			SFX.play_at(SFX.SHELL_KNOCK, global_position, 2.0)
			spawn_particles(global_position + Vector3.UP * 0.3, DIRT, 24, 3.0)
		State.ROCK_TELEGRAPH:
			var target: Node3D = _update_target(1.0)
			var to_t: Vector3 = (target.global_position - global_position) if target != null else -global_transform.basis.z
			to_t.y = 0.0
			net_attack_dir = to_t.normalized() if to_t.length_squared() > 0.01 else Vector3.FORWARD
			_attack_point = Vector3(global_position.x, _ground_y, global_position.z)
			net_attack_point = _attack_point
			_warning.show_line(_attack_point, net_attack_dir, ROCK_LENGTH, ROCK_RADIUS * 2.0)
		State.ROCK:
			_rock_hit = false
			SFX.play_at(SFX.EMERGE_SAND, global_position, 3.0)
		State.DYING:
			body_root.visible = true


# ---------------------------------------------------------------------------
# Estados
# ---------------------------------------------------------------------------

func _process_emerge() -> void:
	var t: float = clampf(_state_time / emerge_time, 0.0, 1.0)
	global_position.y = _ground_y - UNDERGROUND_DEPTH * (1.0 - (1.0 - pow(1.0 - t, 3.0)))
	body_root.rotation.z = sin(_state_time * 25.0) * 0.08 * (1.0 - t)
	if int(_state_time * 10.0) % 3 == 0:
		spawn_particles(Vector3(global_position.x + randf_range(-1, 1), _ground_y + 0.2, global_position.z + randf_range(-1, 1)), DIRT, 6, 3.0)
	if t >= 1.0:
		global_position.y = _ground_y
		body_root.rotation.z = 0.0
		_enter_state(State.RECOVER)


func _process_recover(delta: float) -> void:
	_stand(delta)
	var wait: float = phase_two_recover_time if phase == 2 else recover_time
	if _state_time >= wait:
		_enter_state(State.APPROACH)


func _process_approach(delta: float) -> void:
	var target: Node3D = _update_target(delta)
	_apply_gravity(delta)
	if target == null:
		_stand(delta)
		return
	var to_t: Vector3 = target.global_position - global_position
	to_t.y = 0.0
	var dist: float = to_t.length()
	# Perto → garras; longe (ou depois das garras) → túnel. Alterna para não repetir.
	if dist <= swipe_trigger_distance and not _last_attack_was_swipe:
		_last_attack_was_swipe = true
		_enter_state(State.SWIPE_TELEGRAPH)
		return
	if (dist > swipe_trigger_distance or _last_attack_was_swipe) and _state_time > 1.2:
		_last_attack_was_swipe = false
		_burrow_count += 1
		# #57: de longe, uma vez em cada duas atira uma rocha em vez de surfar.
		if _burrow_count % 2 == 0 and dist > swipe_trigger_distance * 1.5:
			_enter_state(State.ROCK_TELEGRAPH)
			return
		_erupts_left = get_erupt_repeats()
		_enter_state(State.BURROW)
		return
	var dir: Vector3 = to_t / dist if dist > 0.01 else Vector3.ZERO
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	move_and_slide()
	_turn_towards(dir, 0.0, turn_speed, delta)
	_animate_walk(delta)


func _process_swipe_telegraph(delta: float) -> void:
	_stand(delta)
	var to_p: Vector3 = _attack_point - global_position
	_turn_towards(Vector3(to_p.x, 0.0, to_p.z), 0.0, turn_speed * 2.0, delta)
	claws.rotation.x = lerpf(0.0, -1.1, clampf(_state_time / telegraph_time, 0.0, 1.0))
	_warning.pulse(delta)
	if _state_time >= telegraph_time:
		_enter_state(State.SWIPE)


func _do_swipe_impact() -> void:
	claws.rotation.x = 0.5
	SFX.play_at(SFX.CRAB_PINCH, _attack_point, 4.0)
	spawn_particles(_attack_point + Vector3.UP * 0.1, DIRT, 24, 4.0)
	for p: Node3D in _players_within(_attack_point, swipe_radius):
		_deal_damage(p, swipe_damage)


func _process_swipe(delta: float) -> void:
	_stand(delta)
	if _state_time >= 0.5:
		claws.rotation.x = 0.0
		_enter_state(State.RECOVER)


func _process_burrow() -> void:
	var t: float = clampf(_state_time / burrow_time, 0.0, 1.0)
	global_position.y = _ground_y - UNDERGROUND_DEPTH * t * t
	body_root.rotation.z = sin(_state_time * 30.0) * 0.06
	if t >= 1.0:
		body_root.rotation.z = 0.0
		_enter_state(State.TUNNEL)


## Debaixo de terra: só o monte de terra se vê a avançar para o jogador (dentro da trela).
func _process_tunnel(delta: float) -> void:
	var target: Node3D = _update_target(delta)
	var goal: Vector3 = _clamp_to_leash(target.global_position if target != null else _home)
	var to_g: Vector3 = goal - global_position
	to_g.y = 0.0
	var dist: float = to_g.length()
	if dist <= 0.6 or _state_time >= max_tunnel_time:
		_enter_state(State.ERUPT_TELEGRAPH)
		return
	var speed: float = get_tunnel_speed()
	var next: Vector3 = global_position + to_g / dist * minf(speed * delta, dist)
	_ground_y = _ground_height(next, _ground_y)
	global_position = Vector3(next.x, _ground_y - UNDERGROUND_DEPTH, next.z)
	_turn_towards(to_g, 0.0, 6.0, delta)
	_place_mound(0.04 * sin(_state_time * 18.0))
	_surf_wave(to_g / dist, dist)


func _process_erupt_telegraph(delta: float) -> void:
	_warning.pulse(delta)
	_place_mound(0.08 * sin(_state_time * 40.0))
	var wait: float = phase_two_erupt_telegraph_time if phase == 2 else erupt_telegraph_time
	if _state_time >= wait:
		_enter_state(State.ERUPT)


func _do_erupt_impact() -> void:
	SFX.play_at(SFX.EMERGE_SAND, _attack_point, 8.0)
	spawn_particles(_attack_point + Vector3.UP * 0.2, DIRT, 48, 6.0)
	for p: Node3D in _players_within(_attack_point, erupt_radius):
		_deal_damage(p, erupt_damage)
		var out: Vector3 = p.global_position - _attack_point
		out.y = 0.0
		out = out.normalized() if out.length_squared() > 0.01 else Vector3.FORWARD
		# Atira ao ar (#57): sobe muito, afasta pouco.
		_knockback(p, out * 4.0 + Vector3.UP * 13.0, 0.12)


func _process_erupt() -> void:
	var t: float = clampf(_state_time / 0.35, 0.0, 1.0)
	global_position = Vector3(_attack_point.x, _ground_y - UNDERGROUND_DEPTH * (1.0 - t), _attack_point.z)
	if t >= 1.0:
		_erupts_left -= 1
		_enter_state(State.BURROW if _erupts_left > 0 else State.DAZED)


## Ponto fraco: ENTALADA no buraco (#57), meio corpo de fora a esbracejar; dano x2.
func _process_dazed(delta: float) -> void:
	_stand(delta)
	var wait: float = phase_two_dazed_time if phase == 2 else dazed_time
	_animate_stuck(_state_time, wait)
	if _state_time >= wait:
		body_root.rotation.z = 0.0
		body_root.position.y = 0.0
		claws.rotation = Vector3.ZERO
		spawn_particles(global_position + Vector3.UP * 0.3, DIRT, 20, 4.0)
		_enter_state(State.RECOVER)


## Entalada: afunda STUCK_SINK, abana o corpo e as garras às pazadas; sai com um "pop" no fim.
func _animate_stuck(t: float, wait: float) -> void:
	var out: float = clampf((t - (wait - 0.3)) / 0.3, 0.0, 1.0)
	body_root.position.y = -STUCK_SINK * (1.0 - out)
	body_root.rotation.z = sin(t * 14.0) * 0.2
	body_root.rotation.x = sin(t * 7.0) * 0.1
	claws.rotation.x = -0.8 + sin(t * 22.0) * 0.7
	claws.rotation.z = sin(t * 18.0) * 0.25
	if int(t * 10.0) % 3 == 0 and is_inside_tree():
		spawn_particles(global_position + Vector3(randf_range(-1.0, 1.0), 0.2, randf_range(-1.0, 1.0)), DIRT, 3, 3.0)


## Onda de terra atrás do monte: partículas e atira para o lado quem ela apanhar (não no fim
## do caminho, que é onde vai irromper com aviso).
func _surf_wave(dir: Vector3, dist_left: float) -> void:
	var behind: Vector3 = Vector3(global_position.x, _ground_y, global_position.z) - dir * 1.2
	if int(_state_time * 12.0) % 2 == 0:
		spawn_particles(behind + Vector3.UP * 0.2, DIRT, 5, 4.5)
	if dist_left < 3.0:
		return
	for p: Node3D in _players_within(behind + dir * 1.2, WAVE_RADIUS):
		if _wave_hit.has(p):
			continue
		_wave_hit.append(p)
		_deal_damage(p, wave_damage)
		var side: Vector3 = dir.cross(Vector3.UP)
		if side.dot(p.global_position - global_position) < 0.0:
			side = -side
		_knockback(p, side * 9.0 + dir * 3.0 + Vector3.UP * 6.0, 0.06)


## Levanta uma rocha com as garras (aviso em faixa) e atira-a a rolar.
func _process_rock_telegraph(delta: float) -> void:
	_stand(delta)
	_turn_towards(net_attack_dir, 0.0, turn_speed * 2.0, delta)
	_warning.pulse(delta)
	claws.rotation.x = lerpf(0.0, -1.4, clampf(_state_time / telegraph_time, 0.0, 1.0))
	_place_rock()
	if _state_time >= telegraph_time:
		claws.rotation.x = 0.4
		_enter_state(State.ROCK)


func _process_rock(delta: float) -> void:
	_stand(delta)
	_place_rock()
	var p: Vector3 = rock_position()
	if not _rock_hit:
		for n: Node3D in _players_within(p, ROCK_RADIUS + 0.5):
			_rock_hit = true
			_deal_damage(n, rock_damage)
			_knockback(n, net_attack_dir * 12.0 + Vector3.UP * 7.0, 0.09)
	if _state_time >= ROCK_LENGTH / ROCK_SPEED:
		spawn_particles(p, STONE, 24, 4.0)
		claws.rotation.x = 0.0
		_enter_state(State.RECOVER)


## Onde está a rocha agora (host e clientes, a partir do estado e da faixa replicada).
func rock_position() -> Vector3:
	if state == State.ROCK:
		var d: float = minf(_state_time * ROCK_SPEED, ROCK_LENGTH)
		var p: Vector3 = net_attack_point + net_attack_dir * (1.4 + d)
		return Vector3(p.x, _ground_height(p, net_attack_point.y) + ROCK_RADIUS, p.z)
	return global_position + Vector3.UP * 2.6 - net_attack_dir * 0.2


func _place_rock() -> void:
	if _rock == null:
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		# Pedra facetada com musgo, como as das costas
		LowPolyMesh.box(st, Vector3.ZERO, Vector3(1.5, 1.4, 1.5), Basis(Vector3(1, 1, 0).normalized(), 0.6), STONE)
		LowPolyMesh.box(st, Vector3.ZERO, Vector3(1.3, 1.5, 1.3), Basis(Vector3(0, 1, 1).normalized(), 0.8), STONE)
		LowPolyMesh.box(st, Vector3(0.0, 0.7, 0.0), Vector3(0.9, 0.12, 0.8), Basis.IDENTITY, MOSS)
		_rock = LowPolyMesh.commit(st, "Rock", LowPolyMesh.make_material())
		_rock.top_level = true
		add_child(_rock)
	var rolling: bool = state == State.ROCK or state == State.ROCK_TELEGRAPH
	_rock.visible = rolling
	if not rolling:
		return
	_rock.global_position = rock_position()
	if state == State.ROCK:
		var axis: Vector3 = net_attack_dir.cross(Vector3.DOWN).normalized()
		if axis.length_squared() > 0.01:
			_rock.global_basis = Basis(axis, _state_time * ROCK_SPEED / ROCK_RADIUS)


func _process_summon(delta: float) -> void:
	_stand(delta)
	body_root.rotation.x = -sin(clampf(_state_time / 1.2, 0.0, 1.0) * PI) * 0.25
	if _state_time >= 1.2:
		body_root.rotation.x = 0.0
		_enter_state(State.RECOVER)


## Queda: tomba de lado e afunda; reporta a vitória a meio.
func _process_dying(_delta: float) -> void:
	var t: float = clampf(_state_time / 1.8, 0.0, 1.0)
	body_root.rotation.z = lerpf(0.0, 1.4, t * t)
	body_root.position.y = -0.5 * t
	if _state_time >= 1.8 and _state_time - _delta < 1.8:
		hud.visible = false
		boss_defeated.emit(BOSS_ID)
	if _state_time >= 3.0:
		spawn_particles(global_position + Vector3.UP * 0.8, FUR, 40, 4.0)
		queue_free()


func _stand(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()


# ---------------------------------------------------------------------------
# Regras de combate (públicas para os testes)
# ---------------------------------------------------------------------------

func is_phase_two() -> bool:
	return health < max_health * PHASE_TWO_RATIO


func get_tunnel_speed() -> float:
	return tunnel_speed * (phase_two_tunnel_multiplier if phase == 2 else 1.0)


func get_erupt_repeats() -> int:
	return 2 if phase == 2 else 1


func is_weak_point_exposed() -> bool:
	return state == State.DAZED


func is_stuck_in_hole() -> bool:
	return state == State.DAZED


func is_underground() -> bool:
	return state in [State.BURROW, State.TUNNEL, State.ERUPT_TELEGRAPH]


func get_home() -> Vector3:
	return _home


## Começa já acordada (testes / debug), sem a animação de sair da terra.
func wake_immediately() -> void:
	if state == State.EMERGE:
		global_position.y = _ground_y
		_enter_state(State.RECOVER)


func _clamp_to_leash(p: Vector3) -> Vector3:
	var off: Vector3 = p - _home
	off.y = 0.0
	return _home + off.limit_length(leash_radius)


func _can_take_damage() -> bool:
	return not (state in [State.EMERGE, State.BURROW, State.TUNNEL, State.ERUPT_TELEGRAPH, State.DYING])


func _can_be_stunned() -> bool:
	return _can_take_damage()


func _modify_damage(amount: float, _from: Vector3) -> float:
	return amount * WEAK_POINT_MULTIPLIER if is_weak_point_exposed() else amount


func stun(seconds: float) -> void:
	super.stun(minf(seconds, NET_STUN_CAP))


## O repelente não a afeta.
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
	var count: int = 2
	var parent: Node = get_parent()
	if parent == null:
		return
	for i: int in range(count):
		var ang: float = TAU * float(i) / float(count) + randf() * 0.5
		var pos: Vector3 = Vector3(global_position.x, _ground_y, global_position.z) + Vector3(cos(ang), 0.0, sin(ang)) * 4.0
		if _spawn_minion(&"mole", pos) != null:
			continue
		var mole: Mole = MOLE_SCENE.instantiate() as Mole
		mole.spawn_level = 0
		mole.position = pos
		parent.add_child(mole)
		mole.global_position = pos
	reinforcements_called.emit(count)
	if state == State.APPROACH or state == State.RECOVER:
		_enter_state(State.SUMMON)


func _on_died() -> void:
	health_bar.value = 0.0
	_set_stun_fx(false)
	_enter_state(State.DYING)
	set_physics_process(false)


func _process(delta: float) -> void:
	if state == State.DYING and _dead:
		_state_time += delta
		_process_dying(delta)
	elif not has_simulation_authority():
		# Cliente: barra de vida, monte de terra e aviso a partir do estado replicado.
		health_bar.value = health
		if _mound.visible:
			_place_mound(0.04 * sin(Time.get_ticks_msec() * 0.018))
		if _warning.visible:
			_warning.pulse(delta)
		if state == State.DAZED or state == State.ROCK or state == State.ROCK_TELEGRAPH:
			_state_time += delta
			if state == State.DAZED:
				_animate_stuck(_state_time, phase_two_dazed_time if phase == 2 else dazed_time)
			else:
				_place_rock()
		elif body_root.position.y < 0.0:
			body_root.position.y = 0.0


## Cliente: corpo/monte/aviso/colisão a partir do estado do host.
func _on_remote_state(new_state: int) -> void:
	_state_time = 0.0
	if _rock != null and new_state != State.ROCK and new_state != State.ROCK_TELEGRAPH:
		_rock.visible = false
	var underground: bool = new_state in [State.BURROW, State.TUNNEL, State.ERUPT_TELEGRAPH]
	body_root.visible = not (new_state == State.TUNNEL or new_state == State.ERUPT_TELEGRAPH)
	collision_shape.disabled = underground or new_state == State.EMERGE or new_state == State.DYING
	_mound.visible = new_state == State.TUNNEL or new_state == State.ERUPT_TELEGRAPH
	if _mound.visible:
		_ground_y = global_position.y + UNDERGROUND_DEPTH
	if new_state == State.DYING:
		hud.visible = false
	_refresh_remote_warning()


## Cliente: aviso no ponto replicado (estado e ponto podem chegar por qualquer ordem).
func _refresh_remote_warning() -> void:
	_warning.hide_warning()
	match state:
		State.SWIPE_TELEGRAPH:
			_warning.show_circle(net_attack_point, swipe_radius)
		State.ERUPT_TELEGRAPH:
			_warning.show_circle(net_attack_point, erupt_radius)
		State.ROCK_TELEGRAPH:
			_warning.show_line(net_attack_point, net_attack_dir, ROCK_LENGTH, ROCK_RADIUS * 2.0)


func setup_network() -> void:
	super.setup_network()
	_add_synced_property(".:net_attack_point")
	_add_synced_property(".:net_attack_dir")


## Cliente: anda à superfície conforme a velocidade replicada.
func _animate_remote(delta: float, speed: float) -> void:
	if speed > 0.15 and body_root.visible and state != State.DYING:
		_animate_walk(delta * clampf(speed / move_speed, 0.5, 3.0))


## Avisa o core (o host valida, ignora repetidos e libera a compra das Ruínas).
func _report_defeat_to_core(boss_id: StringName) -> void:
	if has_simulation_authority() and GameState.instance != null:
		GameState.instance.request_report_boss_defeated(String(boss_id))


# ---------------------------------------------------------------------------
# Modelo low-poly (~3x a toupeira): corpo, pedras com musgo nas costas, garras enormes
# ---------------------------------------------------------------------------

func _place_mound(wobble: float) -> void:
	if _mound != null:
		_mound.global_position = Vector3(global_position.x, _ground_y + wobble, global_position.z)


func _animate_walk(delta: float) -> void:
	_walk_time += delta * 5.0
	body_root.position.y = absf(sin(_walk_time)) * 0.07
	body_root.rotation.z = sin(_walk_time) * 0.04


func _build_model() -> void:
	var mat: ShaderMaterial = ToonKit.vertex_material(true, true)
	_register_flash_material(mat)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 1. Base / montículo de terra e pedras de onde a toupeira irrompe (como na referência toupeira_gigante.jpg)
	LowPolyMesh.prism(st, Vector3(0, -0.15, 0.0), Vector3(0, 0.35, 0.0), 1.60, 1.35, 10, DIRT)
	for k: int in range(9):
		var ang: float = TAU * float(k) / 9.0 + 0.15
		var r_rubble: float = 1.45 + sin(float(k) * 2.3) * 0.15
		var r_pos: Vector3 = Vector3(cos(ang) * r_rubble, 0.15 + absf(sin(float(k) * 1.7)) * 0.15, sin(ang) * (r_rubble * 0.9))
		var r_col: Color = DIRT_DARK if k % 2 == 0 else DIRT
		LowPolyMesh.box(st, r_pos, Vector3(0.32, 0.22, 0.28), Basis(Vector3.UP, ang).rotated(Vector3.RIGHT, 0.2), r_col)

	# 2. Corpo volumoso em dois troncos (barriga e tronco/pescoço)
	LowPolyMesh.prism(st, Vector3(0, 0.30, 0.10), Vector3(0, 1.15, 0.02), 1.28, 1.12, 10, FUR)
	# Mancha da barriga
	LowPolyMesh.prism(st, Vector3(0, 0.38, -0.45), Vector3(0, 1.10, -0.42), 0.65, 0.55, 6, FUR_BELLY)
	# Tronco superior e pescoço
	LowPolyMesh.prism(st, Vector3(0, 1.15, 0.02), Vector3(0, 1.85, -0.15), 1.12, 0.88, 10, FUR)

	# Manchas de terra e sujidade espalhadas pelo peito e ombros
	var dirt_spots: Array[Vector3] = [
		Vector3(-0.45, 1.35, -0.65), Vector3(0.50, 1.25, -0.62), Vector3(-0.25, 0.95, -0.85),
		Vector3(0.35, 0.85, -0.82), Vector3(-0.65, 1.55, -0.35), Vector3(0.65, 1.55, -0.35)
	]
	for sp: Vector3 in dirt_spots:
		LowPolyMesh.box(st, sp, Vector3(0.24, 0.16, 0.08), Basis.IDENTITY, DIRT_DARK)

	# Pedras com musgo agarradas às costas (veio de debaixo do círculo de pedras)
	for k: int in range(5):
		var ang: float = PI * 0.15 + PI * 0.7 * float(k) / 4.0
		var c: Vector3 = Vector3(cos(ang) * 0.82, 1.15 + sin(ang) * 0.45, 0.75)
		LowPolyMesh.box(st, c, Vector3(0.38, 0.32, 0.32), Basis(Vector3.UP, ang), STONE)
		LowPolyMesh.box(st, c + Vector3(0, 0.18, 0), Vector3(0.32, 0.07, 0.26), Basis(Vector3.UP, ang), MOSS)

	# 3. Focinho rosado proeminente, arredondado e facetado com narinas escuras
	LowPolyMesh.prism(st, Vector3(0, 1.42, -0.72), Vector3(0, 1.36, -1.25), 0.42, 0.30, 8, SNOUT_PINK)
	LowPolyMesh.prism(st, Vector3(0, 1.36, -1.23), Vector3(0, 1.36, -1.28), 0.30, 0.26, 8, SNOUT_PINK)
	# Narinas
	LowPolyMesh.box(st, Vector3(-0.09, 1.35, -1.29), Vector3(0.07, 0.06, 0.02), Basis(Vector3.FORWARD, 0.35), SNOUT_NOSTRIL)
	LowPolyMesh.box(st, Vector3(0.09, 1.35, -1.29), Vector3(0.07, 0.06, 0.02), Basis(Vector3.FORWARD, -0.35), SNOUT_NOSTRIL)

	# Dentes de roedor / cinzel salientes sob o focinho
	LowPolyMesh.box(st, Vector3(-0.065, 1.18, -1.02), Vector3(0.06, 0.12, 0.04), Basis(Vector3.RIGHT, 0.15), TOOTH_WHITE)
	LowPolyMesh.box(st, Vector3(0.065, 1.18, -1.02), Vector3(0.06, 0.12, 0.04), Basis(Vector3.RIGHT, 0.15), TOOTH_WHITE)

	# 4. Óculos de proteção retro de mineiro (goggles com lentes claras e armação metálica)
	# Fita elástica de couro a toda a volta da cabeça
	LowPolyMesh.prism(st, Vector3(0, 1.72, 0.42), Vector3(0, 1.72, -0.68), 0.88, 0.88, 10, GOGGLE_STRAP)
	for side: float in [-1.0, 1.0]:
		var g_center: Vector3 = Vector3(0.32 * side, 1.72, -0.92)
		# Armação metálica grossa
		LowPolyMesh.prism(st, g_center + Vector3(0, 0, 0.08), g_center - Vector3(0, 0, 0.06), 0.28, 0.25, 8, GOGGLE_FRAME)
		# Lente de vidro claro
		LowPolyMesh.prism(st, g_center + Vector3(0, 0, 0.03), g_center - Vector3(0, 0, 0.04), 0.22, 0.22, 8, GOGGLE_LENS)
		# Olho/pupila expressiva por trás da lente
		LowPolyMesh.prism(st, g_center - Vector3(0, 0, 0.04), g_center - Vector3(0, 0, 0.05), 0.08, 0.08, 6, EYE_PUPIL)
		# Brilho branco na pupila
		LowPolyMesh.box(st, g_center + Vector3(-0.03 * side, 0.04, -0.055), Vector3(0.03, 0.03, 0.01), Basis.IDENTITY, EYE_GLINT)
	# Ponte de ligação entre as lentes
	LowPolyMesh.box(st, Vector3(0, 1.72, -0.95), Vector3(0.14, 0.08, 0.06), Basis.IDENTITY, GOGGLE_FRAME)

	# 5. Capacete de mineiro amarelo com lanterna frontal
	# Aba do capacete
	LowPolyMesh.prism(st, Vector3(0, 1.98, -0.22), Vector3(0, 2.08, -0.22), 0.98, 0.92, 10, HELMET_RIM)
	LowPolyMesh.box(st, Vector3(0, 2.02, -1.05), Vector3(0.75, 0.06, 0.28), Basis(Vector3.RIGHT, -0.18), HELMET_YELLOW)
	# Cúpula amarela do capacete
	LowPolyMesh.prism(st, Vector3(0, 2.08, -0.22), Vector3(0, 2.65, -0.25), 0.90, 0.45, 9, HELMET_YELLOW)
	# Nervura central de reforço
	LowPolyMesh.box(st, Vector3(0, 2.42, -0.24), Vector3(0.12, 0.50, 1.05), Basis.IDENTITY, HELMET_DARK)
	# Mancha de lama no capacete
	LowPolyMesh.box(st, Vector3(-0.35, 2.32, -0.68), Vector3(0.20, 0.16, 0.05), Basis(Vector3.FORWARD, 0.3), DIRT_DARK)

	# Lanterna de mineiro na frente do capacete
	var lamp_center: Vector3 = Vector3(0, 2.28, -0.98)
	LowPolyMesh.prism(st, lamp_center + Vector3(0, 0, 0.12), lamp_center - Vector3(0, 0, 0.16), 0.22, 0.20, 8, LANTERN_BEZEL)
	LowPolyMesh.prism(st, lamp_center - Vector3(0, 0, 0.14), lamp_center - Vector3(0, 0, 0.18), 0.16, 0.15, 8, LANTERN_GLOW)
	LowPolyMesh.box(st, lamp_center + Vector3(0, 0.18, 0.05), Vector3(0.08, 0.16, 0.10), Basis.IDENTITY, LANTERN_BEZEL)

	body_root.add_child(LowPolyMesh.commit(st, "Body", mat))

	# 6. Braços musculados erguidos e garras colossais de escavação (no nó Claws para animação)
	var cst: SurfaceTool = SurfaceTool.new()
	cst.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-1.0, 1.0]:
		# Posições relativas ao nó Claws (pivot em 0, 0.75, -0.6)
		var shoulder: Vector3 = Vector3(0.95 * side, 0.40, 0.42)
		var elbow: Vector3 = Vector3(1.48 * side, 0.85, 0.25)
		var palm: Vector3 = Vector3(1.88 * side, 1.32, 0.10)

		# Braço
		LowPolyMesh.prism(cst, shoulder, elbow, 0.38, 0.32, 7, FUR)
		LowPolyMesh.box(cst, shoulder + Vector3(0, 0.12, 0), Vector3(0.24, 0.08, 0.24), Basis.IDENTITY, DIRT_DARK)
		# Antebraço
		LowPolyMesh.prism(cst, elbow, palm, 0.32, 0.40, 7, FUR_DARK)

		# Palma em pá larga de toupeira virada para a frente e para cima
		var palm_basis: Basis = Basis(Vector3.FORWARD, -0.42 * side).rotated(Vector3.UP, -0.22 * side)
		LowPolyMesh.box(cst, palm, Vector3(0.50, 0.54, 0.24), palm_basis, FUR_DARK)

		# 4 garras colossais curvas e pontiagudas em cada pata
		for k: int in 4:
			var claw_x_offset: float = (float(k) * 0.15 - 0.225)
			var c_base: Vector3 = palm + palm_basis.x * claw_x_offset + palm_basis.y * 0.26
			var c_mid: Vector3 = c_base + palm_basis.y * 0.32 + palm_basis.z * -0.14 + palm_basis.x * (0.05 * float(k - 1) * side)
			var c_tip: Vector3 = c_mid + palm_basis.y * 0.30 + palm_basis.z * -0.18 + palm_basis.x * (0.08 * float(k - 1) * side)
			LowPolyMesh.prism(cst, c_base, c_mid, 0.11, 0.07, 5, CLAW_BASE)
			LowPolyMesh.prism(cst, c_mid, c_tip, 0.07, 0.015, 4, CLAW_TIP)

	claws.add_child(LowPolyMesh.commit(cst, "Mesh", mat))

	var mst: SurfaceTool = SurfaceTool.new()
	mst.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyMesh.prism(mst, Vector3(0, -0.1, 0), Vector3(0, 0.55, 0), 1.3, 0.35, 9, DIRT)
	_mound = LowPolyMesh.commit(mst, "Mound", LowPolyMesh.make_material())
	_mound.top_level = true
	_mound.visible = false
	add_child(_mound)

