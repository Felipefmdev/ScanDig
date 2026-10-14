class_name Crab
extends CharacterBody3D

## Primeiro inimigo do "subsolo acorda": sai da areia quando a ameaça sobe,
## persegue o jogador de lado, belisca e volta a enterrar-se quando a ameaça baixa.

signal died()

enum State {
	EMERGE,
	CHASE,
	ATTACK,
	BURROW,
}

@export var max_health: float = 50.0
@export var move_speed: float = 2.6
@export var turn_speed: float = 8.0
@export var attack_damage: float = 10.0
@export var attack_range: float = 1.2
@export var attack_cooldown: float = 1.2
@export var emerge_time: float = 0.8
@export var burrow_time: float = 0.9
## Profundidade de onde o caranguejo sai (abaixo da superfície).
@export var burrow_depth: float = 0.6
## Nível de ameaça que fez este caranguejo surgir. Ao limpar este nível (ou inferior), volta para a areia.
@export var spawn_level: int = 1

@onready var body_root: Node3D = $BodyRoot
@onready var carapace: CSGSphere3D = $BodyRoot/Carapace
@onready var claw_left: Node3D = $BodyRoot/ClawLeft
@onready var claw_right: Node3D = $BodyRoot/ClawRight
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

const RETARGET_INTERVAL: float = 0.5
const FLASH_TIME: float = 0.12
const FLASH_COLOR: Color = Color(1.0, 0.25, 0.2)

var health: float = 50.0
var state: State = State.EMERGE

var _gravity: float = 9.8
var _target: Node3D = null
var _retarget_timer: float = 0.0
var _attack_timer: float = 0.0
var _state_time: float = 0.0
var _scuttle_time: float = 0.0
var _surface_y: float = 0.0
var _carapace_mat: StandardMaterial3D = null
var _base_color: Color = Color.WHITE
var _flash_tween: Tween = null


func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))

	# Material próprio por instância para o flash não afetar outros caranguejos
	if carapace.material is StandardMaterial3D:
		_carapace_mat = (carapace.material as StandardMaterial3D).duplicate() as StandardMaterial3D
		carapace.material = _carapace_mat
		_base_color = _carapace_mat.albedo_color

	if DisturbanceMeter.instance != null:
		DisturbanceMeter.instance.threshold_cleared.connect(_on_threshold_cleared)

	_enter_state(State.EMERGE)


func _physics_process(delta: float) -> void:
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
		_enter_state(State.CHASE)


func _process_burrow() -> void:
	var t: float = clampf(_state_time / burrow_time, 0.0, 1.0)
	global_position.y = _surface_y - burrow_depth * t * t
	body_root.rotation.z = sin(_state_time * 30.0) * 0.12
	if t >= 1.0:
		queue_free()


func _process_chase(delta: float) -> void:
	_update_target(delta)
	_apply_gravity(delta)

	if _target == null:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 4.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * 4.0 * delta)
		move_and_slide()
		return

	var to_target: Vector3 = _target.global_position - global_position
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
	_turn_towards(dir, PI * 0.5, delta)
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
		_turn_towards(to_target / dist, 0.0, delta)

	if _attack_timer <= 0.0:
		_attack_timer = attack_cooldown
		_pinch()


func _pinch() -> void:
	if _target != null and _target.has_method("take_damage"):
		_target.call("take_damage", attack_damage)

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(claw_left, "rotation:y", -0.6, 0.08)
	tween.tween_property(claw_right, "rotation:y", 0.6, 0.08)
	tween.chain().tween_property(claw_left, "rotation:y", 0.0, 0.18)
	tween.parallel().tween_property(claw_right, "rotation:y", 0.0, 0.18)


func _on_threshold_cleared(level: int) -> void:
	if level <= spawn_level and state != State.BURROW and health > 0.0:
		_enter_state(State.BURROW)


# ---------------------------------------------------------------------------
# Movimento
# ---------------------------------------------------------------------------

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0


## Roda no eixo Y para que o -Z local aponte para dir, mais um desvio angular.
func _turn_towards(dir: Vector3, yaw_offset: float, delta: float) -> void:
	if dir.length_squared() < 0.0001:
		return
	var target_yaw: float = atan2(-dir.x, -dir.z) + yaw_offset
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(turn_speed * delta, 0.0, 1.0))


func _animate_scuttle(delta: float) -> void:
	_scuttle_time += delta * 18.0
	body_root.position.y = absf(sin(_scuttle_time)) * 0.04
	body_root.rotation.z = sin(_scuttle_time) * 0.06


func _update_target(delta: float) -> void:
	_retarget_timer -= delta
	if _retarget_timer > 0.0 and is_instance_valid(_target):
		return
	_retarget_timer = RETARGET_INTERVAL

	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	var best: Node3D = null
	var best_dist: float = INF
	for n: Node in players:
		if n is Node3D and n.is_inside_tree():
			var d: float = global_position.distance_squared_to((n as Node3D).global_position)
			if d < best_dist:
				best_dist = d
				best = n as Node3D
	_target = best


# ---------------------------------------------------------------------------
# Vida
# ---------------------------------------------------------------------------

func take_damage(amount: float) -> void:
	if amount <= 0.0 or health <= 0.0 or state == State.EMERGE or state == State.BURROW:
		return
	health = clampf(health - amount, 0.0, max_health)
	_flash()
	if health <= 0.0:
		_die()


func _flash() -> void:
	if _carapace_mat == null:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_carapace_mat.albedo_color = FLASH_COLOR
	_carapace_mat.emission_enabled = true
	_carapace_mat.emission = FLASH_COLOR
	_flash_tween = create_tween()
	_flash_tween.tween_property(_carapace_mat, "albedo_color", _base_color, FLASH_TIME)
	_flash_tween.tween_callback(func() -> void: _carapace_mat.emission_enabled = false)


func _die() -> void:
	died.emit()
	_spawn_death_particles()
	queue_free()


func _spawn_death_particles() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var particles: CPUParticles3D = _make_particles(Color(0.95, 0.42, 0.12), 28, 3.5)
	parent.add_child(particles)
	particles.global_position = global_position + Vector3.UP * 0.25
	particles.emitting = true
	get_tree().create_timer(particles.lifetime + 0.3).timeout.connect(particles.queue_free)


func _emit_sand_puff() -> void:
	var particles: CPUParticles3D = _make_particles(Color(0.85, 0.74, 0.5), 16, 2.0)
	var parent: Node = get_parent()
	if parent == null:
		return
	parent.add_child(particles)
	particles.global_position = Vector3(global_position.x, _surface_y + 0.05, global_position.z)
	particles.emitting = true
	get_tree().create_timer(particles.lifetime + 0.3).timeout.connect(particles.queue_free)


func _make_particles(color: Color, amount: int, speed: float) -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = 0.6
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = speed * 0.6
	p.initial_velocity_max = speed
	p.gravity = Vector3(0.0, -9.8, 0.0)

	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.05, 0.05, 0.05)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mesh.material = mat
	p.mesh = mesh
	return p
