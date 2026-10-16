class_name Seagull
extends EnemyBase

## Gaivota ladra: voa em círculos por cima do jogador, mergulha e ROUBA um item escavado da
## mochila (player.steal_loot()). Sem nada para roubar, só bica (PECK_DAMAGE) e volta a tentar.
## Depois de roubar foge para longe e desaparece passado despawn_after segundos. Se for abatida
## (estilingue), cai e larga o item roubado como ItemPickup onde tocar no chão.
## Coop (#5 F, #24): a gaivota corre no host. A mochila é do dono, por isso ao chegar ao
## jogador o host chama target._steal_from (rpc_id ao dono, ou direto se o jogador for o do
## host) e fica a pairar (WAIT_LOOT) até o dono responder request_seagull_loot(dict do item,
## ou {} se não havia nada). O item roubado é replicado como has_stolen (só visual).
## #57: um mergulho em cada dois é KAMIKAZE: círculo no chão onde o jogador estava, mergulho a
## pique; acerta = atira o jogador; falha = fica com o bico ESPETADO na areia (a espernear,
## presa fácil). O corvo (subclasse) troca-o pela ESPIRAL do bando à volta do jogador.

enum State {
	CIRCLE,
	DIVE,
	ESCAPE,
	FALL,
	WAIT_LOOT,
	KAMIKAZE_TELEGRAPH,
	KAMIKAZE,
	STUCK,
	SPIRAL_TELEGRAPH,
	SPIRAL,
}

const KAMIKAZE_TELEGRAPH_TIME: float = 0.9
const KAMIKAZE_SPEED: float = 16.0
const KAMIKAZE_RADIUS: float = 1.3
const STUCK_TIME: float = 2.6
const KAMIKAZE_DAMAGE: float = 8.0

@export var circle_radius: float = 6.0
## Altura do voo em círculo acima do jogador.
@export var circle_height: float = 7.0
@export var fly_speed: float = 6.5
@export var dive_speed: float = 11.0
@export var escape_speed: float = 9.0
@export var circle_time_min: float = 4.0
@export var circle_time_max: float = 7.0
## Distância ao peito do jogador a que rouba/bica.
@export var steal_distance: float = 1.1
@export var peck_damage: float = 5.0
## Mergulhos sem sucesso antes de desistir e ir embora.
@export var max_dives: int = 3
## Distância a que foge depois de roubar.
@export var escape_distance: float = 30.0
## Segundos depois do roubo (ou da desistência) até desaparecer.
@export var despawn_after: float = 20.0
## Máscara do chão (para saber onde cai quando é abatida).
@export_flags_3d_physics var ground_mask: int = 1

const CHEST_OFFSET: Vector3 = Vector3(0.0, 1.3, 0.0)
## Tempo máximo à espera da resposta do dono da mochila.
const LOOT_REPLY_TIMEOUT: float = 1.5
const MAX_DIVE_TIME: float = 3.5
const STEER: float = 3.0
const WHITE: Color = Color(0.96, 0.96, 0.95)
const WING_GREY: Color = Color(0.62, 0.65, 0.7)
const WING_TIP: Color = Color(0.16, 0.17, 0.2)
const BEAK_YELLOW: Color = Color(1.0, 0.8, 0.1)
const EYE_BLACK: Color = Color(0.04, 0.04, 0.05)
const FEET_ORANGE: Color = Color(0.95, 0.55, 0.2)

var state: State = State.CIRCLE
## Item roubado (largado se a gaivota for abatida).
var stolen: CarriedItem = null
## Replicado: leva um item no bico (os clientes só mostram um item genérico).
var has_stolen: bool = false:
	set(value):
		has_stolen = value
		if not has_simulation_authority() and is_node_ready():
			_show_loot()

var _orbit_angle: float = 0.0
var _orbit_dir: float = 1.0
var _circle_left: float = 5.0
var _state_time: float = 0.0
var _dives: int = 0
var _leave_timer: float = -1.0
var _escape_dir: Vector3 = Vector3.FORWARD
var _escape_start: Vector3 = Vector3.ZERO
var _flap_time: float = 0.0
var _fall_ground_y: float = 0.0
var _wing_left: Node3D = null
var _wing_right: Node3D = null
var _loot_visual: MeshInstance3D = null
## Replicado (#57): ponto do mergulho kamikaze / centro da espiral (aviso nos clientes).
var net_dive_point: Vector3 = Vector3.ZERO:
	set(value):
		net_dive_point = value
		if not has_simulation_authority() and is_node_ready():
			_refresh_dive_warning()
var _dive_warning: GroundWarning = null
var _hit_done: bool = false


func _ready() -> void:
	super._ready()
	_build_model()
	_dive_warning = GroundWarning.new()
	add_child(_dive_warning)
	SFX.play_at(SFX.SEAGULL_CAW, global_position, 2.0)
	_orbit_dir = 1.0 if randf() < 0.5 else -1.0
	_circle_left = randf_range(circle_time_min, circle_time_max)
	var target: Node3D = _update_target(0.0)
	if target != null:
		var rel: Vector3 = global_position - target.global_position
		_orbit_angle = atan2(rel.z, rel.x)


func _enemy_physics(delta: float) -> void:
	_state_time += delta
	if _leave_timer >= 0.0:
		_leave_timer -= delta
		if _leave_timer <= 0.0:
			queue_free()
			return

	match state:
		State.CIRCLE:
			_process_circle(delta)
		State.DIVE:
			_process_dive(delta)
		State.ESCAPE:
			_process_escape(delta)
		State.FALL:
			_process_fall(delta)
		State.WAIT_LOOT:
			_process_wait_loot(delta)
		State.KAMIKAZE_TELEGRAPH:
			_process_kamikaze_telegraph(delta)
		State.KAMIKAZE:
			_process_kamikaze(delta)
		State.STUCK:
			_process_stuck(delta)
		State.SPIRAL_TELEGRAPH, State.SPIRAL:
			_process_spiral(delta)

	_animate_wings(delta)


func _enter_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	_hit_done = false
	_refresh_dive_warning()


# ---------------------------------------------------------------------------
# Estados
# ---------------------------------------------------------------------------

func _process_circle(delta: float) -> void:
	var target: Node3D = _update_target(delta)
	if target == null:
		_start_escape(global_position - Vector3(0.0, 0.0, 1.0))
		return
	_orbit_angle += _orbit_dir * (fly_speed / circle_radius) * delta
	var goal: Vector3 = target.global_position + Vector3(cos(_orbit_angle), 0.0, sin(_orbit_angle)) * circle_radius
	goal.y = target.global_position.y + circle_height + sin(_state_time * 0.8) * 0.6
	_fly_towards(goal, fly_speed * 1.3, delta)

	_circle_left -= delta
	if _circle_left <= 0.0:
		_dives += 1
		SFX.play_at(SFX.SEAGULL_DIVE, global_position)
		_enter_state(_choose_dive(target))


func _process_dive(delta: float) -> void:
	var target: Node3D = _update_target(delta)
	if target == null or _state_time > MAX_DIVE_TIME:
		_after_failed_dive()
		return
	var chest: Vector3 = target.global_position + CHEST_OFFSET
	_fly_towards(chest, dive_speed, delta, 6.0)
	if global_position.distance_to(chest) <= steal_distance:
		_grab(target)


func _grab(target: Node3D) -> void:
	if target.has_method("_steal_from"):
		# Jogador: a mochila é do dono; espera pela resposta (request_seagull_loot).
		_enter_state(State.WAIT_LOOT)
		var owner_id: int = target.get_multiplayer_authority()
		if not NetVisibility.is_online(multiplayer) or owner_id == multiplayer.get_unique_id():
			target.call("_steal_from", get_path())
		else:
			target.rpc_id(owner_id, &"_steal_from", get_path())
		return
	var loot: CarriedItem = null
	if target.has_method("steal_loot"):
		loot = target.call("steal_loot") as CarriedItem
	_on_loot_reply(loot, target)


## Host: resposta do dono da mochila (contrato #5 F). `data` = CarriedItem.to_dict(), ou {}
## se não havia nada para roubar. Só aceita do dono do alvo (ou chamada local no host).
@rpc("any_peer", "call_remote", "reliable")
func request_seagull_loot(data: Dictionary) -> void:
	if not has_simulation_authority():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var target: Node3D = _target if is_instance_valid(_target) else null
	if sender != 0 and (target == null or target.get_multiplayer_authority() != sender):
		return
	var loot: CarriedItem = CarriedItem.from_dict(data) if not data.is_empty() else null
	if state != State.WAIT_LOOT or not is_alive():
		# Já não está à espera (abatida, desistiu): o item não se perde, cai aqui.
		if loot != null and get_parent() != null:
			ItemPickup.spawn(get_parent(), loot, global_position, Vector3.UP)
		return
	_on_loot_reply(loot, target)


func _on_loot_reply(loot: CarriedItem, target: Node3D) -> void:
	if loot != null:
		stolen = loot
		has_stolen = true
		SFX.play_at(SFX.SEAGULL_CAW, global_position)
		_show_loot()
		_start_escape(target.global_position if target != null else global_position)
		return
	if target != null and target.has_method("take_damage"):
		_deal_damage(target, peck_damage)
	_after_failed_dive()


## À espera da resposta do dono: paira junto ao jogador.
func _process_wait_loot(delta: float) -> void:
	var target: Node3D = _target if is_instance_valid(_target) else null
	if target != null:
		_fly_towards(target.global_position + CHEST_OFFSET + Vector3.UP * 0.6, fly_speed * 0.5, delta)
	if _state_time > LOOT_REPLY_TIMEOUT:
		_after_failed_dive()


func _after_failed_dive() -> void:
	if _dives >= max_dives:
		var target: Node3D = _target if is_instance_valid(_target) else null
		_start_escape(target.global_position if target != null else global_position + Vector3.FORWARD)
		return
	_circle_left = randf_range(circle_time_min, circle_time_max)
	_enter_state(State.CIRCLE)


func _start_escape(away_from: Vector3) -> void:
	var dir: Vector3 = global_position - away_from
	dir.y = 0.0
	if dir.length_squared() < 0.01:
		dir = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	_escape_dir = dir.normalized()
	_escape_start = global_position
	if _leave_timer < 0.0:
		_leave_timer = despawn_after
	_enter_state(State.ESCAPE)


func _process_escape(delta: float) -> void:
	var travelled: float = Vector2(global_position.x - _escape_start.x, global_position.z - _escape_start.z).length()
	var goal: Vector3 = global_position + _escape_dir * 5.0
	goal.y = _escape_start.y + 9.0
	if travelled >= escape_distance:
		# Já longe: plana em círculos largos até desaparecer
		_escape_dir = _escape_dir.rotated(Vector3.UP, 0.6 * delta)
		_fly_towards(goal, fly_speed, delta)
	else:
		_fly_towards(goal, escape_speed, delta)


## Replica também has_stolen (o item no bico).
func setup_network() -> void:
	super.setup_network()
	_add_synced_property(".:has_stolen")
	_add_synced_property(".:net_dive_point")


# ---------------------------------------------------------------------------
# #57: kamikaze e bico espetado
# ---------------------------------------------------------------------------

## Que mergulho fazer (o corvo troca o kamikaze pela espiral). O 2.º, 4.º... é kamikaze, mas
## nunca com um item no bico.
func _choose_dive(target: Node3D) -> State:
	if has_stolen or _dives % 2 == 1:
		return State.DIVE
	net_dive_point = _ground_point(target.global_position)
	return State.KAMIKAZE_TELEGRAPH


func _ground_point(p: Vector3) -> Vector3:
	return Vector3(p.x, _ground_height(p, p.y), p.z)


## Pára no ar por cima do ponto, a gritar, antes de mergulhar a pique.
func _process_kamikaze_telegraph(delta: float) -> void:
	_fly_towards(net_dive_point + Vector3.UP * 6.0, fly_speed * 1.5, delta, 5.0)
	_dive_warning.pulse(delta)
	if _state_time >= KAMIKAZE_TELEGRAPH_TIME:
		SFX.play_at(SFX.SEAGULL_CAW, global_position, 4.0)
		_enter_state(State.KAMIKAZE)


func _process_kamikaze(delta: float) -> void:
	var to: Vector3 = net_dive_point + Vector3.UP * 0.25 - global_position
	if to.length() > 0.3 and _state_time < 2.0:
		velocity = to.normalized() * KAMIKAZE_SPEED
		global_position += velocity * minf(delta, to.length() / KAMIKAZE_SPEED)
		_face_velocity(delta * 3.0)
		# Apanha quem estiver no caminho, já perto do chão
		if not _hit_done and to.length() < 3.0:
			for p: Node3D in _players_within(global_position, KAMIKAZE_RADIUS):
				_hit_kamikaze(p)
		return
	# Chegou ao chão: acerta ou espeta-se.
	if not _hit_done:
		for p: Node3D in _players_within(net_dive_point, KAMIKAZE_RADIUS):
			_hit_kamikaze(p)
	if _hit_done:
		_after_failed_dive()
	else:
		global_position = net_dive_point + Vector3.UP * 0.25
		velocity = Vector3.ZERO
		spawn_particles(net_dive_point + Vector3.UP * 0.1, Color(0.85, 0.74, 0.5), 16, 3.0)
		SFX.play_at(SFX.EMERGE_SAND, net_dive_point, 2.0)
		_enter_state(State.STUCK)


func _hit_kamikaze(p: Node3D) -> void:
	if _hit_done:
		return
	_hit_done = true
	_deal_damage(p, KAMIKAZE_DAMAGE)
	var dir: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	dir = dir.normalized() if dir.length_squared() > 0.01 else Vector3.FORWARD
	_knockback(p, dir * 7.0 + Vector3.UP * 6.0, 0.06)
	SFX.play_at(SFX.SEAGULL_CAW, global_position, 4.0)


## Bico espetado na areia: a espernear (rabo para o ar); presa fácil até se soltar.
func _process_stuck(delta: float) -> void:
	velocity = Vector3.ZERO
	_animate_stuck(delta)
	if _state_time >= STUCK_TIME:
		spawn_particles(global_position, Color(0.85, 0.74, 0.5), 10, 2.5)
		rotation.z = 0.0
		velocity = Vector3.UP * 4.0
		_after_failed_dive()


func _animate_stuck(_delta: float) -> void:
	rotation.x = -1.25 + sin(_state_time * 9.0) * 0.08
	rotation.z = sin(_state_time * 16.0) * 0.3
	if _wing_left != null:
		var f: float = sin(_state_time * 22.0) * 0.6
		_wing_left.rotation = Vector3(0.0, 0.0, f)
		_wing_right.rotation = Vector3(0.0, 0.0, -f)


func is_beak_stuck() -> bool:
	return state == State.STUCK


## Espiral do bando (só o corvo a usa; a gaivota nunca escolhe este estado).
func _process_spiral(_delta: float) -> void:
	_after_failed_dive()


func _refresh_dive_warning() -> void:
	if _dive_warning == null:
		return
	match state:
		State.KAMIKAZE_TELEGRAPH, State.KAMIKAZE:
			_dive_warning.show_circle(net_dive_point, KAMIKAZE_RADIUS)
		_:
			_warning_for_state()


## Ganchos para a subclasse mostrar avisos próprios.
func _warning_for_state() -> void:
	_dive_warning.hide_warning()


## Abatida: cai a rodopiar e, ao tocar no chão, larga o item roubado.
func _process_fall(delta: float) -> void:
	velocity.y -= _gravity * delta
	velocity.x = move_toward(velocity.x, 0.0, 2.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 2.0 * delta)
	global_position += velocity * delta
	rotation.z += delta * 8.0
	if global_position.y <= _fall_ground_y + 0.15 or _state_time > 6.0:
		global_position.y = maxf(global_position.y, _fall_ground_y + 0.15)
		_land_and_drop()


func _land_and_drop() -> void:
	if stolen != null and get_parent() != null:
		ItemPickup.spawn(get_parent(), stolen, global_position + Vector3.UP * 0.3,
			Vector3(randf_range(-0.4, 0.4), 1.2, randf_range(-0.4, 0.4)))
		stolen = null
	spawn_particles(global_position, WHITE, 22, 2.2)
	queue_free()


# ---------------------------------------------------------------------------
# Ganchos da EnemyBase
# ---------------------------------------------------------------------------

## Atordoada (rede): fica a pairar no sítio, a bater as asas devagar.
func _stunned_physics(delta: float) -> void:
	velocity = velocity.move_toward(Vector3.ZERO, 12.0 * delta)
	global_position += velocity * delta
	_animate_wings(delta * 0.3)


func _on_stun_ended() -> void:
	if state == State.DIVE:
		_after_failed_dive()


func _on_flee_started() -> void:
	if state != State.FALL:
		_start_escape(_flee_origin)


## Morte: não desaparece logo — cai e só depois larga o item.
func _on_died() -> void:
	_fall_ground_y = _find_ground_y()
	velocity = Vector3(velocity.x * 0.3, 1.0, velocity.z * 0.3)
	spawn_particles(global_position, WHITE, 14, 1.8)
	_enter_state(State.FALL)
	# _dead bloqueia _enemy_physics; a queda corre no seu próprio processo
	set_physics_process(false)
	set_process(true)


func _process(delta: float) -> void:
	if state == State.FALL and _dead:
		_state_time += delta
		_process_fall(delta)
	elif not has_simulation_authority():
		_state_time += delta
		if _dive_warning != null and _dive_warning.visible:
			_dive_warning.pulse(delta)
		if state == State.STUCK:
			_animate_stuck(delta)


## Cliente: estado novo do host (aviso no chão e bico espetado).
func _on_remote_state(_new_state: int) -> void:
	_state_time = 0.0
	_refresh_dive_warning()
	if state != State.STUCK and state != State.FALL:
		rotation.z = 0.0


func _find_ground_y() -> float:
	if not is_inside_tree():
		return global_position.y - 8.0
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		global_position, global_position + Vector3.DOWN * 60.0, ground_mask)
	var hit: Dictionary = space.intersect_ray(query)
	if not hit.is_empty():
		return (hit["position"] as Vector3).y
	return global_position.y - 8.0


# ---------------------------------------------------------------------------
# Voo
# ---------------------------------------------------------------------------

## Voo sem colisões (mask 0): ajusta a velocidade para o objetivo e orienta-se pelo movimento.
func _fly_towards(goal: Vector3, speed: float, delta: float, steer: float = STEER) -> void:
	var to_goal: Vector3 = goal - global_position
	var desired: Vector3 = to_goal.normalized() * speed if to_goal.length() > 0.05 else Vector3.ZERO
	velocity = velocity.lerp(desired, clampf(steer * delta, 0.0, 1.0))
	global_position += velocity * delta
	_face_velocity(delta)


func _face_velocity(delta: float) -> void:
	var flat: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	if flat.length_squared() < 0.01:
		return
	var yaw: float = atan2(-flat.x, -flat.z)
	rotation.y = lerp_angle(rotation.y, yaw, clampf(6.0 * delta, 0.0, 1.0))
	var pitch: float = atan2(velocity.y, flat.length())
	rotation.x = lerpf(rotation.x, clampf(pitch, -0.9, 0.6), clampf(5.0 * delta, 0.0, 1.0))
	# Inclina nas curvas
	var turn: float = clampf(-_orbit_dir * 0.35, -0.5, 0.5) if state == State.CIRCLE else 0.0
	rotation.z = lerpf(rotation.z, turn, clampf(4.0 * delta, 0.0, 1.0))


## Cliente: as asas batem sempre (mais devagar a planar).
func _animate_remote(delta: float, speed: float) -> void:
	_animate_wings(delta * (1.0 if speed > 2.0 else 0.6))


func _animate_wings(delta: float) -> void:
	if _wing_left == null:
		return
	var freq: float = 7.0
	var amp: float = 0.25
	match state:
		State.DIVE:
			freq = 0.0
			amp = 0.0
		State.ESCAPE:
			freq = 12.0
			amp = 0.6
		State.FALL:
			freq = 20.0
			amp = 0.3
	_flap_time += delta * freq
	var flap: float = sin(_flap_time) * amp
	# Em mergulho as asas recolhem para trás
	var tuck: float = 0.55 if state == State.DIVE else 0.0
	_wing_left.rotation = Vector3(0.0, -tuck, flap)
	_wing_right.rotation = Vector3(0.0, tuck, -flap)


# ---------------------------------------------------------------------------
# Modelo low-poly facetado (SurfaceTool): branca, asas cinza com pontas pretas, bico amarelo
# ---------------------------------------------------------------------------

func _build_model() -> void:
	var mat: ShaderMaterial = LowPolyMesh.make_material()
	_register_flash_material(mat)

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Corpo e cauda
	LowPolyMesh.prism(st, Vector3(0.0, 0.0, 0.24), Vector3(0.0, 0.02, -0.2), 0.1, 0.12, 6, WHITE)
	LowPolyMesh.box(st, Vector3(0.0, 0.03, 0.36), Vector3(0.17, 0.025, 0.2), Basis(Vector3.RIGHT, -0.1), WING_GREY)
	# Cabeça, olhos e bico
	LowPolyMesh.box(st, Vector3(0.0, 0.09, -0.27), Vector3(0.14, 0.14, 0.15), Basis.IDENTITY, WHITE)
	LowPolyMesh.box(st, Vector3(-0.072, 0.12, -0.3), Vector3(0.012, 0.03, 0.03), Basis.IDENTITY, EYE_BLACK)
	LowPolyMesh.box(st, Vector3(0.072, 0.12, -0.3), Vector3(0.012, 0.03, 0.03), Basis.IDENTITY, EYE_BLACK)
	LowPolyMesh.prism(st, Vector3(0.0, 0.07, -0.34), Vector3(0.0, 0.055, -0.48), 0.035, 0.0, 4, BEAK_YELLOW)
	# Patas recolhidas
	LowPolyMesh.box(st, Vector3(-0.04, -0.1, 0.12), Vector3(0.03, 0.03, 0.08), Basis.IDENTITY, FEET_ORANGE)
	LowPolyMesh.box(st, Vector3(0.04, -0.1, 0.12), Vector3(0.03, 0.03, 0.08), Basis.IDENTITY, FEET_ORANGE)
	add_child(LowPolyMesh.commit(st, "Body", mat))

	_wing_left = _build_wing(-1.0, mat)
	_wing_right = _build_wing(1.0, mat)


func _build_wing(side: float, mat: Material) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.name = "WingLeft" if side < 0.0 else "WingRight"
	pivot.position = Vector3(0.09 * side, 0.05, -0.02)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyMesh.box(st, Vector3(0.2 * side, 0.0, 0.0), Vector3(0.4, 0.025, 0.21), Basis.IDENTITY, WING_GREY)
	LowPolyMesh.box(st, Vector3(0.5 * side, 0.0, 0.03), Vector3(0.22, 0.02, 0.14), Basis(Vector3.UP, 0.15 * side), WING_TIP)
	pivot.add_child(LowPolyMesh.commit(st, "Mesh", mat))
	add_child(pivot)
	return pivot


## Mostra o item roubado pendurado no bico.
## Item no bico. Num cliente não há `stolen` (só has_stolen): mostra um item genérico.
func _show_loot() -> void:
	if _loot_visual != null or (stolen == null and not has_stolen):
		return
	_loot_visual = MeshInstance3D.new()
	_loot_visual.name = "Loot"
	var cube: BoxMesh = BoxMesh.new()
	cube.size = Vector3(0.12, 0.12, 0.12)
	_loot_visual.mesh = cube
	if stolen != null:
		_loot_visual.material_override = ItemPickup.make_material(stolen.item, stolen.is_rare_variant)
	_loot_visual.position = Vector3(0.0, -0.06, -0.5)
	add_child(_loot_visual)

