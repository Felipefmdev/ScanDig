class_name Scarecrow
extends EnemyBase

## Espantalho Desperto (#41): chefe escondido do Campo. Acorda à noite na lavoura quando os 8
## menires acendem pela ordem do sol (BossTrigger com night). Anda devagar para o jogador mais
## próximo e alterna dois ataques telegrafados:
##   - VARRIDELA da foice: círculo vermelho à volta dele (SWEEP_RADIUS); depois fica TONTO
##     DIZZY_TIME s (dano a dobrar);
##   - ABÓBORA: atira-a ao sítio onde o jogador está (círculo + arco visível), rebenta em
##     PUMPKIN_RADIUS.
## Caos (#57): a abóbora SALTA (2.º círculo mais à frente) e REBENTA em sementes; DESMANCHA-SE
## em palha e remonta noutro sítio (círculo onde vai aparecer, atira quem lá estiver); RODOPIO
## de braços abertos a correr para o jogador e depois fica tonto.
## Chama corvos aos 66 % e 33 %. Ao morrer desfaz-se em palha e larga a Lanterna do Espantalho.
## Coop (#24): IA no host; estado e ponto do ataque (net_attack_point) vão para os clientes.

signal boss_defeated(boss_id: StringName)
signal health_changed(current: float, max_value: float)

enum State { EMERGE, WALK, SWEEP_TELEGRAPH, SWEEP, DIZZY, THROW_TELEGRAPH, THROW, DYING, STRAW_OUT, STRAW_IN, WHIRL_TELEGRAPH, WHIRL }

const BOSS_ID: StringName = &"scarecrow"
const BOSS_NAME: String = "ESPANTALHO DESPERTO"
const GROUP_BOSSES: StringName = &"bosses"
const TROPHY_ITEM_ID: String = "lanterna_espantalho"
const SWEEP_RADIUS: float = 3.0
const PUMPKIN_RADIUS: float = 2.0
const WEAK_POINT_MULTIPLIER: float = 2.0
const REINFORCE_THRESHOLDS: Array[float] = [0.66, 0.33]
const PHASE_TWO_RATIO: float = 0.5
## #57: abóbora saltitona, palha e rodopio.
const BOUNCE_DISTANCE: float = 3.2
const BOUNCE_RADIUS: float = 1.2
const STRAW_RADIUS: float = 2.4
const STRAW_TIME: float = 1.1
const STRAW_DISTANCE: float = 3.5
const WHIRL_RADIUS: float = 2.0
const WHIRL_SPEED: float = 5.5
const WHIRL_TIME: float = 3.0
const THROW_FLIGHT: float = 0.9

const SACK: Color = Color(0.72, 0.58, 0.44)
const COAT_BROWN: Color = Color(0.38, 0.30, 0.22)
const COAT_PLAID: Color = Color(0.28, 0.22, 0.18)
const PANTS_OLIVE: Color = Color(0.32, 0.36, 0.26)
const PATCH_ORANGE: Color = Color(0.85, 0.46, 0.16)
const PATCH_GREEN: Color = Color(0.26, 0.46, 0.22)
const PATCH_RED: Color = Color(0.72, 0.22, 0.18)
const PATCH_BLUE: Color = Color(0.25, 0.35, 0.55)
const BOOTS: Color = Color(0.30, 0.28, 0.26)
const ROPE: Color = Color(0.82, 0.74, 0.54)
const STRAW: Color = Color(0.94, 0.82, 0.36)
const STRAW_DARK: Color = Color(0.78, 0.65, 0.26)

const PUMPKIN: Color = Color(0.94, 0.52, 0.14)
const PUMPKIN_DARK: Color = Color(0.76, 0.38, 0.10)
const STEM: Color = Color(0.35, 0.45, 0.15)
const GLOW: Color = Color(1.0, 0.80, 0.25)
const GLOW_EYE: Color = Color(1.0, 0.65, 0.15)
const MOUTH_DARK: Color = Color(0.18, 0.12, 0.08)

const HAT: Color = Color(0.42, 0.30, 0.20)
const HAT_BAND: Color = Color(0.68, 0.58, 0.42)

const WOOD: Color = Color(0.46, 0.32, 0.18)
const WOOD_DARK: Color = Color(0.32, 0.20, 0.12)
const SCYTHE_RUST: Color = Color(0.60, 0.38, 0.26)
const SCYTHE_IRON: Color = Color(0.50, 0.52, 0.55)
const BLADE: Color = SCYTHE_RUST

const LANTERN_RUST: Color = Color(0.38, 0.26, 0.18)
const LANTERN_GLASS: Color = Color(0.96, 0.85, 0.45)

const CROW_BLACK: Color = Color(0.10, 0.10, 0.12)
const CROW_BEAK: Color = Color(0.88, 0.70, 0.20)

@export var move_speed: float = 1.5
@export var turn_speed: float = 3.0
@export var sweep_damage: float = 20.0
@export var pumpkin_damage: float = 16.0
@export var sweep_telegraph: float = 1.0
@export var throw_telegraph: float = 1.4
@export var dizzy_time: float = 1.8
@export var emerge_time: float = 2.4
## Distância a partir da qual atira abóboras em vez de varrer.
@export var throw_distance: float = 5.0
@export var attack_cooldown: float = 1.2
@export var whirl_damage: float = 12.0
@export var straw_damage: float = 10.0

var state: State = State.EMERGE
var phase: int = 1
var net_attack_point: Vector3 = Vector3.ZERO:
	set(value):
		net_attack_point = value
		if not has_simulation_authority():
			_refresh_remote_visuals()

var _state_time: float = 0.0
var _cooldown: float = 1.0
var _surface_y: float = 0.0
var _hit_done: bool = false
var _reinforce_index: int = 0
var _hud: BossHud = null
var _warning: GroundWarning = null
var _body_root: Node3D = null
var _scythe: Node3D = null
var _pumpkin: MeshInstance3D = null
var _throw_from: Vector3 = Vector3.ZERO
var _anim_time: float = 0.0
var _warning2: GroundWarning = null
var _hit_list: Array[Node] = []
var _attack_count: int = 0
var _straw_fx: CPUParticles3D = null


func _ready() -> void:
	super._ready()
	add_to_group(GROUP_BOSSES)
	stun_fx_height = 2.6
	death_color = STRAW
	_build_model()
	_hud = BossHud.create("🎃 " + BOSS_NAME, max_health, Color(0.95, 0.5, 0.1))
	add_child(_hud)
	_warning = GroundWarning.new()
	add_child(_warning)
	_warning2 = GroundWarning.new()
	add_child(_warning2)
	boss_defeated.connect(_report_defeat_to_core)
	_enter_state(State.EMERGE)


func setup_network() -> void:
	super.setup_network()
	_add_synced_property(".:net_attack_point")


func _enemy_physics(delta: float) -> void:
	_state_time += delta
	match state:
		State.EMERGE:
			var t: float = clampf(_state_time / emerge_time, 0.0, 1.0)
			global_position.y = _surface_y - 2.2 * (1.0 - t)
			if t >= 1.0:
				_hud.visible = true
				_enter_state(State.WALK)
		State.WALK:
			_process_walk(delta)
		State.SWEEP_TELEGRAPH:
			_warning.pulse(delta)
			if _state_time >= sweep_telegraph * (0.75 if phase == 2 else 1.0):
				_enter_state(State.SWEEP)
		State.SWEEP:
			if not _hit_done and _state_time >= 0.15:
				_hit_done = true
				_damage_circle(global_position, SWEEP_RADIUS, sweep_damage)
			if _state_time >= 0.5:
				_enter_state(State.DIZZY)
		State.DIZZY:
			if _state_time >= dizzy_time:
				_cooldown = attack_cooldown
				_enter_state(State.WALK)
		State.THROW_TELEGRAPH:
			_warning.pulse(delta)
			_warning2.pulse(delta)
			if _state_time >= throw_telegraph * (0.8 if phase == 2 else 1.0):
				_enter_state(State.THROW)
		State.THROW:
			_warning.pulse(delta)
			_warning2.pulse(delta)
			# 1.º toque: salta (pequeno); 2.º: rebenta em sementes.
			if _hit_list.is_empty() and _state_time >= 0.1:
				_hit_list.append(self)
				_damage_circle(net_attack_point, BOUNCE_RADIUS, pumpkin_damage * 0.4, 5.0)
				spawn_particles(net_attack_point + Vector3.UP * 0.2, Color(0.5, 0.42, 0.25), 10, 2.5)
				_warning.hide_warning()
			if not _hit_done and _state_time >= 0.1 + THROW_FLIGHT * 0.7:
				_hit_done = true
				_explode_pumpkin(bounce_point())
			if _state_time >= 0.1 + THROW_FLIGHT * 0.7 + 0.3:
				_cooldown = attack_cooldown * 0.6
				_enter_state(State.WALK)
		State.STRAW_OUT:
			if _state_time >= STRAW_TIME * (0.8 if phase == 2 else 1.0):
				_enter_state(State.STRAW_IN)
		State.STRAW_IN:
			if not _hit_done and _state_time >= 0.15:
				_hit_done = true
				_damage_circle(global_position, STRAW_RADIUS, straw_damage, 9.0)
			if _state_time >= 0.6:
				_cooldown = attack_cooldown * 0.5
				_enter_state(State.WALK)
		State.WHIRL_TELEGRAPH:
			_warning.pulse(delta)
			if _state_time >= sweep_telegraph * (0.75 if phase == 2 else 1.0):
				_enter_state(State.WHIRL)
		State.WHIRL:
			_process_whirl(delta)


func _process_walk(delta: float) -> void:
	_apply_gravity(delta)
	var target: Node3D = _update_target(delta)
	_cooldown -= delta
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
	if _cooldown <= 0.0:
		# #57: um ataque em cada três é caótico (palha ou rodopio).
		if _attack_count % 3 == 2:
			_attack_count += 1
			if dist >= throw_distance or _attack_count % 2 == 0:
				var behind: Vector3 = target.global_position + dir * STRAW_DISTANCE
				net_attack_point = Vector3(behind.x, _ground_height(behind, _surface_y), behind.z)
				_enter_state(State.STRAW_OUT)
			else:
				net_attack_point = global_position
				_enter_state(State.WHIRL_TELEGRAPH)
			return
		if dist <= SWEEP_RADIUS * 0.85:
			_attack_count += 1
			_enter_state(State.SWEEP_TELEGRAPH)
			return
		if dist >= throw_distance:
			# Os pés do jogador (um raio ao chão bateria no próprio jogador, que está na camada 1).
			_attack_count += 1
			net_attack_point = target.global_position
			_enter_state(State.THROW_TELEGRAPH)
			return
	var speed: float = move_speed * (1.3 if phase == 2 else 1.0)
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	move_and_slide()


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


func _enter_state(s: State) -> void:
	state = s
	_state_time = 0.0
	_hit_done = false
	_hit_list.clear()
	_warning2.hide_warning()
	if _body_root != null:
		_body_root.visible = s != State.STRAW_OUT
	match s:
		State.EMERGE:
			_surface_y = global_position.y
			global_position.y = _surface_y - 2.2
			collision_layer = 0
		State.WALK:
			collision_layer = 8
			_warning.hide_warning()
		State.SWEEP_TELEGRAPH:
			net_attack_point = global_position
			_warning.show_circle(global_position, SWEEP_RADIUS)
		State.THROW_TELEGRAPH, State.THROW:
			if s == State.THROW_TELEGRAPH:
				_throw_from = global_position + Vector3.UP * 2.0
			_warning.show_circle(net_attack_point, BOUNCE_RADIUS)
			_warning2.show_circle(bounce_point(), PUMPKIN_RADIUS)
		State.SWEEP, State.DIZZY:
			_warning.hide_warning()
		State.STRAW_OUT:
			# Desmancha-se: nuvem de palha aqui, círculo onde vai remontar.
			collision_layer = 0
			_burst_straw(global_position)
			_warning.show_circle(net_attack_point, STRAW_RADIUS)
		State.STRAW_IN:
			_warning.hide_warning()
			if has_simulation_authority():
				global_position = net_attack_point
			collision_layer = 8
			_burst_straw(net_attack_point)
		State.WHIRL_TELEGRAPH:
			_warning.show_circle(global_position, WHIRL_RADIUS)
		State.WHIRL:
			_warning.hide_warning()


func _damage_circle(center: Vector3, radius: float, damage: float, push: float = 6.0) -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group(&"players")
	if players.is_empty():
		players = get_tree().get_nodes_in_group(&"player")
	for n: Node in players:
		var pl: Node3D = n as Node3D
		if pl == null:
			continue
		var d: Vector3 = pl.global_position - center
		d.y = 0.0
		if d.length() <= radius:
			_deal_damage(pl, damage)
			var out: Vector3 = d.normalized() if d.length_squared() > 0.01 else -global_transform.basis.z
			_knockback(pl, out * push + Vector3.UP * push * 0.8, 0.06)


# ---------------------------------------------------------------------------
# Regras de combate
# ---------------------------------------------------------------------------

func is_phase_two() -> bool:
	return health < max_health * PHASE_TWO_RATIO


## Onde a abóbora salta depois do 1.º toque (continua na direção do lançamento).
func bounce_point() -> Vector3:
	var dir: Vector3 = net_attack_point - Vector3(_throw_from.x, net_attack_point.y, _throw_from.z)
	dir.y = 0.0
	dir = dir.normalized() if dir.length_squared() > 0.01 else -global_transform.basis.z
	var p: Vector3 = net_attack_point + dir * BOUNCE_DISTANCE
	return Vector3(p.x, _ground_height(p, net_attack_point.y), p.z)


func _explode_pumpkin(at: Vector3) -> void:
	_damage_circle(at, PUMPKIN_RADIUS, pumpkin_damage, 8.0)
	spawn_particles(at + Vector3.UP * 0.3, PUMPKIN, 24, 5.0)
	# Sementes claras a voar em todas as direções
	spawn_particles(at + Vector3.UP * 0.4, Color(0.98, 0.93, 0.75), 30, 7.0)
	SFX.play_at(SFX.EMERGE_SAND, at, 6.0)


## Rodopio de braços abertos: corre para o alvo a girar, atira quem toca; no fim fica tonto.
func _process_whirl(delta: float) -> void:
	_apply_gravity(delta)
	var target: Node3D = _update_target(delta)
	if target != null:
		var to: Vector3 = target.global_position - global_position
		to.y = 0.0
		var dir: Vector3 = to.normalized() if to.length() > 0.2 else Vector3.ZERO
		var speed: float = WHIRL_SPEED * (1.2 if phase == 2 else 1.0)
		velocity.x = lerpf(velocity.x, dir.x * speed, clampf(2.5 * delta, 0.0, 1.0))
		velocity.z = lerpf(velocity.z, dir.z * speed, clampf(2.5 * delta, 0.0, 1.0))
	move_and_slide()
	for p: Node3D in _players_within(global_position, WHIRL_RADIUS):
		if _hit_list.has(p):
			continue
		_hit_list.append(p)
		_deal_damage(p, whirl_damage)
		var out: Vector3 = p.global_position - global_position
		out.y = 0.0
		out = out.normalized() if out.length_squared() > 0.01 else Vector3.FORWARD
		_knockback(p, (out + out.cross(Vector3.UP)) * 9.0 + Vector3.UP * 7.0, 0.08)
	if fmod(_state_time, 0.9) < delta:
		_hit_list.clear()
	if _state_time >= WHIRL_TIME:
		velocity = Vector3.ZERO
		_enter_state(State.DIZZY)


func _burst_straw(at: Vector3) -> void:
	if not is_inside_tree():
		return
	spawn_particles(at + Vector3.UP * 1.2, STRAW, 36, 4.5)
	spawn_particles(at + Vector3.UP * 0.6, SACK, 12, 3.0)
	if _straw_fx == null:
		_straw_fx = CPUParticles3D.new()
		_straw_fx.name = "StrawCloud"
		_straw_fx.top_level = true
		_straw_fx.one_shot = true
		_straw_fx.explosiveness = 0.9
		_straw_fx.amount = 40
		_straw_fx.lifetime = 1.2
		_straw_fx.spread = 180.0
		_straw_fx.initial_velocity_min = 2.0
		_straw_fx.initial_velocity_max = 5.0
		_straw_fx.gravity = Vector3(0.0, -3.0, 0.0)
		_straw_fx.angular_velocity_min = -400.0
		_straw_fx.angular_velocity_max = 400.0
		# Fios de palha (prismas finos amarelos)
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		LowPolyMesh.prism(st, Vector3(0.0, -0.14, 0.0), Vector3(0.0, 0.14, 0.0), 0.015, 0.0, 4, STRAW)
		var mesh: Mesh = ToonKit.commit(st)
		mesh.surface_set_material(0, LowPolyMesh.make_material())
		_straw_fx.mesh = mesh
		add_child(_straw_fx)
	_straw_fx.global_position = at + Vector3.UP * 1.2
	_straw_fx.restart()


func is_weak_point_exposed() -> bool:
	return state == State.DIZZY


func _can_take_damage() -> bool:
	return state != State.EMERGE and state != State.DYING and state != State.STRAW_OUT


func _can_be_stunned() -> bool:
	return state == State.WALK or state == State.DIZZY


func _modify_damage(amount: float, _from: Vector3) -> float:
	return amount * WEAK_POINT_MULTIPLIER if is_weak_point_exposed() else amount


## O repelente não o afeta (é de palha!).
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
			var pos: Vector3 = global_position + Vector3(cos(ang) * 5.0, 4.0, sin(ang) * 5.0)
			_spawn_minion(&"crow", pos)
	if phase == 1 and is_phase_two():
		phase = 2


## Testes/debug: começa já acordado.
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


func _process_dying() -> void:
	var t: float = clampf(_state_time / 1.6, 0.0, 1.0)
	_body_root.rotation.x = lerpf(0.0, -1.4, t * t)
	if _state_time >= 1.0 and _state_time - get_process_delta_time() < 1.0:
		_hud.visible = false
		spawn_particles(global_position + Vector3.UP * 1.0, STRAW, 40, 4.0)
		if has_simulation_authority():
			QuestRewards.drop_item(get_tree(), TROPHY_ITEM_ID, global_position + Vector3.UP * 1.5)
		boss_defeated.emit(BOSS_ID)
	if _state_time >= 2.2:
		queue_free()


func _report_defeat_to_core(boss_id: StringName) -> void:
	if has_simulation_authority() and GameState.instance != null:
		GameState.instance.request_report_boss_defeated(String(boss_id))


func _on_remote_state(new_state: int) -> void:
	_state_time = 0.0
	_hud.visible = new_state != State.EMERGE and new_state != State.DYING
	if new_state == State.THROW_TELEGRAPH:
		_throw_from = global_position + Vector3.UP * 2.0
	if _body_root != null:
		_body_root.visible = new_state != State.STRAW_OUT
	if new_state == State.STRAW_OUT:
		_burst_straw(global_position)
	elif new_state == State.STRAW_IN:
		_burst_straw(net_attack_point)
	_refresh_remote_visuals()


func _refresh_remote_visuals() -> void:
	_warning2.hide_warning()
	match state:
		State.SWEEP_TELEGRAPH:
			_warning.show_circle(net_attack_point, SWEEP_RADIUS)
		State.THROW_TELEGRAPH:
			_warning.show_circle(net_attack_point, BOUNCE_RADIUS)
			_warning2.show_circle(bounce_point(), PUMPKIN_RADIUS)
		State.STRAW_OUT:
			_warning.show_circle(net_attack_point, STRAW_RADIUS)
		State.WHIRL_TELEGRAPH:
			_warning.show_circle(net_attack_point, WHIRL_RADIUS)
		_:
			_warning.hide_warning()


## Cliente: anda conforme a velocidade replicada.
func _animate_remote(_delta: float, _speed: float) -> void:
	pass


# ---------------------------------------------------------------------------
# Animação e modelo
# ---------------------------------------------------------------------------

func _animate(delta: float) -> void:
	if _body_root == null:
		return
	match state as State:
		State.WALK:
			# Saltita como se estivesse preso ao pau
			_body_root.position.y = absf(sin(_anim_time * 5.0)) * 0.12
			_body_root.rotation.z = sin(_anim_time * 5.0) * 0.08
			_scythe.rotation.y = lerpf(_scythe.rotation.y, 0.0, clampf(6.0 * delta, 0.0, 1.0))
		State.SWEEP_TELEGRAPH:
			_scythe.rotation.y = lerpf(_scythe.rotation.y, 1.2, clampf(6.0 * delta, 0.0, 1.0))
		State.SWEEP:
			_body_root.rotation.y += delta * 22.0
		State.WHIRL_TELEGRAPH:
			_body_root.rotation.y += delta * 8.0 * clampf(_state_time / sweep_telegraph, 0.0, 1.0)
			_body_root.rotation.z = sin(_anim_time * 30.0) * 0.06
		State.WHIRL:
			# Braços abertos a girar como um pião, inclinado para a frente
			_body_root.rotation.y += delta * 18.0
			_body_root.rotation.z = sin(_anim_time * 6.0) * 0.15
			_body_root.position.y = absf(sin(_anim_time * 10.0)) * 0.15
		State.STRAW_IN:
			# Remonta: cresce do chão com um esticão
			var k: float = clampf(_state_time / 0.35, 0.0, 1.0)
			_body_root.scale = Vector3(1.0 + (1.0 - k) * 0.4, k * (1.0 + sin(k * PI) * 0.25), 1.0 + (1.0 - k) * 0.4).max(Vector3.ONE * 0.05)
		State.DIZZY:
			_body_root.rotation.y = lerpf(_body_root.rotation.y, 0.0, clampf(3.0 * delta, 0.0, 1.0))
			_body_root.rotation.z = sin(_anim_time * 9.0) * 0.25
		_:
			_body_root.rotation.z = lerpf(_body_root.rotation.z, 0.0, clampf(4.0 * delta, 0.0, 1.0))
	if state != State.STRAW_IN:
		_body_root.scale = Vector3.ONE
	# Abóbora em arco (telegrafado: na mão; THROW: chega ao ponto, salta e rebenta)
	if state == State.THROW_TELEGRAPH or (state == State.THROW and _state_time < 0.1 + THROW_FLIGHT * 0.7):
		var total: float = throw_telegraph * (0.8 if phase == 2 else 1.0)
		var p: Vector3
		if state == State.THROW_TELEGRAPH:
			var t: float = clampf(_state_time / total, 0.0, 1.0)
			p = _throw_from.lerp(net_attack_point, t)
			p.y += sin(t * PI) * 3.0
		elif _state_time < 0.1:
			p = net_attack_point
		else:
			var b: float = clampf((_state_time - 0.1) / (THROW_FLIGHT * 0.7), 0.0, 1.0)
			p = net_attack_point.lerp(bounce_point(), b)
			p.y += sin(b * PI) * 1.6
		_pumpkin.visible = true
		_pumpkin.global_position = p + Vector3.UP * 0.2
		_pumpkin.rotation.x += delta * 8.0
	elif _pumpkin != null:
		_pumpkin.visible = false


func _build_model() -> void:
	var mat: ShaderMaterial = ToonKit.vertex_material(true, true)
	mat.set_shader_parameter(&"chip_amount", 0.25)
	mat.set_shader_parameter(&"chip_color", Color(0.5, 0.4, 0.25))
	mat.set_shader_parameter(&"chip_scale", 3.0)
	_register_flash_material(mat)
	_body_root = Node3D.new()
	_body_root.name = "BodyRoot"
	add_child(_body_root)

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 1. Pernas articuladas com calças remendadas, palha a sair e botas de trabalho
	for side: float in [-1.0, 1.0]:
		var hip: Vector3 = Vector3(0.18 * side, 1.02, 0.0)
		var knee: Vector3 = Vector3(0.24 * side, 0.58, 0.04)
		var ankle: Vector3 = Vector3(0.26 * side, 0.24, 0.0)

		# Coxa e canela das calças
		LowPolyMesh.prism(st, hip, knee, 0.15, 0.13, 7, PANTS_OLIVE)
		LowPolyMesh.prism(st, knee, ankle, 0.13, 0.12, 7, PANTS_OLIVE)

		# Remendos nas calças com costuras
		var patch_col: Color = PATCH_ORANGE if side > 0.0 else PATCH_GREEN
		LowPolyMesh.box(st, knee + Vector3(0.0, 0.0, -0.12), Vector3(0.15, 0.18, 0.03), Basis.IDENTITY, patch_col)

		# Tufo de palha seca a rebentar do fundo das pernas
		for k: int in 4:
			var s_ang: float = TAU * float(k) / 4.0
			var s_p0: Vector3 = ankle + Vector3(cos(s_ang) * 0.08, 0.04, sin(s_ang) * 0.08)
			var s_p1: Vector3 = s_p0 + Vector3(cos(s_ang) * 0.10, -0.12, sin(s_ang) * 0.10)
			LowPolyMesh.prism(st, s_p0, s_p1, 0.025, 0.0, 4, STRAW)

		# Botas de cabedal pesadas com atacadores
		var boot_pos: Vector3 = ankle + Vector3(0.0, -0.12, -0.06)
		LowPolyMesh.box(st, boot_pos, Vector3(0.17, 0.16, 0.30), Basis.IDENTITY, BOOTS)
		LowPolyMesh.box(st, boot_pos - Vector3(0.0, 0.07, 0.0), Vector3(0.19, 0.04, 0.32), Basis.IDENTITY, WOOD_DARK)
		# Atacadores
		LowPolyMesh.box(st, boot_pos + Vector3(0.0, 0.04, -0.08), Vector3(0.12, 0.04, 0.08), Basis(Vector3.RIGHT, 0.3), ROPE)

	# 2. Tronco: casaco de flanela, cinto de corda com nó e gola de palha
	# Pélvis e cintura
	LowPolyMesh.prism(st, Vector3(0.0, 0.95, 0.0), Vector3(0.0, 1.25, 0.0), 0.35, 0.33, 8, COAT_BROWN)
	# Cinto de corda com nó
	LowPolyMesh.prism(st, Vector3(0.0, 1.22, 0.0), Vector3(0.0, 1.28, 0.0), 0.36, 0.36, 8, ROPE)
	LowPolyMesh.prism(st, Vector3(0.06, 1.25, -0.34), Vector3(0.08, 0.96, -0.36), 0.035, 0.02, 4, ROPE)

	# Palha a sair da bainha da cintura
	for k: int in 6:
		var w_ang: float = TAU * float(k) / 6.0
		var w_p0: Vector3 = Vector3(cos(w_ang) * 0.32, 1.20, sin(w_ang) * 0.32)
		var w_p1: Vector3 = w_p0 + Vector3(cos(w_ang) * 0.14, -0.16, sin(w_ang) * 0.14)
		LowPolyMesh.prism(st, w_p0, w_p1, 0.035, 0.0, 4, STRAW)

	# Tronco superior e peito com padrão de flanela
	LowPolyMesh.prism(st, Vector3(0.0, 1.25, 0.0), Vector3(0.0, 1.82, -0.04), 0.33, 0.38, 8, COAT_BROWN)
	LowPolyMesh.box(st, Vector3(-0.12, 1.48, -0.34), Vector3(0.16, 0.16, 0.03), Basis.IDENTITY, PATCH_ORANGE)
	LowPolyMesh.box(st, Vector3(0.14, 1.58, -0.34), Vector3(0.14, 0.14, 0.03), Basis.IDENTITY, COAT_PLAID)

	# Manto / gola de serapilheira com nó sobre os ombros
	LowPolyMesh.prism(st, Vector3(0.0, 1.68, -0.04), Vector3(0.0, 1.84, -0.04), 0.44, 0.32, 8, SACK)
	LowPolyMesh.prism(st, Vector3(0.0, 1.76, -0.34), Vector3(0.0, 1.60, -0.36), 0.05, 0.025, 4, ROPE)

	# Coroa de palha pontiaguda espetada ao redor do pescoço
	for k: int in 8:
		var c_ang: float = TAU * float(k) / 8.0
		var cp0: Vector3 = Vector3(cos(c_ang) * 0.36, 1.74, sin(c_ang) * 0.36 - 0.04)
		var cp1: Vector3 = cp0 + Vector3(cos(c_ang) * 0.22, 0.08, sin(c_ang) * 0.22)
		LowPolyMesh.prism(st, cp0, cp1, 0.045, 0.0, 4, STRAW)

	# 3. Braço esquerdo segurando a lanterna (como em espantalho.jpg)
	var l_shoulder: Vector3 = Vector3(-0.38, 1.72, -0.02)
	var l_elbow: Vector3 = Vector3(-0.64, 1.44, -0.06)
	var l_wrist: Vector3 = Vector3(-0.72, 1.15, -0.12)
	LowPolyMesh.prism(st, l_shoulder, l_elbow, 0.13, 0.11, 6, COAT_BROWN)
	LowPolyMesh.prism(st, l_elbow, l_wrist, 0.11, 0.12, 6, COAT_BROWN)
	LowPolyMesh.box(st, l_elbow + Vector3(0.0, 0.0, -0.11), Vector3(0.12, 0.14, 0.03), Basis.IDENTITY, PATCH_ORANGE)

	# Palha a rebentar do punho esquerdo
	for k: int in 5:
		var p_ang: float = TAU * float(k) / 5.0
		var cuff_p0: Vector3 = l_wrist + Vector3(cos(p_ang) * 0.10, 0.0, sin(p_ang) * 0.10)
		var cuff_p1: Vector3 = cuff_p0 + Vector3(cos(p_ang) * 0.15, -0.12, sin(p_ang) * 0.15)
		LowPolyMesh.prism(st, cuff_p0, cuff_p1, 0.03, 0.0, 4, STRAW)

	# Mão de serapilheira segurando a pega da lanterna
	var l_hand: Vector3 = l_wrist + Vector3(0.0, -0.08, 0.0)
	LowPolyMesh.prism(st, l_wrist, l_hand, 0.10, 0.08, 5, SACK)

	# Lanterna de querosene rústica pendurada
	var lan_top: Vector3 = l_hand + Vector3(0.0, -0.12, 0.0)
	# Alça de arame
	LowPolyMesh.prism(st, l_hand, lan_top, 0.015, 0.015, 4, LANTERN_RUST)
	# Tampa da lanterna
	LowPolyMesh.prism(st, lan_top, lan_top - Vector3(0.0, 0.07, 0.0), 0.10, 0.12, 7, LANTERN_RUST)
	# Vidro bojudo com chama brilhante
	var lan_mid: Vector3 = lan_top - Vector3(0.0, 0.18, 0.0)
	LowPolyMesh.prism(st, lan_top - Vector3(0.0, 0.07, 0.0), lan_mid - Vector3(0.0, 0.08, 0.0), 0.11, 0.10, 7, LANTERN_GLASS)
	LowPolyMesh.prism(st, lan_mid + Vector3(0.0, 0.04, 0.0), lan_mid - Vector3(0.0, 0.04, 0.0), 0.06, 0.01, 5, GLOW)
	# Depósito inferior da lanterna
	var lan_bot: Vector3 = lan_mid - Vector3(0.0, 0.15, 0.0)
	LowPolyMesh.prism(st, lan_mid - Vector3(0.0, 0.08, 0.0), lan_bot, 0.12, 0.13, 7, LANTERN_RUST)

	# 4. Braço direito que empunha a foice
	var r_shoulder: Vector3 = Vector3(0.38, 1.72, -0.02)
	var r_elbow: Vector3 = Vector3(0.62, 1.45, -0.12)
	var r_hand: Vector3 = Vector3(0.78, 1.28, -0.24)
	LowPolyMesh.prism(st, r_shoulder, r_elbow, 0.13, 0.11, 6, COAT_BROWN)
	LowPolyMesh.prism(st, r_elbow, r_hand, 0.11, 0.12, 6, COAT_BROWN)

	# Palha a rebentar do punho direito
	for k: int in 5:
		var p_ang: float = TAU * float(k) / 5.0
		var cuff_p0: Vector3 = r_hand + Vector3(cos(p_ang) * 0.10, 0.0, sin(p_ang) * 0.10)
		var cuff_p1: Vector3 = cuff_p0 + Vector3(cos(p_ang) * 0.15, -0.12, sin(p_ang) * 0.15)
		LowPolyMesh.prism(st, cuff_p0, cuff_p1, 0.03, 0.0, 4, STRAW)
	LowPolyMesh.prism(st, r_hand, r_hand + Vector3(0.04, 0.0, -0.06), 0.09, 0.07, 5, SACK)

	# 5. Dois corvos negros empoleirados nos ombros
	for side: float in [-1.0, 1.0]:
		var crow_base: Vector3 = Vector3(0.44 * side, 1.84, 0.02)
		# Corpo do corvo
		LowPolyMesh.prism(st, crow_base + Vector3(0.0, 0.0, 0.06), crow_base + Vector3(0.0, 0.08, -0.08), 0.07, 0.06, 6, CROW_BLACK)
		# Cabeça
		var cr_head: Vector3 = crow_base + Vector3(0.0, 0.12, -0.12)
		LowPolyMesh.prism(st, crow_base + Vector3(0.0, 0.08, -0.08), cr_head, 0.045, 0.035, 5, CROW_BLACK)
		# Bico
		LowPolyMesh.prism(st, cr_head, cr_head + Vector3(0.0, -0.01, -0.07), 0.018, 0.002, 4, CROW_BEAK)
		# Olho amarelo do corvo
		LowPolyMesh.box(st, cr_head + Vector3(0.035 * side, 0.01, -0.02), Vector3(0.015, 0.015, 0.01), Basis.IDENTITY, GLOW)

	# 6. Cabeça redonda de abóbora/serapilheira com olhos de botão brilhantes, boca recortada e chapéu de bruxo
	var head: Vector3 = Vector3(0.0, 2.12, -0.05)
	# Manto bulboso da cabeça (abóbora facetada)
	for k: int in 8:
		var ang: float = TAU * float(k) / 8.0
		LowPolyMesh.prism(st, head + Vector3(cos(ang) * 0.12, -0.22, sin(ang) * 0.12),
			head + Vector3(cos(ang) * 0.12, 0.20, sin(ang) * 0.12), 0.22, 0.19, 6, PUMPKIN if k % 2 == 0 else PUMPKIN_DARK)

	# Olhos de botão brilhantes recortados com costura em cruz
	var glow: Color = Color(GLOW.r, GLOW.g, GLOW.b, 0.0)
	var glow_eye: Color = Color(GLOW_EYE.r, GLOW_EYE.g, GLOW_EYE.b, 0.0)
	for side: float in [-1.0, 1.0]:
		var eye_p: Vector3 = head + Vector3(0.12 * side, 0.08, -0.31)
		# Aro externo do botão
		LowPolyMesh.prism(st, eye_p, eye_p - Vector3(0.0, 0.0, 0.02), 0.075, 0.070, 8, PUMPKIN_DARK)
		# Disco do botão brilhante
		LowPolyMesh.prism(st, eye_p - Vector3(0.0, 0.0, 0.01), eye_p - Vector3(0.0, 0.0, 0.03), 0.065, 0.065, 8, glow_eye)
		# Furo central com costura em cruz
		LowPolyMesh.box(st, eye_p - Vector3(0.0, 0.0, 0.032), Vector3(0.035, 0.008, 0.005), Basis.IDENTITY, MOUTH_DARK)
		LowPolyMesh.box(st, eye_p - Vector3(0.0, 0.0, 0.032), Vector3(0.008, 0.035, 0.005), Basis.IDENTITY, MOUTH_DARK)

	# Boca recortada recortada a brilhar (sorriso malévolo e recortado)
	LowPolyMesh.box(st, head + Vector3(0.0, -0.08, -0.32), Vector3(0.26, 0.07, 0.03), Basis.IDENTITY, glow)
	for ti: int in 4:
		var tooth_x: float = (float(ti) - 1.5) * 0.06
		LowPolyMesh.prism(st, head + Vector3(tooth_x, -0.05, -0.33), head + Vector3(tooth_x, -0.11, -0.33), 0.025, 0.0, 3, MOUTH_DARK)

	# Chapéu de bruxo/fazendeiro pontiagudo e amarrotado
	# Aba larga do chapéu
	LowPolyMesh.prism(st, head + Vector3(0.0, 0.18, 0.0), head + Vector3(0.0, 0.23, 0.0), 0.54, 0.48, 9, HAT)
	# Fita do chapéu
	LowPolyMesh.prism(st, head + Vector3(0.0, 0.23, 0.0), head + Vector3(0.0, 0.27, 0.0), 0.26, 0.24, 8, HAT_BAND)
	# Copa pontiaguda do chapéu com curvatura para trás
	LowPolyMesh.prism(st, head + Vector3(0.0, 0.27, 0.0), head + Vector3(0.02, 0.52, 0.04), 0.24, 0.14, 7, HAT)
	LowPolyMesh.prism(st, head + Vector3(0.02, 0.52, 0.04), head + Vector3(0.06, 0.72, 0.12), 0.14, 0.02, 5, HAT)

	_body_root.add_child(_commit(st, "Body", mat))

	# 7. Foice curva imponente com lâmina oxidada e serrada (no nó _scythe para rotação do golpe)
	_scythe = Node3D.new()
	_scythe.name = "Scythe"
	_scythe.position = r_hand
	var sst: SurfaceTool = SurfaceTool.new()
	sst.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Cabo de madeira torto com pegas
	var pole_bot: Vector3 = Vector3(0.0, -1.25, 0.10)
	var pole_grip: Vector3 = Vector3(0.0, 0.0, 0.0)
	var pole_top: Vector3 = Vector3(0.05, 1.15, -0.15)
	LowPolyMesh.prism(sst, pole_bot, pole_grip, 0.042, 0.038, 5, WOOD)
	LowPolyMesh.prism(sst, pole_grip, pole_top, 0.038, 0.035, 5, WOOD)
	# Pega transversal de madeira onde a mão segura
	LowPolyMesh.prism(sst, Vector3(-0.08, -0.15, 0.0), Vector3(0.08, -0.15, 0.0), 0.025, 0.025, 4, WOOD_DARK)
	# Braçadeira de ferro no topo do cabo
	LowPolyMesh.prism(sst, pole_top - Vector3(0.0, 0.08, 0.0), pole_top, 0.052, 0.052, 6, SCYTHE_IRON)

	# Lâmina colossal curva e enferrujada com dentes/falhas
	var blade_base: Vector3 = pole_top
	var blade_elbow: Vector3 = blade_base + Vector3(0.0, 0.16, -0.42)
	var blade_mid: Vector3 = blade_base + Vector3(0.0, -0.12, -0.88)
	var blade_tip: Vector3 = blade_base + Vector3(0.0, -0.58, -1.18)

	# Segmentos contínuos da lâmina curva
	LowPolyMesh.prism(sst, blade_base, blade_elbow, 0.12, 0.10, 4, SCYTHE_RUST)
	LowPolyMesh.prism(sst, blade_elbow, blade_mid, 0.10, 0.08, 4, SCYTHE_RUST)
	LowPolyMesh.prism(sst, blade_mid, blade_tip, 0.08, 0.045, 4, SCYTHE_RUST)
	# Ponta afiada da foice
	LowPolyMesh.prism(sst, blade_tip, blade_tip + Vector3(0.0, -0.22, -0.08), 0.045, 0.005, 3, SCYTHE_IRON)
	# Gume cortante de ferro ao longo da curvatura interna
	LowPolyMesh.prism(sst, blade_elbow - Vector3(0.0, 0.06, 0.0), blade_mid - Vector3(0.0, 0.04, 0.0), 0.03, 0.015, 3, SCYTHE_IRON)

	_scythe.add_child(_commit(sst, "Mesh", mat))
	_body_root.add_child(_scythe)

	# Luz da cara
	var light_head: OmniLight3D = OmniLight3D.new()
	light_head.light_color = GLOW
	light_head.light_energy = 2.5
	light_head.omni_range = 5.0
	light_head.position = head + Vector3(0.0, 0.0, -0.5)
	_body_root.add_child(light_head)

	# Luz da lanterna
	var light_lan: OmniLight3D = OmniLight3D.new()
	light_lan.light_color = GLOW
	light_lan.light_energy = 2.0
	light_lan.omni_range = 4.0
	light_lan.position = lan_mid
	_body_root.add_child(light_lan)

	# Abóbora atirada (top_level: voa pelo mundo)
	var pst: SurfaceTool = SurfaceTool.new()
	pst.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k: int in 6:
		var ang: float = TAU * float(k) / 6.0
		LowPolyMesh.prism(pst, Vector3(cos(ang) * 0.1, -0.18, sin(ang) * 0.1), Vector3(cos(ang) * 0.1, 0.16, sin(ang) * 0.1), 0.16, 0.13, 6,
			PUMPKIN if k % 2 == 0 else PUMPKIN_DARK)
	_pumpkin = _commit(pst, "Pumpkin", mat)
	_pumpkin.top_level = true
	_pumpkin.visible = false
	add_child(_pumpkin)

	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(1.2, 2.6, 1.0)
	shape.shape = box
	shape.position = Vector3(0.0, 1.3, 0.0)
	add_child(shape)


func _commit(st: SurfaceTool, part_name: String, mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = part_name
	mi.mesh = ToonKit.commit(st)
	mi.material_override = mat
	return mi

