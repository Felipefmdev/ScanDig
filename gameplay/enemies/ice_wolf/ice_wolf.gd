class_name IceWolf
extends EnemyBase

## Lobo do Gelo (#43, #57): predador ágil da Geleira Eterna.
## Inspirado fielmente na referência visual lobo_gelo.jpg:
##  - Pelagem azul-gelo com cristais translúcidos pontiagudos no dorso e juba;
##  - Focinho afiado com presas e olhos esbugalhados estilo "How to Fish";
##  - Investida rápida em perseguição e salto voraz (LEAP) telegrafado que abalroa o jogador.

enum State { EMERGE, CHASE, BITE_WINDUP, LEAP_WINDUP, LEAP, RECOVER, FLEE }

const ICE_BODY: Color = Color("#9cc4dc")
const ICE_CRYSTAL: Color = Color("#6ab8d8")
const ICE_BELLY: Color = Color("#d8eef6")
const NOSE_DARK: Color = Color("#1e2630")
const EYE_WHITE: Color = Color(0.96, 0.96, 0.96)
const EYE_PUPIL: Color = Color(0.10, 0.10, 0.12)
const FANG_WHITE: Color = Color(0.92, 0.95, 0.94)

@export var move_speed: float = 3.6
@export var turn_speed: float = 6.0
@export var leap_speed: float = 9.5
@export var leap_damage: float = 16.0
@export var bite_damage: float = 10.0
@export var bite_windup_time: float = 0.35
@export var bite_cooldown_time: float = 1.6
@export var leap_windup_time: float = 0.65
@export var leap_range: float = 7.5
@export var bite_range: float = 1.7
@export var recover_time: float = 0.7
@export var emerge_time: float = 0.9

var state: State = State.EMERGE
var net_leap_dir: Vector3 = Vector3.FORWARD:
	set(value):
		net_leap_dir = value
		if not has_simulation_authority() and is_node_ready():
			_refresh_remote_leap_warning()

var _state_time: float = 0.0
var _bite_cooldown: float = 0.0
var _surface_y: float = 0.0
var _hit_done: bool = false
var _hit_targets: Array[Node] = []
var _walk_anim_time: float = 0.0
var _warning: GroundWarning = null

var _body: Node3D = null
var _leg_fl: Node3D = null
var _leg_fr: Node3D = null
var _leg_bl: Node3D = null
var _leg_br: Node3D = null
var _head: Node3D = null
var _tail: Node3D = null
var _mat: ShaderMaterial = null


func _ready() -> void:
	super._ready()
	max_health = 65.0
	health = 65.0
	death_color = ICE_CRYSTAL
	stun_fx_height = 1.2
	_surface_y = global_position.y
	_build_model()
	_warning = GroundWarning.new()
	add_child(_warning)
	_enter_state(State.EMERGE)


func setup_network() -> void:
	super.setup_network()
	_add_synced_property(".:net_leap_dir")


func _enemy_physics(delta: float) -> void:
	_state_time += delta
	_walk_anim_time += delta
	if _bite_cooldown > 0.0:
		_bite_cooldown -= delta

	match state:
		State.EMERGE:
			var t: float = clampf(_state_time / emerge_time, 0.0, 1.0)
			global_position.y = _surface_y - 1.2 * (1.0 - t)
			if t >= 1.0:
				_enter_state(State.CHASE)
		State.CHASE:
			_process_chase(delta)
		State.BITE_WINDUP:
			_process_bite_windup(delta)
		State.LEAP_WINDUP:
			_process_leap_windup(delta)
		State.LEAP:
			_process_leap(delta)
		State.RECOVER:
			_process_recover(delta)
		State.FLEE:
			_process_flee(delta)

	_animate(delta)


func _enter_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	_hit_done = false
	_hit_targets.clear()

	match state:
		State.EMERGE:
			global_position.y = _surface_y - 1.2
		State.CHASE:
			_warning.hide_warning()
		State.BITE_WINDUP:
			velocity.x = 0.0
			velocity.z = 0.0
			var target: Node3D = _update_target(0.0)
			var to: Vector3 = (target.global_position - global_position) if target != null else -transform.basis.z
			to.y = 0.0
			var dir: Vector3 = to.normalized() if to.length() > 0.1 else -transform.basis.z
			_warning.show_circle(global_position + dir * 0.9, bite_range)
		State.LEAP_WINDUP:
			velocity.x = 0.0
			velocity.z = 0.0
			var target: Node3D = _update_target(0.0)
			if target != null:
				var to: Vector3 = target.global_position - global_position
				to.y = 0.0
				net_leap_dir = to.normalized() if to.length() > 0.1 else -transform.basis.z
			else:
				net_leap_dir = -transform.basis.z
			_warning.show_line(global_position, net_leap_dir, leap_range, 1.4)
		State.LEAP:
			_warning.hide_warning()
			velocity = net_leap_dir * leap_speed + Vector3.UP * 4.5
			SFX.play_at(SFX.EMERGE_SAND, global_position, 2.0)
		State.RECOVER:
			velocity.x = 0.0
			velocity.z = 0.0
			_warning.hide_warning()
		State.FLEE:
			_warning.hide_warning()


func _process_chase(delta: float) -> void:
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
	elif dist <= leap_range and dist > bite_range + 0.8:
		# Prepara o salto de investida
		_enter_state(State.LEAP_WINDUP)
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
			_knockback(target, push_dir * 7.0 + Vector3.UP * 3.0, 0.12)
			spawn_particles(target.global_position + Vector3.UP * 0.5, ICE_CRYSTAL, 8, 2.5)
		_enter_state(State.RECOVER)


func _process_leap_windup(delta: float) -> void:
	_apply_gravity(delta)
	_warning.pulse(delta)
	_turn_towards(net_leap_dir, 0.0, turn_speed * 1.5, delta)
	move_and_slide()
	if _state_time >= leap_windup_time:
		_enter_state(State.LEAP)


func _process_leap(delta: float) -> void:
	_apply_gravity(delta)
	move_and_slide()

	# Dano por atropelamento durante o salto
	for p: Node3D in _all_players():
		if _hit_targets.has(p):
			continue
		var d: Vector3 = p.global_position - global_position
		d.y = 0.0
		if d.length() <= 1.6:
			_hit_targets.append(p)
			_deal_damage(p, leap_damage)
			_knockback(p, net_leap_dir * 9.0 + Vector3.UP * 3.5, 0.15)
			spawn_particles(p.global_position + Vector3.UP * 0.8, ICE_CRYSTAL, 12, 3.5)

	if is_on_floor() and _state_time > 0.2:
		_enter_state(State.RECOVER)


func _process_recover(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, delta * 10.0)
	velocity.z = move_toward(velocity.z, 0.0, delta * 10.0)
	move_and_slide()
	if _state_time >= recover_time:
		_enter_state(State.CHASE)


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
		_enter_state(State.CHASE)


func _on_flee_started() -> void:
	_enter_state(State.FLEE)


func _refresh_remote_leap_warning() -> void:
	if _warning != null and state == State.LEAP_WINDUP:
		_warning.show_line(global_position, net_leap_dir, leap_range, 1.4)


func _on_remote_state(new_state: int) -> void:
	state = new_state as State
	_state_time = 0.0
	if _warning != null:
		if state == State.LEAP_WINDUP:
			_refresh_remote_leap_warning()
		elif state == State.BITE_WINDUP:
			_warning.show_circle(global_position - transform.basis.z * 0.9, bite_range)
		else:
			_warning.hide_warning()


# ---------------------------------------------------------------------------
# Modelo 3D Low-Poly + ToonKit (referência: lobo_gelo.jpg)
# ---------------------------------------------------------------------------

func _build_model() -> void:
	_mat = ToonKit.vertex_material(true, true)
	_register_flash_material(_mat)

	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Tronco alongado e facetado
	LowPolyMesh.prism(st, Vector3(0.0, 0.45, 0.45), Vector3(0.0, 0.52, -0.45), 0.28, 0.34, 6, ICE_BODY)
	# Ventre mais claro
	LowPolyMesh.box(st, Vector3(0.0, 0.32, 0.0), Vector3(0.36, 0.16, 0.75), Basis.IDENTITY, ICE_BELLY)

	# Cristais / espigões pontiagudos de gelo no dorso (como na foto de referência)
	for i: int in 4:
		var z_pos: float = 0.3 - float(i) * 0.22
		var h: float = 0.35 + float(i) * 0.06
		LowPolyMesh.prism(st, Vector3(0.0, 0.6, z_pos), Vector3(0.0, 0.6 + h, z_pos + 0.08), 0.08, 0.0, 4, ICE_CRYSTAL)
		LowPolyMesh.prism(st, Vector3(-0.1, 0.55, z_pos), Vector3(-0.16, 0.55 + h * 0.8, z_pos + 0.05), 0.06, 0.0, 4, ICE_CRYSTAL)
		LowPolyMesh.prism(st, Vector3(0.1, 0.55, z_pos), Vector3(0.16, 0.55 + h * 0.8, z_pos + 0.05), 0.06, 0.0, 4, ICE_CRYSTAL)

	# Juba / colar de gelo no pescoço
	LowPolyMesh.prism(st, Vector3(0.0, 0.54, -0.38), Vector3(0.0, 0.68, -0.58), 0.36, 0.24, 7, ICE_BODY)
	for ang_i: int in 5:
		var a: float = -1.2 + float(ang_i) * 0.6
		var p_end: Vector3 = Vector3(sin(a) * 0.42, 0.68 + cos(a) * 0.2, -0.45)
		LowPolyMesh.prism(st, Vector3(sin(a) * 0.25, 0.58, -0.4), p_end, 0.07, 0.0, 3, ICE_CRYSTAL)

	# Cabeça e focinho afiado
	LowPolyMesh.box(st, Vector3(0.0, 0.72, -0.68), Vector3(0.28, 0.26, 0.26), Basis.IDENTITY, ICE_BODY)
	# Focinho estendido para a frente (-Z)
	LowPolyMesh.prism(st, Vector3(0.0, 0.68, -0.75), Vector3(0.0, 0.62, -1.05), 0.16, 0.08, 5, ICE_BODY)
	# Nariz escuro
	LowPolyMesh.box(st, Vector3(0.0, 0.65, -1.06), Vector3(0.09, 0.07, 0.06), Basis.IDENTITY, NOSE_DARK)

	# Presas inferiores e superiores
	LowPolyMesh.prism(st, Vector3(-0.06, 0.61, -0.98), Vector3(-0.06, 0.54, -0.98), 0.02, 0.0, 3, FANG_WHITE)
	LowPolyMesh.prism(st, Vector3(0.06, 0.61, -0.98), Vector3(0.06, 0.54, -0.98), 0.02, 0.0, 3, FANG_WHITE)

	# Orelhas triangulares
	LowPolyMesh.prism(st, Vector3(-0.11, 0.84, -0.65), Vector3(-0.16, 1.05, -0.68), 0.07, 0.0, 3, ICE_BODY)
	LowPolyMesh.prism(st, Vector3(0.11, 0.84, -0.65), Vector3(0.16, 1.05, -0.68), 0.07, 0.0, 3, ICE_BODY)

	# Olhos esbugalhados "How to Fish"
	LowPolyMesh.box(st, Vector3(-0.13, 0.76, -0.78), Vector3(0.08, 0.08, 0.04), Basis.IDENTITY, EYE_WHITE)
	LowPolyMesh.box(st, Vector3(0.13, 0.76, -0.78), Vector3(0.08, 0.08, 0.04), Basis.IDENTITY, EYE_WHITE)
	LowPolyMesh.box(st, Vector3(-0.13, 0.76, -0.805), Vector3(0.04, 0.04, 0.02), Basis.IDENTITY, EYE_PUPIL)
	LowPolyMesh.box(st, Vector3(0.13, 0.76, -0.805), Vector3(0.04, 0.04, 0.02), Basis.IDENTITY, EYE_PUPIL)

	_body.add_child(LowPolyMesh.commit(st, "TorsoMesh", _mat))

	# Cauda de cristais curvada para cima
	_tail = Node3D.new()
	_tail.name = "Tail"
	_tail.position = Vector3(0.0, 0.52, 0.48)
	var st_tail: SurfaceTool = SurfaceTool.new()
	st_tail.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyMesh.prism(st_tail, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.22, 0.35), 0.12, 0.15, 5, ICE_CRYSTAL)
	LowPolyMesh.prism(st_tail, Vector3(0.0, 0.22, 0.35), Vector3(0.0, 0.45, 0.48), 0.15, 0.02, 4, ICE_BODY)
	_tail.add_child(LowPolyMesh.commit(st_tail, "TailMesh", _mat))
	_body.add_child(_tail)

	# 4 Patas articuladas
	_leg_fl = _build_leg(-0.18, 0.42, -0.32, "LegFL")
	_leg_fr = _build_leg(0.18, 0.42, -0.32, "LegFR")
	_leg_bl = _build_leg(-0.18, 0.42, 0.32, "LegBL")
	_leg_br = _build_leg(0.18, 0.42, 0.32, "LegBR")

	# Collision Shape
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.8, 0.9, 1.6)
	cs.shape = box
	cs.position = Vector3(0.0, 0.45, -0.1)
	add_child(cs)


func _build_leg(x: float, y: float, z: float, leg_name: String) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.name = leg_name
	pivot.position = Vector3(x, y, z)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Coxa
	LowPolyMesh.prism(st, Vector3(0.0, 0.0, 0.0), Vector3(0.0, -0.24, 0.04), 0.10, 0.07, 5, ICE_BODY)
	# Canela
	LowPolyMesh.prism(st, Vector3(0.0, -0.24, 0.04), Vector3(0.0, -0.42, 0.0), 0.07, 0.05, 4, ICE_BODY)
	# Pata com garras
	LowPolyMesh.box(st, Vector3(0.0, -0.42, -0.06), Vector3(0.11, 0.06, 0.14), Basis.IDENTITY, ICE_CRYSTAL)
	for claw_i: int in 3:
		var cx: float = -0.03 + float(claw_i) * 0.03
		LowPolyMesh.prism(st, Vector3(cx, -0.42, -0.12), Vector3(cx, -0.44, -0.18), 0.015, 0.0, 3, NOSE_DARK)
	pivot.add_child(LowPolyMesh.commit(st, "LegMesh", _mat))
	_body.add_child(pivot)
	return pivot


func _animate(delta: float) -> void:
	if _body == null:
		return

	if state == State.CHASE or state == State.FLEE:
		var speed: float = velocity.length()
		var step: float = sin(_walk_anim_time * 14.0) * clampf(speed / move_speed, 0.0, 1.5)
		if _leg_fl != null:
			_leg_fl.rotation.x = step * 0.6
		if _leg_fr != null:
			_leg_fr.rotation.x = -step * 0.6
		if _leg_bl != null:
			_leg_bl.rotation.x = -step * 0.5
		if _leg_br != null:
			_leg_br.rotation.x = step * 0.5
		if _tail != null:
			_tail.rotation.y = sin(_walk_anim_time * 10.0) * 0.35
		_body.position.y = absf(sin(_walk_anim_time * 14.0)) * 0.06
	elif state == State.BITE_WINDUP:
		# Puxa o tronco para trás e rosna antes de morder
		_body.position.y = lerpf(_body.position.y, -0.06, clampf(12.0 * delta, 0.0, 1.0))
		if _head != null:
			_head.rotation.x = -0.3 + sin(_state_time * 30.0) * 0.08
		if _tail != null:
			_tail.rotation.y = sin(_state_time * 20.0) * 0.25
	elif state == State.LEAP_WINDUP:
		# Agacha para saltar
		_body.position.y = lerpf(_body.position.y, -0.18, clampf(8.0 * delta, 0.0, 1.0))
		if _tail != null:
			_tail.rotation.y = sin(_state_time * 24.0) * 0.4
	elif state == State.LEAP:
		# Posição esticada de salto
		_body.position.y = 0.05
		if _leg_fl != null:
			_leg_fl.rotation.x = -0.8
		if _leg_fr != null:
			_leg_fr.rotation.x = -0.8
		if _leg_bl != null:
			_leg_bl.rotation.x = 0.9
		if _leg_br != null:
			_leg_br.rotation.x = 0.9
	elif state == State.RECOVER:
		_body.position.y = lerpf(_body.position.y, 0.0, clampf(6.0 * delta, 0.0, 1.0))
		if _leg_fl != null:
			_leg_fl.rotation.x = 0.0
		if _leg_fr != null:
			_leg_fr.rotation.x = 0.0
		if _leg_bl != null:
			_leg_bl.rotation.x = 0.0
		if _leg_br != null:
			_leg_br.rotation.x = 0.0
