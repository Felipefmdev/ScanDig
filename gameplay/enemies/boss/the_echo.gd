class_name TheEcho
extends EnemyBase

## O Eco (#44, #57): chefe escondido da Cratera.
## Inspirado fielmente na referência visual o_eco.jpg:
##  - Entidade ressonante de máscara/caveira de cristal flutuante fragmentada;
##  - Fragmentos angulares escuros e ciano luminoso com olhos radiantes e cornos cristalinos;
##  - Emite anéis sónicos concêntricos que expandem lateralmente e frontalmente;
##  - Ataques caóticos e telegrafados estilo "How to Fish":
##      * TELETRANSPORTE: desfaz-se em estilhaços no ar e remonta noutra posição;
##      * ONDAS SÓNICAS EM ANEL: emite pulsos de ressonância com recuo e knockback extremo;
##      * ECOS ATRASADOS (#57): marca 3 círculos onde o jogador ESTEVE nos últimos segundos e
##        rebentam um a um (0,35 s) a atirá-lo ao ar — quem fica parado leva com todos;
##      * CORO DE RESSONÂNCIA: após a onda máxima, fica DESPEDAÇADA/TONTA (SHATTERED_DIZZY,
##        dano a 2,5x e guarda completamente aberta);
##  - Troféu ao morrer: 'cristal_eco'.

signal boss_defeated(boss_id: StringName)
signal health_changed(current: float, max_value: float)

enum State { EMERGE, HOVER, TELEPORT, SONIC_RING_TELE, SONIC_RING, SHATTERED_DIZZY, DYING, ECHO_TELE, ECHO_BURST }

const BOSS_ID: StringName = &"the_echo"
const BOSS_NAME: String = "O ECO"
const GROUP_BOSSES: StringName = &"bosses"
const TROPHY_ITEM_ID: String = "cristal_eco"

const CRYSTAL_DARK: Color = Color("#3c3a52")
const CRYSTAL_GREY: Color = Color("#5a5a72")
const RESONANCE_CYAN: Color = Color("#40e8e0")
const RESONANCE_GLOW: Color = Color(0.60, 1.0, 0.98)
const EYE_CYAN: Color = Color(0.85, 1.0, 1.0)

const WEAK_POINT_FACTOR: float = 2.5
const SONIC_RADIUS: float = 5.5
const HOVER_ALTITUDE: float = 2.2
const PHASE_TWO_RATIO: float = 0.5
## Ecos atrasados.
const ECHO_COUNT: int = 3
const ECHO_RADIUS: float = 1.8
const ECHO_RECORD_INTERVAL: float = 0.6
const ECHO_TELE_TIME: float = 1.1
const ECHO_GAP: float = 0.35
const ECHO_DAMAGE: float = 10.0

@export var move_speed: float = 2.8
@export var turn_speed: float = 5.0
@export var sonic_damage: float = 20.0
@export var sonic_tele_time: float = 1.1
@export var dizzy_time: float = 3.5
@export var emerge_time: float = 2.2

var state: State = State.EMERGE
var phase: int = 1
var net_attack_point: Vector3 = Vector3.ZERO:
	set(value):
		net_attack_point = value
		if not has_simulation_authority() and is_node_ready():
			_refresh_remote_visuals()

var _state_time: float = 0.0
var _surface_y: float = 0.0
var _hit_done: bool = false
var _attack_cycle: int = 0
var _anim_time: float = 0.0

var _hud: BossHud = null
var _warning: GroundWarning = null
var _body: Node3D = null
var _fragments: Array[Node3D] = []
var _sonic_rings: Array[MeshInstance3D] = []
var _ring_scales: Array[float] = []
var _mat: ShaderMaterial = null
var _glow_mat: ShaderMaterial = null
## Replicado: onde rebentam os ecos (os clientes desenham os avisos).
var net_echo_points: PackedVector3Array = PackedVector3Array():
	set(value):
		net_echo_points = value
		if not has_simulation_authority() and is_node_ready():
			_refresh_echo_warnings()
var _trail: Array[Vector3] = []
var _trail_timer: float = 0.0
var _echo_warnings: Array[GroundWarning] = []
var _echo_done: int = 0


func _ready() -> void:
	super._ready()
	add_to_group(GROUP_BOSSES)
	max_health = 1250.0
	health = 1250.0
	death_color = RESONANCE_CYAN
	stun_fx_height = 2.6
	_surface_y = global_position.y
	_build_model()
	_hud = BossHud.create("🔊 " + tr(BOSS_NAME), max_health, Color(0.30, 0.90, 0.85))
	add_child(_hud)
	_warning = GroundWarning.new()
	add_child(_warning)
	for i: int in ECHO_COUNT:
		var w: GroundWarning = GroundWarning.new()
		add_child(w)
		_echo_warnings.append(w)
	boss_defeated.connect(_report_defeat_to_core)
	_enter_state(State.EMERGE)


func setup_network() -> void:
	super.setup_network()
	_add_synced_property(".:net_attack_point")
	_add_synced_property(".:net_echo_points")


func _enemy_physics(delta: float) -> void:
	_state_time += delta
	_anim_time += delta

	_update_sonic_rings(delta)

	var speed_k: float = 0.85 if phase == 2 else 1.0

	match state:
		State.EMERGE:
			var t: float = clampf(_state_time / emerge_time, 0.0, 1.0)
			global_position.y = _surface_y + HOVER_ALTITUDE * t
			if t >= 1.0:
				_hud.visible = true
				_enter_state(State.HOVER)
		State.HOVER:
			_process_hover(delta)
		State.TELEPORT:
			_process_teleport(delta)
		State.SONIC_RING_TELE:
			_warning.pulse(delta)
			if _state_time >= sonic_tele_time * speed_k:
				_enter_state(State.SONIC_RING)
		State.SONIC_RING:
			_process_sonic_ring(delta)
		State.SHATTERED_DIZZY:
			_process_shattered_dizzy(delta)
		State.ECHO_TELE:
			for w: GroundWarning in _echo_warnings:
				if w.visible:
					w.pulse(delta)
			if _state_time >= ECHO_TELE_TIME * speed_k:
				_enter_state(State.ECHO_BURST)
		State.ECHO_BURST:
			_process_echo_burst()

	_record_trail(delta)
	_animate(delta)


func _process(delta: float) -> void:
	if not has_simulation_authority() and state != State.DYING:
		_state_time += delta
		_hud.set_health(health)
		if _warning.visible:
			_warning.pulse(delta)
		for w: GroundWarning in _echo_warnings:
			if w.visible:
				w.pulse(delta)
	elif state == State.DYING and _dead:
		# A física fica desligada na morte: o relógio da animação de morte avança aqui
		_state_time += delta
		_process_dying(delta)


func _enter_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	_hit_done = false
	_echo_done = 0
	if not _echo_warnings.is_empty() and has_simulation_authority():
		if new_state == State.ECHO_TELE:
			net_echo_points = echo_points_from_trail()
		_refresh_echo_warnings()

	match state:
		State.EMERGE:
			global_position.y = _surface_y
		State.HOVER:
			_warning.hide_warning()
		State.TELEPORT:
			_warning.hide_warning()
			SFX.play_at(SFX.SHELL_KNOCK, global_position, 6.0)
			spawn_particles(global_position, RESONANCE_CYAN, 30, 6.0)
		State.SONIC_RING_TELE:
			net_attack_point = global_position
			_warning.show_circle(global_position, SONIC_RADIUS)
			SFX.play_at(SFX.SPRAY, global_position, 5.0)
		State.SONIC_RING:
			_warning.hide_warning()
		State.SHATTERED_DIZZY:
			_warning.hide_warning()
			velocity = Vector3.ZERO
			SFX.play_at(SFX.STONE_IMPACT, global_position, 6.0)


func _process_hover(delta: float) -> void:
	var target_y: float = _ground_height(global_position, global_position.y) + HOVER_ALTITUDE
	var bobbing: float = sin(_anim_time * 3.5) * 0.2
	global_position.y = lerpf(global_position.y, target_y + bobbing, clampf(5.0 * delta, 0.0, 1.0))

	var target: Node3D = _update_target(delta)
	if target != null:
		var to: Vector3 = target.global_position - global_position
		to.y = 0.0
		var dist: float = to.length()
		var dir: Vector3 = to.normalized() if dist > 0.1 else Vector3.ZERO
		_turn_towards(dir, 0.0, turn_speed, delta)

		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, delta * 3.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 3.0)

	move_and_slide()

	if _state_time >= 2.0:
		_attack_cycle += 1
		if _attack_cycle % 3 == 1:
			_enter_state(State.TELEPORT)
		elif _attack_cycle % 3 == 2 and _trail.size() >= 2:
			_enter_state(State.ECHO_TELE)
		else:
			_enter_state(State.SONIC_RING_TELE)


func _process_teleport(_delta: float) -> void:
	if _state_time >= 0.3 and not _hit_done:
		_hit_done = true
		var target: Node3D = _update_target(0.0)
		if target != null:
			var ang: float = randf() * TAU
			var dist: float = randf_range(3.5, 6.0)
			global_position = target.global_position + Vector3(cos(ang) * dist, HOVER_ALTITUDE, sin(ang) * dist)
		spawn_particles(global_position, RESONANCE_GLOW, 35, 6.0)
		SFX.play_at(SFX.SHELL_KNOCK, global_position, 6.0)

	if _state_time >= 0.6:
		_enter_state(State.SONIC_RING_TELE)


func _process_sonic_ring(delta: float) -> void:
	if not _hit_done and _state_time >= 0.1:
		_hit_done = true
		_execute_sonic_rings()

	if _state_time >= 1.2:
		_enter_state(State.SHATTERED_DIZZY)


func _execute_sonic_rings() -> void:
	SFX.play_at(SFX.EMERGE_SAND, global_position, 8.0)
	spawn_particles(global_position, RESONANCE_CYAN, 40, 8.0)

	# Cria anel sónico em expansão (referência: o_eco.jpg)
	_spawn_sonic_ring(global_position)

	for p: Node3D in _players_within(global_position, SONIC_RADIUS):
		_deal_damage(p, sonic_damage)
		var away: Vector3 = p.global_position - global_position
		away.y = 0.0
		var push: Vector3 = away.normalized() if away.length() > 0.1 else -transform.basis.z
		# Empurrão sónico exagerado estilo How to Fish
		_knockback(p, push * 15.0 + Vector3.UP * 8.0, 0.3)


func _spawn_sonic_ring(center: Vector3) -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyMesh.prism(st, Vector3(0.0, -0.05, 0.0), Vector3(0.0, 0.05, 0.0), 1.2, 1.2, 16, RESONANCE_CYAN)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = ToonKit.commit(st)
	mi.material_override = _glow_mat
	mi.top_level = true
	add_child(mi)
	mi.global_position = center

	_sonic_rings.append(mi)
	_ring_scales.append(1.0)


func _update_sonic_rings(delta: float) -> void:
	for i: int in range(_sonic_rings.size() - 1, -1, -1):
		var ring: MeshInstance3D = _sonic_rings[i]
		if not is_instance_valid(ring):
			_sonic_rings.remove_at(i)
			_ring_scales.remove_at(i)
			continue

		var s: float = _ring_scales[i] + delta * 9.0
		_ring_scales[i] = s
		ring.scale = Vector3(s, 1.0, s)

		if s >= 6.0:
			ring.queue_free()
			_sonic_rings.remove_at(i)
			_ring_scales.remove_at(i)


# ---------------------------------------------------------------------------
# #57: ecos atrasados
# ---------------------------------------------------------------------------

## Host: guarda onde o alvo pisou (no chão), de ECHO_RECORD_INTERVAL em ECHO_RECORD_INTERVAL.
func _record_trail(delta: float) -> void:
	_trail_timer -= delta
	if _trail_timer > 0.0:
		return
	_trail_timer = ECHO_RECORD_INTERVAL
	var t: Node3D = _update_target(0.0)
	if t == null:
		return
	var p: Vector3 = t.global_position
	_trail.append(Vector3(p.x, _ground_height(p, p.y), p.z))
	while _trail.size() > ECHO_COUNT + 2:
		_trail.remove_at(0)


## Os ECHO_COUNT pontos mais antigos do rasto (o mais velho rebenta primeiro).
func echo_points_from_trail() -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	var start: int = maxi(_trail.size() - ECHO_COUNT, 0)
	for i: int in range(start, _trail.size()):
		out.append(_trail[i])
	return out


func _refresh_echo_warnings() -> void:
	var on: bool = state == State.ECHO_TELE or state == State.ECHO_BURST
	for i: int in _echo_warnings.size():
		if on and i < net_echo_points.size() and i >= _echo_done:
			_echo_warnings[i].show_circle(net_echo_points[i], ECHO_RADIUS)
		else:
			_echo_warnings[i].hide_warning()


func _process_echo_burst() -> void:
	var due: int = mini(int(_state_time / ECHO_GAP) + 1, net_echo_points.size())
	while _echo_done < due:
		var p: Vector3 = net_echo_points[_echo_done]
		_echo_done += 1
		_spawn_sonic_ring(p + Vector3.UP * 0.1)
		spawn_particles(p + Vector3.UP * 0.3, RESONANCE_GLOW, 24, 6.0)
		SFX.play_at(SFX.SHELL_KNOCK, p, 4.0)
		for pl: Node3D in _players_within(p, ECHO_RADIUS):
			_deal_damage(pl, ECHO_DAMAGE)
			var out: Vector3 = pl.global_position - p
			out.y = 0.0
			out = out.normalized() if out.length_squared() > 0.01 else Vector3.FORWARD
			_knockback(pl, out * 4.0 + Vector3.UP * 11.0, 0.12)
		_refresh_echo_warnings()
	if _echo_done >= net_echo_points.size() and _state_time >= ECHO_GAP * float(net_echo_points.size()) + 0.3:
		_enter_state(State.HOVER)


func _process_shattered_dizzy(_delta: float) -> void:
	velocity = Vector3.ZERO
	if _state_time >= dizzy_time:
		_enter_state(State.HOVER)


func is_weak_point_exposed() -> bool:
	return state == State.SHATTERED_DIZZY


func _modify_damage(amount: float, _from: Vector3) -> float:
	if is_weak_point_exposed():
		return amount * WEAK_POINT_FACTOR
	return amount


func _can_take_damage() -> bool:
	return state != State.EMERGE and state != State.DYING


func _can_be_stunned() -> bool:
	return state == State.HOVER or state == State.SHATTERED_DIZZY


func flee_from(_origin: Vector3, _seconds: float) -> void:
	pass


func take_damage(amount: float, from: Vector3 = Vector3.INF) -> void:
	super.take_damage(amount, from)
	if _dead or not has_simulation_authority():
		return
	_hud.set_health(health)
	health_changed.emit(health, max_health)

	if phase == 1 and health < max_health * PHASE_TWO_RATIO:
		phase = 2
		spawn_particles(global_position, RESONANCE_GLOW, 40, 7.0)


func wake_immediately() -> void:
	if state == State.EMERGE:
		global_position.y = _surface_y + HOVER_ALTITUDE
		_hud.visible = true
		_enter_state(State.HOVER)


func _on_died() -> void:
	_hud.set_health(0.0)
	_enter_state(State.DYING)
	set_physics_process(false)


func _process_dying(_delta: float) -> void:
	var t: float = clampf(_state_time / 2.6, 0.0, 1.0)
	_body.position.y = -2.0 * t * t

	if _state_time >= 1.2 and not _hit_done:
		_hit_done = true
		_hud.visible = false
		spawn_particles(global_position, RESONANCE_CYAN, 60, 8.0)
		if has_simulation_authority():
			QuestRewards.drop_item(get_tree(), TROPHY_ITEM_ID, global_position + Vector3.UP * 1.5)
		boss_defeated.emit(BOSS_ID)

	if _state_time >= 3.0:
		for r: MeshInstance3D in _sonic_rings:
			if is_instance_valid(r):
				r.queue_free()
		queue_free()


func _report_defeat_to_core(boss_id: StringName) -> void:
	if has_simulation_authority() and GameState.instance != null:
		GameState.instance.request_report_boss_defeated(String(boss_id))


func _refresh_remote_visuals() -> void:
	if _warning == null:
		return
	match state:
		State.SONIC_RING_TELE:
			_warning.show_circle(global_position, SONIC_RADIUS)
		_:
			_warning.hide_warning()


func _on_remote_state(new_state: int) -> void:
	state = new_state as State
	_state_time = 0.0
	_hud.visible = state != State.EMERGE and state != State.DYING
	_refresh_remote_visuals()
	_refresh_echo_warnings()


# ---------------------------------------------------------------------------
# Modelo 3D Low-Poly + ToonKit (referência: o_eco.jpg)
# ---------------------------------------------------------------------------

func _build_model() -> void:
	_mat = ToonKit.vertex_material(true, true)
	_register_flash_material(_mat)

	_glow_mat = ToonKit.vertex_material(true, true)
	_glow_mat.set_shader_parameter(&"emission_color", RESONANCE_CYAN)
	_register_flash_material(_glow_mat)

	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Crânio / Máscara central fragmentada
	LowPolyMesh.prism(st, Vector3(0.0, 0.4, 0.0), Vector3(0.0, 1.2, 0.0), 0.65, 0.55, 7, CRYSTAL_DARK)
	LowPolyMesh.prism(st, Vector3(0.0, 1.2, 0.0), Vector3(0.0, 1.7, 0.0), 0.55, 0.35, 6, CRYSTAL_GREY)

	# Mandíbula afiada de cristais
	LowPolyMesh.prism(st, Vector3(0.0, 0.4, -0.2), Vector3(0.0, -0.2, -0.1), 0.35, 0.08, 5, CRYSTAL_DARK)

	# Cornos superiores de cristal
	LowPolyMesh.prism(st, Vector3(-0.35, 1.5, 0.0), Vector3(-0.75, 2.3, 0.1), 0.18, 0.02, 4, CRYSTAL_GREY)
	LowPolyMesh.prism(st, Vector3(0.35, 1.5, 0.0), Vector3(0.75, 2.3, 0.1), 0.18, 0.02, 4, CRYSTAL_GREY)

	# Olhos radiantes ciano esbugalhados
	LowPolyMesh.box(st, Vector3(-0.24, 1.1, -0.42), Vector3(0.20, 0.14, 0.08), Basis.IDENTITY, RESONANCE_GLOW)
	LowPolyMesh.box(st, Vector3(0.24, 1.1, -0.42), Vector3(0.20, 0.14, 0.08), Basis.IDENTITY, RESONANCE_GLOW)

	# Anéis de ressonância dos dois lados da máscara (o_eco.jpg)
	for side: float in [-1.0, 1.0]:
		for r: float in [0.55, 0.32]:
			for k: int in 14:
				var a0: float = TAU * float(k) / 14.0
				var a1: float = TAU * float(k + 1) / 14.0
				var p0: Vector3 = Vector3(1.15 * side, 1.1 + cos(a0) * r, sin(a0) * r)
				var p1: Vector3 = Vector3(1.15 * side, 1.1 + cos(a1) * r, sin(a1) * r)
				LowPolyMesh.prism(st, p0, p1, 0.035, 0.035, 4, RESONANCE_GLOW)
	_body.add_child(LowPolyMesh.commit(st, "MaskMesh", _mat))

	# Fragmentos flutuantes orbitantes que se soltam no estado SHATTERED_DIZZY
	for i: int in 6:
		var frag: Node3D = _build_fragment(i)
		_fragments.append(frag)
		_body.add_child(frag)

	# Collision Shape flutuante
	var cs: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.8
	cap.height = 2.4
	cs.shape = cap
	cs.position = Vector3(0.0, 0.8, 0.0)
	add_child(cs)


func _build_fragment(index: int) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.name = "Fragment%d" % index
	var ang: float = float(index) * (TAU / 6.0)
	pivot.position = Vector3(cos(ang) * 0.9, 0.8 + sin(ang * 2.0) * 0.35, sin(ang) * 0.9)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyMesh.prism(st, Vector3.ZERO, Vector3(0.0, 0.35, 0.0), 0.12, 0.0, 4, RESONANCE_CYAN)
	pivot.add_child(LowPolyMesh.commit(st, "FragMesh", _glow_mat))
	return pivot


func _animate(delta: float) -> void:
	if _body == null:
		return

	if state == State.HOVER:
		_body.position.y = sin(_anim_time * 3.5) * 0.12
		_body.rotation.z = sin(_anim_time * 2.5) * 0.08
		for i: int in range(_fragments.size()):
			var f: Node3D = _fragments[i]
			var ang: float = float(i) * (TAU / 6.0) + _anim_time * 1.5
			f.position = Vector3(cos(ang) * 0.9, 0.8 + sin(ang * 2.0) * 0.35, sin(ang) * 0.9)
	elif state == State.SONIC_RING_TELE:
		# Vibra intensamente
		_body.position.x = sin(_anim_time * 35.0) * 0.06
		_body.position.y = cos(_anim_time * 35.0) * 0.06
	elif state == State.SHATTERED_DIZZY:
		# Fragmentos despedaçados afastados e tontos
		_body.rotation.y += 3.0 * delta
		_body.rotation.z = sin(_anim_time * 5.0) * 0.25
		for i: int in range(_fragments.size()):
			var f: Node3D = _fragments[i]
			var ang: float = float(i) * (TAU / 6.0) + _anim_time * 3.0
			f.position = Vector3(cos(ang) * 1.6, 0.8 + sin(ang * 3.0) * 0.6, sin(ang) * 1.6)

