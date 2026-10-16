class_name Penguin
extends EnemyBase

## Pinguim-Ladrão (#43, #57): travesso habitante da Geleira Eterna.
## Inspirado fielmente na referência visual pinguim_ladrao.jpg:
##  - Corpo redondo azul-ardósia com barriga branca, máscara preta de ladrão e olhos loucos;
##  - Cachecol vermelho ao pescoço e saco de pano às costas para o saque;
##  - Desliza de barriga a alta velocidade pelo gelo estilo "How to Fish", abalroa o jogador
##    com solavanco cómico e tenta roubar/derrubar itens da mochila.

enum State { WADDLE, SLIDE_WINDUP, SLIDE, BUMP, RECOVER, FLEE }

const SLATE_BLUE: Color = Color(0.22, 0.28, 0.35)
const BELLY_WHITE: Color = Color(0.95, 0.94, 0.90)
const BEAK_ORANGE: Color = Color(0.92, 0.54, 0.18)
const MASK_BLACK: Color = Color(0.12, 0.14, 0.16)
const EYE_WHITE: Color = Color(0.96, 0.96, 0.96)
const EYE_PUPIL: Color = Color(0.10, 0.10, 0.12)
const SCARF_RED: Color = Color(0.75, 0.18, 0.18)
const SACK_BROWN: Color = Color(0.65, 0.54, 0.40)
const ICE_SPARK: Color = Color(0.78, 0.92, 0.98)

@export var move_speed: float = 1.7
@export var slide_speed: float = 7.8
@export var turn_speed: float = 5.0
@export var bump_damage: float = 8.0
@export var bump_range: float = 1.3
@export var slide_windup_time: float = 0.5
@export var recover_time: float = 0.8
@export var max_slide_time: float = 2.4

var state: State = State.WADDLE
var net_slide_dir: Vector3 = Vector3.FORWARD
var held_loot: CarriedItem = null

var _state_time: float = 0.0
var _anim_time: float = 0.0
var _slide_dir: Vector3 = Vector3.FORWARD
var _warning: GroundWarning = null

var _body: Node3D = null
var _wing_left: Node3D = null
var _wing_right: Node3D = null
var _foot_left: Node3D = null
var _foot_right: Node3D = null
var _scarf_tail: Node3D = null
var _sack: Node3D = null
var _mat: ShaderMaterial = null


func _ready() -> void:
	super._ready()
	max_health = 45.0
	health = 45.0
	death_color = SLATE_BLUE
	stun_fx_height = 0.9
	_build_model()
	_warning = GroundWarning.new()
	add_child(_warning)
	_enter_state(State.WADDLE)


func setup_network() -> void:
	super.setup_network()
	_add_synced_property(".:net_slide_dir")


func _enemy_physics(delta: float) -> void:
	_state_time += delta
	_anim_time += delta

	match state:
		State.WADDLE:
			_process_waddle(delta)
		State.SLIDE_WINDUP:
			_process_slide_windup(delta)
		State.SLIDE:
			_process_slide(delta)
		State.BUMP:
			_process_bump(delta)
		State.RECOVER:
			_process_recover(delta)
		State.FLEE:
			_process_flee(delta)

	_animate(delta)


func _enter_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0

	match state:
		State.WADDLE:
			_warning.hide_warning()
		State.SLIDE_WINDUP:
			velocity.x = 0.0
			velocity.z = 0.0
			var target: Node3D = _update_target(0.0)
			if target != null:
				var to: Vector3 = target.global_position - global_position
				to.y = 0.0
				_slide_dir = to.normalized() if to.length() > 0.1 else -transform.basis.z
			else:
				_slide_dir = -transform.basis.z
			net_slide_dir = _slide_dir
			_warning.show_line(global_position, _slide_dir, 8.0, 1.2)
		State.SLIDE:
			_warning.hide_warning()
			_slide_dir = net_slide_dir
			SFX.play_at(SFX.FOOTSTEP_SAND, global_position, 1.0, 0.2)
		State.BUMP:
			_warning.hide_warning()
			velocity = -_slide_dir * 3.0 + Vector3.UP * 2.0
		State.RECOVER:
			_warning.hide_warning()
			velocity = Vector3.ZERO
		State.FLEE:
			_warning.hide_warning()


func _process_waddle(delta: float) -> void:
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

	# Se tiver saque na mochila/mão ou estiver a meia distância, prepara o deslize de barriga!
	if dist <= 10.0 and dist >= 2.0:
		_enter_state(State.SLIDE_WINDUP)
		return
	elif dist < 2.0:
		# Perto demais, dá cabeçada/empurrão
		_bump_player(target)
		_enter_state(State.RECOVER)
		return

	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	move_and_slide()


func _process_slide_windup(delta: float) -> void:
	_apply_gravity(delta)
	_warning.pulse(delta)
	_turn_towards(_slide_dir, 0.0, turn_speed * 1.5, delta)
	move_and_slide()
	if _state_time >= slide_windup_time:
		_enter_state(State.SLIDE)


func _process_slide(delta: float) -> void:
	_apply_gravity(delta)

	# Desliza na direção com ligeiro ajuste teleguiado
	var target: Node3D = _update_target(delta)
	if target != null:
		var to: Vector3 = target.global_position - global_position
		to.y = 0.0
		if to.length() > 0.1:
			_slide_dir = _slide_dir.slerp(to.normalized(), clampf(2.5 * delta, 0.0, 1.0)).normalized()
			net_slide_dir = _slide_dir

	_turn_towards(_slide_dir, 0.0, turn_speed * 1.2, delta)
	velocity.x = _slide_dir.x * slide_speed
	velocity.z = _slide_dir.z * slide_speed
	move_and_slide()

	# Faíscas de gelo por debaixo da barriga
	if randf() < 0.3:
		spawn_particles(global_position + Vector3.DOWN * 0.1, ICE_SPARK, 2, 1.5)

	# Verifica colisão com jogadores
	for p: Node3D in _all_players():
		var d: Vector3 = p.global_position - global_position
		d.y = 0.0
		if d.length() <= bump_range:
			_bump_player(p)
			_enter_state(State.BUMP)
			return

	if _state_time >= max_slide_time or is_on_wall():
		_enter_state(State.RECOVER)


func _bump_player(player_node: Node3D) -> void:
	SFX.play_at(SFX.SHELL_KNOCK, global_position, 4.0)
	_deal_damage(player_node, bump_damage)
	# Empurrão clássico estilo How to Fish
	_knockback(player_node, _slide_dir * 11.0 + Vector3.UP * 3.5, 0.15)
	spawn_particles(player_node.global_position + Vector3.UP * 0.5, ICE_SPARK, 10, 4.0)

	# Tenta roubar ou derrubar item da mochila se ainda não tiver nenhum
	if held_loot == null:
		if player_node.has_method("steal_loot"):
			var st: Variant = player_node.call("steal_loot")
			if st is CarriedItem:
				held_loot = st as CarriedItem
				SFX.play_at(SFX.PICKUP, global_position, 5.0)
				_enter_state(State.FLEE)
				return
		elif player_node.has_method("_steal_from"):
			# Multiplayer: avisa o jogador para soltar item
			player_node.call("_steal_from", get_path())


func _process_bump(delta: float) -> void:
	_apply_gravity(delta)
	move_and_slide()
	if _state_time >= 0.4:
		if held_loot != null:
			_enter_state(State.FLEE)
		else:
			_enter_state(State.RECOVER)


func _process_recover(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, delta * 8.0)
	velocity.z = move_toward(velocity.z, 0.0, delta * 8.0)
	move_and_slide()
	if _state_time >= recover_time:
		_enter_state(State.WADDLE)


func _process_flee(delta: float) -> void:
	_apply_gravity(delta)
	var target: Node3D = _update_target(delta)
	var dir: Vector3 = -_slide_dir
	if target != null:
		var away: Vector3 = global_position - target.global_position
		away.y = 0.0
		dir = away.normalized() if away.length() > 0.1 else transform.basis.z

	_turn_towards(dir, 0.0, turn_speed, delta)
	velocity.x = dir.x * (move_speed * 1.5)
	velocity.z = dir.z * (move_speed * 1.5)
	move_and_slide()


func _on_died() -> void:
	super._on_died()
	# Se estava a carregar um item roubado, deixa-o cair no chão
	if held_loot != null and has_simulation_authority():
		var root: PickupsRoot = PickupsRoot.find(get_tree())
		if root != null:
			root.drop(held_loot, global_position + Vector3.UP * 0.4, Vector3.UP * 2.5)
		else:
			var scene: Node = get_tree().current_scene if get_tree() != null else null
			if scene != null:
				ItemPickup.spawn(scene, held_loot, global_position + Vector3.UP * 0.4, Vector3.UP * 2.5)
		held_loot = null


# ---------------------------------------------------------------------------
# Modelo 3D Low-Poly + ToonKit (referência: pinguim_ladrao.jpg)
# ---------------------------------------------------------------------------

func _build_model() -> void:
	_mat = LowPolyMesh.make_material()
	_register_flash_material(_mat)

	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Corpo em pêra / oval
	LowPolyMesh.prism(st, Vector3(0.0, 0.12, 0.0), Vector3(0.0, 0.52, 0.0), 0.28, 0.22, 7, SLATE_BLUE)
	# Cabeça arredondada
	LowPolyMesh.prism(st, Vector3(0.0, 0.52, 0.0), Vector3(0.0, 0.74, 0.0), 0.22, 0.12, 6, SLATE_BLUE)

	# Barriga branca frontal
	LowPolyMesh.box(st, Vector3(0.0, 0.35, -0.16), Vector3(0.28, 0.36, 0.14), Basis.IDENTITY, BELLY_WHITE)

	# Máscara de ladrão preta em volta dos olhos
	LowPolyMesh.box(st, Vector3(0.0, 0.62, -0.14), Vector3(0.32, 0.10, 0.12), Basis.IDENTITY, MASK_BLACK)

	# Olhos cómicos brancos em cima da máscara
	LowPolyMesh.box(st, Vector3(-0.09, 0.63, -0.21), Vector3(0.09, 0.09, 0.04), Basis.IDENTITY, EYE_WHITE)
	LowPolyMesh.box(st, Vector3(0.09, 0.63, -0.21), Vector3(0.09, 0.09, 0.04), Basis.IDENTITY, EYE_WHITE)
	LowPolyMesh.box(st, Vector3(-0.09, 0.63, -0.235), Vector3(0.04, 0.04, 0.02), Basis.IDENTITY, EYE_PUPIL)
	LowPolyMesh.box(st, Vector3(0.09, 0.63, -0.235), Vector3(0.04, 0.04, 0.02), Basis.IDENTITY, EYE_PUPIL)

	# Bico laranja cónico
	LowPolyMesh.prism(st, Vector3(0.0, 0.54, -0.16), Vector3(0.0, 0.52, -0.32), 0.08, 0.01, 4, BEAK_ORANGE)

	# Cachecol vermelho grosso enrolado ao pescoço
	LowPolyMesh.prism(st, Vector3(0.0, 0.48, 0.0), Vector3(0.0, 0.55, 0.0), 0.27, 0.26, 7, SCARF_RED)

	_body.add_child(LowPolyMesh.commit(st, "MainMesh", _mat))

	# Ponta solta do cachecol pendurada à frente
	_scarf_tail = Node3D.new()
	_scarf_tail.name = "ScarfTail"
	_scarf_tail.position = Vector3(0.12, 0.48, -0.2)
	var st_scarf: SurfaceTool = SurfaceTool.new()
	st_scarf.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyMesh.box(st_scarf, Vector3(0.0, -0.12, 0.0), Vector3(0.08, 0.22, 0.04), Basis.IDENTITY, SCARF_RED)
	_scarf_tail.add_child(LowPolyMesh.commit(st_scarf, "ScarfMesh", _mat))
	_body.add_child(_scarf_tail)

	# Saco de pano com saque às costas
	_sack = Node3D.new()
	_sack.name = "LootSack"
	_sack.position = Vector3(0.12, 0.40, 0.24)
	var st_sack: SurfaceTool = SurfaceTool.new()
	st_sack.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyMesh.prism(st_sack, Vector3(0.0, -0.08, 0.0), Vector3(0.0, 0.14, 0.0), 0.22, 0.16, 6, SACK_BROWN)
	# Amarra / nó do saco
	LowPolyMesh.box(st_sack, Vector3(0.0, 0.17, 0.0), Vector3(0.08, 0.06, 0.08), Basis.IDENTITY, Color(0.85, 0.78, 0.6))
	_sack.add_child(LowPolyMesh.commit(st_sack, "SackMesh", _mat))
	_body.add_child(_sack)

	# Asas / barbatanas
	_wing_left = _build_wing(-0.24, "WingL")
	_wing_right = _build_wing(0.24, "WingR")

	# Patas palmípedes laranjas
	_foot_left = _build_foot(-0.11, "FootL")
	_foot_right = _build_foot(0.11, "FootR")

	# Collision Shape
	var cs: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 0.8
	cs.shape = cap
	cs.position = Vector3(0.0, 0.42, 0.0)
	add_child(cs)


func _build_wing(x: float, wing_name: String) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.name = wing_name
	pivot.position = Vector3(x, 0.45, 0.0)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s: float = -1.0 if x < 0.0 else 1.0
	LowPolyMesh.box(st, Vector3(s * 0.08, -0.14, 0.0), Vector3(0.05, 0.26, 0.14), Basis(Vector3.FORWARD, s * -0.2), SLATE_BLUE)
	pivot.add_child(LowPolyMesh.commit(st, "WingMesh", _mat))
	_body.add_child(pivot)
	return pivot


func _build_foot(x: float, foot_name: String) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.name = foot_name
	pivot.position = Vector3(x, 0.08, 0.0)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyMesh.box(st, Vector3(0.0, 0.0, -0.08), Vector3(0.14, 0.05, 0.22), Basis.IDENTITY, BEAK_ORANGE)
	pivot.add_child(LowPolyMesh.commit(st, "FootMesh", _mat))
	_body.add_child(pivot)
	return pivot


func _animate(delta: float) -> void:
	if _body == null:
		return

	if state == State.WADDLE or state == State.FLEE:
		var waddle_speed: float = 10.0 if state == State.FLEE else 7.0
		var roll: float = sin(_anim_time * waddle_speed) * 0.25
		_body.rotation.z = roll
		_body.position.y = absf(sin(_anim_time * waddle_speed)) * 0.05
		_body.rotation.x = lerp_angle(_body.rotation.x, 0.0, clampf(10.0 * delta, 0.0, 1.0))
		if _foot_left != null:
			_foot_left.rotation.x = sin(_anim_time * waddle_speed) * 0.4
		if _foot_right != null:
			_foot_right.rotation.x = -sin(_anim_time * waddle_speed) * 0.4
		if _wing_left != null:
			_wing_left.rotation.z = -absf(roll) * 0.8
		if _wing_right != null:
			_wing_right.rotation.z = absf(roll) * 0.8
		if _scarf_tail != null:
			_scarf_tail.rotation.z = -roll * 0.5
	elif state == State.SLIDE_WINDUP:
		# Inclina-se para a frente e bate com a barriga no chão
		_body.rotation.x = lerp_angle(_body.rotation.x, deg_to_rad(65.0), clampf(12.0 * delta, 0.0, 1.0))
		_body.position.y = lerpf(_body.position.y, -0.15, clampf(10.0 * delta, 0.0, 1.0))
		_body.rotation.z = 0.0
	elif state == State.SLIDE:
		# Posição de barriga colada ao gelo
		_body.rotation.x = deg_to_rad(78.0)
		_body.position.y = -0.2
		_body.rotation.z = sin(_anim_time * 16.0) * 0.08
		if _wing_left != null:
			_wing_left.rotation.z = -0.7
		if _wing_right != null:
			_wing_right.rotation.z = 0.7
		if _foot_left != null:
			_foot_left.rotation.x = 0.8
		if _foot_right != null:
			_foot_right.rotation.x = 0.8
		if _scarf_tail != null:
			_scarf_tail.rotation.x = -0.8
	elif state == State.BUMP:
		# Respinga para trás atordoado
		_body.rotation.x = -0.4
		_body.position.y = 0.1
	elif state == State.RECOVER:
		_body.rotation.x = lerp_angle(_body.rotation.x, 0.0, clampf(6.0 * delta, 0.0, 1.0))
		_body.position.y = lerpf(_body.position.y, 0.0, clampf(6.0 * delta, 0.0, 1.0))
		_body.rotation.z = sin(_anim_time * 12.0) * 0.1
