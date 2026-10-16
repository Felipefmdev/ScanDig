class_name AncientWalrus
extends EnemyBase

## Morsa Anciã (#43, #57): chefe de missão da Geleira Eterna.
## Inspirada fielmente na referência visual morsa_ancia.jpg:
##  - Quepe naval de capitão desgastado com insígnia de âncora dourada e estalactites na aba;
##  - Couro cinzento-azulado calejado por cicatrizes e manchas de geada polar;
##  - Bigode farto grisalho, uma presa comprida de marfim e uma presa partida;
##  - Ataques caóticos estilo "How to Fish":
##      * DESLIZE RICOCHETE: atira-se de barriga e ricocheteia pelo gelo como pinball;
##      * BLOCOS DE GELO: arremessa calhaus de gelo pesados em leque na direção do jogador;
##      * ESMAGAR: barrigada estrondosa telegrafada com círculo que projeta toda a gente;
##  - Troféu ao morrer: 'bussola_antiga' (e 'medalha_polar').

signal boss_defeated(boss_id: StringName)
signal health_changed(current: float, max_value: float)

enum State { EMERGE, WALK, SLIDE_TELE, SLIDE_RICOCHET, THROW_ICE_TELE, THROW_ICE, CRUSH_TELE, CRUSH, RECOVER, DYING }

const BOSS_ID: StringName = &"ancient_walrus"
const BOSS_NAME: String = "MORSA ANCIÃ"
const GROUP_BOSSES: StringName = &"bosses"
const TROPHY_ITEM_ID: String = "bussola_antiga"
const SECONDARY_TROPHY_ID: String = "medalha_polar"

const SKIN_GREY: Color = Color(0.42, 0.48, 0.54)
const SKIN_DARK: Color = Color(0.30, 0.35, 0.40)
const FROST_WHITE: Color = Color(0.85, 0.92, 0.96)
const CAPTAIN_NAVY: Color = Color(0.18, 0.22, 0.28)
const GOLD_ANCHOR: Color = Color(0.88, 0.72, 0.22)
const MOUSTACHE_GREY: Color = Color(0.75, 0.80, 0.84)
const TUSK_IVORY: Color = Color(0.92, 0.88, 0.78)
const ICE_BLOCK: Color = Color(0.62, 0.84, 0.94)
const EYE_WHITE: Color = Color(0.96, 0.96, 0.96)
const EYE_PUPIL: Color = Color(0.10, 0.10, 0.12)

const CRUSH_RADIUS: float = 4.2
const SLIDE_SPEED: float = 12.0
const PHASE_TWO_RATIO: float = 0.5

@export var move_speed: float = 1.3
@export var turn_speed: float = 3.0
@export var crush_damage: float = 22.0
@export var slide_damage: float = 20.0
@export var ice_block_damage: float = 16.0
@export var slide_tele_time: float = 1.0
@export var crush_tele_time: float = 1.1
@export var throw_tele_time: float = 0.9
@export var recover_time: float = 2.2
@export var max_bounces: int = 4
@export var emerge_time: float = 2.2

var state: State = State.EMERGE
var phase: int = 1
var net_attack_dir: Vector3 = Vector3.FORWARD:
	set(value):
		net_attack_dir = value
		if not has_simulation_authority() and is_node_ready():
			_refresh_remote_visuals()

var net_attack_point: Vector3 = Vector3.ZERO:
	set(value):
		net_attack_point = value
		if not has_simulation_authority() and is_node_ready():
			_refresh_remote_visuals()

var _state_time: float = 0.0
var _surface_y: float = 0.0
var _hit_done: bool = false
var _hit_targets: Array[Node] = []
var _attack_cycle: int = 0
var _bounce_count: int = 0
var _slide_vector: Vector3 = Vector3.FORWARD
var _anim_time: float = 0.0

var _hud: BossHud = null
var _warning: GroundWarning = null
var _body: Node3D = null
var _flipper_left: Node3D = null
var _flipper_right: Node3D = null
var _ice_projectiles: Array[MeshInstance3D] = []
var _projectile_vels: Array[Vector3] = []
var _mat: ShaderMaterial = null


func _ready() -> void:
	super._ready()
	add_to_group(GROUP_BOSSES)
	max_health = 1150.0
	health = 1150.0
	death_color = SKIN_GREY
	stun_fx_height = 2.4
	_surface_y = global_position.y
	_build_model()
	_hud = BossHud.create("⚓ " + BOSS_NAME, max_health, Color(0.40, 0.65, 0.85))
	add_child(_hud)
	_warning = GroundWarning.new()
	add_child(_warning)
	boss_defeated.connect(_report_defeat_to_core)
	_enter_state(State.EMERGE)


func setup_network() -> void:
	super.setup_network()
	_add_synced_property(".:net_attack_dir")
	_add_synced_property(".:net_attack_point")


func _enemy_physics(delta: float) -> void:
	_state_time += delta
	_anim_time += delta

	_update_ice_projectiles(delta)

	var speed_k: float = 0.85 if phase == 2 else 1.0

	match state:
		State.EMERGE:
			var t: float = clampf(_state_time / emerge_time, 0.0, 1.0)
			global_position.y = _surface_y - 2.5 * (1.0 - t)
			if t >= 1.0:
				_hud.visible = true
				_enter_state(State.WALK)
		State.WALK:
			_process_walk(delta)
		State.SLIDE_TELE:
			_warning.pulse(delta)
			_turn_towards(net_attack_dir, 0.0, turn_speed * 1.5, delta)
			if _state_time >= slide_tele_time * speed_k:
				_enter_state(State.SLIDE_RICOCHET)
		State.SLIDE_RICOCHET:
			_process_slide_ricochet(delta)
		State.THROW_ICE_TELE:
			_warning.pulse(delta)
			_turn_towards(net_attack_dir, 0.0, turn_speed * 1.5, delta)
			if _state_time >= throw_tele_time * speed_k:
				_enter_state(State.THROW_ICE)
		State.THROW_ICE:
			_process_throw_ice(delta)
		State.CRUSH_TELE:
			_warning.pulse(delta)
			if _state_time >= crush_tele_time * speed_k:
				_enter_state(State.CRUSH)
		State.CRUSH:
			_process_crush(delta)
		State.RECOVER:
			_process_recover(delta)

	_animate(delta)


func _process(delta: float) -> void:
	if not has_simulation_authority() and state != State.DYING:
		_state_time += delta
		_hud.set_health(health)
		if _warning.visible:
			_warning.pulse(delta)
	elif state == State.DYING and _dead:
		_process_dying(delta)


func _enter_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	_hit_done = false
	_hit_targets.clear()

	match state:
		State.EMERGE:
			global_position.y = _surface_y - 2.5
		State.WALK:
			_warning.hide_warning()
		State.SLIDE_TELE:
			velocity = Vector3.ZERO
			net_attack_point = global_position
			var target: Node3D = _update_target(0.0)
			if target != null:
				var to: Vector3 = target.global_position - global_position
				to.y = 0.0
				net_attack_dir = to.normalized() if to.length() > 0.1 else -transform.basis.z
			else:
				net_attack_dir = -transform.basis.z
			_slide_vector = net_attack_dir
			_bounce_count = 0
			_warning.show_line(global_position, net_attack_dir, 16.0, 2.2)
		State.SLIDE_RICOCHET:
			_warning.hide_warning()
			SFX.play_at(SFX.EMERGE_SAND, global_position, 4.0)
		State.THROW_ICE_TELE:
			velocity = Vector3.ZERO
			net_attack_point = global_position
			var target: Node3D = _update_target(0.0)
			if target != null:
				var to: Vector3 = target.global_position - global_position
				to.y = 0.0
				net_attack_dir = to.normalized() if to.length() > 0.1 else -transform.basis.z
			else:
				net_attack_dir = -transform.basis.z
			_warning.show_line(global_position, net_attack_dir, 14.0, 3.5)
		State.THROW_ICE:
			_warning.hide_warning()
		State.CRUSH_TELE:
			velocity = Vector3.ZERO
			net_attack_point = global_position
			_warning.show_circle(global_position, CRUSH_RADIUS)
		State.CRUSH:
			_warning.hide_warning()
		State.RECOVER:
			_warning.hide_warning()
			velocity = Vector3.ZERO


func _process_walk(delta: float) -> void:
	_apply_gravity(delta)
	var target: Node3D = _update_target(delta)
	if target == null:
		velocity.x = move_toward(velocity.x, 0.0, delta * 4.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 4.0)
		move_and_slide()
		return

	var to: Vector3 = target.global_position - global_position
	to.y = 0.0
	var dist: float = to.length()
	var dir: Vector3 = to.normalized() if dist > 0.1 else Vector3.ZERO

	_turn_towards(dir, 0.0, turn_speed, delta)

	# Ciclo de 3 ataques cómicos
	if _state_time >= 2.0:
		_attack_cycle += 1
		match _attack_cycle % 3:
			1:
				_enter_state(State.SLIDE_TELE)
			2:
				_enter_state(State.THROW_ICE_TELE)
			0:
				_enter_state(State.CRUSH_TELE)
		return

	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	move_and_slide()


func _process_slide_ricochet(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = _slide_vector.x * SLIDE_SPEED
	velocity.z = _slide_vector.z * SLIDE_SPEED
	move_and_slide()

	# Faíscas no gelo
	if randf() < 0.4:
		spawn_particles(global_position + Vector3.DOWN * 0.1, FROST_WHITE, 4, 2.0)

	# Atropelamento de jogadores com projeção
	for p: Node3D in _all_players():
		if _hit_targets.has(p):
			continue
		var d: Vector3 = p.global_position - global_position
		d.y = 0.0
		if d.length() <= 2.2:
			_hit_targets.append(p)
			_deal_damage(p, slide_damage)
			_knockback(p, _slide_vector * 12.0 + Vector3.UP * 7.0, 0.2)
			spawn_particles(p.global_position + Vector3.UP * 0.8, FROST_WHITE, 15, 4.0)

	# Ricochete nas paredes estilo How to Fish
	if is_on_wall():
		var wall_normal: Vector3 = get_wall_normal()
		wall_normal.y = 0.0
		if wall_normal.length_squared() > 0.01:
			_slide_vector = _slide_vector.bounce(wall_normal.normalized()).normalized()
			_bounce_count += 1
			SFX.play_at(SFX.SHELL_KNOCK, global_position, 6.0)
			spawn_particles(global_position + Vector3.UP * 0.5, ICE_BLOCK, 20, 5.0)
			_hit_targets.clear()

	var max_allowed_bounces: int = max_bounces + (2 if phase == 2 else 0)
	if _bounce_count >= max_allowed_bounces or _state_time >= 4.5:
		_enter_state(State.RECOVER)


func _process_throw_ice(delta: float) -> void:
	_apply_gravity(delta)
	move_and_slide()

	if not _hit_done and _state_time >= 0.1:
		_hit_done = true
		_execute_throw_ice()

	if _state_time >= 0.8:
		_enter_state(State.WALK)


func _execute_throw_ice() -> void:
	SFX.play_at(SFX.EMERGE_SAND, global_position, 6.0)
	var count: int = 4 if phase == 2 else 3
	for i: int in count:
		var spread: float = -0.4 + float(i) * (0.8 / maxf(1.0, float(count - 1)))
		var shoot_dir: Vector3 = net_attack_dir.rotated(Vector3.UP, spread).normalized()
		_spawn_ice_block(global_position + Vector3.UP * 1.2 + shoot_dir * 1.5, shoot_dir)


func _spawn_ice_block(spawn_pos: Vector3, dir: Vector3) -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyMesh.box(st, Vector3.ZERO, Vector3(0.9, 0.8, 0.9), Basis.IDENTITY, ICE_BLOCK)
	LowPolyMesh.prism(st, Vector3(0.0, 0.4, 0.0), Vector3(0.0, 0.7, 0.0), 0.35, 0.0, 4, FROST_WHITE)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = ToonKit.commit(st)
	mi.material_override = _mat
	mi.top_level = true
	mi.global_position = spawn_pos
	add_child(mi)

	_ice_projectiles.append(mi)
	_projectile_vels.append(dir * 10.0 + Vector3.UP * 2.5)


func _update_ice_projectiles(delta: float) -> void:
	for i: int in range(_ice_projectiles.size() - 1, -1, -1):
		var proj: MeshInstance3D = _ice_projectiles[i]
		if not is_instance_valid(proj):
			_ice_projectiles.remove_at(i)
			_projectile_vels.remove_at(i)
			continue

		var vel: Vector3 = _projectile_vels[i]
		vel.y -= 9.8 * delta
		_projectile_vels[i] = vel
		proj.global_position += vel * delta
		proj.rotate_x(5.0 * delta)
		proj.rotate_y(4.0 * delta)

		# Colisão com jogadores
		var hit_player: bool = false
		for p: Node3D in _all_players():
			if p.global_position.distance_squared_to(proj.global_position) <= 2.25:
				_deal_damage(p, ice_block_damage)
				_knockback(p, vel.normalized() * 9.0 + Vector3.UP * 4.0, 0.15)
				hit_player = true
				break

		# Bate no chão ou jogador e quebra
		if hit_player or proj.global_position.y <= _surface_y + 0.2:
			SFX.play_at(SFX.SHELL_KNOCK, proj.global_position, 4.0)
			spawn_particles(proj.global_position, ICE_BLOCK, 18, 4.5)
			proj.queue_free()
			_ice_projectiles.remove_at(i)
			_projectile_vels.remove_at(i)


func _process_crush(delta: float) -> void:
	_apply_gravity(delta)
	move_and_slide()

	if not _hit_done and _state_time >= 0.1:
		_hit_done = true
		_execute_crush()

	if _state_time >= 0.6:
		_enter_state(State.RECOVER)


func _execute_crush() -> void:
	SFX.play_at(SFX.EMERGE_SAND, global_position, 8.0)
	spawn_particles(global_position + Vector3.DOWN * 0.1, FROST_WHITE, 35, 6.0)

	for p: Node3D in _players_within(global_position, CRUSH_RADIUS):
		_deal_damage(p, crush_damage)
		var away: Vector3 = p.global_position - global_position
		away.y = 0.0
		var push: Vector3 = away.normalized() if away.length() > 0.1 else -transform.basis.z
		_knockback(p, push * 10.0 + Vector3.UP * 10.0, 0.3)


func _process_recover(delta: float) -> void:
	_apply_gravity(delta)
	velocity = Vector3.ZERO
	move_and_slide()
	if _state_time >= recover_time:
		_enter_state(State.WALK)


func is_exhausted() -> bool:
	return state == State.RECOVER


func _modify_damage(amount: float, _from: Vector3) -> float:
	if is_exhausted():
		return amount * 1.8
	return amount


func _can_take_damage() -> bool:
	return state != State.EMERGE and state != State.DYING


func _can_be_stunned() -> bool:
	return false


func flee_from(_origin: Vector3, _seconds: float) -> void:
	pass


func take_damage(amount: float, from: Vector3 = Vector3.INF) -> void:
	super.take_damage(amount, from)
	if _dead or not has_simulation_authority():
		return
	_hud.set_health(health)
	health_changed.emit(health, max_health)

	if phase == 1 and health < max_health * PHASE_TWO_RATIO:
		phase = 2
		spawn_particles(global_position + Vector3.UP * 1.5, FROST_WHITE, 30, 5.0)


func wake_immediately() -> void:
	if state == State.EMERGE:
		global_position.y = _surface_y
		_hud.visible = true
		_enter_state(State.WALK)


func _on_died() -> void:
	_hud.set_health(0.0)
	_enter_state(State.DYING)
	set_physics_process(false)


func _process_dying(_delta: float) -> void:
	var t: float = clampf(_state_time / 2.6, 0.0, 1.0)
	_body.position.y = -2.0 * t * t
	_body.rotation.z = lerpf(0.0, 0.45, t)

	if _state_time >= 1.2 and _state_time - get_process_delta_time() < 1.2:
		_hud.visible = false
		spawn_particles(global_position + Vector3.UP * 1.5, FROST_WHITE, 50, 6.0)
		if has_simulation_authority():
			QuestRewards.drop_item(get_tree(), TROPHY_ITEM_ID, global_position + Vector3.UP * 1.5)
			# Também larga a medalha polar de recompensa da expedição
			QuestRewards.drop_item(get_tree(), SECONDARY_TROPHY_ID, global_position + Vector3.UP * 1.5 + Vector3.RIGHT * 1.2)
		boss_defeated.emit(BOSS_ID)

	if _state_time >= 3.0:
		for p: MeshInstance3D in _ice_projectiles:
			if is_instance_valid(p):
				p.queue_free()
		queue_free()


func _report_defeat_to_core(boss_id: StringName) -> void:
	if has_simulation_authority() and GameState.instance != null:
		GameState.instance.request_report_boss_defeated(String(boss_id))


func _refresh_remote_visuals() -> void:
	if _warning == null:
		return
	match state:
		State.SLIDE_TELE:
			_warning.show_line(global_position, net_attack_dir, 16.0, 2.2)
		State.THROW_ICE_TELE:
			_warning.show_line(global_position, net_attack_dir, 14.0, 3.5)
		State.CRUSH_TELE:
			_warning.show_circle(global_position, CRUSH_RADIUS)
		_:
			_warning.hide_warning()


func _on_remote_state(new_state: int) -> void:
	state = new_state as State
	_state_time = 0.0
	_hud.visible = state != State.EMERGE and state != State.DYING
	_refresh_remote_visuals()


# ---------------------------------------------------------------------------
# Modelo 3D Low-Poly + ToonKit (referência: morsa_ancia.jpg)
# ---------------------------------------------------------------------------

func _build_model() -> void:
	_mat = LowPolyMesh.make_material()
	_register_flash_material(_mat)

	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Tronco maciço cinzento com cicatrizes
	LowPolyMesh.prism(st, Vector3(0.0, 0.45, 0.7), Vector3(0.0, 0.75, -0.2), 0.55, 0.62, 7, SKIN_GREY)
	LowPolyMesh.prism(st, Vector3(0.0, 0.75, -0.2), Vector3(0.0, 1.15, -0.55), 0.62, 0.48, 7, SKIN_GREY)

	# Manchas de geada e cicatrizes no couro
	LowPolyMesh.box(st, Vector3(0.0, 0.88, 0.2), Vector3(0.85, 0.25, 0.40), Basis.IDENTITY, FROST_WHITE)
	LowPolyMesh.box(st, Vector3(0.25, 1.05, -0.2), Vector3(0.12, 0.35, 0.08), Basis(Vector3.FORWARD, 0.4), SKIN_DARK)
	LowPolyMesh.box(st, Vector3(0.25, 1.05, -0.2), Vector3(0.12, 0.35, 0.08), Basis(Vector3.FORWARD, -0.4), SKIN_DARK)

	# Cabeça robusta de capitão
	LowPolyMesh.prism(st, Vector3(0.0, 1.15, -0.55), Vector3(0.0, 1.25, -0.92), 0.48, 0.38, 6, SKIN_GREY)

	# Focinho e queixo
	LowPolyMesh.box(st, Vector3(0.0, 1.08, -1.05), Vector3(0.50, 0.28, 0.26), Basis.IDENTITY, SKIN_DARK)

	# Bigode grisalho exuberante
	LowPolyMesh.prism(st, Vector3(0.0, 1.12, -0.98), Vector3(0.0, 0.98, -1.16), 0.38, 0.28, 6, MOUSTACHE_GREY)
	LowPolyMesh.box(st, Vector3(0.0, 0.94, -1.12), Vector3(0.56, 0.22, 0.16), Basis.IDENTITY, MOUSTACHE_GREY)

	# Presa esquerda inteira de marfim
	LowPolyMesh.prism(st, Vector3(-0.18, 1.0, -1.08), Vector3(-0.20, 0.22, -1.02), 0.07, 0.018, 4, TUSK_IVORY)
	# Presa direita PARTIDA (referência: morsa_ancia.jpg!)
	LowPolyMesh.prism(st, Vector3(0.18, 1.0, -1.08), Vector3(0.19, 0.65, -1.05), 0.07, 0.045, 4, TUSK_IVORY)
	LowPolyMesh.box(st, Vector3(0.19, 0.63, -1.05), Vector3(0.08, 0.04, 0.08), Basis(Vector3.FORWARD, 0.3), Color(0.85, 0.80, 0.70))

	# Olhos arregalados e experientes
	LowPolyMesh.box(st, Vector3(-0.20, 1.32, -0.88), Vector3(0.11, 0.11, 0.05), Basis.IDENTITY, EYE_WHITE)
	LowPolyMesh.box(st, Vector3(0.20, 1.32, -0.88), Vector3(0.11, 0.11, 0.05), Basis.IDENTITY, EYE_WHITE)
	LowPolyMesh.box(st, Vector3(-0.20, 1.32, -0.91), Vector3(0.05, 0.05, 0.02), Basis.IDENTITY, EYE_PUPIL)
	LowPolyMesh.box(st, Vector3(0.20, 1.32, -0.91), Vector3(0.05, 0.05, 0.02), Basis.IDENTITY, EYE_PUPIL)

	# QUEPE DE CAPITÃO NAVAL (referência: morsa_ancia.jpg)
	# Base e topo do quepe
	LowPolyMesh.prism(st, Vector3(0.0, 1.45, -0.75), Vector3(0.0, 1.62, -0.72), 0.36, 0.42, 7, CAPTAIN_NAVY)
	# Aba do quepe curvada para a frente
	LowPolyMesh.box(st, Vector3(0.0, 1.46, -0.95), Vector3(0.48, 0.06, 0.24), Basis(Vector3.RIGHT, -0.2), CAPTAIN_NAVY)
	# Estalactites de gelo na borda do quepe
	for ice_i: int in 4:
		var x_ice: float = -0.18 + float(ice_i) * 0.12
		LowPolyMesh.prism(st, Vector3(x_ice, 1.44, -1.05), Vector3(x_ice, 1.28, -1.05), 0.025, 0.0, 3, FROST_WHITE)
	# Insígnia da âncora dourada
	LowPolyMesh.box(st, Vector3(0.0, 1.54, -0.96), Vector3(0.14, 0.14, 0.04), Basis.IDENTITY, GOLD_ANCHOR)

	# Barbatanas traseiras com dedos
	LowPolyMesh.box(st, Vector3(-0.32, 0.22, 1.05), Vector3(0.40, 0.08, 0.42), Basis(Vector3.UP, -0.3), SKIN_DARK)
	LowPolyMesh.box(st, Vector3(0.32, 0.22, 1.05), Vector3(0.40, 0.08, 0.42), Basis(Vector3.UP, 0.3), SKIN_DARK)

	_body.add_child(LowPolyMesh.commit(st, "MainMesh", _mat))

	# Barbatanas dianteiras articuladas
	_flipper_left = _build_flipper(-0.54, "FlipperL")
	_flipper_right = _build_flipper(0.54, "FlipperR")

	# Collision Shape de chefe
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(1.6, 1.5, 2.4)
	cs.shape = box
	cs.position = Vector3(0.0, 0.75, 0.0)
	add_child(cs)


func _build_flipper(x: float, flipper_name: String) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.name = flipper_name
	pivot.position = Vector3(x, 0.48, -0.2)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s: float = -1.0 if x < 0.0 else 1.0
	LowPolyMesh.box(st, Vector3(s * 0.22, -0.2, 0.0), Vector3(0.46, 0.10, 0.52), Basis(Vector3.FORWARD, s * -0.28), SKIN_DARK)
	pivot.add_child(LowPolyMesh.commit(st, "FlipperMesh", _mat))
	_body.add_child(pivot)
	return pivot


func _animate(delta: float) -> void:
	if _body == null:
		return

	if state == State.WALK:
		var waddle: float = sin(_anim_time * 4.5) * 0.18
		_body.rotation.z = waddle
		_body.rotation.x = lerp_angle(_body.rotation.x, 0.0, clampf(8.0 * delta, 0.0, 1.0))
		_body.position.y = absf(sin(_anim_time * 4.5)) * 0.1
		if _flipper_left != null:
			_flipper_left.rotation.x = sin(_anim_time * 4.5) * 0.4
		if _flipper_right != null:
			_flipper_right.rotation.x = -sin(_anim_time * 4.5) * 0.4
	elif state == State.SLIDE_TELE:
		# Inclina para a frente no gelo
		_body.rotation.x = lerpf(_body.rotation.x, deg_to_rad(65.0), clampf(8.0 * delta, 0.0, 1.0))
		_body.position.y = lerpf(_body.position.y, -0.2, clampf(8.0 * delta, 0.0, 1.0))
	elif state == State.SLIDE_RICOCHET:
		# Posição rasante de ricochete
		_body.rotation.x = deg_to_rad(75.0)
		_body.position.y = -0.28
		_body.rotation.z = sin(_anim_time * 18.0) * 0.12
	elif state == State.CRUSH_TELE:
		# Ergue o corpão massivo
		_body.rotation.x = -0.55
		_body.position.y = 0.45
	elif state == State.CRUSH:
		# Bate com tudo no gelo
		_body.rotation.x = 0.25
		_body.position.y = -0.15
	elif state == State.RECOVER:
		# Cansado e ofegante
		_body.rotation.x = lerp_angle(_body.rotation.x, 0.0, clampf(5.0 * delta, 0.0, 1.0))
		_body.position.y = lerpf(_body.position.y, 0.0, clampf(5.0 * delta, 0.0, 1.0))
		_body.rotation.z = sin(_anim_time * 6.0) * 0.08
