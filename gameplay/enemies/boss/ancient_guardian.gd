class_name AncientGuardian
extends EnemyBase

## Guardião Ancestral (#42): chefe principal das Ruínas, um colosso de pedra no pátio a leste
## do templo (acorda pelo BossAltar). Desenhado com o espírito da #57 (caos How to Fish, tudo
## telegrafado):
##   - ARMADURA: de pedra, só ARMOR_FACTOR do dano. Há PLATE_COUNT placas de jade à volta do
##     pátio e uma acende de cada vez; quem a pisar faz o colosso ajoelhar com o núcleo de jade
##     exposto (EXPOSED_TIME s, dano a dobrar e meio).
##   - PISÃO: anel vermelho à volta dele, depois onda de choque que atira toda a gente para fora.
##   - BOWLING: arranca um pedregulho e rola-o em linha para o jogador (faixa no chão).
##   - PIÃO: abre os braços e gira atrás dos jogadores; no fim fica TONTO (guarda aberta).
## Fase 2 (vida < 50 %): ataques mais rápidos e dois pedregulhos em leque.
## Coop (#24): IA no host; estado, ponto/direção do ataque e placa acesa replicados.

signal boss_defeated(boss_id: StringName)
signal health_changed(current: float, max_value: float)

enum State { EMERGE, WALK, STOMP_TELE, STOMP, BOWL_TELE, BOWL, SPIN_TELE, SPIN, DIZZY, EXPOSED, DYING }

const BOSS_ID: StringName = &"ancient_guardian"
const BOSS_NAME: String = "GUARDIÃO ANCESTRAL"
const GROUP_BOSSES: StringName = &"bosses"
const TROPHY_ITEM_ID: String = "nucleo_guardiao"
const CrabModel := preload("res://gameplay/enemies/crab/crab_model.gd")
const ARMOR_FACTOR: float = 0.25
const EXPOSED_FACTOR: float = 2.5
const STOMP_RADIUS: float = 4.5
const PLATE_COUNT: int = 4
const PLATE_RADIUS: float = 7.0
const PLATE_STEP: float = 1.1
const BOWL_LENGTH: float = 20.0
const BOWL_SPEED: float = 11.0
const SPIN_RADIUS: float = 2.6
const PHASE_TWO_RATIO: float = 0.5

const STONE: Color = Color("#b38d5c")
const STONE_DARK: Color = Color("#6e6a5c")
const MOSS: Color = Color("#5e7a2a")
const JADE: Color = Color("#40f0d8")

@export var move_speed: float = 1.4
@export var stomp_damage: float = 18.0
@export var bowl_damage: float = 20.0
@export var spin_damage: float = 14.0
@export var tele_time: float = 1.1
@export var spin_time: float = 3.2
@export var dizzy_time: float = 2.6
@export var exposed_time: float = 4.0
@export var emerge_time: float = 2.5
## Segundos entre mudanças da placa acesa.
@export var plate_interval: float = 7.0

var state: State = State.EMERGE
var phase: int = 1
var net_attack_point: Vector3 = Vector3.ZERO
var net_attack_dir: Vector3 = Vector3.FORWARD
## Placa acesa (0..PLATE_COUNT-1, -1 = nenhuma). Replicada.
var lit_plate: int = -1:
	set(value):
		lit_plate = value
		_refresh_plates()

var _state_time: float = 0.0
var _home: Vector3 = Vector3.ZERO
var _surface_y: float = 0.0
var _hit_done: bool = false
var _hit_list: Array[Node] = []
var _plate_timer: float = 3.0
var _attack_cycle: int = 0
var _hud: BossHud = null
var _warning: GroundWarning = null
var _body: Node3D = null
var _arm_left: Node3D = null
var _arm_right: Node3D = null
var _core_mat: ShaderMaterial = null
var _plates: Array[MeshInstance3D] = []
var _plate_mats: Array[ShaderMaterial] = []
var _boulders: Array[MeshInstance3D] = []
var _anim_time: float = 0.0


func _ready() -> void:
	super._ready()
	add_to_group(GROUP_BOSSES)
	stun_fx_height = 4.8
	death_color = STONE
	_home = global_position
	_surface_y = global_position.y
	_build_model()
	_build_plates()
	_hud = BossHud.create("🗿 " + BOSS_NAME, max_health, Color(0.3, 0.75, 0.55))
	add_child(_hud)
	_warning = GroundWarning.new()
	add_child(_warning)
	boss_defeated.connect(_report_defeat_to_core)
	_enter_state(State.EMERGE)


func setup_network() -> void:
	super.setup_network()
	_add_synced_property(".:net_attack_point")
	_add_synced_property(".:net_attack_dir")
	_add_synced_property(".:lit_plate")


func _enemy_physics(delta: float) -> void:
	_state_time += delta
	if state != State.EMERGE and state != State.DYING:
		_update_plates(delta)
	var speed_k: float = 0.75 if phase == 2 else 1.0
	match state:
		State.EMERGE:
			var t: float = clampf(_state_time / emerge_time, 0.0, 1.0)
			global_position.y = _surface_y - 4.5 * (1.0 - t)
			if t >= 1.0:
				_hud.visible = true
				_enter_state(State.WALK)
		State.WALK:
			_process_walk(delta)
		State.STOMP_TELE:
			_warning.pulse(delta)
			if _state_time >= tele_time * speed_k:
				_enter_state(State.STOMP)
		State.STOMP:
			if not _hit_done and _state_time >= 0.12:
				_hit_done = true
				_stomp()
			if _state_time >= 0.8:
				_enter_state(State.WALK)
		State.BOWL_TELE:
			_warning.pulse(delta)
			_face(net_attack_dir, delta)
			if _state_time >= tele_time * speed_k:
				_enter_state(State.BOWL)
		State.BOWL:
			_process_bowl()
		State.SPIN_TELE:
			if _state_time >= 0.8 * speed_k:
				_enter_state(State.SPIN)
		State.SPIN:
			_process_spin(delta)
		State.DIZZY:
			if _state_time >= dizzy_time:
				_enter_state(State.WALK)
		State.EXPOSED:
			if _state_time >= exposed_time:
				_enter_state(State.WALK)


func _process(delta: float) -> void:
	_anim_time += delta
	if not has_simulation_authority() or state == State.DYING:
		_state_time += delta
	_animate(delta)
	if state == State.DYING and _dead:
		_process_dying()
	elif not has_simulation_authority():
		_hud.set_health(health)
		if _warning.visible:
			_warning.pulse(delta)


# ---------------------------------------------------------------------------
# Estados
# ---------------------------------------------------------------------------

func _enter_state(s: State) -> void:
	state = s
	_state_time = 0.0
	_hit_done = false
	_hit_list.clear()
	match s:
		State.EMERGE:
			_surface_y = global_position.y
			global_position.y = _surface_y - 4.5
		State.STOMP_TELE:
			net_attack_point = global_position
		State.STOMP:
			SFX.play_at(SFX.EMERGE_SAND, global_position, 8.0)
		State.EXPOSED:
			lit_plate = -1
			_plate_timer = plate_interval
			SFX.play_at(SFX.SHELL_KNOCK, global_position, 6.0)
	_refresh_visuals()


func _refresh_visuals() -> void:
	match state:
		State.STOMP_TELE:
			_warning.show_circle(net_attack_point, STOMP_RADIUS)
		State.BOWL_TELE:
			_warning.show_line(net_attack_point, net_attack_dir, BOWL_LENGTH, 1.8)
		_:
			_warning.hide_warning()
	if _core_mat != null:
		var open: bool = state == State.EXPOSED or state == State.DIZZY
		_core_mat.set_shader_parameter(&"emission_color", Color(0.3, 0.9, 0.6) if open else Color(0.0, 0.08, 0.05))
	for b: MeshInstance3D in _boulders:
		b.visible = state == State.BOWL


func _process_walk(delta: float) -> void:
	_apply_gravity(delta)
	var target: Node3D = _update_target(delta)
	if target == null:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	var to: Vector3 = target.global_position - global_position
	to.y = 0.0
	var dist: float = to.length()
	var dir: Vector3 = to / dist if dist > 0.01 else Vector3.FORWARD
	_face(dir, delta)
	# Não se afasta muito do pátio (as placas estão lá).
	var home_d: Vector3 = global_position - _home
	home_d.y = 0.0
	if home_d.length() > PLATE_RADIUS - 1.5:
		dir = (-home_d).normalized()
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	move_and_slide()
	if _state_time < (1.0 if phase == 2 else 1.8):
		return
	_attack_cycle += 1
	net_attack_dir = (to / dist) if dist > 0.01 else -global_transform.basis.z
	net_attack_point = global_position
	if dist < STOMP_RADIUS - 0.5:
		_enter_state(State.STOMP_TELE if _attack_cycle % 3 != 0 else State.SPIN_TELE)
	elif _attack_cycle % 2 == 0:
		_enter_state(State.SPIN_TELE)
	else:
		_enter_state(State.BOWL_TELE)


func _stomp() -> void:
	spawn_particles(global_position + Vector3.UP * 0.2, STONE_DARK, 30, 5.0)
	for p: Node3D in _all_players():
		var d: Vector3 = p.global_position - global_position
		d.y = 0.0
		if d.length() <= STOMP_RADIUS:
			_deal_damage(p, stomp_damage)
			var out: Vector3 = d.normalized() if d.length() > 0.1 else Vector3.FORWARD
			_knockback(p, out * 10.0 + Vector3.UP * 7.0, 0.09)


## Pedregulho(s) a rolar: posição = início + direção × velocidade × tempo (igual em todos os peers).
func _process_bowl() -> void:
	var travelled: float = _state_time * BOWL_SPEED
	for i: int in _bowl_dirs().size():
		var dir: Vector3 = _bowl_dirs()[i]
		var pos: Vector3 = net_attack_point + dir * travelled
		for p: Node3D in _all_players():
			if _hit_list.has(p):
				continue
			var d: Vector3 = p.global_position - pos
			d.y = 0.0
			if d.length() <= 1.4:
				_hit_list.append(p)
				_deal_damage(p, bowl_damage)
				_knockback(p, dir * 11.0 + Vector3.UP * 8.0, 0.08)
	if travelled >= BOWL_LENGTH:
		_enter_state(State.WALK)


func _bowl_dirs() -> Array[Vector3]:
	if phase == 2:
		return [net_attack_dir.rotated(Vector3.UP, 0.3), net_attack_dir.rotated(Vector3.UP, -0.3)]
	return [net_attack_dir]


func _process_spin(delta: float) -> void:
	_apply_gravity(delta)
	var target: Node3D = _update_target(delta)
	if target != null:
		var to: Vector3 = target.global_position - global_position
		to.y = 0.0
		var dir: Vector3 = to.normalized() if to.length() > 0.1 else Vector3.ZERO
		velocity.x = dir.x * move_speed * 3.2
		velocity.z = dir.z * move_speed * 3.2
	move_and_slide()
	for p: Node3D in _all_players():
		var d: Vector3 = p.global_position - global_position
		d.y = 0.0
		if d.length() <= SPIN_RADIUS and not _hit_list.has(p):
			_hit_list.append(p)
			_deal_damage(p, spin_damage)
			var side: Vector3 = d.normalized().cross(Vector3.UP)
			_knockback(p, (d.normalized() + side) * 9.0 + Vector3.UP * 6.0, 0.07)
	# Pode bater outra vez a cada volta (0,8 s).
	if fmod(_state_time, 0.8) < delta:
		_hit_list.clear()
	if _state_time >= spin_time:
		velocity = Vector3.ZERO
		_enter_state(State.DIZZY)


func _face(dir: Vector3, delta: float) -> void:
	_turn_towards(dir, 0.0, 2.5, delta)


# ---------------------------------------------------------------------------
# Placas de jade
# ---------------------------------------------------------------------------

func plate_position(i: int) -> Vector3:
	var a: float = TAU * float(i) / float(PLATE_COUNT) + PI * 0.25
	return Vector3(_home.x + cos(a) * PLATE_RADIUS, _surface_y, _home.z + sin(a) * PLATE_RADIUS)


func _update_plates(delta: float) -> void:
	if state == State.EXPOSED:
		return
	_plate_timer -= delta
	if _plate_timer <= 0.0:
		_plate_timer = plate_interval * (0.8 if phase == 2 else 1.0)
		var next: int = randi() % PLATE_COUNT
		if next == lit_plate:
			next = (next + 1) % PLATE_COUNT
		lit_plate = next
	if lit_plate < 0:
		return
	var plate: Vector3 = plate_position(lit_plate)
	for p: Node3D in _all_players():
		var d: Vector3 = p.global_position - plate
		d.y = 0.0
		if d.length() <= PLATE_STEP:
			spawn_particles(plate + Vector3.UP * 0.2, JADE, 16, 3.0)
			_enter_state(State.EXPOSED)
			return


func _refresh_plates() -> void:
	for i: int in _plate_mats.size():
		var on: bool = i == lit_plate
		_plate_mats[i].set_shader_parameter(&"emission_color", Color(0.2, 0.8, 0.5) if on else Color.BLACK)
		_plate_mats[i].set_shader_parameter(&"albedo_color", JADE if on else STONE_DARK)


# ---------------------------------------------------------------------------
# Regras de combate
# ---------------------------------------------------------------------------

func is_phase_two() -> bool:
	return health < max_health * PHASE_TWO_RATIO


func is_exposed() -> bool:
	return state == State.EXPOSED


func _can_take_damage() -> bool:
	return state != State.EMERGE and state != State.DYING


func _can_be_stunned() -> bool:
	return false


func _modify_damage(amount: float, _from: Vector3) -> float:
	match state:
		State.EXPOSED:
			return amount * EXPOSED_FACTOR
		State.DIZZY:
			return amount
	return amount * ARMOR_FACTOR


func flee_from(_origin: Vector3, _seconds: float) -> void:
	pass


func take_damage(amount: float, from: Vector3 = Vector3.INF) -> void:
	super.take_damage(amount, from)
	if _dead or not has_simulation_authority():
		return
	_hud.set_health(health)
	health_changed.emit(health, max_health)
	if phase == 1 and is_phase_two():
		phase = 2
		for i: int in 2:
			var ang: float = randf() * TAU
			_spawn_minion(&"stone_guardian", _home + Vector3(cos(ang) * 5.0, 0.0, sin(ang) * 5.0))


func wake_immediately() -> void:
	if state == State.EMERGE:
		global_position.y = _surface_y
		_hud.visible = true
		_enter_state(State.WALK)


func _on_died() -> void:
	_hud.set_health(0.0)
	lit_plate = -1
	_enter_state(State.DYING)
	set_physics_process(false)


func _process_dying() -> void:
	var t: float = clampf(_state_time / 2.5, 0.0, 1.0)
	_body.position.y = -3.5 * t * t
	_body.rotation.z = lerpf(0.0, 0.4, t)
	if _state_time >= 1.2 and not _hit_done:
		_hit_done = true
		_hud.visible = false
		spawn_particles(global_position + Vector3.UP * 2.0, STONE, 50, 6.0)
		if has_simulation_authority():
			QuestRewards.drop_item(get_tree(), TROPHY_ITEM_ID, global_position + Vector3.UP * 2.0)
		boss_defeated.emit(BOSS_ID)
	if _state_time >= 3.0:
		for m: MeshInstance3D in _plates:
			m.queue_free()
		queue_free()


func _report_defeat_to_core(boss_id: StringName) -> void:
	if has_simulation_authority() and GameState.instance != null:
		GameState.instance.request_report_boss_defeated(String(boss_id))


func _on_remote_state(new_state: int) -> void:
	_state_time = 0.0
	_hud.visible = new_state != State.EMERGE and new_state != State.DYING
	_refresh_visuals()


# ---------------------------------------------------------------------------
# Animação e modelo
# ---------------------------------------------------------------------------

func _animate(delta: float) -> void:
	if _body == null:
		return
	var arm: float = 0.0
	var spin_speed: float = 0.0
	match state:
		State.STOMP_TELE:
			arm = -2.6
			_body.position.y = lerpf(_body.position.y, 0.4, clampf(5.0 * delta, 0.0, 1.0))
		State.STOMP:
			arm = 0.5
			_body.position.y = lerpf(_body.position.y, 0.0, clampf(18.0 * delta, 0.0, 1.0))
		State.BOWL_TELE:
			arm = -1.6
		State.BOWL:
			arm = 0.8
		State.SPIN_TELE, State.SPIN:
			arm = -1.57
			spin_speed = 9.0 if state == State.SPIN else 2.0
		State.DIZZY:
			_body.rotation.z = sin(_anim_time * 6.0) * 0.12
		State.EXPOSED:
			_body.position.y = lerpf(_body.position.y, -1.2, clampf(6.0 * delta, 0.0, 1.0))
			arm = 0.9
		State.WALK:
			arm = sin(_anim_time * 2.0) * 0.2
	if state != State.EXPOSED and state != State.STOMP_TELE and state != State.DYING:
		_body.position.y = lerpf(_body.position.y, 0.0, clampf(6.0 * delta, 0.0, 1.0))
	if state != State.DIZZY and state != State.DYING:
		_body.rotation.z = lerpf(_body.rotation.z, 0.0, clampf(6.0 * delta, 0.0, 1.0))
	_body.rotation.y += spin_speed * delta
	if spin_speed == 0.0:
		_body.rotation.y = lerp_angle(_body.rotation.y, 0.0, clampf(4.0 * delta, 0.0, 1.0))
	if state == State.SPIN or state == State.SPIN_TELE:
		_arm_left.rotation = Vector3(0.0, 0.0, arm)
		_arm_right.rotation = Vector3(0.0, 0.0, -arm)
	else:
		_arm_left.rotation = Vector3(lerpf(_arm_left.rotation.x, arm, clampf(10.0 * delta, 0.0, 1.0)), 0.0, 0.0)
		_arm_right.rotation = Vector3(lerpf(_arm_right.rotation.x, arm, clampf(10.0 * delta, 0.0, 1.0)), 0.0, 0.0)
	# Pedregulhos a rolar (todos os peers)
	if state == State.BOWL:
		var dirs: Array[Vector3] = _bowl_dirs()
		for i: int in _boulders.size():
			if i < dirs.size():
				_boulders[i].visible = true
				_boulders[i].global_position = net_attack_point + dirs[i] * _state_time * BOWL_SPEED + Vector3.UP * 0.9
				_boulders[i].rotation.x -= delta * 12.0
			else:
				_boulders[i].visible = false


func _build_model() -> void:
	var mat: ShaderMaterial = ToonKit.vertex_material(true, true)
	mat.set_shader_parameter(&"spots_amount", 0.55)
	mat.set_shader_parameter(&"spots_color", MOSS)
	mat.set_shader_parameter(&"spots_scale", 1.6)
	mat.set_shader_parameter(&"spots_size", 0.28)
	mat.set_shader_parameter(&"chip_amount", 0.3)
	mat.set_shader_parameter(&"chip_color", STONE_DARK)
	mat.set_shader_parameter(&"chip_scale", 1.5)
	_register_flash_material(mat)
	_body = Node3D.new()
	_body.name = "BodyRoot"
	add_child(_body)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Pernas, tronco, ombros e cabeça-máscara
	for side: float in [-1.0, 1.0]:
		LowPolyMesh.box(st, Vector3(0.6 * side, 0.8, 0.0), Vector3(0.8, 1.6, 0.9), Basis.IDENTITY, STONE_DARK)
		LowPolyMesh.box(st, Vector3(0.6 * side, 0.15, -0.15), Vector3(1.0, 0.3, 1.3), Basis.IDENTITY, STONE)
	LowPolyMesh.prism(st, Vector3(0.0, 1.6, 0.0), Vector3(0.0, 3.4, 0.0), 1.2, 1.5, 6, STONE)
	for side: float in [-1.0, 1.0]:
		LowPolyMesh.box(st, Vector3(1.45 * side, 3.25, 0.0), Vector3(0.9, 0.6, 1.1), Basis(Vector3.FORWARD, 0.2 * side), STONE_DARK)
	LowPolyMesh.box(st, Vector3(0.0, 3.95, -0.1), Vector3(1.3, 1.1, 1.1), Basis.IDENTITY, STONE)
	LowPolyMesh.prism(st, Vector3(0.0, 4.5, -0.1), Vector3(0.0, 5.2, -0.1), 0.7, 0.0, 4, STONE_DARK)
	var jade: Color = Color(JADE.r, JADE.g, JADE.b, 0.0)
	for side: float in [-1.0, 1.0]:
		LowPolyMesh.box(st, Vector3(0.3 * side, 4.0, -0.66), Vector3(0.32, 0.14, 0.05), Basis.IDENTITY, jade)
	LowPolyMesh.box(st, Vector3(0.0, 3.6, -0.66), Vector3(0.7, 0.1, 0.05), Basis.IDENTITY, Color(0.1, 0.08, 0.07, 0.0))
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = ToonKit.commit(st)
	mi.material_override = mat
	_body.add_child(mi)
	# Núcleo de jade no peito (brilha quando exposto)
	var cst: SurfaceTool = SurfaceTool.new()
	cst.begin(Mesh.PRIMITIVE_TRIANGLES)
	CrabModel.gem(cst, Transform3D.IDENTITY, Vector3(0.0, 2.6, -1.25), Basis(Vector3.RIGHT, -PI * 0.5), [
		Vector3(-0.1, 0.35, 0.35), Vector3(0.05, 0.4, 0.4)], 6, -0.2, 0.25, Color(JADE.r, JADE.g, JADE.b, 0.0), 0.0, 5)
	_core_mat = ToonKit.vertex_material(true, true)
	var core: MeshInstance3D = MeshInstance3D.new()
	core.mesh = ToonKit.commit(cst)
	core.material_override = _core_mat
	_body.add_child(core)
	_arm_left = _build_arm(-1.0, mat)
	_arm_right = _build_arm(1.0, mat)
	# Pedregulhos do bowling (top_level: andam pelo mundo)
	for i: int in 2:
		var bst: SurfaceTool = SurfaceTool.new()
		bst.begin(Mesh.PRIMITIVE_TRIANGLES)
		CrabModel.gem(bst, Transform3D.IDENTITY, Vector3.ZERO, Basis.IDENTITY, [
			Vector3(-0.5, 0.7, 0.7), Vector3(0.0, 0.9, 0.9), Vector3(0.5, 0.7, 0.7)], 7, -0.9, 0.9, STONE, 0.06, 20 + i)
		var b: MeshInstance3D = MeshInstance3D.new()
		b.mesh = ToonKit.commit(bst)
		b.material_override = mat
		b.top_level = true
		b.visible = false
		add_child(b)
		_boulders.append(b)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(2.6, 4.6, 2.0)
	shape.shape = box
	shape.position = Vector3(0.0, 2.3, 0.0)
	add_child(shape)


func _build_arm(side: float, mat: Material) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.position = Vector3(1.6 * side, 3.1, 0.0)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyMesh.box(st, Vector3(0.15 * side, -0.7, 0.0), Vector3(0.7, 1.4, 0.7), Basis.IDENTITY, STONE)
	LowPolyMesh.box(st, Vector3(0.2 * side, -1.9, -0.1), Vector3(0.9, 1.0, 0.9), Basis.IDENTITY, STONE_DARK)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = ToonKit.commit(st)
	mi.material_override = mat
	pivot.add_child(mi)
	_body.add_child(pivot)
	return pivot


func _build_plates() -> void:
	for i: int in PLATE_COUNT:
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		LowPolyMesh.prism(st, Vector3(0.0, -0.05, 0.0), Vector3(0.0, 0.08, 0.0), 1.0, 0.9, 8, Color.WHITE)
		LowPolyMesh.prism(st, Vector3(0.0, 0.08, 0.0), Vector3(0.0, 0.12, 0.0), 0.5, 0.4, 6, Color.WHITE)
		var m: ShaderMaterial = ToonKit.vertex_material(true, true)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "Plate%d" % i
		mi.mesh = ToonKit.commit(st)
		mi.material_override = m
		mi.top_level = true
		add_child(mi)
		var p: Vector3 = plate_position(i)
		mi.global_position = Vector3(p.x, _ground_height(p, _surface_y) + 0.02, p.z)
		_plates.append(mi)
		_plate_mats.append(m)
	_refresh_plates()
