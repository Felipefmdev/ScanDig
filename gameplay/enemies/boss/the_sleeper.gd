class_name TheSleeper
extends EnemyBase

## O Que Dorme Lá Em Baixo (#44, #57): chefe principal final da Cratera.
## Inspirado fielmente na referência visual o_que_dorme.jpg:
##  - Titã colossal e antigo emergindo das profundezas da cratera com borda rochosa;
##  - Corpo pétreo escuro incrustado de grandes cristais de ametista púrpura brilhantes;
##  - Máscara com múltiplos olhos luminosos roxos, braços colossais com garras de pedra;
##  - 3 Fases caóticas estilo "How to Fish":
##      * FASE 1: Espigões de cristal que emergem do solo telegrafados e esmagamento de garras;
##      * FASE 2: Pulso de inversão de gravidade (GRAVITY_INVERT) que levita os jogadores no ar,
##        seguido de meteoritos rolantes incandescentes;
##      * FASE 3: Chuva de meteoritos caótica e núcleo de ametista exposto brilhante (EXPOSED, dano a 2,5x);
##  - Troféus ao morrer: 'nucleo_adormecido' e 'orbe_vibrante'.

signal boss_defeated(boss_id: StringName)
signal health_changed(current: float, max_value: float)

enum State { EMERGE, IDLE, CRYSTAL_SPIKES_TELE, CRYSTAL_SPIKES, GRAVITY_INVERT_TELE, GRAVITY_INVERT, METEOR_TELE, METEOR_ROLL, EXPOSED, DYING }

const BOSS_ID: StringName = &"the_sleeper"
const BOSS_NAME: String = "O QUE DORME LÁ EMBAIXO"
const GROUP_BOSSES: StringName = &"bosses"
const TROPHY_ITEM_ID: String = "nucleo_adormecido"
const SECONDARY_TROPHY_ID: String = "orbe_vibrante"

const TITAN_STONE: Color = Color("#4a4440")
const TITAN_DARK: Color = Color("#2e2a28")
const AMETHYST_PURPLE: Color = Color("#9a3ae8")
const AMETHYST_GLOW: Color = Color(0.85, 0.45, 1.0)
const EYE_PURPLE: Color = Color(0.92, 0.35, 1.0)
const METEOR_CRUST: Color = Color("#3a3432")

const WEAK_POINT_FACTOR: float = 2.5
const GRAVITY_PULSE_RADIUS: float = 8.5
const SPIKES_RADIUS: float = 4.5
const METEOR_SPEED: float = 10.0

@export var slam_damage: float = 22.0
@export var spikes_damage: float = 18.0
@export var gravity_damage: float = 20.0
@export var meteor_damage: float = 24.0
@export var tele_time: float = 1.1
@export var exposed_time: float = 3.6
@export var emerge_time: float = 2.5

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
var _core_mesh: MeshInstance3D = null
var _meteors: Array[MeshInstance3D] = []
var _meteor_dirs: Array[Vector3] = []
var _mat: ShaderMaterial = null
var _amethyst_mat: ShaderMaterial = null


func _ready() -> void:
	super._ready()
	add_to_group(GROUP_BOSSES)
	max_health = 1600.0
	health = 1600.0
	death_color = AMETHYST_PURPLE
	stun_fx_height = 4.2
	_surface_y = global_position.y
	_build_model()
	_hud = BossHud.create("👁️ " + tr(BOSS_NAME), max_health, Color(0.65, 0.25, 0.95))
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

	_update_meteors(delta)

	var speed_k: float = 0.85 if phase >= 2 else 1.0
	if phase == 3:
		speed_k = 0.7

	match state:
		State.EMERGE:
			var t: float = clampf(_state_time / emerge_time, 0.0, 1.0)
			global_position.y = _surface_y - 4.0 * (1.0 - t)
			if t >= 1.0:
				_hud.visible = true
				_enter_state(State.IDLE)
		State.IDLE:
			_process_idle(delta)
		State.CRYSTAL_SPIKES_TELE:
			_warning.pulse(delta)
			if _state_time >= tele_time * speed_k:
				_enter_state(State.CRYSTAL_SPIKES)
		State.CRYSTAL_SPIKES:
			_process_crystal_spikes(delta)
		State.GRAVITY_INVERT_TELE:
			_warning.pulse(delta)
			if _state_time >= tele_time * speed_k:
				_enter_state(State.GRAVITY_INVERT)
		State.GRAVITY_INVERT:
			_process_gravity_invert(delta)
		State.METEOR_TELE:
			_warning.pulse(delta)
			if _state_time >= tele_time * speed_k:
				_enter_state(State.METEOR_ROLL)
		State.METEOR_ROLL:
			_process_meteor_roll(delta)
		State.EXPOSED:
			_process_exposed(delta)

	_animate(delta)


func _process(delta: float) -> void:
	if not has_simulation_authority() and state != State.DYING:
		_state_time += delta
		_hud.set_health(health)
		if _warning.visible:
			_warning.pulse(delta)
	elif state == State.DYING and _dead:
		# A física fica desligada na morte: o relógio da animação de morte avança aqui
		_state_time += delta
		_process_dying(delta)


func _enter_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	_hit_done = false
	_hit_targets.clear()

	match state:
		State.EMERGE:
			global_position.y = _surface_y - 4.0
		State.IDLE:
			_warning.hide_warning()
		State.CRYSTAL_SPIKES_TELE:
			var target: Node3D = _update_target(0.0)
			net_attack_point = target.global_position if target != null else global_position
			_warning.show_circle(net_attack_point, SPIKES_RADIUS)
			SFX.play_at(SFX.SLINGSHOT_FIRE, global_position, 4.0)
		State.CRYSTAL_SPIKES:
			_warning.hide_warning()
		State.GRAVITY_INVERT_TELE:
			net_attack_point = global_position
			_warning.show_circle(global_position, GRAVITY_PULSE_RADIUS)
			SFX.play_at(SFX.SPRAY, global_position, 6.0)
		State.GRAVITY_INVERT:
			_warning.hide_warning()
		State.METEOR_TELE:
			net_attack_point = global_position
			var target: Node3D = _update_target(0.0)
			if target != null:
				var to: Vector3 = target.global_position - global_position
				to.y = 0.0
				net_attack_dir = to.normalized() if to.length() > 0.1 else -transform.basis.z
			else:
				net_attack_dir = -transform.basis.z
			_warning.show_line(global_position, net_attack_dir, 20.0, 3.2)
		State.METEOR_ROLL:
			_warning.hide_warning()
		State.EXPOSED:
			_warning.hide_warning()
			SFX.play_at(SFX.SHELL_KNOCK, global_position, 7.0)


func _process_idle(_delta: float) -> void:
	# O Que Dorme permanece ancorado no centro da cratera
	if _state_time >= 2.0:
		_attack_cycle += 1
		if phase == 1:
			if _attack_cycle % 2 == 1:
				_enter_state(State.CRYSTAL_SPIKES_TELE)
			else:
				_enter_state(State.METEOR_TELE)
		elif phase == 2:
			match _attack_cycle % 3:
				1:
					_enter_state(State.GRAVITY_INVERT_TELE)
				2:
					_enter_state(State.CRYSTAL_SPIKES_TELE)
				0:
					_enter_state(State.METEOR_TELE)
		else:
			# Fase 3: ciclo com inversão de gravidade e expõe o núcleo!
			match _attack_cycle % 4:
				1:
					_enter_state(State.GRAVITY_INVERT_TELE)
				2:
					_enter_state(State.METEOR_TELE)
				3:
					_enter_state(State.CRYSTAL_SPIKES_TELE)
				0:
					_enter_state(State.EXPOSED)


func _process_crystal_spikes(_delta: float) -> void:
	if not _hit_done and _state_time >= 0.1:
		_hit_done = true
		_execute_crystal_spikes()

	if _state_time >= 0.8:
		_enter_state(State.IDLE)


func _execute_crystal_spikes() -> void:
	SFX.play_at(SFX.EMERGE_SAND, net_attack_point, 8.0)
	spawn_particles(net_attack_point + Vector3.UP * 0.5, AMETHYST_PURPLE, 40, 7.0)

	for p: Node3D in _players_within(net_attack_point, SPIKES_RADIUS):
		_deal_damage(p, spikes_damage)
		var away: Vector3 = p.global_position - net_attack_point
		away.y = 0.0
		var push: Vector3 = away.normalized() if away.length() > 0.1 else Vector3.UP
		_knockback(p, push * 9.0 + Vector3.UP * 6.0, 0.2)


func _process_gravity_invert(_delta: float) -> void:
	if not _hit_done and _state_time >= 0.12:
		_hit_done = true
		_execute_gravity_invert()

	if _state_time >= 1.0:
		_enter_state(State.EXPOSED)


func _execute_gravity_invert() -> void:
	SFX.play_at(SFX.EMERGE_SAND, global_position, 9.0)
	spawn_particles(global_position + Vector3.UP * 1.5, AMETHYST_GLOW, 50, 9.0)

	for p: Node3D in _players_within(global_position, GRAVITY_PULSE_RADIUS):
		_deal_damage(p, gravity_damage)
		# Inversão gravitacional que faz o jogador flutuar alto estilo How to Fish
		_knockback(p, Vector3.UP * 14.0 + (p.global_position - global_position).normalized() * 5.0, 0.3)


func _process_meteor_roll(_delta: float) -> void:
	if not _hit_done and _state_time >= 0.1:
		_hit_done = true
		_execute_meteor_roll()

	if _state_time >= 0.8:
		_enter_state(State.IDLE)


func _execute_meteor_roll() -> void:
	SFX.play_at(SFX.STONE_IMPACT, global_position, 8.0)
	var count: int = 3 if phase == 3 else 2
	for i: int in count:
		var spread: float = -0.3 + float(i) * (0.6 / maxf(1.0, float(count - 1)))
		var m_dir: Vector3 = net_attack_dir.rotated(Vector3.UP, spread).normalized()
		_spawn_meteor(global_position + Vector3.UP * 1.0 + m_dir * 2.0, m_dir)


func _spawn_meteor(spawn_pos: Vector3, dir: Vector3) -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyMesh.prism(st, Vector3(0.0, -0.7, 0.0), Vector3(0.0, 0.7, 0.0), 0.8, 0.8, 7, METEOR_CRUST)
	LowPolyMesh.prism(st, Vector3(0.0, -0.4, 0.0), Vector3(0.0, 0.4, 0.0), 0.9, 0.9, 6, AMETHYST_PURPLE)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = ToonKit.commit(st)
	mi.material_override = _mat
	mi.top_level = true
	mi.global_position = spawn_pos
	add_child(mi)

	_meteors.append(mi)
	_meteor_dirs.append(dir)


func _update_meteors(delta: float) -> void:
	for i: int in range(_meteors.size() - 1, -1, -1):
		var m: MeshInstance3D = _meteors[i]
		if not is_instance_valid(m):
			_meteors.remove_at(i)
			_meteor_dirs.remove_at(i)
			continue

		var dir: Vector3 = _meteor_dirs[i]
		m.global_position += dir * METEOR_SPEED * delta
		m.rotate(dir.cross(Vector3.UP).normalized(), 10.0 * delta)

		for p: Node3D in _all_players():
			if p.global_position.distance_squared_to(m.global_position) <= 2.8:
				_deal_damage(p, meteor_damage)
				_knockback(p, dir * 13.0 + Vector3.UP * 5.0, 0.2)
				spawn_particles(m.global_position, AMETHYST_GLOW, 20, 5.0)

		if m.global_position.distance_squared_to(global_position) > 700.0:
			m.queue_free()
			_meteors.remove_at(i)
			_meteor_dirs.remove_at(i)


func _process_exposed(_delta: float) -> void:
	if _state_time >= exposed_time:
		_enter_state(State.IDLE)


func is_weak_point_exposed() -> bool:
	return state == State.EXPOSED


func _modify_damage(amount: float, _from: Vector3) -> float:
	if is_weak_point_exposed():
		return amount * WEAK_POINT_FACTOR
	return amount


func _can_take_damage() -> bool:
	return state != State.EMERGE and state != State.DYING


func _can_be_stunned() -> bool:
	return false


func flee_from(_origin: Vector3, _seconds: float) -> void:
	pass


func take_damage(amount: float, from: Vector3 = Vector3.INF) -> void:
	super.take_damage(amount, from)
	if _dead or not has_simulation_authority():
		return
	_hud.set_health(health)
	health_changed.emit(health, max_health)

	# Transição de fases
	if phase == 1 and health <= max_health * 0.66:
		phase = 2
		spawn_particles(global_position + Vector3.UP * 2.0, AMETHYST_GLOW, 40, 6.0)
		_spawn_minion(&"crawler", global_position + Vector3(-3.5, 0.0, 2.0))
		_spawn_minion(&"crawler", global_position + Vector3(3.5, 0.0, 2.0))
	elif phase == 2 and health <= max_health * 0.33:
		phase = 3
		spawn_particles(global_position + Vector3.UP * 2.5, AMETHYST_PURPLE, 50, 8.0)
		_spawn_minion(&"floater", global_position + Vector3(0.0, 2.0, 4.0))


func wake_immediately() -> void:
	if state == State.EMERGE:
		global_position.y = _surface_y
		_hud.visible = true
		_enter_state(State.IDLE)


func _on_died() -> void:
	_hud.set_health(0.0)
	_enter_state(State.DYING)
	set_physics_process(false)


func _process_dying(_delta: float) -> void:
	var t: float = clampf(_state_time / 3.0, 0.0, 1.0)
	_body.position.y = -3.5 * t * t

	if _state_time >= 1.2 and not _hit_done:
		_hit_done = true
		_hud.visible = false
		spawn_particles(global_position + Vector3.UP * 2.0, AMETHYST_PURPLE, 70, 8.0)
		if has_simulation_authority():
			QuestRewards.drop_item(get_tree(), TROPHY_ITEM_ID, global_position + Vector3.UP * 2.0)
			QuestRewards.drop_item(get_tree(), SECONDARY_TROPHY_ID, global_position + Vector3.UP * 2.0 + Vector3.RIGHT * 1.5)
		boss_defeated.emit(BOSS_ID)

	if _state_time >= 3.2:
		for m: MeshInstance3D in _meteors:
			if is_instance_valid(m):
				m.queue_free()
		queue_free()


func _report_defeat_to_core(boss_id: StringName) -> void:
	if has_simulation_authority() and GameState.instance != null:
		GameState.instance.request_report_boss_defeated(String(boss_id))


func _refresh_remote_visuals() -> void:
	if _warning == null:
		return
	match state:
		State.CRYSTAL_SPIKES_TELE:
			_warning.show_circle(net_attack_point, SPIKES_RADIUS)
		State.GRAVITY_INVERT_TELE:
			_warning.show_circle(global_position, GRAVITY_PULSE_RADIUS)
		State.METEOR_TELE:
			_warning.show_line(global_position, net_attack_dir, 20.0, 3.2)
		_:
			_warning.hide_warning()


func _on_remote_state(new_state: int) -> void:
	state = new_state as State
	_state_time = 0.0
	_hud.visible = state != State.EMERGE and state != State.DYING
	_refresh_remote_visuals()


# ---------------------------------------------------------------------------
# Modelo 3D Low-Poly + ToonKit (referência: o_que_dorme.jpg)
# ---------------------------------------------------------------------------

func _build_model() -> void:
	_mat = ToonKit.vertex_material(true, true)
	_register_flash_material(_mat)

	_amethyst_mat = ToonKit.vertex_material(true, true)
	_amethyst_mat.set_shader_parameter(&"emission_color", AMETHYST_PURPLE)
	_register_flash_material(_amethyst_mat)

	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Borda circular rochosa da cratera de onde emerge
	LowPolyMesh.prism(st, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.6, 0.0), 2.8, 2.5, 10, TITAN_DARK)
	for k: int in 12:
		var a: float = TAU * float(k) / 12.0
		var h: float = 0.85 + 0.25 * float(k % 3)
		var lip: Vector3 = Vector3(sin(a) * 2.6, 0.0, cos(a) * 2.6)
		LowPolyMesh.box(st, lip + Vector3(0.0, h * 0.5, 0.0), Vector3(1.2, h, 0.5), Basis(Vector3.UP, a), METEOR_CRUST)

	# Tronco maciço colossal
	LowPolyMesh.prism(st, Vector3(0.0, 0.5, 0.0), Vector3(0.0, 2.4, 0.0), 1.6, 1.4, 8, TITAN_STONE)
	LowPolyMesh.box(st, Vector3(0.0, 2.2, 0.2), Vector3(2.4, 1.2, 1.6), Basis.IDENTITY, TITAN_DARK)

	# Cabeça pétrea imponente com máscara de olhos
	LowPolyMesh.prism(st, Vector3(0.0, 2.5, 0.0), Vector3(0.0, 3.4, -0.3), 1.0, 0.75, 6, TITAN_STONE)

	# Múltiplos olhos púrpuras brilhantes (referência: o_que_dorme.jpg)
	var eye_offsets: Array[Vector3] = [
		Vector3(0.0, 3.1, -0.98),
		Vector3(-0.35, 2.9, -0.98),
		Vector3(0.35, 2.9, -0.98),
		Vector3(-0.25, 2.65, -1.0),
		Vector3(0.25, 2.65, -1.0),
		Vector3(0.0, 2.45, -1.02)
	]
	for eo: Vector3 in eye_offsets:
		LowPolyMesh.box(st, eo, Vector3(0.2, 0.14, 0.08), Basis.IDENTITY, EYE_PURPLE)

	# Mandíbulas / presas de pedra ao redor da boca
	LowPolyMesh.prism(st, Vector3(-0.4, 2.3, -0.6), Vector3(-0.2, 1.8, -0.7), 0.15, 0.04, 4, TITAN_DARK)
	LowPolyMesh.prism(st, Vector3(0.4, 2.3, -0.6), Vector3(0.2, 1.8, -0.7), 0.15, 0.04, 4, TITAN_DARK)

	_body.add_child(LowPolyMesh.commit(st, "TitanMesh", _mat))

	# Cristais gigantes de ametista no dorso e ombros
	var st_cr: SurfaceTool = SurfaceTool.new()
	st_cr.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in 6:
		var a: float = float(i) * 1.05
		var c_pos: Vector3 = Vector3(cos(a) * 1.1, 2.5 + sin(a * 2.0) * 0.4, 0.4 + sin(a) * 0.5)
		LowPolyMesh.prism(st_cr, c_pos, c_pos * 1.45 + Vector3.UP * 0.6, 0.28, 0.0, 5, AMETHYST_GLOW)
	# Núcleo de ametista central no peito
	LowPolyMesh.prism(st_cr, Vector3(0.0, 1.8, -0.4), Vector3(0.0, 1.8, -0.7), 0.35, 0.0, 6, AMETHYST_GLOW)
	_core_mesh = LowPolyMesh.commit(st_cr, "AmethystMesh", _amethyst_mat)
	_body.add_child(_core_mesh)

	# Braços colossais que seguram a borda da cratera
	_arm_left = _build_arm(-1.6, "ArmL")
	_arm_right = _build_arm(1.6, "ArmR")

	# Collision Shape colossal
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(3.2, 3.6, 3.2)
	cs.shape = box
	cs.position = Vector3(0.0, 1.8, 0.0)
	add_child(cs)


func _build_arm(x: float, arm_name: String) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.name = arm_name
	pivot.position = Vector3(x, 2.2, 0.0)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s: float = -1.0 if x < 0.0 else 1.0
	# Ombro e braço superior
	LowPolyMesh.prism(st, Vector3(0.0, 0.0, 0.0), Vector3(s * 0.8, -0.7, -0.4), 0.45, 0.38, 6, TITAN_STONE)
	# Antebraço e garras colossais na borda
	LowPolyMesh.prism(st, Vector3(s * 0.8, -0.7, -0.4), Vector3(s * 1.1, -1.8, -0.8), 0.38, 0.28, 5, TITAN_DARK)
	# Garras
	for k: int in 3:
		var gz: float = -0.6 - float(k) * 0.2
		LowPolyMesh.prism(st, Vector3(s * 1.1, -1.8, gz), Vector3(s * 1.3, -2.1, gz - 0.2), 0.08, 0.0, 3, TITAN_STONE)
	pivot.add_child(LowPolyMesh.commit(st, "ArmMesh", _mat))
	_body.add_child(pivot)
	return pivot


func _animate(delta: float) -> void:
	if _body == null:
		return

	if state == State.IDLE:
		_body.position.y = absf(sin(_anim_time * 2.5)) * 0.08
		if _arm_left != null:
			_arm_left.rotation.x = sin(_anim_time * 2.5) * 0.15
		if _arm_right != null:
			_arm_right.rotation.x = -sin(_anim_time * 2.5) * 0.15
	elif state == State.CRYSTAL_SPIKES_TELE:
		# Levanta o braço convocando espigões
		if _arm_left != null:
			_arm_left.rotation.x = -0.8
		if _arm_right != null:
			_arm_right.rotation.x = -0.8
	elif state == State.GRAVITY_INVERT_TELE:
		# Ergue o corpo com ametistas a pulsar
		_body.position.y = lerpf(_body.position.y, 0.5, clampf(6.0 * delta, 0.0, 1.0))
	elif state == State.EXPOSED:
		# Ajoelhado / caído na borda com o núcleo saliente
		_body.position.y = lerpf(_body.position.y, -0.4, clampf(6.0 * delta, 0.0, 1.0))
		_body.rotation.x = 0.35
		_body.rotation.z = sin(_anim_time * 6.0) * 0.05
