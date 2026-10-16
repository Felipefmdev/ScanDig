class_name Crawler
extends EnemyBase

## Criatura Rastejante (#44, #57): predador subterrâneo da Cratera.
## Inspirada fielmente na referência visual criatura_rastejante.jpg:
##  - Carapaça esférica de geodo rochoso facetado com núcleo violeta/púrpura brilhante;
##  - Olho ciclópico esbugalhado saliente na fronte estilo "How to Fish";
##  - 6 patas pontiagudas articuladas de pedra;
##  - Avança muito rápido e enrola-se para saltar como mola (SPRING_JUMP) telegrafada,
##    mordendo e repelindo o jogador com solavanco.

enum State { EMERGE, CRAWL, BITE_WINDUP, SPRING_WINDUP, SPRING_JUMP, RECOVER, FLEE }

const STONE_BODY: Color = Color("#77737a")
const STONE_DARK: Color = Color("#4c4850")
const PURPLE_CORE: Color = Color("#b040ff")
const EYE_WHITE: Color = Color(0.96, 0.96, 0.96)
const EYE_PUPIL: Color = Color(0.10, 0.10, 0.12)
const EYE_RIM: Color = Color("#5a5660")

@export var move_speed: float = 3.5
@export var turn_speed: float = 7.0
@export var spring_speed: float = 11.0
@export var spring_damage: float = 15.0
@export var bite_damage: float = 9.0
@export var bite_windup_time: float = 0.35
@export var bite_cooldown_time: float = 1.6
@export var spring_windup_time: float = 0.6
@export var spring_range: float = 8.0
@export var bite_range: float = 1.6
@export var recover_time: float = 0.65
@export var emerge_time: float = 0.8

var state: State = State.EMERGE
var net_spring_dir: Vector3 = Vector3.FORWARD:
	set(value):
		net_spring_dir = value
		if not has_simulation_authority() and is_node_ready():
			_refresh_remote_warning()

var _state_time: float = 0.0
var _bite_cooldown: float = 0.0
var _surface_y: float = 0.0
var _anim_time: float = 0.0
var _hit_targets: Array[Node] = []
var _warning: GroundWarning = null

var _body: Node3D = null
var _legs: Array[Node3D] = []
var _core_mesh: MeshInstance3D = null
var _mat: ShaderMaterial = null
var _core_mat: ShaderMaterial = null


func _ready() -> void:
	super._ready()
	max_health = 60.0
	health = 60.0
	death_color = PURPLE_CORE
	stun_fx_height = 1.0
	_surface_y = global_position.y
	_build_model()
	_warning = GroundWarning.new()
	add_child(_warning)
	_enter_state(State.EMERGE)


func setup_network() -> void:
	super.setup_network()
	_add_synced_property(".:net_spring_dir")


func _enemy_physics(delta: float) -> void:
	_state_time += delta
	_anim_time += delta
	if _bite_cooldown > 0.0:
		_bite_cooldown -= delta

	match state:
		State.EMERGE:
			var t: float = clampf(_state_time / emerge_time, 0.0, 1.0)
			global_position.y = _surface_y - 1.2 * (1.0 - t)
			if t >= 1.0:
				_enter_state(State.CRAWL)
		State.CRAWL:
			_process_crawl(delta)
		State.BITE_WINDUP:
			_process_bite_windup(delta)
		State.SPRING_WINDUP:
			_process_spring_windup(delta)
		State.SPRING_JUMP:
			_process_spring_jump(delta)
		State.RECOVER:
			_process_recover(delta)
		State.FLEE:
			_process_flee(delta)

	_animate(delta)


func _enter_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	_hit_targets.clear()

	match state:
		State.EMERGE:
			global_position.y = _surface_y - 1.2
		State.CRAWL:
			_warning.hide_warning()
		State.BITE_WINDUP:
			velocity.x = 0.0
			velocity.z = 0.0
			var target: Node3D = _update_target(0.0)
			var to: Vector3 = (target.global_position - global_position) if target != null else -transform.basis.z
			to.y = 0.0
			var dir: Vector3 = to.normalized() if to.length() > 0.1 else -transform.basis.z
			_warning.show_circle(global_position + dir * 0.8, bite_range)
		State.SPRING_WINDUP:
			velocity.x = 0.0
			velocity.z = 0.0
			var target: Node3D = _update_target(0.0)
			if target != null:
				var to: Vector3 = target.global_position - global_position
				to.y = 0.0
				net_spring_dir = to.normalized() if to.length() > 0.1 else -transform.basis.z
			else:
				net_spring_dir = -transform.basis.z
			_warning.show_line(global_position, net_spring_dir, spring_range, 1.4)
		State.SPRING_JUMP:
			_warning.hide_warning()
			velocity = net_spring_dir * spring_speed + Vector3.UP * 4.2
			SFX.play_at(SFX.EMERGE_SAND, global_position, 3.0)
			spawn_particles(global_position, PURPLE_CORE, 12, 3.0)
		State.RECOVER:
			_warning.hide_warning()
			velocity = Vector3.ZERO
		State.FLEE:
			_warning.hide_warning()


func _process_crawl(delta: float) -> void:
	_apply_gravity(delta)
	var target: Node3D = _update_target(delta)
	if target == null:
		velocity.x = move_toward(velocity.x, 0.0, delta * 5.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 5.0)
		move_and_slide()
		return

	var to: Vector3 = target.global_position - global_position
	to.y = 0.0
	var dist: float = to.length()
	var dir: Vector3 = to.normalized() if dist > 0.1 else Vector3.ZERO

	_turn_towards(dir, 0.0, turn_speed, delta)

	if dist <= bite_range and _bite_cooldown <= 0.0:
		# Aviso telegrafado antes da mordida (#63)
		_enter_state(State.BITE_WINDUP)
	elif dist <= spring_range and dist > bite_range + 0.6:
		# Enrola-se para saltar como mola
		_enter_state(State.SPRING_WINDUP)
	else:
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed

	move_and_slide()


func _process_bite_windup(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, delta * 8.0)
	velocity.z = move_toward(velocity.z, 0.0, delta * 8.0)
	var target: Node3D = _update_target(delta)
	if target != null:
		var to: Vector3 = target.global_position - global_position
		to.y = 0.0
		var dir: Vector3 = to.normalized() if to.length() > 0.1 else -transform.basis.z
		_turn_towards(dir, 0.0, turn_speed * 1.5, delta)
	move_and_slide()
	_warning.pulse(delta)

	if _state_time >= bite_windup_time:
		_bite_cooldown = bite_cooldown_time
		if target != null and global_position.distance_to(target.global_position) <= bite_range + 0.6:
			var to: Vector3 = target.global_position - global_position
			to.y = 0.0
			var push_dir: Vector3 = to.normalized() if to.length() > 0.1 else -transform.basis.z
			_deal_damage(target, bite_damage)
			_knockback(target, push_dir * 7.5 + Vector3.UP * 3.5, 0.12)
			spawn_particles(target.global_position + Vector3.UP * 0.5, PURPLE_CORE, 8, 2.5)
		_enter_state(State.RECOVER)


func _process_spring_windup(delta: float) -> void:
	_apply_gravity(delta)
	_warning.pulse(delta)
	_turn_towards(net_spring_dir, 0.0, turn_speed * 1.5, delta)
	move_and_slide()
	if _state_time >= spring_windup_time:
		_enter_state(State.SPRING_JUMP)


func _process_spring_jump(delta: float) -> void:
	_apply_gravity(delta)
	move_and_slide()

	for p: Node3D in _all_players():
		if _hit_targets.has(p):
			continue
		var d: Vector3 = p.global_position - global_position
		d.y = 0.0
		if d.length() <= 1.5:
			_hit_targets.append(p)
			_deal_damage(p, spring_damage)
			_knockback(p, net_spring_dir * 10.0 + Vector3.UP * 4.0, 0.15)
			spawn_particles(p.global_position + Vector3.UP * 0.5, PURPLE_CORE, 16, 4.0)

	if is_on_floor() and _state_time > 0.2:
		_enter_state(State.RECOVER)


func _process_recover(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, delta * 8.0)
	velocity.z = move_toward(velocity.z, 0.0, delta * 8.0)
	move_and_slide()
	if _state_time >= recover_time:
		_enter_state(State.CRAWL)


func _process_flee(delta: float) -> void:
	_apply_gravity(delta)
	var away: Vector3 = global_position - _flee_origin
	away.y = 0.0
	var dir: Vector3 = away.normalized() if away.length() > 0.1 else Vector3.FORWARD
	_turn_towards(dir, 0.0, turn_speed, delta)
	velocity.x = dir.x * move_speed * 1.4
	velocity.z = dir.z * move_speed * 1.4
	move_and_slide()
	if not is_fleeing():
		_enter_state(State.CRAWL)


func _on_flee_started() -> void:
	_enter_state(State.FLEE)


func _refresh_remote_warning() -> void:
	if _warning != null and state == State.SPRING_WINDUP:
		_warning.show_line(global_position, net_spring_dir, spring_range, 1.4)


func _on_remote_state(new_state: int) -> void:
	state = new_state as State
	_state_time = 0.0
	if _warning != null:
		if state == State.SPRING_WINDUP:
			_refresh_remote_warning()
		elif state == State.BITE_WINDUP:
			_warning.show_circle(global_position - transform.basis.z * 0.8, bite_range)
		else:
			_warning.hide_warning()


# ---------------------------------------------------------------------------
# Modelo 3D Low-Poly + ToonKit (referência: criatura_rastejante.jpg)
# ---------------------------------------------------------------------------

func _build_model() -> void:
	_mat = ToonKit.vertex_material(true, true)
	_register_flash_material(_mat)

	_core_mat = ToonKit.vertex_material(true, true)
	_core_mat.set_shader_parameter(&"emission_color", PURPLE_CORE)
	_register_flash_material(_core_mat)

	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Casca esférica facetada de geodo
	LowPolyMesh.prism(st, Vector3(0.0, 0.25, 0.0), Vector3(0.0, 0.72, 0.0), 0.38, 0.32, 8, STONE_BODY)
	LowPolyMesh.prism(st, Vector3(0.0, 0.72, 0.0), Vector3(0.0, 0.92, 0.0), 0.32, 0.18, 7, STONE_DARK)

	# Fendas rochosas com brilho
	LowPolyMesh.box(st, Vector3(0.0, 0.48, 0.0), Vector3(0.68, 0.16, 0.42), Basis.IDENTITY, STONE_DARK)

	# Olho ciclópico frontal saliente (referência: criatura_rastejante.jpg)
	# Aro de pedra do olho
	LowPolyMesh.prism(st, Vector3(0.0, 0.65, -0.22), Vector3(0.0, 0.72, -0.42), 0.22, 0.20, 6, EYE_RIM)
	# Globo ocular branco esbugalhado
	LowPolyMesh.box(st, Vector3(0.0, 0.72, -0.42), Vector3(0.24, 0.24, 0.12), Basis.IDENTITY, EYE_WHITE)
	# Pupila preta
	LowPolyMesh.box(st, Vector3(0.0, 0.72, -0.485), Vector3(0.12, 0.12, 0.03), Basis.IDENTITY, EYE_PUPIL)

	_body.add_child(LowPolyMesh.commit(st, "StoneShell", _mat))

	# Núcleo interior brilhante de ametista
	var st_core: SurfaceTool = SurfaceTool.new()
	st_core.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Núcleo maior que a casca: aparece como faixa roxa a brilhar entre as placas (criatura_rastejante.jpg)
	LowPolyMesh.prism(st_core, Vector3(0.0, 0.36, 0.0), Vector3(0.0, 0.64, 0.0), 0.4, 0.36, 8, PURPLE_CORE)
	_core_mesh = LowPolyMesh.commit(st_core, "CoreMesh", _core_mat)
	_body.add_child(_core_mesh)

	# 6 Patas articuladas de pedra (3 de cada lado)
	for i: int in 3:
		var z_pos: float = -0.15 + float(i) * 0.18
		_legs.append(_build_leg(-0.35, z_pos, -1.0, "LegL%d" % i))
		_legs.append(_build_leg(0.35, z_pos, 1.0, "LegR%d" % i))

	# Collision Shape
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(1.1, 0.9, 1.1)
	cs.shape = box
	cs.position = Vector3(0.0, 0.45, 0.0)
	add_child(cs)


func _build_leg(x: float, z: float, side: float, leg_name: String) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.name = leg_name
	pivot.position = Vector3(x, 0.42, z)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Segmento superior angular
	LowPolyMesh.prism(st, Vector3(0.0, 0.0, 0.0), Vector3(side * 0.28, 0.18, 0.0), 0.07, 0.05, 4, STONE_BODY)
	# Segmento inferior até ao chão
	LowPolyMesh.prism(st, Vector3(side * 0.28, 0.18, 0.0), Vector3(side * 0.48, -0.42, 0.0), 0.05, 0.015, 3, STONE_DARK)
	pivot.add_child(LowPolyMesh.commit(st, "LegMesh", _mat))
	_body.add_child(pivot)
	return pivot


func _animate(delta: float) -> void:
	if _body == null:
		return

	if state == State.CRAWL or state == State.FLEE:
		var speed: float = 16.0 if state == State.FLEE else 12.0
		for i: int in range(_legs.size()):
			var leg: Node3D = _legs[i]
			var phase_offset: float = float(i) * 1.05
			leg.rotation.x = sin(_anim_time * speed + phase_offset) * 0.35
			leg.rotation.z = cos(_anim_time * speed + phase_offset) * 0.15
		_body.position.y = absf(sin(_anim_time * speed)) * 0.04
		_body.rotation.y = sin(_anim_time * (speed * 0.5)) * 0.05
	elif state == State.BITE_WINDUP:
		# Encolhe ligeiramente e treme antes do bote
		var jitter: float = sin(_state_time * 40.0) * 0.02
		_body.position.y = -0.06 + jitter
		_body.rotation.y = jitter * 2.0
	elif state == State.SPRING_WINDUP:
		# Comprime-se como uma mola de relógio no chão
		_body.position.y = lerpf(_body.position.y, -0.22, clampf(10.0 * delta, 0.0, 1.0))
		for leg: Node3D in _legs:
			leg.rotation.z = lerpf(leg.rotation.z, 0.4, clampf(8.0 * delta, 0.0, 1.0))
	elif state == State.SPRING_JUMP:
		# Esticado no salto
		_body.position.y = 0.1
		for leg: Node3D in _legs:
			leg.rotation.z = -0.3
	elif state == State.RECOVER:
		_body.position.y = lerpf(_body.position.y, 0.0, clampf(6.0 * delta, 0.0, 1.0))
		for leg: Node3D in _legs:
			leg.rotation.x = 0.0
			leg.rotation.z = 0.0
