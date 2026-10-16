class_name CrowKing
extends EnemyBase

## Corvo-Rei (#41): chefe adicional da missão da Dona Lurdes, sobre a lavoura do Campo.
## Voa em círculos alto à volta do sítio onde nasceu (só o estilingue lhe chega), escolhe o
## jogador mais próximo, paira por cima dele com um círculo vermelho no chão e mergulha
## (DIVE_RADIUS). Depois do mergulho fica no chão GROUNDED_TIME s, atordoado: é aí que a pá
## lhe chega e o dano conta a dobrar. Chama corvos aos 66 % e 33 %; na fase 2 (vida < 50 %)
## circula menos tempo. Ao morrer cai e larga a Pena do Corvo-Rei.
## Caos (#57), em roda depois de cada volta: MERGULHO EM PARAFUSO (o de cima, a rodar e a
## atirar o jogador), ROUBO (rasante numa faixa marcada; tira a ferramenta da mão de quem
## apanhar, Player.apply_disarm, e foge baixinho com ela: acertar-lhe devolve-a) e TORNADO DE
## PENAS (círculo; puxa jogadores e itens do chão para o centro e depois fica exausto no chão).
## Coop (#24): IA no host; ponto do mergulho (net_attack_point) e estado vão para os clientes.

signal boss_defeated(boss_id: StringName)
signal health_changed(current: float, max_value: float)

enum State { ARRIVE, CIRCLE, TELEGRAPH, DIVE, GROUNDED, TAKEOFF, DYING, STEAL_TELEGRAPH, STEAL, CARRY, TORNADO_TELEGRAPH, TORNADO }

const BOSS_ID: StringName = &"crow_king"
const BOSS_NAME: String = "CORVO-REI"
const GROUP_BOSSES: StringName = &"bosses"
const TROPHY_ITEM_ID: String = "pena_corvo_rei"
const DIVE_RADIUS: float = 2.2
const WEAK_POINT_MULTIPLIER: float = 2.0
const REINFORCE_THRESHOLDS: Array[float] = [0.66, 0.33]
const PHASE_TWO_RATIO: float = 0.5
const MODEL_SCALE: float = 3.2
## #57: roubo, tornado e ordem dos ataques.
const STEAL_LENGTH: float = 18.0
const STEAL_SPEED: float = 15.0
const STEAL_RADIUS: float = 1.4
const STEAL_HEIGHT: float = 1.3
const DISARM_SECONDS: float = 5.0
const CARRY_TIME: float = 4.5
const TORNADO_RADIUS: float = 5.0
const TORNADO_TIME: float = 3.5
const TORNADO_PULL_INTERVAL: float = 0.35
const ATTACK_CYCLE: Array[int] = [State.TELEGRAPH, State.STEAL_TELEGRAPH, State.TELEGRAPH, State.TORNADO_TELEGRAPH]
## Modelos das ferramentas que o corvo leva no bico (as mesmas do chão).
const TOOL_WORLD_SCENES: Dictionary = {
	&"forcado": "res://gameplay/weapons/pitchfork/pitchfork_world.tscn",
	&"estilingue": "res://gameplay/weapons/slingshot/slingshot_world.tscn",
	&"arpao_corda": "res://gameplay/weapons/harpoon/harpoon_world.tscn",
	&"repelente": "res://gameplay/weapons/repellent/repellent_world.tscn",
	&"kit_medico": "res://gameplay/weapons/medkit/medkit_world.tscn",
	&"pulso_magnetico": "res://gameplay/weapons/magnetic_pulse/magnetic_pulse_world.tscn",
}
const FEATHER_GOLD: Color = Color(0.86, 0.62, 0.22)

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
var net_attack_dir: Vector3 = Vector3.FORWARD
## Replicada: ferramenta que leva no bico (&"" = nenhuma; &"?" = pá/sem modelo).
var net_stolen_tool: StringName = &"":
	set(value):
		net_stolen_tool = value
		_refresh_stolen_model()

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
var _cycle_index: int = 0
var _steal_from: Vector3 = Vector3.ZERO
var _victim: Node3D = null
var _pull_timer: float = 0.0
var _tornado_fx: CPUParticles3D = null
var _stolen_model: Node3D = null
var _screw: float = 0.0


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
	_add_synced_property(".:net_attack_dir")
	_add_synced_property(".:net_stolen_tool")


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
				_start_attack()
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
		State.STEAL_TELEGRAPH:
			_fly_to(_steal_from, fly_speed * 2.0, delta)
			_warning.pulse(delta)
			if _state_time >= telegraph_time * (0.8 if phase == 2 else 1.0):
				_enter_state(State.STEAL)
		State.STEAL:
			_process_steal(delta)
		State.CARRY:
			_process_carry(delta)
		State.TORNADO_TELEGRAPH:
			_fly_to(net_attack_point + Vector3.UP * 3.0, fly_speed * 1.4, delta)
			_warning.pulse(delta)
			if _state_time >= telegraph_time * (0.8 if phase == 2 else 1.0):
				_enter_state(State.TORNADO)
		State.TORNADO:
			_process_tornado(delta)


func _process(delta: float) -> void:
	_animate(delta)
	if state == State.DYING and _dead:
		_state_time += delta
		_process_dying(delta)
	elif not has_simulation_authority():
		_hud.set_health(health)
		_state_time += delta
		if _warning.visible:
			_warning.pulse(delta)


func _enter_state(s: State) -> void:
	state = s
	_state_time = 0.0
	if _tornado_fx != null:
		_tornado_fx.emitting = s == State.TORNADO
	match s:
		State.TELEGRAPH:
			_warning.show_circle(net_attack_point, DIVE_RADIUS)
		State.DIVE:
			_hit_done = false
			_warning.hide_warning()
		State.CIRCLE, State.TAKEOFF, State.GROUNDED, State.CARRY:
			_warning.hide_warning()
		State.STEAL_TELEGRAPH:
			_warning.show_line(_ground_at(_steal_from), net_attack_dir, STEAL_LENGTH, STEAL_RADIUS * 2.0)
		State.STEAL:
			_hit_done = false
			_warning.hide_warning()
			SFX.play_at(SFX.SEAGULL_DIVE, global_position, 4.0)
		State.TORNADO_TELEGRAPH:
			_warning.show_circle(net_attack_point, TORNADO_RADIUS)
		State.TORNADO:
			_warning.hide_warning()
			_pull_timer = 0.0
			_place_tornado()


func _orbit_point() -> Vector3:
	return _home + Vector3(cos(_orbit) * circle_radius, circle_height, sin(_orbit) * circle_radius)


## Próximo ataque da roda (#57); público para os testes.
func next_attack() -> State:
	var s: State = ATTACK_CYCLE[_cycle_index % ATTACK_CYCLE.size()] as State
	_cycle_index += 1
	return s


func _start_attack() -> void:
	var target: Node3D = _update_target(0.0)
	if target == null or target.global_position.distance_to(_home) > attack_range:
		_state_time = 0.0
		return
	var kind: State = next_attack()
	match kind:
		State.STEAL_TELEGRAPH:
			var to: Vector3 = target.global_position - _home
			to.y = 0.0
			var dir: Vector3 = to.normalized() if to.length_squared() > 0.01 else Vector3.FORWARD
			net_attack_dir = dir
			_steal_from = target.global_position - dir * STEAL_LENGTH * 0.5
			_steal_from.y = _ground_at(_steal_from).y + STEAL_HEIGHT
			net_attack_point = _steal_from
			SFX.play_at(SFX.SEAGULL_DIVE, global_position, 2.0)
			_enter_state(State.STEAL_TELEGRAPH)
			return
		State.TORNADO_TELEGRAPH:
			net_attack_point = target.global_position
			_enter_state(State.TORNADO_TELEGRAPH)
			return
	_start_dive(target)


func _start_dive(target: Node3D) -> void:
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
			# Parafuso (#57): atira em espiral para o lado.
			var out: Vector3 = d.normalized() if d.length_squared() > 0.01 else Vector3.FORWARD
			_knockback(pl, (out + out.cross(Vector3.UP)) * 8.0 + Vector3.UP * 9.0, 0.1)


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


func is_carrying_tool() -> bool:
	return net_stolen_tool != &""


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
	var before: float = health
	super.take_damage(amount, from)
	if not has_simulation_authority():
		return
	# Leva um golpe com a ferramenta no bico: larga-a e o dono recupera-a.
	if health < before and is_carrying_tool():
		_release_tool()
	if _dead:
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
	if is_carrying_tool() and has_simulation_authority():
		_release_tool()
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
	if _tornado_fx != null:
		_tornado_fx.emitting = state == State.TORNADO
	match state:
		State.TELEGRAPH:
			_warning.show_circle(net_attack_point, DIVE_RADIUS)
		State.STEAL_TELEGRAPH:
			_warning.show_line(_ground_at(net_attack_point), net_attack_dir, STEAL_LENGTH, STEAL_RADIUS * 2.0)
		State.TORNADO_TELEGRAPH:
			_warning.show_circle(net_attack_point, TORNADO_RADIUS)
		State.TORNADO:
			_warning.hide_warning()
			_place_tornado()
		_:
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
	var tuck: float = 0.7 if state == State.DIVE or state == State.STEAL else 0.0
	_wing_left.rotation = Vector3(0.0, -tuck, f)
	_wing_right.rotation = Vector3(0.0, tuck, -f)
	# Parafuso no mergulho; no tornado roda sobre si.
	if state == State.DIVE:
		_screw += delta * 22.0
	else:
		_screw = lerp_angle(_screw, 0.0, clampf(delta * 6.0, 0.0, 1.0))
	if state != State.DYING:
		rotation.z = _screw
	if state == State.TORNADO:
		rotation.y += delta * 12.0


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


# ---------------------------------------------------------------------------
# #57: roubo da ferramenta e tornado de penas
# ---------------------------------------------------------------------------

func _ground_at(p: Vector3) -> Vector3:
	return Vector3(p.x, _ground_height(p, _ground_y), p.z)


## Rasante pela faixa: o primeiro jogador apanhado fica sem a ferramenta.
func _process_steal(delta: float) -> void:
	var d: float = minf(_state_time * STEAL_SPEED, STEAL_LENGTH)
	var p: Vector3 = _steal_from + net_attack_dir * d
	global_position = Vector3(p.x, _ground_at(p).y + STEAL_HEIGHT, p.z)
	rotation.y = atan2(-net_attack_dir.x, -net_attack_dir.z)
	if not _hit_done:
		for pl: Node3D in _players_within(global_position, STEAL_RADIUS):
			_hit_done = true
			_victim = pl
			var tool_id: StringName = pl.get(&"held_tool_id") if &"held_tool_id" in pl else &""
			net_stolen_tool = tool_id if tool_id != &"" else &"?"
			_player_effect(pl, &"apply_disarm", [DISARM_SECONDS])
			_knockback(pl, net_attack_dir * 5.0 + Vector3.UP * 4.0, 0.05)
			SFX.play_at(SFX.CRAB_PINCH, global_position, 3.0)
			break
	if d >= STEAL_LENGTH:
		_enter_state(State.CARRY if is_carrying_tool() else State.TAKEOFF)


## Foge baixinho às voltas com a ferramenta (ao alcance da pá dos outros); larga-a no fim.
func _process_carry(delta: float) -> void:
	_orbit += delta * (fly_speed / circle_radius) * 1.3
	var goal: Vector3 = _home + Vector3(cos(_orbit) * circle_radius, 0.0, sin(_orbit) * circle_radius)
	goal.y = _ground_at(goal).y + 2.2 + sin(_state_time * 3.0) * 0.4
	_fly_to(goal, fly_speed, delta)
	if _state_time >= CARRY_TIME:
		_release_tool()
		_enter_state(State.TAKEOFF)


## Larga a ferramenta: o dono recupera-a já (end_disarm) e ela cai a girar (só visual).
func _release_tool() -> void:
	if _victim != null and is_instance_valid(_victim):
		_player_effect(_victim, &"end_disarm")
	_victim = null
	spawn_particles(global_position, BLUE_BLACK, 12, 3.0)
	net_stolen_tool = &""


func _refresh_stolen_model() -> void:
	if _stolen_model != null:
		_stolen_model.queue_free()
		_stolen_model = null
	if net_stolen_tool == &"" or not is_inside_tree():
		return
	var path: String = String(TOOL_WORLD_SCENES.get(net_stolen_tool, ""))
	var holder: Node3D = Node3D.new()
	holder.name = "StolenTool"
	# No bico, pendurada para baixo.
	holder.position = Vector3(0.0, -0.1, -0.5) * MODEL_SCALE * 0.6
	holder.rotation = Vector3(0.0, PI * 0.5, 0.4)
	add_child(holder)
	_stolen_model = holder
	if path != "" and ResourceLoader.exists(path):
		var scene: PackedScene = load(path) as PackedScene
		var inst: Node = scene.instantiate() if scene != null else null
		if inst is Node3D:
			# Só o modelo: sem física nem colisões.
			if inst is RigidBody3D:
				(inst as RigidBody3D).freeze = true
				(inst as RigidBody3D).collision_layer = 0
				(inst as RigidBody3D).collision_mask = 0
			if inst is Area3D:
				(inst as Area3D).monitoring = false
			holder.add_child(inst)
			return
		if inst != null:
			inst.free()
	# Pá (ou sem modelo): cabo e lâmina simples.
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyMesh.prism(st, Vector3(0.0, -0.5, 0.0), Vector3(0.0, 0.5, 0.0), 0.04, 0.04, 6, Color(0.45, 0.3, 0.17))
	LowPolyMesh.box(st, Vector3(0.0, -0.65, 0.0), Vector3(0.26, 0.32, 0.04), Basis.IDENTITY, Color(0.6, 0.62, 0.66))
	holder.add_child(LowPolyMesh.commit(st, "Shovel", LowPolyMesh.make_material()))


## Tornado: de TORNADO_PULL_INTERVAL em TORNADO_PULL_INTERVAL puxa jogadores para o centro (em
## espiral) e arrasta os itens do chão; no fim fica exausto no chão (GROUNDED, dano x2).
func _process_tornado(delta: float) -> void:
	var center: Vector3 = net_attack_point
	_fly_to(center + Vector3.UP * (3.0 + sin(_state_time * 4.0) * 0.4), fly_speed, delta)
	_pull_timer -= delta
	if _pull_timer <= 0.0:
		_pull_timer = TORNADO_PULL_INTERVAL
		for p: Node3D in _players_within(center, TORNADO_RADIUS * 1.3):
			var d: Vector3 = center - p.global_position
			d.y = 0.0
			var inward: Vector3 = d.normalized() if d.length_squared() > 0.04 else Vector3.ZERO
			var swirl: Vector3 = inward.cross(Vector3.UP)
			_knockback(p, inward * 3.5 + swirl * 4.0 + Vector3.UP * 2.5, 0.03)
	_pull_pickups(center, delta)
	if _state_time >= TORNADO_TIME:
		net_attack_point = _ground_at(global_position)
		_dive_from = global_position
		_hit_done = true
		_enter_state(State.GROUNDED)
		global_position = net_attack_point + Vector3.UP * 0.3


## Itens soltos no chão (ItemPickup, física no host) são arrastados para o centro.
func _pull_pickups(center: Vector3, _delta: float) -> void:
	if not is_inside_tree():
		return
	for n: Node in get_tree().get_nodes_in_group(ItemPickup.GROUP):
		var rb: RigidBody3D = n as RigidBody3D
		if rb == null or rb.freeze:
			continue
		var d: Vector3 = center - rb.global_position
		d.y = 0.0
		if d.length() > TORNADO_RADIUS * 1.6 or d.length() < 0.2:
			continue
		rb.apply_central_force(d.normalized() * 6.0 + d.normalized().cross(Vector3.UP) * 6.0 + Vector3.UP * 7.0)


## Coluna de penas (pretas com ponta dourada, como a Pena do Corvo-Rei) a rodar.
func _place_tornado() -> void:
	if _tornado_fx == null:
		_tornado_fx = CPUParticles3D.new()
		_tornado_fx.name = "FeatherTornado"
		_tornado_fx.top_level = true
		_tornado_fx.amount = 90
		_tornado_fx.lifetime = 1.6
		_tornado_fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		_tornado_fx.emission_ring_axis = Vector3.UP
		_tornado_fx.emission_ring_radius = TORNADO_RADIUS * 0.8
		_tornado_fx.emission_ring_inner_radius = 0.6
		_tornado_fx.emission_ring_height = 0.3
		_tornado_fx.direction = Vector3.UP
		_tornado_fx.spread = 10.0
		_tornado_fx.initial_velocity_min = 2.5
		_tornado_fx.initial_velocity_max = 4.5
		_tornado_fx.gravity = Vector3.ZERO
		_tornado_fx.orbit_velocity_min = 0.6
		_tornado_fx.orbit_velocity_max = 0.9
		_tornado_fx.radial_accel_min = -3.0
		_tornado_fx.radial_accel_max = -1.5
		_tornado_fx.angular_velocity_min = -360.0
		_tornado_fx.angular_velocity_max = 360.0
		_tornado_fx.particle_flag_rotate_y = true
		_tornado_fx.scale_amount_min = 0.8
		_tornado_fx.scale_amount_max = 1.5
		_tornado_fx.mesh = _feather_mesh()
		_tornado_fx.emitting = false
		add_child(_tornado_fx)
	_tornado_fx.global_transform = Transform3D(Basis.IDENTITY, _ground_at(net_attack_point))
	_tornado_fx.emitting = state == State.TORNADO


## Pena low-poly da referência (pena_corvo_rei.jpg): lâmina facetada cinza-negra com a ponta
## dourada e haste fina.
func _feather_mesh() -> Mesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyMesh.prism(st, Vector3(0.0, -0.22, 0.0), Vector3(0.0, 0.22, 0.0), 0.012, 0.006, 4, TIP)
	LowPolyMesh.box(st, Vector3(0.0, -0.02, 0.0), Vector3(0.12, 0.3, 0.012), Basis(Vector3.FORWARD, 0.08), BLACK)
	LowPolyMesh.box(st, Vector3(0.015, -0.08, 0.0), Vector3(0.1, 0.12, 0.014), Basis(Vector3.FORWARD, -0.3), BLUE_BLACK)
	LowPolyMesh.box(st, Vector3(0.0, 0.16, 0.0), Vector3(0.1, 0.08, 0.014), Basis(Vector3.FORWARD, 0.12),
		Color(FEATHER_GOLD.r, FEATHER_GOLD.g, FEATHER_GOLD.b, 0.0))
	var mesh: Mesh = ToonKit.commit(st)
	mesh.surface_set_material(0, LowPolyMesh.make_material())
	return mesh
