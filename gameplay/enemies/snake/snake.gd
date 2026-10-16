class_name Snake
extends EnemyBase

## Cobra do Campo Antigo: rápida e frágil. Persegue, enrola-se (aviso) e dá um bote em linha
## reta. Quando é atordoada (rede/estilingue) e o atordoamento acaba, foge e some na erva.
## Também se vai embora quando a ameaça que a fez surgir baixa (como o caranguejo).
## #57: de meia distância, um ataque em cada dois é a MOLA: encolhe-se toda (círculo onde vai
## cair), salta em arco e, se cair em cima do jogador, ENROLA-SE nele (Player.apply_snare:
## anda a 25 %, abanar as teclas solta-o). Quando o jogador se solta, a cobra é atirada e fica tonta.

enum State {
	EMERGE,
	CHASE,
	COIL,
	STRIKE,
	RECOVER,
	FLEE,
	LEAVE,
	SPRING_COIL,
	SPRING,
	WRAP,
}

const SPRING_COIL_TIME: float = 0.8
const SPRING_AIR_TIME: float = 0.6
const SPRING_HEIGHT: float = 2.4
const SPRING_MIN_DIST: float = 2.6
const SPRING_MAX_DIST: float = 6.5
const WRAP_RADIUS: float = 1.1
const WRAP_TIME: float = 3.0
## Distância do jogador ao nó a partir da qual a cobra é sacudida (ele soltou-se).
const WRAP_BREAK: float = 1.3

const SEGMENTS: int = 7
const SEGMENT_SPACING: float = 0.16
const SCALE_GREEN: Color = Color(0.44, 0.48, 0.20)
const SCALE_DARK: Color = Color(0.18, 0.16, 0.12)
const BELLY: Color = Color(0.88, 0.85, 0.65)
const EYE: Color = Color(0.98, 0.98, 0.98)
const TONGUE: Color = Color(0.88, 0.12, 0.18)

@export var move_speed: float = 3.0
@export var turn_speed: float = 7.0
@export var bite_damage: float = 8.0
## Distância a que começa o bote.
@export var strike_range: float = 2.2
@export var strike_speed: float = 9.0
@export var strike_length: float = 2.4
@export var coil_time: float = 0.45
@export var recover_time: float = 0.8
@export var emerge_time: float = 0.5
@export var leave_time: float = 0.6
## Raio do corpo para acertar no jogador durante o bote.
@export var bite_radius: float = 0.9
## Segundos de fuga quando o atordoamento acaba.
@export var flee_after_stun: float = 4.0
@export var flee_speed_multiplier: float = 1.5
## Nível de ameaça que a fez surgir (0 = ambiente). Ao limpar este nível vai-se embora.
@export var spawn_level: int = 1

var state: State = State.EMERGE

var _state_time: float = 0.0
var _strike_dir: Vector3 = Vector3.FORWARD
var _strike_start: Vector3 = Vector3.ZERO
var _bit: bool = false
var _wiggle: float = 0.0
var _body_root: Node3D = null
var _segments: Array[Node3D] = []
var _collision: CollisionShape3D = null
var _strikes: int = 0
var _spring_from: Vector3 = Vector3.ZERO
var _spring_to: Vector3 = Vector3.ZERO
var _wrapped: Node3D = null
var _wrap_bite: float = 0.0
var _warning: GroundWarning = null


func _ready() -> void:
	super._ready()
	stun_fx_height = 0.45
	_collision = get_node_or_null(^"CollisionShape3D") as CollisionShape3D
	_build_model()
	_warning = GroundWarning.new()
	add_child(_warning)
	if DisturbanceMeter.instance != null:
		DisturbanceMeter.instance.threshold_cleared.connect(_on_threshold_cleared)
	_enter_state(State.EMERGE)


func _enemy_physics(delta: float) -> void:
	_state_time += delta
	match state:
		State.EMERGE:
			_process_emerge()
		State.CHASE:
			_process_chase(delta)
		State.COIL:
			_process_coil(delta)
		State.STRIKE:
			_process_strike(delta)
		State.RECOVER:
			_process_recover(delta)
		State.FLEE:
			_process_flee(delta)
		State.LEAVE:
			_process_leave()
		State.SPRING_COIL:
			_process_spring_coil(delta)
		State.SPRING:
			_process_spring()
		State.WRAP:
			_process_wrap(delta)


func _enter_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	if _warning != null:
		_warning.hide_warning()
	match new_state:
		State.EMERGE, State.LEAVE:
			velocity = Vector3.ZERO
			if _collision != null:
				_collision.disabled = true
		State.COIL:
			velocity = Vector3.ZERO
			var target: Node3D = _update_target(1.0)
			var to_t: Vector3 = (target.global_position - global_position) if target != null else -global_transform.basis.z
			to_t.y = 0.0
			_strike_dir = to_t.normalized() if to_t.length_squared() > 0.01 else -global_transform.basis.z
		State.STRIKE:
			_strike_start = global_position
			_bit = false
		State.SPRING_COIL:
			velocity = Vector3.ZERO
			_warning.show_circle(_spring_to, WRAP_RADIUS)
		State.SPRING:
			_spring_from = global_position
			if _collision != null:
				_collision.disabled = true
		State.WRAP:
			velocity = Vector3.ZERO
			_wrap_bite = 0.6
			if _collision != null:
				_collision.disabled = true
		_:
			if _collision != null:
				_collision.disabled = false


# ---------------------------------------------------------------------------
# Estados
# ---------------------------------------------------------------------------

func _process_emerge() -> void:
	var t: float = clampf(_state_time / emerge_time, 0.0, 1.0)
	_body_root.scale = Vector3.ONE * maxf(t, 0.05)
	if t >= 1.0:
		_enter_state(State.FLEE if is_fleeing() else State.CHASE)


func _process_chase(delta: float) -> void:
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
	if dist <= strike_range:
		_strikes += 1
		_enter_state(State.COIL)
		return
	if _strikes % 2 == 1 and dist >= SPRING_MIN_DIST and dist <= SPRING_MAX_DIST and is_on_floor():
		_strikes += 1
		start_spring(target.global_position)
		return
	var dir: Vector3 = to_t / dist if dist > 0.001 else Vector3.ZERO
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	move_and_slide()
	_turn_towards(dir, 0.0, turn_speed, delta)
	_animate_slither(delta, 1.0)


## Aviso: enrola-se e levanta a cabeça antes do bote.
func _process_coil(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()
	_turn_towards(_strike_dir, 0.0, turn_speed * 2.0, delta)
	var t: float = clampf(_state_time / coil_time, 0.0, 1.0)
	_body_root.scale = Vector3(1.0, 1.0, lerpf(1.0, 0.7, t))
	_segments[0].position.y = 0.12 + 0.18 * t
	if _state_time >= coil_time:
		_body_root.scale = Vector3.ONE
		_enter_state(State.STRIKE)


func _process_strike(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = _strike_dir.x * strike_speed
	velocity.z = _strike_dir.z * strike_speed
	move_and_slide()
	if not _bit:
		var hits: Array[Node3D] = _players_within(global_position - global_transform.basis.z * 0.4, bite_radius)
		if not hits.is_empty():
			_bit = true
			SFX.play_at(SFX.CRAB_PINCH, global_position, 0.0, 0.2)
			for p: Node3D in hits:
				_deal_damage(p, bite_damage)
	var travelled: float = Vector2(global_position.x - _strike_start.x, global_position.z - _strike_start.z).length()
	if travelled >= strike_length or _bit or (is_on_wall() and _state_time > 0.1):
		_segments[0].position.y = 0.12
		_enter_state(State.RECOVER)


## Mola (#57) para o ponto dado (público para testes/bot).
func start_spring(at: Vector3) -> void:
	_spring_to = Vector3(at.x, _ground_height(at, global_position.y), at.z)
	var to: Vector3 = _spring_to - global_position
	to.y = 0.0
	if to.length_squared() > 0.01:
		_strike_dir = to.normalized()
	_enter_state(State.SPRING_COIL)


## Encolhe-se como uma mola (achata e treme) virada para o ponto.
func _process_spring_coil(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()
	_turn_towards(_strike_dir, 0.0, turn_speed * 2.0, delta)
	_warning.pulse(delta)
	var t: float = clampf(_state_time / SPRING_COIL_TIME, 0.0, 1.0)
	_body_root.scale = Vector3(1.0 + 0.3 * t, 1.0 - 0.45 * t, 1.0 - 0.5 * t)
	_body_root.position.x = sin(_state_time * 70.0) * 0.02 * t
	if _state_time >= SPRING_COIL_TIME:
		_body_root.position.x = 0.0
		_body_root.scale = Vector3.ONE
		_enter_state(State.SPRING)


## Salto em arco, esticada como uma mola solta.
func _process_spring() -> void:
	var t: float = clampf(_state_time / SPRING_AIR_TIME, 0.0, 1.0)
	var p: Vector3 = _spring_from.lerp(_spring_to, t)
	p.y += sin(t * PI) * SPRING_HEIGHT
	global_position = p
	_body_root.scale = Vector3(0.8, 0.8, 1.0 + sin(t * PI) * 0.6)
	_body_root.rotation.x = lerpf(0.6, -0.6, t)
	if t < 1.0:
		return
	_body_root.scale = Vector3.ONE
	_body_root.rotation.x = 0.0
	for p2: Node3D in _players_within(_spring_to, WRAP_RADIUS):
		_wrapped = p2
		_player_effect(p2, &"apply_snare", [WRAP_TIME])
		_deal_damage(p2, bite_damage * 0.5)
		SFX.play_at(SFX.CRAB_PINCH, global_position, 0.0, 0.2)
		_enter_state(State.WRAP)
		return
	_enter_state(State.RECOVER)


## Enrolada no jogador: roda à volta das pernas dele e morde de vez em quando. Se ele se
## afastar (soltou-se a abanar) é sacudida e fica tonta.
func _process_wrap(delta: float) -> void:
	if _wrapped == null or not is_instance_valid(_wrapped) or _state_time >= WRAP_TIME:
		_release_wrap(false)
		return
	var feet: Vector3 = _wrapped.global_position
	var d: Vector3 = feet - global_position
	d.y = 0.0
	if d.length() > WRAP_BREAK:
		_release_wrap(true)
		return
	# Segue-o devagar (ele anda a 25 %): quem abana as teclas solta-se e afasta-se.
	global_position = global_position.lerp(Vector3(feet.x, feet.y + 0.35, feet.z), clampf(2.5 * delta, 0.0, 1.0))
	_body_root.rotation.y += delta * 9.0
	_wiggle += delta * 20.0
	for i: int in _segments.size():
		var a: float = float(i) / float(_segments.size()) * TAU
		_segments[i].position = Vector3(cos(a + _wiggle * 0.2) * 0.32, 0.12 + float(i) * 0.06, sin(a + _wiggle * 0.2) * 0.32)
	_wrap_bite -= delta
	if _wrap_bite <= 0.0:
		_wrap_bite = 1.0
		_deal_damage(_wrapped, bite_damage * 0.25)


func _release_wrap(flung: bool) -> void:
	var from: Vector3 = _wrapped.global_position if _wrapped != null and is_instance_valid(_wrapped) else global_position
	_wrapped = null
	_reset_segments()
	_body_root.rotation.y = 0.0
	var away: Vector3 = global_position - from
	away.y = 0.0
	away = away.normalized() if away.length_squared() > 0.01 else -global_transform.basis.z
	global_position = Vector3(global_position.x, _ground_height(global_position, global_position.y - 0.35), global_position.z)
	_enter_state(State.RECOVER)
	if flung:
		velocity = away * 6.0 + Vector3.UP * 4.0
		spawn_particles(global_position, SCALE_GREEN, 10, 3.0)
		stun(1.5)


func _reset_segments() -> void:
	for i: int in _segments.size():
		_segments[i].position = Vector3(0, 0.12 if i == 0 else 0.07, float(i) * SEGMENT_SPACING - 0.45)


func is_wrapping() -> bool:
	return state == State.WRAP


func _process_recover(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, strike_speed * 3.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, strike_speed * 3.0 * delta)
	move_and_slide()
	if _state_time >= recover_time:
		_enter_state(State.FLEE if is_fleeing() else State.CHASE)


func _process_flee(delta: float) -> void:
	_apply_gravity(delta)
	if not is_fleeing():
		_enter_state(State.LEAVE)
		return
	var away: Vector3 = global_position - _flee_origin
	away.y = 0.0
	if away.length_squared() < 0.0001:
		away = global_transform.basis.z
	var dir: Vector3 = away.normalized()
	velocity.x = dir.x * move_speed * flee_speed_multiplier
	velocity.z = dir.z * move_speed * flee_speed_multiplier
	move_and_slide()
	_turn_towards(dir, 0.0, turn_speed, delta)
	_animate_slither(delta, 1.6)


## Some na erva: encolhe e liberta o nó.
func _process_leave() -> void:
	var t: float = clampf(_state_time / leave_time, 0.0, 1.0)
	_body_root.scale = Vector3.ONE * maxf(1.0 - t, 0.05)
	if t >= 1.0:
		queue_free()


func _on_threshold_cleared(level: int) -> void:
	if not has_simulation_authority():
		return
	if level <= spawn_level and is_alive() and state != State.LEAVE:
		_enter_state(State.LEAVE)


# ---------------------------------------------------------------------------
# Ganchos da EnemyBase
# ---------------------------------------------------------------------------

func _can_take_damage() -> bool:
	return state != State.EMERGE and state != State.LEAVE


func _can_be_stunned() -> bool:
	return state != State.EMERGE and state != State.LEAVE and state != State.SPRING


## Atordoada: deixa-se ir com o sacudidela em vez de travar a seco.
func _stunned_physics(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
	move_and_slide()


## Cliente: colisão e cabeça levantada no bote (o resto chega pelo synchronizer).
func _on_remote_state(new_state: int) -> void:
	if _collision != null:
		_collision.disabled = new_state == State.EMERGE or new_state == State.LEAVE
	_segments[0].position.y = 0.3 if new_state == State.COIL else 0.12
	_body_root.visible = new_state != State.LEAVE
	_body_root.scale = Vector3(1.3, 0.55, 0.5) if new_state == State.SPRING_COIL else Vector3.ONE
	if new_state != State.WRAP:
		_reset_segments()
		_body_root.rotation.y = 0.0


func _on_stunned() -> void:
	if state == State.WRAP:
		_release_wrap(false)
	_segments[0].position.y = 0.12
	_body_root.scale = Vector3.ONE


## Atordoada → assusta-se: foge do jogador e depois vai-se embora.
func _on_stun_ended() -> void:
	var target: Node3D = _update_target(1.0)
	var origin: Vector3 = target.global_position if target != null else global_position + global_transform.basis.z * -1.0
	flee_from(origin, flee_after_stun)


func _on_flee_started() -> void:
	if state == State.WRAP:
		_release_wrap(false)
	if state in [State.CHASE, State.COIL, State.STRIKE, State.RECOVER, State.SPRING_COIL]:
		_segments[0].position.y = 0.12
		_body_root.scale = Vector3.ONE
		_enter_state(State.FLEE)


# ---------------------------------------------------------------------------
# Modelo low-poly: segmentos que ondulam (cabeça = segmento 0, à frente em -Z)
# ---------------------------------------------------------------------------

func _build_model() -> void:
	_body_root = get_node_or_null(^"BodyRoot") as Node3D
	if _body_root == null:
		_body_root = Node3D.new()
		_body_root.name = "BodyRoot"
		add_child(_body_root)
	var mat: ShaderMaterial = ToonKit.vertex_material(true, true)
	_register_flash_material(mat)
	for i: int in SEGMENTS:
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var r: float = 0.095 * (1.0 - float(i) / float(SEGMENTS) * 0.55)
		if i == 0:
			# Cabeça triangular/diamante de víbora (cobra.jpg)
			LowPolyMesh.prism(st, Vector3(0.0, 0.02, 0.06), Vector3(0.0, 0.02, -0.16), 0.13, 0.08, 6, SCALE_GREEN)
			LowPolyMesh.prism(st, Vector3(0.0, 0.01, -0.12), Vector3(0.0, -0.01, -0.25), 0.08, 0.04, 5, SCALE_GREEN)
			# Padrão escuro no topo da cabeça
			LowPolyMesh.box(st, Vector3(0.0, 0.045, -0.05), Vector3(0.08, 0.015, 0.08), Basis(Vector3.UP, PI * 0.25), SCALE_DARK)
			# Mandíbula inferior e ventre creme
			LowPolyMesh.box(st, Vector3(0.0, -0.035, -0.08), Vector3(0.14, 0.03, 0.18), Basis(Vector3.RIGHT, 0.12), BELLY)
			LowPolyMesh.box(st, Vector3(0.0, -0.01, -0.10), Vector3(0.10, 0.02, 0.14), Basis.IDENTITY, Color(0.52, 0.12, 0.16)) # interior da boca
			# Presas brancas afiadas (cobra.jpg)
			for side: float in [-1.0, 1.0]:
				LowPolyMesh.prism(st, Vector3(0.05 * side, -0.005, -0.16), Vector3(0.05 * side, -0.055, -0.16), 0.015, 0.0, 3, Color(0.98, 0.98, 0.98))
			# Língua bifurcada vermelha longa curvada (cobra.jpg)
			LowPolyMesh.box(st, Vector3(0.0, -0.02, -0.22), Vector3(0.025, 0.008, 0.10), Basis(Vector3.RIGHT, -0.2), TONGUE)
			LowPolyMesh.box(st, Vector3(-0.02, -0.045, -0.28), Vector3(0.012, 0.006, 0.06), Basis(Vector3.UP, 0.4), TONGUE)
			LowPolyMesh.box(st, Vector3(0.02, -0.045, -0.28), Vector3(0.012, 0.006, 0.06), Basis(Vector3.UP, -0.4), TONGUE)
			# Olhos arregalados cómicos (cobra.jpg)
			for side: float in [-1.0, 1.0]:
				LowPolyMesh.box(st, Vector3(0.09 * side, 0.065, -0.10), Vector3(0.065, 0.065, 0.065), Basis.IDENTITY, Color(0.98, 0.98, 0.98))
				LowPolyMesh.box(st, Vector3(0.115 * side, 0.065, -0.11), Vector3(0.025, 0.035, 0.035), Basis.IDENTITY, Color(0.08, 0.08, 0.10))
				LowPolyMesh.box(st, Vector3(0.085 * side, 0.10, -0.10), Vector3(0.055, 0.015, 0.06), Basis(Vector3.FORWARD, 0.25 * side), SCALE_DARK)
		else:
			# Segmentos com dorso verde, ventre creme e losangos escuros (cobra.jpg)
			LowPolyMesh.prism(st, Vector3(0, 0, -SEGMENT_SPACING * 0.55), Vector3(0, 0, SEGMENT_SPACING * 0.55), r, r * 0.92, 6, SCALE_GREEN)
			# Ventre creme
			LowPolyMesh.box(st, Vector3(0.0, -r * 0.72, 0.0), Vector3(r * 1.35, r * 0.4, SEGMENT_SPACING * 0.95), Basis.IDENTITY, BELLY)
			# Padrão losangular escuro nas costas e flancos
			LowPolyMesh.box(st, Vector3(0.0, r * 0.85, 0.0), Vector3(r * 0.95, r * 0.22, r * 0.95), Basis(Vector3.UP, PI * 0.25), SCALE_DARK)
			for side: float in [-1.0, 1.0]:
				LowPolyMesh.box(st, Vector3(r * 0.85 * side, 0.0, 0.0), Vector3(r * 0.18, r * 0.75, r * 0.75), Basis(Vector3.UP, PI * 0.25), SCALE_DARK)
			if i == SEGMENTS - 1:
				# Guizo na cauda
				LowPolyMesh.box(st, Vector3(0.0, 0.0, SEGMENT_SPACING * 0.55), Vector3(0.045, 0.045, 0.07), Basis.IDENTITY, Color(0.82, 0.72, 0.45))
				LowPolyMesh.box(st, Vector3(0.0, 0.0, SEGMENT_SPACING * 0.65), Vector3(0.035, 0.035, 0.05), Basis.IDENTITY, Color(0.68, 0.58, 0.35))
		var seg: MeshInstance3D = LowPolyMesh.commit(st, "Segment%d" % i, mat)
		var py: float = 0.20 if i == 0 else (0.15 if i == 1 else (0.10 if i == 2 else 0.07))
		var pz: float = -0.45 + float(i) * SEGMENT_SPACING
		seg.position = Vector3(0, py, pz)
		_body_root.add_child(seg)
		_segments.append(seg)


## Cliente: o corpo ondula conforme a velocidade replicada.
func _animate_remote(delta: float, speed: float) -> void:
	if speed > 0.1:
		_animate_slither(delta, clampf(speed / move_speed, 0.5, 2.0))


func _animate_slither(delta: float, speed: float) -> void:
	_wiggle += delta * 12.0 * speed
	for i: int in _segments.size():
		_segments[i].position.x = sin(_wiggle - float(i) * 0.9) * 0.06 * float(i) / float(SEGMENTS)

