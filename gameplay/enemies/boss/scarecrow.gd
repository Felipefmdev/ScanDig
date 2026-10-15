class_name Scarecrow
extends EnemyBase

## Espantalho Desperto (#41): chefe escondido do Campo. Acorda à noite na lavoura quando os 8
## menires acendem pela ordem do sol (BossTrigger com night). Anda devagar para o jogador mais
## próximo e alterna dois ataques telegrafados:
##   - VARRIDELA da foice: círculo vermelho à volta dele (SWEEP_RADIUS); depois fica TONTO
##     DIZZY_TIME s (dano a dobrar);
##   - ABÓBORA: atira-a ao sítio onde o jogador está (círculo + arco visível), rebenta em
##     PUMPKIN_RADIUS.
## Chama corvos aos 66 % e 33 %. Ao morrer desfaz-se em palha e larga a Lanterna do Espantalho.
## Coop (#24): IA no host; estado e ponto do ataque (net_attack_point) vão para os clientes.

signal boss_defeated(boss_id: StringName)
signal health_changed(current: float, max_value: float)

enum State { EMERGE, WALK, SWEEP_TELEGRAPH, SWEEP, DIZZY, THROW_TELEGRAPH, THROW, DYING }

const BOSS_ID: StringName = &"scarecrow"
const BOSS_NAME: String = "ESPANTALHO DESPERTO"
const GROUP_BOSSES: StringName = &"bosses"
const TROPHY_ITEM_ID: String = "lanterna_espantalho"
const SWEEP_RADIUS: float = 3.0
const PUMPKIN_RADIUS: float = 2.0
const WEAK_POINT_MULTIPLIER: float = 2.0
const REINFORCE_THRESHOLDS: Array[float] = [0.66, 0.33]
const PHASE_TWO_RATIO: float = 0.5

const SACK: Color = Color(0.72, 0.6, 0.4)
const PATCH_RED: Color = Color(0.7, 0.2, 0.15)
const PATCH_BLUE: Color = Color(0.25, 0.35, 0.55)
const STRAW: Color = Color(0.93, 0.8, 0.35)
const PUMPKIN: Color = Color(0.95, 0.5, 0.1)
const PUMPKIN_DARK: Color = Color(0.75, 0.35, 0.06)
const STEM: Color = Color(0.35, 0.45, 0.15)
const HAT: Color = Color(0.38, 0.28, 0.18)
const WOOD: Color = Color(0.45, 0.3, 0.17)
const BLADE: Color = Color(0.6, 0.62, 0.66)
const GLOW: Color = Color(1.0, 0.75, 0.2)

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
			if _state_time >= throw_telegraph * (0.8 if phase == 2 else 1.0):
				_enter_state(State.THROW)
		State.THROW:
			if not _hit_done and _state_time >= 0.1:
				_hit_done = true
				_damage_circle(net_attack_point, PUMPKIN_RADIUS, pumpkin_damage)
				spawn_particles(net_attack_point + Vector3.UP * 0.2, PUMPKIN, 20, 3.5)
			if _state_time >= 0.4:
				_cooldown = attack_cooldown * 0.6
				_enter_state(State.WALK)


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
		if dist <= SWEEP_RADIUS * 0.85:
			_enter_state(State.SWEEP_TELEGRAPH)
			return
		if dist >= throw_distance:
			# Os pés do jogador (um raio ao chão bateria no próprio jogador, que está na camada 1).
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
		State.THROW_TELEGRAPH:
			_throw_from = global_position + Vector3.UP * 2.0
			_warning.show_circle(net_attack_point, PUMPKIN_RADIUS)
		State.SWEEP, State.THROW, State.DIZZY:
			_warning.hide_warning()


func _damage_circle(center: Vector3, radius: float, damage: float) -> void:
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
	_refresh_remote_visuals()


func _refresh_remote_visuals() -> void:
	match state:
		State.SWEEP_TELEGRAPH:
			_warning.show_circle(net_attack_point, SWEEP_RADIUS)
		State.THROW_TELEGRAPH:
			_warning.show_circle(net_attack_point, PUMPKIN_RADIUS)
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
		State.DIZZY:
			_body_root.rotation.y = lerpf(_body_root.rotation.y, 0.0, clampf(3.0 * delta, 0.0, 1.0))
			_body_root.rotation.z = sin(_anim_time * 9.0) * 0.25
		_:
			_body_root.rotation.z = lerpf(_body_root.rotation.z, 0.0, clampf(4.0 * delta, 0.0, 1.0))
	# Abóbora em arco (telegrafado: na mão; THROW: chega ao ponto)
	if state == State.THROW_TELEGRAPH or state == State.THROW:
		var total: float = throw_telegraph * (0.8 if phase == 2 else 1.0)
		var t: float = clampf(_state_time / total, 0.0, 1.0) if state == State.THROW_TELEGRAPH else 1.0
		var p: Vector3 = _throw_from.lerp(net_attack_point, t)
		p.y += sin(t * PI) * 3.0
		_pumpkin.visible = true
		_pumpkin.global_position = p
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
	# Pau e pernas de calças com remendos
	LowPolyMesh.prism(st, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0), 0.07, 0.07, 6, WOOD)
	for side: float in [-1.0, 1.0]:
		LowPolyMesh.prism(st, Vector3(0.14 * side, 0.15, 0.0), Vector3(0.12 * side, 0.95, 0.0), 0.12, 0.13, 7, PATCH_BLUE)
		LowPolyMesh.prism(st, Vector3(0.14 * side, 0.15, 0.0), Vector3(0.18 * side, 0.0, -0.05), 0.08, 0.0, 5, STRAW)
	# Tronco (saco) com remendo vermelho e cinto de corda
	LowPolyMesh.prism(st, Vector3(0.0, 0.9, 0.0), Vector3(0.0, 1.75, 0.0), 0.36, 0.3, 8, SACK)
	LowPolyMesh.box(st, Vector3(0.12, 1.35, -0.3), Vector3(0.18, 0.18, 0.04), Basis(Vector3.FORWARD, 0.2), PATCH_RED)
	LowPolyMesh.prism(st, Vector3(0.0, 1.0, 0.0), Vector3(0.0, 1.06, 0.0), 0.38, 0.38, 8, STRAW)
	# Braços abertos (pau em cruz) com palha nas mangas
	LowPolyMesh.prism(st, Vector3(-0.95, 1.55, 0.0), Vector3(0.95, 1.55, 0.0), 0.05, 0.05, 5, WOOD)
	for side: float in [-1.0, 1.0]:
		LowPolyMesh.prism(st, Vector3(0.25 * side, 1.55, 0.0), Vector3(0.75 * side, 1.55, 0.0), 0.12, 0.1, 6, SACK)
		for k: int in 3:
			var off: Vector3 = Vector3(0.0, (float(k) - 1.0) * 0.06, (float(k) - 1.0) * 0.06)
			LowPolyMesh.prism(st, Vector3(0.75 * side, 1.55, 0.0) + off, Vector3(0.98 * side, 1.5 - 0.05 * k, 0.0) + off * 2.0, 0.04, 0.0, 4, STRAW)
	# Cabeça de abóbora com cara recortada a brilhar (sem desgaste)
	var head: Vector3 = Vector3(0.0, 2.05, 0.0)
	for k: int in 6:
		var ang: float = TAU * float(k) / 6.0
		LowPolyMesh.prism(st, head + Vector3(cos(ang) * 0.12, -0.24, sin(ang) * 0.12),
			head + Vector3(cos(ang) * 0.12, 0.2, sin(ang) * 0.12), 0.2, 0.17, 6, PUMPKIN if k % 2 == 0 else PUMPKIN_DARK)
	LowPolyMesh.prism(st, head + Vector3(0.0, 0.18, 0.0), head + Vector3(0.03, 0.34, 0.0), 0.04, 0.03, 5, STEM)
	var glow: Color = Color(GLOW.r, GLOW.g, GLOW.b, 0.0)
	for side: float in [-1.0, 1.0]:
		LowPolyMesh.prism(st, head + Vector3(0.11 * side, 0.06, -0.3), head + Vector3(0.11 * side, 0.14, -0.31), 0.06, 0.0, 3, glow)
	LowPolyMesh.box(st, head + Vector3(0.0, -0.1, -0.31), Vector3(0.24, 0.06, 0.03), Basis.IDENTITY, glow)
	# Chapéu de palha velho
	LowPolyMesh.prism(st, head + Vector3(0.0, 0.2, 0.0), head + Vector3(0.0, 0.24, 0.0), 0.5, 0.46, 9, HAT)
	LowPolyMesh.prism(st, head + Vector3(0.0, 0.24, 0.0), head + Vector3(0.0, 0.48, 0.0), 0.24, 0.14, 7, HAT)
	_body_root.add_child(_commit(st, "Body", mat))
	# Foice (nó para rodar na varridela)
	_scythe = Node3D.new()
	_scythe.name = "Scythe"
	_scythe.position = Vector3(0.9, 1.55, 0.0)
	var sst: SurfaceTool = SurfaceTool.new()
	sst.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyMesh.prism(sst, Vector3(0.0, -1.0, 0.0), Vector3(0.0, 0.7, 0.0), 0.035, 0.03, 5, WOOD)
	LowPolyMesh.box(sst, Vector3(0.0, 0.7, -0.45), Vector3(0.05, 0.1, 0.9), Basis(Vector3.RIGHT, 0.25), BLADE)
	LowPolyMesh.prism(sst, Vector3(0.0, 0.62, -0.9), Vector3(0.0, 0.45, -1.15), 0.05, 0.0, 4, BLADE)
	_scythe.add_child(_commit(sst, "Mesh", mat))
	_body_root.add_child(_scythe)
	# Luz da cara (a noite é escura)
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = GLOW
	light.light_energy = 2.5
	light.omni_range = 5.0
	light.position = head + Vector3(0.0, 0.0, -0.5)
	_body_root.add_child(light)
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
	box.size = Vector3(1.0, 2.4, 0.9)
	shape.shape = box
	shape.position = Vector3(0.0, 1.2, 0.0)
	add_child(shape)


func _commit(st: SurfaceTool, part_name: String, mat: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = part_name
	mi.mesh = ToonKit.commit(st)
	mi.material_override = mat
	return mi
