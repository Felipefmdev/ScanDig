class_name Snake
extends EnemyBase

## Cobra do Campo Antigo: rápida e frágil. Persegue, enrola-se (aviso) e dá um bote em linha
## reta. Quando é atordoada (rede/estilingue) e o atordoamento acaba, foge e some na erva.
## Também se vai embora quando a ameaça que a fez surgir baixa (como o caranguejo).

enum State {
	EMERGE,
	CHASE,
	COIL,
	STRIKE,
	RECOVER,
	FLEE,
	LEAVE,
}

const SEGMENTS: int = 7
const SEGMENT_SPACING: float = 0.16
const SCALE_GREEN: Color = Color(0.36, 0.52, 0.18)
const SCALE_DARK: Color = Color(0.2, 0.32, 0.1)
const BELLY: Color = Color(0.82, 0.78, 0.45)
const EYE: Color = Color(0.95, 0.75, 0.1)
const TONGUE: Color = Color(0.85, 0.12, 0.2)

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


func _ready() -> void:
	super._ready()
	stun_fx_height = 0.45
	_collision = get_node_or_null(^"CollisionShape3D") as CollisionShape3D
	_build_model()
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


func _enter_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
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
		_enter_state(State.COIL)
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
	if level <= spawn_level and is_alive() and state != State.LEAVE:
		_enter_state(State.LEAVE)


# ---------------------------------------------------------------------------
# Ganchos da EnemyBase
# ---------------------------------------------------------------------------

func _can_take_damage() -> bool:
	return state != State.EMERGE and state != State.LEAVE


func _can_be_stunned() -> bool:
	return state != State.EMERGE and state != State.LEAVE


func _on_stunned() -> void:
	_segments[0].position.y = 0.12
	_body_root.scale = Vector3.ONE


## Atordoada → assusta-se: foge do jogador e depois vai-se embora.
func _on_stun_ended() -> void:
	var target: Node3D = _update_target(1.0)
	var origin: Vector3 = target.global_position if target != null else global_position + global_transform.basis.z * -1.0
	flee_from(origin, flee_after_stun)


func _on_flee_started() -> void:
	if state == State.CHASE or state == State.COIL or state == State.STRIKE or state == State.RECOVER:
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
	var mat: StandardMaterial3D = LowPolyMesh.make_material()
	_register_flash_material(mat)
	for i: int in SEGMENTS:
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var r: float = 0.075 * (1.0 - float(i) / float(SEGMENTS) * 0.6)
		if i == 0:
			# Cabeça achatada com olhos amarelos e língua
			LowPolyMesh.box(st, Vector3(0, 0, -0.04), Vector3(0.17, 0.09, 0.2), Basis.IDENTITY, SCALE_DARK)
			LowPolyMesh.box(st, Vector3(0, -0.035, -0.04), Vector3(0.15, 0.03, 0.18), Basis.IDENTITY, BELLY)
			for side: float in [-1.0, 1.0]:
				LowPolyMesh.box(st, Vector3(0.07 * side, 0.03, -0.09), Vector3(0.04, 0.04, 0.04), Basis.IDENTITY, EYE)
			LowPolyMesh.prism(st, Vector3(0, -0.01, -0.14), Vector3(0, -0.01, -0.24), 0.012, 0.0, 3, TONGUE)
		else:
			var color: Color = SCALE_GREEN if i % 2 == 1 else SCALE_DARK
			LowPolyMesh.prism(st, Vector3(0, 0, -SEGMENT_SPACING * 0.55), Vector3(0, 0, SEGMENT_SPACING * 0.55), r, r * 0.9, 6, color)
		var seg: MeshInstance3D = LowPolyMesh.commit(st, "Segment%d" % i, mat)
		seg.position = Vector3(0, 0.12 if i == 0 else 0.07, float(i) * SEGMENT_SPACING - 0.45)
		_body_root.add_child(seg)
		_segments.append(seg)


func _animate_slither(delta: float, speed: float) -> void:
	_wiggle += delta * 12.0 * speed
	for i: int in _segments.size():
		_segments[i].position.x = sin(_wiggle - float(i) * 0.9) * 0.06 * float(i) / float(SEGMENTS)
