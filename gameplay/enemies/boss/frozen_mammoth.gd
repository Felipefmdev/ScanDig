class_name FrozenMammoth
extends EnemyBase

## Mamute Congelado (#43, #57): chefe principal da Geleira Eterna.
## Inspirado fielmente na referência visual mamute_congelado.jpg:
##  - Metade dianteira com pelagem castanha espessa, tromba curvada e presas gigantes de marfim
##    com estalactites penduradas;
##  - Metade traseira presa num enorme bloco de gelo glacial facetado;
##  - Olhos esbugalhados estilo "How to Fish", tromba que sopra gelo;
##  - Ataques caóticos e telegrafados:
##      * INVESTIDA (CHARGE): investe em linha reta e lança quem estiver no caminho pelos ares;
##        ao bater na parede ou esgotar a corrida, FICA PRESO/EXPOSTO no gelo (STUCK, dano a 2,5x);
##      * PISÃO (STOMP): ergue as patas dianteiras e esmaga o chão, rachando o gelo com onda de choque;
##      * AVALANCHE: solta bolas de neve gigantes que rolam pela arena;
##  - Troféu ao morrer: 'dente_mamute'.

signal boss_defeated(boss_id: StringName)
signal health_changed(current: float, max_value: float)

enum State { EMERGE, WALK, CHARGE_TELE, CHARGE, STUCK, STOMP_TELE, STOMP, DYING }

const BOSS_ID: StringName = &"frozen_mammoth"
const BOSS_NAME: String = "MAMUTE CONGELADO"
const GROUP_BOSSES: StringName = &"bosses"
const TROPHY_ITEM_ID: String = "dente_mamute"

const FUR_BROWN: Color = Color("#6a4228")
const FUR_DARK: Color = Color("#4a2c1a")
const GLACIER_ICE: Color = Color("#5aa8c0")
const ICE_HIGHLIGHT: Color = Color("#a0d8e8")
const TUSK_IVORY: Color = Color("#dcdcd0")
const EYE_WHITE: Color = Color(0.96, 0.96, 0.96)
const EYE_PUPIL: Color = Color(0.10, 0.10, 0.12)
const SNOW_WHITE: Color = Color(0.95, 0.97, 1.0)

const WEAK_POINT_FACTOR: float = 2.5
const CHARGE_RANGE: float = 18.0
const CHARGE_SPEED: float = 11.5
## Distância mínima (m) do centro do mamute às paredes da arena (meio corpo + folga).
const ARENA_MARGIN: float = 3.0
const STOMP_RADIUS: float = 4.8
const PHASE_TWO_RATIO: float = 0.5

@export var move_speed: float = 1.4
@export var turn_speed: float = 2.8
@export var charge_damage: float = 24.0
@export var stomp_damage: float = 20.0
@export var snowball_damage: float = 16.0
@export var charge_tele_time: float = 1.2
@export var stomp_tele_time: float = 1.1
@export var stuck_time: float = 3.8
@export var emerge_time: float = 2.4

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
var _anim_time: float = 0.0

var _hud: BossHud = null
var _warning: GroundWarning = null
var _body: Node3D = null
var _trunk: Node3D = null
## Meia-largura (x, z) da arena; INF = ainda não lida.
var _arena_half: Vector2 = Vector2(INF, INF)
var _leg_fl: Node3D = null
var _leg_fr: Node3D = null
var _glacier_block: MeshInstance3D = null
var _snowballs: Array[MeshInstance3D] = []
var _snowball_dirs: Array[Vector3] = []
var _snowball_speeds: Array[float] = []
var _mat: ShaderMaterial = null
var _ice_mat: ShaderMaterial = null


func _ready() -> void:
	super._ready()
	add_to_group(GROUP_BOSSES)
	max_health = 1350.0
	health = 1350.0
	death_color = GLACIER_ICE
	stun_fx_height = 3.6
	_surface_y = global_position.y
	_build_model()
	_hud = BossHud.create("🦣 " + tr(BOSS_NAME), max_health, Color(0.45, 0.75, 0.95))
	add_child(_hud)
	_warning = GroundWarning.new()
	add_child(_warning)
	boss_defeated.connect(_report_defeat_to_core)
	_enter_state(State.EMERGE)


func setup_network() -> void:
	super.setup_network()
	_add_synced_property(".:net_attack_dir")
	_add_synced_property(".:net_attack_point")


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if has_simulation_authority() and not _dead:
		_keep_inside_arena()


## QA coop (#62): numa investida o mamute saiu para lá das paredes (x 33.6 com a parede a
## 30.5) e ficou fora do alcance dos jogadores até ao fim. Mantém-no dentro dos Bounds do mapa.
func _keep_inside_arena() -> void:
	if _arena_half.x == INF:
		_arena_half = _find_arena_half()
	if _arena_half.x == INF or _arena_half.x <= 0.0:
		return
	var p: Vector3 = global_position
	var cx: float = clampf(p.x, -_arena_half.x, _arena_half.x)
	var cz: float = clampf(p.z, -_arena_half.y, _arena_half.y)
	if cx != p.x or cz != p.z:
		global_position = Vector3(cx, p.y, cz)


## Meia-largura útil da arena a partir das paredes do nó "Bounds" do mapa (menos a margem do
## corpo); (-1, -1) se o mapa não tiver Bounds (fica sem limite).
func _find_arena_half() -> Vector2:
	var scene: Node = get_tree().current_scene if is_inside_tree() else null
	var bounds: Node = scene.get_node_or_null(^"Bounds") if scene != null else null
	if bounds == null:
		return Vector2(-1.0, -1.0)
	var half: Vector2 = Vector2(INF, INF)
	for c: Node in bounds.get_children():
		var wall: Node3D = c as Node3D
		if wall == null:
			continue
		if absf(wall.position.x) > absf(wall.position.z):
			half.x = minf(half.x, absf(wall.position.x) - ARENA_MARGIN)
		else:
			half.y = minf(half.y, absf(wall.position.z) - ARENA_MARGIN)
	if half.x == INF or half.y == INF:
		return Vector2(-1.0, -1.0)
	return half


func _enemy_physics(delta: float) -> void:
	_state_time += delta
	_anim_time += delta

	_update_snowballs(delta)

	var speed_k: float = 0.8 if phase == 2 else 1.0

	match state:
		State.EMERGE:
			var t: float = clampf(_state_time / emerge_time, 0.0, 1.0)
			global_position.y = _surface_y - 3.5 * (1.0 - t)
			if t >= 1.0:
				_hud.visible = true
				_enter_state(State.WALK)
		State.WALK:
			_process_walk(delta)
		State.CHARGE_TELE:
			_warning.pulse(delta)
			_turn_towards(net_attack_dir, 0.0, turn_speed * 1.5, delta)
			if _state_time >= charge_tele_time * speed_k:
				_enter_state(State.CHARGE)
		State.CHARGE:
			_process_charge(delta)
		State.STUCK:
			_process_stuck(delta)
		State.STOMP_TELE:
			_warning.pulse(delta)
			if _state_time >= stomp_tele_time * speed_k:
				_enter_state(State.STOMP)
		State.STOMP:
			_process_stomp(delta)

	_animate(delta)


func _process(delta: float) -> void:
	if not has_simulation_authority() and state != State.DYING:
		_state_time += delta
		_hud.set_health(health)
		if _warning.visible:
			_warning.pulse(delta)
	elif state == State.DYING and _dead:
		# A física fica desligada na morte: o relógio da animação de morte avança aqui
		_state_time += delta
		_process_dying(delta)


func _enter_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	_hit_done = false
	_hit_targets.clear()

	match state:
		State.EMERGE:
			global_position.y = _surface_y - 3.5
		State.WALK:
			_warning.hide_warning()
		State.CHARGE_TELE:
			velocity = Vector3.ZERO
			net_attack_point = global_position
			var target: Node3D = _update_target(0.0)
			if target != null:
				var to: Vector3 = target.global_position - global_position
				to.y = 0.0
				net_attack_dir = to.normalized() if to.length() > 0.1 else -transform.basis.z
			else:
				net_attack_dir = -transform.basis.z
			_warning.show_line(global_position, net_attack_dir, CHARGE_RANGE, 2.8)
		State.CHARGE:
			_warning.hide_warning()
			SFX.play_at(SFX.EMERGE_SAND, global_position, 5.0)
		State.STUCK:
			_warning.hide_warning()
			velocity = Vector3.ZERO
			SFX.play_at(SFX.SHELL_KNOCK, global_position, 8.0)
			spawn_particles(global_position + Vector3.UP * 1.5, GLACIER_ICE, 35, 6.0)
		State.STOMP_TELE:
			velocity = Vector3.ZERO
			net_attack_point = global_position
			_warning.show_circle(global_position, STOMP_RADIUS)
		State.STOMP:
			_warning.hide_warning()


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

	# Alterna entre Investida e Pisão com avalanche
	if _state_time >= 2.2:
		_attack_cycle += 1
		if _attack_cycle % 2 == 1:
			_enter_state(State.CHARGE_TELE)
		else:
			_enter_state(State.STOMP_TELE)
		return

	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	move_and_slide()


func _process_charge(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = net_attack_dir.x * CHARGE_SPEED
	velocity.z = net_attack_dir.z * CHARGE_SPEED

	# Colisão com jogadores: arremesso estrondoso pelos ares (antes de mover: o corpo do
	# jogador travava o mamute antes de contar o golpe)
	for p: Node3D in _all_players():
		if _hit_targets.has(p):
			continue
		var d: Vector3 = p.global_position - global_position
		d.y = 0.0
		if d.length() <= 3.3:
			_hit_targets.append(p)
			_deal_damage(p, charge_damage)
			# Lança o jogador alto com tromba e presas!
			# Para o lado de fora da faixa (#57): à frente o mamute apanhava-o e prendia-o.
			var side: Vector3 = net_attack_dir.cross(Vector3.UP)
			if side.dot(d) < 0.0:
				side = -side
			_knockback(p, side * 11.0 + net_attack_dir * 5.0 + Vector3.UP * 11.0, 0.3)
			spawn_particles(p.global_position + Vector3.UP * 1.0, ICE_HIGHLIGHT, 20, 5.0)

	move_and_slide()
	# Se colidir contra parede ou completar o percurso, bate e FICA PRESO (um jogador no
	# caminho não conta como parede)
	if _state_time >= (CHARGE_RANGE / CHARGE_SPEED) or (is_on_wall() and _state_time > 0.2 and not _wall_is_player()):
		_enter_state(State.STUCK)


func _wall_is_player() -> bool:
	for i: int in get_slide_collision_count():
		var c: Object = get_slide_collision(i).get_collider()
		if c is Node and ((c as Node).is_in_group(&"players") or (c as Node).is_in_group(&"player")):
			return true
	return false


func _process_stuck(delta: float) -> void:
	_apply_gravity(delta)
	velocity = Vector3.ZERO
	move_and_slide()
	if _state_time >= stuck_time:
		_enter_state(State.WALK)


func _process_stomp(delta: float) -> void:
	_apply_gravity(delta)
	move_and_slide()

	if not _hit_done and _state_time >= 0.12:
		_hit_done = true
		_execute_stomp_and_avalanche()

	if _state_time >= 0.9:
		_enter_state(State.WALK)


func _execute_stomp_and_avalanche() -> void:
	SFX.play_at(SFX.EMERGE_SAND, global_position, 8.0)
	spawn_particles(global_position + Vector3.UP * 0.2, GLACIER_ICE, 40, 7.0)

	# Onda de choque do pisão
	for p: Node3D in _players_within(global_position, STOMP_RADIUS):
		_deal_damage(p, stomp_damage)
		var away: Vector3 = p.global_position - global_position
		away.y = 0.0
		var push: Vector3 = away.normalized() if away.length() > 0.1 else -transform.basis.z
		_knockback(p, push * 10.0 + Vector3.UP * 7.0, 0.2)

	# Avalanche de bolas de neve gigantes rolando pela arena!
	var count: int = 3 if phase == 2 else 2
	for i: int in count:
		var ang: float = -0.5 + float(i) * (1.0 / maxf(1.0, float(count - 1)))
		var roll_dir: Vector3 = (-transform.basis.z).rotated(Vector3.UP, ang).normalized()
		_spawn_rolling_snowball(global_position + Vector3.UP * 0.8 + roll_dir * 1.5, roll_dir)


func _spawn_rolling_snowball(spawn_pos: Vector3, dir: Vector3) -> void:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyMesh.prism(st, Vector3(0.0, -0.6, 0.0), Vector3(0.0, 0.6, 0.0), 0.75, 0.75, 8, SNOW_WHITE)
	LowPolyMesh.prism(st, Vector3(0.0, -0.75, 0.0), Vector3(0.0, 0.75, 0.0), 0.5, 0.5, 6, ICE_HIGHLIGHT)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = ToonKit.commit(st)
	mi.material_override = _mat
	mi.top_level = true
	add_child(mi)
	mi.global_position = spawn_pos

	_snowballs.append(mi)
	_snowball_dirs.append(dir)
	_snowball_speeds.append(8.5)


func _update_snowballs(delta: float) -> void:
	for i: int in range(_snowballs.size() - 1, -1, -1):
		var sb: MeshInstance3D = _snowballs[i]
		if not is_instance_valid(sb):
			_snowballs.remove_at(i)
			_snowball_dirs.remove_at(i)
			_snowball_speeds.remove_at(i)
			continue

		var dir: Vector3 = _snowball_dirs[i]
		var spd: float = _snowball_speeds[i]
		sb.global_position += dir * spd * delta
		sb.rotate(dir.cross(Vector3.UP).normalized(), 8.0 * delta)

		# Colisão da bola de neve com jogadores
		for p: Node3D in _all_players():
			var d: Vector3 = p.global_position - sb.global_position
			d.y = 0.0
			if d.length() <= 1.5:
				_deal_damage(p, snowball_damage)
				_knockback(p, dir * 12.0 + Vector3.UP * 4.0, 0.15)
				spawn_particles(sb.global_position, SNOW_WHITE, 15, 4.0)

		# Desaparece após percorrer distância (~2.5s)
		if sb.global_position.distance_squared_to(global_position) > 600.0:
			sb.queue_free()
			_snowballs.remove_at(i)
			_snowball_dirs.remove_at(i)
			_snowball_speeds.remove_at(i)


func is_weak_point_exposed() -> bool:
	return state == State.STUCK


func _modify_damage(amount: float, _from: Vector3) -> float:
	if is_weak_point_exposed():
		return amount * WEAK_POINT_FACTOR
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
		spawn_particles(global_position + Vector3.UP * 2.0, ICE_HIGHLIGHT, 40, 6.0)
		# Invoca dois lobos do gelo como reforço
		_spawn_minion(&"ice_wolf", global_position + Vector3(-4.0, 0.0, 0.0))
		_spawn_minion(&"ice_wolf", global_position + Vector3(4.0, 0.0, 0.0))


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
	var t: float = clampf(_state_time / 2.8, 0.0, 1.0)
	_body.position.y = -2.5 * t * t
	_body.rotation.z = lerpf(0.0, 0.35, t)

	if _state_time >= 1.2 and not _hit_done:
		_hit_done = true
		_hud.visible = false
		spawn_particles(global_position + Vector3.UP * 2.0, GLACIER_ICE, 60, 7.0)
		if has_simulation_authority():
			QuestRewards.drop_item(get_tree(), TROPHY_ITEM_ID, global_position + Vector3.UP * 2.0)
		boss_defeated.emit(BOSS_ID)

	if _state_time >= 3.2:
		for sb: MeshInstance3D in _snowballs:
			if is_instance_valid(sb):
				sb.queue_free()
		queue_free()


func _report_defeat_to_core(boss_id: StringName) -> void:
	if has_simulation_authority() and GameState.instance != null:
		GameState.instance.request_report_boss_defeated(String(boss_id))


func _refresh_remote_visuals() -> void:
	if _warning == null:
		return
	match state:
		State.CHARGE_TELE:
			_warning.show_line(global_position, net_attack_dir, CHARGE_RANGE, 2.8)
		State.STOMP_TELE:
			_warning.show_circle(global_position, STOMP_RADIUS)
		_:
			_warning.hide_warning()


func _on_remote_state(new_state: int) -> void:
	state = new_state as State
	_state_time = 0.0
	_hud.visible = state != State.EMERGE and state != State.DYING
	_refresh_remote_visuals()


# ---------------------------------------------------------------------------
# Modelo 3D Low-Poly + ToonKit (referência: mamute_congelado.jpg)
# ---------------------------------------------------------------------------

func _build_model() -> void:
	_mat = ToonKit.vertex_material(true, true)
	_register_flash_material(_mat)

	_ice_mat = ToonKit.vertex_material(true, true)
	_ice_mat.set_shader_parameter(&"specular_amount", 0.6)
	_register_flash_material(_ice_mat)

	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Tronco frontal peludo e maciço
	LowPolyMesh.prism(st, Vector3(0.0, 1.2, 0.4), Vector3(0.0, 1.6, -1.0), 1.1, 1.3, 7, FUR_BROWN)
	# Costas e corcunda peluda com tufos
	LowPolyMesh.box(st, Vector3(0.0, 2.2, -0.4), Vector3(1.6, 0.8, 1.4), Basis.IDENTITY, FUR_DARK)

	# Cabeça volumosa com topete peludo
	LowPolyMesh.prism(st, Vector3(0.0, 1.8, -1.0), Vector3(0.0, 2.1, -1.8), 0.95, 0.75, 6, FUR_BROWN)
	LowPolyMesh.box(st, Vector3(0.0, 2.6, -1.5), Vector3(1.1, 0.6, 0.8), Basis.IDENTITY, FUR_DARK)

	# Orelhas largas
	LowPolyMesh.box(st, Vector3(-0.95, 2.1, -1.2), Vector3(0.12, 0.65, 0.45), Basis(Vector3.FORWARD, 0.25), FUR_DARK)
	LowPolyMesh.box(st, Vector3(0.95, 2.1, -1.2), Vector3(0.12, 0.65, 0.45), Basis(Vector3.FORWARD, -0.25), FUR_DARK)

	# Olhos cómicos "How to Fish" esbugalhados
	LowPolyMesh.box(st, Vector3(-0.55, 2.2, -1.75), Vector3(0.22, 0.22, 0.08), Basis.IDENTITY, EYE_WHITE)
	LowPolyMesh.box(st, Vector3(0.55, 2.2, -1.75), Vector3(0.22, 0.22, 0.08), Basis.IDENTITY, EYE_WHITE)
	LowPolyMesh.box(st, Vector3(-0.55, 2.2, -1.8), Vector3(0.10, 0.10, 0.04), Basis.IDENTITY, EYE_PUPIL)
	LowPolyMesh.box(st, Vector3(0.55, 2.2, -1.8), Vector3(0.10, 0.10, 0.04), Basis.IDENTITY, EYE_PUPIL)

	# Presas gigantes de marfim curvadas para a frente e para cima
	for s: float in [-1.0, 1.0]:
		LowPolyMesh.prism(st, Vector3(0.45 * s, 1.6, -1.8), Vector3(0.75 * s, 1.2, -2.6), 0.18, 0.14, 5, TUSK_IVORY)
		LowPolyMesh.prism(st, Vector3(0.75 * s, 1.2, -2.6), Vector3(0.65 * s, 2.0, -3.2), 0.14, 0.03, 4, TUSK_IVORY)
		# Estalactites de gelo penduradas nas presas (como na foto de referência!)
		for ic: int in 4:
			var ipos: Vector3 = Vector3(0.55 * s, 1.4 - float(ic) * 0.15, -2.1 - float(ic) * 0.25)
			LowPolyMesh.prism(st, ipos, ipos + Vector3(0.0, -0.45, 0.0), 0.05, 0.0, 3, ICE_HIGHLIGHT)

	_body.add_child(LowPolyMesh.commit(st, "FurMesh", _mat))

	# Metade traseira: BLOCO GIGANTE DE GELO GLACIAL (referência: mamute_congelado.jpg)
	var st_ice: SurfaceTool = SurfaceTool.new()
	st_ice.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Núcleo + pedregulhos facetados sobrepostos: massa de gelo arredondada, não um bloco
	LowPolyMesh.prism(st_ice, Vector3(0.0, 0.2, 0.5), Vector3(0.0, 2.3, 0.7), 1.5, 1.2, 9, GLACIER_ICE)
	var lumps: Array[Vector4] = [
		Vector4(-0.9, 0.7, 1.4, 0.75), Vector4(0.9, 0.7, 1.4, 0.75), Vector4(0.0, 0.9, 2.0, 0.8),
		Vector4(-1.1, 1.6, 0.6, 0.6), Vector4(1.1, 1.6, 0.6, 0.6), Vector4(0.0, 2.2, 1.1, 0.7),
		Vector4(-0.6, 2.3, 0.2, 0.5), Vector4(0.6, 2.25, 0.3, 0.5), Vector4(0.0, 1.5, 2.3, 0.6),
	]
	for i: int in lumps.size():
		var l: Vector4 = lumps[i]
		var c: Vector3 = Vector3(l.x, l.y, l.z)
		LowPolyMesh.prism(st_ice, c - Vector3(0.0, l.w * 0.7, 0.0), c + Vector3(0.0, l.w * 0.6, 0.0), l.w, l.w * 0.55, 6, ICE_HIGHLIGHT if i % 3 == 0 else GLACIER_ICE)
	# Cristais pontiagudos saindo do bloco
	for k: int in 6:
		var ang: float = float(k) * 1.05
		var cpos: Vector3 = Vector3(cos(ang) * 1.2, 1.6 + sin(ang * 2.0) * 0.4, 0.8 + sin(ang) * 0.6)
		LowPolyMesh.prism(st_ice, cpos, cpos * 1.35 + Vector3.UP * 0.4, 0.22, 0.0, 4, ICE_HIGHLIGHT)
	_glacier_block = LowPolyMesh.commit(st_ice, "GlacierMesh", _ice_mat)
	_body.add_child(_glacier_block)

	# Tromba articulada curvada para cima
	_trunk = Node3D.new()
	_trunk.name = "Trunk"
	_trunk.position = Vector3(0.0, 1.7, -1.9)
	var st_trunk: SurfaceTool = SurfaceTool.new()
	st_trunk.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Tromba longa em S: desce, curva para a frente e ergue-se a soprar gelo (mamute_congelado.jpg)
	var pts: Array[Vector3] = [
		Vector3(0.0, 0.0, 0.0), Vector3(0.0, -0.55, -0.3), Vector3(0.0, -0.75, -0.75),
		Vector3(0.0, -0.45, -1.15), Vector3(0.0, 0.1, -1.3), Vector3(0.0, 0.6, -1.25),
	]
	for i: int in pts.size() - 1:
		var r0: float = lerpf(0.24, 0.1, float(i) / float(pts.size() - 1))
		var r1: float = lerpf(0.24, 0.1, float(i + 1) / float(pts.size() - 1))
		LowPolyMesh.prism(st_trunk, pts[i], pts[i + 1], r0, r1, 6, FUR_DARK if i % 2 == 0 else FUR_BROWN)
	LowPolyMesh.prism(st_trunk, pts[5], pts[5] + Vector3(0.0, 0.06, 0.0), 0.13, 0.13, 6, FUR_DARK)
	# Nuvem de neve a sair da ponta
	for k: int in 4:
		var puff: Vector3 = pts[5] + Vector3((float(k) - 1.5) * 0.14, 0.25 + 0.12 * float(k % 2), 0.05)
		LowPolyMesh.prism(st_trunk, puff - Vector3(0.0, 0.1, 0.0), puff + Vector3(0.0, 0.1, 0.0), 0.12, 0.08, 6, SNOW_WHITE)
	_trunk.add_child(LowPolyMesh.commit(st_trunk, "TrunkMesh", _mat))
	_body.add_child(_trunk)

	# Patas dianteiras robustas
	_leg_fl = _build_leg(-0.75, "LegFL")
	_leg_fr = _build_leg(0.75, "LegFR")

	# Collision Shape colossal
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(2.6, 2.8, 4.4)
	cs.shape = box
	cs.position = Vector3(0.0, 1.4, -0.2)
	add_child(cs)


func _build_leg(x: float, leg_name: String) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.name = leg_name
	pivot.position = Vector3(x, 1.1, -0.6)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	LowPolyMesh.prism(st, Vector3(0.0, 0.0, 0.0), Vector3(0.0, -0.7, 0.0), 0.36, 0.32, 6, FUR_BROWN)
	LowPolyMesh.prism(st, Vector3(0.0, -0.7, 0.0), Vector3(0.0, -1.1, 0.0), 0.32, 0.35, 6, FUR_DARK)
	pivot.add_child(LowPolyMesh.commit(st, "LegMesh", _mat))
	_body.add_child(pivot)
	return pivot


func _animate(delta: float) -> void:
	if _body == null:
		return

	if state == State.WALK:
		var step: float = sin(_anim_time * 5.0)
		if _leg_fl != null:
			_leg_fl.rotation.x = step * 0.35
		if _leg_fr != null:
			_leg_fr.rotation.x = -step * 0.35
		if _trunk != null:
			_trunk.rotation.x = sin(_anim_time * 4.0) * 0.25
		_body.position.y = absf(sin(_anim_time * 5.0)) * 0.1
	elif state == State.CHARGE_TELE:
		# Raspa a pata no chão e levanta a tromba
		_body.rotation.x = -0.15
		if _trunk != null:
			_trunk.rotation.x = -0.45
	elif state == State.CHARGE:
		_body.rotation.x = 0.12
		_body.position.y = absf(sin(_anim_time * 12.0)) * 0.15
		if _trunk != null:
			_trunk.rotation.x = 0.35
	elif state == State.STUCK:
		# Enfiado de cabeça no gelo, rabo preso levantado
		_body.rotation.x = 0.35
		_body.position.y = -0.3
		_body.rotation.z = sin(_anim_time * 8.0) * 0.06
	elif state == State.STOMP_TELE:
		# Ergue as patas bem alto
		_body.rotation.x = -0.45
		_body.position.y = 0.5
		if _leg_fl != null:
			_leg_fl.rotation.x = -0.6
		if _leg_fr != null:
			_leg_fr.rotation.x = -0.6
	elif state == State.STOMP:
		# Bate estrondosamente no chão
		_body.rotation.x = 0.2
		_body.position.y = -0.2
