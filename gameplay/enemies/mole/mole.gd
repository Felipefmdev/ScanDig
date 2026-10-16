class_name Mole
extends EnemyBase

## Toupeira do Campo Antigo: viaja debaixo de terra (imune, só se vê o monte de terra a
## avançar), pára debaixo do jogador, treme (aviso no chão) e irrompe. Depois fica exposta à
## superfície uns segundos (é aí que se lhe bate) e volta a enterrar-se. Fugir do aviso evita
## o golpe. Com flee_from (repelente) enterra-se e vai-se embora.

enum State {
	UNDERGROUND,
	TELEGRAPH,
	ERUPT,
	EXPOSED,
	DIG_DOWN,
	LEAVE,
}

const FUR: Color = Color(0.26, 0.20, 0.17)
const FUR_DARK: Color = Color(0.18, 0.14, 0.12)
const SNOUT: Color = Color(0.96, 0.62, 0.65)
const NOSE_TIP: Color = Color(0.85, 0.45, 0.50)
const CLAW: Color = Color(0.88, 0.84, 0.72)
const GLASSES_FRAME: Color = Color(0.14, 0.12, 0.10)
const GLASSES_LENS: Color = Color(0.85, 0.90, 0.94)
const DIRT: Color = Color(0.48, 0.36, 0.22)

## Profundidade (abaixo do chão) a que viaja.
const UNDERGROUND_DEPTH: float = 1.0

@export var underground_speed: float = 2.6
## Distância (no plano) ao jogador a que pára para irromper.
@export var erupt_trigger: float = 0.6
@export var telegraph_time: float = 0.8
@export var erupt_radius: float = 1.3
@export var erupt_damage: float = 14.0
@export var erupt_time: float = 0.25
@export var exposed_time: float = 2.5
@export var dig_down_time: float = 0.6
## Arranhão à superfície (quando o jogador fica colado).
@export var scratch_damage: float = 6.0
@export var scratch_range: float = 1.2
@export var scratch_cooldown: float = 1.2
## Nível de ameaça que a fez surgir (0 = ambiente).
@export var spawn_level: int = 1

var state: State = State.UNDERGROUND

var _state_time: float = 0.0
var _ground_y: float = 0.0
var _erupt_point: Vector3 = Vector3.ZERO
var _scratch_timer: float = 0.0
var _leaving: bool = false
var _body_root: Node3D = null
var _mound: MeshInstance3D = null
var _warning: GroundWarning = null
var _collision: CollisionShape3D = null


func _ready() -> void:
	super._ready()
	stun_fx_height = 0.8
	_collision = get_node_or_null(^"CollisionShape3D") as CollisionShape3D
	_ground_y = global_position.y
	_build_model()
	_warning = GroundWarning.new()
	add_child(_warning)
	if DisturbanceMeter.instance != null:
		DisturbanceMeter.instance.threshold_cleared.connect(_on_threshold_cleared)
	_enter_state(State.UNDERGROUND)


func _enemy_physics(delta: float) -> void:
	_state_time += delta
	if _scratch_timer > 0.0:
		_scratch_timer -= delta
	match state:
		State.UNDERGROUND:
			_process_underground(delta)
		State.TELEGRAPH:
			_process_telegraph(delta)
		State.ERUPT:
			_process_erupt()
		State.EXPOSED:
			_process_exposed(delta)
		State.DIG_DOWN, State.LEAVE:
			_process_dig_down()


func _enter_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	velocity = Vector3.ZERO
	if _warning != null:
		_warning.hide_warning()
	var surface: bool = new_state == State.EXPOSED or new_state == State.ERUPT
	if _collision != null:
		_collision.disabled = not surface
	if _mound != null:
		_mound.visible = new_state != State.EXPOSED and new_state != State.ERUPT
	match new_state:
		State.UNDERGROUND:
			_body_root.visible = false
			global_position.y = _ground_y - UNDERGROUND_DEPTH
		State.TELEGRAPH:
			_erupt_point = Vector3(global_position.x, _ground_y, global_position.z)
			_warning.show_circle(_erupt_point, erupt_radius)
		State.ERUPT:
			_body_root.visible = true
			SFX.play_at(SFX.EMERGE_SAND, _erupt_point, 2.0)
			spawn_particles(_erupt_point + Vector3.UP * 0.1, DIRT, 24, 4.0)
			for p: Node3D in _players_within(_erupt_point, erupt_radius):
				_deal_damage(p, erupt_damage)
				# #57: lança o jogador ao ar (pequeno), quase na vertical.
				var out: Vector3 = p.global_position - _erupt_point
				out.y = 0.0
				out = out.normalized() if out.length_squared() > 0.01 else Vector3.FORWARD
				_knockback(p, out * 2.5 + Vector3.UP * 9.0, 0.06)
		State.DIG_DOWN, State.LEAVE:
			SFX.play_at(SFX.EMERGE_SAND, global_position)
			spawn_particles(Vector3(global_position.x, _ground_y + 0.05, global_position.z), DIRT, 12, 2.0)


# ---------------------------------------------------------------------------
# Estados
# ---------------------------------------------------------------------------

func _process_underground(delta: float) -> void:
	var target: Node3D = _update_target(delta)
	if target == null:
		return
	var to_t: Vector3 = target.global_position - global_position
	to_t.y = 0.0
	var dist: float = to_t.length()
	if dist <= erupt_trigger:
		_enter_state(State.TELEGRAPH)
		return
	var step: Vector3 = to_t / dist * minf(underground_speed * delta, dist)
	var next: Vector3 = global_position + step
	_ground_y = _ground_height(next, _ground_y)
	global_position = Vector3(next.x, _ground_y - UNDERGROUND_DEPTH, next.z)
	_turn_towards(to_t, 0.0, 10.0, delta)
	_place_mound(0.03 * sin(_state_time * 20.0))


func _process_telegraph(delta: float) -> void:
	_warning.pulse(delta)
	_place_mound(0.06 * sin(_state_time * 45.0))
	if _state_time >= telegraph_time:
		_enter_state(State.ERUPT)


func _process_erupt() -> void:
	var t: float = clampf(_state_time / erupt_time, 0.0, 1.0)
	global_position = Vector3(_erupt_point.x, _ground_y - UNDERGROUND_DEPTH * (1.0 - t), _erupt_point.z)
	# Sai disparada como uma rolha (#57)
	_body_root.position.y = sin(t * PI) * 0.6
	if t >= 1.0:
		_enter_state(State.EXPOSED)


## À superfície: vulnerável, arranha quem estiver colado, e volta para baixo de terra.
func _process_exposed(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()
	var target: Node3D = _update_target(delta)
	if target != null:
		var to_t: Vector3 = target.global_position - global_position
		to_t.y = 0.0
		_turn_towards(to_t, 0.0, 6.0, delta)
		if to_t.length() <= scratch_range and _scratch_timer <= 0.0:
			_scratch_timer = scratch_cooldown
			SFX.play_at(SFX.CRAB_PINCH, global_position, -2.0)
			_deal_damage(target, scratch_damage)
	_body_root.position.y = absf(sin(_state_time * 6.0)) * 0.04
	if _state_time >= exposed_time:
		_enter_state(State.LEAVE if _leaving else State.DIG_DOWN)


func _process_dig_down() -> void:
	var t: float = clampf(_state_time / dig_down_time, 0.0, 1.0)
	global_position.y = _ground_y - UNDERGROUND_DEPTH * t
	if t >= 1.0:
		if state == State.LEAVE:
			queue_free()
		else:
			_enter_state(State.UNDERGROUND)


func _on_threshold_cleared(level: int) -> void:
	if not has_simulation_authority():
		return
	if level <= spawn_level and is_alive():
		_go_away()


func _go_away() -> void:
	_leaving = true
	if state == State.UNDERGROUND or state == State.TELEGRAPH:
		queue_free()
	elif state == State.EXPOSED:
		_enter_state(State.LEAVE)


# ---------------------------------------------------------------------------
# Ganchos da EnemyBase
# ---------------------------------------------------------------------------

## Cliente: corpo, monte de terra, aviso e colisão a partir do estado do host.
func _on_remote_state(new_state: int) -> void:
	var surface: bool = new_state == State.EXPOSED or new_state == State.ERUPT
	_body_root.visible = surface or new_state == State.DIG_DOWN or new_state == State.LEAVE
	_mound.visible = not surface
	if _collision != null:
		_collision.disabled = not surface
	if new_state == State.TELEGRAPH:
		_ground_y = global_position.y + UNDERGROUND_DEPTH
		_warning.show_circle(Vector3(global_position.x, _ground_y, global_position.z), erupt_radius)
	else:
		_warning.hide_warning()


## Cliente: o monte de terra segue a posição replicada (o host move-o no _physics_process).
func _process(delta: float) -> void:
	if has_simulation_authority():
		return
	if state == State.UNDERGROUND or state == State.TELEGRAPH:
		_ground_y = global_position.y + UNDERGROUND_DEPTH
		_place_mound(0.03 * sin(Time.get_ticks_msec() * 0.02))
	if state == State.TELEGRAPH:
		_warning.pulse(delta)


## Só leva dano à superfície.
func _can_take_damage() -> bool:
	return state == State.EXPOSED


func _can_be_stunned() -> bool:
	return state == State.EXPOSED


## Atordoada fica mais tempo exposta (o _state_time não avança durante o stun).
func _on_flee_started() -> void:
	_go_away()


# ---------------------------------------------------------------------------
# Modelo e monte de terra
# ---------------------------------------------------------------------------

func _place_mound(wobble: float) -> void:
	if _mound != null:
		_mound.global_position = Vector3(global_position.x, _ground_y + wobble, global_position.z)


func _build_model() -> void:
	_body_root = get_node_or_null(^"BodyRoot") as Node3D
	if _body_root == null:
		_body_root = Node3D.new()
		_body_root.name = "BodyRoot"
		add_child(_body_root)
	var mat: ShaderMaterial = ToonKit.vertex_material(true, true)
	_register_flash_material(mat)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Corpo rechonchudo em forma de pêra (toupeira.jpg)
	LowPolyMesh.prism(st, Vector3(0, 0.0, 0.05), Vector3(0, 0.52, 0.0), 0.35, 0.28, 8, FUR)
	LowPolyMesh.prism(st, Vector3(0, 0.50, 0.0), Vector3(0, 0.74, -0.05), 0.28, 0.18, 8, FUR)

	# Focinho carnudo rosa bulboso e ponta do nariz com narinas (toupeira.jpg)
	LowPolyMesh.prism(st, Vector3(0, 0.58, -0.14), Vector3(0, 0.56, -0.32), 0.15, 0.11, 7, SNOUT)
	LowPolyMesh.box(st, Vector3(0, 0.56, -0.34), Vector3(0.15, 0.10, 0.06), Basis.IDENTITY, NOSE_TIP)
	LowPolyMesh.box(st, Vector3(-0.038, 0.56, -0.372), Vector3(0.022, 0.028, 0.015), Basis.IDENTITY, FUR_DARK)
	LowPolyMesh.box(st, Vector3(0.038, 0.56, -0.372), Vector3(0.022, 0.028, 0.015), Basis.IDENTITY, FUR_DARK)

	# Óculos redondos cómicos com aros escuros, lentes e olhos por trás (toupeira.jpg)
	# Ponte dos óculos
	LowPolyMesh.box(st, Vector3(0.0, 0.68, -0.21), Vector3(0.06, 0.02, 0.02), Basis.IDENTITY, GLASSES_FRAME)
	for side: float in [-1.0, 1.0]:
		# Aro redondo
		LowPolyMesh.prism(st, Vector3(0.12 * side, 0.67, -0.19), Vector3(0.12 * side, 0.67, -0.225), 0.085, 0.085, 8, GLASSES_FRAME)
		# Vidro da lente
		LowPolyMesh.box(st, Vector3(0.12 * side, 0.67, -0.22), Vector3(0.11, 0.11, 0.012), Basis.IDENTITY, GLASSES_LENS)
		# Pupila atrás da lente
		LowPolyMesh.box(st, Vector3(0.12 * side, 0.67, -0.228), Vector3(0.035, 0.035, 0.01), Basis.IDENTITY, Color.BLACK)
		# Hastes laterais dos óculos
		LowPolyMesh.box(st, Vector3(0.20 * side, 0.68, -0.11), Vector3(0.016, 0.016, 0.20), Basis(Vector3.UP, 0.22 * side), GLASSES_FRAME)

		# Grandes patas e garras de escavação (toupeira.jpg)
		# Braço
		LowPolyMesh.box(st, Vector3(0.26 * side, 0.38, -0.08), Vector3(0.16, 0.14, 0.18), Basis(Vector3.FORWARD, 0.35 * side), FUR_DARK)
		# Palma em pá larga marfim/osso
		var paw_pos: Vector3 = Vector3(0.33 * side, 0.36, -0.22)
		LowPolyMesh.box(st, paw_pos, Vector3(0.22, 0.08, 0.20), Basis(Vector3.UP, -0.25 * side), CLAW)
		# 4 garras longas curvas de escavador
		for k: int in 4:
			var offset: float = (float(k) - 1.5) * 0.045
			var c: Vector3 = paw_pos + Vector3(offset, 0.0, -0.10)
			LowPolyMesh.prism(st, c, c + Vector3(offset * 0.2 * side, -0.06, -0.16), 0.024, 0.005, 4, CLAW)

	_body_root.add_child(LowPolyMesh.commit(st, "Body", mat))
	_body_root.visible = false

	var mst: SurfaceTool = SurfaceTool.new()
	mst.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyMesh.prism(mst, Vector3(0, -0.05, 0), Vector3(0, 0.24, 0), 0.48, 0.16, 8, DIRT)
	# Pedras e terra revolvida à volta do monte
	for k: int in 6:
		var ang: float = float(k) * (TAU / 6.0) + 0.2
		var rx: float = cos(ang) * 0.38
		var rz: float = sin(ang) * 0.38
		LowPolyMesh.box(mst, Vector3(rx, 0.08, rz), Vector3(0.09, 0.07, 0.08), Basis(Vector3.UP, ang), Color(0.38, 0.28, 0.18))
	_mound = LowPolyMesh.commit(mst, "Mound", ToonKit.vertex_material(true, true))
	_mound.top_level = true
	add_child(_mound)
	_place_mound(0.0)
