class_name EnemyBase
extends CharacterBody3D

## Base de todos os inimigos (grupo 'enemies', layer 4). Trata vida, dano com origem,
## atordoamento (stun), fuga (flee), flash de dano, partículas e procura do jogador.
## Subclasses implementam _enemy_physics(delta) e os ganchos _on_*.
##
## API usada pelas armas (Dev_Player):
##   take_damage(amount, from = Vector3.INF)  — from = origem do golpe (INF = desconhecida)
##   stun(seconds)                            — parado e sem atacar, com estrelas por cima
##   flee_from(origin, seconds)               — foge e depois vai-se embora
##   is_alive()
##
## Coop (#5, bloco F): a IA e a física só correm com autoridade de simulação (o host).
## Com `replicated = false` (hoje: solo e coop sem MultiplayerSpawner) cada peer simula os
## seus. O estado a replicar são campos simples: `state` (int, nas subclasses), `health`,
## `stunned` e `fleeing`; o dano entra sempre por take_damage().

signal died()
signal damaged(amount: float, health_left: float)

const GROUP: StringName = &"enemies"
const RETARGET_INTERVAL: float = 0.5
const FLASH_TIME: float = 0.12
const FLASH_COLOR: Color = Color(1.0, 0.25, 0.2)
## Flash quando o golpe foi amortecido (ex.: concha do ermitão).
const BLOCK_FLASH_COLOR: Color = Color(0.55, 0.65, 1.0)

@export var max_health: float = 50.0
## Cor das partículas ao morrer.
@export var death_color: Color = Color(0.95, 0.42, 0.12)
## Altura (local) onde aparecem as estrelas do atordoamento.
@export var stun_fx_height: float = 0.6

var health: float = 50.0
## Posto a true pelo MultiplayerSpawner (fase 3, #24): só o host simula; os clientes só
## recebem position/rotation/state/health/stunned/fleeing.
var replicated: bool = false

## Campos simples para o MultiplayerSynchronizer. No host refletem o estado real; num
## cliente replicado, escrever neles só liga/desliga o efeito visual.
var stunned: bool:
	get:
		return _stun_left > 0.0
	set(value):
		if value == (_stun_left > 0.0):
			return
		_stun_left = 0.25 if value else 0.0
		_set_stun_fx(value)
var fleeing: bool:
	get:
		return _flee_left > 0.0
	set(value):
		_flee_left = maxf(_flee_left, 0.25) if value else 0.0

var _gravity: float = 9.8
var _target: Node3D = null
var _retarget_timer: float = 0.0
var _stun_left: float = 0.0
var _flee_left: float = 0.0
var _flee_origin: Vector3 = Vector3.ZERO
var _dead: bool = false
var _flash_mats: Array[StandardMaterial3D] = []
var _flash_base_colors: Array[Color] = []
var _flash_tween: Tween = null
var _stun_fx: Node3D = null


func _ready() -> void:
	add_to_group(GROUP)
	health = max_health
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))


func _physics_process(delta: float) -> void:
	if _dead or not has_simulation_authority():
		return
	if _flee_left > 0.0:
		_flee_left -= delta
	if _stun_left > 0.0:
		_stun_left -= delta
		_animate_stun_fx(delta)
		_stunned_physics(delta)
		if _stun_left <= 0.0:
			_set_stun_fx(false)
			_on_stun_ended()
		return
	_enemy_physics(delta)


# ---------------------------------------------------------------------------
# API pública
# ---------------------------------------------------------------------------

## Verdadeiro onde a IA deve correr: sempre, salvo num cliente com o inimigo replicado.
func has_simulation_authority() -> bool:
	if not replicated or not is_inside_tree():
		return true
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()


func is_alive() -> bool:
	return not _dead and health > 0.0 and not is_queued_for_deletion()


func take_damage(amount: float, from: Vector3 = Vector3.INF) -> void:
	if amount <= 0.0 or not is_alive() or not _can_take_damage():
		return
	var final_amount: float = _modify_damage(amount, from)
	if final_amount <= 0.0:
		return
	health = clampf(health - final_amount, 0.0, max_health)
	_flash(BLOCK_FLASH_COLOR if final_amount < amount else FLASH_COLOR)
	damaged.emit(final_amount, health)
	if health <= 0.0:
		_die()


func stun(seconds: float) -> void:
	if seconds <= 0.0 or not is_alive() or not _can_be_stunned():
		return
	_stun_left = maxf(_stun_left, seconds)
	_set_stun_fx(true)
	_on_stunned()


func is_stunned() -> bool:
	return _stun_left > 0.0


func flee_from(origin: Vector3, seconds: float) -> void:
	if seconds <= 0.0 or not is_alive():
		return
	_flee_origin = origin
	_flee_left = maxf(_flee_left, seconds)
	_on_flee_started()


func is_fleeing() -> bool:
	return _flee_left > 0.0


# ---------------------------------------------------------------------------
# Ganchos para subclasses
# ---------------------------------------------------------------------------

## Lógica normal do inimigo (não corre enquanto atordoado).
func _enemy_physics(_delta: float) -> void:
	pass


## Enquanto atordoado: por omissão trava, aplica gravidade e não ataca.
func _stunned_physics(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()


func _can_take_damage() -> bool:
	return true


func _can_be_stunned() -> bool:
	return true


## Ajusta o dano recebido (armaduras, pontos fracos). from = Vector3.INF se desconhecido.
func _modify_damage(amount: float, _from: Vector3) -> float:
	return amount


func _on_stunned() -> void:
	pass


func _on_stun_ended() -> void:
	pass


func _on_flee_started() -> void:
	pass


## Chamado uma vez ao morrer, antes de libertar o nó. Por omissão: partículas + queue_free.
func _on_died() -> void:
	spawn_particles(global_position + Vector3.UP * 0.25, death_color, 28, 3.5)
	queue_free()


# ---------------------------------------------------------------------------
# Utilitários para subclasses
# ---------------------------------------------------------------------------

func _die() -> void:
	if _dead:
		return
	_dead = true
	_set_stun_fx(false)
	died.emit()
	_on_died()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0


## Altura do chão (layer 1) por baixo de (pos.x, pos.z); `fallback` se não houver chão.
## Para inimigos que andam debaixo de terra (sem colisão) em mapas com relevo.
func _ground_height(pos: Vector3, fallback: float) -> float:
	if not is_inside_tree():
		return fallback
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		Vector3(pos.x, pos.y + 6.0, pos.z), Vector3(pos.x, pos.y - 20.0, pos.z), 1, [get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return (hit["position"] as Vector3).y if not hit.is_empty() else fallback


## Jogadores (grupo 'player') a menos de `radius` m de `center` no plano.
func _players_within(center: Vector3, radius: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n: Node in get_tree().get_nodes_in_group("player"):
		if n is Node3D and n.has_method("take_damage"):
			var p: Vector3 = (n as Node3D).global_position
			if Vector2(p.x - center.x, p.z - center.z).length() <= radius:
				out.append(n as Node3D)
	return out


## Roda no eixo Y para que o -Z local aponte para dir, mais um desvio angular.
func _turn_towards(dir: Vector3, yaw_offset: float, turn_speed: float, delta: float) -> void:
	if dir.length_squared() < 0.0001:
		return
	var target_yaw: float = atan2(-dir.x, -dir.z) + yaw_offset
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(turn_speed * delta, 0.0, 1.0))


## Jogador mais próximo do grupo 'player' (reavaliado a cada RETARGET_INTERVAL).
func _update_target(delta: float) -> Node3D:
	_retarget_timer -= delta
	if _retarget_timer > 0.0 and is_instance_valid(_target):
		return _target
	_retarget_timer = RETARGET_INTERVAL

	var best: Node3D = null
	var best_dist: float = INF
	for n: Node in get_tree().get_nodes_in_group("player"):
		if n is Node3D and n.is_inside_tree():
			var d: float = global_position.distance_squared_to((n as Node3D).global_position)
			if d < best_dist:
				best_dist = d
				best = n as Node3D
	_target = best
	return _target


## Aplica dano ao jogador já escalado pela dificuldade (nº de jogadores). Usar sempre isto.
func _deal_damage(target: Node, amount: float) -> void:
	if target == null or not target.has_method("take_damage"):
		return
	var tree: SceneTree = get_tree() if is_inside_tree() else null
	target.call("take_damage", amount * DifficultyProfile.current(tree).enemy_damage_multiplier)


## Regista um material para o flash de dano (albedo_color é animado de volta à cor base).
func _register_flash_material(mat: StandardMaterial3D) -> void:
	if mat == null:
		return
	_flash_mats.append(mat)
	_flash_base_colors.append(mat.albedo_color)


func _flash(color: Color) -> void:
	if _flash_mats.is_empty() or not is_inside_tree():
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween().set_parallel(true)
	for i: int in range(_flash_mats.size()):
		var mat: StandardMaterial3D = _flash_mats[i]
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		_flash_tween.tween_property(mat, "albedo_color", _flash_base_colors[i], FLASH_TIME)
	_flash_tween.chain().tween_callback(_end_flash)


func _end_flash() -> void:
	for mat: StandardMaterial3D in _flash_mats:
		mat.emission_enabled = false


## Partículas one-shot no pai (sobrevivem ao inimigo).
func spawn_particles(pos: Vector3, color: Color, amount: int, speed: float) -> void:
	var parent: Node = get_parent()
	if parent == null or not is_inside_tree():
		return
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

	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.3).timeout.connect(p.queue_free)


# ---------------------------------------------------------------------------
# Efeito visual do atordoamento: estrelas amarelas a rodar por cima
# ---------------------------------------------------------------------------

func _set_stun_fx(on: bool) -> void:
	if not on:
		if _stun_fx != null:
			_stun_fx.queue_free()
			_stun_fx = null
		return
	if _stun_fx != null:
		return
	_stun_fx = Node3D.new()
	_stun_fx.name = "StunFx"
	_stun_fx.top_level = true
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k: int in range(4):
		var ang: float = TAU * float(k) / 4.0
		var c: Vector3 = Vector3(cos(ang), 0.0, sin(ang)) * 0.22
		# Estrela simples: dois losangos cruzados
		LowPolyMesh.box(st, c, Vector3(0.07, 0.07, 0.02), Basis(Vector3.FORWARD, PI * 0.25), Color(1.0, 0.9, 0.2))
		LowPolyMesh.box(st, c, Vector3(0.02, 0.07, 0.07), Basis(Vector3.RIGHT, PI * 0.25), Color(1.0, 0.9, 0.2))
	var mat: StandardMaterial3D = LowPolyMesh.make_material()
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.2)
	mat.emission_energy_multiplier = 0.6
	_stun_fx.add_child(LowPolyMesh.commit(st, "Stars", mat))
	add_child(_stun_fx)
	_animate_stun_fx(0.0)


func _animate_stun_fx(delta: float) -> void:
	if _stun_fx == null:
		return
	_stun_fx.global_position = global_position + Vector3.UP * stun_fx_height
	_stun_fx.rotation.y += delta * 5.0
