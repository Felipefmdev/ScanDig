class_name Crab
extends EnemyBase

## Primeiro inimigo do "subsolo acorda": sai da areia quando a ameaça sobe,
## persegue o jogador de lado, belisca e volta a enterrar-se quando a ameaça baixa.
## Com flee_from (repelente) foge da origem e depois enterra-se.
## #57: de vez em quando entra em CORRIDA DE LADO frenética (faixa marcada, patas a tremer
## antes): atira o jogador e choca com os outros caranguejos (ficam ambos tontos).

enum State {
	EMERGE,
	CHASE,
	ATTACK,
	BURROW,
	FLEE,
	RUSH_TELEGRAPH,
	RUSH,
}

const RUSH_TELEGRAPH_TIME: float = 0.6
const RUSH_SPEED: float = 7.5
const RUSH_TIME: float = 1.3
const RUSH_WIDTH: float = 1.0

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
## Segundos até poder voltar a fazer a corrida de lado (aleatório).
var rush_cooldown: float = 0.0
var _rush_dir: Vector3 = Vector3.ZERO
var _rush_hit: Array[Node] = []
var _rush_warning: GroundWarning = null


func _ready() -> void:
	super._ready()
	_build_model()
	rush_cooldown = randf_range(4.0, 9.0)
	if walk_sideways:
		_rush_warning = GroundWarning.new()
		add_child(_rush_warning)

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
		State.RUSH_TELEGRAPH:
			_process_rush_telegraph(delta)
		State.RUSH:
			_process_rush(delta)


# ---------------------------------------------------------------------------
# Estados
# ---------------------------------------------------------------------------

func _enter_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	if _rush_warning != null:
		_rush_warning.hide_warning()
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
		State.RUSH_TELEGRAPH:
			collision_shape.disabled = false
			velocity = Vector3.ZERO
			_rush_warning.show_line(global_position, _rush_dir, RUSH_SPEED * RUSH_TIME, RUSH_WIDTH * 2.0)
		State.RUSH:
			collision_shape.disabled = false
			_rush_hit.clear()
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
	rush_cooldown -= delta
	if walk_sideways and rush_cooldown <= 0.0 and dist >= 2.5 and dist <= 9.0:
		start_rush(to_target / dist)
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


## Corrida de lado (#57) na direção dada (público para testes/bot).
func start_rush(dir: Vector3) -> void:
	if _rush_warning == null:
		return
	rush_cooldown = randf_range(7.0, 12.0)
	_rush_dir = Vector3(dir.x, 0.0, dir.z).normalized()
	_enter_state(State.RUSH_TELEGRAPH)


func _process_rush_telegraph(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()
	_turn_towards(_rush_dir, PI * 0.5, turn_speed, delta)
	_rush_warning.pulse(delta)
	# Patas a tremer e a carapaça a vibrar antes de arrancar
	_animate_scuttle(delta * 4.0)
	body_root.position.x = sin(_state_time * 60.0) * 0.03
	if _state_time >= RUSH_TELEGRAPH_TIME:
		body_root.position.x = 0.0
		_enter_state(State.RUSH)


func _process_rush(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = _rush_dir.x * RUSH_SPEED
	velocity.z = _rush_dir.z * RUSH_SPEED
	move_and_slide()
	_turn_towards(_rush_dir, PI * 0.5, turn_speed * 2.0, delta)
	_animate_scuttle(delta * 5.0)
	if int(_state_time * 12.0) % 3 == 0:
		_emit_sand_puff()
	for p: Node3D in _players_within(global_position, RUSH_WIDTH):
		if _rush_hit.has(p):
			continue
		_rush_hit.append(p)
		_deal_damage(p, attack_damage * 0.6)
		_knockback(p, _rush_dir * 8.0 + Vector3.UP * 5.0, 0.05)
	# Choca com outros caranguejos: ambos tontos e o outro sai disparado.
	var crashed: bool = false
	for n: Node in get_tree().get_nodes_in_group(GROUP):
		var other: Crab = n as Crab
		if other == null or other == self or _rush_hit.has(other) or not other.is_alive():
			continue
		var d: Vector3 = other.global_position - global_position
		if Vector2(d.x, d.z).length() <= RUSH_WIDTH + 0.7 and absf(d.y) < 1.5:
			_rush_hit.append(other)
			other.velocity += _rush_dir * 6.0 + Vector3.UP * 4.0
			other.stun(1.0)
			crashed = true
	if crashed or (is_on_wall() and _state_time > 0.15) or _state_time >= RUSH_TIME:
		if crashed or is_on_wall():
			SFX.play_at(SFX.SHELL_KNOCK, global_position, 2.0)
			_enter_state(State.CHASE)
			stun(1.0)
		else:
			_enter_state(State.CHASE)


## Tonto: deixa-se ir com o empurrão (choque de outro caranguejo) em vez de travar a seco.
func _stunned_physics(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
	move_and_slide()


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

