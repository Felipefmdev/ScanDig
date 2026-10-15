class_name Crab
extends EnemyBase

## Primeiro inimigo do "subsolo acorda": sai da areia quando a ameaça sobe,
## persegue o jogador de lado, belisca e volta a enterrar-se quando a ameaça baixa.
## Com flee_from (repelente) foge da origem e depois enterra-se.

enum State {
	EMERGE,
	CHASE,
	ATTACK,
	BURROW,
	FLEE,
}

@export var move_speed: float = 1.9
@export var turn_speed: float = 8.0
@export var attack_damage: float = 10.0
@export var attack_range: float = 1.2
@export var attack_cooldown: float = 1.6
@export var emerge_time: float = 0.8
@export var burrow_time: float = 0.9
## Profundidade de onde o caranguejo sai (abaixo da superfície).
@export var burrow_depth: float = 0.6
## Nível de ameaça que fez este caranguejo surgir. Ao limpar este nível (ou inferior), volta para a areia.
## 0 = surgiu por spawn ambiente: não volta para a areia com a descida da ameaça.
@export var spawn_level: int = 1
## Caranguejos normais andam de lado; o ermitão anda de frente (concha atrás).
@export var walk_sideways: bool = true
## Multiplicador de velocidade ao fugir.
@export var flee_speed_multiplier: float = 1.6

## Modelo low-poly partilhado (#37): carapaça, olhos em pedúnculos, pinça gigante, patas finas.
const CrabModel := preload("res://gameplay/enemies/crab/crab_model.gd")

@onready var body_root: Node3D = $BodyRoot
## Pinça gigante levantada (esquerda, como na referência) e pinça pequena (direita).
@onready var claw_left: Node3D = $BodyRoot/ClawLeft
@onready var claw_right: Node3D = $BodyRoot/ClawRight
@onready var legs_left: Node3D = $BodyRoot/LegsLeft
@onready var legs_right: Node3D = $BodyRoot/LegsRight
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

## Carapaça + boca + olhos (MeshInstance3D criada em _build_model).
var carapace: MeshInstance3D = null
## Material toon desta instância (partilhado pelas peças; o flash de dano anima-o).
var body_material: ShaderMaterial = null

var state: State = State.EMERGE

var _attack_timer: float = 0.0
var _state_time: float = 0.0
var _scuttle_time: float = 0.0
var _surface_y: float = 0.0


func _ready() -> void:
	super._ready()
	_build_model()

	if DisturbanceMeter.instance != null:
		DisturbanceMeter.instance.threshold_cleared.connect(_on_threshold_cleared)

	_enter_state(State.EMERGE)


func _enemy_physics(delta: float) -> void:
	_state_time += delta
	if _attack_timer > 0.0:
		_attack_timer -= delta

	match state:
		State.EMERGE:
			_process_emerge()
		State.CHASE:
			_process_chase(delta)
		State.ATTACK:
			_process_attack(delta)
		State.BURROW:
			_process_burrow()
		State.FLEE:
			_process_flee(delta)


# ---------------------------------------------------------------------------
# Estados
# ---------------------------------------------------------------------------

func _enter_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	match new_state:
		State.EMERGE:
			_surface_y = global_position.y
			global_position.y = _surface_y - burrow_depth
			collision_shape.disabled = true
			velocity = Vector3.ZERO
			_emit_sand_puff()
		State.BURROW:
			_surface_y = global_position.y
			collision_shape.disabled = true
			velocity = Vector3.ZERO
			_emit_sand_puff()
		_:
			collision_shape.disabled = false


func _process_emerge() -> void:
	var t: float = clampf(_state_time / emerge_time, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - t, 3.0)
	global_position.y = _surface_y - burrow_depth * (1.0 - eased)
	body_root.rotation.z = sin(_state_time * 30.0) * 0.12 * (1.0 - t)
	if t >= 1.0:
		body_root.rotation.z = 0.0
		_enter_state(State.FLEE if is_fleeing() else State.CHASE)


func _process_burrow() -> void:
	var t: float = clampf(_state_time / burrow_time, 0.0, 1.0)
	global_position.y = _surface_y - burrow_depth * t * t
	body_root.rotation.z = sin(_state_time * 30.0) * 0.12
	if t >= 1.0:
		queue_free()


func _process_chase(delta: float) -> void:
	var target: Node3D = _update_target(delta)
	_apply_gravity(delta)

	if target == null:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 4.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 4.0 * delta)
		move_and_slide()
		return

	var to_target: Vector3 = target.global_position - global_position
	to_target.y = 0.0
	var dist: float = to_target.length()

	if dist <= attack_range:
		_enter_state(State.ATTACK)
		return

	var dir: Vector3 = to_target / dist if dist > 0.001 else Vector3.ZERO
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	move_and_slide()

	# Caranguejo anda de lado: o corpo fica perpendicular à direção do movimento
	_turn_towards(dir, PI * 0.5 if walk_sideways else 0.0, turn_speed, delta)
	_animate_scuttle(delta)


func _process_attack(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, move_speed * 6.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, move_speed * 6.0 * delta)
	move_and_slide()

	if not is_instance_valid(_target):
		_target = null
		_enter_state(State.CHASE)
		return

	var to_target: Vector3 = _target.global_position - global_position
	to_target.y = 0.0
	var dist: float = to_target.length()
	if dist > attack_range * 1.25:
		_enter_state(State.CHASE)
		return

	# Vira as pinças de frente para o jogador
	if dist > 0.001:
		_turn_towards(to_target / dist, 0.0, turn_speed, delta)

	if _attack_timer <= 0.0:
		_attack_timer = attack_cooldown
		_pinch()


## Foge da origem do repelente; quando o tempo acaba, enterra-se.
func _process_flee(delta: float) -> void:
	_apply_gravity(delta)
	if not is_fleeing():
		_enter_state(State.BURROW)
		return
	var away: Vector3 = global_position - _flee_origin
	away.y = 0.0
	if away.length_squared() < 0.0001:
		away = -global_transform.basis.z
	var dir: Vector3 = away.normalized()
	velocity.x = dir.x * move_speed * flee_speed_multiplier
	velocity.z = dir.z * move_speed * flee_speed_multiplier
	move_and_slide()
	_turn_towards(dir, PI * 0.5 if walk_sideways else 0.0, turn_speed, delta)
	_animate_scuttle(delta * 1.4)


func _pinch() -> void:
	SFX.play_at(SFX.CRAB_PINCH, global_position)
	if _target != null and _target.has_method("take_damage"):
		_deal_damage(_target, attack_damage)

	# A pinça gigante desce para a frente; a pequena fecha para dentro
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(claw_left, "rotation:x", -0.9, 0.08)
	tween.tween_property(claw_right, "rotation:y", 0.6, 0.08)
	tween.chain().tween_property(claw_left, "rotation:x", 0.0, 0.22)
	tween.parallel().tween_property(claw_right, "rotation:y", 0.0, 0.18)


func _on_threshold_cleared(level: int) -> void:
	if not has_simulation_authority():
		return
	if level <= spawn_level and state != State.BURROW and is_alive():
		_enter_state(State.BURROW)


# ---------------------------------------------------------------------------
# Ganchos da EnemyBase
# ---------------------------------------------------------------------------

## Imune enquanto está debaixo da areia (a sair ou a entrar).
func _can_take_damage() -> bool:
	return state != State.EMERGE and state != State.BURROW


func _can_be_stunned() -> bool:
	return state != State.EMERGE and state != State.BURROW


## Cliente: sem colisão enquanto está debaixo da areia (o resto chega pelo synchronizer).
func _on_remote_state(new_state: int) -> void:
	collision_shape.disabled = new_state == State.EMERGE or new_state == State.BURROW


func _on_flee_started() -> void:
	if state == State.CHASE or state == State.ATTACK:
		_enter_state(State.FLEE)


func _on_stun_ended() -> void:
	# Depois da rede, volta a perseguir (ou continua a fugir se o repelente ainda durar)
	if state == State.ATTACK:
		_enter_state(State.CHASE)
	_attack_timer = maxf(_attack_timer, 0.4)


# ---------------------------------------------------------------------------
# Animação e efeitos
# ---------------------------------------------------------------------------

## Cliente: patas a mexer conforme a velocidade replicada.
func _animate_remote(delta: float, speed: float) -> void:
	if speed > 0.15:
		_animate_scuttle(delta * clampf(speed / move_speed, 0.5, 2.0))
	else:
		body_root.position.y = move_toward(body_root.position.y, 0.0, delta)
		body_root.rotation.z = move_toward(body_root.rotation.z, 0.0, delta)
		legs_left.rotation.z = move_toward(legs_left.rotation.z, 0.0, delta)
		legs_right.rotation.z = move_toward(legs_right.rotation.z, 0.0, delta)


func _animate_scuttle(delta: float) -> void:
	_scuttle_time += delta * 18.0
	body_root.position.y = absf(sin(_scuttle_time)) * 0.04
	body_root.rotation.z = sin(_scuttle_time) * 0.06
	# Patas em contratempo: um lado levanta enquanto o outro apoia
	legs_left.rotation.z = -maxf(sin(_scuttle_time), 0.0) * 0.35
	legs_right.rotation.z = maxf(-sin(_scuttle_time), 0.0) * 0.35
	claw_left.rotation.z = sin(_scuttle_time * 0.5) * 0.08


func _emit_sand_puff() -> void:
	SFX.play_at(SFX.EMERGE_SAND, global_position)
	spawn_particles(Vector3(global_position.x, _surface_y + 0.05, global_position.z), Color(0.85, 0.74, 0.5), 16, 2.0)


## Paleta do modelo (o Ermitão troca as cores).
func _palette() -> Dictionary:
	return CrabModel.PALETTE_CRAB


func _build_model() -> void:
	var m: Dictionary = CrabModel.meshes(_palette())
	body_material = CrabModel.make_material()
	_register_flash_material(body_material)
	carapace = _add_part(body_root, "Carapace", m["body"])
	_add_part(legs_left, "Mesh", m["legs_left"])
	_add_part(legs_right, "Mesh", m["legs_right"])
	_add_part(claw_left, "Mesh", m["claw_big"])
	_add_part(claw_right, "Mesh", m["claw_small"])


func _add_part(parent: Node3D, part_name: String, mesh: Mesh) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = part_name
	mi.mesh = mesh
	mi.material_override = body_material
	parent.add_child(mi)
	return mi
