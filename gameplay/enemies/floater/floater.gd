class_name Floater
extends EnemyBase

## Criatura Flutuante (#44, #57): entidade cósmica flutuante da Cratera.
## Inspirada fielmente na referência visual criatura_flutuante.jpg:
##  - Cúpula rochosa em formato de cratera preenchida com cristais ciano/turquesa brilhantes;
##  - 3 olhos arregalados cómicos na face e tentáculos de cristal reluzente pendentes;
##  - Flutua acima do solo e carrega um pulso de gravidade (PULSE) telegrafado que
##    ergue e projeta o jogador violentamente pelo ar.

enum State { FLOAT, PULSE_WINDUP, PULSE, RECOVER, FLEE }

const ROCK_GREY: Color = Color(0.44, 0.40, 0.45)
const ROCK_DARK: Color = Color(0.32, 0.29, 0.34)
const CYAN_CRYSTAL: Color = Color(0.20, 0.90, 0.85)
const CYAN_GLOW: Color = Color(0.50, 0.98, 0.94)
const EYE_WHITE: Color = Color(0.96, 0.96, 0.96)
const EYE_PUPIL: Color = Color(0.10, 0.10, 0.12)

const HOVER_HEIGHT: float = 1.9
const PULSE_RADIUS: float = 3.2

@export var move_speed: float = 2.4
@export var turn_speed: float = 4.5
@export var pulse_damage: float = 14.0
@export var pulse_windup_time: float = 0.85
@export var pulse_range: float = 9.0
@export var recover_time: float = 0.9

var state: State = State.FLOAT
var net_pulse_pos: Vector3 = Vector3.ZERO:
	set(value):
		net_pulse_pos = value
		if not has_simulation_authority() and is_node_ready():
			_refresh_remote_warning()

var _state_time: float = 0.0
var _anim_time: float = 0.0
var _hit_done: bool = false
var _warning: GroundWarning = null

var _body: Node3D = null
var _tentacles: Array[Node3D] = []
var _crystal_top: MeshInstance3D = null
var _mat: ShaderMaterial = null
var _crystal_mat: ShaderMaterial = null


func _ready() -> void:
	super._ready()
	max_health = 70.0
	health = 70.0
	death_color = CYAN_CRYSTAL
	stun_fx_height = 1.6
	_build_model()
	_warning = GroundWarning.new()
	add_child(_warning)
	_enter_state(State.FLOAT)


func setup_network() -> void:
	super.setup_network()
	_add_synced_property(".:net_pulse_pos")


func _enemy_physics(delta: float) -> void:
	_state_time += delta
	_anim_time += delta

	match state:
		State.FLOAT:
			_process_float(delta)
		State.PULSE_WINDUP:
			_process_pulse_windup(delta)
		State.PULSE:
			_process_pulse(delta)
		State.RECOVER:
			_process_recover(delta)
		State.FLEE:
			_process_flee(delta)

	_animate(delta)


func _enter_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	_hit_done = false

	match state:
		State.FLOAT:
			_warning.hide_warning()
		State.PULSE_WINDUP:
			velocity.x = 0.0
			velocity.z = 0.0
			var target: Node3D = _update_target(0.0)
			net_pulse_pos = target.global_position if target != null else global_position
			_warning.show_circle(net_pulse_pos, PULSE_RADIUS)
			SFX.play_at(SFX.SPRAY, global_position, 3.0)
		State.PULSE:
			_warning.hide_warning()
		State.RECOVER:
			_warning.hide_warning()
			velocity = Vector3.ZERO
		State.FLEE:
			_warning.hide_warning()


func _process_float(delta: float) -> void:
	# Flutuação suave sobre o chão
	var target_y: float = _ground_height(global_position, global_position.y) + HOVER_HEIGHT
	var bobbing: float = sin(_anim_time * 3.5) * 0.15
	global_position.y = lerpf(global_position.y, target_y + bobbing, clampf(5.0 * delta, 0.0, 1.0))

	var target: Node3D = _update_target(delta)
	if target == null:
		velocity.x = move_toward(velocity.x, 0.0, delta * 3.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 3.0)
		move_and_slide()
		return

	var to: Vector3 = target.global_position - global_position
	to.y = 0.0
	var dist: float = to.length()
	var dir: Vector3 = to.normalized() if dist > 0.1 else Vector3.ZERO

	_turn_towards(dir, 0.0, turn_speed, delta)

	# Se estiver a alcance de tiro do pulso de gravidade
	if dist <= pulse_range and dist >= 2.0:
		_enter_state(State.PULSE_WINDUP)
		return

	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	move_and_slide()


func _process_pulse_windup(delta: float) -> void:
	_warning.pulse(delta)
	# Acompanha ligeiramente o jogador no solo
	var target: Node3D = _update_target(delta)
	if target != null:
		net_pulse_pos = net_pulse_pos.lerp(target.global_position, clampf(3.0 * delta, 0.0, 1.0))
		_warning.show_circle(net_pulse_pos, PULSE_RADIUS)

	if _state_time >= pulse_windup_time:
		_enter_state(State.PULSE)


func _process_pulse(delta: float) -> void:
	if not _hit_done and _state_time >= 0.08:
		_hit_done = true
		_execute_pulse()

	if _state_time >= 0.5:
		_enter_state(State.RECOVER)


func _execute_pulse() -> void:
	SFX.play_at(SFX.EMERGE_SAND, net_pulse_pos, 7.0)
	spawn_particles(net_pulse_pos + Vector3.UP * 0.2, CYAN_CRYSTAL, 30, 6.0)

	for p: Node3D in _players_within(net_pulse_pos, PULSE_RADIUS):
		_deal_damage(p, pulse_damage)
		# Pulso de anti-gravidade: eleva o jogador bem alto no ar!
		_knockback(p, Vector3.UP * 11.5 + (-transform.basis.z * 3.0), 0.2)


func _process_recover(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, delta * 5.0)
	velocity.z = move_toward(velocity.z, 0.0, delta * 5.0)
	move_and_slide()
	if _state_time >= recover_time:
		_enter_state(State.FLOAT)


func _process_flee(delta: float) -> void:
	var away: Vector3 = global_position - _flee_origin
	away.y = 0.0
	var dir: Vector3 = away.normalized() if away.length() > 0.1 else Vector3.FORWARD
	_turn_towards(dir, 0.0, turn_speed, delta)
	velocity.x = dir.x * move_speed * 1.3
	velocity.z = dir.z * move_speed * 1.3
	move_and_slide()
	if not is_fleeing():
		_enter_state(State.FLOAT)


func _on_flee_started() -> void:
	_enter_state(State.FLEE)


func _refresh_remote_warning() -> void:
	if _warning != null and state == State.PULSE_WINDUP:
		_warning.show_circle(net_pulse_pos, PULSE_RADIUS)


func _on_remote_state(new_state: int) -> void:
	state = new_state as State
	_state_time = 0.0
	if _warning != null:
		if state == State.PULSE_WINDUP:
			_refresh_remote_warning()
		else:
			_warning.hide_warning()


# ---------------------------------------------------------------------------
# Modelo 3D Low-Poly + ToonKit (referência: criatura_flutuante.jpg)
# ---------------------------------------------------------------------------

func _build_model() -> void:
	_mat = LowPolyMesh.make_material()
	_register_flash_material(_mat)

	_crystal_mat = LowPolyMesh.make_material()
	_crystal_mat.set_shader_parameter(&"emission_color", CYAN_CRYSTAL)
	_register_flash_material(_crystal_mat)

	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Cúpula / anel rochoso de cratera
	LowPolyMesh.prism(st, Vector3(0.0, 0.3, 0.0), Vector3(0.0, 0.8, 0.0), 0.58, 0.48, 8, ROCK_GREY)
	LowPolyMesh.box(st, Vector3(0.0, 0.45, 0.0), Vector3(1.15, 0.35, 1.15), Basis.IDENTITY, ROCK_DARK)

	# Espigões de cristal salientes nas laterais
	for i: int in 4:
		var ang: float = float(i) * (TAU / 4.0) + 0.4
		var side_pos: Vector3 = Vector3(cos(ang) * 0.55, 0.55, sin(ang) * 0.55)
		LowPolyMesh.prism(st, side_pos, side_pos * 1.45 + Vector3.UP * 0.15, 0.09, 0.0, 4, CYAN_CRYSTAL)

	# 3 Olhos cómicos agrupados na face (referência: criatura_flutuante.jpg)
	var eye_positions: Array[Vector3] = [
		Vector3(-0.16, 0.54, -0.52),
		Vector3(0.0, 0.68, -0.48),
		Vector3(0.18, 0.56, -0.50)
	]
	for ep: Vector3 in eye_positions:
		LowPolyMesh.box(st, ep, Vector3(0.14, 0.14, 0.08), Basis.IDENTITY, EYE_WHITE)
		LowPolyMesh.box(st, ep + Vector3(0.0, 0.0, -0.05), Vector3(0.06, 0.06, 0.02), Basis.IDENTITY, EYE_PUPIL)

	_body.add_child(LowPolyMesh.commit(st, "StoneCanopy", _mat))

	# Cristais ciano luminosos no topo oco da cratera
	var st_cr: SurfaceTool = SurfaceTool.new()
	st_cr.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k: int in 5:
		var a: float = float(k) * (TAU / 5.0)
		var c_base: Vector3 = Vector3(cos(a) * 0.22, 0.72, sin(a) * 0.22)
		var c_tip: Vector3 = c_base + Vector3(cos(a) * 0.15, 0.45, sin(a) * 0.15)
		LowPolyMesh.prism(st_cr, c_base, c_tip, 0.08, 0.0, 4, CYAN_GLOW)
	_crystal_top = LowPolyMesh.commit(st_cr, "CrystalTop", _crystal_mat)
	_body.add_child(_crystal_top)

	# Tentáculos / tentáculos pendentes com pontas de pedra (6 tentáculos)
	for t: int in 6:
		var ta: float = float(t) * (TAU / 6.0)
		_tentacles.append(_build_tentacle(cos(ta) * 0.35, sin(ta) * 0.35, "Tentacle%d" % t))

	# Collision Shape
	var cs: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.55
	cap.height = 1.4
	cs.shape = cap
	cs.position = Vector3(0.0, 0.4, 0.0)
	add_child(cs)


func _build_tentacle(x: float, z: float, t_name: String) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.name = t_name
	pivot.position = Vector3(x, 0.3, z)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Filamento de cristal luminoso
	LowPolyMesh.prism(st, Vector3(0.0, 0.0, 0.0), Vector3(0.0, -0.45, 0.0), 0.06, 0.04, 4, CYAN_CRYSTAL)
	# Ponta rochosa
	LowPolyMesh.prism(st, Vector3(0.0, -0.45, 0.0), Vector3(0.0, -0.75, 0.0), 0.04, 0.01, 3, ROCK_DARK)
	pivot.add_child(LowPolyMesh.commit(st, "TentacleMesh", _mat))
	_body.add_child(pivot)
	return pivot


func _animate(delta: float) -> void:
	if _body == null:
		return

	# Balanço dos tentáculos
	var sway: float = sin(_anim_time * 4.0)
	for i: int in range(_tentacles.size()):
		var t_node: Node3D = _tentacles[i]
		var ph: float = float(i) * 1.1
		t_node.rotation.x = sin(_anim_time * 5.0 + ph) * 0.25
		t_node.rotation.z = cos(_anim_time * 5.0 + ph) * 0.25

	if state == State.PULSE_WINDUP:
		# Gira rápido no próprio eixo carregando energia
		_body.rotation.y += 14.0 * delta
		_body.position.y = sin(_anim_time * 18.0) * 0.08
	elif state == State.PULSE:
		_body.position.y = 0.2
	elif state == State.RECOVER:
		_body.rotation.y = lerp_angle(_body.rotation.y, 0.0, clampf(6.0 * delta, 0.0, 1.0))
