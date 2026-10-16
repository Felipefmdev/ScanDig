class_name Walrus
extends EnemyBase

## Morsa (#43, #57): habitante massivo e resistente da Geleira Eterna.
## Inspirada fielmente na referência visual morsa.jpg:
##  - Corpo pesado e volumoso de couro castanho com pregas e barbatanas;
##  - Bigode farfalhante cor de palha, presas longas de marfim e olhos severos de banda desenhada;
##  - Resistente (camada grossa de gordura que amortece dano);
##  - Barrigada no gelo (SLAM) telegrafada com círculo que projeta os jogadores pelo ar.

enum State { WADDLE, SLAM_WINDUP, SLAM, RECOVER, FLEE }

const BLUBBER_BROWN: Color = Color("#6e4a34")
const BLUBBER_DARK: Color = Color("#4a3020")
const MOUSTACHE_TAN: Color = Color("#8a6a48")
const TUSK_IVORY: Color = Color("#e0d0a0")
const FLIPPER_COLOR: Color = Color("#5a3c2a")
const EYE_WHITE: Color = Color(0.96, 0.96, 0.96)
const EYE_PUPIL: Color = Color(0.10, 0.10, 0.12)
const ICE_SHARDS: Color = Color("#b8e0f0")

const ARMOR_FACTOR: float = 0.55
const SLAM_RADIUS: float = 3.4

@export var move_speed: float = 1.3
@export var turn_speed: float = 3.5
@export var slam_damage: float = 20.0
@export var slam_windup_time: float = 0.9
@export var recover_time: float = 1.2
@export var slam_cooldown: float = 2.5

var state: State = State.WADDLE
var net_slam_pos: Vector3 = Vector3.ZERO:
	set(value):
		net_slam_pos = value
		if not has_simulation_authority() and is_node_ready():
			_refresh_remote_slam_warning()

var _state_time: float = 0.0
var _cooldown_timer: float = 0.0
var _anim_time: float = 0.0
var _hit_done: bool = false
var _warning: GroundWarning = null

var _body: Node3D = null
var _flipper_left: Node3D = null
var _flipper_right: Node3D = null
var _head: Node3D = null
var _mat: ShaderMaterial = null


func _ready() -> void:
	super._ready()
	max_health = 110.0
	health = 110.0
	death_color = BLUBBER_BROWN
	stun_fx_height = 1.6
	_build_model()
	_warning = GroundWarning.new()
	add_child(_warning)
	_enter_state(State.WADDLE)


func setup_network() -> void:
	super.setup_network()
	_add_synced_property(".:net_slam_pos")


func _enemy_physics(delta: float) -> void:
	_state_time += delta
	_anim_time += delta
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta

	match state:
		State.WADDLE:
			_process_waddle(delta)
		State.SLAM_WINDUP:
			_process_slam_windup(delta)
		State.SLAM:
			_process_slam(delta)
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
		State.WADDLE:
			_warning.hide_warning()
		State.SLAM_WINDUP:
			velocity.x = 0.0
			velocity.z = 0.0
			net_slam_pos = global_position
			_warning.show_circle(global_position, SLAM_RADIUS)
		State.SLAM:
			_warning.hide_warning()
		State.RECOVER:
			_warning.hide_warning()
			velocity = Vector3.ZERO
			_cooldown_timer = slam_cooldown
		State.FLEE:
			_warning.hide_warning()


func _process_waddle(delta: float) -> void:
	_apply_gravity(delta)
	var target: Node3D = _update_target(delta)
	if target == null:
		velocity.x = move_toward(velocity.x, 0.0, delta * 4.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 4.0)
		move_and_slide()
		return

	var to: Vector3 = target.global_position - global_position
	to.y = 0.0
	var dist: float = to.length()
	var dir: Vector3 = to.normalized() if dist > 0.1 else Vector3.ZERO

	_turn_towards(dir, 0.0, turn_speed, delta)

	# Se estiver perto e fora de cooldown, prepara a barrigada!
	if dist <= SLAM_RADIUS * 0.9 and _cooldown_timer <= 0.0:
		_enter_state(State.SLAM_WINDUP)
		return

	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	move_and_slide()


func _process_slam_windup(delta: float) -> void:
	_apply_gravity(delta)
	_warning.pulse(delta)
	move_and_slide()
	if _state_time >= slam_windup_time:
		_enter_state(State.SLAM)


func _process_slam(delta: float) -> void:
	_apply_gravity(delta)
	move_and_slide()

	if not _hit_done and _state_time >= 0.1:
		_hit_done = true
		_execute_slam()

	if _state_time >= 0.5:
		_enter_state(State.RECOVER)


func _execute_slam() -> void:
	SFX.play_at(SFX.EMERGE_SAND, global_position, 6.0)
	spawn_particles(global_position + Vector3.DOWN * 0.1, ICE_SHARDS, 25, 5.0)

	for p: Node3D in _players_within(global_position, SLAM_RADIUS):
		_deal_damage(p, slam_damage)
		var away: Vector3 = p.global_position - global_position
		away.y = 0.0
		var push_dir: Vector3 = away.normalized() if away.length() > 0.1 else -transform.basis.z
		# Atira o jogador bem alto no ar estilo How to Fish
		_knockback(p, push_dir * 8.0 + Vector3.UP * 9.5, 0.25)


func _process_recover(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, delta * 6.0)
	velocity.z = move_toward(velocity.z, 0.0, delta * 6.0)
	move_and_slide()
	if _state_time >= recover_time:
		_enter_state(State.WADDLE)


func _process_flee(delta: float) -> void:
	_apply_gravity(delta)
	var away: Vector3 = global_position - _flee_origin
	away.y = 0.0
	var dir: Vector3 = away.normalized() if away.length() > 0.1 else Vector3.FORWARD
	_turn_towards(dir, 0.0, turn_speed, delta)
	velocity.x = dir.x * move_speed * 1.3
	velocity.z = dir.z * move_speed * 1.3
	move_and_slide()
	if not is_fleeing():
		_enter_state(State.WADDLE)


func _on_flee_started() -> void:
	_enter_state(State.FLEE)


func is_armor_open() -> bool:
	return is_stunned() or state == State.RECOVER


func _modify_damage(amount: float, _from: Vector3) -> float:
	if is_armor_open():
		return amount
	return amount * ARMOR_FACTOR


func _refresh_remote_slam_warning() -> void:
	if _warning != null and state == State.SLAM_WINDUP:
		_warning.show_circle(net_slam_pos, SLAM_RADIUS)


func _on_remote_state(new_state: int) -> void:
	state = new_state as State
	_state_time = 0.0
	if _warning != null:
		if state == State.SLAM_WINDUP:
			_refresh_remote_slam_warning()
		else:
			_warning.hide_warning()


# ---------------------------------------------------------------------------
# Modelo 3D Low-Poly + ToonKit (referência: morsa.jpg)
# ---------------------------------------------------------------------------

func _build_model() -> void:
	_mat = ToonKit.vertex_material(true, true)
	_register_flash_material(_mat)

	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Tronco maciço, curvado para trás
	LowPolyMesh.prism(st, Vector3(0.0, 0.4, 0.5), Vector3(0.0, 0.65, -0.2), 0.45, 0.52, 7, BLUBBER_BROWN)
	LowPolyMesh.prism(st, Vector3(0.0, 0.65, -0.2), Vector3(0.0, 0.95, -0.45), 0.52, 0.40, 7, BLUBBER_BROWN)

	# Pregas de pele e marcas no lombo
	LowPolyMesh.box(st, Vector3(0.0, 0.72, 0.1), Vector3(0.75, 0.22, 0.35), Basis.IDENTITY, BLUBBER_DARK)
	LowPolyMesh.box(st, Vector3(0.0, 0.88, -0.2), Vector3(0.68, 0.20, 0.30), Basis.IDENTITY, BLUBBER_DARK)

	# Cabeça robusta
	LowPolyMesh.prism(st, Vector3(0.0, 0.95, -0.45), Vector3(0.0, 1.05, -0.75), 0.40, 0.32, 6, BLUBBER_BROWN)

	# Focinho carnudo e queixo
	LowPolyMesh.box(st, Vector3(0.0, 0.92, -0.88), Vector3(0.42, 0.24, 0.22), Basis.IDENTITY, BLUBBER_DARK)

	# Bigode volumoso farfalhante (referência: morsa.jpg)
	LowPolyMesh.prism(st, Vector3(0.0, 0.94, -0.82), Vector3(0.0, 0.84, -0.98), 0.32, 0.24, 6, MOUSTACHE_TAN)
	LowPolyMesh.box(st, Vector3(0.0, 0.80, -0.92), Vector3(0.46, 0.18, 0.14), Basis.IDENTITY, MOUSTACHE_TAN)

	# Presas longas de marfim curvadas para baixo
	LowPolyMesh.prism(st, Vector3(-0.14, 0.84, -0.90), Vector3(-0.16, 0.25, -0.85), 0.06, 0.015, 4, TUSK_IVORY)
	LowPolyMesh.prism(st, Vector3(0.14, 0.84, -0.90), Vector3(0.16, 0.25, -0.85), 0.06, 0.015, 4, TUSK_IVORY)

	# Olhos severos cómicos "How to Fish"
	LowPolyMesh.box(st, Vector3(-0.18, 1.12, -0.72), Vector3(0.10, 0.10, 0.05), Basis.IDENTITY, EYE_WHITE)
	LowPolyMesh.box(st, Vector3(0.18, 1.12, -0.72), Vector3(0.10, 0.10, 0.05), Basis.IDENTITY, EYE_WHITE)
	LowPolyMesh.box(st, Vector3(-0.18, 1.12, -0.75), Vector3(0.05, 0.05, 0.02), Basis.IDENTITY, EYE_PUPIL)
	LowPolyMesh.box(st, Vector3(0.18, 1.12, -0.75), Vector3(0.05, 0.05, 0.02), Basis.IDENTITY, EYE_PUPIL)

	# Sobrancelhas franzidas de couro
	LowPolyMesh.box(st, Vector3(-0.18, 1.19, -0.74), Vector3(0.12, 0.04, 0.06), Basis(Vector3.FORWARD, 0.2), BLUBBER_DARK)
	LowPolyMesh.box(st, Vector3(0.18, 1.19, -0.74), Vector3(0.12, 0.04, 0.06), Basis(Vector3.FORWARD, -0.2), BLUBBER_DARK)

	# Barbatanas traseiras
	LowPolyMesh.box(st, Vector3(-0.25, 0.20, 0.8), Vector3(0.32, 0.08, 0.35), Basis(Vector3.UP, -0.3), FLIPPER_COLOR)
	LowPolyMesh.box(st, Vector3(0.25, 0.20, 0.8), Vector3(0.32, 0.08, 0.35), Basis(Vector3.UP, 0.3), FLIPPER_COLOR)

	# Placa de gelo partida onde se apoia (morsa.jpg)
	LowPolyMesh.prism(st, Vector3(0.0, -0.02, 0.1), Vector3(0.0, 0.12, 0.1), 0.95, 0.9, 7, ICE_SHARDS)
	for k: int in 3:
		var a: float = 1.2 + 1.4 * float(k)
		var chip: Vector3 = Vector3(sin(a) * 1.05, 0.06, 0.1 + cos(a) * 1.05)
		LowPolyMesh.box(st, chip, Vector3(0.14, 0.1, 0.12), Basis(Vector3.UP, a), ICE_SHARDS)
	_body.add_child(LowPolyMesh.commit(st, "MainMesh", _mat))

	# Barbatanas dianteiras articuladas
	_flipper_left = _build_flipper(-0.45, "FlipperL")
	_flipper_right = _build_flipper(0.45, "FlipperR")

	# Collision Shape
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(1.3, 1.2, 1.8)
	cs.shape = box
	cs.position = Vector3(0.0, 0.6, 0.0)
	add_child(cs)


func _build_flipper(x: float, flipper_name: String) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.name = flipper_name
	pivot.position = Vector3(x, 0.42, -0.15)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s: float = -1.0 if x < 0.0 else 1.0
	LowPolyMesh.box(st, Vector3(s * 0.18, -0.16, 0.0), Vector3(0.38, 0.08, 0.44), Basis(Vector3.FORWARD, s * -0.25), FLIPPER_COLOR)
	pivot.add_child(LowPolyMesh.commit(st, "FlipperMesh", _mat))
	_body.add_child(pivot)
	return pivot


func _animate(delta: float) -> void:
	if _body == null:
		return

	if state == State.WADDLE or state == State.FLEE:
		var speed: float = 6.0 if state == State.FLEE else 4.5
		var waddle: float = sin(_anim_time * speed) * 0.15
		_body.rotation.z = waddle
		_body.rotation.x = lerp_angle(_body.rotation.x, 0.0, clampf(8.0 * delta, 0.0, 1.0))
		_body.position.y = absf(sin(_anim_time * speed)) * 0.08
		if _flipper_left != null:
			_flipper_left.rotation.x = sin(_anim_time * speed) * 0.35
		if _flipper_right != null:
			_flipper_right.rotation.x = -sin(_anim_time * speed) * 0.35
	elif state == State.SLAM_WINDUP:
		# Ergue-se bem alto nas barbatanas preparando a barrigada
		_body.rotation.x = lerpf(_body.rotation.x, -0.65, clampf(6.0 * delta, 0.0, 1.0))
		_body.position.y = lerpf(_body.position.y, 0.35, clampf(6.0 * delta, 0.0, 1.0))
		_body.rotation.z = 0.0
		if _flipper_left != null:
			_flipper_left.rotation.z = -0.5
		if _flipper_right != null:
			_flipper_right.rotation.z = 0.5
	elif state == State.SLAM:
		# Esmaga com a barriga no gelo!
		_body.rotation.x = 0.18
		_body.position.y = -0.12
		if _flipper_left != null:
			_flipper_left.rotation.z = -0.8
		if _flipper_right != null:
			_flipper_right.rotation.z = 0.8
	elif state == State.RECOVER:
		# Respira ofegante
		_body.rotation.x = lerp_angle(_body.rotation.x, 0.0, clampf(4.0 * delta, 0.0, 1.0))
		_body.position.y = lerpf(_body.position.y, 0.0, clampf(4.0 * delta, 0.0, 1.0))
		_body.rotation.z = sin(_anim_time * 8.0) * 0.06
